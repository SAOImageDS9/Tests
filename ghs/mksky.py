#!/usr/bin/env python3
# Make ghs/sky.fits: a deterministic float image for the GHS scale tests.
# Sky 100 with gaussian noise (sigma 2), a faint diffuse blob (+6 at the
# centre, ~3 sigma), and point sources up to 1e5, so that with minmax
# limits the sky is narrower than one step of DS9's 16384-entry scale
# table. No numpy needed.
#   usage: python3 ghs/mksky.py ghs/sky.fits
import math, random, struct, sys

N = 256
random.seed(1)
src = [(random.uniform(0, N), random.uniform(0, N), 10**random.uniform(2, 5))
       for _ in range(20)]
src.append((128, 128, 1e5))

data = []
for y in range(N):
    for x in range(N):
        v = 100 + random.gauss(0, 2)
        v += 6*math.exp(-((x-100)**2 + (y-140)**2)/(2*45**2))
        data.append(v)
for sx, sy, a in src:
    for y in range(max(0, int(sy)-10), min(N, int(sy)+11)):
        for x in range(max(0, int(sx)-10), min(N, int(sx)+11)):
            data[y*N+x] += a*math.exp(-((x-sx)**2 + (y-sy)**2)/(2*1.5**2))

cards = ["SIMPLE  =                    T", "BITPIX  =                  -32",
         "NAXIS   =                    2", "NAXIS1  = %20d" % N,
         "NAXIS2  = %20d" % N, "OBJECT  = 'GHS test sky'", "END"]
hdr = "".join(c.ljust(80) for c in cards)
hdr = hdr.ljust(((len(hdr)+2879)//2880)*2880)
body = struct.pack('>%df' % (N*N), *data)
body += b'\0'*((-len(body)) % 2880)
open(sys.argv[1], 'wb').write(hdr.encode() + body)

s = sorted(data)
print("min %.4f max %.4f median %.4f" % (s[0], s[-1], s[len(s)//2]))
