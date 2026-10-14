# Check that an image ds9 resampled from a full-sky HEALPix map is blank
# (NaN) exactly outside the projection's boundary, and has a value
# everywhere inside it.
#
# usage: python boundary.py IMAGE.fits ...
#
# The boundary is computed analytically in the projection plane from
# CRPIX/CDELT (degrees, default PV values, CRVAL2 = 0). A pixel is only
# classified when its centre and all four corners agree on inside or
# outside, so pixels the boundary passes through are skipped.
#
# Exit status 0 if every image passes, 1 otherwise.
# Needs numpy, astropy.

import sys

import numpy as np
from astropy.io import fits

R = 180 / np.pi


def inside(code, X, Y):
    """True where projection-plane point (X, Y) in degrees is on the sky."""
    with np.errstate(invalid='ignore'):
        if code in ('AIT', 'MOL'):
            return (X / (2 * np.sqrt(2) * R))**2 + (Y / (np.sqrt(2) * R))**2 <= 1
        if code == 'CAR':
            return (np.abs(X) <= 180) & (np.abs(Y) <= 90)
        if code == 'CEA':
            return (np.abs(X) <= 180) & (np.abs(Y) <= R)
        if code in ('SFL', 'GLS'):
            return (np.abs(Y) <= 90) & (np.abs(X) <= 180 * np.cos(np.radians(Y)))
        if code == 'PAR':
            theta = 3 * np.arcsin(np.clip(Y / 180, -1, 1))
            return (np.abs(Y) <= 90) & (np.abs(X) <= 180 * (2 * np.cos(2 * theta / 3) - 1))
    raise ValueError(f'no boundary for projection {code}')


def main():
    if len(sys.argv) < 2:
        print('usage: boundary.py IMAGE.fits ...')
        return 2

    ok = True
    for img in sys.argv[1:]:
        hd = fits.getheader(img)
        d = fits.getdata(img)
        code = hd['CTYPE1'][5:8]
        ny, nx = d.shape
        y, x = np.mgrid[1:ny + 1, 1:nx + 1].astype(np.float64)

        def plane(dx, dy):
            return ((x + dx - hd['CRPIX1']) * hd['CDELT1'],
                    (y + dy - hd['CRPIX2']) * hd['CDELT2'])

        tests = [inside(code, *plane(dx, dy))
                 for dx, dy in ((0, 0), (-.5, -.5), (-.5, .5), (.5, -.5), (.5, .5))]
        allin = np.logical_and.reduce(tests)
        allout = ~np.logical_or.reduce(tests)

        fin = np.isfinite(d)
        blank_in = (allin & ~fin).sum()
        finite_out = (allout & fin).sum()
        good = blank_in == 0 and finite_out == 0
        ok &= good
        print(f"  {img.split('/')[-1]}: {code} inside={allin.sum()} outside={allout.sum()} "
              f"blank-inside={blank_in} finite-outside={finite_out} "
              f"{'PASSED' if good else 'FAILED'}")
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
