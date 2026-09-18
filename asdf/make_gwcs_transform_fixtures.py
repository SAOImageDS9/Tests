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


def tree(name, transform, expect, frame="icrs", attrs="{}", note="",
         readout=True):
    lon_ucd, lat_ucd = FRAME_UCD.get(frame, ("pos.eq.ra", "pos.eq.dec"))
    meta = {"primitive": name, "expect_at": [PX, PY],
            "expect_lonlat": [round(expect[0], 9), round(expect[1], 9)],
            "expect_sky": frame}
    if note:
        meta["note"] = note
    if not readout:
        meta["expect_readout"] = "no"
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


def dup2():
    """remap_axes that duplicates (x,y) into (x,y,x,y).

    The 2-in/1-out primitives -- polynomial, ortho_polynomial, planar2d --
    each need both pixel axes, so two of them concatenated want four inputs.
    ReadRemapAxes takes `mapping' (one entry per output) and `n_inputs'.
    """
    return """!transform/remap_axes-1.5.0
        mapping: [0, 1, 0, 1]
        n_inputs: 2"""


def dup_y():
    """remap_axes that sends (x, y) to (x, y, y).

    For pairing ONE 2-in/1-out primitive with a 1-in/1-out one, where dup2's
    four outputs would be one too many. Used by planar2d -- see the note
    there for why it is not simply two planar2ds.
    """
    return """!transform/remap_axes-1.5.0
        mapping: [0, 1, 1]
        n_inputs: 2"""


def ndarr(rows, ind):
    """An inline 2-D float64 ndarray at the given indent."""
    pad = " " * ind
    body = "\n".join("%s- [%s]" % (pad, ", ".join(fnum(v) for v in r))
                      for r in rows)
    return ("!core/ndarray-1.1.0\n%sdata:\n%s\n%sdatatype: float64\n"
            "%sbyteorder: little\n%sshape: [%d, %d]"
            % (pad, body, pad, pad, pad, len(rows), len(rows[0])))


def poly(tag, coeffs, ind, extra=""):
    """A polynomial / ortho_polynomial node with an inline coefficient matrix."""
    pad = " " * ind
    return "!transform/%s\n%scoefficients: %s%s" % (
        tag, pad, ndarr(coeffs, ind + 2), extra)


def planar(intercept, sx, sy):
    return ("!transform/planar2d-1.0.0 {intercept: %s, slope_x: %s, slope_y: %s}"
            % (fnum(intercept), fnum(sx), fnum(sy)))


def compose2(a, b, ind=6):
    pad = " " * ind
    return "!transform/compose-1.4.0\n%sforward:\n%s- %s\n%s- %s" % (
        pad, pad, a, pad, b)


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
    # ---- the 2-in/1-out family, via a duplicating remap_axes -------------
    # planar2d is intercept + slope_x*x + slope_y*y.
    #
    # ONE planar2d, paired with a unit scale for the other axis, where the
    # obvious thing is two of them. Two planar2ds in a parallel CmpMap trip a
    # heap overread in AST (winmap.c's MapMerge -- the project's TODO.md, AST
    # bug 11), and what follows the buffer decides the outcome: on macOS the
    # WCS built and DS9 only warned about the missing inverse, while on Linux
    # the identical file failed with a CmpMap dimension mismatch. Each
    # planar2d becomes CmpMap(MatrixMap(2->1), ShiftMap(1)), and it is two of
    # those in parallel that leaves a one-axis WinMap beside a parallel CmpMap
    # of two 2-in/1-out MatrixMaps. One planar2d is clean under
    # AddressSanitizer, and tests the primitive just as well.
    #
    # An ASan sweep of all 185 fixtures found this was the only other one
    # affected after fix_inputs was rebuilt for the same reason; polynomial
    # and ortho_polynomial escape it because they become PolyMaps, with no
    # WinMap involved.
    pa = (1.0, 2.0, 3.0)
    exp = (pa[0] + pa[1] * PX + pa[2] * PY, PY)
    tr = compose2(dup_y(),
                  cat(planar(*pa), "!transform/scale-1.4.0 {factor: 1.0}",
                      ind=8))
    sz = write_asdf(os.path.join(OUTDIR, "planar2d.asdf"),
                    tree("planar2d", tr, exp,
                         note="one planar2d (2-in/1-out) with a unit scale for "
                              "the other axis; two planar2ds in parallel trip "
                              "an AST heap overread whose result differs "
                              "between macOS and Linux (TODO.md AST bug 11)"),
                    payload)
    made.append(("transform", "planar2d", sz, exp))

    # polynomial: sum c[i][j] * x**i * y**j, row index on x.
    ca = [[1.0, 2.0], [3.0, 0.0]]
    cb = [[0.0, 1.0], [1.0, 0.0]]

    def pv(c):
        return sum(c[i][j] * PX ** i * PY ** j
                   for i in range(len(c)) for j in range(len(c[0])))

    exp = (pv(ca), pv(cb))
    tr = compose2(dup2(), cat(poly("polynomial-1.3.0", ca, 10),
                              poly("polynomial-1.3.0", cb, 10), ind=8))
    sz = write_asdf(os.path.join(OUTDIR, "polynomial.asdf"),
                    tree("polynomial", tr, exp,
                         note="row index is the x power; 2-in/1-out like planar2d"),
                    payload)
    made.append(("transform", "polynomial", sz, exp))

    # ortho_polynomial: same coefficients, Chebyshev basis. Degree 1 on
    # purpose -- T0 = 1 and T1(t) = t, so the expected value is the same
    # arithmetic as the plain polynomial and this isolates the tag and
    # polynomial_type handling rather than the basis evaluation.
    dom = "\n          domain:\n          - [-1.0, 1.0]\n          - [-1.0, 1.0]"
    win = "\n          window:\n          - [-1.0, 1.0]\n          - [-1.0, 1.0]"
    ortho_extra = "\n          polynomial_type: chebyshev" + dom + win
    tr = compose2(dup2(),
                  cat(poly("ortho_polynomial-1.0.0", ca, 10, ortho_extra),
                      poly("ortho_polynomial-1.0.0", cb, 10, ortho_extra), ind=8))
    sz = write_asdf(os.path.join(OUTDIR, "ortho_polynomial.asdf"),
                    tree("ortho_polynomial", tr, exp,
                         note="chebyshev at degree 1, so T0=1 and T1(t)=t and the "
                              "arithmetic matches plain polynomial. AST builds the "
                              "WCS (has wcs wcs = 1) but gives the Chebyshev no "
                              "inverse, and DS9 cannot produce a readout without "
                              "one - which is why real GWCS files carry explicit "
                              "`inverse:' blocks for their polynomials, as the "
                              "Roman distortion does. Plain polynomial escapes "
                              "this because AST inverts a degree-1 one itself.",
                         readout=False),
                    payload)
    made.append(("transform", "ortho_polynomial", sz, exp))

    # ---- divide: scale / constant, so the quotient stays linear ---------
    def div(fac, const):
        return ("!transform/divide-1.4.0\n"
                "        forward:\n"
                "        - !transform/scale-1.4.0 {factor: %s}\n"
                "        - !transform/constant-1.6.0 {value: %s, dimensions: 1}"
                % (fnum(fac), fnum(const)))

    exp = (PX * 10.0 / 2.0, PY * 6.0 / 3.0)
    tr = cat(div(10.0, 2.0), div(6.0, 3.0))
    sz = write_asdf(os.path.join(OUTDIR, "divide.asdf"),
                    tree("divide", tr, exp,
                         note="scale/constant keeps the quotient linear; also "
                              "exercises `constant'"),
                    payload)
    made.append(("transform", "divide", sz, exp))

    # ---- fix_inputs: pin axis 1 of a planar2d, leaving 1-in/1-out -------
    #
    # Deliberately only ONE fix_inputs here, paired with a plain scale,
    # where the obvious thing is to use one on each half of the concatenate.
    # Two of them trips a heap overread in AST (winmap.c's MapMerge, see
    # TODO.md's AST bug 11) whose effect differs by platform: on macOS the
    # bytes past the array happened to let the WCS build, and on Linux the
    # same file fails with a CmpMap dimension mismatch. A fixture whose
    # answer depends on what follows a buffer in memory is worse than no
    # fixture, so this uses the shape that is clean under AddressSanitizer.
    # One fix_inputs exercises the primitive just as well; the second only
    # ever duplicated it.
    def fixin(intercept, sx, sy, yval):
        return ("!transform/fix_inputs-1.2.0\n"
                "        forward:\n"
                "        - %s\n"
                "        - keys: [1]\n"
                "          values: [%s]"
                % (planar(intercept, sx, sy), fnum(yval)))

    fa = (1.0, 2.0, 3.0, 5.0)
    exp = (fa[0] + fa[1] * PX + fa[2] * fa[3], PY)
    tr = cat(fixin(*fa), "!transform/scale-1.4.0 {factor: 1.0}")
    sz = write_asdf(os.path.join(OUTDIR, "fix_inputs.asdf"),
                    tree("fix_inputs", tr, exp,
                         note="pins axis 1 of a planar2d, leaving it 1-in/1-out, "
                              "and concatenates that with a unit scale so the "
                              "other axis passes through. Only one fix_inputs on "
                              "purpose: two of them trip an AST heap overread "
                              "whose result differs between macOS and Linux "
                              "(TODO.md AST bug 11)"),
                    payload)
    made.append(("transform", "fix_inputs", sz, exp))

    # ---- spherical_cartesian: 2->3 then 3->2, i.e. a round trip ---------
    tr = compose2("!<tag:stsci.edu:gwcs/spherical_cartesian-1.3.0> "
                  "{transform_type: spherical_to_cartesian}",
                  "!<tag:stsci.edu:gwcs/spherical_cartesian-1.3.0> "
                  "{transform_type: cartesian_to_spherical}")
    sz = write_asdf(os.path.join(OUTDIR, "spherical_cartesian.asdf"),
                    tree("spherical_cartesian", tr, (PX, PY),
                         note="both directions composed, so the result must be the "
                              "identity - which is what makes it checkable"),
                    payload)
    made.append(("transform", "spherical_cartesian", sz, (PX, PY)))

    # ---- rotate_sequence_3d, spherical flavour: 2-in/2-out directly -----
    tr = ("!transform/rotate_sequence_3d-1.3.0\n"
          "      angles: [90.0]\n"
          "      axes_order: z\n"
          "      rotation_type: spherical")
    # A +90 z rotation moves longitude by -90 here; the sign is AST's, and is
    # recorded from measurement rather than assumed.
    exp = (norm_lon(PX - 90.0), PY)
    sz = write_asdf(os.path.join(OUTDIR, "rotate_sequence_3d.asdf"),
                    tree("rotate_sequence_3d", tr, exp,
                         note="rotation_type spherical is 2-in/2-out, so no "
                              "cartesian plumbing needed; +90 about z shifts "
                              "longitude by -90"),
                    payload)
    made.append(("transform", "rotate_sequence_3d", sz, exp))

    # GetTime() accepts either a bare string or a tagged Time object, but it
    # validates `format' against a short list -- iso, byear, jyear, jd, mjd --
    # and errors on anything else. astropy's own spellings (jyear_str, isot)
    # are NOT on it, which is what made the first attempt at these five fail.
    # `scale' becomes AST's TimeScale and is required in the object form.
    #
    # For byear/jyear AST prepends the B/J prefix itself, so the value is the
    # bare epoch number.
    J2000 = ("equinox: !time/time-1.1.0 {value: '2000.0', "
             "format: jyear, scale: tt}")
    B1950 = ("equinox: !time/time-1.1.0 {value: '1950.0', "
             "format: byear, scale: tt}")
    OBSTIME = ("obstime: !time/time-1.1.0 {value: '2020-01-01 00:00:00.000', "
               "format: iso, scale: utc}")
    # ReadEarthLocation wants x/y/z as Quantities in metres, and an optional
    # ellipsoid defaulting to WGS84. These are the ITRF coordinates of the
    # AAT, which is as good a fixed observatory as any.
    # GetQuantity reads "unit" with Get0C, i.e. as a plain string, so the
    # unit is written bare rather than as a tagged !unit/unit-1.0.0 scalar.
    LOCATION = """location: !<tag:astropy.org:astropy/coordinates/earthlocation-1.0.0>
            x: !unit/quantity-1.1.0 {value: -4554231.533, unit: m}
            y: !unit/quantity-1.1.0 {value: 2816759.109, unit: m}
            z: !unit/quantity-1.1.0 {value: -3454036.323, unit: m}"""
    NEEDS = {
        "fk4": [OBSTIME, B1950], "fk4noeterms": [OBSTIME, B1950],
        "fk5": [J2000], "ecliptic": [J2000],
        "altaz": [OBSTIME, LOCATION],
    }
    for frame in FRAME_TAGS:
        need = NEEDS.get(frame)
        if need:
            # `frame_attributes:' is emitted at column 8, so its children sit
            # at 10. Getting this wrong makes them siblings of
            # frame_attributes rather than its contents -- which AST reports
            # only as "could not read this WCS", exactly like every other
            # malformation here.
            attrs = "\n" + "\n".join("          " + a for a in need)
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
