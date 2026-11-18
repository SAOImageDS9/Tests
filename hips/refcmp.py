#!/usr/bin/env python
"""Compare a projected HiPS image saved by ds9 with an independent one.

usage: python -I refcmp.py <ds9 image.fits> <reference map.fits> [ring]

<reference map.fits> is the NESTED HEALPix table mkref.py writes from
the HiPS tiles (not through ds9's reader), or with ring, any RING
HEALPix table (a plain HEALPix file ds9 loaded). It is projected onto the WCS
of <ds9 image.fits> with reproject_from_healpix, nearest-neighbour as
ds9 samples, converting from the map's frame (COORDSYS) to the image's.
Prints "<agree> <nanagree> <n>": the percentages of pixels with the
same value and of pixels that are NaN in both or neither, and the
number of pixels. Pixels with no sky position (outside an all-sky
projection) are NaN in the reference. Only pixels whose centre falls
exactly on a HEALPix pixel edge should differ.
"""
import sys
import warnings
import numpy as np
from astropy.io import fits
from astropy.wcs import WCS
from reproject import reproject_from_healpix
warnings.simplefilter("ignore")

img, hdr = fits.getdata(sys.argv[1], header=True)
img = img.astype(np.float64)
w = WCS(hdr).celestial
nested = not (len(sys.argv) > 3 and sys.argv[3] == "ring")
ref, _ = reproject_from_healpix(sys.argv[2], w, shape_out=img.shape,
                                order="nearest-neighbor", nested=nested)
# outside an all-sky projection (no sky position) reproject still fills
# in a value (seen with MOL, AIT, CAR); there is nothing there
yy, xx = np.mgrid[0:img.shape[0], 0:img.shape[1]]
lon, lat = w.pixel_to_world_values(xx, yy)
ref[~(np.isfinite(lon) & np.isfinite(lat))] = np.nan
na, nb = np.isnan(img), np.isnan(ref)
both = ~na & ~nb
# float32 in ds9 (BSCALE'd integers, Allsky floats): same to 1e-6
same = both & np.isclose(img, ref, rtol=1e-6, atol=1e-6)
n = img.size
print(f"{100.*(same.sum() + (na & nb).sum())/n:.2f} "
      f"{100.*(na == nb).sum()/n:.2f} {n}")
