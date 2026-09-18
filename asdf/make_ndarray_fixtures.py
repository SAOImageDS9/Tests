#!/usr/bin/env python3
"""Generate ASDF fixtures for atypical numpy array descriptions.

The 108 fixtures under `fixtures/` vary the *codec* over a fixed set of
ordinary C-contiguous, big-endian arrays. This covers the other axis: the
ways `core/ndarray` can describe an array that is not that.

Three groups, and they are checked differently:

1. **Byte order and dtype.** These must load, and load *correctly*. Each
   big/little pair holds the same logical values, so the two fixtures must
   probe identically -- a self-checking design that needs no external truth.
   The unsigned and half-precision ones carry values chosen so that a
   mis-signed or narrowed read is obvious rather than subtle: uint16 holds
   values above 32767, uint32 above 2^31, float16 its own maximum.

2. **Views: `offset` and `strides`.** These must be *refused*. asdf writes
   the whole parent array as the block and describes the view with
   strides/offset, so the block's bytes are not the array: a 64x64 parent
   with a [32, 64] view is still 8192 bytes on disk. Handing those bytes to
   the array loader would render the wrong pixels with no complaint, which
   is why `asdf.tcl` records them as unsupported instead (see
   AsdfEnumFlush). Every one of these is what the asdf library itself
   produces for the corresponding numpy view -- not hand-written -- so the
   test is against real ecosystem output.

3. **Shapes and dtypes with no FITS representation.** Rank 0 and rank 1,
   a rank-3 array with a single plane, a structured (record) dtype, and the
   dtypes `AsdfDatatypeToBitpix`/`AsdfWidenDatatype` deliberately leave
   unmapped. These must be refused or handled, never misread.

Most fixtures are written by the asdf library, so they are exactly what the
ecosystem emits. Three cannot be: an explicit `offset: 0` (asdf omits a zero
offset) and a missing `byteorder` (the schema's `dependencies` make shape,
datatype and byteorder mandatory whenever `source` is present, so asdf will
never write one). Those are built by hand, and are marked `handmade` in
their own metadata -- the byteorder one is *deliberately invalid* ASDF,
pinning defensive behaviour rather than describing a real file.

Needs numpy and asdf:
    python3 make_ndarray_fixtures.py
"""

import json
import os
import struct

import numpy as np

try:
    import asdf
except ImportError:  # pragma: no cover
    raise SystemExit("this generator needs the asdf library: pip install asdf")

HERE = os.path.dirname(os.path.abspath(__file__))
OUTDIR = os.path.join(HERE, "arrays")

N = 64  # every 2-D fixture is N x N, keeping fixtures a few KB


def parent(dtype):
    """The N x N array every fixture is cut from, as `dtype`.

    A plain arange, so a big/little pair carries identical logical values
    and the two must probe the same. Values run to N*N-1 = 4095, which is
    exact in float16 only up to 2048 -- float16 gets its own data below.
    """
    return np.arange(N * N, dtype=dtype).reshape(N, N)


def write(name, arr, note, expect=None):
    """One fixture, written by the asdf library itself."""
    meta = {"case": name, "note": note}
    if expect:
        meta.update(expect)
    af = asdf.AsdfFile({"meta": meta, "data": arr})
    path = os.path.join(OUTDIR, name + ".asdf")
    af.write_to(path)
    return path


# ---------------------------------------------------------------- handmade

def block(payload):
    hdr = struct.pack(">IIQQQ16s", 0, 0, len(payload), len(payload),
                      len(payload), b"\x00" * 16)
    return b"\xd3BLK" + struct.pack(">H", 48) + hdr + payload


def write_raw(name, fields, payload, note, expect=None):
    """One fixture with a hand-written ndarray node.

    Only for the two shapes asdf will not emit. Mirrors the block+index
    writer in make_gwcs_transform_fixtures.py: the index offset is computed
    from the finished tree, never patched in afterwards -- editing an ASDF
    file in place invalidates its block index.
    """
    meta = {"case": name, "note": note, "handmade": True}
    if expect:
        meta.update(expect)
    body = "".join("  %s\n" % f for f in fields)
    # Concatenated, not %-formatted: the header contains "%YAML", which a
    # %-format string reads as a conversion specifier.
    tree = ("#ASDF 1.0.0\n#ASDF_STANDARD 1.5.0\n%YAML 1.1\n"
            "%TAG ! tag:stsci.edu:asdf/\n--- !core/asdf-1.1.0\n"
            "asdf_library: !core/software-1.0.0 "
            "{name: make_ndarray_fixtures, version: '1.0'}\n"
            + "meta: " + json.dumps(meta) + "\n"
            + "data: !core/ndarray-1.1.0\n" + body + "...\n")
    idx = ("#ASDF BLOCK INDEX\n%YAML 1.1\n---\n- "
           + str(len(tree.encode())) + "\n...\n")
    path = os.path.join(OUTDIR, name + ".asdf")
    with open(path, "wb") as fh:
        fh.write(tree.encode() + block(payload) + idx.encode())
    return path


# -------------------------------------------------------------------- main

def main():
    os.makedirs(OUTDIR, exist_ok=True)
    made = []

    # --- 1. byte order -----------------------------------------------
    # The pairs hold identical logical values, so they must probe alike.
    for dt, tag in ((">i2", "int16_big"), ("<i2", "int16_little"),
                    (">f4", "float32_big"), ("<f4", "float32_little")):
        a = parent(dt)
        made.append(write(tag, a,
                          "byteorder %s; the big/little pair of a type holds "
                          "the same values and must read identically"
                          % ("big" if dt[0] == ">" else "little"),
                          {"expect_load": "yes",
                           "expect_at": [1, 1, N // 2, N // 2, N, N],
                           "expect_values": [float(a[0, 0]),
                                             float(a[N // 2 - 1, N // 2 - 1]),
                                             float(a[N - 1, N - 1])]}))

    # --- 2. views: offset and strides, all refused --------------------
    a16 = parent(">i2")
    a32 = parent(">f4")
    views = [
        ("int16_offset", a16[8:],
         "a[8:] -- contiguous but starting part way into the block, so asdf "
         "writes offset with NO strides"),
        ("float32_offset", a32[8:],
         "as int16_offset, for a float type"),
        ("int16_strides_skip", a16[::2],
         "a[::2] -- every other row, so asdf writes strides with no offset"),
        ("float32_strides_skip", a32[::2],
         "as int16_strides_skip, for a float type"),
        ("int16_strides_fortran", np.asfortranarray(a16),
         "column-major, expressed as strides rather than a different shape"),
        ("int16_strides_slice", a16[8:40, 8:40],
         "a[8:40, 8:40] -- a tile, so offset AND strides together, which is "
         "the example the ndarray schema itself gives"),
        ("int16_strides_negative", a16[::-1],
         "a[::-1] -- rows reversed, giving a negative stride; the schema "
         "allows these (its items are minimum 1 or maximum -1)"),
        ("int16_strides_negative_both", a16[::-1, ::-1],
         "a[::-1, ::-1] -- both axes reversed, so both strides negative"),
    ]
    for tag, arr, note in views:
        made.append(write(tag, arr, note,
                          {"expect_load": "no",
                           "expect_reason": "offset/strides describe a view, "
                           "so the block's bytes are not the array"}))

    # --- 3a. shapes ---------------------------------------------------
    made.append(write("int16_rank0", np.array(7, dtype=">i2"),
                      "shape [] -- a 0-d array; AsdfEnumFlush drops a node "
                      "with an empty shape before anything else looks at it",
                      {"expect_load": "no"}))
    made.append(write("int16_rank1", parent(">i2").ravel()[:100],
                      "shape [100] -- rank 1, which is neither an image nor "
                      "a cube",
                      {"expect_load": "no"}))
    plane = parent(">i2").reshape(1, N, N)
    made.append(write("int16_plane1", plane,
                      "shape [1, 64, 64] -- a rank-3 cube with a single "
                      "plane, which should load as a cube of depth 1",
                      {"expect_load": "yes",
                       "expect_values": [float(plane[0, 0, 0]),
                                         float(plane[0, N // 2 - 1, N // 2 - 1]),
                                         float(plane[0, N - 1, N - 1])]}))

    # --- 3b. dtypes ---------------------------------------------------
    # uint16 -> bitpix -16, fitsy's private unsigned-short code. Values
    # above 32767 so a signed read would show negatives.
    u16 = (np.arange(N * N, dtype=">u2") % 25000 + 40000).astype(">u2").reshape(N, N)
    made.append(write("uint16", u16,
                      "uint16 -> bitpix -16 (fitsy's own unsigned-short "
                      "code, not a FITS value). Every value exceeds 32767, "
                      "so a signed misread shows negatives",
                      {"expect_load": "yes",
                       "expect_values": [float(u16[0, 0]),
                                         float(u16[N // 2 - 1, N // 2 - 1]),
                                         float(u16[N - 1, N - 1])]}))

    # uint32 -> widened to int64 by asdfconvert. Values above 2^31 so a
    # signed-32 misread would wrap negative.
    u32 = (np.arange(N * N, dtype=">u4") + 2147483648).astype(">u4").reshape(N, N)
    made.append(write("uint32", u32,
                      "uint32 has no fitsy bitpix and is widened to int64 "
                      "by asdfconvert. Values exceed 2^31, so a signed-32 "
                      "misread wraps negative. Real Roman dq arrays are "
                      "uint32",
                      {"expect_load": "yes",
                       "expect_values": [float(u32[0, 0]),
                                         float(u32[N // 2 - 1, N // 2 - 1]),
                                         float(u32[N - 1, N - 1])]}))

    # float16 -> widened to float32. Values exact in half precision, and
    # one at float16's maximum.
    f16 = np.full((N, N), 1.5, dtype=">f2")
    f16[0, 0] = 2.25
    f16[N // 2 - 1, N // 2 - 1] = -8.5
    f16[N - 1, N - 1] = 65504.0          # float16 max, exact
    made.append(write("float16", f16,
                      "float16 has no fitsy bitpix and is widened to "
                      "float32. Values are exact in half precision, the "
                      "last being float16's maximum. Real Roman err and "
                      "var_poisson arrays are float16",
                      {"expect_load": "yes",
                       "expect_values": [2.25, -8.5, 65504.0]}))

    for tag, dt, why in (
        ("int8", ">i1", "int8 is signed 8-bit; fitsy's bitpix 8 is "
                        "*unsigned*, so there is no lossless mapping"),
        ("uint64", ">u8", "uint64 has no lossless widening in fitsy's set "
                          "{8,16,-16,32,64,-32,-64}"),
    ):
        arr = (parent(">i2") % 100).astype(dt)
        if dt == ">i1":
            arr = (parent(">i2") % 100 - 50).astype(dt)   # exercise negatives
        made.append(write(tag, arr,
                          why + " -- must be refused, not coerced",
                          {"expect_load": "no"}))

    c64 = (parent(">f4") + 1j * parent(">f4")).astype(">c8")
    made.append(write("complex64", c64,
                      "a complex dtype, which no FITS image can hold",
                      {"expect_load": "no"}))

    rec = np.zeros((8, 8), dtype=[("x", ">f4"), ("y", ">i2")])
    rec["x"] = parent(">f4")[:8, :8]
    rec["y"] = parent(">i2")[:8, :8]
    made.append(write("struct2d", rec,
                      "a structured (record) dtype, where `datatype' is a "
                      "multi-line YAML *list* of named fields rather than a "
                      "scalar. The interesting part is the field parser: "
                      "each nested entry carries its own `datatype:' and "
                      "`byteorder:', so a parser scanning the node body "
                      "line by line could pick one of those up and load the "
                      "array as that type",
                      {"expect_load": "no"}))

    # --- the two asdf will not write --------------------------------
    payload = parent(">i2").tobytes()
    made.append(write_raw(
        "int16_offset_zero",
        ["source: 0", "datatype: int16", "byteorder: big",
         "shape: [%d, %d]" % (N, N), "offset: 0"],
        payload,
        "offset: 0 spelled out. A zero offset is just the default, so this "
        "must LOAD -- unlike every other offset fixture. asdf omits a zero "
        "offset, so this cannot come from the library",
        {"expect_load": "yes",
         "expect_values": [0.0, float(parent(">i2")[N // 2 - 1, N // 2 - 1]),
                           float(parent(">i2")[N - 1, N - 1])]}))

    made.append(write_raw(
        "int16_no_byteorder",
        ["source: 0", "datatype: int16", "shape: [%d, %d]" % (N, N)],
        payload,
        "byteorder omitted. DELIBERATELY INVALID: the ndarray schema's "
        "`dependencies' make shape, datatype and byteorder all mandatory "
        "when `source' is present, so no real file looks like this. It pins "
        "asdf.tcl's defensive default of little-endian, which for this "
        "big-endian payload means the pixels are expected to read swapped",
        {"expect_load": "yes", "expect_byteorder_default": "little"}))

    print("%d fixtures in %s" % (len(made), OUTDIR))
    for p in sorted(made):
        print("   %-34s %6d bytes" % (os.path.basename(p), os.path.getsize(p)))


if __name__ == "__main__":
    main()
