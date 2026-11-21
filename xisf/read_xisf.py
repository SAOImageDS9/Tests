#!/usr/bin/env python3
"""An independent, minimal XISF decoder for checking fixtures.

Deliberately shares no code with make_xisf_fixtures.py: it parses the header
with ElementTree and decodes blocks from the attributes alone, so a fixture
the generator got wrong does not get "verified" by the same mistake.

    read_xisf.py check            decode every fixture in MANIFEST.tsv and
                                  compare it with its FITS twin (or confirm
                                  it is refused)
    read_xisf.py twin <file.xisf> [index]
                                  write <file>.fits from a real file: the
                                  oracle for files we did not generate
    read_xisf.py dump <file.xisf> list the images and their attributes

Run with the ds9asdf conda env (numpy, astropy, lz4, zstandard).
"""
import base64
import hashlib
import pathlib
import struct
import sys
import xml.etree.ElementTree as ET
import zlib

import lz4.block
import numpy as np
import zstandard
from astropy.io import fits

NS = "{http://www.pixinsight.com/xisf}"
HERE = pathlib.Path(__file__).resolve().parent
DTYPE = {"UInt8": "u1", "UInt16": "u2", "UInt32": "u4", "UInt64": "u8",
         "Float32": "f4", "Float64": "f8"}
HASH = {"sha-1": "sha1", "sha1": "sha1", "sha-256": "sha256",
        "sha256": "sha256", "sha-512": "sha512", "sha512": "sha512",
        "sha3-256": "sha3_256", "sha3-512": "sha3_512"}


class Refused(Exception):
    pass


def header(raw):
    if raw[:8] != b"XISF0100":
        raise Refused("bad signature")
    (n,) = struct.unpack("<I", raw[8:12])
    if 16 + n > len(raw):
        raise Refused("header length past EOF")
    text = raw[16:16 + n]
    end = text.find(b"</xisf>")        # drop a detached <Signature>
    if end < 0:
        raise Refused("no </xisf> in header")
    try:
        root = ET.fromstring(text[:end + 7])
    except ET.ParseError as e:
        raise Refused(f"XML: {e}")
    if root.tag != NS + "xisf":
        raise Refused(f"root is {root.tag}")
    if root.get("version") != "1.0":
        raise Refused(f"version {root.get('version')}")
    return root


def decompress(codec, data, usize):
    if codec == "zlib":
        out = zlib.decompress(data)
    elif codec in ("lz4", "lz4hc"):
        out = lz4.block.decompress(data, uncompressed_size=usize)
    elif codec == "zstd":
        out = zstandard.ZstdDecompressor().decompress(data, max_output_size=usize)
    else:
        raise Refused(f"codec {codec}")
    if len(out) != usize:
        raise Refused(f"{codec}: {len(out)} bytes, declared {usize}")
    return out


def unshuffle(data, k):
    n = len(data) // k
    body = np.frombuffer(data[:n * k], np.uint8).reshape(k, n)
    return body.T.tobytes() + data[n * k:]


def block(raw, el, holder):
    """Stored bytes of el's block -> decoded bytes. `holder` carries the
    compression/checksum attributes (the element itself, or its <Data>)."""
    loc = el.get("location", "")
    if loc == "embedded":
        d = el.find(NS + "Data")
        holder = d
        txt = "".join(d.text.split()) if d.text else ""
        stored = (base64.b64decode(txt) if d.get("encoding") == "base64"
                  else bytes.fromhex(txt))
    elif loc.startswith("attachment:"):
        _, p, s = loc.split(":")
        p, s = int(p), int(s)
        if p + s > len(raw):
            raise Refused("attachment past EOF")
        stored = raw[p:p + s]
    else:
        raise Refused(f"location {loc!r}")
    ck = holder.get("checksum")
    if ck:
        algo, digest = ck.split(":")
        if algo not in HASH:
            raise Refused(f"checksum {algo}")
        if hashlib.new(HASH[algo], stored).hexdigest() != digest:
            raise Refused("checksum mismatch")
    comp = holder.get("compression")
    if not comp:
        return stored
    parts = comp.split(":")
    codec, usize = parts[0], int(parts[1])
    sh = codec.endswith("+sh")
    codec = codec[:-3] if sh else codec
    # Validate the codec before anything else: a block whose stored size
    # happens to equal its declared size would otherwise pass as a raw
    # subblock and an unknown codec would never be noticed.
    if codec not in ("zlib", "lz4", "lz4hc", "zstd"):
        raise Refused(f"codec {codec}")
    sub = holder.get("subblocks")
    pairs = ([tuple(int(v) for v in s.split(",")) for s in sub.split(":")]
             if sub else [(len(stored), usize)])
    if sum(c for c, _ in pairs) != len(stored) or sum(u for _, u in pairs) != usize:
        raise Refused("subblock sizes do not add up")
    out, at = [], 0
    for c, u in pairs:
        chunk = stored[at:at + c]
        at += c
        out.append(chunk if c == u else decompress(codec, chunk, u))
    data = b"".join(out)
    return unshuffle(data, int(parts[2])) if sh else data


def image(raw, el):
    """-> (pixels as (channels, [depth,] h, w), element). Raises Refused."""
    fmt = el.get("sampleFormat")
    if fmt not in DTYPE:
        raise Refused(f"sampleFormat {fmt}")
    try:
        g = [int(v) for v in el.get("geometry").split(":")]
    except Exception:
        raise Refused("geometry")
    if len(g) < 3 or min(g) <= 0:
        raise Refused("geometry")
    dims, nch = g[:-1], g[-1]
    count = nch
    for d in dims:
        count *= d
    if count > 2**40:
        raise Refused("geometry overflow")
    if el.get("location", "").startswith("inline:"):
        raise Refused("inline location on Image")
    data = block(raw, el, el)
    dt = np.dtype(DTYPE[fmt]).newbyteorder(">" if el.get("byteOrder") == "big"
                                           else "<")
    if len(data) != count * dt.itemsize:
        raise Refused(f"block is {len(data)} bytes, geometry wants "
                      f"{count * dt.itemsize}")
    a = np.frombuffer(data, dt).astype(dt.newbyteorder("="))
    shape = tuple(reversed(dims))               # [d,] h, w
    if el.get("pixelStorage", "Planar") == "Normal":
        a = np.moveaxis(a.reshape(shape + (nch,)), -1, 0)
    else:
        a = a.reshape((nch,) + shape)
    if fmt == "UInt64" and a.max() > np.iinfo(np.int64).max:
        raise Refused("UInt64 value above INT64_MAX")
    return a, el


def images(path):
    raw = pathlib.Path(path).read_bytes()
    root = header(raw)
    els = root.findall(NS + "Image")
    if not els:
        raise Refused("no Image elements")
    return raw, els


def as_fits(pix):
    a = pix[..., ::-1, :]
    if a.dtype in (np.uint32, np.uint64):
        a = a.astype(np.int64)
    return a[0] if a.shape[0] == 1 else a


def check():
    bad = 0
    rows = [l.rstrip("\n").split("\t") for l in open(HERE / "MANIFEST.tsv")
            if not l.startswith("#")]
    for rel, expect, _, _ in rows:
        try:
            raw, els = images(HERE / rel)
            pix, _ = image(raw, els[0])
            got = "load"
        except Refused as e:
            got, why = "refuse", str(e)
        if expect == "refuse":
            ok = got == "refuse"
            msg = f"refused: {why}" if ok else "LOADED but should refuse"
        elif got == "refuse":
            ok, msg = False, f"REFUSED: {why}"
        else:
            twin = fits.getdata(HERE / pathlib.Path(rel).with_suffix(".fits"))
            mine = as_fits(pix)
            ok = (mine.shape == twin.shape and
                  np.array_equal(mine.astype(twin.dtype), twin, equal_nan=True))
            msg = "pixels match twin" if ok else "PIXELS DIFFER from twin"
        bad += not ok
        print(f"{'ok  ' if ok else 'FAIL'} {rel}: {msg}")
    print(f"{len(rows) - bad}/{len(rows)} as expected")
    return bad


def main(argv):
    if argv[:1] == ["check"]:
        return 1 if check() else 0
    if argv[:1] == ["dump"]:
        raw, els = images(argv[1])
        for i, el in enumerate(els):
            print(i, {k: v for k, v in el.attrib.items()})
        return 0
    if argv[:1] == ["twin"]:
        raw, els = images(argv[1])
        idx = int(argv[2]) if len(argv) > 2 else 0
        pix, el = image(raw, els[idx])
        out = pathlib.Path(argv[1]).with_suffix(
            ".fits" if idx == 0 else f".{idx}.fits")
        fits.PrimaryHDU(np.ascontiguousarray(as_fits(pix))).writeto(
            out, overwrite=True)
        print(f"{out.name}: {pix.shape} {pix.dtype} min {np.nanmin(pix)} "
              f"max {np.nanmax(pix)}")
        return 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
