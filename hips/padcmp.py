import sys, glob, os, numpy as np
from astropy.io import fits
D = sys.argv[1]; bad = 0; n = 0
for f in sorted(glob.glob(f"{D}/out/*.fits")):
    name = os.path.basename(f).split("_")[0]
    ref = np.load(f"{D}/pad/{name}.npy")
    with fits.open(f, do_not_scale_image_data=True) as h:
        got = h[0].data; hd = h[0].header
    # ds9 saves a 1xN image with NAXIS = 1, so compare without unit axes
    ok = got.size == ref.size and np.array_equal(got.reshape(ref.shape).astype(ref.dtype), ref, equal_nan=True)
    if name == "i16":
        ok = ok and hd.get("BLANK") == -32768 and hd.get("BSCALE") == 0.5 and hd.get("BZERO") == 10.0
    n += 1; bad += not ok
    if not ok: print("MISMATCH", os.path.basename(f))
print(f"{n} saved images compared, {bad} mismatches")
r = np.load(f"{D}/pad/i16.npy"); print("i16 expected (1,1) =", r[0,0]*0.5+10, " (8,6) raw =", r[5,7], "-> blank")
print("fermi expected (8,6) =", np.load(f"{D}/pad/fermi.npy")[5,7])
