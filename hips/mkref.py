#!/usr/bin/env python
"""Write the HEALPix map a HiPS order holds, as a NESTED HEALPix table.

usage: python -I mkref.py <hips root> <order> <out.fits> [allsky]

Independent of ds9's reader: tiles (or Norder<k>/Allsky.fits with
"allsky") are de-interleaved with the measured HiPS convention (rows
from the top -> ix in the even bits, columns -> iy in the odd bits).
Missing tiles are NaN; integer BLANK -> NaN, BSCALE/BZERO applied (by
astropy). Needs numpy, astropy, healpy (the hpxtest conda env).
"""
import os, sys, warnings
import numpy as np
import healpy as hp
from astropy.io import fits
warnings.simplefilter("ignore")

root, K, out = sys.argv[1], int(sys.argv[2]), sys.argv[3]
use_allsky = len(sys.argv) > 4 and sys.argv[4] == "allsky"
props = {}
for line in open(f"{root}/properties"):
    if "=" in line and not line.startswith("#"):
        k, v = line.split("=", 1)
        props.setdefault(k.strip(), v.strip())
frame = {"equatorial": "C", "galactic": "G", "ecliptic": "E"}.get(
    props.get("hips_frame", ""), None)

def interleave(ix, iy, bits):
    r = np.zeros_like(ix)
    for b in range(bits):
        r |= ((ix >> b) & 1) << (2 * b) | ((iy >> b) & 1) << (2 * b + 1)
    return r

def blank_to_nan(hdu):
    d = hdu.data.astype(float)
    if "BLANK" in hdu.header:
        raw = fits.getdata(hdu.fileinfo()["file"].name, do_not_scale_image_data=True)
        d[raw == hdu.header["BLANK"]] = np.nan
    return d[::-1]          # rows from the top

ntile = 12 * 4 ** K
if use_allsky:
    with fits.open(f"{root}/Norder{K}/Allsky.fits") as h:
        A = blank_to_nan(h[0])
    ncol = int(np.sqrt(ntile))
    W = A.shape[1] // ncol
    tiles = {n: A[(n // ncol) * W:(n // ncol + 1) * W, (n % ncol) * W:(n % ncol + 1) * W]
             for n in range(ntile)}
else:
    W = int(props.get("hips_tile_width", 512))
    tiles = {}
    for n in range(ntile):
        p = f"{root}/Norder{K}/Dir{(n // 10000) * 10000}/Npix{n}.fits"
        if os.path.exists(p):
            with fits.open(p) as h:
                tiles[n] = blank_to_nan(h[0])
nside = W << K
rr, cc = np.mgrid[0:W, 0:W]
sub = interleave(rr, cc, W.bit_length() - 1)
m = np.full(12 * nside * nside, np.nan, dtype=np.float32)
for n, t in tiles.items():
    m[n * W * W + sub] = t
hp.write_map(out, m, nest=True, coord=frame, dtype=np.float32, overwrite=True)
print(f"order {K}, tile width {W}, nside {nside}, {len(tiles)} of {ntile} tiles, frame {frame}")
