# HiPS test samples

Partial copies of public HiPS, fetched 2026-11-15 for the work in
`TODO_HIPS.md` (Phase 0). Each directory keeps the HiPS's own layout
(`properties`, `Moc.fits`, `NorderK/...`), so it can be loaded as a
local HiPS root. Only the files listed below were fetched. Every other
tile is absent, so treat these as *partial* HiPS when testing (missing
tiles -> NaN).

The file list comes from `Tests/hips/hipslist.py`. The contents were
checked with `Tests/hips/inspect.py`.

## DSS2_red

- Source: IRSA mirror of `CDS/P/DSS2/red`,
  <https://irsa.ipac.caltech.edu/data/hips/CDS/DSS2/red> (status
  "public mirror unclonable", so only a few tiles were taken).
- Equatorial, `hips_order` 9, 512-px tiles, BITPIX 16 with
  `BLANK=-32768`, formats jpeg + fits.
- Fetched: `properties`, `Moc.fits`, `Norder3/Allsky.fits` +
  `Allsky.jpg`, one FITS tile per order 3-9 at M31 (10.6847, +41.2690),
  all four order-9 children of order-8 tile 43345 (173380-173383), and
  `Norder9/Dir170000/Npix173383.jpg`.
- Covers: a deep HiPS, integer tiles with BLANK, a **reduced Allsky**
  (64-px tiles for a 512-px HiPS), and **unpadded** FITS tiles (all 10).

## Abell1763_irac1

- Source: `ov-gso/P/Abell1763/irac1`,
  <https://cade.irap.omp.eu/documents/Ancillary/4Aladin/Abell1763_irac1>.
- **Galactic** frame, `hips_order` 5, 512-px tiles, BITPIX -32,
  formats png jpeg fits, `moc_sky_fraction` 3.6e-5.
- Fetched: `properties`, `Moc.fits`, `Norder3/Allsky.fits` (reduced,
  64-px tiles), and every existing tile (FITS + PNG) near the target at
  orders 0-5: `Norder0 Npix1`, `Norder1 Npix7`, `Norder2 Npix30`,
  `Norder3 Npix123`, `Norder4 Npix494`, `Norder5 Npix1978, 1979`.
- Covers: **partial coverage** (most tiles absent, and the server 404s
  them), NaN blanks inside tiles (91% of `Npix1979`), PNG alpha 0 on
  blanks, and **padded** FITS tiles. Allsky exists only at order 3.

## XRISM_RESOLVE

- Source: `JAXA/P/XRISM/RESOLVE/Image`,
  <https://data.darts.isas.jaxa.jp/pub/HiPS/XRISM-RESOLVE_Image>.
- Equatorial, `hips_order` 7, 512-px tiles, PNG only,
  `dataproduct_subtype = color`.
- Fetched: `properties`, `Moc.fits`, `Norder3/Allsky.png`, and the
  tiles at orders 0-7 near the initial position (64.336, +37.922).
- Covers: a **colour** HiPS (RGBA, R != G != B, alpha 0/255), an RGB
  Allsky, and Allsky only at order 3.

## LABHI_cube

- Source: `CAMRAS/P/LABHI/CUBE` (Leiden/Argentine/Bonn HI survey),
  <https://data.camras.nl/hips/labh/cds_aladin_cube>.
- `dataproduct_type = cube`, equatorial, `hips_order` 0, 128-px tiles,
  PNG only (no FITS tiles, though `hips_pixel_bitpix` is 16),
  `hips_cube_depth` 891, `hips_cube_firstframe` 445; velocity axis
  `data_cube_crval3/cdelt3` in M/S.
- Fetched: `properties`, `Moc.fits`, and the 12 order-0 tiles for
  frames 0 (no suffix), `_1`, `_445` and `_890`. **Tiles 0-3 of frame
  890 do not exist on the server.** There is no `Allsky`.
- Covers: cube naming (`NpixN_f`), the first frame, the 3rd-axis WCS,
  and missing frames. PNG values are 8-bit display values (grey RGBA),
  not physical units.

## Not covered (servers unreachable on 2026-11-15)

The CDS HiPS hosts (`alasky`, `alaskybis`) answered "page currently
unavailable" or didn't connect, and ESA's `skies.esac.esa.int` didn't
connect, so these weren't fetched: a **FITS** cube (e.g.
`CDS/P/ACT/DR5/f150`, 3 frames), an 8-bit integer HiPS (e.g.
`ESAVO/P/EXOSAT/all`), and BITPIX -64 (e.g.
`CDS/P/MeerKAT/Galactic-Centre-spectral-index`). Retry later.

Update 2026-11-16: the CDS server answers again, but there is no FITS
cube left to fetch. The MocServer lists 23 cubes with FITS tiles
(`dataproduct_type=cube && hips_tile_format=*fits*`), all CDS and all
`client_category = Deprecated/HiPS-Cube`; the `properties` of ACT DR4/5,
HI4PI, HIPASS, GALFA-HI, CGPS, Mopra and Bayestar19 are 404 at
alasky.cds.unistra.fr (alaskybis timed out).
