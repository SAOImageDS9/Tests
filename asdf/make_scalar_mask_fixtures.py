#!/usr/bin/env python3
"""Generate the *_blank_scalar ASDF fixtures.

asdf-standard's core/ndarray allows `mask` to be either a bool8 ndarray or
a *scalar number*, in which case (quoting the schema) "that number is used
to represent missing values" - the FITS BLANK convention exactly. The
scalar form is a documented example in every schema version
(ndarray-1.0.0/1.1.0/1.2.0), on float64 data.

It needs its own generator because asdf's Python *writer* cannot emit it:
the ndarray converter does `result["mask"] = data.mask` unconditionally, so
a numpy masked array always serializes as a boolean mask array. asdf reads
the scalar form fine (NDArrayType._apply_mask -> ma.masked_values), it just
never writes it. Files carrying a scalar mask therefore come from other
writers, and a reader has to handle both - which is the point of these
fixtures.

So each output is built by re-treeing an existing fixture: the data block
is copied over byte for byte, with only the YAML tree rewritten and the
block index recomputed. That keeps every codec, including lz4, without
this script needing a compressor of its own, and guarantees the pixel
bytes are identical to the sibling fixture.

Every output is then validated by reading it back with asdf.open() and
comparing against the original FITS - that is the authoritative check that
the file is spec-conformant, not just that our own reader likes it.
"""

import os
import re
import struct
import sys

import numpy as np
from astropy.io import fits
import asdf

HERE = os.path.dirname(os.path.abspath(__file__))
FITSDIR = os.path.join(HERE, os.pardir, "fits")
FIXDIR = os.path.join(HERE, "fixtures")
CODECS = ("none", "zlib", "bzp2", "lz4")

# integer sources: the sentinel is the source FITS file's own BLANK, so the
# result must render identically to that FITS file
INT_SOURCES = ("char_blank", "short_blank", "int_blank", "long_blank")
# float sources: FITS has no BLANK for float, so these exercise the schema's
# own headline case - a scalar mask on floating point data
FLOAT_SOURCES = ("float", "double")

BLOCK_MAGIC = b"\xd3BLK"


def block_extent(buf, off):
    """Byte length of the block starting at off, header included."""
    if buf[off:off + 4] != BLOCK_MAGIC:
        raise ValueError("no block magic at %d" % off)
    hsize = struct.unpack(">H", buf[off + 4:off + 6])[0]
    allocated = struct.unpack(">Q", buf[off + 6 + 8:off + 6 + 16])[0]
    return 6 + hsize + allocated


def split_container(path):
    """Return (treeText, firstBlockBytes)."""
    buf = open(path, "rb").read()
    first = buf.find(BLOCK_MAGIC)
    if first < 0:
        raise ValueError("%s has no binary blocks" % path)
    return buf[:first].decode("latin-1"), buf[first:first + block_extent(buf, first)]


def write_container(path, tree, block):
    off = len(tree.encode("latin-1"))
    index = "#ASDF BLOCK INDEX\n%YAML 1.1\n---\n- {}\n...\n".format(off)
    with open(path, "wb") as fh:
        fh.write(tree.encode("latin-1"))
        fh.write(block)
        fh.write(index.encode("latin-1"))


def replace_ndarray_mask(tree, scalar):
    """Swap a nested `mask: !core/ndarray-...` node for a scalar mask."""
    pat = re.compile(
        r"(\n  mask: )!core/ndarray-[0-9.]+\n(?:    [^\n]*\n)+")
    new, n = pat.subn(r"\g<1>{}\n".format(scalar), tree, count=1)
    if n != 1:
        raise ValueError("expected exactly one nested mask node, found %d" % n)
    return new


def insert_scalar_mask(tree, scalar):
    """Add a scalar mask to a data node that has none."""
    pat = re.compile(r"(\ndata: !core/ndarray-[0-9.]+\n  source: \d+\n)")
    new, n = pat.subn(r"\g<1>  mask: {}\n".format(scalar), tree, count=1)
    if n != 1:
        raise ValueError("could not find the data node to add a mask to")
    return new


def fmt(value, isfloat):
    if not isfloat:
        return str(int(value))
    # keep full float64 precision so the sentinel compares exactly
    return repr(float(value))


def validate(path, expect, sentinel, isfloat):
    with asdf.open(path) as af:
        # asdf hands back a lazy NDArrayType; slicing materializes it, and
        # only then is the mask applied (NDArrayType._apply_mask)
        got = af["data"][:]
        if not isinstance(got, np.ma.MaskedArray):
            raise AssertionError("%s: asdf did not read a masked array" % path)
        if got.dtype != expect.dtype:
            raise AssertionError(
                "%s: dtype %s != %s" % (path, got.dtype, expect.dtype))

        want_mask = np.isnan(expect) if (isfloat and np.isnan(sentinel)) \
            else (expect == sentinel)
        if not np.array_equal(np.ma.getmaskarray(got), want_mask):
            raise AssertionError("%s: mask positions differ" % path)
        if not want_mask.any():
            raise AssertionError("%s: sentinel masks nothing - useless fixture" % path)

        a = np.asarray(got.data)[~want_mask]
        b = expect[~want_mask]
        if not np.array_equal(a, b):
            raise AssertionError("%s: unmasked pixel values differ" % path)
        return int(want_mask.sum())


def main():
    made = 0
    for name in INT_SOURCES:
        fpath = os.path.join(FITSDIR, name + ".fits")
        with fits.open(fpath, do_not_scale_image_data=True) as hdul:
            raw = hdul[0].data
            blank = hdul[0].header["BLANK"]
        for codec in CODECS:
            src = os.path.join(FIXDIR, codec, name + ".asdf")
            dst = os.path.join(FIXDIR, codec, name + "_scalar.asdf")
            tree, block = split_container(src)
            write_container(dst, replace_ndarray_mask(tree, fmt(blank, False)), block)
            n = validate(dst, raw, blank, False)
            print("  %-5s %-22s mask=%-6s masked=%d" %
                  (codec, name + "_scalar", blank, n))
            made += 1

    for name in FLOAT_SOURCES:
        fpath = os.path.join(FITSDIR, name + ".fits")
        raw = fits.getdata(fpath)
        # pick a sentinel that genuinely occurs, so the fixture masks something
        vals, counts = np.unique(raw, return_counts=True)
        sentinel = float(vals[int(np.argmax(counts))])
        for codec in CODECS:
            src = os.path.join(FIXDIR, codec, name + ".asdf")
            dst = os.path.join(FIXDIR, codec, name + "_blank_scalar.asdf")
            tree, block = split_container(src)
            write_container(dst, insert_scalar_mask(tree, fmt(sentinel, True)), block)
            n = validate(dst, raw, sentinel, True)
            print("  %-5s %-22s mask=%-6s masked=%d" %
                  (codec, name + "_blank_scalar", sentinel, n))
            made += 1

    print("\n%d fixtures written and validated against the source FITS" % made)


if __name__ == "__main__":
    sys.exit(main())
