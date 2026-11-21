# XISF fixtures (Phase 0 of `TODO_XISF.md`)

Test files for DS9's native XISF reader, made **before** the reader exists.
Every file's expected DS9 result is already recorded, as a `.sav` probe
baseline in the same format `../asdf.sh` uses.

## Layout

| Path | What |
|---|---|
| `make_xisf_fixtures.py` | Writes every synthetic `.xisf`, its FITS twin, and `MANIFEST.tsv`. No XISF library: bytes are laid out by hand, so each layout choice the spec allows can be made on purpose. Deterministic: a rerun is byte-identical. |
| `read_xisf.py` | An independent minimal decoder, sharing no code with the generator. `check` decodes every manifest entry and compares it with its twin, or confirms it is refused. `twin` writes a twin for a file we did not generate. `dump` lists images. |
| `make_baselines.sh` | Loads each FITS twin into *today's* DS9 and records the probe as `<fixture>.xisf.sav`. Refused fixtures get the empty-frame probe. |
| `crosscheck_sergio.py` | Runs a third-party reader, [sergio-dr/xisf](https://github.com/sergio-dr/xisf) (GPL-3.0), over every manifest entry. Point it at a checkout's `src/`. |
| `check_container.py` | Check of fitsy's container reader (Phases 1–2): runs `utils/xisfdump` over every file and compares each image's verdict, stored bytes and **decoded** bytes with `read_xisf.py`. Refusals only `block()` can make (bad checksum, a subblock decoding to the wrong size) are checked there, and Phase 3 refusals are listed as DEFERRED. Expect 0 failures, 8 BLOCK, 1 DEFERRED. |
| `check_fits.py` | Phase 3 check of `FitsXisf`, the FitsFile ds9 loads: runs `utils/xisfdump --fits` over every file and compares dimensions, BITPIX and every plane's samples with the twin, loads the other images of multi-image files by id/index, requires a message for every refusal, checks the header carries no BZERO/BSCALE/BLANK, and compares its WCS with the twin's numerically (same sky position to 1e-9° on a pixel grid; no WCS where the twin has none). Expect 0 failures. |
| `check_ds9_wcs.sh` | Phase 4: the reader's exact header cards plus the twin's pixels, loaded into ds9, must reproduce every `wcs/` fixture's probe baseline, so AST reads the reader's WCS as it reads the twin's. Run with `sh`. Expect 19 passed. |
| `MANIFEST.tsv` | `fixture  expect  bitpix  notes` for the 107 synthetic files. `expect` is `load`, `load-first` (multi-image: the twin is the default image) or `refuse`. |
| `real/MANIFEST.tsv`, `real/libxisf/`, `real/xisfits/` | 14 real files from two other projects' test suites: 11 written by PixInsight (1.8.6 and 1.8.9), 2 by libXISF. See below. |

Families: `formats/` (every sampleFormat, non-finite values, bounds),
`codecs/` (zlib/lz4/lz4hc/zstd × ±byte-shuffle, subblocks, raw subblocks, an
item size that does not divide the block), `storage/` (RGB planar/normal,
3-D cubes, depth 1, CIELab, RGBA), `byteorder/`, `location/` (embedded base64
and hex, multi-image, forbidden `inline:`/`url()`/`path()`), `checksum/`
(all five algorithms, bad digests), `header/` (FITSKeywords with escapes and
stale structural cards, a signed unit, comments and foreign elements,
Thumbnail, pedestal, nonzero reserved bytes, no `encoding=`), `wcs/` (layer 1
in all seven projections, GCRS, unknown projection, incomplete or unknown
layer 3, keywords vs properties precedence, top-down keyword-only WCS, the legacy `PCL:AstrometricSolution:` prefix, an unsupported solution Version, and a file shaped exactly like PCL 2.15 output), and `malformed/`.

## The twin is the oracle, and it encodes our conventions

`<name>.fits` holds the same pixels as `<name>.xisf`, as DS9 should present
them. The conversions it bakes in are the ones `TODO_XISF.md` §2 commits to:

- **Rows are flipped.** XISF stores rows top to bottom (spec §8.5, Figure 2),
  and FITS row 1 is the bottom.
- **Pixel centres.** XISF (i, j) is centred at (i+0.5, j+0.5) (§8.5.2), so
  `CRPIX1 = x_ref + 0.5` and `CRPIX2 = H - y_ref + 0.5`.
- **The linear matrix.** `LinearTransformationMatrix` M is row-major,
  applied to (x−x₀, y−y₀). The flip negates its second column, giving
  `CD = [[M00, −M01], [M10, −M11]]`. **Confirmed against PCL 2.15.0**, PixInsight's
  reference implementation (<https://gitlab.com/pixinsight/PCL>).
  `AstrometricMetadata::ToProperties` writes `Matrix(A00, A01, A10, A11)` of its
  image-to-world transform, with `ReferenceImageCoordinates = TransformInverse(0)`.
  Its `ComputeWCSKeywords` converts to FITS through `x_I = x_F − 0.5`,
  `y_I = H + 0.5 − y_F`, which is the twin's conversion to the letter.
- **Projections.** Gnomonic→TAN, Stereographic→STG, ZenithalEqualArea→ZEA,
  Orthographic→SIN, PlateCarree→CAR, Mercator→MER, HammerAitoff→AIT. The spec
  names no codes; this is PCL's own table (`ProjectionBase.cpp`).
- **WCS keywords stored with an image are top-down.** PCL's `WCSKeywords.h`: in
  PixInsight, WCS keywords "refer to the pixel data of the image as stored in
  memory, where the first row is the top row", and its FITS module mirrors them
  when file and memory row orders differ. So a keyword-only solution
  (`wcs/keywords_only`) is put through PCL's `MirrorVertically` for the
  row-flipped twin: `CRPIX2 → H+1−CRPIX2`, and `CD1_2`/`CD2_2` (or `CDELT2`
  with no PC matrix) negated, and the SIP terms (A/AP for odd q, B/BP for even q).
  The generator re-derives each mirrored twin's sky positions with astropy before
  writing it, so a wrong rule cannot produce a twin. **Caveat:** PCL's own `ComputeWCSKeywords`
  writes *bottom-up* keywords next to the properties in every solved XISF it
  saves, which contradicts that documented convention. PixInsight never reads
  them back, because the properties win. A DS9 reader must not use them when
  properties are present (`wcs/pcl_shaped`, `wcs/properties_beat_keywords`).
- **BITPIX.** UInt8→8, UInt16→−16 (fitsy's private unsigned code),
  UInt32/UInt64→64, Float32→−32, Float64→−64. The twin itself stores UInt16 as
  16+BZERO, so `make_baselines.sh` takes the bitpix line from the manifest.

If real PixInsight output ever disagrees with a twin, the convention is what
is wrong. Fix it in the generator, regenerate, and rerun the baselines.

## Running against ds9

`../xisf.sh` (from `Tests/`) drives ds9's own `xisf` command:
- `xpa` compares every fixture with its baseline;
- `command` does one `-xisf` launch per file;
- `mask` checks that a mask leaves the image alone;
- `extra` covers image selection, error messages, the header viewer and
  backup/restore.

It has no `save` mode: the baselines come from the twins, through
`make_baselines.sh`, never from the reader.

## Regenerating

```bash
~/miniforge/envs/ds9asdf/bin/python make_xisf_fixtures.py
~/miniforge/envs/ds9asdf/bin/python read_xisf.py check      # expect 107/107
~/miniforge/envs/ds9asdf/bin/python crosscheck_sergio.py <xisf checkout>/src  # expect 115/121
make -C ../../utils/xisfdump && ~/miniforge/envs/ds9asdf/bin/python check_container.py ../../utils/xisfdump/xisfdump
~/miniforge/envs/ds9asdf/bin/python check_fits.py ../../utils/xisfdump/xisfdump
PATH=<dir with ds9 + xpa tools>:$PATH sh check_ds9_wcs.sh
PATH=<dir with ds9 + xpa tools>:$PATH sh make_baselines.sh  # AGENTS.md: macOS shim
```

The generator needs numpy, astropy, lz4 and zstandard. zstandard was added
to the `ds9asdf` conda env for this on 2026-11-21.

## The real files

### `real/libxisf/`

From libXISF's test directory
(<https://gitea.nouspiro.space/nou/libXISF/src/branch/master/test>, GPL-3.0),
fetched 2026-11-21. Their twins were written by `read_xisf.py twin`, and every
decode was checked against libXISF's own `main.cpp` assertions: the
endian files' pixels equal their storage index in both images, and
`test.xisf` equals `test_lz4.xisf`.

What they showed that the spec alone did not:

- **PixInsight copies stale structural cards into `FITSKeyword`.** `test.xisf`
  (PixInsight 1.8.9, from an INDI capture) has 0–9 UInt16 pixels and carries
  `BITPIX = 16`, `BZERO = 32768`, `DATAMIN/DATAMAX`. A reader that honoured
  that BZERO would display 32768–32777.
- **String keyword values keep their FITS quotes and padding:** `'Unknown '`.
- **`ROWORDER = 'TOP-DOWN'`** is present, the INDI convention for the source
  FITS file.
- **A `<Thumbnail>` whose attachment points past EOF** (`attachment:8192:128000`
  in a 5466-byte file). Thumbnails must be skipped, not validated.
- **PixInsight really writes raw subblocks.** `subblock-lz4hc-sh.xisf` has
  subblocks `4194304,4194304:2642749,4194304:2810,9796`; the first is stored
  raw.
- **libXISF bends the header rules.** It omits `encoding="UTF-8"` from the XML
  declaration, puts `byteOrder` on scalar properties, and writes `subblocks`
  even for a single block. Readers should tolerate all three.
- **`XISF:CreationTime` is typed `String`, not `TimePoint`,** in PixInsight
  1.8.9's output.

### `real/xisfits/`

From the test images of xisfits, a Rust XISF-to-FITS converter
(<https://github.com/vrruiz/xisfits>, MIT), fetched 2026-11-21. All nine were
written by PixInsight 1.8.6. Note that `xisf-image-rgb-256x256-8bits-compressed.xisf` is
actually a Gray image (embedded zlib). The upstream name is kept on disk.

- **PixInsight writes RGB as Planar.** The three RGB files have no `pixelStorage`
  attribute, which means the Planar default.
- **An inline `<ICCProfile>`** sits on each RGB image; the reader must skip it.
- **Most of these images are constant.** The RGB ones are one value per plane
  (full, half, quarter scale). That tests channel order and the planar layout,
  but **cannot detect a row flip**. Only the two 16-bit zlib images vary.
- xisfits itself writes FITS rows in XISF storage order, without flipping, so its
  FITS output is upside-down relative to PixInsight's display. Implementations
  disagree on this point, so its output is not evidence either way.

None of the real files carries an astrometric solution or uses Normal storage.
A plate-solved PixInsight file is the most valuable thing still missing.

## Third-party cross-check

`crosscheck_sergio.py` agrees with the manifest on 115 of 121 files, including
every real file it can read. Each disagreement is explained:

| Fixture | sergio-dr/xisf | Why |
|---|---|---|
| `formats/uint64` | refuses | UInt64 is not implemented there. |
| `header/signed` | refuses | It parses the trailing `<Signature>` sibling and fails; the spec allows it. |
| `header/empty_vector_property`, both `real/libxisf/*endian` | crash | An empty inline vector (`length="0"`, no content) yields `None`. The synthetic fixture was written to reproduce exactly this. |
| `malformed/version_2` | loads | It does not check `version`. We refuse, as the spec requires `"1.0"`. |

## Gotchas

- **Tolerance policy.** Refuse what makes the pixels unknowable (bad layout,
  codec, checksum, geometry, version). Tolerate writer slips that do not:
  nonzero reserved bytes, a missing `encoding=`, and a float image without
  `bounds` (it only sets the display range, which DS9 computes anyway).
- **Short subblocks need their own fixtures.** If a subblock's declared size is
  larger than its real one, and the total still matches the geometry, some other
  subblock must overflow. Every codec rejects an overflow on capacity alone, which
  hides a reader that never checks each decoded size. `malformed/subblock_short_*`
  make every subblock short instead (the data is short overall). Without them, a
  reader with that check removed passed every test.
- **Check the codec name before the raw-subblock rule.** A block with no
  `subblocks` attribute and an unknown codec, whose stored size happens to
  equal its declared size, looks exactly like a raw subblock.
  `malformed/unknown_codec.xisf` is built that way, and the first `read_xisf.py`
  loaded it.
- **DS9 prints −Inf as `inf`** in `xpaget data image`, for FITS too, so
  `formats/*_nonfinite` baselines cannot tell +Inf from −Inf. `read_xisf.py
  check` can.
- As in the ASDF suite, the probe reads **slice 1 only**. Cube and RGB
  baselines check plane 1. Use `scale limits` for the other planes.
