import sys, numpy as np
from astropy.io import fits
out = sys.argv[1]
def ext(name, val, x0):
    h = fits.ImageHDU(np.full((32, 32), val, ">f4"), name=name)
    for k, v in dict(CTYPE1="RA---TAN", CTYPE2="DEC--TAN", CRVAL1=10.0, CRVAL2=20.0,
                     CRPIX1=16.5 - x0, CRPIX2=16.5, CDELT1=-1e-3, CDELT2=1e-3).items():
        h.header[k] = v
    return h
hl = fits.HDUList([fits.PrimaryHDU(), ext("A", 1.0, 0), ext("B", 2.0, 32)])
hl.writeto(f"{out}/mext_pad.fits", overwrite=True)
raw = open(f"{out}/mext_pad.fits", "rb").read()
short = len(raw) - (2880 - 32*32*4 % 2880)           # drop B's padding
open(f"{out}/mext_nopad.fits", "wb").write(raw[:short])
print(len(raw), short)
