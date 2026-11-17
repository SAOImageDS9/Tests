#!/usr/bin/env python
"""Check a coverage outline against a MOC.

usage: python -I mocref.py <Moc.fits> <outline.ctr> <tol_deg>

<outline.ctr> is a ds9 contour file (contour save aux ... wcs <frame>)
in the MOC's own frame (galactic for COORDSYS G, fk5 for C).

Prints "near N/N far 0 cells M/M" and exits 0 when
  - every outline vertex is within tol of the edge of the coverage:
    a point tol/2 to one side is covered and a point to the other isn't
    is too strict near corners, so instead: within tol of a covered
    cell's boundary (sampled) -- "near"
  - and every cell on the edge of the coverage has an outline vertex
    within one cell size + tol -- "edge cells"
NUNIQ is decoded here (no mocpy), cells are drawn with healpy.
"""
import sys
import numpy as np
import healpy as hp
from astropy.io import fits

moc, ctr, tol = sys.argv[1], sys.argv[2], float(sys.argv[3])

uniq = fits.getdata(moc, 1).field(0).astype(np.int64)
order = (np.floor(np.log2(uniq // 4)) // 2).astype(int)
npix = uniq - 4 * 4 ** order.astype(np.int64)

# every covered cell, at its own order: boundary samples and centre
bnd = []
cent = []
size = []
for o, p in zip(order, npix):
    ns = 2 ** int(o)
    v = hp.boundaries(ns, int(p), step=8, nest=True)       # 3 x 32
    bnd.append(v.T)
    cent.append(hp.pix2vec(ns, int(p), nest=True))
    size.append(np.degrees(hp.nside2resol(ns)))
bnd = np.vstack(bnd)
cent = np.array(cent)
size = np.array(size)

# outline vertices
pts = []
for line in open(ctr):
    f = line.split()
    if len(f) == 2:
        try:
            pts.append((float(f[0]), float(f[1])))
        except ValueError:
            pass
pts = np.array(pts)
th = np.radians(90 - pts[:, 1])
ph = np.radians(pts[:, 0])
pv = np.vstack([np.sin(th) * np.cos(ph), np.sin(th) * np.sin(ph), np.cos(th)]).T

def angdist(a, b):
    return np.degrees(np.arccos(np.clip(a @ b.T, -1, 1)))

near = 0
for chunk in np.array_split(pv, max(1, len(pv) // 500)):
    d = angdist(chunk, bnd).min(axis=1)
    near += int((d <= tol).sum())

# edge cells: a point just outside one of the cell's sides is not
# covered by any cell (any order). Interior cells needn't touch the
# outline. "covered" tests each order present: the point's pixel there.
cellset = {}
for o, p in zip(order, npix):
    cellset.setdefault(int(o), set()).add(int(p))
def covered(v):
    for o, ps in cellset.items():
        if int(hp.vec2pix(2 ** o, *v, nest=True)) in ps:
            return True
    return False

edge = []
for (o, p), c in zip(zip(order, npix), cent):
    ns = 2 ** int(o)
    v = hp.boundaries(ns, int(p), step=4, nest=True).T     # 16 x 3
    c = np.asarray(c)
    out = False
    for q in v:
        r = q + 0.05 * (q - c)                              # 5% outside
        r /= np.linalg.norm(r)
        if not covered(r):
            out = True
            break
    edge.append(out)
edge = np.array(edge)

cells = 0
for c, s, e in zip(cent, size, edge):
    if not e:
        continue
    d = angdist(np.asarray(c)[None, :], pv).min()
    if d <= s + tol:
        cells += 1
nedge = int(edge.sum())

print(f"vertices {len(pts)} near {near}/{len(pts)} edge cells {cells}/{nedge} (of {len(cent)})")
sys.exit(0 if near == len(pts) and cells == nedge and len(pts) else 1)
