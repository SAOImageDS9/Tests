import sys, glob, os, numpy as np
from astropy.io import fits
from PIL import Image
import warnings; warnings.simplefilter("ignore")
for root in sys.argv[1:]:
    print("=====", root)
    fl = sorted(glob.glob(f"{root}/Norder*/Dir*/*.fits"))
    if fl:
        f = fl[-1]; h = fits.getheader(f)
        cards = {k: h[k] for k in ("BITPIX","NAXIS1","NAXIS2","BSCALE","BZERO","BLANK","CTYPE1","ORDER","NPIX") if k in h}
        sizes = {os.path.getsize(x) % 2880 == 0 for x in fl}
        d = fits.getdata(f, do_not_scale_image_data=True)
        nblank = int(np.sum(d == h["BLANK"])) if "BLANK" in h else int(np.isnan(d).sum()) if d.dtype.kind == "f" else 0
        print(f"  fits tiles {len(fl)}; header {cards}; padded {sizes}; {os.path.basename(f)} blanks {nblank}/{d.size}")
    for a in sorted(glob.glob(f"{root}/Norder*/Allsky.*")):
        if a.endswith(".fits"):
            h = fits.getheader(a); shape = (h["NAXIS1"], h["NAXIS2"]); extra = {k: h[k] for k in ("BITPIX","BLANK","BSCALE","BZERO") if k in h}
        else:
            im = Image.open(a); shape = im.size; extra = im.mode
        k = int(a.split("Norder")[1][0]); ncol = int(np.sqrt(12 * 4**k))
        print(f"  {a[len(root)+1:]}: {shape} -> {ncol} tiles/row, tile {shape[0]//ncol}px {extra}")
    pl = sorted(glob.glob(f"{root}/Norder*/Dir*/*.png"))
    if pl:
        modes = {}
        for p in pl:
            im = Image.open(p); a = np.asarray(im)
            key = (im.mode, im.size, a.dtype.str)
            modes.setdefault(key, []).append(p)
        for key, ps in modes.items():
            a = np.asarray(Image.open(ps[-1]))
            alpha = (np.unique(a[..., -1])[:4].tolist() if a.ndim == 3 and a.shape[2] in (2, 4) else "-")
            gray = a.ndim == 3 and a.shape[2] >= 3 and np.array_equal(a[..., 0], a[..., 1]) and np.array_equal(a[..., 1], a[..., 2])
            print(f"  png {key}: {len(ps)} files; e.g. {os.path.basename(ps[-1])} R=G=B {gray} alpha values {alpha} range {a.min()}..{a.max()}")
