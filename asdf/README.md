# ASDF FITS test suite (Phase 5 fixtures)

`fixtures/` holds 108 small ASDF files (27 source images x 4 block-compression
codecs), converted from this test suite's own sample FITS images (`../fits/`
— read-only source, nothing was written back into it). Built for the
`SAOImageDS9/asdf_format` project's Phase 5 "generalize beyond Roman's fixed
paths" work — see that repo's `TODO.md` Phase 5 and
`ASDF_NATIVE_SUPPORT_DESIGN.md` for the design context this test suite exists
to serve (those documents live in the `asdf_format` checkout, not here).

## Layout

```
fixtures/
  none/   char.asdf, char_blank.asdf, ..., short_bscale.asdf   (uncompressed)
  zlib/   same 27 files, zlib-compressed blocks
  bzp2/   same 27 files, bzip2-compressed blocks
  lz4/    same 27 files, lz4-compressed blocks
```

21 come from `convert_fits_to_asdf.py`; the 6 `*_blank_scalar` files come
from `make_scalar_mask_fixtures.py` (see "Scalar masks" below).

Each `.asdf` file has a flat, non-Roman tree — deliberately **not** nested
under a top-level `roman:` mapping the way the real Roman products Phases
1-3 were built against are:

```yaml
data: !core/ndarray-1.1.0
  source: 0
  datatype: float64
  byteorder: big
  shape: [256, 256]
meta: {source_fits_file: double_nan.fits, original_bitpix: -64, ...}
```

This is intentional, and it is the point of the fixtures: the `asdf_format`
project's Phase 2/3 reader only looked for keys at a Roman-specific
indent/nesting (2-space direct children of `roman:`, or 4-space under
`roman.meta:`), so a flat `data:` was invisible to it.

**Phase 4 changed that, and all 27 now load.** Its `AsdfEnumNdarrays` walks
the whole tree and gives every `core/ndarray` a root-relative path, and a
bare name resolves either as `roman/<name>` or — failing that — as any
*uniquely* matching path, so plain `data` is found here without a
Roman-style prefix. Verified against the real reader: with bzip2 support
added in Phase 5, all **108/108** fixtures load — all 27 in each of the four
codec directories — with dimensions and `minmax` both matching DS9's own
reading of the source FITS image in every case.

These fixtures still exist for that project's Phase 4/5 generalization work
rather than as a Roman regression check — and they have already paid for
themselves there. The four masked `_blank` files caught a silent misread in
Phase 4's enumerator: a `mask:` ndarray nested inside `data:` had its
`source:` merged into the parent, so `data` read the boolean mask block as
if it were the image. In `char_blank` specifically that is undetectable by
size alone, because `uint8` data and a `bool8` mask are both one byte per
element. Fixed in `asdf_format` by making the enumerator stack nested
ndarrays; `data` and `data/mask` are now separate paths.

## Source images and what each exercises

All from `../fits/` in this same Tests repo. Two different conversion paths,
depending on whether the source FITS file has a `BLANK` keyword:

- **No `BLANK`** (baseline files, `_bscale` files, `_nan`/`_inf` float files):
  read with astropy's normal default scaling (`fits.getdata()`), which
  applies `BSCALE`/`BZERO` and yields the same physical pixel values DS9
  already renders from the FITS file. `core/ndarray` has no `BSCALE`/`BZERO`
  concept of its own, so this resolves the FITS convention into plain
  physical values rather than carrying it through as metadata.
- **Has `BLANK`** (the four `_blank` files): read raw
  (`do_not_scale_image_data=True`, no rescaling needed for these — none set
  real `BSCALE`/`BZERO`) and represented as a **numpy masked array**
  (`np.ma.masked_array(raw, mask=(raw == BLANK))`). `asdf` serializes this
  natively as a `mask:` sibling ndarray next to `data:` — confirmed by
  inspecting the written YAML, not assumed:
  ```yaml
  data: !core/ndarray-1.1.0
    source: 0
    mask: !core/ndarray-1.1.0
      source: 1
      datatype: bool8
      byteorder: big
      shape: [256, 256]
    datatype: uint8
    byteorder: big
    shape: [256, 256]
  ```
  This keeps the **original integer dtype** intact — converting `BLANK`
  pixels to NaN the way astropy's default scaling does would force the whole
  array to float, defeating the point of an integer-with-nulls fixture.

| file | dtype written | what it exercises |
|---|---|---|
| `char.fits` | `uint8` | baseline 8-bit integer |
| `char_blank.fits` | `uint8` + mask | `BLANK` sentinel, integer dtype preserved |
| `char_bscale.fits` | `float32` | `BSCALE`/`BZERO` rescaling |
| `short.fits` | `>i2` | baseline 16-bit integer (big-endian) |
| `short_blank.fits` | `>i2` + mask | `BLANK`, integer dtype preserved |
| `short_bscale.fits` | `float32` | `BSCALE`/`BZERO` |
| `int.fits` | `>i4` | baseline 32-bit integer |
| `int_blank.fits` | `>i4` + mask | `BLANK`, integer dtype preserved |
| `int_bscale.fits` | `float64` | `BSCALE`/`BZERO` |
| `long.fits` | `>i8` | baseline 64-bit integer |
| `long_blank.fits` | `>i8` + mask | `BLANK`, integer dtype preserved |
| `long_bscale.fits` | `float64` | `BSCALE`/`BZERO` |
| `float.fits` | `>f4` | baseline float32 |
| `float_bscale.fits` | `>f4` | `BSCALE`/`BZERO` on float data |
| `float_nan.fits` | `>f4` | real IEEE NaN pixels |
| `float_inf.fits` | `>f4` | real IEEE +Inf pixels |
| `double.fits` | `>f8` | baseline float64 |
| `double_bscale.fits` | `>f8` | `BSCALE`/`BZERO` on double data |
| `double_nan.fits` | `>f8` | real IEEE NaN pixels |
| `double_inf.fits` | `>f8` | real IEEE +Inf pixels |
| `img.fits` | `>f4` | larger (800x800) generic image |

`table.fits` and `healpix_partial.fits` (also in `../fits/`) were
deliberately excluded — a binary table and a HEALPix pixelization aren't
plain image arrays, out of scope for the `core/ndarray`-only reader the
`asdf_format` project builds.

## Scalar masks

`core/ndarray`'s `mask` is `anyOf` **a scalar number**, a `complex-1.0.0`, or
a `bool8` ndarray — quoting the schema, "If a scalar number, that number is
used to represent missing values. If an ndarray, the given array provides a
mask, where non-zero values represent missing values in this array. The mask
array must be broadcastable to the dimensions of this array." The scalar form
is therefore the FITS `BLANK` convention exactly, and it is a documented
example in every schema version (`ndarray-1.0.0`/`1.1.0`/`1.2.0`) — in each
case as `mask: -999` on **`float64`** data, so its headline use is floating
point rather than integer.

The `_blank` files above use the ndarray form. The 6 `*_blank_scalar` files
use the scalar form:

| file | data | scalar mask | what it exercises |
|---|---|---|---|
| `char_blank_scalar` | `uint8` | 128 | must render identically to `char_blank.fits` |
| `short_blank_scalar` | `>i2` | 256 | ditto `short_blank.fits` |
| `int_blank_scalar` | `>i4` | 256 | ditto `int_blank.fits` |
| `long_blank_scalar` | `>i8` | 256 | ditto `long_blank.fits` |
| `float_blank_scalar` | `>f4` | 255.0 | scalar mask on float data (the schema's own example case) |
| `double_blank_scalar` | `>f8` | 255.0 | ditto, float64 |

The four integer ones deliberately reuse the **source FITS file's own
`BLANK`**, so a correct reader must render them identically to that FITS
file — which makes the comparison unambiguous. The float sentinel is picked
as a value that genuinely occurs in the data (255.0, 256 pixels), so the
fixture actually masks something; the generator asserts that rather than
assuming it.

These need a separate generator because **asdf's Python writer cannot emit a
scalar mask**: its ndarray converter does `result["mask"] = data.mask`
unconditionally, so a numpy masked array always serializes as a boolean
array. asdf *reads* the scalar form fine
(`NDArrayType._apply_mask` -> `ma.masked_values`), it simply never writes it.
Files carrying one come from other writers, which is exactly why a reader
needs testing against them.

So `make_scalar_mask_fixtures.py` builds each output by **re-treeing an
existing fixture**: the data block is copied over byte for byte and only the
YAML tree is rewritten and the block index recomputed. That covers all four
codecs — **including `lz4`, with no compressor needed** — and guarantees the
pixel bytes are identical to the sibling fixture.

```
python3 make_scalar_mask_fixtures.py
```

Every output is read back with `asdf.open()` and checked against the original
FITS for dtype preservation, exact mask positions, and unmasked pixel
equality, 24/24, before being treated as done. One wrinkle worth knowing if
you write similar checks: `asdf.open()` returns a lazy `NDArrayType`, and the
mask is applied only when it is materialized — a validator has to slice it
(`af["data"][:]`) or it will wrongly conclude there is no mask.

## Compression codecs

The 4 directories are every codec `asdf`'s Python library actually supports
for writing (confirmed via `asdf._compression.validate`'s `builtin_labels`,
not assumed — the fourth builtin label, `"input"`, means "keep whatever
compression an already-read block had" and isn't meaningful for a fresh
write, so it's excluded here):

- **`none`** — uncompressed, raw block.
- **`zlib`** — already supported by `ds9/library/asdf.tcl`'s `AsdfReadBlock`.
- **`lz4`** — already supported (via the `tclasdf` extension's
  `asdflz4decompress`, per Phase 0/2).
- **`bzp2`** (bzip2) — supported as of Phase 5, and these fixtures are what
  it was built against. Unlike lz4 (which has no stream format, so asdf
  frames it as length-prefixed chunks), a bzp2 block payload is a single
  plain bzip2 stream: every payload here starts with the `BZh9` magic at
  byte 0 and the block header's `used` field is the whole compressed
  length.

## GWCS primitives (`gwcs/`)

The 108 fixtures above are about the *container* — codecs, dtypes, masks. They
say nothing about the WCS: they have none, and every real Roman file uses the
same projection (TAN), so until now exactly one of the sky projections
`ast/src/yamlchan.c` implements was ever exercised.

`make_gwcs_fixtures.py` writes one fixture per projection into `gwcs/`, built
from the matching file in `../wcs/` — the Calabretta & Greisen 1904-66 set,
which is one FITS image per projection code over the same field. That choice
buys two things: the parameters are the canonical ones rather than invented,
and DS9 can read the FITS twin, so each fixture has an independent reference
instead of only "it loaded". The parameter names come from
`ReadSkyProjection()` in `yamlchan.c`, which is the only authority that
matters — it is what parses them.

```
python3 asdf/make_gwcs_fixtures.py
```

**Status — 7 of 27 are verified; the rest are not, and deliberately have no
baselines yet.** `asdf.sh` will report them as `NO BASELINE`, which is the
correct signal: they exist and load, but their WCS is not blessed.

| group | state |
|---|---|
| gnomonic, airy, stereographic, zenithal_equal_area, zenithal_equidistant, slant_orthographic, slant_zenithal_perspective | **verified** — agree with their twin to 0.0266–0.0269″ |
| conic_×4, cylindrical_×2, mercator, plate_carree, hammer_aitoff, molleweide, parabolic, sanson_flamsteed, polyconic, bonne_equal_area, 3 quad-cubes | wrong by ~84° — see below |
| zenithal_perspective | wrong by ~6500″, looks like an AST bug |
| healpix, healpix_polar | build no FrameSet at all, undiagnosed |

The residual on the verified seven is **constant** at ~0.027″, and that is what
identifies it: it is the FK5 J2000 → ICRS frame bias, since the 1904-66 files
are `EQUINOX 2000` while these fixtures declare ICRS. A projection error would
not be identical across seven different projections.

The ~84° group fails for a structural reason, not a parameter slip. FITS puts
the fiducial point of a *zenithal* projection at the native pole,
(φ₀,θ₀) = (0°,90°), but at the native *equator*, (0°,0°), for conics,
cylindricals, pseudo-cylindricals and the quad-cubes. A single
`rotate3d(CRVAL1, CRVAL2, LONPOLE)` is the correct native→celestial rotation
only in the first case, so those need the θ₀=0 construction instead.

`zenithal_perspective` is separate and more interesting: its parameters are
right, but `yamlchan.c` maps it onto `AST__SZP` with `pv1=mu, pv2=gamma`.
AZP and SZP are different projections whose second and third parameters mean
different things, so this looks like a genuine AST bug and a candidate to
report upstream.

Two things this exercise turned up that are worth knowing independently of the
fixtures:

- **`axis_physical_types` is effectively mandatory.** It reads like metadata,
  and `yamlchan.c` fetches it with a not-required flag, but without it on both
  frames AST builds no FrameSet and the file loads its pixels with no WCS and
  no error. Found by bisection — a fixture containing nothing but
  `transform: identity` failed until those two lines were added.
- **DS9 feeds its image coordinate straight into the GWCS**, with no
  1-based/0-based correction, which is the opposite of what the FITS↔gwcs
  convention difference suggests. The identity fixture reads sky (4,4) at
  image (4,4). So the shift offset here is `-CRPIX` exactly; `-(CRPIX-1)`
  moves everything one pixel, which at this plate scale is 240″.

## Running them

`../asdf.sh` drives these through DS9, and is wired into `../io.sh` along with the
other format tests (`nrrd.sh`, `envi.sh`, `photo.sh`). It follows the suite's
usual shape: a `command` section, an `xpa` section, an optional leading
`slow`, and the `.sav`/`.out` baseline idiom `ciaoregs.sh` uses.

```
./asdf.sh              # both sections
./asdf.sh command      # command line only: ds9 -asdf <file> -exit
./asdf.sh xpa          # load over XPA and diff against the baselines
./asdf.sh save         # (re)create the baselines
./asdf.sh slow xpa     # add a sleep between files
```

**Files are found, not listed.** The script does
`find asdf -name '*.asdf' -type f | sort`, so dropping a new file anywhere
under `asdf/` — including at the top level, not just in `fixtures/<codec>/` —
picks it up with no edit to the script. A file with no baseline yet is
reported as

```
 aaa_newfile_test.asdf
  NO BASELINE -- run './asdf.sh save' to create aaa_newfile_test.asdf.sav
    size 256 256
    bitpix 16
    ...
```

which prints the values so they can be eyeballed before `save` accepts them.
`save` regenerates every baseline, so review `git diff` afterwards rather
than trusting it blindly — that diff is the actual test result when something
has changed on purpose.

Unlike most of the suite, this is more than a smoke test. Each file's
baseline records what DS9 actually made of it:

```
size 256 256
bitpix 16
blank 256
value 1 1 0
value 128 128 254
value 256 256 510
wcs none
```

The pixel samples are the part that earns its keep. An ASDF file can load at
the wrong shape, or from the wrong array, and still "work" — a Roman
`*_cal.asdf` has 15 arrays of identical shape *and* identical WCS, so size
alone cannot tell them apart. The sample coordinates are derived from the
reported size rather than hardwired, so the probe stays valid for any shape,
from a 4x4096 reference strip to a 5000² coadd. `blank` catches the
integer-null sentinel on the `_blank`/`_blank_scalar` files, and `wcs` reads
`none` for these flat fixtures but becomes the single most valuable number in
the file if a real Roman product is dropped in.

## Regenerating

```
pip install asdf   # installs into user site-packages; no conda env needed
python3 Tests/asdf/convert_fits_to_asdf.py    # from this repo's root, or
cd Tests/asdf && python3 convert_fits_to_asdf.py   # from here directly
```

Requires `astropy`, `asdf`, and `numpy` (also used by the sibling
`asdf_format` checkout's own Python tooling — see its `utils/asdf_gwcs_probe/`
— but not a dependency of this Tests repo otherwise). Paths are resolved
relative to the script's own location, so it works from either invocation
above. Re-running overwrites `fixtures/` in place.

Every fixture was round-trip validated after generation — read back with
`asdf.open()` and compared against the original FITS pixel values (NaN
positions and non-NaN values for the float files; mask positions, unmasked
values, and dtype for the 4 masked `_blank` files) across all 21 files x 4
codecs, 84/84 passing, before being treated as done.
