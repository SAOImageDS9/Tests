StartDS9 () {
    if [ `xpaaccess DS9Test` = no ]; then
	timeout 2m ds9 -title DS9Test &

	i=1
	while [ "$i" -le 10 ]
	    do
	    sleep 2
	    if [ `xpaaccess DS9Test` = yes ]; then
		break
	    fi

	    i=`expr $i + 1`
	done
    fi
}

# Regression test for WCS alignment between a normal tangent-plane FITS
# image and a MOC/HEALPIX (HPX-projected) image -- tksao/frame/base.C's
# Base::calcAlignWCS(), used by both "frame match wcs" (Base::alignWCS)
# and the "-mask"/"mask" overlay (Frame::updateMaskMatrices).
#
# calcAlignWCS() fits a single affine matrix between the two images by
# probing a small box with AST's astLinearApprox() and testing whether
# the true WCS transform is linear enough over that box. Two bugs here
# let a MOC frame end up completely misregistered when matched/masked
# against a normal image:
#
#  1. The result of astLinearApprox() (an int, non-zero on success) was
#     compared against AST__BAD (a double sentinel, -DBL_MAX). That
#     comparison is always true, so a *failed* fit's AST__BAD
#     (~-1.8e308) coefficients were used as if they were real, driving
#     the computed zoom/matrix to infinity -- the MOC frame landed
#     completely outside the display area after "frame match wcs".
#
#  2. Once (1) was fixed, a failed fit correctly fell back to leaving
#     the matrix untouched -- but the probe box was a fixed +/-10
#     pixels in the MOC's own (coarse) pixel space, regardless of how
#     much sky the other image actually covers. For a small image
#     aligned to an all-sky MOC, that fixed box can span a genuinely
#     non-linear part of the HPX projection and fail even where the
#     *actual* footprint needed is perfectly linear, leaving the
#     matrix at its fallback identity -- which "-mask" used directly
#     as the mask-to-image transform, scattering mask pixels instead
#     of covering the image, and which "frame match wcs" used as a
#     no-op zoom scale, silently leaving the MOC frame ~50x too small
#     (a coincidentally plausible-looking but wrong field of view).
#
# The fix sizes the probe box to the *reference* image's own footprint
# (its four corners, mapped into the MOC's pixel space) instead of a
# fixed +/-10, so the fit covers the region actually being aligned.
#
# "frame match wcs" and "-mask"/"mask" both resolve to the exact same
# Base::calcAlignWCS(fits1, fits2, ...) call for a given image pair and
# coordinate system, so a single quantitative check on the zoom computed
# by "frame match wcs" exercises the same arithmetic "-mask" relies on.
# That metric is the resulting zoom of the MOC frame after matching:
# with the reference frame's zoom pinned to 1 beforehand (so the result
# doesn't depend on window size / auto zoom-to-fit), it is the HPX
# projection's true local pixel-scale ratio at that sky position.
# Measured independently against astropy/wcslib's own HPX WCS for the
# fixtures below, that true ratio is ~50-56; the two failure states are
# each unambiguously distinct from that: the original bug (1) drives it
# to inf/nan, and the probe-box regression (2) leaves it at exactly 1
# (the pinned baseline, untouched).
#
# moc/acisf00635N005.fits is the fixture that actually triggers the
# non-linear probe-box failure (its sky position sits close enough to
# an HPX facet seam that the old fixed +/-10 pixel box failed);
# moc/acisf20545N004.fits never triggered it (a different sky position,
# far from any seam) and is included as a baseline so the fix can't be
# "fixed" again by overcorrecting and breaking the already-working case.
#
# We also run the literal "-mask" command as an end-to-end smoke test
# (non-crash coverage, matching this repo's other tests), since that is
# the exact command the bug was originally reported against.

echo
echo "*** moc.sh ***"

where=moc
mocfile=fits/ChandraMOC10_nograting.fits
fail=0

# checkzoom NAME IMGFILE
checkzoom () {
    name=$1
    imgfile=$2

    xpaset -p DS9Test frame delete all
    xpaset -p DS9Test frame new
    xpaset -p DS9Test file ${where}/${imgfile}
    xpaset -p DS9Test zoom to 1
    xpaset -p DS9Test frame new
    xpaset -p DS9Test file ${mocfile}
    xpaset -p DS9Test frame 1
    xpaset -p DS9Test frame match wcs
    xpaset -p DS9Test frame 2

    zoom=`xpaget DS9Test zoom`
    zx=`echo $zoom | awk '{print $1}'`
    zy=`echo $zoom | awk '{print $2}'`

    shapefail=0
    for zz in "$zx" "$zy"
    do
	ok=`echo $zz | awk '{if ($1 > 20 && $1 < 150) print "yes"; else print "no"}'`
	if [ "$ok" != "yes" ]; then
	    shapefail=1
	fi
    done

    if [ $shapefail = "0" ]; then
	echo " $name PASSED (zoom $zx $zy)"
    else
	echo " $name FAILED: zoom '$zx $zy' outside expected ~20-150 range"
	fail=1
    fi
}

StartDS9

checkzoom "match-wcs bad-field" acisf00635N005.fits
checkzoom "match-wcs good-field" acisf20545N004.fits

xpaset -p DS9Test frame delete all
xpaset -p DS9Test quit

# End-to-end smoke test of the literal reported command (non-crash
# coverage only -- the quantitative check above is what actually
# verifies the shared alignment math).
echo " -mask smoke test"
rm -f moc_mask_smoke.png
timeout 1m ds9 -title DS9Test ${where}/acisf00635N005.fits -scale log -scale limits 0 20 -mask ${mocfile} -mask transparency 40 -saveimage png moc_mask_smoke.png -exit
if [ -s moc_mask_smoke.png ]; then
    echo " -mask smoke test PASSED"
else
    echo " -mask smoke test FAILED: no output image produced"
    fail=1
fi
rm -f moc_mask_smoke.png

if [ $fail = "0" ]; then
    echo "PASSED"
else
    echo "FAILED"
    exit 1
fi
