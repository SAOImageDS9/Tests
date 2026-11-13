# Compare an image ds9 resampled from a HEALPix table (saved with
# "save fits") against an independent reprojection of the same table
# with reproject.reproject_from_healpix(order='nearest-neighbor') onto
# the exact same header.
#
# usage: python compare.py HEALPIXFILE SYSTEM IMAGE.fits ...
#   SYSTEM is the sky system ds9 was told to use (galactic, equatorial,
#   ecliptic, unknown), or "header" to take it from COORDSYS (absent =
#   unknown).
#
# Pass criteria, per image:
#   - ds9 kept the sky system: CTYPE1 starts GLON / RA-- / ELON / XLON
#   - every pixel where ds9 has a value equals the reference exactly
#   - ds9 has no value where the reference is blank
# (reproject does not blank pixels outside the AIT/MOL/SFL/PAR
# boundaries, so the reverse is not checked here; see boundary.py.)
#
# Handles full-sky RING/NESTED maps (binary or ASCII table), partial
# maps (INDXSCHM=EXPLICIT) and NUNIQ MOCs with no data column (covered =
# 1, uncovered = 0, which is how ds9 displays them). ds9 never changes
# the sky system, so the reference is made in the image's own frame; an
# XLON/XLAT (unknown) image is relabelled galactic for reproject.
#
# Exit status 0 if every image passes, 1 otherwise.
# Needs numpy, astropy, healpy, reproject.

import sys
import warnings

import numpy as np
import healpy as hp
from astropy.io import fits
from astropy.wcs import WCS
from astropy.wcs.utils import wcs_to_celestial_frame
from reproject import reproject_from_healpix

warnings.simplefilter('ignore')

# expected CTYPE1 prefix, by COORDSYS letter and by SYSTEM name
COORDSYS = {'G': 'GLON', 'C': 'RA--', 'Q': 'RA--', 'E': 'ELON'}
SYSTEMS = {'galactic': 'GLON', 'equatorial': 'RA--', 'ecliptic': 'ELON',
           'unknown': 'XLON'}


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

        # implicit full-sky map; binary or ASCII table, any repeat count
        m = np.asarray(hdu.data.field(0), dtype=np.float64).ravel()
    m[m == hp.UNSEEN] = np.nan
    return m, nested, coordsys


def main():
    if len(sys.argv) < 4:
        print('usage: compare.py HEALPIXFILE SYSTEM IMAGE.fits ...')
        return 2

    path, system, images = sys.argv[1], sys.argv[2], sys.argv[3:]
    m, nested, coordsys = load_map(path)
    prefix = COORDSYS.get(coordsys, 'XLON') if system == 'header' else SYSTEMS[system]

    ok = True
    for img in images:
        hd = fits.getheader(img)
        d = fits.getdata(img).astype(np.float64)
        sysok = hd['CTYPE1'][:4] == prefix
        if hd['CTYPE1'].startswith('XLON'):
            hd['CTYPE1'] = 'GLON' + hd['CTYPE1'][4:]
            hd['CTYPE2'] = 'GLAT' + hd['CTYPE2'][4:]
        w = WCS(hd)
        ref, _ = reproject_from_healpix((m, wcs_to_celestial_frame(w)), w,
                                        shape_out=d.shape, nested=nested,
                                        order='nearest-neighbor')
        fd, fr = np.isfinite(d), np.isfinite(ref)
        both = fd & fr
        neq = (both & (d != ref)).sum()
        ds9only = (fd & ~fr).sum()
        good = sysok and neq == 0 and ds9only == 0 and both.sum() > 0
        ok &= good
        ctype = fits.getheader(img)['CTYPE1']
        print(f"  {img.split('/')[-1]}: {ctype} {d.shape[1]}x{d.shape[0]} "
              f"compared={both.sum()} differ={neq} ds9-only={ds9only}"
              f"{'' if sysok else f' (expected {prefix})'} "
              f"{'PASSED' if good else 'FAILED'}")
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
