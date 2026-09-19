#!/usr/bin/env python3
"""Generate malformed and edge-case ASDF fixtures for the reader's defences.

The `fixtures/` and `arrays/` families are all *valid* ASDF: they vary the
codec and the way `core/ndarray` legitimately describes an array. These are
the opposite. Each one is a file a correct reader must refuse, or handle
without believing it, and every one of them corresponds to a specific
defence in `fitsy/asdf.C`:

  int64_blank_wide          the masked pixels share a value outside the
                            FITS BLANK range. BLANK is carried as an int
                            the whole way down (FitsImageHDU::blank_,
                            FitsData::blank_), so that value cannot be the
                            sentinel; the reader has to fall back to a
                            candidate that fits rather than truncate one
                            that does not, which would leave the masked
                            pixels not matching BLANK at all.

  int64_scalar_mask_wide    a *scalar* mask outside the same range. Here
                            there is no fallback -- the file named the
                            sentinel -- so the array must load with no
                            nulls rather than with a truncated BLANK.

  shape_overflow            three dimensions, each individually legal
                            (below INT_MAX), whose product overflows
                            size_t. The expected-length check has to be
                            computed so it cannot wrap; a wrapped length
                            would accept a tiny buffer as complete.

  block_huge_decoded        a block header declaring a decoded size far
                            beyond available memory. Allocation must fail
                            as a reader error, not as an uncaught
                            std::bad_alloc.

  lz4_bad_chunk             an lz4 payload whose framing claims a chunk
                            longer than the payload. The chunk loop has to
                            notice rather than read past the buffer.

  mask_missing_block        a valid array whose `mask` ndarray points at a
                            block index that does not exist. The image is
                            fine, so it must still load -- but without
                            null semantics, and saying so rather than
                            silently.

Needs nothing but the standard library: every file here is hand-written,
because the asdf library will not emit any of them.

    python3 make_adversarial_fixtures.py
"""

import json
import os
import struct

HERE = os.path.dirname(os.path.abspath(__file__))
OUTDIR = os.path.join(HERE, "malformed")

N = 32  # small: none of these is about pixel content


def block(payload, decoded=None, used=None):
    """One ASDF binary block.

    `decoded`/`used` override the header's declared sizes, which is the
    whole point for the fixtures that lie about them.
    """
    if decoded is None:
        decoded = len(payload)
    if used is None:
        used = len(payload)
    hdr = struct.pack(">IIQQQ16s", 0, 0, len(payload), used, decoded,
                      b"\x00" * 16)
    return b"\xd3BLK" + struct.pack(">H", 48) + hdr + payload


def write(name, nodes, blocks, note, expect):
    """One fixture.

    `nodes` is the already-indented YAML for the tree's ndarray nodes, so a
    fixture can describe several (a data array plus its mask). The block
    index offset is computed from the finished tree rather than patched in
    afterwards -- editing an ASDF file in place invalidates its index.
    """
    meta = {"case": name, "note": note, "handmade": True,
            "adversarial": True}
    meta.update(expect)
    tree = ("#ASDF 1.0.0\n#ASDF_STANDARD 1.5.0\n%YAML 1.1\n"
            "%TAG ! tag:stsci.edu:asdf/\n--- !core/asdf-1.1.0\n"
            "asdf_library: !core/software-1.0.0 "
            "{name: make_adversarial_fixtures, version: '1.0'}\n"
            + "meta: " + json.dumps(meta) + "\n"
            + nodes + "...\n")

    body = b"".join(blocks)
    offs = []
    at = len(tree.encode())
    for bb in blocks:
        offs.append(at)
        at += len(bb)
    idx = ("#ASDF BLOCK INDEX\n%YAML 1.1\n---\n"
           + "".join("- %d\n" % oo for oo in offs) + "...\n")

    path = os.path.join(OUTDIR, name + ".asdf")
    with open(path, "wb") as fh:
        fh.write(tree.encode() + body + idx.encode())
    return path


def ndarray(key, source, datatype, shape, byteorder="big", extra=()):
    ll = ["%s: !core/ndarray-1.1.0" % key,
          "  source: %d" % source,
          "  datatype: %s" % datatype,
          "  byteorder: %s" % byteorder,
          "  shape: [%s]" % ", ".join(str(s) for s in shape)]
    ll.extend("  " + e for e in extra)
    return "".join(l + "\n" for l in ll)


def main():
    os.makedirs(OUTDIR, exist_ok=True)
    made = []

    # ---- int64 sentinels outside the FITS BLANK range -----------------
    # Masked pixels all hold 2^40, which no int BLANK can express. Nothing
    # in the array uses INT_MIN, so that is the fallback the reader should
    # pick, rewriting the masked pixels to it.
    WIDE = 1 << 40
    data = []
    mask = []
    for ii in range(N * N):
        masked = (ii % 7) == 0
        data.append(WIDE if masked else ii)
        mask.append(1 if masked else 0)
    made.append(write(
        "int64_blank_wide",
        ndarray("data", 0, "int64", (N, N),
                extra=["mask: !core/ndarray-1.1.0",
                       "  source: 1",
                       "  datatype: bool8",
                       "  byteorder: big",
                       "  shape: [%d, %d]" % (N, N)]),
        [block(struct.pack(">%dq" % len(data), *data)),
         block(bytes(mask))],
        "int64 whose masked pixels all hold 2^40, outside the int range "
        "FITS BLANK is carried in. The reader must fall back to a sentinel "
        "that fits instead of truncating this one",
        {"expect_load": "yes", "expect_blank": -2147483648}))

    # The scalar form names the sentinel outright, so there is no second
    # choice: this one has to load with no nulls at all.
    made.append(write(
        "int64_scalar_mask_wide",
        ndarray("data", 0, "int64", (N, N),
                extra=["mask: %d" % WIDE]),
        [block(struct.pack(">%dq" % (N * N),
                           *[WIDE if (ii % 7) == 0 else ii
                             for ii in range(N * N)]))],
        "int64 with a scalar mask of 2^40, outside the FITS BLANK range. "
        "Unlike the array form there is no fallback, so this must load "
        "without null values rather than with a truncated BLANK",
        {"expect_load": "yes", "expect_blank": "none"}))

    # ---- arithmetic the reader must not let wrap ----------------------
    # Each dimension is under INT_MAX and so passes the per-axis check;
    # their product times 8 bytes is far past size_t.
    BIG = 2000000000
    made.append(write(
        "shape_overflow",
        ndarray("data", 0, "int64", (BIG, BIG, BIG)),
        [block(struct.pack(">8q", *range(8)))],
        "three dimensions each below INT_MAX whose product overflows "
        "size_t. The expected-length check must not wrap, or a tiny block "
        "passes as a complete array",
        {"expect_load": "no"}))

    # A header that declares vastly more decoded bytes than exist.
    made.append(write(
        "block_huge_decoded",
        ndarray("data", 0, "int64", (N, N)),
        [block(struct.pack(">%dq" % (N * N), *range(N * N)),
               decoded=1 << 62)],
        "a block header declaring 2^62 decoded bytes. Allocation has to "
        "fail as a reader error, not as an uncaught std::bad_alloc",
        {"expect_load": "no"}))

    # ---- codec framing ------------------------------------------------
    # An lz4 payload whose leading big-endian chunk length runs past the
    # end of the payload.
    made.append(write(
        "lz4_bad_chunk",
        ndarray("data", 0, "int64", (N, N)),
        [(lambda payload: b"\xd3BLK" + struct.pack(">H", 48)
          + struct.pack(">IIQQQ16s", 0, int.from_bytes(b"lz4\x00", "big"),
                        len(payload), len(payload), N * N * 8,
                        b"\x00" * 16)
          + payload)(struct.pack(">I", 1 << 30) + b"garbage")],
        "an lz4 block whose chunk length claims 2^30 bytes in a payload of "
        "eleven. The chunk loop must reject it rather than read past the "
        "buffer",
        {"expect_load": "no"}))

    # ---- a mask the reader cannot read --------------------------------
    # The image is intact, so it must load; only the null semantics are
    # lost, and that should be reported rather than silent.
    made.append(write(
        "mask_missing_block",
        ndarray("data", 0, "int16", (N, N),
                extra=["mask: !core/ndarray-1.1.0",
                       "  source: 9",
                       "  datatype: bool8",
                       "  byteorder: big",
                       "  shape: [%d, %d]" % (N, N)]),
        [block(struct.pack(">%dh" % (N * N), *range(N * N)))],
        "a mask ndarray pointing at block 9 of a file with one block. The "
        "image is fine and must still load, without nulls",
        {"expect_load": "yes", "expect_blank": "none"}))

    for pp in made:
        print("wrote %s (%d bytes)" % (pp, os.path.getsize(pp)))


if __name__ == "__main__":
    main()
