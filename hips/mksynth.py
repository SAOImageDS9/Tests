#!/usr/bin/env python
"""Write small synthetic HiPS that exercise every FITS tile pixel type.

usage: python -I mksynth.py <outdir>

Makes <outdir>/synth_<type>/ for BITPIX 8, 16, 32, 64 (integer, with
BLANK and BSCALE/BZERO) and -32, -64 (float, with NaN): 16-px tiles at
orders 0 and 1 (nside 16 and 32), equatorial, from random data. Tiles
alternate padded/unpadded, a few tiles are missing, and order 1 also
has a reduced (8-px) Allsky.fits.

<outdir>/synth_reduced/ has order-0 tiles plus only a reduced Allsky at
order 1, so order=1 must come from the Allsky.

Tile layout follows the HiPS convention measured on real data (see
TODO_HIPS.md): rows from the top -> ix (even bits), columns -> iy.
"""
import os, sys
import numpy as np
from astropy.io import fits

out = sys.argv[1]
W, ORDERS, RW = 16, (0, 1), 8          # tile width, orders, Allsky width
rng = np.random.default_rng(42)
MISSING = {0: {5}, 1: {3, 17, 40}}      # absent tiles per order

TYPES = {                               # name: (bitpix, dtype, blank, bscale, bzero)
    "u8": (8, np.uint8, 255, 2.0, -100.0),
    "i16": (16, np.int16, -32768, 0.5, 10.0),
    "i32": (32, np.int32, -2147483648, 1e-3, 0.0),
    "i64": (64, np.int64, -(2**63), 1.0, 5.0),
    "f32": (-32, np.float32, None, 1.0, 0.0),
    "f64": (-64, np.float64, None, 1.0, 0.0),
}

def interleave(ix, iy, bits):
    r = np.zeros_like(ix)
    for b in range(bits):
        r |= ((ix >> b) & 1) << (2 * b) | ((iy >> b) & 1) << (2 * b + 1)
    return r

def raw_values(dt, n):
    if np.issubdtype(dt, np.integer):
        info = np.iinfo(dt)
        lo, hi = max(info.min + 1, -30000), min(info.max - 1, 30000)
        v = rng.integers(lo, hi, size=n).astype(dt)
    else:
        v = rng.normal(size=n).astype(dt)
    return v

def write_image(path, data, bitpix, blank, bscale, bzero, pad):
    # header and raw big-endian values by hand, so nothing gets rescaled
    hd = fits.Header()
    hd["SIMPLE"] = True
    hd["BITPIX"] = bitpix
    hd["NAXIS"] = 2
    hd["NAXIS1"] = data.shape[1]
    hd["NAXIS2"] = data.shape[0]
    if blank is not None:
        hd["BLANK"] = blank
    if bscale != 1.0 or bzero != 0.0:
        hd["BSCALE"] = bscale
        hd["BZERO"] = bzero
    raw = hd.tostring().encode("ascii")
    body = data.astype(data.dtype.newbyteorder(">")).tobytes()
    if pad:
        body += b"\0" * (-len(body) % 2880)
    with open(path, "wb") as f:
        f.write(raw + body)

def properties(root, bitpix, order):
    with open(f"{root}/properties", "w") as f:
        f.write("# synthetic HiPS for ds9 tests\n")
        f.write(f"creator_did          = ivo://ds9.test/P/synth/{os.path.basename(root)}\n")
        f.write(f"obs_title            = synthetic {os.path.basename(root)}\n")
        f.write("dataproduct_type     = image\nhips_version         = 1.4\n")
        f.write("hips_release_date    = 2026-11-15T00:00Z\nhips_status          = private master unclonable\n")
        f.write(f"hips_tile_format     = fits\nhips_order           = {order}\nhips_frame           = equatorial\n")
        f.write(f"hips_tile_width      = {W}\nhips_pixel_bitpix    = {bitpix}\n")

def tiles_for(maparr, order, w):
    """split a NESTED map (raw values) into tiles, rows from the top"""
    rr, cc = np.mgrid[0:w, 0:w]
    sub = interleave(rr, cc, w.bit_length() - 1)
    return {n: maparr[n * w * w + sub] for n in range(12 * 4 ** order)}

def allsky(tiles, order, w, dt, fill):
    ncol = int(np.sqrt(12 * 4 ** order))
    nrow = -(-len(tiles) // ncol)
    A = np.full((nrow * w, ncol * w), fill, dtype=dt)
    for n, t in tiles.items():
        r, c = divmod(n, ncol)
        A[r * w:(r + 1) * w, c * w:(c + 1) * w] = t
    return A[::-1]                      # FITS rows bottom-up

def make(name, bitpix, dt, blank, bscale, bzero, orders, allsky_orders, reduced_only=()):
    root = f"{out}/synth_{name}"
    os.makedirs(root, exist_ok=True)
    properties(root, bitpix, max(orders + tuple(reduced_only)))
    for k in orders + tuple(reduced_only):
        nside = W << k
        m = raw_values(dt, 12 * nside * nside)
        if blank is not None:
            m[rng.choice(m.size, m.size // 50, replace=False)] = blank
        elif np.issubdtype(dt, np.floating):
            m[rng.choice(m.size, m.size // 50, replace=False)] = np.nan
        tiles = tiles_for(m, k, W)
        if k in orders:
            os.makedirs(f"{root}/Norder{k}/Dir0", exist_ok=True)
            for n, t in tiles.items():
                if n in MISSING.get(k, ()):
                    continue
                write_image(f"{root}/Norder{k}/Dir0/Npix{n}.fits", t[::-1].copy(),
                            bitpix, blank, bscale, bzero, pad=bool(n % 2))
        if k in allsky_orders or k in reduced_only:
            # reduced Allsky: every other pixel of each tile, so its own
            # map is the nside (RW << k) NESTED map those pixels make
            red = {n: t[::W // RW, ::W // RW] for n, t in tiles.items()}
            fill = blank if blank is not None else np.nan
            os.makedirs(f"{root}/Norder{k}", exist_ok=True)
            write_image(f"{root}/Norder{k}/Allsky.fits", allsky(red, k, RW, dt, fill),
                        bitpix, blank, bscale, bzero, pad=True)
    print("wrote", root)

for name, (bp, dt, blank, bs, bz) in TYPES.items():
    make(name, bp, dt, blank, bs, bz, ORDERS, allsky_orders=(1,))
make("reduced", 16, np.int16, -32768, 0.5, 10.0, (0,), allsky_orders=(), reduced_only=(1,))
