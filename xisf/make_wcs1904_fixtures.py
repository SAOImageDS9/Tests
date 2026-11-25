#!/usr/bin/env python3
"""XISF versions of the Calabretta & Greisen 1904-66 WCS examples.

The same source the ASDF GWCS fixtures were built from (../wcs/, from
https://www.atnf.csiro.au/computing/software/wcs/example_data.html): one
192x192 image per FITS projection code over the same field, with the
reference point at the south celestial pole, far off the image, and
LONPOLE/LATPOLE given explicitly - the cases a WCS conversion gets wrong.

Two sets, under wcs1904/:

  solution/  The 7 projections an XISF AstrometricSolution can express
             (TAN STG ZEA SIN CAR MER AIT), as a layer 1 solution:
               ReferenceCelestialCoordinates  = (CRVAL1, CRVAL2)
               ReferenceImageCoordinates      = (CRPIX1 - 0.5, H + 0.5 - CRPIX2)
               LinearTransformationMatrix     = CD with column 2 negated
               CelestialPoleNativeCoordinates = (LONPOLE, LATPOLE)
               ReferenceNativeCoordinates     = the projection's default
                                                (phi0, theta0), written out
                                                as PCL always writes it
             The inverse of TODO_XISF.md §2.7 / PCL's ComputeWCSKeywords.
             A solution is ICRS, while the files are EQUINOX 2000 (FK5),
             ~0.025" apart; the twin is the original with RADESYS = 'ICRS'
             added, so the comparison is exact and a residual means a
             conversion error, not a frame difference.

  keywords/  All 28 files (Paper II's 27 projections and the legacy NCP),
             with the original WCS keywords as XISF
             FITSKeyword elements, mirrored to describe the rows top down
             (PCL's documented convention; make_xisf_fixtures.mirror_vertically,
             which checks itself with astropy). The reader mirrors them back,
             so the twin is the original file, unchanged. This covers the 21
             codes a solution cannot express, PV parameters included.

  solution/ variants  The 1904-66 headers give LONPOLE/LATPOLE and imply
             (phi0, theta0) exactly as WCS would default them, so on their own
             they cannot tell a reader that honours CelestialPoleNativeCoordinates
             and ReferenceNativeCoordinates from one that ignores both (a mutant
             that drops them passes). Each variant changes one of those to a
             non-default value, in the solution and in the twin alike:
             TAN LONPOLE 150, ZEA LONPOLE 240, CAR theta0 20 (PV1_2) and AIT
             phi0 30 (PV1_1), those two with CRVAL2 moved to -50, since a
             non-default native reference at the pole has no valid celestial
             pole. The WCS then no longer describes the sky those pixels
             show; what is checked is that the XISF solution and the FITS twin
             agree with each other.

Pixels are the originals', rows reversed into XISF's top-down order, with
bounds from their finite range. The other keywords (BUNIT, BMAJ, HISTORY,
...) ride along as FITSKeywords in both sets.

Writes wcs1904/MANIFEST.tsv in the format of ../MANIFEST.tsv.

    ~/miniforge/envs/ds9asdf/bin/python make_wcs1904_fixtures.py
"""
import pathlib
import sys

import numpy as np
from astropy.io import fits

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import make_xisf_fixtures as mx          # the writer; its main() is not run

SRC = HERE.parent / "wcs"
OUT = HERE / "wcs1904"

SOLUTION = {"TAN": "Gnomonic", "STG": "Stereographic",
            "ZEA": "ZenithalEqualArea", "SIN": "Orthographic",
            "CAR": "PlateCarree", "MER": "Mercator", "AIT": "HammerAitoff"}
# (phi0, theta0) defaults, FITS WCS Paper II: zenithal at the native
# pole, cylindrical and pseudocylindrical on the native equator
NATIVE = {"TAN": (0.0, 90.0), "STG": (0.0, 90.0), "ZEA": (0.0, 90.0),
          "SIN": (0.0, 90.0), "CAR": (0.0, 0.0), "MER": (0.0, 0.0),
          "AIT": (0.0, 0.0)}

STRUCTURAL = {"SIMPLE", "BITPIX", "NAXIS", "NAXIS1", "NAXIS2", "EXTEND",
              "BSCALE", "BZERO", "BLANK", "END"}
WCS = ("CTYPE", "CRPIX", "CRVAL", "CDELT", "CROTA", "CUNIT", "PC", "CD",
       "PV", "PS", "LONPOLE", "LATPOLE", "RADESYS", "WCSAXES")


def is_wcs(name):
    return name.startswith(WCS)


def fits_value(v):
    """A header value as FITS value text."""
    if isinstance(v, bool):
        return "T" if v else "F"
    if isinstance(v, str):
        return "'" + v.replace("'", "''") + "'"
    if isinstance(v, int):
        return str(v)
    return f"{float(v):.17G}"


def xisf_pixels(data):
    """FITS rows are bottom up; XISF's top down."""
    return np.ascontiguousarray(data[::-1, :]).astype(np.float32)[None]


def other_keywords(header):
    out = []
    for card in header.cards:
        k = card.keyword
        if k in STRUCTURAL or is_wcs(k) or k == "":
            continue
        if k in ("HISTORY", "COMMENT"):
            out.append(mx.keyword(k, "", str(card.value)))
        else:
            out.append(mx.keyword(k, fits_value(card.value), card.comment))
    return out


def bounds(data):
    return f"{float(np.nanmin(data)):.9G}:{float(np.nanmax(data)):.9G}"


# (projection, label, header overrides) - see the docstring
VARIANTS = [("TAN", "lonpole150", {"LONPOLE": 150.0}),
            ("ZEA", "lonpole240", {"LONPOLE": 240.0}),
            # a non-default phi0 or theta0 needs the reference off the pole:
            # with CRVAL2 -90 there is no valid celestial pole (wcslib:
            # |lat0| <= 60)
            ("CAR", "theta20", {"PV1_2": 20.0, "CRVAL2": -50.0}),
            ("AIT", "phi30", {"PV1_1": 30.0, "CRVAL2": -50.0})]


def solution_props(h, code):
    cd = np.array([[h["CDELT1"], 0.0], [0.0, h["CDELT2"]]])
    if "PC1_1" in h or "CD1_1" in h or "CROTA2" in h:
        raise ValueError("only CDELT-only headers are converted")
    m = np.array([[cd[0, 0], -cd[0, 1]], [cd[1, 0], -cd[1, 1]]])
    H = h["NAXIS2"]
    pre = "AstrometricSolution:"
    return [
        mx.prop(pre + "Version", "String", text="1.0"),
        mx.prop(pre + "ProjectionSystem", "String", text=SOLUTION[code]),
        mx.prop_vector(pre + "ReferenceCelestialCoordinates",
                       (h["CRVAL1"], h["CRVAL2"])),
        mx.prop_vector(pre + "ReferenceImageCoordinates",
                       (h["CRPIX1"] - 0.5, H + 0.5 - h["CRPIX2"])),
        mx.prop_matrix(pre + "LinearTransformationMatrix", m),
        mx.prop_vector(pre + "ReferenceNativeCoordinates",
                       (h.get("PV1_1", NATIVE[code][0]),
                        h.get("PV1_2", NATIVE[code][1]))),
        mx.prop_vector(pre + "CelestialPoleNativeCoordinates",
                       (h["LONPOLE"], h["LATPOLE"])),
        mx.prop(pre + "CelestialReferenceSystem", "String", text="ICRS"),
    ]


def main():
    rows = []
    for src in sorted(SRC.glob("1904-66_*.fits")):
        code = src.stem.split("_")[1]
        with fits.open(src) as hdul:
            h = hdul[0].header.copy()
            data = hdul[0].data.copy()
        pix = xisf_pixels(data)
        others = other_keywords(h)
        b = bounds(data)

        # keywords/: every projection, WCS keywords mirrored top down
        wcs_cards = [(c.keyword, c.value) for c in h.cards if is_wcs(c.keyword)]
        mirrored = mx.mirror_vertically_for(wcs_cards, h["NAXIS2"])
        kw = [mx.keyword(k, fits_value(v)) for k, v in mirrored]
        rel = f"keywords/{src.stem}.xisf"
        mx.write_xisf(OUT / rel,
                      [mx.Image(pix, "Float32", bounds=b,
                                children=others + kw)])
        hdu = fits.PrimaryHDU(data, header=h)
        hdu.writeto(OUT / f"keywords/{src.stem}.fits", overwrite=True)
        rows.append((f"wcs1904/{rel}", "load", "-32",
                     f"1904-66 {code}: original WCS keywords, mirrored top "
                     f"down; twin is the original"))

        # solution/: the projections a solution can express
        if code in SOLUTION:
            rel = f"solution/{src.stem}.xisf"
            mx.write_xisf(OUT / rel,
                          [mx.Image(pix, "Float32", bounds=b,
                                    children=others +
                                    solution_props(h, code))])
            th = h.copy()
            th["RADESYS"] = ("ICRS", "XISF solutions are ICRS")
            fits.PrimaryHDU(data, header=th).writeto(
                OUT / f"solution/{src.stem}.fits", overwrite=True)
            rows.append((f"wcs1904/{rel}", "load", "-32",
                         f"1904-66 {code} as a {SOLUTION[code]} layer 1 "
                         f"solution (pole native coords from LONPOLE/LATPOLE); "
                         f"twin is the original with RADESYS ICRS"))

    for code, label, over in VARIANTS:
        src = SRC / f"1904-66_{code}.fits"
        with fits.open(src) as hdul:
            h = hdul[0].header.copy()
            data = hdul[0].data.copy()
        for k, v in over.items():
            h[k] = v
        name = f"{src.stem}_{label}"
        rel = f"solution/{name}.xisf"
        mx.write_xisf(OUT / rel,
                      [mx.Image(xisf_pixels(data), "Float32",
                                bounds=bounds(data),
                                children=other_keywords(h) +
                                solution_props(h, code))])
        th = h.copy()
        th["RADESYS"] = ("ICRS", "XISF solutions are ICRS")
        fits.PrimaryHDU(data, header=th).writeto(
            OUT / f"solution/{name}.fits", overwrite=True)
        rows.append((f"wcs1904/{rel}", "load", "-32",
                     f"1904-66 {code} with {over}: a non-default pole or "
                     f"native reference, so ignoring the solution's "
                     f"CelestialPole/ReferenceNativeCoordinates shows"))

    with open(OUT / "MANIFEST.tsv", "w") as fh:
        fh.write("# fixture\texpect\tbitpix\tnotes\n")
        for r in rows:
            fh.write("\t".join(r) + "\n")
    print(f"{len(rows)} fixtures written under {OUT}")


if __name__ == "__main__":
    main()
