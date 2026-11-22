# TIFF fixtures (`TODO_TIFF16.md`, Phases 0–2)

Test files for DS9's native full-depth TIFF reader. They were made before the reader
exists, from Python and with no help from libtiff. Each `<name>.tif` has a twin,
`<name>.fits`, holding the same samples as DS9 should present them.

| Path | What |
|---|---|
| `make_tiff_fixtures.py` | Writes every fixture, its twin, and `MANIFEST.tsv`, using tifffile. Deterministic: a rerun is byte-identical. |
| `check_fixtures.py` | Reads every fixture back with tifffile and checks its tags against the manifest and its pixels against the twin. Expect 108 checked, 0 failed. |
| `check_probe.py` | Runs fitsy's libtiff probe (`fitsy tiff decode`) inside a live ds9 over XPA, and compares directory 0's tags and nsamples/min/max/sum with the manifest. For `refuse` entries it prints what libtiff says. Expect 102 probed, 0 failed. |
| `check_load.py` | Phase 1: has a live ds9 load every fixture with the frame's `load tiff` and write it back with `save fits file`. Grayscale fixtures must equal their twin pixel for pixel (directory 0 only), with the expected in-memory BITPIX from `get fits header` and a header astropy parses. `header/texttags_u2.tif`'s CREATOR/DATE/OBSERVER/COMMENT cards are checked exactly. Everything else must be refused with a `tiff: ...` reason. Expect 89 loads and 19 refusals, 0 failed. |
| `check_entry.py` | Phase 2: every way a TIFF reaches ds9 picks the right reader. That covers XPA by file name and by data, each mode keyword and the preference, slice, mask, the SAMP path, recent files, backup/restore, and the command line (`-tiff`, `-tiff native/photo`, `-tiff -`, `-mask -tiff native`). It starts and restarts its own ds9 (title `DS9TiffEntry`) and keeps the user's recent-files list as it was. Expect 27 checks, 0 failed. |
| `MANIFEST.tsv` | One row per fixture: `expect` (`load`/`refuse`), the tags as stored, and the probe's expected statistics. |

Families: `dtype/` (u1 u2 i2 u4 i4 f4 f8 × none/PackBits/LZW/Deflate 8/Deflate
32946), `tiled/`, `byteorder/` (MM), `predictor/` (2 and 3), `rgb/` (contig and planar,
strip and tile, RGBA), `pages/` (stacks, a reduced-resolution page, mixed geometry),
`orientation/` (1–8), `photometric/` (MINISWHITE), `header/` (Software,
DateTime, Artist and ImageDescription, long and with quotes), `edge/` (BigTIFF, RowsPerStrip 1
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
~/miniforge/envs/ds9asdf/bin/python check_load.py DS9TiffProbe
~/miniforge/envs/ds9asdf/bin/python check_entry.py    # starts its own ds9
```

Two things about `check_load.py` that are ds9's behaviour, not the reader's. ds9's
`save fits` writes BITPIX -16 (fitsy's unsigned 16) as BITPIX 32, losslessly, so
BITPIX is read from the in-memory header instead. It also writes a 1×N image as 1-D,
so shapes are compared squeezed. Both were confirmed by sending the FITS twins
through the same path.

To catch heap overruns, run ds9 under Guard Malloc:
`DYLD_INSERT_LIBRARIES=/usr/lib/libgmalloc.dylib .../MacOS/ds9 -title DS9TiffGM &`.
Don't launch it through `nohup`, because SIP strips `DYLD_*` variables. Check with
`vmmap <pid> | grep libgmalloc`.

The env needs numpy, astropy, tifffile and imagecodecs. tifffile and imagecodecs were
added to `ds9asdf` for this on 2026-11-22.
