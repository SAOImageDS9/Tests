#!/usr/bin/env python
"""Send ds9 one SAMP ds9.set or ds9.get through the hub of <lockfile>.

usage: python -I sampcall.py <lockfile> <ds9 name> set|get <command>

Prints the reply's value (get), or "ERROR: <text>" when ds9 reports a
failure; exits 1 if there is no such client.
"""
import sys
import warnings
warnings.simplefilter("ignore")
from astropy.samp import SAMPIntegratedClient

lock, name, kind, cmd = sys.argv[1:5]

# the lockfile: key=value lines, # comments
params = {}
with open(lock) as f:
    for line in f:
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            k, v = line.split("=", 1)
            params[k] = v

cli = SAMPIntegratedClient(name="hipstest")
cli.connect(hub_params=params)
try:
    target = None
    for cid in cli.get_registered_clients():
        md = cli.get_metadata(cid)
        if md.get("samp.name", "").lower() == name.lower():
            target = cid
    if target is None:
        print(f"no client {name}")
        sys.exit(1)
    r = cli.ecall_and_wait(target, "ds9." + kind, "60", cmd=cmd)
    if r.get("samp.status") != "samp.ok":
        err = r.get("samp.error", {})
        print("ERROR: " + str(err.get("samp.errortxt", r.get("samp.status"))))
    else:
        res = r.get("samp.result", {})
        url = res.get("url")
        if url:
            # a long answer comes as a file (file://localhost/<path>)
            path = url.split("localhost", 1)[1] if "localhost" in url else url[7:]
            with open(path) as f:
                print(f.read(), end="")
        elif res.get("value") is not None:
            print(res["value"])
finally:
    cli.disconnect()
