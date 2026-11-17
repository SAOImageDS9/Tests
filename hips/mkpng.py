#!/usr/bin/env python
"""Write small HiPS with the same pixels as FITS, PNG and JPEG tiles.

usage: python -I mkpng.py <outdir>

Random 0-255 levels in 16-px tiles at orders 0 and 1 (tile 5 of order 0
and tiles 3, 17, 40 of order 1 missing), plus an order-1 Allsky (full
size) and some blank pixels:
  <outdir>/pfits   BITPIX -32, blank pixels NaN        (the reference)
  <outdir>/ppng    PNG, grey + alpha (blank: alpha 0)  == pfits exactly
  <outdir>/pjpg    JPEG, grey, quality 95 (blank: 0)   ~= pfits
  <outdir>/prgb    PNG, RGB + alpha, random colours
  <outdir>/prgbl   BITPIX -32: the luminance of prgb   == prgb
  <outdir>/pcol    prgb marked dataproduct_subtype = color: an RGB HiPS
  <outdir>/pcr, pcg, pcb   BITPIX -32: its red, green, blue levels
hips_tile_format lists only the one format in each, so the reader has
no choice. PNG/JPEG rows are top-down, FITS rows bottom-up.
"""
import os
import sys
import numpy as np
from astropy.io import fits
from PIL import Image

out = sys.argv[1]
W, ORDERS = 16, (0, 1)
MISSING = {0: {5}, 1: {3, 17, 40}}
rng = np.random.default_rng(7)


def props(d, fmt, title, extra=""):
    with open(os.path.join(d, "properties"), "w") as f:
        f.write(extra + f"""creator_did = ivo://test/{title}
obs_title = {title}
dataproduct_type = image
hips_version = 1.4
hips_frame = equatorial
hips_order = 1
hips_order_min = 0
hips_tile_width = {W}
hips_tile_format = {fmt}
hips_pixel_cut = 10 200
""")


def tilepath(d, k, n, ext):
    p = os.path.join(d, f"Norder{k}", f"Dir{(n // 10000) * 10000}")
    os.makedirs(p, exist_ok=True)
    return os.path.join(p, f"Npix{n}.{ext}")


grey = {}   # (k, n) -> uint8 tile, top row first
blank = {}  # (k, n) -> bool mask
rgb = {}
for k in ORDERS:
    for n in range(12 * 4 ** k):
        if n in MISSING[k]:
            continue
        grey[k, n] = rng.integers(0, 256, (W, W), dtype=np.uint8)
        m = np.zeros((W, W), bool)
        m[rng.integers(0, W, 3), rng.integers(0, W, 3)] = True
        blank[k, n] = m
        rgb[k, n] = rng.integers(0, 256, (W, W, 3), dtype=np.uint8)

for name in ("pfits", "ppng", "pjpg", "prgb", "prgbl", "pcol", "pcr", "pcg", "pcb"):
    os.makedirs(os.path.join(out, name), exist_ok=True)
props(os.path.join(out, "pfits"), "fits", "pfits")
props(os.path.join(out, "ppng"), "png", "ppng")
props(os.path.join(out, "pjpg"), "jpeg", "pjpg")
props(os.path.join(out, "prgb"), "png", "prgb")
props(os.path.join(out, "prgbl"), "fits", "prgbl")
props(os.path.join(out, "pcol"), "png", "pcol", "dataproduct_subtype = color\n")
for name in ("pcr", "pcg", "pcb"):
    props(os.path.join(out, name), "fits", name)


def lum(c):
    c = c.astype(np.float32)
    v = np.float32(.299) * c[..., 0] + np.float32(.587) * c[..., 1] \
        + np.float32(.114) * c[..., 2]
    same = (c[..., 0] == c[..., 1]) & (c[..., 1] == c[..., 2])
    return np.where(same, c[..., 0], v).astype(np.float32)


def fitsfile(fn, a):
    fits.PrimaryHDU(np.flipud(a).astype(np.float32)).writeto(fn, overwrite=True)


for (k, n), g in grey.items():
    m = blank[k, n]
    f = g.astype(np.float32)
    f[m] = np.nan
    fitsfile(tilepath(os.path.join(out, "pfits"), k, n, "fits"), f)
    a = np.where(m, 0, 255).astype(np.uint8)
    Image.fromarray(np.dstack([g, a]), "LA").save(
        tilepath(os.path.join(out, "ppng"), k, n, "png"))
    Image.fromarray(np.where(m, 0, g).astype(np.uint8), "L").save(
        tilepath(os.path.join(out, "pjpg"), k, n, "jpg"), quality=95)
    c = rgb[k, n]
    Image.fromarray(np.dstack([c, a]), "RGBA").save(
        tilepath(os.path.join(out, "prgb"), k, n, "png"))
    l = lum(c)
    l[m] = np.nan
    fitsfile(tilepath(os.path.join(out, "prgbl"), k, n, "fits"), l)
    Image.fromarray(np.dstack([c, a]), "RGBA").save(
        tilepath(os.path.join(out, "pcol"), k, n, "png"))
    for i, name in enumerate(("pcr", "pcg", "pcb")):
        ch = c[..., i].astype(np.float32)
        ch[m] = np.nan
        fitsfile(tilepath(os.path.join(out, name), k, n, "fits"), ch)

# order-1 Allsky, full size: 48 tiles, 6 a row (int(sqrt(48)))
k, ncol = 1, 6
nrow = 48 // ncol
ag = np.zeros((nrow * W, ncol * W), np.float32)
ag[:] = np.nan
ap = np.zeros((nrow * W, ncol * W, 2), np.uint8)
for (kk, n), g in grey.items():
    if kk != k:
        continue
    r, c = (n // ncol) * W, (n % ncol) * W
    f = g.astype(np.float32)
    f[blank[kk, n]] = np.nan
    ag[r:r + W, c:c + W] = f
    ap[r:r + W, c:c + W, 0] = g
    ap[r:r + W, c:c + W, 1] = np.where(blank[kk, n], 0, 255)
fitsfile(os.path.join(out, "pfits", "Norder1", "Allsky.fits"), ag)
Image.fromarray(ap, "LA").save(os.path.join(out, "ppng", "Norder1", "Allsky.png"))
