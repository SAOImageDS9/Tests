#!/usr/bin/env python
"""Check the HiPS tile layout conventions fitsy/hips.C relies on.

usage: python -I tileorder.py <hips root> [order]

1. In-tile pixel order: for each of the 8 flips/rotations of a tile,
   assemble the NESTED HEALPix map and score how well values match across
   tile seams (pairs of HEALPix neighbours in different tiles). The
   correct orientation has by far the lowest seam mismatch.
2. Hierarchy: an order K-1 tile is the 2x2 mean of its 4 children.
3. Allsky.fits layout: int(sqrt(ntiles)) tiles per row, from top-left.
4. PNG tiles are stored top-down (vertical flip of FITS).

Needs numpy, astropy, healpy, pillow (the hpxtest conda env).
"""
import sys
import numpy as np
import healpy as hp
from astropy.io import fits

root = sys.argv[1]
K = int(sys.argv[2]) if len(sys.argv) > 2 else 3


def path(k, n, ext):
    return f"{root}/Norder{k}/Dir{(n // 10000) * 10000}/Npix{n}.{ext}"


def tile(k, n):
    # rows from the top: FITS stores bottom-up
    return fits.getdata(path(k, n, "fits")).astype(float)[::-1]


def interleave(ix, iy, bits):
    r = np.zeros_like(ix)
    for b in range(bits):
        r |= ((ix >> b) & 1) << (2 * b) | ((iy >> b) & 1) << (2 * b + 1)
    return r


t0 = tile(K, 0)
W = t0.shape[0]
S = W.bit_length() - 1
nside = W << K
rr, cc = np.mgrid[0:W, 0:W]          # rr counted from the top
cands = {
    "ix=r,iy=c (expected)": (rr, cc), "ix=c,iy=r": (cc, rr),
    "ix=W-1-r,iy=c": (W - 1 - rr, cc), "ix=r,iy=W-1-c": (rr, W - 1 - cc),
    "ix=W-1-r,iy=W-1-c": (W - 1 - rr, W - 1 - cc),
    "ix=W-1-c,iy=r": (W - 1 - cc, rr), "ix=c,iy=W-1-r": (cc, W - 1 - rr),
    "ix=W-1-c,iy=W-1-r": (W - 1 - cc, W - 1 - rr)}
tiles = [tile(K, n) for n in range(12 * 4 ** K)]
nb = hp.get_all_neighbours(nside, np.arange(12 * nside * nside), nest=True)
pix = np.broadcast_to(np.arange(nb.shape[1]), nb.shape)
seam = (nb >= 0) & (nb // (W * W) != pix // (W * W))
print(f"order {K}, tile width {W}, nside {nside}")
for name, (ix, iy) in cands.items():
    sub = interleave(ix, iy, S)
    m = np.empty(12 * nside * nside)
    for n, t in enumerate(tiles):
        m[n * W * W + sub] = t
    d = np.abs(m[pix[seam]] - m[nb[seam]])
    print(f"  {name:22s} seam |diff| mean {np.nanmean(d):.3e}")

if K > 0:
    p = 12
    big = np.zeros((2 * W, 2 * W))
    for q in range(4):              # q bit0 -> ix (row half), bit1 -> iy
        r0, c0 = (q & 1) * W, (q >> 1) * W
        big[r0:r0 + W, c0:c0 + W] = tile(K, 4 * p + q)
    mean = big.reshape(W, 2, W, 2).mean(axis=(1, 3))
    print("hierarchy max|parent-mean(children)|/std:",
          np.nanmax(np.abs(tile(K - 1, p) - mean)) / np.nanstd(mean))

if K <= 3:
    A = fits.getdata(f"{root}/Norder{K}/Allsky.fits").astype(float)[::-1]
    ncol = int(np.sqrt(12 * 4 ** K))
    tw = A.shape[1] // ncol
    worst = 0
    for n in range(12 * 4 ** K):
        r, c = divmod(n, ncol)
        a = A[r * tw:(r + 1) * tw, c * tw:(c + 1) * tw]
        t = tiles[n].reshape(tw, W // tw, tw, W // tw).mean(axis=(1, 3))
        worst = max(worst, np.nanmax(np.abs(a - t)))
    print(f"Allsky: {ncol} tiles/row, {tw} px tiles, max diff {worst:.3e}")

try:
    from PIL import Image
    im = np.asarray(Image.open(path(K, 300, "png")))[..., :3].mean(-1)
    t = tiles[300]
    print("png corr as stored %.4f, flipped %.4f" % (
        np.corrcoef(im.ravel(), t.ravel())[0, 1],
        np.corrcoef(im[::-1].ravel(), t.ravel())[0, 1]))
except (ImportError, FileNotFoundError) as e:
    print("png check skipped:", e)
