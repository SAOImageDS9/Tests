#!/usr/bin/env python
"""Check the fixtures themselves, independently of DS9.

Reads every MANIFEST.tsv entry back with tifffile (a different reader from
the libtiff DS9 uses) and checks that
- the tags in the file are the ones the manifest says (so a tifffile
  default did not quietly change what a fixture tests), and
- for `load' entries, the stored samples, flipped and with Orientation
  applied, page/sample planes stacked, equal the FITS twin exactly.

    ~/miniforge/envs/ds9asdf/bin/python check_fixtures.py
"""

import csv
import os
import sys

import numpy as np
import tifffile
from astropy.io import fits

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_tiff_fixtures import displayed  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))


def tag(page, code, default):
    t = page.tags.get(code)
    if t is None:
        return default
    v = t.value
    return int(v[0] if isinstance(v, tuple) else v)


def main():
    fails = 0
    rows = list(csv.DictReader(open(os.path.join(HERE, 'MANIFEST.tsv')),
                               delimiter='\t'))
    for r in rows:
        problems = []
        with tifffile.TiffFile(os.path.join(HERE, r['fixture'])) as tf:
            p0 = tf.pages[0]
            want = {
                'compression': (259, 1), 'photometric': (262, -1),
                'planar': (284, 1), 'orientation': (274, 1),
                'predictor': (317, 1), 'subfiletype': (254, 0),
                'width': (256, 0), 'height': (257, 0), 'spp': (277, 1),
            }
            for k, (code, dflt) in want.items():
                got = tag(p0, code, dflt)
                exp = int(r[k])
                if k == 'predictor' and exp == 0:
                    continue        # codec without a predictor
                if got != exp:
                    problems.append(f'{k}={got} want {exp}')
            bo = 'MM' if tf.byteorder == '>' else 'II'
            if bo != r['byteorder']:
                problems.append(f'byteorder {bo}')
            if len(tf.pages) != int(r['ndirs']):
                problems.append(f'ndirs={len(tf.pages)}')
            if ('tile' if p0.is_tiled else 'strip') != r['layout']:
                problems.append('layout')

            if r['expect'] == 'load':
                planes = []
                for pg in tf.pages:
                    if tag(pg, 254, 0) & 1:
                        continue                        # reduced resolution
                    if (pg.shape[:2] != p0.shape[:2]
                            and pg.shape != p0.shape):
                        continue                        # different geometry
                    a = pg.asarray()
                    o = tag(pg, 274, 1)
                    spp = int(r['spp'])
                    if spp == 1:
                        planes.append(displayed(a, o) if o != 1 else a)
                    else:
                        if int(r['planar']) == 2:
                            a = np.moveaxis(a, 0, -1)
                        for s in range(min(spp, 3)):
                            planes.append(a[..., s])
                data = np.stack([np.flipud(p) for p in planes])
                if data.shape[0] == 1:
                    data = data[0]
                twin = fits.getdata(os.path.join(HERE, r['twin']))
                if twin.shape != data.shape:
                    problems.append(f'twin shape {twin.shape} vs {data.shape}')
                elif not np.array_equal(twin, data.astype(twin.dtype)):
                    problems.append('twin pixels differ')
                elif data.dtype.kind in 'ui' and \
                        not np.array_equal(twin.astype(np.int64),
                                           data.astype(np.int64)):
                    problems.append('twin values differ after BZERO')

        if problems:
            fails += 1
            print(f"FAIL {r['fixture']}: {'; '.join(problems)}")
    print(f'{len(rows)} checked, {fails} failed')
    return 1 if fails else 0


if __name__ == '__main__':
    sys.exit(main())
