#!/usr/bin/env python3
"""Generate one ASDF/GWCS fixture per non-projection GWCS primitive.

Companion to make_gwcs_fixtures.py, which covers the 27 sky projections.
This covers the other half of what `ast/src/yamlchan.c` implements: the
transforms, the combinators that glue them together, and the celestial
reference frames.

These cannot be checked against the 1904-66 set -- there is no FITS file
whose WCS is "rotate2d by 30 degrees". So instead each fixture maps pixel
coordinates straight to lon/lat with no projection, which makes the expected
answer a closed-form calculation, and carries that answer in its own `meta`
block. The validator reads it back from the file rather than keeping a
separate table that could drift.

Parameter names come from the Read* functions in yamlchan.c, which is what
parses them -- not from the asdf-standard schemas, which are a superset.
Several primitives are 1-in/1-out (shift, scale, linear1d, multiplyscale),
so a 2-D WCS has to pair them with `concatenate`; that is noted per fixture
rather than pretended away.
"""

import json
import math
import os
import struct

HERE = os.path.dirname(os.path.abspath(__file__))
OUTDIR = os.path.join(HERE, "transform")
FRAMEDIR = os.path.join(HERE, "frames")

# The one pixel every fixture is checked at.
PX, PY = 10.0, 20.0

D2R = math.pi / 180.0


def norm_lon(v):
    return v % 360.0


def block(payload):
    hdr = struct.pack(">IIQQQ16s", 0, 0, len(payload), len(payload),
                      len(payload), b"\x00" * 16)
    return b"\xd3BLK" + struct.pack(">H", 48) + hdr + payload


def write_asdf(path, tree_body, payload):
    head = ("#ASDF 1.0.0\n#ASDF_STANDARD 1.5.0\n%YAML 1.1\n"
            "%TAG ! tag:stsci.edu:asdf/\n--- !core/asdf-1.1.0\n")
    tree = head + tree_body + "...\n"
    idx = ("#ASDF BLOCK INDEX\n%YAML 1.1\n---\n- "
           + str(len(tree.encode())) + "\n...\n")
    with open(path, "wb") as fh:
        fh.write(tree.encode() + block(payload) + idx.encode())
    return os.path.getsize(path)


def fnum(v):
    s = repr(float(v))
    return s if ("." in s or "e" in s or "E" in s) else s + ".0"


# The authority prefix matters: the tag is
# tag:astropy.org:astropy/coordinates/frames/<name>-<ver>, and yamlchan.c
# compares the whole class string, so dropping "astropy.org:" makes every
# frame unrecognized -- which fails silently as "no WCS", not as a bad tag.
#
# The names are the ones MAKE_TEST spells, not the ones astropy writes:
# it wants "ecliptic", so a real file's "baseecliptic" would not match
# (strncasecmp compares up to the version dash, so the lengths must agree).
FRAME_TAGS = {
    "icrs": "astropy.org:astropy/coordinates/frames/icrs-1.1.0",
    "fk5": "astropy.org:astropy/coordinates/frames/fk5-1.0.0",
    "fk4": "astropy.org:astropy/coordinates/frames/fk4-1.0.0",
    "fk4noeterms": "astropy.org:astropy/coordinates/frames/fk4noeterms-1.0.0",
    "galactic": "astropy.org:astropy/coordinates/frames/galactic-1.0.0",
    "supergalactic": "astropy.org:astropy/coordinates/frames/supergalactic-1.0.0",
    "ecliptic": "astropy.org:astropy/coordinates/frames/ecliptic-1.0.0",
    "altaz": "astropy.org:astropy/coordinates/frames/altaz-1.0.0",
}

# Galactic and ecliptic frames are not equatorial, so their axes carry
# different UCDs -- and yamlchan.c checks these against the frame it built,
# so getting them wrong is an error rather than cosmetic.
FRAME_UCD = {
    "galactic": ("pos.galactic.lon", "pos.galactic.lat"),
    "supergalactic": ("pos.supergalactic.lon", "pos.supergalactic.lat"),
    "ecliptic": ("pos.ecliptic.lon", "pos.ecliptic.lat"),
    "altaz": ("pos.az.azi", "pos.az.alt"),
}


def tree(name, transform, expect, frame="icrs", attrs="{}", note=""):
    lon_ucd, lat_ucd = FRAME_UCD.get(frame, ("pos.eq.ra", "pos.eq.dec"))
    meta = {"primitive": name, "expect_at": [PX, PY],
            "expect_lonlat": [round(expect[0], 9), round(expect[1], 9)],
            "expect_sky": frame}
    if note:
        meta["note"] = note
    return """asdf_library: !core/software-1.0.0 {{name: make_gwcs_transform_fixtures, version: '1.0'}}
meta: {meta}
data: !core/ndarray-1.1.0
  source: 0
  datatype: uint8
  byteorder: big
  shape: [32, 32]
wcs: !<tag:stsci.edu:gwcs/wcs-1.4.0>
  name: {name}
  steps:
  - !<tag:stsci.edu:gwcs/step-1.3.0>
    frame: !<tag:stsci.edu:gwcs/frame2d-1.2.0>
      axes_names: [x, y]
      axes_order: [0, 1]
      axis_physical_types: ['custom:x', 'custom:y']
      name: detector
      unit: [!unit/unit-1.0.0 pixel, !unit/unit-1.0.0 pixel]
    transform: {transform}
  - !<tag:stsci.edu:gwcs/step-1.3.0>
    frame: !<tag:stsci.edu:gwcs/celestial_frame-1.2.0>
      axes_names: [lon, lat]
      axes_order: [0, 1]
      axis_physical_types: [{lon_ucd}, {lat_ucd}]
      name: world
      reference_frame: !<tag:{ftag}>
        frame_attributes: {attrs}
      unit: [!unit/unit-1.0.0 deg, !unit/unit-1.0.0 deg]
    transform: null
""".format(name=name, transform=transform, meta=json.dumps(meta),
           ftag=FRAME_TAGS[frame], attrs=attrs,
           lon_ucd=lon_ucd, lat_ucd=lat_ucd)


def cat(a, b, ind=6):
    """concatenate two 1-in/1-out transforms into a 2-in/2-out one.

    `ind` is the column its continuation lines sit at.  It has to be passed
    when nesting one of these inside another node's `forward:` list -- YAML
    is indentation sensitive, and getting it wrong produces a tree that AST
    rejects with no diagnostic beyond "could not read this WCS".
    """
    pad = " " * ind
    return ("!transform/concatenate-1.4.0\n%sforward:\n"
            "%s- %s\n%s- %s" % (pad, pad, a, pad, b))


PAIRED = ("1-in/1-out, so paired with concatenate to make a 2-D WCS")

TRANSFORMS = [
    ("identity", "!transform/identity-1.4.0 {n_dims: 2}", (PX, PY), ""),

    ("shift", cat("!transform/shift-1.4.0 {offset: 5.0}",
                  "!transform/shift-1.4.0 {offset: -3.0}"),
     (PX + 5.0, PY - 3.0), PAIRED),

    ("scale", cat("!transform/scale-1.4.0 {factor: 2.0}",
                  "!transform/scale-1.4.0 {factor: 3.0}"),
     (PX * 2.0, PY * 3.0), PAIRED),

    # NB `offset', not astropy's `intercept': ReadLinear1d reads slope and
    # offset, and a wrong key name fails as "no WCS" rather than as an error.
    ("linear1d", cat("!transform/linear1d-1.0.0 {slope: 2.0, offset: 1.0}",
                     "!transform/linear1d-1.0.0 {slope: 0.5, offset: -2.0}"),
     (PX * 2.0 + 1.0, PY * 0.5 - 2.0), PAIRED),

    ("multiplyscale", cat("!transform/multiplyscale-1.0.0 {factor: 1.5}",
                          "!transform/multiplyscale-1.0.0 {factor: 2.0}"),
     (PX * 1.5, PY * 2.0), PAIRED),

    ("affine", """!transform/affine-1.5.0
      matrix: !core/ndarray-1.1.0
        data:
        - [2.0, 0.0]
        - [0.0, 3.0]
        datatype: float64
        byteorder: little
        shape: [2, 2]
      translation: !core/ndarray-1.1.0
        data: [1.0, -2.0]
        datatype: float64
        byteorder: little
        shape: [2]""",
     (2.0 * PX + 1.0, 3.0 * PY - 2.0), ""),

    ("rotate2d", "!transform/rotate2d-1.3.0 {angle: 30.0}",
     (norm_lon(PX * math.cos(30 * D2R) - PY * math.sin(30 * D2R)),
      PX * math.sin(30 * D2R) + PY * math.cos(30 * D2R)), ""),

    ("remap_axes", """!transform/remap_axes-1.5.0
      mapping: [1, 0]""",
     (PY, PX), "swaps the two axes"),

    ("concatenate", cat("!transform/shift-1.4.0 {offset: 1.0}",
                        "!transform/scale-1.4.0 {factor: 2.0}"),
     (PX + 1.0, PY * 2.0), "two *different* 1-D transforms, unlike the pairs above"),

    ("compose", """!transform/compose-1.4.0
      forward:
      - %s
      - %s""" % (cat("!transform/shift-1.4.0 {offset: 5.0}",
                     "!transform/shift-1.4.0 {offset: 5.0}", ind=8),
                 cat("!transform/scale-1.4.0 {factor: 2.0}",
                     "!transform/scale-1.4.0 {factor: 2.0}", ind=8)),
     ((PX + 5.0) * 2.0, (PY + 5.0) * 2.0), "shift then scale, in that order"),
]


def rot3d_expect(lon, lat, phi, theta, psi):
    """What rotate3d native2celestial does, per ReadRotate3d: a FitsChan with
    CRVAL1=phi, CRVAL2=theta, LONPOLE=psi -- i.e. the native pole lands at
    (phi, theta)."""
    lo, la = lon * D2R, lat * D2R
    dp, ap, pp = theta * D2R, phi * D2R, psi * D2R
    # native -> celestial, Paper II eq (2)
    dlon = lo - pp
    sd = math.sin(la) * math.sin(dp) + math.cos(la) * math.cos(dp) * math.cos(dlon)
    dec = math.asin(max(-1.0, min(1.0, sd)))
    y = -math.cos(la) * math.sin(dlon)
    x = math.sin(la) * math.cos(dp) - math.cos(la) * math.sin(dp) * math.cos(dlon)
    ra = ap + math.atan2(y, x)
    return norm_lon(ra / D2R), dec / D2R


def main():
    os.makedirs(OUTDIR, exist_ok=True)
    os.makedirs(FRAMEDIR, exist_ok=True)
    payload = bytes(((x * 5 + y * 11) % 251 for y in range(32) for x in range(32)))
    made = []

    for name, tr, exp, note in TRANSFORMS:
        body = tree(name, tr, exp, note=note)
        sz = write_asdf(os.path.join(OUTDIR, name + ".asdf"), body, payload)
        made.append(("transform", name, sz, exp))

    # rotate3d, on top of an identity so the input is (10,20) in degrees
    phi, theta, psi = 40.0, 20.0, 180.0
    exp = rot3d_expect(PX, PY, phi, theta, psi)
    tr = ("""!transform/rotate3d-1.3.0 {phi: %s, theta: %s, psi: %s, direction: native2celestial}"""
          % (fnum(phi), fnum(theta), fnum(psi)))
    sz = write_asdf(os.path.join(OUTDIR, "rotate3d.asdf"),
                    tree("rotate3d", tr, exp,
                         note="native2celestial; input (10,20) read as native lon/lat"),
                    payload)
    made.append(("transform", "rotate3d", sz, exp))

    # yamlchan.c (around the astSetEquinox/astSetEpoch calls) requires:
    #   FK4, FK4NOETERMS -> obstime and equinox
    #   FK5, ECLIPTIC    -> equinox
    #   ALTAZ            -> location (an earthlocation) and obstime
    # ICRS, GALACTIC and SUPERGALACTIC need nothing, which is exactly why
    # those three worked with an empty frame_attributes and the rest did not.
    EQUINOX = ("equinox: !time/time-1.1.0 {value: 'J2000.000', "
               "format: jyear_str, scale: tt}")
    OBSTIME = ("obstime: !time/time-1.1.0 {value: '2020-01-01T00:00:00.000', "
               "format: isot, scale: utc}")
    LOCATION = """location: !<tag:astropy.org:astropy/coordinates/earthlocation-1.0.0>
          x: !unit/quantity-1.1.0 {value: 4517590.0, unit: !unit/unit-1.0.0 m}
          y: !unit/quantity-1.1.0 {value: 2922041.0, unit: !unit/unit-1.0.0 m}
          z: !unit/quantity-1.1.0 {value: -3508110.0, unit: !unit/unit-1.0.0 m}"""
    NEEDS = {
        "fk4": [OBSTIME, EQUINOX], "fk4noeterms": [OBSTIME, EQUINOX],
        "fk5": [EQUINOX], "ecliptic": [EQUINOX],
        "altaz": [OBSTIME, LOCATION],
    }
    for frame in FRAME_TAGS:
        need = NEEDS.get(frame)
        if need:
            attrs = "\n" + "\n".join("        " + a for a in need)
        else:
            attrs = "{}"
        note = "identity transform, so lon/lat should equal the pixel"
        body = tree("frame_" + frame, "!transform/identity-1.4.0 {n_dims: 2}",
                    (PX, PY), frame=frame, attrs=attrs, note=note)
        sz = write_asdf(os.path.join(FRAMEDIR, frame + ".asdf"), body, payload)
        made.append(("frames", frame, sz, (PX, PY)))

    print("wrote %d fixtures" % len(made))
    for where, name, sz, exp in made:
        print("  %-10s %-16s %6d B  expect %.6f %.6f" % (where, name, sz, exp[0], exp[1]))


if __name__ == "__main__":
    main()
