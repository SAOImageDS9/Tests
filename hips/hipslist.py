# Build the candidate file list (relative paths) for each test HiPS.
import numpy as np, healpy as hp
from astropy.coordinates import SkyCoord
import astropy.units as u
def tile(k, n, ext): return f"Norder{k}/Dir{(n//10000)*10000}/Npix{n}.{ext}"
def disc(ra, dec, rad_deg, k, frame):
    c = SkyCoord(ra*u.deg, dec*u.deg, frame="icrs")
    if frame == "galactic": c = c.galactic; lon, lat = c.l.deg, c.b.deg
    else: lon, lat = c.ra.deg, c.dec.deg
    v = hp.ang2vec(lon, lat, lonlat=True)
    return hp.query_disc(2**k, v, np.radians(rad_deg), inclusive=True, nest=True)
def point(ra, dec, k): return int(hp.ang2pix(2**k, ra, dec, lonlat=True, nest=True))
L = {}
# A. DSS2 red (IRSA mirror): Allsky + one path order 3..9 at M31 + siblings at 9
a = ["properties", "Moc.fits", "Norder3/Allsky.fits", "Norder3/Allsky.jpg"]
for k in range(3, 10): a.append(tile(k, point(10.6847, 41.2690, k), "fits"))
n9 = point(10.6847, 41.2690, 9)
a += [tile(9, (n9//4)*4 + q, "fits") for q in range(4) if (n9//4)*4+q != n9]
a.append(tile(9, n9, "jpg"))
L["DSS2_red"] = ("https://irsa.ipac.caltech.edu/data/hips/CDS/DSS2/red", a)
# B. Abell1763 irac1 (galactic, partial): everything near the target, orders 0-5
b = ["properties", "Moc.fits", "metadata.xml"] + [f"Norder{k}/Allsky.fits" for k in range(4)]
for k in range(6):
    for n in disc(203.95, 41.15, 1.0, k, "galactic"):
        b += [tile(k, int(n), "fits"), tile(k, int(n), "png")]
L["Abell1763_irac1"] = ("https://cade.irap.omp.eu/documents/Ancillary/4Aladin/Abell1763_irac1", b)
# C. XRISM RESOLVE colour: Allsky 0-3 + tiles near the initial target, orders 0-7
c = ["properties", "Moc.fits"] + [f"Norder{k}/Allsky.png" for k in range(4)]
for k in range(8):
    c += [tile(k, int(n), "png") for n in disc(64.3359375, 37.92165, 0.25, k, "equatorial")]
L["XRISM_RESOLVE"] = ("https://data.darts.isas.jaxa.jp/pub/HiPS/XRISM-RESOLVE_Image", c)
# D. LAB HI cube: order 0, all 12 tiles, frames 0, 1, 445 (first), 890 (last)
d = ["properties", "Moc.fits", "Norder0/Allsky.png", "Norder0/Allsky_445.png", "Norder0/Dir0/Npix0.fits"]
for f in ("", "_1", "_445", "_890"):
    d += [f"Norder0/Dir0/Npix{n}{f}.png" for n in range(12)]
L["LABHI_cube"] = ("https://data.camras.nl/hips/labh/cds_aladin_cube", d)
for name, (base, files) in L.items():
    for f in dict.fromkeys(files): print(name, base, f)
