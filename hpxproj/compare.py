# Compare an image ds9 resampled from a HEALPix table (saved with
# "save fits") against an independent reprojection of the same table
# with reproject.reproject_from_healpix(order='nearest-neighbor') onto
# the exact same header.
#
# usage: python compare.py HEALPIXFILE SYSTEM IMAGE.fits ...
#   SYSTEM is the frame ds9 was told to use (galactic, icrs, ecliptic),
#   or "header" to take it from COORDSYS.
#
# Pass criteria, per image:
#   - every pixel where ds9 has a value equals the reference exactly
#   - ds9 has no value where the reference is blank
# (reproject does not blank pixels outside the AIT/MOL/SFL/PAR
# boundaries, so the reverse is not checked here; see boundary.py.)
#
# Handles full-sky RING/NESTED maps, partial maps (INDXSCHM=EXPLICIT)
# and NUNIQ MOCs with no data column (covered = 1, uncovered = 0, which
# is how ds9 displays them).
#
# Exit status 0 if every image passes, 1 otherwise.
# Needs numpy, astropy, healpy, reproject.

import sys
import warnings

import numpy as np
import healpy as hp
from astropy.io import fits
from astropy.wcs import WCS
from reproject import reproject_from_healpix

warnings.simplefilter('ignore')

COORDSYS = {'G': 'galactic', 'C': 'icrs', 'Q': 'icrs', 'E': 'barycentrictrueecliptic'}
SYSTEMS = {'galactic': 'galactic', 'icrs': 'icrs', 'fk5': 'icrs',
           'equatorial': 'icrs', 'ecliptic': 'barycentrictrueecliptic'}


def load_map(path):
    """Return (map, nested, coordsys letter) for a HEALPix table."""
    with fits.open(path) as hl:
        hdu = hl[1]
        hd = hdu.header
        ordering = hd.get('ORDERING', 'RING').strip().upper()
        coordsys = hd.get('COORDSYS', ' ').strip()[:1].upper()

        if ordering == 'NUNIQ':
            uniq = np.asarray(hdu.data.field(0), dtype=np.int64)
            order = (np.floor(np.log2(uniq // 4) / 2)).astype(int)
            ipix = uniq - 4 * 4**order.astype(np.int64)
            maxorder = int(hd.get('MOCORDER', order.max()))
            nside = 2**maxorder
            m = np.zeros(12 * nside * nside, dtype=np.float64)
            for oo in np.unique(order):
                sel = ipix[order == oo]
                shift = 4**(maxorder - oo)
                start = sel * shift
                idx = (start[:, None] + np.arange(shift)[None, :]).ravel()
                m[idx] = 1
            return m, True, coordsys

        nested = ordering.startswith('N')
        if hd.get('INDXSCHM', '').strip().upper() == 'EXPLICIT':
            nside = int(hd['NSIDE'])
            m = np.full(12 * nside * nside, np.nan)
            m[np.asarray(hdu.data.field(0), dtype=np.int64)] = hdu.data.field(1)
            return m, nested, coordsys

    m = hp.read_map(path, field=0, nest=nested, dtype=np.float64)
    m[m == hp.UNSEEN] = np.nan
    return m, nested, coordsys


def main():
    if len(sys.argv) < 4:
        print('usage: compare.py HEALPIXFILE SYSTEM IMAGE.fits ...')
        return 2

    path, system, images = sys.argv[1], sys.argv[2], sys.argv[3:]
    m, nested, coordsys = load_map(path)
    frame = COORDSYS.get(coordsys, 'galactic') if system == 'header' else SYSTEMS[system]

    ok = True
    for img in images:
        hd = fits.getheader(img)
        d = fits.getdata(img).astype(np.float64)
        ref, _ = reproject_from_healpix((m, frame), WCS(hd), shape_out=d.shape,
                                        nested=nested, order='nearest-neighbor')
        fd, fr = np.isfinite(d), np.isfinite(ref)
        both = fd & fr
        neq = (both & (d != ref)).sum()
        ds9only = (fd & ~fr).sum()
        good = neq == 0 and ds9only == 0 and both.sum() > 0
        ok &= good
        print(f"  {img.split('/')[-1]}: {hd['CTYPE1']} {d.shape[1]}x{d.shape[0]} "
              f"compared={both.sum()} differ={neq} ds9-only={ds9only} "
              f"{'PASSED' if good else 'FAILED'}")
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
