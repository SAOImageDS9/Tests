#!/usr/bin/env python
"""Check fitsy/hpxnest.h against healpy.

usage: python -I nesttest.py <points.txt>    (from nesttest.C)

ang2pix: the pixel must equal healpy's (nest=True, lonlat=True). A point
exactly on a pixel boundary may legitimately go to either neighbour, so
a mismatch counts only if healpy's own pixel boundaries don't pass within
1e-9 deg of the point (checked by asking healpy for the pixel of points
nudged around it). pix2ang: the centre must match healpy's to 1e-9 deg
(scaled for huge nside, where doubles hold ~1e-12 rad).
Prints a summary and exits 0 if everything agrees.
"""
import sys
import numpy as np
import healpy as hp

a, c = [], []
for line in open(sys.argv[1]):
    f = line.split()
    if f[0] == "a":
        a.append((int(f[1]), float(f[2]), float(f[3]), int(f[4])))
    else:
        c.append((int(f[1]), int(f[2]), float(f[3]), float(f[4])))

bad = 0
edge = 0
for nside in sorted({x[0] for x in a}):
    pts = [x for x in a if x[0] == nside]
    lon = np.array([p[1] for p in pts])
    lat = np.array([p[2] for p in pts])
    mine = np.array([p[3] for p in pts])
    ref = hp.ang2pix(nside, lon, lat, nest=True, lonlat=True)
    for i in np.nonzero(mine != ref)[0]:
        # on a boundary? healpy's pixels around the point include mine
        d = 1e-9
        near = set()
        for dl in (-d, 0, d):
            for db in (-d, 0, d):
                bb = min(90, max(-90, lat[i] + db))
                near.add(int(hp.ang2pix(nside, lon[i] + dl, bb, nest=True,
                                        lonlat=True)))
        if mine[i] in near:
            edge += 1
        else:
            bad += 1
            if bad <= 10:
                print(f"ang2pix nside {nside} lon {lon[i]!r} lat {lat[i]!r}:"
                      f" mine {mine[i]} healpy {ref[i]}")

cbad = 0
worst = 0.0
for nside, pix, lon, lat in c:
    rl, rb = hp.pix2ang(nside, pix, nest=True, lonlat=True)
    dl = abs(((lon - rl) + 180) % 360 - 180) * np.cos(np.radians(lat))
    d = max(dl, abs(lat - rb))
    worst = max(worst, d)
    if d > 1e-9:
        cbad += 1
        if cbad <= 10:
            print(f"pix2ang nside {nside} pix {pix}: mine {lon},{lat} "
                  f"healpy {rl},{rb}")

print(f"ang2pix: {len(a)} points, {bad} wrong, {edge} on a boundary; "
      f"pix2ang: {len(c)} pixels, {cbad} wrong, worst {worst:.2g} deg")
sys.exit(0 if bad == 0 and cbad == 0 else 1)
