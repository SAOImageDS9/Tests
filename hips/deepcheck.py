#!/usr/bin/env python
"""Check a deep HiPS window (saved by ds9) against the HiPS tiles.

usage: python -I deepcheck.py <hips dir> <window.fits> [frame]

The window's HISTORY says which order K it shows ("HiPS order K tiles").
For every window pixel: its sky position from the window's WCS
(astropy), its NESTED pixel at nside W<<K (healpy), that tile read
directly (FITS: rows bottom-up; PNG: top-down), and the value there.
Pixels whose order-K tile exists must match exactly; a few on HEALPix
pixel edges may pick the neighbour (allowed if that neighbour's value
matches). Prints a summary; exits 0 if no pixel with a tile differs.
"""
import os
import sys
import numpy as np
import healpy as hp
from astropy.io import fits
from astropy.wcs import WCS
from PIL import Image

root, wfile = sys.argv[1], sys.argv[2]
props = {}
for line in open(os.path.join(root, "properties")):
    if "=" in line and not line.lstrip().startswith("#"):
        k, v = line.split("=", 1)
        props.setdefault(k.strip(), v.strip())
W = int(props.get("hips_tile_width", 512))
fmts = props.get("hips_tile_format", "fits").split()
ext = "fits" if "fits" in fmts else ("png" if "png" in fmts else "jpg")
bits = W.bit_length() - 1

hdr = fits.getheader(wfile)
data = fits.getdata(wfile).astype(np.float64)
K = None
for c in hdr.get("HISTORY", []):
    s = str(c)
    if "HiPS order" in s:
        K = int(s.split("HiPS order")[1].split()[0])
if K is None:
    print("no HiPS order in the window's HISTORY (not a deep window)")
    sys.exit(1)
nside = W << K

w = WCS(hdr)
ny, nx = data.shape
yy, xx = np.mgrid[0:ny, 0:nx]
lon, lat = w.all_pix2world(xx.ravel(), yy.ravel(), 0)
good = np.isfinite(lon) & np.isfinite(lat)
ipix = np.full(lon.shape, -1, np.int64)
ipix[good] = hp.ang2pix(nside, lon[good], lat[good], nest=True, lonlat=True)

tiles = {}
def tile(n):
    if n not in tiles:
        p = os.path.join(root, f"Norder{K}", f"Dir{(n // 10000) * 10000}",
                         f"Npix{n}.{ext}")
        if not os.path.exists(p):
            tiles[n] = None
        elif ext == "fits":
            t = fits.getdata(p).astype(np.float64)
            tiles[n] = np.flipud(t)      # row 0 = top
        else:
            tiles[n] = np.asarray(Image.open(p).convert("L"), np.float64)
    return tiles[n]

def value(p):
    t = tile(int(p >> (2 * bits)))
    if t is None:
        return None
    sub = int(p) & ((1 << (2 * bits)) - 1)
    r = c = 0
    for b in range(bits):
        r |= ((sub >> (2 * b)) & 1) << b
        c |= ((sub >> (2 * b + 1)) & 1) << b
    return t[r, c]

got = data.ravel()
checked = same = edge = bad = 0
for i in np.nonzero(ipix >= 0)[0]:
    v = value(ipix[i])
    if v is None:
        continue
    checked += 1
    g = got[i]
    if (np.isnan(v) and np.isnan(g)) or v == g:
        same += 1
        continue
    # on a pixel edge: one of the neighbours?
    nb = hp.get_all_neighbours(nside, ipix[i], nest=True)
    if any(n >= 0 and (value(n) == g or (value(n) is not None and np.isnan(value(n)) and np.isnan(g))) for n in nb):
        edge += 1
    else:
        bad += 1
        if bad <= 5:
            print(f"pixel {i % nx},{i // nx}: window {g} tile {v}")

print(f"order {K}: {checked} window pixels with an order-{K} tile: "
      f"{same} identical, {edge} on an edge (neighbour's value), {bad} wrong; "
      f"{len([t for t in tiles.values() if t is not None])} tiles used")
sys.exit(0 if bad == 0 and checked > 0 else 1)
