#!/usr/bin/env python3
"""Check fitsy's XISF container reader against the fixtures (TODO_XISF.md Phases 1-2).

    check_container.py <path to utils/xisfdump/xisfdump>

Runs the standalone dump driver over every fixture in MANIFEST.tsv and
real/MANIFEST.tsv and checks, for **every** image in every file, not just
the first:

  * the container verdict (whole file refused or not) agrees with
    read_xisf.py's;
  * each image's verdict agrees with read_xisf.py's: both load it, or both
    refuse it - except where read_xisf.py's reason belongs to a later phase
    (decompression, checksums, sample values), which the container reader
    is not expected to catch yet and which is listed as DEFERRED;
  * the stored bytes the reader returns are exactly the block's bytes;
  * the decoded bytes block() returns (checksum verified, decompressed,
    unshuffled) are exactly read_xisf.py's, for every image it loads;
  * a block whose checksum is wrong, or whose subblocks decode to other than
    their declared sizes, is refused by block(), even though the header
    alone cannot know that;
  * the manifest's expectation for image 0 is consistent with all of that.

Exit status is the number of failures.
"""
import base64
import hashlib
import pathlib
import subprocess
import sys

import read_xisf as rx

HERE = pathlib.Path(__file__).resolve().parent

# read_xisf.py refusals that only block() can make - the header cannot know
# a digest is wrong, or that a subblock decodes to other than its declared
# size - and those that are Phase 3's (sample values).
BLOCK_LEVEL = ("checksum mismatch", "zlib:", "lz4:", "lz4hc:", "zstd:")
DEFERRED = ("UInt64 value above INT64_MAX",)


def fnv1a64(data):
    h = 0xcbf29ce484222325
    for b in data:
        h ^= b
        h = (h * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF
    return f"{h:016x}"


def stored_bytes(raw, el):
    """The block's bytes as stored, independently of read_xisf.block()."""
    loc = el.get("location", "")
    if loc.startswith("attachment:"):
        _, p, s = loc.split(":")
        return raw[int(p):int(p) + int(s)]
    if loc == "embedded":
        d = el.find(rx.NS + "Data")
        txt = "".join((d.text or "").split())
        return (base64.b64decode(txt) if d.get("encoding") == "base64"
                else bytes.fromhex(txt))
    return None


def dump(tool, path):
    out = subprocess.run([tool, str(path)], capture_output=True, text=True,
                         timeout=60)
    if out.returncode:
        return {"crash": out.stderr.strip() or f"exit {out.returncode}"}
    res = {"images": {}, "stored": {}, "block": {}}
    for line in out.stdout.splitlines():
        kind, _, rest = line.partition(" ")
        if kind == "error":
            res["error"] = rest
        elif kind == "image":
            idx, _, attrs = rest.partition(" ")
            status = attrs.split(" status=", 1)[1]
            res["images"][int(idx)] = status
        elif kind in ("stored", "block"):
            idx, _, val = rest.partition(" ")
            res[kind][int(idx)] = val
    return res


def main(tool):
    rows = []
    for m in (HERE / "MANIFEST.tsv", HERE / "real/MANIFEST.tsv"):
        rows += [l.rstrip("\n").split("\t") for l in open(m)
                 if not l.startswith("#")]
    fails, deferred, checked = [], [], 0
    for rel, expect, _, _ in rows:
        path = HERE / rel
        d = dump(tool, path)
        problems = []
        if "crash" in d:
            fails.append(f"{rel}: CRASH {d['crash']}")
            continue
        try:
            raw, els = rx.images(path)
            py_err = None
        except rx.Refused as e:
            raw, els, py_err = None, [], str(e)
        # "no Image elements" is a container-valid unit with nothing to load
        if py_err == "no Image elements":
            py_err, els = None, []
        if py_err or "error" in d:
            if not (py_err and "error" in d):
                problems.append(f"container: reader {d.get('error', 'ok')!r}"
                                f" vs reference {py_err or 'ok'!r}")
        else:
            if len(d["images"]) != len(els):
                problems.append(f"{len(d['images'])} images, reference "
                                f"{len(els)}")
            for i, el in enumerate(els):
                checked += 1
                status = d["images"].get(i, "missing")
                try:
                    rx.image(raw, el)
                    py = None
                except rx.Refused as e:
                    py = str(e)
                ok = status == "ok"
                if py is None and not ok:
                    problems.append(f"image {i}: reader {status!r}, "
                                    "reference loads it")
                elif py is not None and ok and py.startswith(BLOCK_LEVEL):
                    blk = d["block"].get(i, "")
                    if not blk.startswith("error"):
                        problems.append(f"image {i}: block() returned "
                                        f"{blk!r}, reference: {py}")
                    deferred.append(f"{rel} image {i}: refused by block(): "
                                    f"{blk[6:]}")
                elif py is not None and ok:
                    if py.startswith(DEFERRED):
                        deferred.append(f"{rel} image {i}: {py}")
                    else:
                        problems.append(f"image {i}: reader loads it, "
                                        f"reference refuses: {py}")
                sb = stored_bytes(raw, el)
                if ok and sb is not None:
                    want = f"{len(sb)} {fnv1a64(sb)}"
                    if d["stored"].get(i) != want:
                        problems.append(f"image {i}: stored "
                                        f"{d['stored'].get(i)} != {want}")
                if ok and py is None:
                    dec = rx.block(raw, el, el)
                    want = f"{len(dec)} {fnv1a64(dec)}"
                    if d["block"].get(i) != want:
                        problems.append(f"image {i}: block "
                                        f"{d['block'].get(i)} != {want}")
            first = d["images"].get(0)
            if expect in ("load", "load-first") and first != "ok":
                problems.append(f"manifest says {expect}, image 0 is {first}")
        if expect == "refuse" and "error" not in d and \
                d["images"].get(0, "missing") == "ok" and \
                not any(x.startswith(f"{rel} image 0:") for x in deferred):
            problems.append("manifest says refuse, reader accepts image 0")
        if problems:
            fails += [f"{rel}: {p}" for p in problems]
    for x in deferred:
        print(("BLOCK    " if "refused by block()" in x else "DEFERRED ") + x)
    for f in fails:
        print(f"FAIL     {f}")
    nb = sum("refused by block()" in x for x in deferred)
    print(f"{len(rows)} files, {checked} images: {len(fails)} failures, "
          f"{nb} refused by block(), {len(deferred) - nb} deferred to "
          "later phases")
    return len(fails)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    sys.exit(main(sys.argv[1]))
