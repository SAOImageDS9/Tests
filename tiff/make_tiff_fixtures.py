#!/usr/bin/env python
"""Write the TIFF fixtures for DS9's native full-depth TIFF reader.

Phase 0 of TODO_TIFF16.md. For every <name>.tif this writes <name>.fits, the
twin: the same samples as DS9 should present them, under the conventions
TODO_TIFF16.md section 2 commits to:

- rows flipped (TIFF row 0 is the top, FITS row 1 the bottom);
- the Orientation tag applied, so the twin is the image as displayed;
- RGB(A) and multi-page files become cubes, one plane per sample or page
  (alpha dropped, reduced-resolution pages skipped);
- MINISWHITE values kept as stored, not inverted;
- uint16 and uint32 as astropy writes them (BZERO), which DS9 reads back
  as the same values.

MANIFEST.tsv also records, for directory 0 of each file, what fitsy's
Phase 0 probe (`fitsy tiff decode`) must report: the tags, and the
nsamples/min/max/sum of every stored sample. check_probe.py compares them.

Needs numpy, astropy, tifffile and imagecodecs (the ds9asdf conda env):
    ~/miniforge/envs/ds9asdf/bin/python make_tiff_fixtures.py
Deterministic: no random numbers, no timestamps in the files.
"""

import os
import sys

import numpy as np
import tifffile
from astropy.io import fits

HERE = os.path.dirname(os.path.abspath(__file__))

# TIFF tag values, for the manifest
COMPRESSION = {
    None: 1, 'packbits': 32773, 'lzw': 5, 'adobe_deflate': 8,
    'deflate': 32946, 'lzma': 34925, 'zstd': 50000, 'jpeg': 7,
}
SAMPLEFORMAT = {'u': 1, 'i': 2, 'f': 3}
PHOTOMETRIC = {'miniswhite': 0, 'minisblack': 1, 'rgb': 2, 'palette': 3,
               'ycbcr': 6}

GRAY_W, GRAY_H = 37, 23        # odd, so nothing divides evenly
TILE_W, TILE_H = 50, 40        # with 16x16 tiles: clipped edge tiles
TILE = (16, 16)

MANIFEST_COLS = [
    'fixture', 'twin', 'expect', 'group', 'dtype', 'compression', 'layout',
    'planar', 'byteorder', 'photometric', 'width', 'height', 'spp', 'ndirs',
    'orientation', 'predictor', 'subfiletype', 'nsamples', 'min', 'max',
    'sum', 'notes',
]


def pattern(h, w, dtype, seed=0):
    """A deterministic image with no symmetry, so any flip or transpose
    shows, and with the low byte of every 16-bit value non-constant, so an
    8-bit truncation shows."""
    dt = np.dtype(dtype)
    y, x = np.mgrid[0:h, 0:w].astype(np.float64)
    if dt.kind == 'f':
        v = (np.sin(0.37 * x + 0.11 * seed) * np.cos(0.23 * y)
             + 0.01 * x - 0.02 * y + 0.5 * seed)
        if dt.itemsize >= 4:
            v = v * 1.0e3 - 7.25     # negative values and a wide range
        return v.astype(dt)
    if dt.kind == 'u':
        top = np.iinfo(dt).max
        v = (x * 257 + y * 1031 + seed * 4099) * (top // 65535 or 1) // 3
        v = v.astype(np.uint64) % (top + 1)
        v.flat[0] = 0
        v.flat[-1] = top             # both ends of the range
        return v.astype(dt)
    # signed
    info = np.iinfo(dt)
    span = int(info.max) - int(info.min) + 1
    v = (x * 263 + y * 1033 + seed * 4111) * (span // 65536 or 1)
    v = (v.astype(np.int64) % min(span, 2**62)) + int(info.min)
    v.flat[0] = info.min
    v.flat[-1] = info.max
    return v.astype(dt)


def stackpage(img, k):
    """Page k of a stack, with a range of its own (integers divided by
    k+1, floats multiplied by k+1), so that per-slice min/max, which
    tiff.sh probes, tells the slices apart: pattern() pins every image to
    its type's full range."""
    if img.dtype.kind == 'f':
        return (img * (k + 1)).astype(img.dtype)
    return (img // (k + 1)).astype(img.dtype)


# Orientation: `stored(c, o)` is the raster a writer stores so that a
# reader applying Orientation o displays c (row 0 at the top). displayed()
# is the reader's side, written directly from the tag's definition, and
# write_orientation() asserts the two agree.
def stored(c, o):
    return {
        1: lambda a: a,
        2: lambda a: a[:, ::-1],
        3: lambda a: a[::-1, ::-1],
        4: lambda a: a[::-1, :],
        5: lambda a: a.T,
        6: lambda a: np.rot90(a, 1),
        7: lambda a: np.rot90(a, 1)[:, ::-1],
        8: lambda a: np.rot90(a, 3),
    }[o](c)


def displayed(s, o):
    """Orientation per TIFF 6.0: where stored row 0 and column 0 go."""
    r, cc = s.shape
    if o in (1, 2, 3, 4):
        out = np.empty((r, cc), s.dtype)
        for i in range(r):
            for j in range(cc):
                di = i if o in (1, 2) else r - 1 - i       # row 0 top/bottom
                dj = j if o in (1, 4) else cc - 1 - j      # col 0 left/right
                out[di, dj] = s[i, j]
        return out
    out = np.empty((cc, r), s.dtype)  # 5-8: rows become columns
    for i in range(r):
        for j in range(cc):
            dj = i if o in (5, 8) else r - 1 - i           # row 0 left/right
            di = j if o in (5, 6) else cc - 1 - j          # col 0 top/bottom
            out[di, dj] = s[i, j]
    return out


def luminance(page, planar):
    """.299R + .587G + .114B, in the order and precision fitsy uses
    (double, left to right), rounded to nearest for integers."""
    a = np.asarray(page)
    r, g, b = (a[0], a[1], a[2]) if planar == 'separate' else \
        (a[..., 0], a[..., 1], a[..., 2])
    v = (0.299 * r.astype(np.float64) + 0.587 * g.astype(np.float64)
         + 0.114 * b.astype(np.float64))
    if a.dtype.kind == 'f':
        return v.astype(a.dtype)
    return np.floor(v + 0.5).astype(a.dtype)


class Writer:
    def __init__(self):
        self.rows = []

    def path(self, group, name, ext):
        d = os.path.join(HERE, group)
        os.makedirs(d, exist_ok=True)
        return os.path.join(d, name + ext)

    def twin(self, group, name, planes, cards=None):
        """planes: list of 2-D arrays, top row first, as displayed."""
        data = np.stack([np.flipud(p) for p in planes])
        if data.shape[0] == 1:
            data = data[0]
        if data.dtype == np.float16:
            data = data.astype(np.float32)
        if data.dtype == np.uint32:
            # as int64 (BITPIX 64), exact and as the native reader widens
            # it; astropy's BITPIX 32 + BZERO would make ds9 show scaled
            # values in %g form, which tiff.sh's text baselines cannot
            # compare with the exact integers of a native load
            data = data.astype(np.int64)
        hdu = fits.PrimaryHDU(data)
        for c in cards or []:
            # FITS cards the reader merges from ImageDescription
            hdu.header.append(fits.Card.fromstring(c), end=True)
        fn = self.path(group, name, '.fits')
        hdu.writeto(fn, overwrite=True)
        return os.path.relpath(fn, HERE)

    def add(self, group, name, stored_pages, *, expect='load',
            twin_planes=None, compression=None, tile=None, planar=None,
            byteorder='<', photometric=None, orientation=None,
            predictor=None, subfiletypes=None, bigtiff=False,
            rowsperstrip=None, extrasamples=None, colormap=None,
            texttags=None, bitspersample=None, twin_cards=None,
            notes=''):
        """stored_pages: list of arrays as they go in the file, each (h, w)
        or (h, w, spp) for contig or (spp, h, w) for separate planes."""
        fn = self.path(group, name, '.tif')
        if os.path.exists(fn):
            os.remove(fn)
        with tifftools_writer(fn, bigtiff, byteorder) as tw:
            for k, page in enumerate(stored_pages):
                if bitspersample is not None:
                    extra_kw = {'bitspersample': bitspersample}
                else:
                    extra_kw = {}
                kw = dict(compression=compression, tile=tile, **extra_kw,
                          photometric=photometric, predictor=predictor,
                          rowsperstrip=rowsperstrip, metadata=None,
                          software=False, datetime=False)
                if texttags:
                    kw['software'] = texttags.get('software', False)
                    kw['datetime'] = texttags.get('datetime', False)
                    kw['description'] = texttags.get('description')
                if planar:
                    kw['planarconfig'] = planar
                if extrasamples is not None:
                    kw['extrasamples'] = extrasamples
                if colormap is not None:
                    kw['colormap'] = colormap
                if subfiletypes is not None:
                    kw['subfiletype'] = subfiletypes[k]
                extratags = []
                if orientation is not None:
                    extratags.append((274, 'H', 1, orientation, True))
                if texttags and 'artist' in texttags:
                    extratags.append((315, 's', 0, texttags['artist'], True))
                kw['extratags'] = extratags
                if compression == 'jpeg':
                    kw['compressionargs'] = {'level': 95}
                tw.write(page, **kw)

        twin = ''
        if expect == 'load':
            twin = self.twin(group, name, twin_planes, cards=twin_cards)
            if photometric == 'rgb':
                # what a non-RGB frame shows: one luminance plane per
                # full-resolution page (TODO_TIFF16.md, Phase 3)
                self.twin(group, name + '.lum', [
                    luminance(pg, planar) for k, pg in
                    enumerate(stored_pages)
                    if not (subfiletypes and subfiletypes[k] & 1)])

        first = np.asarray(stored_pages[0])
        if first.ndim == 2:
            h, w = first.shape
            spp = 1
        elif planar == 'separate':
            spp, h, w = first.shape
        else:
            h, w, spp = first.shape
        stats = first.astype(np.float64) if first.dtype.kind == 'f' \
            else first.astype(np.int64 if first.dtype.kind == 'i'
                              or first.dtype.itemsize < 8 else np.uint64)
        pred = 0
        if compression in ('lzw', 'adobe_deflate', 'deflate', 'lzma', 'zstd'):
            pred = {None: 1, False: 1, True: 2 if first.dtype.kind != 'f'
                    else 3}.get(predictor, predictor)
        self.rows.append(dict(
            fixture=os.path.relpath(fn, HERE), twin=twin, expect=expect,
            group=group, dtype=first.dtype.str.lstrip('<>|='),
            compression=COMPRESSION[compression],
            layout='tile' if tile else 'strip',
            planar=2 if planar == 'separate' else 1,
            byteorder='MM' if byteorder == '>' else 'II',
            photometric=PHOTOMETRIC[photometric or
                                    ('rgb' if spp >= 3 else 'minisblack')],
            width=w, height=h, spp=spp, ndirs=len(stored_pages),
            orientation=orientation or 1, predictor=pred,
            subfiletype=subfiletypes[0] if subfiletypes else 0,
            nsamples=int(stats.size), min=repr(stats.min().item()),
            max=repr(stats.max().item()),
            sum=repr(stats.astype(np.float64).sum().item()
                     if first.dtype.kind == 'f' else int(stats.sum())),
            notes=notes))

    def manifest(self):
        fn = os.path.join(HERE, 'MANIFEST.tsv')
        with open(fn, 'w') as f:
            f.write('\t'.join(MANIFEST_COLS) + '\n')
            for r in self.rows:
                f.write('\t'.join(str(r[c]) for c in MANIFEST_COLS) + '\n')
        return fn


class tifftools_writer:
    def __init__(self, fn, bigtiff, byteorder):
        self.tw = tifffile.TiffWriter(fn, bigtiff=bigtiff,
                                      byteorder=byteorder)

    def __enter__(self):
        return self.tw

    def __exit__(self, *a):
        self.tw.close()


DTYPES = ['u1', 'u2', 'i2', 'u4', 'i4', 'f4', 'f8']


def main():
    w = Writer()

    # dtype x compression, gray, strips, little-endian
    for dt in DTYPES:
        for comp in (None, 'packbits', 'lzw', 'adobe_deflate', 'deflate'):
            img = pattern(GRAY_H, GRAY_W, dt)
            cname = comp or 'none'
            w.add('dtype', f'gray_{dt}_{cname}', [img], twin_planes=[img],
                  compression=comp, rowsperstrip=5,
                  notes='5-row strips, short last strip')

    # dtype, tiled with clipped edge tiles
    for dt in DTYPES:
        img = pattern(TILE_H, TILE_W, dt, seed=1)
        w.add('tiled', f'gray_{dt}_tiled_deflate', [img], twin_planes=[img],
              compression='adobe_deflate', tile=TILE,
              notes='16x16 tiles over 50x40')
        w.add('tiled', f'gray_{dt}_tiled_none', [img], twin_planes=[img],
              tile=TILE, notes='16x16 tiles over 50x40')

    # big-endian
    for dt in DTYPES:
        img = pattern(GRAY_H, GRAY_W, dt, seed=2)
        w.add('byteorder', f'gray_{dt}_MM_none', [img], twin_planes=[img],
              byteorder='>')
        w.add('byteorder', f'gray_{dt}_MM_deflate', [img], twin_planes=[img],
              byteorder='>', compression='adobe_deflate', rowsperstrip=7)

    # predictors
    for dt, comp in (('u2', 'lzw'), ('u2', 'adobe_deflate'),
                     ('i2', 'adobe_deflate'), ('i4', 'adobe_deflate'),
                     ('f4', 'adobe_deflate'), ('f8', 'lzw')):
        img = pattern(GRAY_H, GRAY_W, dt, seed=3)
        w.add('predictor', f'gray_{dt}_{comp}_predictor', [img],
              twin_planes=[img], compression=comp, predictor=True,
              rowsperstrip=6,
              notes='horizontal (2) for ints, floating point (3) for floats')
    img = pattern(TILE_H, TILE_W, 'u2', seed=3)
    w.add('predictor', 'gray_u2_tiled_lzw_predictor', [img],
          twin_planes=[img], compression='lzw', predictor=True, tile=TILE)

    # RGB: contig and separate, strip and tile
    for dt in ('u1', 'u2', 'f4'):
        for planar in ('contig', 'separate'):
            for tiled in (False, True):
                hh, ww = (TILE_H, TILE_W) if tiled else (GRAY_H, GRAY_W)
                planes = [pattern(hh, ww, dt, seed=s) for s in (4, 5, 6)]
                page = (np.stack(planes) if planar == 'separate'
                        else np.dstack(planes))
                lay = 'tiled' if tiled else 'strip'
                w.add('rgb', f'rgb_{dt}_{planar}_{lay}', [page],
                      twin_planes=planes, compression='adobe_deflate',
                      tile=TILE if tiled else None, planar=planar,
                      photometric='rgb', rowsperstrip=None if tiled else 4,
                      notes='twin: 3-plane cube R,G,B')
    planes = [pattern(GRAY_H, GRAY_W, 'u2', seed=s) for s in (4, 5, 6, 7)]
    w.add('rgb', 'rgba_u2_contig_strip', [np.dstack(planes)],
          twin_planes=planes[:3], compression='adobe_deflate',
          photometric='rgb', extrasamples=[2],
          notes='unassociated alpha; twin drops it')

    # multi-page
    pages = [stackpage(pattern(GRAY_H, GRAY_W, 'u2', seed=s), k)
             for k, s in enumerate((8, 9, 10))]
    w.add('pages', 'stack3_u2_deflate', pages, twin_planes=pages,
          compression='adobe_deflate', notes='3 pages -> 3-plane cube')
    pages = [stackpage(pattern(TILE_H, TILE_W, 'f4', seed=s), k)
             for k, s in enumerate((8, 9, 10))]
    w.add('pages', 'stack3_f4_tiled', pages, twin_planes=pages, tile=TILE,
          compression='adobe_deflate')
    full = [stackpage(pattern(GRAY_H, GRAY_W, 'u2', seed=s), k)
            for k, s in enumerate((11, 12))]
    thumb = pattern(GRAY_H // 2, GRAY_W // 2, 'u2', seed=13)
    w.add('pages', 'stack2_u2_with_reduced', [full[0], thumb, full[1]],
          twin_planes=full, subfiletypes=[0, 1, 0],
          notes='middle page is NewSubfileType=1 (reduced); skipped')
    mixed = [pattern(GRAY_H, GRAY_W, 'u2', seed=14),
             pattern(GRAY_H + 3, GRAY_W, 'u2', seed=15)]
    w.add('pages', 'mixed_geometry_u2', mixed, twin_planes=mixed[:1],
          notes='second page differs in size; twin is page 1 only')

    # orientation
    canon = pattern(GRAY_H, GRAY_W, 'u2', seed=16)
    for o in range(1, 9):
        s = np.ascontiguousarray(stored(canon, o))
        assert np.array_equal(displayed(s, o), canon), o
        w.add('orientation', f'orient{o}_u2', [s], twin_planes=[canon],
              orientation=o, notes='twin is the image as displayed')

    # photometric
    img = pattern(GRAY_H, GRAY_W, 'u2', seed=17)
    w.add('photometric', 'miniswhite_u2', [img], twin_planes=[img],
          photometric='miniswhite', notes='values as stored, not inverted')

    # text tags -> header cards (CREATOR, DATE, OBSERVER, COMMENT)
    img = pattern(GRAY_H, GRAY_W, 'u2', seed=26)
    w.add('header', 'texttags_u2', [img], twin_planes=[img], texttags={
        'software': "O'Brien Capture 3.1 (a Software tag long enough that "
                    "it cannot fit on one FITS card with its comment)",
        'datetime': '2026:11:22 10:11:12',
        'artist': "Observer with an apostrophe's quote",
        'description': ('M42 stack, 40 x 120 s, gain 100. ' * 6).strip(),
    }, notes='Software/DateTime/Artist/ImageDescription; long, with quotes')

    # Phase 4: half floats
    f2 = pattern(GRAY_H, GRAY_W, 'f2')
    w.add('dtype', 'gray_f2_none', [f2], twin_planes=[f2],
          notes='half float -> float32, exactly')
    w.add('dtype', 'gray_f2_adobe_deflate_predictor', [f2], twin_planes=[f2],
          compression='adobe_deflate', predictor=True, rowsperstrip=6,
          notes='half float, floating point predictor (3)')
    sp = pattern(GRAY_H, GRAY_W, 'f2', seed=3)
    special = np.array([0.0, -0.0, 6.0e-8, -6.0e-8, 6.1e-5, 1.0e-6,
                        65504.0, -65504.0, 6.103515625e-05], np.float16)
    sp.flat[:special.size] = special
    w.add('dtype', 'gray_f2_special', [sp], twin_planes=[sp],
          notes='half float: zeros, subnormals, extremes')

    # Phase 4: packed unsigned depths, raw counts
    for bps in (1, 2, 4, 10, 12, 14):
        dt = 'u1' if bps < 8 else 'u2'
        img = (pattern(GRAY_H, GRAY_W, 'u2', seed=bps).astype(np.uint32)
               % (1 << bps)).astype(dt)
        img.flat[0] = 0
        img.flat[-1] = (1 << bps) - 1
        w.add('packed', f'gray_u{bps}_none', [img], twin_planes=[img],
              bitspersample=bps, rowsperstrip=5,
              notes=f'{bps} bits per sample, packed, 5-row strips')
    u12 = (pattern(TILE_H, TILE_W, 'u2', seed=31) >> 4).astype(np.uint16)
    w.add('packed', 'gray_u12_tiled', [u12], twin_planes=[u12],
          bitspersample=12, tile=TILE, notes='12 bit, 16x16 tiles')
    rgb12 = [(pattern(GRAY_H, GRAY_W, 'u2', seed=s) >> 4).astype(np.uint16)
             for s in (32, 33, 34)]
    w.add('packed', 'rgb_u12_contig', [np.dstack(rgb12)],
          twin_planes=rgb12, bitspersample=12, photometric='rgb',
          rowsperstrip=4, notes='12-bit RGB, chunky: samples straddle bytes')
    b1 = (pattern(GRAY_H, GRAY_W, 'u1', seed=25) & 1).astype(np.uint8)
    w.add('packed', 'bilevel_1bit', [b1], twin_planes=[b1],
          bitspersample=1, notes='1 bit, MinIsBlack')
    w.add('packed', 'miniswhite_1bit', [b1], twin_planes=[b1],
          bitspersample=1, photometric='miniswhite',
          notes='1 bit, MinIsWhite: values as stored')

    # Phase 4: FITS cards in ImageDescription
    img = pattern(GRAY_H, GRAY_W, 'u2', seed=35)
    fc = [fits.Card('SIMPLE', True).image,
          fits.Card('BITPIX', 16).image,
          fits.Card('NAXIS', 2).image,
          fits.Card('NAXIS1', GRAY_W).image,
          fits.Card('NAXIS2', GRAY_H).image,
          fits.Card('OBJECT', "Orion's nebula", 'target').image,
          fits.Card('EXPTIME', 120.0, '[s]').image,
          fits.Card('DATE', '2026-01-02T03:04:05', 'from the FITS cards').image,
          fits.Card('CTYPE1', 'RA---TAN').image,
          fits.Card('CTYPE2', 'DEC--TAN').image,
          fits.Card('CRPIX1', 19.0).image,
          fits.Card('CRPIX2', 12.0).image,
          fits.Card('CRVAL1', 83.8221).image,
          fits.Card('CRVAL2', -5.3911).image,
          fits.Card('CDELT1', -0.0003).image,
          fits.Card('CDELT2', 0.0003).image,
          fits.Card('RADESYS', 'ICRS').image,
          fits.Card('COMMENT', 'written by a capture program').image,
          fits.Card('HISTORY', 'stacked 40 frames').image,
          'END'.ljust(80)]
    merged = [c for c in fc if c[:8].rstrip() not in
              ('SIMPLE', 'BITPIX', 'NAXIS', 'NAXIS1', 'NAXIS2', 'END')]
    tt = {'datetime': '2026:11:22 10:11:12'}
    w.add('header', 'fitscards_newline_u2', [img], twin_planes=[img],
          texttags=dict(tt, description='\n'.join(c.rstrip() for c in fc)),
          twin_cards=merged,
          notes='FITS cards, one per line, with a TAN WCS: merged')
    w.add('header', 'fitscards_80_u2', [img], twin_planes=[img],
          texttags=dict(tt, description=''.join(fc)), twin_cards=merged,
          notes='FITS cards back to back, 80 characters each: merged')
    bad = [fits.Card('NAXIS1', GRAY_W + 3).image if c.startswith('NAXIS1')
           else c for c in fc]
    w.add('header', 'fitscards_badnaxis_u2', [img], twin_planes=[img],
          texttags=dict(tt, description='\n'.join(c.rstrip() for c in bad)),
          notes='FITS cards whose NAXIS1 is not the image: not merged')
    w.add('header', 'imagej_u2', [img], twin_planes=[img],
          texttags={'description': 'ImageJ=1.54f\nimages=1\nunit=micron\n'
                    'spacing=0.5\nmin=0.0\nmax=65535.0\n'},
          notes='an ImageJ description: not FITS, kept as COMMENTs')

    # edge cases
    img = pattern(GRAY_H, GRAY_W, 'u2', seed=18)
    w.add('edge', 'bigtiff_u2', [img], twin_planes=[img], bigtiff=True,
          compression='adobe_deflate')
    w.add('edge', 'rps1_u2', [img], twin_planes=[img], rowsperstrip=1)
    w.add('edge', 'onestrip_u2', [img], twin_planes=[img],
          rowsperstrip=GRAY_H, notes='single strip; -array skip= cross-check')
    row = pattern(1, 61, 'u2', seed=19)
    w.add('edge', 'row_1x61_u2', [row], twin_planes=[row])
    col = pattern(61, 1, 'u2', seed=19)
    w.add('edge', 'col_61x1_u2', [col], twin_planes=[col])

    # Phase 3: an RGB stack, gray with alpha, and multi-band gray
    pages = [stackpage(np.dstack([pattern(GRAY_H, GRAY_W, 'u2', seed=s + c)
                             for c in (0, 1, 2)]), k)
             for k, s in enumerate((30, 40))]
    w.add('pages', 'stack2_rgb_u2', pages,
          twin_planes=[pages[0][..., c] for c in (0, 1, 2)],
          compression='adobe_deflate', photometric='rgb',
          notes='twin: page 1 R,G,B (RGB frame); .lum twin: 2 pages')
    ga = [pattern(GRAY_H, GRAY_W, 'u2', seed=s) for s in (50, 51)]
    w.add('rgb', 'graya_u2_contig', [np.dstack(ga)], twin_planes=ga[:1],
          photometric='minisblack', extrasamples=[2],
          notes='gray + unassociated alpha; twin drops the alpha')

    # not loadable natively in v1: report why (or fall back to photo)
    img = pattern(GRAY_H, GRAY_W, 'u2', seed=20)
    w.add('unsupported', 'gray_u2_lzma', [img], expect='refuse',
          compression='lzma', notes='codec not in tifftcl')
    w.add('unsupported', 'gray_u2_zstd', [img], expect='refuse',
          compression='zstd', notes='codec not in tifftcl')
    pal = (pattern(GRAY_H, GRAY_W, 'u1', seed=21) % 16).astype(np.uint8)
    cmap = np.zeros((3, 256), np.uint16)
    cmap[:, :16] = np.arange(16) * 4096
    w.add('unsupported', 'palette_u1', [pal], expect='refuse',
          photometric='palette', colormap=cmap, notes='photo path')
    rgb8 = np.dstack([pattern(48, 64, 'u1', seed=s) for s in (22, 23, 24)])
    w.add('unsupported', 'rgb_u1_jpeg', [rgb8], expect='refuse',
          compression='jpeg', photometric='ycbcr', tile=None,
          rowsperstrip=16, notes='JPEG/YCbCr: photo path')
    mb = [pattern(GRAY_H, GRAY_W, 'u2', seed=s) for s in (60, 61, 62)]
    w.add('unsupported', 'multiband_u2', [np.dstack(mb)], expect='refuse',
          photometric='minisblack', extrasamples=[0, 0],
          notes='3 bands, ExtraSamples unspecified: not cut to band 1')
    try:
        i12 = (pattern(GRAY_H, GRAY_W, 'i2', seed=27) >> 4).astype(np.int16)
        w.add('unsupported', 'gray_i12_none', [i12], expect='refuse',
              bitspersample=12, notes='signed packed: not supported')
    except Exception as e:                      # tifffile refuses it
        print('skipped unsupported/gray_i12_none:', e)
        for ext in ('.tif', '.fits'):
            fn = os.path.join(HERE, 'unsupported', 'gray_i12_none' + ext)
            if os.path.exists(fn):
                os.remove(fn)

    fn = w.manifest()
    nload = sum(r['expect'] == 'load' for r in w.rows)
    print(f'{len(w.rows)} fixtures ({nload} load, '
          f'{len(w.rows) - nload} refuse); manifest {fn}')


if __name__ == '__main__':
    sys.exit(main())
