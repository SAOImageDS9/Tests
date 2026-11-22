#!/usr/bin/env python
"""Check of the native TIFF load (`$frame load tiff <file>`), Phases 1-3.

Has a live ds9 (over XPA, through its `tcl' entry point) load every
MANIFEST.tsv entry with the frame's `load tiff' command and write what it
loaded straight back out, then compares in Python:

- in an ordinary frame, every `load' fixture: the saved image (`save fits
  file') must equal the twin pixel for pixel, and BITPIX (from `get fits
  header') must be the one TODO_TIFF16.md section 2.3 maps the sample type
  to. A stack loads as a cube, all of it; an RGB TIFF as luminance, so its
  twin there is <name>.lum.fits;
- in an RGB frame, every loadable RGB fixture: the three channels (`save
  fits rgb cube file') must equal the twin, page 1's R, G and B;
- every `refuse' fixture: the load must fail, with a `tiff: ...' reason.

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


def run(title, xpabin, tmp, tag, rows, save, setup='', teardown=''):
    """Load each row's fixture, save it with `save', keep its header.
    Returns {index: (status, saved file or error)}."""
    out = os.path.join(tmp, f'{tag}.out')
    script = os.path.join(tmp, f'{tag}.tcl')
    with open(script, 'w') as f:
        f.write(f'set _ch [open {{{out}}} w]\n{setup}\n')
        for k, r in rows:
            fn = os.path.join(HERE, r['fixture'])
            sav = os.path.join(tmp, f'{tag}{k}.fits')
            hdr = os.path.join(tmp, f'{tag}{k}.hdr')
            f.write(
                f'if {{[catch {{$current(frame) load tiff {{{fn}}}}} _r]}} '
                f'{{puts $_ch [list {k} ERROR $_r]}} '
                f'elseif {{[catch {{$current(frame) save {save} '
                f'{{{sav}}}}} _r]}} {{puts $_ch [list {k} SAVEERROR $_r]}} '
                f'else {{set _h [open {{{hdr}}} w]; '
                f'puts -nonewline $_h [$current(frame) get fits header 1]; '
                f'close $_h; puts $_ch [list {k} OK {{{sav}}}]}}\n')
        f.write(f'{teardown}\nclose $_ch\n')
    # xpaset reports the last error the script caught (a refusal) and exits
    # 1 even though the script ran to the end; the .out file is what counts.
    subprocess.run([os.path.join(xpabin, 'xpaset'), title, 'tcl'],
                   input=f'source {{{script}}}\n', text=True,
                   capture_output=True)
    got = {}
    for line in open(out):
        k, status, rest = line.rstrip('\n').split(' ', 2)
        got[int(k)] = (status, rest.strip('{}'))
    return got


def compare(r, status, rest, twin_fn, problems):
    if status != 'OK':
        problems.append(f'{status}: {rest}')
        return
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
    twin = fits.getdata(os.path.join(HERE, twin_fn))
    # `save fits' writes a 1 x N image as 1-D, for FITS too
    twin = np.squeeze(twin)
    if data is not None:
        data = np.squeeze(data)
    want = BITPIX[r['dtype']]
    if hdr is not None and hdr['BITPIX'] != want:
        problems.append(f"BITPIX {hdr['BITPIX']} want {want}")
    if hdr is not None and r['fixture'] == 'header/texttags_u2.tif':
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
        return
    kind = twin.dtype.kind
    a = data.astype(np.float64 if kind == 'f' else np.int64)
    b = twin.astype(np.float64 if kind == 'f' else np.int64)
    if not np.array_equal(a, b):
        problems.append(f'{int(np.sum(a != b))} pixels differ')


def main():
    title = sys.argv[1] if len(sys.argv) > 1 else 'DS9TiffProbe'
    xpabin = sys.argv[2] if len(sys.argv) > 2 else \
        os.path.join(HERE, '..', '..', 'bin')
    rows = list(csv.DictReader(open(os.path.join(HERE, 'MANIFEST.tsv')),
                               delimiter='\t'))
    tmp = tempfile.mkdtemp(prefix='tiffload')

    # a ds9 left with no frame (after `frame delete') has nothing to load
    # into, so make one first
    base = run(title, xpabin, tmp, 'base', list(enumerate(rows)),
               'fits file',
               setup='if {$current(frame) == {}} {CreateFrame}')
    rgbrows = [(k, r) for k, r in enumerate(rows)
               if r['expect'] == 'load' and int(r['photometric']) == 2]
    rgb = run(title, xpabin, tmp, 'rgb', rgbrows, 'fits rgb cube file',
              setup='CreateRGBFrame', teardown='DeleteCurrentFrame')

    fails = 0
    nload = nrefuse = 0
    for k, r in enumerate(rows):
        problems = []
        status, rest = base.get(k, ('MISSING', ''))
        if r['expect'] == 'load':
            nload += 1
            twin = r['twin']
            if int(r['photometric']) == 2:
                twin = twin[:-5] + '.lum.fits'
            compare(r, status, rest, twin, problems)
        else:
            nrefuse += 1
            if status == 'OK':
                problems.append('loaded, but must be refused')
            elif not rest.startswith('tiff: '):
                problems.append(f'no reason given: {status} {rest!r}')
            else:
                print(f"REFUSED {r['fixture']}: {rest}")
        if problems:
            fails += 1
            print(f"FAIL {r['fixture']}: {'; '.join(problems)}")

    for k, r in rgbrows:
        problems = []
        status, rest = rgb.get(k, ('MISSING', ''))
        compare(r, status, rest, r['twin'], problems)
        if problems:
            fails += 1
            print(f"FAIL {r['fixture']} (RGB frame): {'; '.join(problems)}")

    print(f'{nload} loads, {len(rgbrows)} RGB-frame loads and {nrefuse} '
          f'refusals checked, {fails} failed')
    return 1 if fails else 0


if __name__ == '__main__':
    sys.exit(main())
