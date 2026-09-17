#!/usr/bin/env python3
"""Convert this test suite's sample FITS images (fits/) into ASDF, one file
per source image per supported block-compression codec, for a Phase 5
(generalized, non-Roman-specific ASDF reading) regression test suite in the
SAOImageDS9/asdf_format checkout - see that repo's TODO.md Phase 5 and
ASDF_NATIVE_SUPPORT_DESIGN.md for the full design context (this Tests repo
just hosts the fixtures; the design docs live in the main asdf_format repo).

Source files live in fits/, a sibling of this directory within this same
Tests checkout - read-only, nothing is written back into it. Each source FITS
file with no BLANK keyword is read with astropy's default scaling behavior
(BSCALE/BZERO applied), so the resulting ASDF array holds the same physical
pixel values DS9 already renders from the original FITS file. The 4 files
that do have a BLANK keyword (char_blank/short_blank/int_blank/long_blank)
are read raw instead and written as numpy masked arrays - asdf serializes
this natively as a `mask:` sibling ndarray next to `data:`, which keeps the
original integer dtype intact rather than promoting to float+NaN the way
astropy's default scaling would (confirmed by inspecting the written YAML,
not assumed).

Each source image is written 4 times, once per codec asdf's Python library
actually supports (confirmed via asdf._compression.validate's builtin_labels
list, not assumed): uncompressed, zlib, bzp2 (bzip2), lz4. DS9's own reader
(ds9/library/asdf.tcl's AsdfReadBlock, in the asdf_format repo) only
understands zlib/lz4/uncompressed today - the bzp2 variants are deliberately
included anyway, so Phase 5's generalization work has a real fixture to test
bzip2 support against rather than needing to generate one later.

Usage (from anywhere - paths are resolved relative to this script):
    python3 convert_fits_to_asdf.py
"""
import pathlib

import asdf
import numpy as np
from astropy.io import fits

THIS_DIR = pathlib.Path(__file__).resolve().parent
FITS_DIR = THIS_DIR.parent / "fits"
OUT_DIR = THIS_DIR / "fixtures"

# The image FITS files to convert - deliberately excludes table.fits (a binary
# table, not an image - out of scope for the core/ndarray-only reader this
# project builds) and healpix_partial.fits (a different pixelization, not a
# plain image array).
SOURCE_FILES = [
    "char.fits",
    "char_blank.fits",
    "char_bscale.fits",
    "double.fits",
    "double_bscale.fits",
    "double_inf.fits",
    "double_nan.fits",
    "float.fits",
    "float_bscale.fits",
    "float_inf.fits",
    "float_nan.fits",
    "img.fits",
    "int.fits",
    "int_blank.fits",
    "int_bscale.fits",
    "long.fits",
    "long_blank.fits",
    "long_bscale.fits",
    "short.fits",
    "short_blank.fits",
    "short_bscale.fits",
]

# asdf._compression.validate()'s builtin_labels list, minus "input" (which
# means "keep whatever compression the source block already had" - not
# meaningful when writing a freshly-read numpy array). None means uncompressed.
CODECS = {
    "none": None,
    "zlib": "zlib",
    "bzp2": "bzp2",
    "lz4": "lz4",
}


def convert_one(src_path: pathlib.Path) -> None:
    with fits.open(src_path) as probe_hdul:
        original_bitpix = probe_hdul[0].header.get("BITPIX")
        had_blank = probe_hdul[0].header.get("BLANK") is not None

    if had_blank:
        # Integer FITS data has no NaN of its own - BLANK names a sentinel
        # integer value standing in for "undefined pixel". Converting that to
        # a float array with NaN (astropy's default scaling behavior) reads
        # back fine but defeats the point of an integer-with-nulls fixture -
        # the whole array gets promoted to float and the original integer
        # dtype is lost. Read raw instead (do_not_scale_image_data=True) and
        # represent the nulls as an ASDF mask attached to the still-integer
        # data array (asdf serializes a numpy masked array natively as a
        # `data: {..., mask: !core/ndarray ...}` pair - confirmed directly,
        # not assumed, by writing one and inspecting the resulting YAML).
        with fits.open(src_path, do_not_scale_image_data=True) as hdul:
            hdu = hdul[0]
            header = hdu.header
            raw = hdu.data
        blank = header["BLANK"]
        data = np.ma.masked_array(raw, mask=(raw == blank))
        note = (
            "Converted from the DS9 test suite's Tests/fits/ sample images "
            "for Phase 5 ASDF-reader regression testing. This file's BLANK "
            "keyword marks null pixels; represented here as a numpy masked "
            "array (asdf writes this as a `mask:` sibling ndarray next to "
            "`data:`), keeping the original integer dtype intact rather than "
            "promoting to float+NaN the way astropy's default scaling would."
        )
    else:
        with fits.open(src_path) as hdul:
            hdu = hdul[0]
            header = hdu.header
            data = hdu.data
        note = (
            "Converted from the DS9 test suite's Tests/fits/ sample images "
            "for Phase 5 ASDF-reader regression testing. Pixel values are "
            "the physical (BSCALE/BZERO-applied) values astropy reads by "
            "default, matching what DS9 renders from the original FITS file."
        )

    tree = {
        "data": data,
        "meta": {
            "source_fits_file": src_path.name,
            "original_bitpix": original_bitpix,
            "had_blank_keyword": had_blank,
            "note": note,
        },
    }

    stem = src_path.stem
    for codec_dir, codec in CODECS.items():
        out_dir = OUT_DIR / codec_dir
        out_dir.mkdir(parents=True, exist_ok=True)
        out_path = out_dir / f"{stem}.asdf"
        af = asdf.AsdfFile(tree)
        af.write_to(out_path, all_array_compression=codec)
        print(f"{src_path.name:25s} -> {out_path.relative_to(THIS_DIR.parent)} "
              f"(dtype={data.dtype}, shape={data.shape}, codec={codec_dir})")


def main() -> None:
    missing = [f for f in SOURCE_FILES if not (FITS_DIR / f).exists()]
    if missing:
        raise SystemExit(f"missing source FITS file(s) in {FITS_DIR}: {missing}")

    for fname in SOURCE_FILES:
        convert_one(FITS_DIR / fname)


if __name__ == "__main__":
    main()
