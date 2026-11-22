#!/usr/bin/env python
"""Phase 1 check of the native TIFF load (`$frame load tiff <file>`).

For every MANIFEST.tsv entry, has a live ds9 (over XPA, through its `tcl'
entry point) load the file with the frame's `load tiff' command and, if
that works, write the loaded image straight back out with `save fits file'.
Then compares, in Python:

- loadable in Phase 1 (one sample per pixel, `load' in the manifest): the
  saved image must equal the twin pixel for pixel (directory 0 only, so a
  stack's twin contributes its first plane), and BITPIX must be the one
  TODO_TIFF16.md section 2.3 maps the sample type to;
- everything else (RGB, the `refuse' fixtures): the load must fail, with a
  `tiff: ...' reason.

Start ds9 first, with xpans on PATH (AGENTS.md), then
    ~/miniforge/envs/ds9asdf/bin/python check_load.py [title] [xpa bin dir]
"""

import csv
import os
import subprocess
import sys
import tempfile

import numpy as np
from astropy.io import fits

HERE = os.path.dirname(os.path.abspath(__file__))

# TODO_TIFF16.md section 2.3: BITPIX of the image in memory, as
# `get fits header' shows it (-16 is fitsy's unsigned 16; `save fits'
# writes such an image out as BITPIX 32, so the saved file is not used).
BITPIX = {'u1': 8, 'u2': -16, 'i2': 16, 'u4': 64, 'i4': 32,
          'f4': -32, 'f8': -64}

# header/texttags_u2.tif: the cards its text tags must give
TEXTTAGS = {
    'CREATOR': "O'Brien Capture 3.1 (a Software tag long enough",
    'DATE': '2026-11-22T10:11:12',
    'OBSERVER': "Observer with an apostrophe's quote",
}


def phase1_loadable(r):
    return r['expect'] == 'load' and int(r['spp']) == 1


def main():
    title = sys.argv[1] if len(sys.argv) > 1 else 'DS9TiffProbe'
    xpabin = sys.argv[2] if len(sys.argv) > 2 else \
        os.path.join(HERE, '..', '..', 'bin')
    rows = list(csv.DictReader(open(os.path.join(HERE, 'MANIFEST.tsv')),
                               delimiter='\t'))

    tmp = tempfile.mkdtemp(prefix='tiffload')
    out = os.path.join(tmp, 'load.out')
    script = os.path.join(tmp, 'load.tcl')
    with open(script, 'w') as f:
        f.write(f'set _ch [open {{{out}}} w]\n')
        for k, r in enumerate(rows):
            fn = os.path.join(HERE, r['fixture'])
            sav = os.path.join(tmp, f'{k}.fits')
            hdr = os.path.join(tmp, f'{k}.hdr')
            f.write(
                f'if {{[catch {{$current(frame) load tiff {{{fn}}}}} _r]}} '
                f'{{puts $_ch [list {k} ERROR $_r]}} '
                f'elseif {{[catch {{$current(frame) save fits file '
                f'{{{sav}}}}} _r]}} {{puts $_ch [list {k} SAVEERROR $_r]}} '
                f'else {{set _h [open {{{hdr}}} w]; '
                f'puts -nonewline $_h [$current(frame) get fits header 1]; '
                f'close $_h; puts $_ch [list {k} OK {{{sav}}}]}}\n')
        f.write('close $_ch\n')
    # xpaset reports the last error the script caught (a refusal) and exits
    # 1 even though the script ran to the end; load.out is what counts.
    subprocess.run([os.path.join(xpabin, 'xpaset'), title, 'tcl'],
                   input=f'source {{{script}}}\n', text=True,
                   capture_output=True)

    got = {}
    for line in open(out):
        k, status, rest = line.rstrip('\n').split(' ', 2)
        got[int(k)] = (status, rest.strip('{}'))

    fails = 0
    nload = nrefuse = 0
    for k, r in enumerate(rows):
        status, rest = got.get(k, ('MISSING', ''))
        problems = []
        if phase1_loadable(r):
            nload += 1
            if status != 'OK':
                problems.append(f'{status}: {rest}')
            else:
                data = fits.getdata(rest)
                text = open(rest[:-5] + '.hdr').read()
                try:
                    hdr = fits.Header.fromstring(text, sep='\n')
                except Exception as e:
                    hdr = None
                    problems.append(f'header does not parse: {e}')
                bad = [ln for ln in text.split('\n') if ln and len(ln) != 80]
                if bad:
                    problems.append(f'{len(bad)} header lines not 80 chars')
                twin = fits.getdata(os.path.join(HERE, r['twin']))
                if twin.ndim == 3:
                    twin = twin[0]          # directory 0 only, in Phase 1
                # `save fits' writes a 1 x N image as 1-D, for FITS too
                twin = np.squeeze(twin)
                if data is not None:
                    data = np.squeeze(data)
                want = BITPIX[r['dtype']]
                if hdr is not None and hdr['BITPIX'] != want:
                    problems.append(f"BITPIX {hdr['BITPIX']} want {want}")
                if hdr is not None and r['fixture'] == \
                        'header/texttags_u2.tif':
                    for key, val in TEXTTAGS.items():
                        card = hdr.get(key)
                        if card is None or not str(card).startswith(val):
                            problems.append(f'{key}={card!r}')
                    comments = ' '.join(str(c) for c in hdr['COMMENT'])
                    if 'M42 stack, 40 x 120 s, gain 100.' not in comments:
                        problems.append('ImageDescription not in COMMENT')
                if data is None or data.shape != twin.shape:
                    problems.append('shape %s want %s' % (
                        None if data is None else data.shape, twin.shape))
                else:
                    kind = twin.dtype.kind
                    a = data.astype(np.float64 if kind == 'f' else np.int64)
                    b = twin.astype(np.float64 if kind == 'f' else np.int64)
                    if not np.array_equal(a, b):
                        n = int(np.sum(a != b))
                        problems.append(f'{n} pixels differ')
        else:
            nrefuse += 1
            if status == 'OK':
                problems.append('loaded, but Phase 1 must refuse it')
            elif not rest.startswith('tiff: '):
                problems.append(f'no reason given: {status} {rest!r}')
            else:
                print(f"REFUSED {r['fixture']}: {rest}")
        if problems:
            fails += 1
            print(f"FAIL {r['fixture']}: {'; '.join(problems)}")

    print(f'{nload} loads and {nrefuse} refusals checked, {fails} failed')
    return 1 if fails else 0


if __name__ == '__main__':
    sys.exit(main())
