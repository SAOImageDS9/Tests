#!/usr/bin/env python3
"""Generate one ASDF/GWCS fixture per GWCS sky-projection primitive.

The projections are the largest family of things `ast/src/yamlchan.c` knows
how to read, and until now nothing in this suite exercised any of them except
gnomonic (every Roman file uses TAN) and the fitswcs_imaging shortcut.

Rather than invent parameters, each fixture is built from the matching file in
`../wcs/` -- the Calabretta & Greisen 1904-66 set, which is one FITS image per
projection code over the same field.  That has two payoffs: the parameters are
the canonical ones, and DS9 can read the FITS twin, so every fixture has an
independent reference to be checked against instead of merely "it loaded".

The parameter names and their AST meanings are taken from ReadSkyProjection()
in yamlchan.c, which is the only authority that matters here -- it is what
will actually parse these files.

No asdf/gwcs Python needed: the container is written by hand, which is the
point.  It lets each fixture name an exact tag and version, which a library
writer would not let us choose.
"""

import glob
import math
import os
import struct
import sys

# ---------------------------------------------------------------------------
# STATUS, measured against the FITS twin in DS9 (see README "GWCS primitives")
#
#   VERIFIED (25 of 27)  every projection with a 1904-66 twin agrees with it to
#                 0.0265-0.0271 arcsec.  That residual is constant across all
#                 25, which is what identifies it: it is the FK5 J2000 -> ICRS
#                 frame bias (the FITS files are EQUINOX 2000, these fixtures
#                 declare ICRS), not a projection error.
#
#   healpix_polar No XPH image exists in the 1904-66 set, so this one borrows
#                 HPX's header for its parameters and has no reference to be
#                 checked against -- it is marked `verify_against: none'.  It
#                 loads and produces a WCS; that is all that is claimed.
#
#   zenithal_perspective  Was out by 4195 arcsec (1.17 deg) with demonstrably
#                 correct parameters, which turned out to be an AST bug rather
#                 than anything these fixtures could work around: yamlchan.c
#                 mapped it to AST__SZP with pv1=mu, pv2=gamma, but those are
#                 AZP's PV2_1/PV2_2 while SZP's 2nd and 3rd parameters are
#                 phi_c/theta_c, so gamma arrived as phi_c.  AST__AZP was never
#                 wired up in either direction -- the writer had two
#                 `type == AST__SZP' branches, the second unreachable.  Fixed
#                 in the project's vendored ast/ and sent upstream; this
#                 fixture now agrees with its twin to 0.0250 arcsec, the same
#                 frame bias as the rest.
#
# Getting here needed two fixes outside this script, both recorded in the
# project's TODO.md:
#   - ds9/library/asdf.tcl only looked for a `wcs' key at Roman's indents, so
#     a flat tree like these loaded its pixels and silently got no WCS.
#   - ast/src/yamlchan.c's IsASkyProjection() omitted both HEALPix variants,
#     making the /healpix- and /healpix_polar- branches of ReadSkyProjection()
#     unreachable dead code.
# ---------------------------------------------------------------------------

HERE = os.path.dirname(os.path.abspath(__file__))
WCSDIR = os.path.join(HERE, os.pardir, "wcs")
OUTDIR = os.path.join(HERE, "gwcs")

# FITS projection code -> (gwcs tag name, tag version, {gwcs param: FITS card})
#
# Versions are the ceilings from yamlchan.c's MAKE_TEST table.  That macro
# requires major to match exactly and minor to be <= the ceiling, so naming
# the ceiling is both legal and the strongest test of it.
PROJ = {
    "TAN": ("gnomonic",                   "1.2.0", {}),
    "AIR": ("airy",                       "1.2.0", {"theta_b": "PV2_1"}),
    "SIN": ("slant_orthographic",         "1.2.0", {"xi": "PV2_1", "eta": "PV2_2"}),
    "SZP": ("slant_zenithal_perspective", "1.2.0", {"mu": "PV2_1", "phi0": "PV2_2",
                                                    "theta0": "PV2_3"}),
    "STG": ("stereographic",              "1.2.0", {}),
    "ZEA": ("zenithal_equal_area",        "1.2.0", {}),
    "ARC": ("zenithal_equidistant",       "1.2.0", {}),
    "AZP": ("zenithal_perspective",       "1.3.0", {"mu": "PV2_1", "gamma": "PV2_2"}),
    "HPX": ("healpix",                    "1.2.0", {"H": None, "X": None}),
    "COE": ("conic_equal_area",           "1.3.0", {"sigma": "PV2_1", "delta": "PV2_2"}),
    "COD": ("conic_equidistant",          "1.3.0", {"sigma": "PV2_1", "delta": "PV2_2"}),
    "COO": ("conic_orthomorphic",         "1.3.0", {"sigma": "PV2_1", "delta": "PV2_2"}),
    "COP": ("conic_perspective",          "1.3.0", {"sigma": "PV2_1", "delta": "PV2_2"}),
    "CEA": ("cylindrical_equal_area",     "1.3.0", {"lambda": "PV2_1"}),
    "CYP": ("cylindrical_perspective",    "1.3.0", {"mu": "PV2_1", "lambda": "PV2_2"}),
    "MER": ("mercator",                   "1.2.0", {}),
    "CAR": ("plate_carree",               "1.2.0", {}),
    "BON": ("bonne_equal_area",           "1.3.0", {"theta1": "PV2_1"}),
    "PCO": ("polyconic",                  "1.2.0", {}),
    "AIT": ("hammer_aitoff",              "1.2.0", {}),
    "MOL": ("molleweide",                 "1.2.0", {}),
    "PAR": ("parabolic",                  "1.2.0", {}),
    "SFL": ("sanson_flamsteed",           "1.2.0", {}),
    "CSC": ("cobe_quad_spherical_cube",   "1.2.0", {}),
    "QSC": ("quad_spherical_cube",        "1.2.0", {}),
    "TSC": ("tangential_spherical_cube",  "1.2.0", {}),
}

# The native coordinates of each projection's fiducial point.  FITS-WCS
# Paper II puts it at the native *pole* for the zenithal projections,
# (phi0,theta0) = (0,90), but on the native *equator*, (0,0), for the
# cylindricals, pseudo-cylindricals, quad-cubes, Bonne, polyconic and HEALPix;
# and at (0,theta_a) for the conics, theta_a being the sigma parameter.
#
# This is the whole reason a single rotate3d(CRVAL1,CRVAL2,LONPOLE) is not
# enough: AST's rotate3d wants the celestial coordinates of the *native pole*,
# which only coincide with CRVAL when theta0 = 90.
THETA0 = {
    "gnomonic": 90.0, "airy": 90.0, "slant_orthographic": 90.0,
    "slant_zenithal_perspective": 90.0, "stereographic": 90.0,
    "zenithal_equal_area": 90.0, "zenithal_equidistant": 90.0,
    "zenithal_perspective": 90.0,
}
# everything not listed sits on the native equator, except the conics, which
# take theta0 from their own sigma parameter (handled in build()).
CONICS = ("conic_equal_area", "conic_equidistant", "conic_orthomorphic",
          "conic_perspective")


def native_pole(crval, lonpole, theta0):
    """Celestial (alpha_p, delta_p) of the native pole.

    Every file in the 1904-66 set has LONPOLE - phi0 = 180, which collapses
    Paper II's general expression to cos(theta0 + delta_p) = -sin(delta0):

        sin(delta0) = sin(theta0) sin(delta_p)
                      + cos(theta0) cos(delta_p) cos(phi0 - LONPOLE)
                    = -cos(theta0 + delta_p)

    so delta_p = acos(-sin delta0) - theta0.  That reduces to delta_p = CRVAL2
    when theta0 = 90, which is exactly the zenithal case that already worked,
    so the one formula covers both families.

    alpha_p is formally degenerate here because delta0 = -90 puts the fiducial
    on the celestial pole, where alpha0 means nothing; FITS resolves it by
    convention and CRVAL1 is the value that reproduces the twin (checked
    against the alternative, which is out by 53 degrees).
    """
    a0, d0 = crval
    dp = math.degrees(math.acos(max(-1.0, min(1.0, -math.sin(math.radians(d0))))))
    return a0, dp - theta0


# HEALPix takes H and X, which the 1904-66 HPX file leaves to the defaults.
# yamlchan.c defaults them to 4 and 3; name them explicitly so the fixture
# tests the parsing rather than the default path.
HPX_DEFAULTS = {"H": 4.0, "X": 3.0}

# healpix_polar (XPH) has no counterpart in the 1904-66 set, so it gets the
# same field by borrowing HPX's header.  Flagged so the validator knows there
# is no FITS twin to compare against.
NO_TWIN = {"XPH": ("healpix_polar", "1.2.0", {}, "HPX")}


def read_header(path):
    """Minimal FITS header reader -- no astropy dependency."""
    out = {}
    with open(path, "rb") as fh:
        while True:
            block = fh.read(2880)
            if not block:
                break
            done = False
            for i in range(0, 2880, 80):
                card = block[i:i + 80].decode("latin-1")
                key = card[:8].strip()
                if key == "END":
                    done = True
                    break
                if card[8:10].find("=") >= 0:
                    out[key] = card[10:].split("/")[0].strip()
            if done:
                break
    return out


def num(hdr, key, default=None):
    if key in hdr:
        return float(hdr[key])
    if default is None:
        raise KeyError(key)
    return default


def block(payload):
    hdr = struct.pack(">IIQQQ16s", 0, 0, len(payload), len(payload),
                      len(payload), b"\x00" * 16)
    return b"\xd3BLK" + struct.pack(">H", 48) + hdr + payload


def write_asdf(path, tree_body, payload):
    head = ("#ASDF 1.0.0\n#ASDF_STANDARD 1.5.0\n%YAML 1.1\n"
            "%TAG ! tag:stsci.edu:asdf/\n--- !core/asdf-1.1.0\n")
    tree = head + tree_body + "...\n"
    blk = block(payload)
    idx = ("#ASDF BLOCK INDEX\n%YAML 1.1\n---\n- " + str(len(tree.encode()))
           + "\n...\n")
    with open(path, "wb") as fh:
        fh.write(tree.encode() + blk + idx.encode())
    return os.path.getsize(path)


def fnum(v):
    """Render a float so YAML reads it back as a float, never an int."""
    s = repr(float(v))
    return s if ("." in s or "e" in s or "E" in s) else s + ".0"


def gwcs_tree(nx, ny, proj, ver, params, crpix, cdelt, crval, lonpole, theta0):
    """A complete GWCS: pixel -> shift -> affine -> projection -> rotate3d -> icrs.

    The shift offset is -crpix, with no 1-based/0-based correction. That is
    worth stating because it is the opposite of what the FITS/gwcs convention
    difference suggests: DS9 feeds its own image coordinate straight into the
    AST FrameSet built from the GWCS, with no adjustment. Verified with an
    identity-transform fixture, which reads sky (4,4) at image (4,4). So for
    these fixtures to agree with a FITS twin computing cdelt*(X - CRPIX) at
    the same DS9 coordinate X, the offset has to be -CRPIX exactly. Using
    -(crpix-1) moves everything by one pixel, which at this plate scale is
    240 arcsec.

    rotate3d with direction native2celestial is handed phi/theta/psi, which
    ReadRotate3d() feeds to a FitsChan as CRVAL1/CRVAL2/LONPOLE with a zenithal
    CTYPE -- so what it really wants is the celestial position of the *native
    pole*, not CRVAL.  For a zenithal projection those are the same point; for
    everything else they are not, which is what native_pole() computes.

    Both frames must carry axis_physical_types.  It looks optional -- gwcs
    treats it as metadata and yamlchan.c reads it with a not-required flag --
    but without it AST builds no FrameSet at all and the file loads its pixels
    with no WCS.  Found by bisection: a fixture with nothing but
    `transform: identity` failed until these two lines were added.  For the
    celestial frame the values are checked against the frame's expected UCDs,
    so they have to be pos.eq.ra/pos.eq.dec rather than anything descriptive.
    """
    plist = "".join(", %s: %s" % (k, fnum(v)) for k, v in sorted(params.items()))
    return """asdf_library: !core/software-1.0.0 {{name: make_gwcs_fixtures, version: '1.0'}}
meta:
  projection: {proj}
  source_fits_file: {twin}
  verify_against: {verify}
data: !core/ndarray-1.1.0
  source: 0
  datatype: float32
  byteorder: big
  shape: [{ny}, {nx}]
wcs: !<tag:stsci.edu:gwcs/wcs-1.4.0>
  name: {proj}
  steps:
  - !<tag:stsci.edu:gwcs/step-1.3.0>
    frame: !<tag:stsci.edu:gwcs/frame2d-1.2.0>
      name: detector
      axes_names: [x, y]
      axes_order: [0, 1]
      axis_physical_types: ['custom:x', 'custom:y']
      unit: [!unit/unit-1.0.0 pixel, !unit/unit-1.0.0 pixel]
    transform: !transform/compose-1.4.0
      forward:
      - !transform/concatenate-1.4.0
        forward:
        - !transform/shift-1.4.0 {{offset: {sx}}}
        - !transform/shift-1.4.0 {{offset: {sy}}}
      - !transform/compose-1.4.0
        forward:
        - !transform/affine-1.5.0
          matrix: !core/ndarray-1.1.0
            data:
            - [{cd1}, 0.0]
            - [0.0, {cd2}]
            datatype: float64
            byteorder: little
            shape: [2, 2]
          translation: !core/ndarray-1.1.0
            data: [0.0, 0.0]
            datatype: float64
            byteorder: little
            shape: [2]
        - !transform/compose-1.4.0
          forward:
          - !transform/{proj}-{ver} {{direction: pix2sky{plist}}}
          - !transform/rotate3d-1.3.0 {{phi: {phi}, theta: {theta}, psi: {psi}, direction: native2celestial}}
  - !<tag:stsci.edu:gwcs/step-1.3.0>
    frame: !<tag:stsci.edu:gwcs/celestial_frame-1.2.0>
      name: icrs
      axes_names: [lon, lat]
      axes_order: [0, 1]
      axis_physical_types: [pos.eq.ra, pos.eq.dec]
      unit: [!unit/unit-1.0.0 deg, !unit/unit-1.0.0 deg]
      reference_frame: !<tag:astropy.org:astropy/coordinates/frames/icrs-1.1.0>
        frame_attributes: {{}}
    transform: null
""".format(proj=proj, ver=ver, plist=plist, nx=nx, ny=ny,
           twin=os.path.basename(gwcs_tree.twin),
           verify=(os.path.basename(gwcs_tree.twin) if gwcs_tree.verify else "none"),
           sx=fnum(-crpix[0]), sy=fnum(-crpix[1]),
           cd1=fnum(cdelt[0]), cd2=fnum(cdelt[1]),
           phi=fnum(native_pole(crval, lonpole, theta0)[0]),
           theta=fnum(native_pole(crval, lonpole, theta0)[1]),
           psi=fnum(lonpole))


def fits_data(path, nx, ny):
    """The twin's data array, verbatim.  BITPIX -32 big-endian both sides."""
    want = nx * ny * 4
    with open(path, "rb") as fh:
        while True:
            blk = fh.read(2880)
            if not blk:
                raise EOFError(path)
            if any(blk[i:i + 8].strip() == b"END" for i in range(0, 2880, 80)):
                break
        data = fh.read(want)
    if len(data) != want:
        raise EOFError("%s: got %d of %d data bytes" % (path, len(data), want))
    return data


def build(code, proj, ver, pmap, twin_code=None):
    # twin_code means the parameters were borrowed from another projection's
    # header, so that file is NOT a reference to check the result against.
    twin = os.path.join(WCSDIR, "1904-66_%s.fits" % (twin_code or code))
    if not os.path.exists(twin):
        return None
    hdr = read_header(twin)
    nx = int(float(hdr["NAXIS1"]))
    ny = int(float(hdr["NAXIS2"]))

    params = {}
    for name, card in pmap.items():
        if card is None:
            params[name] = HPX_DEFAULTS[name]
        else:
            params[name] = num(hdr, card)

    theta0 = THETA0.get(proj, 0.0)
    if proj in CONICS:
        theta0 = params["sigma"]

    gwcs_tree.twin = twin
    gwcs_tree.verify = (twin_code is None)
    body = gwcs_tree(
        nx, ny, proj, ver, params,
        (num(hdr, "CRPIX1"), num(hdr, "CRPIX2")),
        (num(hdr, "CDELT1"), num(hdr, "CDELT2")),
        (num(hdr, "CRVAL1"), num(hdr, "CRVAL2")),
        num(hdr, "LONPOLE", 0.0),
        theta0,
    )
    # The twin's own pixels, copied byte for byte.  Synthesising a pattern
    # would be smaller, but sharing the data means a readout from the fixture
    # and from the FITS file can be compared directly -- which is the point of
    # pairing them, and makes asdf.sh's pixel samples meaningful rather than
    # self-referential.  Both are big-endian float32, so this is a copy.
    payload = fits_data(twin, nx, ny)
    out = os.path.join(OUTDIR, "%s.asdf" % proj)
    size = write_asdf(out, body, payload)
    return proj, code, size, params


def main():
    os.makedirs(OUTDIR, exist_ok=True)
    made = []
    for code in sorted(PROJ):
        proj, ver, pmap = PROJ[code]
        r = build(code, proj, ver, pmap)
        if r:
            made.append(r)
        else:
            print("  SKIP %-28s no ../wcs/1904-66_%s.fits" % (proj, code))
    for code, (proj, ver, pmap, twin) in sorted(NO_TWIN.items()):
        r = build(code, proj, ver, pmap, twin_code=twin)
        if r:
            made.append(r)

    print("wrote %d fixtures into %s/" % (len(made), os.path.relpath(OUTDIR, HERE)))
    for proj, code, size, params in made:
        ps = " ".join("%s=%g" % kv for kv in sorted(params.items()))
        print("  %-28s <- %-3s %6d B  %s" % (proj, code, size, ps))


if __name__ == "__main__":
    main()
