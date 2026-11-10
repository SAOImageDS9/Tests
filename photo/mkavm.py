#!/usr/bin/env python3
"""Make the AVM test images in photo/ from rose.png.

Astronomy Visualization Metadata (AVM) is stored as an XMP packet in
the image file. The WCS described here is synthetic: it is tagged for
a version of the image twice the size (Spatial.ReferenceDimension),
and rotated, so loading it exercises rescaling and rotation. The XMP
also has a Photoshop style history of empty elements before the AVM
tags, and a contact struct written as attributes.

  avm.png      iTXt chunk
  avmz.png     compressed iTXt chunk
  avm.jpeg     APP1 segment
  avmext.jpeg  Spatial tags only in ExtendedXMP APP1 segments
  avm.tiff     tag 700
  avm.gif      'XMP DataXMP' application extension
  avmpos.png   Spatial.Quality Position: no WCS applied
  avmcrop.png  cropped after tagging: no WCS applied

Also prints the expected sky position of a few pixels, for photo.sh.
Needs Pillow; astropy for the expected positions.
"""

import io
import os
import struct

from PIL import Image, PngImagePlugin

DIR = os.path.dirname(os.path.abspath(__file__))

# rose is 227 x 149; the WCS is for an original twice that size
NX, NY = 227, 149
REFDIM = (2 * NX, 2 * NY)
REFPIX = (300.25, 100.75)
REFVAL = (202.4696, 47.1952)
SCALE = (-2.0e-4, 2.0e-4)
ROT = 30.0

HISTORY = "".join(
    '<rdf:li stEvt:action="saved" stEvt:when="2026-11-10T00:00:0%d"/>' % i
    for i in range(3)
)


def seq(name, vals):
    lis = "".join("<rdf:li>%s</rdf:li>" % v for v in vals)
    return "<avm:%s><rdf:Seq>%s</rdf:Seq></avm:%s>" % (name, lis, name)


def spatial(quality="Full"):
    return (
        "<avm:Spatial.CoordinateFrame>ICRS</avm:Spatial.CoordinateFrame>"
        "<avm:Spatial.CoordsystemProjection>TAN</avm:Spatial.CoordsystemProjection>"
        + seq("Spatial.ReferenceValue", REFVAL)
        + seq("Spatial.ReferenceDimension", REFDIM)
        + seq("Spatial.ReferencePixel", REFPIX)
        + seq("Spatial.Scale", SCALE)
        + "<avm:Spatial.Rotation>%s</avm:Spatial.Rotation>" % ROT
        + "<avm:Spatial.Quality>%s</avm:Spatial.Quality>" % quality
    )


def packet(body, extra_attrs=""):
    return (
        '<?xpacket begin="\ufeff" id="W5M0MpCehiHzreSzNTczkc9d"?>'
        '<x:xmpmeta xmlns:x="adobe:ns:meta/">'
        '<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">'
        '<rdf:Description rdf:about=""'
        ' xmlns:avm="http://www.communicatingastronomy.org/avm/1.0/"'
        ' xmlns:dc="http://purl.org/dc/elements/1.1/"'
        ' xmlns:photoshop="http://ns.adobe.com/photoshop/1.0/"'
        ' xmlns:xmpMM="http://ns.adobe.com/xap/1.0/mm/"'
        ' xmlns:stEvt="http://ns.adobe.com/xap/1.0/sType/ResourceEvent#"'
        ' xmlns:Iptc4xmpCore="http://iptc.org/std/Iptc4xmpCore/1.0/xmlns/"'
        ' avm:MetadataVersion="1.2" avm:Type="Observation"%s>'
        "<xmpMM:History><rdf:Seq>%s</rdf:Seq></xmpMM:History>"
        '<dc:title><rdf:Alt><rdf:li xml:lang="x-default">DS9 AVM Test Rose</rdf:li></rdf:Alt></dc:title>'
        "<photoshop:Credit>SAOImageDS9 Tests</photoshop:Credit>"
        '<Iptc4xmpCore:CreatorContactInfo Iptc4xmpCore:CiEmailWork="ds9@example.org"'
        ' Iptc4xmpCore:CiAdrCity="Cambridge"/>'
        "%s"
        "</rdf:Description></rdf:RDF></x:xmpmeta>"
        '<?xpacket end="w"?>'
    ) % (extra_attrs, HISTORY, body)


def png(name, xmp, compressed=False, img=None):
    img = img or Image.open(os.path.join(DIR, "rose.png")).convert("RGB")
    info = PngImagePlugin.PngInfo()
    info.add_itxt("XML:com.adobe.xmp", xmp, zip=compressed)
    img.save(os.path.join(DIR, name), pnginfo=info)


def app1(payload):
    return b"\xff\xe1" + struct.pack(">H", len(payload) + 2) + payload


def jpeg(name, segs):
    buf = io.BytesIO()
    Image.open(os.path.join(DIR, "rose.png")).convert("RGB").save(buf, "JPEG", quality=90)
    jj = buf.getvalue()
    open(os.path.join(DIR, name), "wb").write(jj[:2] + segs + jj[2:])


def gif(name, xmp):
    buf = io.BytesIO()
    Image.open(os.path.join(DIR, "rose.png")).convert("P").save(buf, "GIF")
    gg = b"GIF89a" + buf.getvalue()[6:]
    flags = gg[10]
    pos = 13 + (3 * (1 << ((flags & 7) + 1)) if flags & 0x80 else 0)
    trailer = bytes([1] + list(range(255, -1, -1)) + [0])
    ext = b"\x21\xff\x0bXMP DataXMP" + xmp + trailer
    open(os.path.join(DIR, name), "wb").write(gg[:pos] + ext + gg[pos:])


def main():
    full = packet(spatial())
    rose = Image.open(os.path.join(DIR, "rose.png")).convert("RGB")
    assert rose.size == (NX, NY)

    png("avm.png", full)
    png("avmz.png", full, compressed=True)
    png("avmpos.png", packet(spatial("Position")))
    png("avmcrop.png", full, img=rose.crop((0, 0, NX, NY - 40)))

    jpeg("avm.jpeg", app1(b"http://ns.adobe.com/xap/1.0/\x00" + full.encode()))

    guid = b"0123456789ABCDEF0123456789ABCDEF"
    main_pkt = packet(
        "",
        ' xmlns:xmpNote="http://ns.adobe.com/xmp/note/"'
        ' xmpNote:HasExtendedXMP="%s"' % guid.decode(),
    ).encode()
    ext = (
        '<x:xmpmeta xmlns:x="adobe:ns:meta/">'
        '<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">'
        '<rdf:Description rdf:about=""'
        ' xmlns:avm="http://www.communicatingastronomy.org/avm/1.0/">'
        + spatial()
        + "</rdf:Description></rdf:RDF></x:xmpmeta>"
    ).encode()
    half = len(ext) // 2
    sig = b"http://ns.adobe.com/xmp/extension/\x00"
    segs = app1(b"http://ns.adobe.com/xap/1.0/\x00" + main_pkt)
    # out of order, as a reader must not assume otherwise
    segs += app1(sig + guid + struct.pack(">II", len(ext), half) + ext[half:])
    segs += app1(sig + guid + struct.pack(">II", len(ext), 0) + ext[:half])
    jpeg("avmext.jpeg", segs)

    rose.save(os.path.join(DIR, "avm.tiff"), tiffinfo={700: full.encode()})
    gif("avm.gif", full.encode())

    expected()


def expected():
    """Expected ICRS position of pixels in the loaded (227x149) image"""
    try:
        from astropy.wcs import WCS
    except ImportError:
        return
    rx, ry = NX / REFDIM[0], NY / REFDIM[1]
    w = WCS(naxis=2)
    w.wcs.ctype = ["RA---TAN", "DEC--TAN"]
    w.wcs.radesys = "ICRS"
    w.wcs.crval = REFVAL
    # rescale about the pixel edge, as ds9 does
    w.wcs.crpix = [(REFPIX[0] - 0.5) * rx + 0.5, (REFPIX[1] - 0.5) * ry + 0.5]
    w.wcs.cdelt = [SCALE[0] / rx, SCALE[1] / ry]
    w.wcs.crota = [ROT, ROT]
    for x, y in [(1, 1), (NX, NY), (114, 75)]:
        ra, dec = w.pixel_to_world_values(x - 1, y - 1)
        print("%d %d %.7f %.7f" % (x, y, ra, dec))


if __name__ == "__main__":
    main()
