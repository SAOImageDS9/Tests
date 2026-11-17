#!/usr/bin/env python
"""A small HTTP server for the remote HiPS tests.

usage: python -I hipsserve.py <root> <portfile> <logfile>

Serves files under <root> (404 for anything missing), on a free port
on 127.0.0.1 that it writes to <portfile>. Each GET is logged to
<logfile> as "<code> <path>". Path prefixes:
  /redirect/...  302 to the same path without the prefix
  /slow/...      as without it, after 0.2 s
  /crawl/...     as without it, after 1 s
  /half/...      properties as without it, anything else 503 (a broken
                 server whose properties name a mirror)
  /nodeep/...    as without it, but 503 for tiles of order 3 and up (a
                 server that fails while a deep window fetches)
  /MocServer/query
                 a mock CDS MocServer over the records in <root>/registry.txt
                 ("key = value" lines, blank-line separated; {URL} becomes
                 this server's base URL). Any parameter but get, fields and
                 fmt is a constraint (a glob; * means the key is present);
                 fields= keeps those keys; the answer is "key = value"
                 records. Logged with its query.
  /down/MocServer/query
                 503 (a MocServer that is down)
With HIPSSERVE_CERT and HIPSSERVE_KEY set (PEM files) it serves https
instead. Runs until killed.
"""
import os
import re
import sys
import time
import threading
from fnmatch import fnmatchcase
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
from urllib.parse import unquote, urlsplit, parse_qs

root, portfile, logfile = sys.argv[1], sys.argv[2], sys.argv[3]
root = os.path.abspath(root)
lock = threading.Lock()


def log(code, path):
    with lock:
        with open(logfile, "a") as f:
            f.write(f"{code} {path}\n")


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def send(self, code, data=b""):
        self.send_response(code)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def mocserver(self, path):
        query = urlsplit(self.path).query
        logged = f"{path}?{unquote(query)}"
        if path.startswith("/down/"):
            log(503, logged)
            return self.send(503)
        base = f"{scheme}://127.0.0.1:{self.server.server_address[1]}"
        recs, rec = [], []
        try:
            lines = open(os.path.join(root, "registry.txt")).read().splitlines()
        except OSError:
            lines = []
        for line in lines + [""]:
            if not line.strip():
                if rec:
                    recs.append(rec)
                rec = []
                continue
            k, _, v = line.partition("=")
            rec.append((k.strip(), v.strip().replace("{URL}", base)))
        q = {k: v[0] for k, v in parse_qs(query).items()}
        fields = q.get("fields")
        out = []
        for rec in recs:
            d = dict(rec)
            keep = True
            for k, v in q.items():
                if k in ("get", "fields", "fmt"):
                    continue
                if v == "*":
                    keep = keep and k in d
                else:
                    keep = keep and fnmatchcase(d.get(k, ""), v)
            if not keep:
                continue
            for k, v in rec:
                if fields is None or k in fields.split(","):
                    out.append(f"{k:<20} = {v}")
            out.append("")
        log(200, logged)
        self.send(200, "\n".join(out).encode())

    def do_GET(self):
        path = unquote(self.path.split("?", 1)[0])
        if path.endswith("/MocServer/query"):
            return self.mocserver(path)
        if path.startswith("/redirect/"):
            log(302, path)
            self.send_response(302)
            self.send_header("Location", path[len("/redirect"):])
            self.send_header("Content-Length", "0")
            self.end_headers()
            return
        if path.startswith("/half/"):
            if not path.endswith("/properties"):
                log(503, path)
                self.send_response(503)
                self.send_header("Content-Length", "0")
                self.end_headers()
                return
            path = path[len("/half"):]
        if path.startswith("/nodeep/"):
            path = path[len("/nodeep"):]
            if re.search(r"/Norder([3-9]|[1-9][0-9])/", path):
                log(503, path)
                self.send_response(503)
                self.send_header("Content-Length", "0")
                self.end_headers()
                return
        if path.startswith("/crawl/"):
            time.sleep(1.0)
            path = path[len("/crawl"):]
        if path.startswith("/slow/"):
            time.sleep(0.2)
            path = path[len("/slow"):]
        # normpath, not realpath: the test links sample HiPS into root
        fn = os.path.normpath(os.path.join(root, path.lstrip("/")))
        if not fn.startswith(root + os.sep) or not os.path.isfile(fn):
            log(404, path)
            self.send_response(404)
            self.send_header("Content-Length", "0")
            self.end_headers()
            return
        with open(fn, "rb") as f:
            data = f.read()
        log(200, path)
        self.send_response(200)
        self.send_header("Content-Type", "application/octet-stream")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)


srv = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
scheme = "http"
if os.environ.get("HIPSSERVE_CERT"):
    import ssl
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    ctx.load_cert_chain(os.environ["HIPSSERVE_CERT"], os.environ["HIPSSERVE_KEY"])
    srv.socket = ctx.wrap_socket(srv.socket, server_side=True,
                                 do_handshake_on_connect=False)
    scheme = "https"
with open(portfile, "w") as f:
    f.write(str(srv.server_address[1]))
srv.serve_forever()
