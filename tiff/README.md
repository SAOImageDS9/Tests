# TIFF fixtures (Phase 0 of `TODO_TIFF16.md`)

Test files for DS9's native full-depth TIFF reader. They were made before the reader
exists, from Python and with no help from libtiff. Each `<name>.tif` has a twin,
`<name>.fits`, holding the same samples as DS9 should present them.

| Path | What |
|---|---|
| `make_tiff_fixtures.py` | Writes every fixture, its twin, and `MANIFEST.tsv`, using tifffile. Deterministic: a rerun is byte-identical. |
| `check_fixtures.py` | Reads every fixture back with tifffile and checks its tags against the manifest and its pixels against the twin. Expect 107 checked, 0 failed. |
| `check_probe.py` | Runs fitsy's libtiff probe (`fitsy tiff decode`) inside a live ds9 over XPA, and compares directory 0's tags and nsamples/min/max/sum with the manifest. For `refuse` entries it prints what libtiff says. Expect 101 probed, 0 failed. |
| `MANIFEST.tsv` | One row per fixture: `expect` (`load`/`refuse`), the tags as stored, and the probe's expected statistics. |

Families: `dtype/` (u1 u2 i2 u4 i4 f4 f8 × none/PackBits/LZW/Deflate 8/Deflate
32946), `tiled/`, `byteorder/` (MM), `predictor/` (2 and 3), `rgb/` (contig and planar,
strip and tile, RGBA), `pages/` (stacks, a reduced-resolution page, mixed geometry),
`orientation/` (1–8), `photometric/` (MINISWHITE), `edge/` (BigTIFF, RowsPerStrip 1
and H, 1×N, N×1), `unsupported/` (LZMA, ZSTD, half float, palette, JPEG/YCbCr,
1-bit).

## The twin encodes our conventions (TODO_TIFF16.md §2)

- **Rows are flipped.** TIFF row 0 is the top row; FITS row 1 is the bottom.
- **Orientation is applied**, so the twin is the image as displayed.
  `make_tiff_fixtures.py` checks the stored raster against an independent reading of
  the tag definition (`displayed()`).
- **RGB(A) and stacks become cubes**, one plane per sample or page. Alpha is dropped,
  reduced-resolution pages (NewSubfileType bit 0) are skipped, and so are pages whose
  geometry differs from page 1.
- **MINISWHITE values are kept as stored**, not inverted.
- **uint16 and uint32** are written as astropy writes them (BZERO), so they read back
  as the same values.

## Running

```
~/miniforge/envs/ds9asdf/bin/python make_tiff_fixtures.py
~/miniforge/envs/ds9asdf/bin/python check_fixtures.py
```

For the probe, start ds9 with `xpans` on `PATH` and a title of its own (AGENTS.md),
then:

```
~/miniforge/envs/ds9asdf/bin/python check_probe.py DS9TiffProbe
```

The env needs numpy, astropy, tifffile and imagecodecs. tifffile and imagecodecs were
added to `ds9asdf` for this on 2026-11-22.
