#!/usr/bin/env python3
"""Check fitsy's FitsXisf against the FITS twins (TODO_XISF.md Phase 3).

    check_fits.py <path to utils/xisfdump/xisfdump>

For every fixture in MANIFEST.tsv and real/MANIFEST.tsv, runs
`xisfdump --fits` - the FitsFile ds9 will load - and checks:

  * a `load'/`load-first' fixture loads, with the twin's width, height and
    depth, the manifest's BITPIX, and every plane's samples byte-identical
    to the twin's (rows flipped, Normal storage made planar, UInt32
    widened, channels as planes);
  * a `refuse' fixture is refused, with a message;
  * the other images of a multi-image file load by id or index and match
    their own twins (multi_three__<id>.fits, <name>.<index>.fits);
  * no header carries a card that would reinterpret the pixels (BZERO,
    BSCALE, BLANK);
  * the header's WCS and the twin's agree: the same sky position, to 1e-9
    degrees, at a grid of pixels over the whole image (Phase 4) - and a
    twin with no celestial WCS means the header must have none;
  * the header keeps the keywords it should, for the fixtures built to
    test that.

Exit status is the number of failures.
"""
import pathlib
import subprocess
import sys

import warnings

import numpy as np
from astropy.io import fits
from astropy.wcs import WCS, FITSFixedWarning

HERE = pathlib.Path(__file__).resolve().parent

DTYPE = {"8": "u1", "-16": "<u2", "64": "<i8", "-32": "<f4", "-64": "<f8"}

# cards no loaded header may have
FORBIDDEN = ("BZERO", "BSCALE", "BLANK")
WCS_TOL = 1e-9          # degrees

# keywords particular fixtures must carry: name -> value text it contains
EXPECT_CARDS = {
    "header/keywords.xisf": {"OBJECT": "'M31 & friends'", "EXPTIME": "300.",
                             "FILTER": "'Ha'", "DATE-OBS": "2026-10-01T03:00:00Z",
                             "XBINNING": "2", "IMAGETYP": "'Light'",
                             "DATAMIN": "0", "DATAMAX": "1"},
    "real/libxisf/test.xisf": {"OBJECT": "'Unknown '", "EXPTIME": "1.",
                               "ROWORDER": "'TOP-DOWN'"},
    "formats/float32_bounds_wide.xisf": {"DATAMIN": "-200", "DATAMAX": "800"},
}


def fnv1a64(data):
    h = 0xcbf29ce484222325
    for b in data:
        h ^= b
        h = (h * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF
    return f"{h:016x}"


def run(tool, path, key=None):
    cmd = [tool, "--fits"] + (["--image", key] if key else []) + [str(path)]
    out = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    if out.returncode:
        return {"crash": out.stderr.strip() or f"exit {out.returncode}"}
    res = {"cards": [], "planes": []}
    for line in out.stdout.splitlines():
        kind, _, rest = line.partition(" ")
        if kind == "fits" and rest.startswith("error"):
            res["error"] = rest[6:]
        elif kind == "fits":
            res["shape"] = [int(v) for v in rest.split()]
        elif kind == "card":
            res["cards"].append(rest)
        elif kind == "plane":
            res["planes"].append(rest.split()[1])
    return res


def card_value(cards, name):
    for c in cards:
        if c[:8].rstrip() == name and c[8:10] == "= ":
            return c[10:]
    return None


def celestial(header):
    with warnings.catch_warnings():
        warnings.simplefilter("ignore", FITSFixedWarning)
        w = WCS(header, naxis=2)
    return w if w.has_celestial else None


def compare_wcs(cards, twin_header, w, h):
    head = fits.Header.fromstring("".join(c.ljust(80)[:80] for c in cards))
    mine, want = celestial(head), celestial(twin_header)
    if want is None:
        return ["header has a WCS, twin has none"] if mine else []
    if mine is None:
        return ["header has no WCS, twin has one"]
    xs = np.linspace(1, w, 7)
    ys = np.linspace(1, h, 5)
    pix = np.array([(x, y) for x in xs for y in ys])
    a = mine.all_pix2world(pix, 1)
    b = want.all_pix2world(pix, 1)
    dra = (a[:, 0] - b[:, 0] + 180) % 360 - 180
    err = np.max(np.hypot(dra * np.cos(np.radians(b[:, 1])), a[:, 1] - b[:, 1]))
    return [f"WCS differs from the twin by {err:.3g} deg"] if err > WCS_TOL \
        else []


def compare(rel, d, twin_path, bitpix):
    problems = []
    if "crash" in d:
        return [f"CRASH {d['crash']}"]
    if "error" in d:
        return [f"refused: {d['error']}"]
    twin = fits.getdata(twin_path)
    planes = twin if twin.ndim == 3 else twin[None]
    w, h, dep, bp = d["shape"]
    if bitpix is None:          # another image of the file: its own format
        bitpix = str(bp)
    if (dep, h, w) != planes.shape:
        problems.append(f"shape {w}x{h}x{dep}, twin {planes.shape[::-1]}")
    if str(bp) != bitpix:
        problems.append(f"bitpix {bp}, manifest {bitpix}")
    for k, p in enumerate(planes):
        want = fnv1a64(np.ascontiguousarray(p).astype(DTYPE[bitpix]).tobytes())
        got = d["planes"][k] if k < len(d["planes"]) else None
        if got != want:
            problems.append(f"plane {k}: {got} != twin {want}")
    for name in FORBIDDEN:
        if card_value(d["cards"], name) is not None:
            problems.append(f"header has {name}")
    problems += compare_wcs(d["cards"], fits.getheader(twin_path), w, h)
    for name, text in EXPECT_CARDS.get(rel, {}).items():
        v = card_value(d["cards"], name)
        if v is None or text not in v:
            problems.append(f"header {name} is {v!r}, wants {text!r}")
    return problems


def main(tool):
    rows = []
    for m in (HERE / "MANIFEST.tsv", HERE / "real/MANIFEST.tsv"):
        rows += [l.rstrip("\n").split("\t") for l in open(m)
                 if not l.startswith("#")]
    fails, loads, refusals, extra = [], 0, 0, 0
    for rel, expect, bitpix, _ in rows:
        path = HERE / rel
        d = run(tool, path)
        if expect == "refuse":
            refusals += 1
            if "crash" in d:
                fails.append(f"{rel}: CRASH {d['crash']}")
            elif "error" not in d:
                fails.append(f"{rel}: loaded, manifest says refuse")
            elif not d["error"].strip():
                fails.append(f"{rel}: refused with no message")
            continue
        loads += 1
        fails += [f"{rel}: {p}" for p in
                  compare(rel, d, path.with_suffix(".fits"), bitpix)]
        # the other images, where a twin exists for them
        for twin in sorted(path.parent.glob(path.stem + "__*.fits")):
            key = twin.stem.split("__", 1)[1]
            extra += 1
            fails += [f"{rel} [{key}]: {p}" for p in
                      compare(rel, run(tool, path, key), twin, None)]
        for twin in sorted(path.parent.glob(path.stem + ".[0-9].fits")):
            key = twin.suffixes[-2][1:]
            extra += 1
            fails += [f"{rel} [{key}]: {p}" for p in
                      compare(rel, run(tool, path, key), twin, None)]
    for f in fails:
        print(f"FAIL {f}")
    print(f"{len(rows)} files: {loads} loads + {extra} more images by key, "
          f"{refusals} refusals; {len(fails)} failures")
    return len(fails)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    sys.exit(main(sys.argv[1]))
