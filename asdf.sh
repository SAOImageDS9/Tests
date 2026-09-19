StartDS9 () {
    if [ `xpaaccess DS9Test` = no ]; then
	ds9 -title DS9Test &

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
    sleep 1
}

# Probe the currently loaded frame and write a small, diffable summary.
#
# Deliberately more than a smoke test: an ASDF file can load at the wrong
# shape, or from the wrong array, and still "work". The pixel samples are
# what catch that -- a Roman *_cal.asdf has 15 arrays of identical shape,
# so size alone cannot tell them apart.
#
# The sample coordinates are derived from the reported size rather than
# hardwired, so this stays valid for any shape, from a 4x4096 reference
# strip to a 5000^2 coadd.
probe () {
    size=`xpaget DS9Test fits size`
    echo "size $size"
    echo "bitpix `xpaget DS9Test fits bitpix`"

    # BLANK is present only for integer arrays carrying a null sentinel
    blank=`xpaget DS9Test fits header keyword BLANK 2>/dev/null`
    if [ -z "$blank" ]; then
	echo "blank none"
    else
	echo "blank $blank"
    fi

    set -- $size
    w=$1
    h=$2
    cx=""
    cy=""
    if [ "$w" -gt 0 ] 2>/dev/null && [ "$h" -gt 0 ] 2>/dev/null; then
	cx=`expr $w / 2`
	cy=`expr $h / 2`
	for xy in "1 1" "$cx $cy" "$w $h"; do
	    set -- $xy
	    echo "value $1 $2 `xpaget DS9Test data image $1 $2 1 1 yes`"
	done
    else
	echo "value none"
    fi

    # Most fixtures carry no WCS; a real Roman product does, and the gwcs/
    # ones exist precisely to exercise it, so this is often the most valuable
    # line in the file.
    #
    # The crosshair has to be positioned explicitly first. `xpaget data' does
    # not move it, so reading the crosshair straight after those samples
    # reports wherever it was last left -- which made this line depend on
    # whatever ran before, and therefore not reproducible.
    if [ -n "$cx" ]; then
	xpaset -p DS9Test crosshair $cx $cy image
	wcs=`xpaget DS9Test crosshair wcs icrs degrees 2>/dev/null`
	if [ -z "`echo $wcs`" ]; then
	    echo "wcs $cx $cy none"
	else
	    echo "wcs $cx $cy $wcs"
	fi
    else
	echo "wcs none"
    fi
}

# Load one file, probe it, and either diff against its baseline or, in
# save mode, create the baseline.
testit () {
    f=$1
    echo " ${f#$where/}"

    xpaset -p DS9Test frame new
    xpaset -p DS9Test $what $f
    if [ $slow = "1" ]; then
	sleep 1
    fi

    probe > ${f}.out 2>&1
    xpaset -p DS9Test frame delete

    if [ "$mode" = "$save" ]; then
	mv ${f}.out ${f}.sav
	echo "  SAVED ${f#$where/}.sav"
	return
    fi

    if [ ! -f ${f}.sav ]; then
	echo "  NO BASELINE -- run '$0 $save' to create ${f#$where/}.sav"
	cat ${f}.out | sed 's/^/    /'
	rm -f ${f}.out
	nobase=`expr $nobase + 1`
	return
    fi

    o=`diff ${f}.sav ${f}.out`
    if [ "$o" = "" ]; then
	echo "  PASSED"
	passed=`expr $passed + 1`
    else
	echo "  FAILED"
	echo "$o" | sed 's/^/    /'
	failed=`expr $failed + 1`
    fi
    rm -f ${f}.out
}

# which/where/what
where=asdf

ext=asdf

what=asdf

save=save

# slow down?
slow=0
if [ "$1" = "slow" ]; then
    slow=1
    shift
fi

mode=$1

# Every .asdf under $where, found rather than listed, so that dropping a
# new file into the directory picks it up with no edit here. A new file
# reports NO BASELINE until '$0 save' is run for it.
files=`find $where -name "*.$ext" -type f | sort`

if [ -z "$files" ]; then
    echo "No *.$ext files found under $where/"
    exit 1
fi

echo
echo "*** ASDF ***"
echo "`echo "$files" | wc -l | tr -d ' '` files under $where/"

# Command Line
if [ "$mode" = "command" -o -z "$mode" ]; then
echo "Testing Command Line File"

for f in $files
do
    echo " ${f#$where/}"
    opt="-$what $f -sleep .1"
    if [ $slow = "1" ]; then
	opt="$opt -sleep 1"
    fi
    ds9 -title DS9Test $opt -exit
done
echo "PASSED"
fi

# Mask layers, which the per-file probe above cannot cover: a mask is a
# *second* load into a frame that already holds an image, so what has to be
# checked is that the first load survives the second. Both of these were
# real regressions - an ASDF mask replaced the frame's WCS with its own,
# and replaced the cached YAML tree the header viewer shows - and neither
# is visible in a single-file probe or in a rendered-image comparison,
# because the frame goes on reporting the image as its file either way.
if [ "$mode" = "mask" -o -z "$mode" ]; then
echo "Testing Mask Layers"

StartDS9

mpassed=0
mfailed=0

check () {
    # check <label> <expected> <actual>
    if [ "$2" = "$3" ]; then
	echo "  PASSED $1"
	mpassed=`expr $mpassed + 1`
    else
	echo "  FAILED $1"
	echo "    expected: $2"
	echo "    actual:   $3"
	mfailed=`expr $mfailed + 1`
    fi
}

# An ASDF image, then a mask from a *different* ASDF file whose own WCS is
# on the same 192x192 grid -- so the grid check cannot reject it and the
# only thing stopping it replacing the image's WCS is the layer test.
xpaset -p DS9Test frame new
xpaset -p DS9Test asdf $where/gwcs/gnomonic.asdf
xpaset -p DS9Test crosshair 96 96 image
before=`xpaget DS9Test crosshair wcs icrs degrees`

xpaset -p DS9Test asdf mask $where/gwcs/zenithal_equal_area.asdf
xpaset -p DS9Test crosshair 96 96 image
check "asdf mask leaves the image WCS alone" \
    "$before" "`xpaget DS9Test crosshair wcs icrs degrees`"

# The header viewer reads this, so it has to still be the image's file.
#
# Two things about getting a value back out: `xpaset tcl' returns nothing,
# so it has to go through a file; and it evaluates what it receives a line
# at a time, so a ';'-separated one-liner fails with "wrong # args" -- the
# script has to be newline separated.
tmp=`mktemp`
probe_tcl () {
    printf 'set ch [open %s w]\nputs $ch [%s]\nclose $ch\n' "$tmp" "$1" \
	| xpaset DS9Test tcl
    cat $tmp
}
check "asdf mask leaves the cached tree alone" \
    "gnomonic.asdf" \
    "`probe_tcl 'file tail $asdf(file,$current(frame))'`"

check "the mask is actually applied" "nonzero" "`xpaget DS9Test mask mark`"
xpaset -p DS9Test mask clear
xpaset -p DS9Test frame delete

# A FITS image with an ASDF mask must keep its FITS header -- caching the
# mask's tree here would make the Header command show YAML for a FITS file.
xpaset -p DS9Test frame new
xpaset -p DS9Test fits fits/float.fits
xpaset -p DS9Test asdf mask $where/fixtures/none/float.asdf
check "asdf mask on a FITS image caches no tree" "0" \
    "`probe_tcl 'AsdfHasTree $current(frame)'`"
xpaset -p DS9Test mask clear
xpaset -p DS9Test frame delete

rm -f $tmp
xpaset -p DS9Test quit

echo "$mpassed passed, $mfailed failed"
if [ "$mfailed" = "0" ]; then
    echo "PASSED"
else
    echo "FAILED"
fi
fi

# XPA, with baseline comparison
if [ "$mode" = "xpa" -o "$mode" = "$save" -o -z "$mode" ]; then
if [ "$mode" = "$save" ]; then
    echo "Testing XPA File -- creating baselines"
else
    echo "Testing XPA File"
fi

StartDS9

passed=0
failed=0
nobase=0

for f in $files
do
    testit $f
done

xpaset -p DS9Test quit

echo "$passed passed, $failed failed, $nobase without a baseline"
if [ "$failed" = "0" -a "$nobase" = "0" ]; then
    echo "PASSED"
else
    echo "FAILED"
fi
fi

echo "DONE"
