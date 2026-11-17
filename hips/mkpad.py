import sys, os, numpy as np
from astropy.io import fits
out, tile = sys.argv[1], sys.argv[2]
P = int(sys.argv[3])
def unpadded(name, data, extra=()):
    h = fits.PrimaryHDU(data)
    for k, v in extra: h.header[k] = v
    h.writeto(f"{out}/{name}_pad.fits", overwrite=True)
    hb = len(h.header.tostring())          # 2880*n
    raw = open(f"{out}/{name}_pad.fits", "rb").read()
    nb = data.nbytes
    open(f"{out}/{name}_nopad.fits", "wb").write(raw[:hb + nb])
    print(name, "padded", len(raw), "unpadded", hb + nb, "page-aligned end:", (hb + nb) % P == 0)
# 1. the real Fermi tile, as is (already unpadded) + padded control
raw = open(tile, "rb").read()
open(f"{out}/fermi_nopad.fits", "wb").write(raw)
open(f"{out}/fermi_pad.fits", "wb").write(raw + b"\0" * (-len(raw) % 2880))
np.save(f"{out}/fermi.npy", fits.getdata(f"{out}/fermi_pad.fits").astype(">f4"))
rng = np.random.default_rng(1)
# 2. 512x512 float
d = rng.normal(size=(512, 512)).astype(">f4"); unpadded("f512", d); np.save(f"{out}/f512.npy", d)
# 3. int16 with BLANK + BSCALE/BZERO
d = rng.integers(-1000, 1000, size=(64, 64)).astype(">i2"); d[5, 7] = -32768
unpadded("i16", d, [("BLANK", -32768), ("BSCALE", 0.5), ("BZERO", 10.0)]); np.save(f"{out}/i16.npy", d)
# 4. file ends exactly on a page boundary, padding would cross into the next page
n = (4 * P - 2880) // 4
d = rng.normal(size=(1, n)).astype(">f4"); unpadded("page", d); np.save(f"{out}/page.npy", d)
