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

# Regression test for Composite Region (Region -> Composite Region, and the
# "&&"/"||" grammar in .reg files) member include/exclude handling and
# Union/Intersection combination, covering every region shape that has an
# area (Marker::hasArea() == 1) and can therefore be a composite member.
# The following shapes have NO area (Marker::hasArea() == 0, the base
# class default) and are intentionally NOT covered: point, line, vector
# (arrow), text, ruler, compass, projection, segment -- these are pure
# decorators/annotations with no well-defined "inside" test and cannot be
# composite operands.
#
# This guards a bug fixed in the main DS9 repo (tksao/frame/composite.C):
# Composite::isIn and Composite::isInRegion never checked a member's
# INCLUDE property, so an excluded member (eg "-box(...)") was folded
# directly into the Union/Intersection combination instead of being
# carved out as a hole first -- Pixel Mask export of an Intersection
# composite with an excluded member showed only include-member-1 AND
# include-member-2 AND *include*-member-3 (ignoring the exclude flag
# entirely), and a Union composite included the "excluded" member's
# pixels rather than subtracting them.
#
# There is no XPA verb that renders (or queries the render of) the
# "Show Area" hatch overlay directly, and a canvas screenshot comparison
# would be fragile (this test suite must not depend on a running X
# server's rendering fidelity). Fortunately Composite::isIn(v) now
# *delegates directly* to Composite::isInArea(v) (the exact function
# that decides which pixels get the "Show Area" hatch pattern), and
# Composite::isInRegion (the Pixel-Mask-export code path) was fixed with
# the identical exclude-first-then-combine logic. So testing composite
# membership via Pixel Mask export (a plain, deterministic pixel-value
# readback) exercises precisely the same logic "Show Area" relies on.
# We additionally do a cheap direct smoke-test of the real
# Composite::showArea API surface itself (toggling "composite area 1"
# through the Tcl entry point) so the two are both covered.
#
# Also guards the companion fix in baseellipse.h/basebox.h/basemarker.C:
# a shape used as a composite member must still have its own hole
# (annulus family) and angular wedge (panda family) respected -- the
# per-shape "wedge" sub-test below wraps a single half-wedge
# panda/epanda/bpanda in a (trivial, one-member) composite specifically
# to confirm the composite code path does not regress that.
#
# Every fixture shape lives on the small (64x40, all value 1.0)
# synthetic test image pixmask/img.fits (shared with pixmask.sh), in
# plain "image" pixel coordinates (no WCS) so probe coordinates are
# exact integers.
#
# For each of the 10 shapes we build a 3-member composite:
#   A: shape centered (20,20), sized so its footprint spans roughly
#      x:[5,35] y:[5,35] -- INCLUDED
#   B: same shape/size, centered (40,20), spans x:[25,55] y:[5,35],
#      overlapping A in x:[25,35] -- INCLUDED
#   C: same shape family, smaller, centered (30,20), spans roughly
#      x:[25,35] y:[15,25] -- EXCLUDED; sits inside the A/B overlap
# For the annulus/panda-family shapes, A/B/C all use a degenerate zero
# inner-radius/full 0-360 degree wedge so they behave as plain solid
# disks/boxes here -- the hole and wedge logic get their own dedicated,
# decoupled probes in pixmask.sh and in the "wedge" sub-test below, so
# this matrix isn't testing two different things behind one probe.
#
# Probe points and their expected Union / Intersection membership:
#   pA   =(10,20): inside A only                 -> union IN,  inter OUT
#   pB   =(50,20): inside B only                  -> union IN,  inter OUT
#   pAB  =(30,10): inside both A and B, not C      -> union IN,  inter IN
#   pC   =(30,20): inside A, B, AND excluded C     -> union OUT, inter OUT
#   pout =(58,38): outside A, B, and C entirely    -> union OUT, inter OUT
# (pC must read OUT under both operations -- an exclude is always a hole
# first, regardless of how the *included* members are combined.)
#
# All probe/expectation pairs and the degenerate zero-radius/0-360-degree
# "acts as solid" behavior were verified against the live, already-fixed
# ds9 binary before being hardcoded here.

echo
echo "*** COMPOSITES ***"

StartDS9

where=pixmask
fail=0

# shapeparams NAME -> sets $A $B $C to that shape's member definitions
shapeparams () {
    case "$1" in
	circle)
	    A="circle(20,20,15)"; B="circle(40,20,15)"; C="circle(30,20,5)";;
	ellipse)
	    A="ellipse(20,20,15,15,0)"; B="ellipse(40,20,15,15,0)"; C="ellipse(30,20,5,5,0)";;
	box)
	    A="box(20,20,30,30,0)"; B="box(40,20,30,30,0)"; C="box(30,20,10,10,0)";;
	polygon)
	    A="polygon(5,5,35,5,35,35,5,35)"
	    B="polygon(25,5,55,5,55,35,25,35)"
	    C="polygon(25,15,35,15,35,25,25,25)";;
	annulus)
	    A="annulus(20,20,0,15)"; B="annulus(40,20,0,15)"; C="annulus(30,20,0,5)";;
	boxannulus)
	    A="box(20,20,0,0,30,30,0)"; B="box(40,20,0,0,30,30,0)"; C="box(30,20,0,0,10,10,0)";;
	ellipseannulus)
	    A="ellipse(20,20,0,0,15,15,0)"; B="ellipse(40,20,0,0,15,15,0)"; C="ellipse(30,20,0,0,5,5,0)";;
	panda)
	    A="panda(20,20,0,360,1,0,15,1)"; B="panda(40,20,0,360,1,0,15,1)"; C="panda(30,20,0,360,1,0,5,1)";;
	epanda)
	    A="epanda(20,20,0,360,1,0,0,15,15,1,0)"
	    B="epanda(40,20,0,360,1,0,0,15,15,1,0)"
	    C="epanda(30,20,0,360,1,0,0,5,5,1,0)";;
	bpanda)
	    A="bpanda(20,20,0,360,1,0,0,30,30,1,0)"
	    B="bpanda(40,20,0,360,1,0,0,30,30,1,0)"
	    C="bpanda(30,20,0,360,1,0,0,10,10,1,0)";;
    esac
}

# wedgeparams NAME -> sets $W to a single 0-180 degree half-wedge member
# (only meaningful for the panda family)
wedgeparams () {
    case "$1" in
	panda)  W="panda(20,20,0,180,1,5,15,1)";;
	epanda) W="epanda(20,20,0,180,1,5,5,15,15,1,0)";;
	bpanda) W="bpanda(20,20,0,180,1,10,10,30,30,1,0)";;
    esac
}

# gencomposite OP FILE -> writes a 3-member ($A include, $C exclude, $B
# include) composite region file using conjunction OP ("||" or "&&")
gencomposite () {
    op=$1
    file=$2
    {
	echo "# Region file format: DS9 version 4.1"
	echo "global color=green select=1 edit=1 move=1 delete=1 include=1 source=1"
	echo "image"
	echo "# composite(30,20,0) $op composite=1"
	echo "$A $op"
	echo "-$C $op"
	echo "$B"
    } > "$file"
}

# genwedge FILE -> writes a single-member composite wrapping $W
genwedge () {
    file=$1
    {
	echo "# Region file format: DS9 version 4.1"
	echo "global color=green select=1 edit=1 move=1 delete=1 include=1 source=1"
	echo "image"
	echo "# composite(20,20,0) || composite=1"
	echo "$W"
    } > "$file"
}

# probe X Y -> mask value at that pixel
probe () {
    xpaget DS9Test data image $1 $2 1 1 no | awk -F'= ' '{print $2}'
}

probeok () {
    v=$1
    expect=$2
    if [ "$expect" = "OUT" ]; then
	[ "$v" = "0" ]
    else
	[ "$v" != "0" ]
    fi
}

loadmask () {
    regfile=$1
    xpaset -p DS9Test frame clear
    xpaset -p DS9Test file ${where}/img.fits
    xpaset -p DS9Test regions deleteall
    xpaset -p DS9Test regions file $regfile
}

savemask () {
    outfile=$1
    echo "SavePixelMaskFile $outfile" | xpaset DS9Test tcl
}

showareasmoke () {
    # Toggle the real Composite::showArea flag on the just-loaded
    # composite (its marker id is whatever DS9 assigned this session,
    # discovered dynamically -- ids increment across the whole session
    # and are not reset by "regions deleteall").
    xpaset -p DS9Test regions select all
    idfile=$1
    {
	printf '%s\n' 'set fr $::current(frame)'
	printf '%s\n' 'set ids [$fr get marker select]'
	printf '%s\n' 'set id [lindex $ids 0]'
	printf '%s\n' 'set ok 1'
	printf '%s\n' 'if {[catch {$fr marker $id composite area 1} err]} { set ok 0 }'
	printf 'set fh [open %s w]\n' "$idfile"
	printf '%s\n' 'puts $fh $ok'
	printf '%s\n' 'close $fh'
    } | xpaset DS9Test tcl
}

# doshape NAME
doshape () {
    name=$1
    shapefail=0

    shapeparams $name

    for opname in union intersection
    do
	if [ "$opname" = "union" ]; then
	    op="||"
	    e_pA=IN;  e_pB=IN;  e_pAB=IN; e_pC=OUT; e_pout=OUT
	else
	    op="&&"
	    e_pA=OUT; e_pB=OUT; e_pAB=IN; e_pC=OUT; e_pout=OUT
	fi

	regfile=${name}.${opname}.reg.tmp
	maskfile=${name}.${opname}.mask.tmp.fits
	areafile=${name}.${opname}.area.tmp

	gencomposite "$op" $regfile
	loadmask $regfile
	savemask $maskfile
	showareasmoke $areafile

	xpaset -p DS9Test regions deleteall
	xpaset -p DS9Test frame new
	xpaset -p DS9Test file $maskfile

	pA=`probe 10 20`;  pB=`probe 50 20`;  pAB=`probe 30 10`
	pC=`probe 30 20`;  pout=`probe 58 38`
	xpaset -p DS9Test frame delete

	if probeok "$pA" "$e_pA" && probeok "$pB" "$e_pB" && \
	   probeok "$pAB" "$e_pAB" && probeok "$pC" "$e_pC" && \
	   probeok "$pout" "$e_pout"
	then
	    :
	else
	    echo "  $name $opname: pA=$pA(want $e_pA) pB=$pB(want $e_pB)" \
		 "pAB=$pAB(want $e_pAB) pC=$pC(want $e_pC)" \
		 "pout=$pout(want $e_pout)"
	    shapefail=1
	fi

	areaok=`cat $areafile 2>/dev/null`
	if [ "$areaok" != "1" ]; then
	    echo "  $name $opname: composite area 1 (Show Area) failed"
	    shapefail=1
	fi

	rm -f $regfile $maskfile $areafile
    done

    # panda-family only: composite-wrapped half-wedge sub-test
    case "$name" in
	panda|epanda|bpanda)
	    wedgeparams $name
	    regfile=${name}.wedge.reg.tmp
	    maskfile=${name}.wedge.mask.tmp.fits

	    genwedge $regfile
	    loadmask $regfile
	    savemask $maskfile
	    xpaset -p DS9Test regions deleteall
	    xpaset -p DS9Test frame new
	    xpaset -p DS9Test file $maskfile

	    hole=`probe 20 20`; north=`probe 20 30`; south=`probe 20 10`
	    xpaset -p DS9Test frame delete

	    if probeok "$hole" OUT && probeok "$north" IN && probeok "$south" OUT
	    then
		:
	    else
		echo "  $name wedge: hole=$hole(want OUT) north=$north(want IN)" \
		     "south=$south(want OUT)"
		shapefail=1
	    fi

	    rm -f $regfile $maskfile
	    ;;
    esac

    if [ $shapefail = "0" ]; then
	echo " $name PASSED"
    else
	echo " $name FAILED"
	fail=1
    fi
}

doshape circle
doshape ellipse
doshape box
doshape polygon
doshape annulus
doshape boxannulus
doshape ellipseannulus
doshape panda
doshape epanda
doshape bpanda

xpaset -p DS9Test quit

if [ $fail = "0" ]; then
    echo "PASSED"
else
    echo "FAILED"
    exit 1
fi
