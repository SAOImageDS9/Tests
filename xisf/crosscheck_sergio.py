#!/usr/bin/env python3
"""Decode every fixture with a third-party XISF reader and compare to the twins.

read_xisf.py is independent of the generator, but both were written by the
same hand against the same reading of the spec. This runs sergio-dr's `xisf`
(https://github.com/sergio-dr/xisf, GPL-3.0; numpy + lz4 + zstandard), a
reader written by someone else, over the same manifest, so an agreement here
is evidence about the fixtures rather than about one author's reading.

    crosscheck_sergio.py /path/to/xisf/src     # the directory holding xisf.py

Nothing is vendored: point it at a checkout. The module reads its own version
from installed package metadata at import time, which a bare checkout does
not have, so that one call is stubbed.
"""
import importlib.metadata as md
import pathlib
import sys
import warnings

import numpy as np
from astropy.io import fits

HERE = pathlib.Path(__file__).resolve().parent


def load_module(src):
    real = md.version
    md.version = lambda name: "0+checkout" if name == "xisf" else real(name)
    sys.path.insert(0, str(src))
    try:
        import xisf
    finally:
        md.version = real
    return xisf


def main(src):
    xisf = load_module(src)
    rows = []
    for m in (HERE / "MANIFEST.tsv", HERE / "real/MANIFEST.tsv"):
        rows += [l.rstrip("\n").split("\t") for l in open(m)
                 if not l.startswith("#")]
    agree = 0
    for rel, expect, _, _ in rows:
        try:
            with warnings.catch_warnings():
                warnings.simplefilter("ignore")
                pix = xisf.XISF(str(HERE / rel)).read_image(0, "channels_first")
            got, why = "load", ""
        except Exception as e:                       # noqa: BLE001
            got, why = "refuse", f"{type(e).__name__}: {e}"
        if expect == "refuse":
            ok = got == "refuse"
            msg = ("refused: " + why[:90]) if ok else "LOADED (we refuse)"
        elif got == "refuse":
            ok, msg = False, "REFUSED (we load): " + why[:90]
        else:
            twin = fits.getdata(HERE / pathlib.Path(rel).with_suffix(".fits"))
            a = np.asarray(pix)[..., ::-1, :]
            a = a[0] if a.shape[0] == 1 else a
            ok = a.shape == twin.shape and np.array_equal(
                a.astype(twin.dtype), twin, equal_nan=True)
            msg = "pixels match twin" if ok else f"PIXELS DIFFER {a.shape} vs {twin.shape}"
        agree += ok
        print(f"{'ok  ' if ok else 'DIFF'} {rel}: {msg}")
    print(f"{agree}/{len(rows)} agree with the manifest")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
