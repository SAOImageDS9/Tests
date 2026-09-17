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
import os
import struct
import sys

# ---------------------------------------------------------------------------
# STATUS, measured against the FITS twin in DS9 (see README "GWCS primitives")
#
#   VERIFIED (7)  the zenithal family: gnomonic, airy, stereographic,
#                 zenithal_equal_area, zenithal_equidistant,
#                 slant_orthographic, slant_zenithal_perspective.
#                 All agree with their 1904-66 twin to 0.0266-0.0269 arcsec.
#                 That residual is constant across all seven, which is what
#                 identifies it: it is the FK5 J2000 -> ICRS frame bias (the
#                 FITS files are EQUINOX 2000, these fixtures declare ICRS),
#                 not a projection error.
#
#   NOT YET (18)  the non-zenithal families -- conic_*, cylindrical_*,
#                 mercator, plate_carree, hammer_aitoff, molleweide,
#                 parabolic, sanson_flamsteed, polyconic, bonne_equal_area,
#                 and the three quad-cubes -- are all out by ~84 degrees.
#                 The cause is structural, not a parameter slip: FITS puts the
#                 fiducial point of a zenithal projection at the native pole
#                 (phi0,theta0)=(0,90), but at the native *equator* (0,0) for
#                 all of these. A single rotate3d(CRVAL1,CRVAL2,LONPOLE) is
#                 only the correct native->celestial rotation in the first
#                 case, so these need the theta0=0 construction instead.
#                 Their fixtures are still written -- they are valid ASDF and
#                 do exercise the tag parsing -- but their WCS is wrong, so
#                 they must not be given asdf.sh baselines yet.
#
#   AZP (1)       zenithal_perspective is out by ~6500 arcsec even though its
#                 parameters are right. yamlchan.c maps it to AST__SZP with
#                 pv1=mu, pv2=gamma, but AZP and SZP are different
#                 projections with different parameter meanings (SZP's second
#                 and third are phi_c/theta_c). This looks like an AST bug
#                 rather than anything in this tree, and is a candidate to
#                 report upstream.
#
#   HEALPIX (2)   healpix and healpix_polar fail to build a FrameSet at all.
#                 Not yet diagnosed.
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


def gwcs_tree(nx, ny, proj, ver, params, crpix, cdelt, crval, lonpole):
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
    ReadRotate3d() feeds to a FitsChan as CRVAL1/CRVAL2/LONPOLE -- so the FITS
    values go straight through with no conversion.

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
data: !core/ndarray-1.1.0
  source: 0
  datatype: uint8
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
           sx=fnum(-crpix[0]), sy=fnum(-crpix[1]),
           cd1=fnum(cdelt[0]), cd2=fnum(cdelt[1]),
           phi=fnum(crval[0]), theta=fnum(crval[1]), psi=fnum(lonpole))


def build(code, proj, ver, pmap, twin_code=None):
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

    gwcs_tree.twin = twin
    body = gwcs_tree(
        nx, ny, proj, ver, params,
        (num(hdr, "CRPIX1"), num(hdr, "CRPIX2")),
        (num(hdr, "CDELT1"), num(hdr, "CDELT2")),
        (num(hdr, "CRVAL1"), num(hdr, "CRVAL2")),
        num(hdr, "LONPOLE", 0.0),
    )
    # A recognisable ramp rather than the real pixels: these fixtures are
    # about the WCS, and a deterministic pattern keeps the file small and the
    # baseline stable.
    payload = bytes(((x * 7 + y * 13) % 251 for y in range(ny) for x in range(nx)))
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
