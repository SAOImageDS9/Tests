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
arrays/   24 atypical ndarray descriptions (uncompressed)
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

**Status — 26 of 27 verified against their twin.**

| group | state |
|---|---|
| all 26 projections with a 1904-66 twin | **verified** — agree to 0.0250–0.0271″ |
| `healpix_polar` | loads, but **no XPH image exists** in the 1904-66 set, so it borrows HPX's header for parameters and has nothing to be checked against. Marked `verify_against: none` in its own metadata |

The residual on the verified 26 is **constant** at ~0.027″, and that is what
identifies it: it is the FK5 J2000 → ICRS frame bias, since the 1904-66 files
are `EQUINOX 2000` while these fixtures declare ICRS. A projection error would
not be identical across 26 different projections.

`zenithal_perspective` was the last one to join them, and for a while it was
the odd one out at 4195″ (1.17°) from its twin with demonstrably correct
parameters. The cause was in AST: ASDF's zenithal_perspective is the FITS
**AZP** projection, its `mu` and `gamma` being AZP's PV2_1 and PV2_2, but
`ReadSkyProjection()` sent it to `AST__SZP`, whose 2nd and 3rd parameters are
phi_c and theta_c — so gamma arrived as phi_c. The writer had the matching
half: two `type == AST__SZP` branches, the second of them unreachable, so
`AST__AZP` was never wired up in either direction. One token in each place.
Fixed in the project's vendored `ast/` and sent upstream; it now sits at
0.0250″, the same frame bias as every other projection here.

Each fixture carries the twin's **own pixel data**, copied byte for byte
(both sides are big-endian float32). So a readout from the fixture and from
the FITS file can be compared directly, and `asdf.sh`'s pixel samples mean
something rather than being self-referential.

### The θ₀ construction, which is the whole difficulty

AST's `rotate3d` with `native2celestial` is handed φ/θ/ψ and feeds them to a
FitsChan as CRVAL1/CRVAL2/LONPOLE *with a zenithal CTYPE*. So what it actually
wants is the celestial position of the **native pole** — which coincides with
CRVAL only when the projection's fiducial point is at the native pole,
(φ₀,θ₀) = (0°,90°). That holds for the zenithal family and nothing else:
conics sit at (0°,θ_a), and cylindricals, pseudo-cylindricals, quad-cubes,
Bonne, polyconic and HEALPix all sit on the native *equator*, (0°,0°).

Passing CRVAL regardless is what put 18 of these out by ~84°. Every file in
the set has LONPOLE − φ₀ = 180°, which collapses Paper II's general expression
to

    sin δ₀ = −cos(θ₀ + δ_p)   ⟹   δ_p = acos(−sin δ₀) − θ₀

and that reduces to δ_p = CRVAL2 when θ₀ = 90°, so one formula covers both
families. α_p is formally degenerate here because δ₀ = −90° puts the fiducial
on the celestial pole where α₀ means nothing; FITS fixes it by convention and
CRVAL1 is the value that reproduces the twin (the alternative is out by 53°).

`zenithal_perspective` is separate and genuinely broken upstream: its
parameters are right, but `yamlchan.c` maps it onto `AST__SZP` with
`pv1=mu, pv2=gamma`. AZP and SZP are different projections whose second and
third parameters mean different things (SZP's are φ_c/θ_c), so this is an AST
bug rather than anything these fixtures can work around.

Two things this exercise turned upTwo things this exercise turned up that are worth knowing independently of the
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
- **Both HEALPix branches in AST were dead code.** `ReadSkyProjection()` has
  handlers for `/healpix-` and `/healpix_polar-`, but `IsASkyProjection()` ORs
  six family recognizers and HEALPix is in none of them, so neither tag was
  ever recognized as a sky projection and both loaded with no WCS. Fixed
  locally in `ast/src/yamlchan.c`; another candidate to send upstream.

## GWCS transforms and frames (`transform/`, `frames/`)

`make_gwcs_transform_fixtures.py` covers the other half of what
`yamlchan.c` implements — the transforms, the combinators that glue them
together, and the celestial reference frames. These cannot be paired with a
1904-66 file (there is no FITS image whose WCS is "rotate2d by 30°"), so
instead each fixture maps pixel coordinates **straight to lon/lat with no
projection**, which makes the answer a closed-form calculation. Each fixture
carries its own expected value in its `meta` block, so the truth travels with
the file rather than living in a table that could drift:

```yaml
meta: {"primitive": "affine", "expect_at": [10.0, 20.0],
       "expect_lonlat": [21.0, 58.0], "expect_sky": "icrs"}
```

**23 of 26 verified exactly** — 0.0000″ for everything but `rotate2d` and
`rotate3d`, which come in at 0.0002″ (print precision, not error). `altaz`
joined them once the AST bug that had blocked it was found; see below.

| group | primitive | state |
|---|---|---|
| transform | identity, shift, scale, linear1d, multiplyscale, affine, rotate2d, remap_axes, concatenate, compose, rotate3d, planar2d, polynomial, divide, fix_inputs, spherical_cartesian, rotate_sequence_3d | **verified** (17) |
| transform | ortho_polynomial | builds a WCS (`has wcs wcs` = 1) but yields no readout — see below |
| frames | icrs, galactic, fk5, fk4, ecliptic | **verified** — identity transform, so lon/lat must equal the pixel in the frame's own system |
| frames | fk4noeterms, supergalactic | load and convert correctly, but DS9 has no display system for either, so only the ICRS conversion was checked |
| frames | altaz | **verified** to 2.8″ against astropy's own AzEl→ICRS, but read out in radians — see below |

The 2-in/1-out primitives — `polynomial`, `ortho_polynomial`, `planar2d` —
each need both pixel axes, so two of them concatenated want four inputs. A
`remap_axes` with `mapping: [0, 1, 0, 1]` duplicates `(x,y)` into
`(x,y,x,y)` to feed them. `divide` is `scale / constant`, chosen so the
quotient stays linear and checkable (and it exercises `constant` too).
`fix_inputs` pins axis 1 of a `planar2d`, leaving 1-in/1-out, and is
concatenated with a **unit scale** rather than with a second `fix_inputs`.
That asymmetry is deliberate. Two `fix_inputs` in one concatenate put two
2-in/1-out `planar2d`s into a parallel CmpMap, which trips a heap overread in
AST's `winmap.c` MapMerge (the project's `TODO.md`, AST bug 11): it reads one
element past the WinMap's scale/zero arrays, and what follows them in memory
decides the outcome. On macOS the WCS built and DS9 warned "the WCS has no
defined inverse"; on Linux the identical file failed with a CmpMap dimension
mismatch. A fixture whose answer depends on adjacent heap is worse than no
fixture, so this one uses the shape that is clean under AddressSanitizer.
One `fix_inputs` exercises the primitive just as well -- the second only
duplicated it.

The "no defined inverse" warning is still expected and still correct:
`fix_inputs` throws an input away, so no inverse can exist. It is the Linux
error, not the warning, that was the bug.
`spherical_cartesian` composes both directions, 2→3→2, so the result must be
the identity — which is what makes it verifiable at all.

Two conventions were settled by measurement rather than assumed, and are
recorded in the generator: `polynomial`'s coefficient matrix has the **row
index on x** (`sum c[i][j] x**i y**j`), and a **+90° `rotate_sequence_3d`
about z shifts longitude by −90°**.

`ortho_polynomial` is the interesting near-miss. AST builds the WCS, but
gives the Chebyshev no inverse, and DS9 produces no readout without one.
Plain `polynomial` escapes this because AST inverts a degree-1 one itself.
This also explains something visible in the real Roman WCS: its distortion
polynomials carry large explicit `inverse:` blocks. A faithful fixture would
supply one too; this one deliberately does not, and records
`expect_readout: no` in its own metadata so the absence is a stated fact
rather than a silent failure.

`shift`, `scale`, `linear1d` and `multiplyscale` are 1-in/1-out, so a 2-D WCS
has to pair them with `concatenate`; that is noted in each fixture rather than
glossed over. `concatenate` and `compose` get their own fixtures using
*different* children, so they test the combinator rather than the pair.

`altaz` was the last frame to work, and the reason it resisted is worth
recording, because the fixture was never at fault. `IsA()` dispatches on a
class prefix, and its branch tested
`strncmp( km_class, "astropy/coordinates/earthlocation/", 34 )` — **with a
trailing slash**. Astropy writes an EarthLocation as
`astropy/coordinates/earthlocation-1.2.0`, with no class component at all, so
that branch could never be entered and `IsAEarthLocation()` was dead code.
Comparing 33 characters instead fixes it, and the fixture then reads.

Two things made this expensive to find. The error named the *frame*
(`Property 'location' ... is not of the required class 'earthlocation'`),
which sends you to the serialization of the location rather than to the code
deciding whether to look at it. And the obvious suspect was innocent:
`MAKE_TEST(EarthLocation, astropy/coordinates/earthlocation, 1, 0)` builds the
odd-looking class `astropy/coordinates/earthlocation/EarthLocation`, but that
*does* prefix-match the real tag, because `strncasecmp` compares only up to
the version dash. The caller was wrong, not the test.

It now converts correctly: for the fixture's site and epoch, AzEl (16°,16°)
is ICRS 268.061422 +38.675185 by astropy's own reckoning, and DS9 gives
268.062201 +38.675213 — 2.8″ in RA, 0.1″ in Dec, which is the expected
AST-vs-astropy level for an AzEl conversion (refraction, UT1 and polar-motion
defaults differ). The baseline records the readout as `4.678568 0.6750098`
because DS9 prints it in **radians** despite `degrees` being asked for: there
is no azel display system, so the SkyFrame's format is never set. That is
left alone, since an AzEl WCS is not something a Roman product contains — and
note astropy cannot serialize an AltAz frame to ASDF at all, so this fixture
is necessarily synthetic.

The other four equatorial/ecliptic frames were fixed by two things. First, `yamlchan.c` validates a
Time's `format` against a short list — `iso`, `byear`, `jyear`, `jd`, `mjd`
— and errors on anything else, so astropy's own spellings (`jyear_str`,
`isot`) are rejected. Second, and more interesting, they were then
*silently wrong* rather than failing: see AST bug 3 below.

### Four AST bugs this turned up

None of these are in DS9, and all three are recorded in the project's
`TODO.md` as upstream candidates:

1. **Both HEALPix projections were dead code.** `ReadSkyProjection()` has
   handlers for them, but `IsASkyProjection()` ORs six family recognizers and
   HEALPix is in none, so neither tag was ever recognized. Fixed locally.
2. **`ReadLinear1d()` built its WinMap from an uninitialized variable.** It
   assigned `outa` twice — the second store overwriting the correct one — and
   never assigned `outb` at all. The resulting mapping was arbitrary and not
   even reproducible. Fixed locally; `linear1d` then lands exactly.
3. **`GetTime()` tested the wrong string for its epoch prefix.** Each branch
   read `strncasecmp(format, "B", 1)` where it meant `value` — asking whether
   the *value* already carries the prefix. Since `"jyear"` itself starts with
   a `j`, every branch was dead, so an equinox of `2000.0` reached
   `astUnformat()` with the TimeFrame's default format and was read as **MJD
   2000, i.e. 1864** — about 1.8° of precession from J2000. That is exactly
   what the FK4/FK5/ecliptic fixtures measured before the fix, and it is the
   nastiest of these bugs because the WCS loads and looks plausible.
   Fixed locally.
4. **`zenithal_perspective` is mapped to the wrong projection** (`AST__SZP`,
   whose 2nd/3rd parameters mean something other than AZP's). Not fixed — it
   needs an upstream decision, since AST does have an `AST__AZP`.

## Atypical ndarray descriptions (`arrays/`)

`fixtures/` varies the **codec** over a fixed set of ordinary C-contiguous,
big-endian arrays. `arrays/` varies the other axis: the ways `core/ndarray`
can describe an array that is not that. 24 files from
`make_ndarray_fixtures.py`, all uncompressed, all 64x64 where 2-D, and only
two types — int16 and float32 — since the point is the *description*, not the
type.

Most are written by the asdf library itself, so they are exactly what the
ecosystem emits rather than something hand-rolled to look plausible. That
matters most for the views: give asdf a non-contiguous numpy view and it
writes the **whole parent array** as the block and describes the view with
`strides`/`offset`. A 64x64 int16 parent is 8192 bytes on disk whether the
view is `[64, 64]` or `[32, 64]`, so the block's bytes are *not* the array,
and handing them to the loader would render the wrong pixels with no
complaint. That is the whole reason `asdf.tcl` refuses them.

| group | fixtures | expected |
|---|---|---|
| byte order | `int16_big`, `int16_little`, `float32_big`, `float32_little` | **load**, and the pair of each type must probe *identically* |
| offset | `int16_offset`, `float32_offset` (`a[8:]`, offset with no strides) | refused |
| offset | `int16_offset_zero` (`offset: 0` written out) | **loads** — a zero offset is just the default spelled out |
| strides | `int16_strides_skip`, `float32_strides_skip` (`a[::2]`) | refused |
| strides | `int16_strides_fortran` (column-major) | refused |
| strides | `int16_strides_slice` (`a[8:40, 8:40]` — offset *and* strides, the schema's own example) | refused |
| strides | `int16_strides_negative`, `..._negative_both` (`a[::-1]`) | refused |
| shape | `int16_rank0` (shape `[]`), `int16_rank1` (`[100]`) | refused |
| shape | `int16_plane1` (`[1, 64, 64]`) | **loads** as a one-plane cube |
| dtype | `uint16` | **loads** at bitpix **-16** |
| dtype | `uint32`, `float16` | **load**, widened to 64 and -32 |
| dtype | `int8`, `uint64`, `complex64`, `struct2d` | refused |
| malformed | `int16_no_byteorder` | refused — see below |

**All 24 behave as documented**, one of them only after the reader was changed to suit it (`int16_no_byteorder`, below). The three dtype rows worth having are
`uint16`, `uint32` and `float16`: `asdf.tcl`'s mapping table claims -16 for
the first and lossless widening for the other two, all three occur on real
Roman arrays (`dq` is uint32, `err`/`var_poisson` are float16), and until now
nothing exercised any of them — `uint32` and `float16` are also the only path
through `asdfconvert`'s widening in C. Their values are chosen so a misread
cannot hide: uint16 holds values above 32767 (a signed read would go
negative), uint32 above 2^31 (a signed-32 read would wrap), and float16
carries its own maximum, 65504, exactly. All read correctly.

Every refusal names its reason, and the compound cases name both parts:

```
ASDF: unsupported ndarray view data (strides, offset)
ASDF: unsupported ndarray datatype uint64
ASDF: unsupported ndarray rank data [100]
```

`struct2d` is the one that was genuinely in doubt. A structured (record)
dtype writes `datatype` as a multi-line YAML **list** of named fields, each
entry carrying its own `datatype:` and `byteorder:` — so a field parser
scanning the node body line by line could pick up `datatype: float32` from a
nested entry and load the record array as float32, which would be wrong
pixels rather than an error. It does not: the array is refused. The message
names no type (`unsupported ndarray datatype` with nothing after it), because
the scalar value is empty when the list is on the following lines, which is
cosmetic rather than wrong.

`int16_rank0` is refused as `ambiguous or unknown array` rather than by rank,
because `AsdfEnumFlush` drops a node whose shape is empty before anything
else sees it, so the path is never enumerated at all.

**`int16_no_byteorder` is the one that changed the reader.** It is one of the
two hand-written fixtures here, along with `int16_offset_zero`; asdf will
emit neither, since it omits a zero offset, and the ndarray schema's
`dependencies` make `shape`, `datatype` and `byteorder` all mandatory
whenever `source` is present, so a block-backed array without byteorder
cannot legally exist.

It used to load. `asdf.tcl` defaulted to little-endian when the field was
absent, so this big-endian payload came in with **every pixel byte-swapped**
and nothing said so: 2015 read as -8441 and 4095 as -241, which is exactly
`0x07DF` -> `0xDF07` and `0x0FFF` -> `0xFF0F` taken as signed. The default
looked harmless because an inline `data:` array genuinely needs no
byteorder — but the enumerator never sees an inline array (it requires
`source`), so the default only ever applied where the field is mandatory,
which means only to malformed files. It now refuses:

```
ASDF: ndarray has no byteorder data
```

The fixture is what makes that a test rather than a claim, and it is why the
file is worth keeping even though no valid file looks like it.

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
python3 Tests/asdf/make_ndarray_fixtures.py   # the arrays/ family
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
