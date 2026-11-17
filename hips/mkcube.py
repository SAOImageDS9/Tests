#!/usr/bin/env python
"""Write a small, complete HiPS cube.

usage: python -I mkcube.py <outdir>

<outdir>/cube: dataproduct_type cube, 5 frames, 16-px FITS tiles at
orders 0, 1 and 2 (every tile of every frame), equatorial, first frame
2, third axis crval3 = 1000 m/s at crpix3 = 1, cdelt3 = 250 m/s. Frame
n's tiles are NpixN_n (frame 0 without a suffix). The value of the
pixel at row r (from the top), column c of tile N, order K, frame n is
    1000*n + 100*K + (N % 10) + (r*16 + c) / 1000
so any value says which frame, order and tile it came from.
"""
import os
import sys
import numpy as np
from astropy.io import fits

out = os.path.join(sys.argv[1], "cube")
W, ORDERS, DEPTH = 16, (0, 1, 2), 5
os.makedirs(out, exist_ok=True)
with open(os.path.join(out, "properties"), "w") as f:
    f.write("""creator_did = ivo://test/cube
obs_title = test cube
dataproduct_type = cube
hips_version = 1.4
hips_frame = equatorial
hips_order = 2
hips_order_min = 0
hips_tile_width = 16
hips_tile_format = fits
hips_cube_depth = 5
hips_cube_firstframe = 2
data_cube_crpix3 = 1
data_cube_crval3 = 1000
data_cube_cdelt3 = 250
data_cube_bunit3 = m/s
""")

rc = (np.arange(W)[:, None] * W + np.arange(W)[None, :]) / 1000.0
for k in ORDERS:
    for n in range(12 * 4 ** k):
        d = os.path.join(out, f"Norder{k}", f"Dir{(n // 10000) * 10000}")
        os.makedirs(d, exist_ok=True)
        for fr in range(DEPTH):
            v = (1000 * fr + 100 * k + n % 10 + rc).astype(np.float32)
            sfx = f"_{fr}" if fr else ""
            # FITS rows bottom-up: row 0 of the data is the tile's bottom
            fits.PrimaryHDU(np.flipud(v)).writeto(
                os.path.join(d, f"Npix{n}{sfx}.fits"), overwrite=True)
