#!/usr/bin/env python3
"""Synthetic XISF fixtures for DS9's native XISF reader (TODO_XISF.md, Phase 0).

Writes monolithic XISF 1.0 files byte by byte, with no XISF library, so every
layout choice the spec allows (codec, byte shuffling, subblocks, raw
subblocks, byte order, planar vs normal storage, embedded vs attached blocks,
checksums, signed units, malformed variants) can be produced on purpose.

Next to every file DS9 is expected to *load*, this also writes its FITS twin
(`<name>.fits`): the same pixels in FITS orientation, with the WCS translated
to FITS cards. The twin is the oracle. Loading it into today's DS9 produces
the probe baseline the XISF file must reproduce once the reader exists; see
make_baselines.sh. The twin encodes the conversions TODO_XISF.md §2 commits
to, so a twin that disagrees with real PixInsight output means one of those
conventions is wrong:

  * Rows. XISF stores rows top to bottom (spec §8.5, Figure 2). FITS row 1 is
    the bottom. Twins are row-flipped.
  * Pixel centres. The XISF pixel (i, j) has its centre at (i+0.5, j+0.5)
    (§8.5.2). FITS pixel centres are integers, 1-based. So
    x_fits = x_xisf + 0.5 and y_fits = H - y_xisf + 0.5.
  * Linear matrix. AstrometricSolution:LinearTransformationMatrix M maps
    (x - x0, y - y0) in XISF image coordinates to projection-plane
    coordinates in degrees, row-major. Flipping y negates the second column:
    CD = [[M00, -M01], [M10, -M11]]. Confirmed against PCL (PixInsight's
    reference implementation, PCL 2.15.0): AstrometricMetadata writes the
    matrix as Matrix(A00, A01, A10, A11) of its image-to-world transform, and
    its ComputeWCSKeywords converts to FITS through x_I = x_F - 0.5,
    y_I = H + 0.5 - y_F, which is exactly the CRPIX/CD conversion above.
  * Projections. Gnomonic TAN, Stereographic STG, ZenithalEqualArea ZEA,
    Orthographic SIN, PlateCarree CAR, Mercator MER, HammerAitoff AIT. The
    spec names no codes. This is PCL's own table
    (ProjectionBase::ProjectionIdentifierToWCSCode).
  * WCS FITSKeywords. In PixInsight, WCS keywords stored with an image refer
    to its rows in storage order: row 1 is the TOP row (PCL WCSKeywords.h,
    ExtractWorldTransformation). A keyword-only solution therefore goes
    through PCL's MirrorVertically for the row-flipped twin: CRPIX2 -> H + 1 -
    CRPIX2, and CD1_2, CD2_2 (or CDELT2 when there is no CD/PC) negated.
  * Sample formats map to the BITPIX the reader will produce (TODO_XISF.md
    §2.9): UInt8 -> 8, UInt16 -> -16 (fitsy's private unsigned code; the FITS
    twin itself is 16 + BZERO), UInt32 and UInt64 -> 64, Float32 -> -32,
    Float64 -> -64. Complex is refused.

Every fixture is listed in MANIFEST.tsv with its expected outcome. The
outcomes are `load` (with a twin), `refuse` (no twin; DS9 must say why and
leave the frame empty), or `load-first` (multi-image file; the twin is the
image DS9 should pick by default).

Requires numpy, astropy, lz4 and zstandard. The ds9asdf conda env has all
four:
    ~/miniforge/envs/ds9asdf/bin/python Tests/xisf/make_xisf_fixtures.py
Output is deterministic (fixed creation time, no random data), so a rerun
produces byte-identical files.
"""
import base64
import hashlib
import pathlib
import struct
import zlib
from xml.sax.saxutils import escape, quoteattr

import lz4.block
import numpy as np
import zstandard
from astropy.io import fits

OUT = pathlib.Path(__file__).resolve().parent
W, H = 64, 48          # deliberately not square: a transposed read shows up
ALIGN = 4096           # XISF:BlockAlignmentSize, PixInsight's default
CREATED = "2026-11-21T00:00:00Z"
MANIFEST = []          # (relpath, expect, bitpix, notes)


# ---------------------------------------------------------------- pixel data

def ramp(w=W, h=H):
    """A [0,1) ramp, row 0 = top. Its value identifies the pixel, so any
    flip or transpose of the read changes the probed corners."""
    y, x = np.mgrid[0:h, 0:w]
    return (x + y * w) / float(w * h)


def as_format(f, fmt):
    """The XISF sample array for format `fmt` from a [0,1) float image."""
    if fmt == "UInt8":
        return np.floor(f * 255).astype(np.uint8)
    if fmt == "UInt16":
        return np.floor(f * 65535).astype(np.uint16)
    if fmt == "UInt32":
        # above 2^31, so the reader cannot get away with int32
        return (np.floor(f * 1.0e9) + 3_000_000_000).astype(np.uint32)
    if fmt == "UInt64":
        return (np.floor(f * 1.0e12) + 5_000_000_000).astype(np.uint64)
    if fmt == "Float32":
        return f.astype(np.float32)
    if fmt == "Float64":
        return f.astype(np.float64)
    if fmt == "Complex32":
        return (f + 1j * (1 - f)).astype(np.complex64)
    if fmt == "Complex64":
        return (f + 1j * (1 - f)).astype(np.complex128)
    raise ValueError(fmt)


BITPIX = {"UInt8": 8, "UInt16": -16, "UInt32": 64, "UInt64": 64,
          "Float32": -32, "Float64": -64}


def twin_array(a):
    """The array as the FITS twin should hold it (dtype the reader produces)."""
    if a.dtype in (np.uint32, np.uint64):
        return a.astype(np.int64)
    return a


# ------------------------------------------------------------ block encoding

def shuffle(raw, itemsize):
    """XISF byte shuffling: byte 0 of every item, then byte 1, ...; a
    trailing partial item is copied as is."""
    n = len(raw) // itemsize
    body = np.frombuffer(raw[:n * itemsize], np.uint8).reshape(n, itemsize)
    return body.T.tobytes() + raw[n * itemsize:]


def compress_one(codec, data):
    if codec == "zlib":
        return zlib.compress(data, 9)
    if codec == "lz4":
        return lz4.block.compress(data, store_size=False)
    if codec == "lz4hc":
        return lz4.block.compress(data, mode="high_compression",
                                  store_size=False)
    if codec == "zstd":
        return zstandard.ZstdCompressor(level=3).compress(data)
    raise ValueError(codec)


class Block:
    """A data block: stored bytes plus the attributes that describe them."""

    def __init__(self, raw, codec=None, itemsize=1, shuffled=False,
                 subblock=None, raw_subblocks=(), checksum=None,
                 bad_checksum=False, lie_size=0):
        self.attrs = {}
        stored = raw
        if codec:
            data = shuffle(raw, itemsize) if shuffled else raw
            if subblock:
                parts, sizes = [], []
                for k, i in enumerate(range(0, len(data), subblock)):
                    chunk = data[i:i + subblock]
                    c = chunk if k in raw_subblocks else compress_one(codec, chunk)
                    parts.append(c)
                    sizes.append(f"{len(c)},{len(chunk)}")
                stored = b"".join(parts)
                self.attrs["subblocks"] = ":".join(sizes)
            else:
                stored = compress_one(codec, data)
            name = codec + ("+sh" if shuffled else "")
            usize = len(raw) + lie_size
            self.attrs["compression"] = (f"{name}:{usize}:{itemsize}"
                                         if shuffled else f"{name}:{usize}")
        if checksum:
            algo = {"sha-1": "sha1", "sha-256": "sha256", "sha-512": "sha512",
                    "sha3-256": "sha3_256", "sha3-512": "sha3_512"}[checksum]
            digest = hashlib.new(algo, stored).hexdigest()
            if bad_checksum:
                digest = digest[:-1] + ("0" if digest[-1] != "0" else "1")
            self.attrs["checksum"] = f"{checksum}:{digest}"
        self.stored = stored


# -------------------------------------------------------------- XML builder

def attrs_xml(d):
    return "".join(f" {k}={quoteattr(str(v))}" for k, v in d.items())


def prop(pid, ptype, value=None, text=None):
    if text is not None:
        return f'<Property id="{pid}" type="{ptype}">{escape(text)}</Property>'
    return f'<Property id="{pid}" type="{ptype}" value={quoteattr(str(value))}/>'


def prop_vector(pid, values):
    b = base64.b64encode(np.asarray(values, "<f8").tobytes()).decode()
    return (f'<Property id="{pid}" type="F64Vector" length="{len(values)}" '
            f'location="inline:base64">{b}</Property>')


def prop_matrix(pid, m):
    m = np.asarray(m, "<f8")
    b = base64.b64encode(m.tobytes()).decode()   # row-major, as the spec says
    return (f'<Property id="{pid}" type="F64Matrix" rows="{m.shape[0]}" '
            f'columns="{m.shape[1]}" location="inline:base64">{b}</Property>')


def keyword(name, value="", comment=""):
    return (f'<FITSKeyword name="{name}" value={quoteattr(value)} '
            f'comment={quoteattr(comment)}/>')


class Image:
    """One <Image> element. `pixels` is (channels, [depth,] h, w), the
    planar logical layout; storage only changes how it is serialised."""

    def __init__(self, pixels, fmt, color="Gray", storage=None, order="little",
                 bounds=None, children=(), extra=None, block_kw=None,
                 embedded=None, geometry=None, location=None):
        self.pixels, self.fmt = pixels, fmt
        self.color, self.storage, self.order = color, storage, order
        self.bounds, self.children = bounds, list(children)
        self.extra = extra or {}
        self.embedded = embedded        # None, "base64" or "hex"
        self.geometry, self.location = geometry, location
        a = pixels
        if storage == "Normal":
            a = np.moveaxis(a, 0, -1)   # channel fastest
        a = a.astype(a.dtype.newbyteorder(">" if order == "big" else "<"))
        bk = dict(block_kw or {})
        bk.setdefault("itemsize", pixels.dtype.itemsize)
        self.block = Block(np.ascontiguousarray(a).tobytes(), **bk)

    def element(self, pos):
        nch = self.pixels.shape[0]
        dims = list(reversed(self.pixels.shape[1:]))     # w, h[, d]
        at = {"geometry": self.geometry or ":".join(str(d) for d in dims + [nch]),
              "sampleFormat": self.fmt}
        if self.bounds:
            at["bounds"] = self.bounds
        if self.color != "Gray":
            at["colorSpace"] = self.color
        if self.storage:
            at["pixelStorage"] = self.storage
        if self.order == "big":
            at["byteOrder"] = "big"
        at.update(self.extra)
        inner = "".join(self.children)
        if self.embedded:
            enc = (base64.b64encode(self.block.stored).decode()
                   if self.embedded == "base64" else self.block.stored.hex())
            at["location"] = "embedded"
            inner = (f'<Data encoding="{self.embedded}"'
                     f'{attrs_xml(self.block.attrs)}>{enc}</Data>' + inner)
        else:
            at.update(self.block.attrs)
            at["location"] = (self.location if self.location
                              else f"attachment:{pos}:{len(self.block.stored)}")
        return f"<Image{attrs_xml(at)}>{inner}</Image>"


def write_xisf(path, images, metadata=(), trailer="", prolog="",
               magic=b"XISF0100", reserved=0, lie_header=0, truncate=None,
               root_attrs=None,
               xmldecl='<?xml version="1.0" encoding="UTF-8"?>'):
    """Lay out a monolithic unit. Attachment positions depend on the header
    length and the header length on the positions' digit count, so iterate
    until the layout is stable."""
    attached = [im for im in images if not im.embedded and not im.location]
    positions = [0] * len(attached)
    root = {"version": "1.0", "xmlns": "http://www.pixinsight.com/xisf"}
    root.update(root_attrs or {})
    meta = [prop("XISF:CreationTime", "TimePoint", CREATED),
            prop("XISF:CreatorApplication", "String",
                 text="DS9 Tests make_xisf_fixtures.py"),
            prop("XISF:BlockAlignmentSize", "UInt16", ALIGN)] + list(metadata)
    while True:
        it = iter(positions)
        body = "".join(im.element(next(it) if im in attached else 0)
                       for im in images)
        xml = (xmldecl + "\n" + prolog +
               f"<xisf{attrs_xml(root)}>" + body +
               "<Metadata>" + "".join(meta) + "</Metadata></xisf>" + trailer)
        header = xml.encode("utf-8")
        pos, new = 16 + len(header), []
        for im in attached:
            pos = -(-pos // ALIGN) * ALIGN
            new.append(pos)
            pos += len(im.block.stored)
        if new == positions:
            break
        positions = new
    out = bytearray(magic + struct.pack("<II", len(header) + lie_header,
                                        reserved) + header)
    for im, p in zip(attached, positions):
        out += b"\0" * (p - len(out))
        out += im.block.stored
    if truncate:
        out = out[:truncate(len(out), positions)]
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(bytes(out))


# ------------------------------------------------------------------- twins

def write_twin(path, pixels, header_cards=(), bounds=None):
    """pixels: (channels, [depth,] h, w) in XISF order (row 0 = top)."""
    a = twin_array(pixels)[..., ::-1, :]          # flip rows
    if a.shape[0] == 1:
        a = a[0]                                   # gray: drop channel axis
    elif a.ndim == 4:
        raise ValueError("no twin for multi-channel 3-D images")
    hdu = fits.PrimaryHDU(np.ascontiguousarray(a))
    if bounds:
        lo, hi = (float(v) for v in bounds.split(":"))
        hdu.header["DATAMIN"], hdu.header["DATAMAX"] = lo, hi
    for k, v in header_cards:
        hdu.header[k] = v
    hdu.writeto(path, overwrite=True)


def fixture(rel, images, expect="load", notes="", twin=None, twin_cards=(),
            **kw):
    path = OUT / rel
    write_xisf(path, images, **kw)
    bitpix = ""
    if expect in ("load", "load-first"):
        im = twin if twin is not None else images[0]
        write_twin(path.with_suffix(".fits"), im.pixels, twin_cards, im.bounds)
        bitpix = str(BITPIX[im.fmt])
    MANIFEST.append((rel, expect, bitpix, notes))


def gray(fmt, f=None):
    return as_format(ramp() if f is None else f, fmt)[None]


def bounds_for(fmt):
    return "0:1" if fmt.startswith("Float") else None


# ---------------------------------------------------------------- families

def formats():
    for fmt in ["UInt8", "UInt16", "UInt32", "UInt64", "Float32", "Float64"]:
        fixture(f"formats/{fmt.lower()}.xisf",
                [Image(gray(fmt), fmt, bounds=bounds_for(fmt))],
                notes="baseline sample format")
    for fmt in ["Complex32", "Complex64"]:
        fixture(f"formats/{fmt.lower()}.xisf", [Image(gray(fmt), fmt)],
                expect="refuse", notes="complex samples are refused by name")
    big = gray("UInt64")
    big[0, 0, 0] = np.uint64(2**63 + 5)          # top-left: does not fit int64
    fixture("formats/uint64_overflow.xisf", [Image(big, "UInt64")],
            expect="refuse", notes="a UInt64 value above INT64_MAX: refuse, never wrap")
    f = ramp()
    # exactly where the probe samples: FITS (1,1), (W/2,H/2), (W,H) are XISF
    # (row H-1, col 0), (row H/2, col W/2-1) and (row 0, col W-1)
    f[H - 1, 0], f[H // 2, W // 2 - 1], f[0, W - 1] = np.nan, np.inf, -np.inf
    for fmt in ["Float32", "Float64"]:
        fixture(f"formats/{fmt.lower()}_nonfinite.xisf",
                [Image(gray(fmt, f), fmt, bounds="0:1")],
                notes="NaN, +Inf, -Inf under the three probed pixels")
    fixture("formats/float32_bounds_wide.xisf",
            [Image(gray("Float32", ramp() * 1000 - 200), "Float32",
                   bounds="-200:800")],
            notes="bounds other than 0:1")
    fixture("formats/float32_no_bounds.xisf",
            [Image(gray("Float32"), "Float32")],
            notes="bounds is required for float images (spec 11.5.1), but it "
                  "only sets display range, which DS9 computes anyway: tolerate")


def codecs():
    for fmt in ["UInt16", "Float32"]:
        for codec in ["zlib", "lz4", "lz4hc", "zstd"]:
            for sh in (False, True):
                name = f"{fmt.lower()}_{codec}{'_sh' if sh else ''}"
                fixture(f"codecs/{name}.xisf",
                        [Image(gray(fmt), fmt, bounds=bounds_for(fmt),
                               block_kw=dict(codec=codec, shuffled=sh))],
                        notes=f"{codec}{'+sh' if sh else ''}")
    nbytes = W * H * 4
    fixture("codecs/float32_zstd_sh_subblocks.xisf",
            [Image(gray("Float32"), "Float32", bounds="0:1",
                   block_kw=dict(codec="zstd", shuffled=True,
                                 subblock=nbytes // 3 + 1))],
            notes="three subblocks, shuffled across the whole block first")
    fixture("codecs/float32_zlib_raw_subblock.xisf",
            [Image(gray("Float32"), "Float32", bounds="0:1",
                   block_kw=dict(codec="zlib", subblock=nbytes // 4,
                                 raw_subblocks={1, 3}))],
            notes="subblocks 1 and 3 stored raw (c == u): copy, do not inflate")
    fixture("codecs/uint16_lz4_odd_sh.xisf",
            [Image(gray("UInt16", ramp(W - 1, H)), "UInt16",
                   block_kw=dict(codec="lz4", shuffled=True, itemsize=3))],
            notes="itemSize 3 does not divide the block: trailing bytes unshuffled")


def storage():
    f = ramp()
    rgb = np.stack([f, 1 - f, (f * 7) % 1])
    for fmt in ["UInt16", "Float32"]:
        for st in ["Planar", "Normal"]:
            fixture(f"storage/rgb_{fmt.lower()}_{st.lower()}.xisf",
                    [Image(as_format(rgb, fmt), fmt, color="RGB", storage=st,
                           bounds=bounds_for(fmt))],
                    notes="RGB; plain frame shows a 3-plane cube; R,G,B,R,... corners differ")
    cube = np.stack([as_format(ramp(), "UInt16") // 4 + 10000 * k
                     for k in range(3)]).astype(np.uint16)[None]
    fixture("storage/uint16_cube3.xisf", [Image(cube, "UInt16")],
            notes="geometry W:H:3:1; planes offset by 10000 (cf. asdf int16_cube3)")
    fixture("storage/uint16_cube3_zstd_sh.xisf",
            [Image(cube, "UInt16", block_kw=dict(codec="zstd", shuffled=True))],
            notes="cube through a codec")
    fixture("storage/uint16_plane1.xisf",
            [Image(as_format(ramp(), "UInt16")[None, None], "UInt16")],
            notes="geometry W:H:1:1; depth 1 must not open the Cube panel")
    lab = np.stack([f, f * 0.5 + 0.25, 0.75 - f * 0.5])
    fixture("storage/cielab_float32.xisf",
            [Image(lab.astype(np.float32), "Float32", color="CIELab",
                   bounds="0:1")],
            notes="CIELab: 3-plane cube, no colour conversion")
    rgba = np.concatenate([rgb, np.ones((1, H, W)) * 0.5])
    fixture("storage/rgba_float32.xisf",
            [Image(rgba.astype(np.float32), "Float32", color="RGB",
                   bounds="0:1")],
            notes="4 channels: RGB + alpha; the alpha plane is the 4th")


def byteorder():
    for fmt in ["UInt16", "UInt32", "Float32", "Float64"]:
        fixture(f"byteorder/{fmt.lower()}_big.xisf",
                [Image(gray(fmt), fmt, order="big", bounds=bounds_for(fmt))],
                notes="byteOrder=big")
    fixture("byteorder/float32_big_zlib_sh.xisf",
            [Image(gray("Float32"), "Float32", order="big", bounds="0:1",
                   block_kw=dict(codec="zlib", shuffled=True))],
            notes="byte order applies to the uncompressed, unshuffled data")


def location():
    for enc in ["base64", "hex"]:
        fixture(f"location/embedded_{enc}.xisf",
                [Image(gray("UInt16"), "UInt16", embedded=enc)],
                notes=f"location=embedded, <Data encoding={enc}>")
    fixture("location/embedded_base64_zlib.xisf",
            [Image(gray("UInt16"), "UInt16", embedded="base64",
                   block_kw=dict(codec="zlib", checksum="sha-1"))],
            notes="compression and checksum carried on the <Data> child")
    a = Image(gray("UInt16"), "UInt16", extra={"id": "light"})
    b = Image(gray("Float32", ramp(32, 24)), "Float32", bounds="0:1",
              extra={"id": "small"})
    c = Image(as_format(np.stack([ramp()] * 3), "UInt8"), "UInt8",
              color="RGB", extra={"id": "preview"})
    fixture("location/multi_three.xisf", [a, b, c], expect="load-first",
            notes="ids light/small/preview; default load is the first. "
                  "Twins for the others: multi_three__<id>.fits")
    write_twin(OUT / "location/multi_three__small.fits", b.pixels, (), "0:1")
    write_twin(OUT / "location/multi_three__preview.fits", c.pixels)
    fixture("location/inline_on_image.xisf",
            [Image(gray("UInt8"), "UInt8", location="inline:base64")],
            expect="refuse", notes="inline: is forbidden on Image (spec 11.5)")
    fixture("location/url_in_monolithic.xisf",
            [Image(gray("UInt8"), "UInt8",
                   location="url(https://example.invalid/x.xisb)")],
            expect="refuse", notes="external block in a monolithic unit; never fetch")
    fixture("location/path_external.xisf",
            [Image(gray("UInt8"), "UInt8", location="path(@header_dir/x.xisb)")],
            expect="refuse", notes="distributed XISF is out of scope for v1")


def checksums():
    for algo in ["sha-1", "sha-256", "sha-512", "sha3-256", "sha3-512"]:
        fixture(f"checksum/{algo.replace('-', '')}.xisf",
                [Image(gray("UInt16"), "UInt16",
                       block_kw=dict(checksum=algo))],
                notes=f"good {algo}" + (" (sha3 may be 'unsupported' at first)"
                                        if algo.startswith("sha3") else ""))
    fixture("checksum/sha256_zstd.xisf",
            [Image(gray("UInt16"), "UInt16",
                   block_kw=dict(codec="zstd", checksum="sha-256"))],
            notes="digest is over the stored (compressed) bytes")
    fixture("checksum/sha256_bad.xisf",
            [Image(gray("UInt16"), "UInt16",
                   block_kw=dict(checksum="sha-256", bad_checksum=True))],
            expect="refuse", notes="checksum mismatch: the block is unavailable")
    fixture("checksum/sha256_bad_zstd.xisf",
            [Image(gray("UInt16"), "UInt16",
                   block_kw=dict(codec="zstd", checksum="sha-256",
                                 bad_checksum=True))],
            expect="refuse", notes="bad checksum: must not even decompress")


def header():
    kws = [keyword("OBJECT", "'M31 & friends'", "target <name>"),
           keyword("EXPTIME", "300.", "[s]"),
           keyword("FILTER", "'Ha'"),
           keyword("HISTORY", "", "calibrated by a test script"),
           keyword("COMMENT", "", "an empty-value COMMENT card"),
           keyword("NAXIS1", "999", "stale: from the original FITS"),
           keyword("BITPIX", "16", "stale: the image is Float32"),
           keyword("BZERO", "32768", "stale: must not rescale a float image")]
    props = [prop("Observation:Object:Name", "String", text="M31"),
             prop("Instrument:ExposureTime", "Float32", 300.0),
             prop("Instrument:Filter:Name", "String", text="Ha"),
             prop("Observation:Time:Start", "TimePoint", "2026-10-01T03:00:00Z"),
             prop("Observation:Time:End", "TimePoint", "2026-10-01T03:05:00Z"),
             prop("Instrument:Camera:XBinning", "Int32", 2)]
    fixture("header/keywords.xisf",
            [Image(gray("Float32"), "Float32", bounds="0:1",
                   children=kws + props, extra={"imageType": "Light"})],
            notes="FITSKeywords incl. & and < escapes, empty HISTORY/COMMENT, "
                  "stale NAXIS1/BITPIX/BZERO the reader must override",
            twin_cards=[("OBJECT", "M31 & friends"), ("EXPTIME", 300.0),
                        ("FILTER", "Ha")])
    fixture("header/signed.xisf", [Image(gray("UInt16"), "UInt16")],
            trailer='<Signature xmlns="http://www.w3.org/2000/09/xmldsig#">'
                    '<SignedInfo/></Signature>',
            notes="detached <Signature> after </xisf>: two top-level elements")
    fixture("header/comment_and_foreign.xisf",
            [Image(gray("UInt16"), "UInt16",
                   children=['<ext:Thing xmlns:ext="urn:example:ext" a="1"/>',
                             '<Unknown attr="x"/>'],
                   extra={"orientation": "flip", "someFutureAttribute": "1"})],
            prolog="<!-- generated for DS9 tests; decoders ignore this -->\n",
            notes="XML comment, foreign-namespace and unknown elements and "
                  "attributes are ignored; orientation is a display hint only")
    thumb = ('<Thumbnail geometry="16:12:1" sampleFormat="UInt8" '
             'location="attachment:0:0"/>')
    fixture("header/with_thumbnail.xisf",
            [Image(gray("UInt16"), "UInt16", children=[thumb])],
            notes="a <Thumbnail> child is not an image to load; its bogus "
                  "location must not break the parent")
    fixture("header/empty_vector_property.xisf",
            [Image(gray("UInt16"), "UInt16", children=[
                '<Property id="Empty" type="F64Vector" length="0" '
                'location="inline:base64"/>',
                '<Property id="EmptyMatrix" type="F64Matrix" rows="0" '
                'columns="0" location="inline:base64"/>',
                '<ICCProfile location="inline:base64">AAAA</ICCProfile>'])],
            notes="empty vector/matrix = inline block with no content (spec "
                  "11.1.8); libXISF writes one and crashed sergio-dr/xisf; "
                  "plus an inline ICCProfile, as PixInsight writes")
    fixture("header/offset_pedestal.xisf",
            [Image(gray("UInt16"), "UInt16", extra={"offset": "100"})],
            notes="offset is recorded, pixels are not changed")


# --------------------------------------------------------------------- WCS

PROJ = {"Gnomonic": "TAN", "Stereographic": "STG", "ZenithalEqualArea": "ZEA",
        "Orthographic": "SIN", "PlateCarree": "CAR", "Mercator": "MER",
        "HammerAitoff": "AIT"}


def mirror_vertically(cards):
    """PCL's WCSKeywords::MirrorVertically, for a keyword list whose rows
    are about to be stored in reverse order."""
    names = {k for k, _ in cards}
    has_matrix = any(n.startswith(("CD1_", "CD2_", "PC1_", "PC2_"))
                     for n in names)
    out = []
    for k, v in cards:
        if k == "CRPIX2":
            v = H + 1 - v
        elif k in ("CD1_2", "CD2_2", "PC1_2", "PC2_2"):
            v = -v
        elif k == "CDELT2" and not has_matrix:
            v = -v
        out.append((k, v))
    return out


def solution(proj="Gnomonic", crval=(10.6847, 41.2690), ref=(30.25, 20.75),
             scale=1.0 / 3600, rot=30.0, frame=None, extra=(),
             prefix="AstrometricSolution:", version="1.0", native=None,
             pole=None):
    t = np.radians(rot)
    # north up, east left as displayed top-down, then rotated
    m = scale * np.array([[-np.cos(t), np.sin(t)], [-np.sin(t), -np.cos(t)]])
    p = ([prop(prefix + "Version", "String", text=version)]
         if version else [])
    p += [prop(prefix + "ProjectionSystem", "String", text=proj),
          prop_vector(prefix + "ReferenceCelestialCoordinates", crval),
          prop_vector(prefix + "ReferenceImageCoordinates", ref),
          prop_matrix(prefix + "LinearTransformationMatrix", m)]
    if native:
        p.append(prop_vector(prefix + "ReferenceNativeCoordinates", native))
    if pole:
        p.append(prop_vector(prefix + "CelestialPoleNativeCoordinates", pole))
    if frame:
        p.append(prop(prefix + "CelestialReferenceSystem",
                      "String", text=frame))
    p += list(extra)
    code = PROJ.get(proj, "TAN")
    cards = [("CTYPE1", f"RA---{code}"), ("CTYPE2", f"DEC--{code}"),
             ("CRVAL1", crval[0]), ("CRVAL2", crval[1]),
             ("CRPIX1", ref[0] + 0.5), ("CRPIX2", H - ref[1] + 0.5),
             ("CD1_1", m[0, 0]), ("CD1_2", -m[0, 1]),
             ("CD2_1", m[1, 0]), ("CD2_2", -m[1, 1]),
             ("RADESYS", "ICRS")]
    if native:
        cards += [("PV1_1", native[0]), ("PV1_2", native[1])]
    if pole:
        cards += [("LONPOLE", pole[0]), ("LATPOLE", pole[1])]
    return p, cards


def wcs():
    for proj in PROJ:
        crval = (10.6847, 41.2690) if PROJ[proj] in ("TAN", "STG", "ZEA",
                                                     "SIN") else (10.6847, 0.0)
        p, cards = solution(proj, crval=crval, scale=10.0 / 3600)
        fixture(f"wcs/layer1_{PROJ[proj].lower()}.xisf",
                [Image(gray("Float32"), "Float32", bounds="0:1", children=p)],
                notes=f"{proj} -> {PROJ[proj]}; 10\"/px so the projection matters",
                twin_cards=cards)
    p, cards = solution(rot=0.0)
    fixture("wcs/layer1_tan_northup.xisf",
            [Image(gray("Float32"), "Float32", bounds="0:1", children=p)],
            notes="rotation 0: north up, east left; easiest to eyeball",
            twin_cards=cards)
    p, cards = solution(frame="GCRS")
    fixture("wcs/layer1_tan_gcrs.xisf",
            [Image(gray("Float32"), "Float32", bounds="0:1", children=p)],
            notes="GCRS: no FITS RADESYS value; expected mapped to ICRS + warning",
            twin_cards=cards)
    p, _ = solution(proj="Bonne")
    fixture("wcs/unknown_projection.xisf",
            [Image(gray("Float32"), "Float32", bounds="0:1", children=p)],
            notes="unknown ProjectionSystem disables the solution: image, no WCS")
    p, cards = solution(extra=[prop(
        "AstrometricSolution:DistortionModel:ImageToProjection:BasisFunction",
        "String", text="ThinPlateSpline")])
    fixture("wcs/layer3_incomplete.xisf",
            [Image(gray("Float32"), "Float32", bounds="0:1", children=p)],
            notes="an incomplete layer 3 falls back to layer 1", twin_cards=cards)
    p, cards = solution(extra=[prop(
        "AstrometricSolution:DistortionModel:ImageToProjection:BasisFunction",
        "String", text="NotABasis")])
    fixture("wcs/layer3_unknown_basis.xisf",
            [Image(gray("Float32"), "Float32", bounds="0:1", children=p)],
            notes="unknown BasisFunction: layer 3 unavailable, layer 1 stands",
            twin_cards=cards)
    stale = [keyword("CTYPE1", "'RA---TAN'"), keyword("CTYPE2", "'DEC--TAN'"),
             keyword("CRVAL1", "200.0"), keyword("CRVAL2", "-30.0"),
             keyword("CRPIX1", "1.0"), keyword("CRPIX2", "1.0"),
             keyword("CDELT1", "-0.001"), keyword("CDELT2", "0.001")]
    p, cards = solution()
    fixture("wcs/properties_beat_keywords.xisf",
            [Image(gray("Float32"), "Float32", bounds="0:1",
                   children=stale + p)],
            notes="stale WCS FITSKeywords + a solution: the solution wins",
            twin_cards=cards)
    fixture("wcs/keywords_only.xisf",
            [Image(gray("Float32"), "Float32", bounds="0:1", children=stale)],
            notes="WCS from FITSKeywords alone. Per PCL, keywords refer to "
                  "rows in storage order (row 1 = top), so the twin's cards "
                  "are MirrorVertically'd: CRPIX2 1 -> H, CDELT2 negated",
            twin_cards=mirror_vertically(
                [("CTYPE1", "RA---TAN"), ("CTYPE2", "DEC--TAN"),
                 ("CRVAL1", 200.0), ("CRVAL2", -30.0),
                 ("CRPIX1", 1.0), ("CRPIX2", 1.0),
                 ("CDELT1", -0.001), ("CDELT2", 0.001)]))
    p, cards = solution(prefix="PCL:AstrometricSolution:", version=None)
    fixture("wcs/legacy_pcl_prefix.xisf",
            [Image(gray("Float32"), "Float32", bounds="0:1", children=p)],
            notes="pre-standard PixInsight block (PCL:AstrometricSolution:*, "
                  "no Version); PCL still reads it, same semantics",
            twin_cards=cards)
    p, _ = solution(version="2.0")
    fixture("wcs/solution_version_2.xisf",
            [Image(gray("Float32"), "Float32", bounds="0:1", children=p)],
            notes="AstrometricSolution:Version major != 1: PCL ignores the "
                  "whole block. Image, no WCS")
    p, cards = solution(native=(0.0, 90.0), pole=(180.0, 90.0))
    pcl_keywords = [keyword(k, f"'{v}'" if isinstance(v, str) else repr(float(v)))
                    for k, v in cards]
    fixture("wcs/pcl_shaped.xisf",
            [Image(gray("Float32"), "Float32", bounds="0:1",
                   children=pcl_keywords + p)],
            notes="what PCL 2.15 writes: the full layer 1 set incl. native and "
                  "pole coordinates, plus the WCS keywords ComputeWCSKeywords "
                  "emits (bottom-up: they equal the twin's cards). Properties "
                  "win, so the answer is the same either way",
            twin_cards=cards)
    p, _ = solution()
    p = [x for x in p if "LinearTransformationMatrix" not in x]
    fixture("wcs/layer1_missing_matrix.xisf",
            [Image(gray("Float32"), "Float32", bounds="0:1", children=p)],
            notes="a required layer 1 property is missing: image, no WCS")


# -------------------------------------------------------------- malformed

def malformed():
    img = lambda: [Image(gray("UInt16"), "UInt16")]
    cases = [
        ("bad_magic", dict(magic=b"XISF0200"), "wrong signature"),
        ("header_len_past_eof", dict(lie_header=10_000_000),
         "header length runs past end of file"),
        ("header_len_short", dict(lie_header=-40),
         "header length cuts the XML short"),
        ("attachment_past_eof",
         dict(truncate=lambda n, pos: pos[0] + 100),
         "attachment position + size past end of file"),
        ("version_2", dict(root_attrs={"version": "2.0"}),
         "unsupported XISF version"),
        ("wrong_namespace", dict(root_attrs={"xmlns": "urn:not-xisf"}),
         "root is not in the XISF namespace"),
    ]
    for name, kw, why in cases:
        fixture(f"malformed/{name}.xisf", img(), expect="refuse", notes=why, **kw)
    fixture("header/reserved_nonzero.xisf", img(), reserved=7,
            notes="reserved bytes 12-15 nonzero: 'shall be zero' binds "
                  "writers; readers tolerate it")
    fixture("header/xml_decl_no_encoding.xisf", img(),
            xmldecl='<?xml version="1.0"?>',
            notes="libXISF omits encoding=UTF-8 (spec says must begin with "
                  "it); real files do this, so tolerate")
    fixture("malformed/size_lie.xisf",
            [Image(gray("UInt16"), "UInt16",
                   block_kw=dict(codec="zstd", lie_size=2))],
            expect="refuse",
            notes="declared uncompressed size != actual: invalid block")
    fixture("malformed/unknown_codec.xisf",
            [Image(gray("UInt16"), "UInt16",
                   extra={"compression": "brotli:6144"})],
            expect="refuse", notes="unknown codec: image unavailable. Stored "
                                   "size == declared size, so a reader that "
                                   "applies the raw-subblock rule before "
                                   "checking the codec name loads it by mistake")
    fixture("malformed/geometry_zero.xisf",
            [Image(gray("UInt16"), "UInt16", geometry="0:48:1")],
            expect="refuse", notes="zero dimension")
    fixture("malformed/geometry_mismatch.xisf",
            [Image(gray("UInt16"), "UInt16", geometry="64:4800:1")],
            expect="refuse", notes="geometry needs 100x more bytes than the block holds")
    fixture("malformed/geometry_overflow.xisf",
            [Image(gray("UInt16"), "UInt16",
                   geometry="4294967295:4294967295:65535")],
            expect="refuse", notes="geometry product overflows 64 bits")
    fixture("malformed/no_images.xisf", [], expect="refuse",
            notes="valid unit with no Image: nothing to load")


def main():
    for fam in (formats, codecs, storage, byteorder, location, checksums,
                header, wcs, malformed):
        fam()
    with open(OUT / "MANIFEST.tsv", "w") as fh:
        fh.write("# fixture\texpect\tbitpix\tnotes\n")
        for row in MANIFEST:
            fh.write("\t".join(row) + "\n")
    print(f"{len(MANIFEST)} fixtures written under {OUT}")


if __name__ == "__main__":
    main()
