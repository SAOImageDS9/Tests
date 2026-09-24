StartDS9 () {
    if [ `xpaaccess DS9Test` = no ]; then
	timeout 1m ds9 -title DS9Test &

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

# Regression test for "Save As -> Pixel Mask" export (Base::savePixelMask in
# tksao/frame/frsave.C), covering every region shape that actually has an
# area (Marker::hasArea() == 1) and can therefore be meaningfully rasterized
# into a mask. The following shapes have NO area (Marker::hasArea() == 0,
# the base class default) and are intentionally NOT covered here: point,
# line, vector (arrow), text, ruler, compass, projection, segment. These
# are pure decorators/annotations with no well-defined "inside" test and
# cannot be pixel-masked or used as composite operands.
#
# This test specifically guards two bugs fixed in the main DS9 repo
# (tksao/frame/baseellipse.h, basebox.h, basemarker.C/h):
#
#  1. BaseEllipse/BaseBox's generic isIn(v) used to test only the
#     outermost ring radius, so the *inner* radius of an
#     annulus/boxannulus/ellipseannulus (and the innermost ring of a
#     panda/epanda/bpanda) was never excluded -- the "hole" in the middle
#     was incorrectly painted as part of the mask.
#  2. The same generic isIn(v) ignored the angular wedge (start/stop
#     angle) of panda/epanda/bpanda entirely, so e.g. a 0-180 degree
#     wedge was rasterized as a full 360 degree ring.
#
# Each fixture in pixmask/ is a single shape on the small (64x40, all
# value 1.0) synthetic test image pixmask/img.fits, sized in plain
# "image" pixel coordinates (no WCS) so probe coordinates are exact
# integers. For each shape we probe a handful of hand-picked pixels and
# assert whether they are IN (mask value != 0) or OUT (mask value == 0)
# of the region. The pixel mask's nonzero value is the region's marker
# id, which is session-dependent (increments across loads), so we only
# assert nonzero-ness, never a specific id.
#
# Probe rationale per shape:
#  - circle/ellipse/box/polygon (solid shapes): a center probe and a
#    probe just inside/outside the boundary confirm ordinary boundary
#    correctness (no hole/angle logic involved for these).
#  - annulus/boxannulus/ellipseannulus: a probe at the shape's own
#    center (inside the hole), a probe in the ring proper, and a probe
#    outside the outer boundary.
#  - panda/epanda/bpanda: a wedge from angle 0 to 180 degrees. DS9's
#    angle convention is standard math convention (0 = +x/east,
#    increasing counter-clockwise; 90 = +y/north; 180 = -x/west), so a
#    0-180 wedge covers north/east/west and excludes only the south
#    side. We probe the shared center (the hole, must be OUT), a point
#    to the north at mid-radius (must be IN), and a point to the south
#    at the same radius (must be OUT) -- isolating the angle-wedge
#    check from the radius/hole check.
#
# All probe/expectation pairs below were verified against the live,
# already-fixed ds9 binary before being hardcoded here.

echo
echo "*** PIXMASK ***"

StartDS9

where=pixmask
fail=0

# probe VALUE EXPECT -> EXPECT is "IN" (nonzero) or "OUT" (zero)
probeok () {
    v=$1
    expect=$2
    if [ "$expect" = "OUT" ]; then
	[ "$v" = "0" ]
    else
	[ "$v" != "0" ]
    fi
}

# doshape NAME REGFILE  "x,y,EXPECT" ...
doshape () {
    name=$1
    regfile=$2
    shift 2

    xpaset -p DS9Test frame clear
    xpaset -p DS9Test file ${where}/img.fits
    xpaset -p DS9Test regions deleteall
    xpaset -p DS9Test regions file ${where}/${regfile}
    echo "SavePixelMaskFile ${where}/${name}.mask.out.fits" | xpaset DS9Test tcl
    xpaset -p DS9Test regions deleteall

    xpaset -p DS9Test frame new
    xpaset -p DS9Test file ${where}/${name}.mask.out.fits

    shapefail=0
    for probe in "$@"
    do
	x=`echo $probe | cut -d, -f1`
	y=`echo $probe | cut -d, -f2`
	expect=`echo $probe | cut -d, -f3`

	v=`xpaget DS9Test data image $x $y 1 1 no | awk -F'= ' '{print $2}'`

	if probeok "$v" "$expect"; then
	    :
	else
	    echo "  probe ($x,$y): expected $expect, got value '$v'"
	    shapefail=1
	fi
    done

    xpaset -p DS9Test frame delete
    rm -f ${where}/${name}.mask.out.fits

    if [ $shapefail = "0" ]; then
	echo " $name PASSED"
    else
	echo " $name FAILED"
	fail=1
    fi
}

doshape circle circle.reg \
    "20,20,IN" "20,10,IN" "20,3,OUT"

doshape ellipse ellipse.reg \
    "20,20,IN" "34,20,IN" "36,20,OUT" "20,29,IN" "20,31,OUT"

doshape box box.reg \
    "20,20,IN" "34,20,IN" "36,20,OUT"

doshape polygon polygon.reg \
    "20,20,IN" "34,20,IN" "36,20,OUT"

doshape annulus annulus.reg \
    "20,20,OUT" "20,10,IN" "20,3,OUT"

doshape boxannulus boxannulus.reg \
    "20,20,OUT" "20,10,IN" "20,3,OUT"

doshape ellipseannulus ellipseannulus.reg \
    "20,20,OUT" "30,20,IN" "20,27,IN" "20,3,OUT"

doshape panda panda.reg \
    "20,20,OUT" "20,30,IN" "20,10,OUT"

doshape epanda epanda.reg \
    "20,20,OUT" "20,30,IN" "20,10,OUT"

doshape bpanda bpanda.reg \
    "20,20,OUT" "20,30,IN" "20,10,OUT"

xpaset -p DS9Test quit

if [ $fail = "0" ]; then
    echo "PASSED"
else
    echo "FAILED"
    exit 1
fi
