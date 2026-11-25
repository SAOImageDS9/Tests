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
    # min/max per slice in the probe below
    xpaset -p DS9Test scale mode minmax
}

# Native full-depth TIFF (TODO_TIFF16.md). Every tiff/**/*.tif is loaded
# with `tiff native' and probed; the probe has to match a baseline that
# was recorded from the fixture's FITS twin, not from a TIFF load, so a
# reader bug cannot make its own baseline. See tiff/README.md for what the
# twins encode, and tiff/check_*.py for the deeper, pixel-for-pixel checks
# (those need python; this needs only ds9 and the xpa tools).
#
#   tiff.sh [slow] [command|xpa|rgb|baselines]
#
#   command    load every fixture on the command line (smoke test)
#   xpa        load every fixture over XPA and compare with <file>.sav
#   rgb        load every RGB fixture into an RGB frame and compare each
#              channel with <file>.rgb.sav
#   baselines  record <file>.sav and <file>.rgb.sav from the twins:
#              <name>.fits (<name>.lum.fits for an RGB fixture, which a
#              non-RGB frame shows as luminance; <name>.fits loaded as an
#              rgbcube for the RGB frame). A fixture with no twin is one
#              the native reader refuses, so it falls back to the photo
#              path, and its baseline is a `tiff photo' load.
#
# No argument runs command, xpa and rgb.

# Probe the current frame: size, depth, three pixels, the min/max of
# every slice, and the sky at the centre. BITPIX is left out on purpose:
# a twin with BZERO reports 16 where the native load reports -16 (fitsy's
# unsigned 16), and the pixel values are what show the depth. `xpaget
# data' always reads slice 1, so the slices of a stack are told apart by
# their scale limits (minmax).
probe () {
    size=`xpaget DS9Test fits size`
    echo "size $size"
    depth=`xpaget DS9Test fits depth 2>/dev/null`
    echo "depth $depth"

    set -- $size
    w=$1
    h=$2
    if [ "$w" -gt 0 ] 2>/dev/null && [ "$h" -gt 0 ] 2>/dev/null; then
	cx=`expr \( $w + 1 \) / 2`
	cy=`expr \( $h + 1 \) / 2`
	for xy in "1 1" "$cx $cy" "$w $h"; do
	    set -- $xy
	    echo "value $1 $2 `xpaget DS9Test data image $1 $2 1 1 yes`"
	done
	k=1
	while [ "$k" -le "$depth" ] 2>/dev/null; do
	    xpaset -p DS9Test cube $k
	    echo "slice $k limits `xpaget DS9Test scale limits`"
	    k=`expr $k + 1`
	done
	# the sky at the centre: none for most fixtures; header/fitscards_*
	# carry a WCS in ImageDescription, which must match the twin's
	xpaset -p DS9Test crosshair $cx $cy image
	wcs=`xpaget DS9Test crosshair wcs icrs degrees 2>/dev/null`
	if [ -z "`echo $wcs`" ]; then
	    echo "wcs none"
	else
	    echo "wcs $wcs"
	fi
    else
	echo "value none"
    fi
}

# the three channels of an RGB frame
probergb () {
    for c in red green blue; do
	xpaset -p DS9Test rgb channel $c
	echo "channel $c"
	probe
    done
    xpaset -p DS9Test rgb channel red
}

compare () {
    # compare <out> <sav> <label>
    if [ ! -f $2 ]; then
	echo "  NO BASELINE -- run '$0 baselines' to create ${2#$where/}"
	sed 's/^/    /' $1
	nobase=`expr $nobase + 1`
    else
	o=`diff -w $2 $1`
	if [ "$o" = "" ]; then
	    echo "  PASSED"
	    passed=`expr $passed + 1`
	else
	    echo "  FAILED"
	    echo "$o" | sed 's/^/    /'
	    failed=`expr $failed + 1`
	fi
    fi
    rm -f $1
}

where=tiff
what=tiff

slow=0
if [ "$1" = "slow" ]; then
    slow=1
    shift
fi
mode=$1

files=`find $where -name "*.tif" -type f | sort`
if [ -z "$files" ]; then
    echo "No *.tif files found under $where/"
    exit 1
fi

# the RGB fixtures: the ones with a luminance twin
rgbfiles=
for f in $files; do
    if [ -f ${f%.tif}.lum.fits ]; then
	rgbfiles="$rgbfiles $f"
    fi
done

echo
echo "*** TIFF ***"
echo "`echo "$files" | wc -l | tr -d ' '` files under $where/"

# Command Line
if [ "$mode" = "command" -o -z "$mode" ]; then
echo "Testing Command Line File"

if command -v timeout > /dev/null 2>&1; then
    tmout="timeout 10s"
else
    tmout=
    echo " (no timeout command; a wedged ds9 will stall this phase)"
fi

for f in $files
do
    echo " ${f#$where/}"
    opt="-$what native $f -sleep .1"
    if [ $slow = "1" ]; then
	opt="$opt -sleep 1"
    fi
    $tmout ds9 -title DS9Test $opt -exit
done
echo "PASSED"
fi

# Baselines, from the twins
if [ "$mode" = "baselines" ]; then
echo "Recording baselines from the FITS twins"
StartDS9

for f in $files
do
    echo " ${f#$where/}"
    twin=${f%.tif}.fits
    lum=${f%.tif}.lum.fits

    xpaset -p DS9Test frame new
    if [ -f $lum ]; then
	xpaset -p DS9Test fits $lum
    elif [ -f $twin ]; then
	xpaset -p DS9Test fits $twin
    else
	xpaset -p DS9Test $what photo $f 2>/dev/null
    fi
    probe > ${f}.sav 2>&1
    xpaset -p DS9Test frame delete

    if [ -f $lum ]; then
	xpaset -p DS9Test frame new rgb
	xpaset -p DS9Test rgbcube $twin
	probergb > ${f}.rgb.sav 2>&1
	xpaset -p DS9Test frame delete
    fi
done

xpaset -p DS9Test quit
echo "DONE"
exit 0
fi

# XPA, compared with the baselines
if [ "$mode" = "xpa" -o -z "$mode" ]; then
echo "Testing XPA File"
StartDS9

passed=0
failed=0
nobase=0
for f in $files
do
    echo " ${f#$where/}"
    xpaset -p DS9Test frame new
    xpaset -p DS9Test $what native $f 2>/dev/null
    if [ $slow = "1" ]; then
	sleep 1
    fi
    probe > ${f}.out 2>&1
    xpaset -p DS9Test frame delete
    compare ${f}.out ${f}.sav
done

xpaset -p DS9Test quit
echo "$passed passed, $failed failed, $nobase without a baseline"
if [ "$failed" = "0" -a "$nobase" = "0" ]; then
    echo "PASSED"
else
    echo "FAILED"
fi
fi

# RGB frame, compared with the baselines
if [ "$mode" = "rgb" -o -z "$mode" ]; then
echo "Testing RGB Frame"
StartDS9

passed=0
failed=0
nobase=0
for f in $rgbfiles
do
    echo " ${f#$where/}"
    xpaset -p DS9Test frame new rgb
    xpaset -p DS9Test $what native $f
    if [ $slow = "1" ]; then
	sleep 1
    fi
    probergb > ${f}.rgb.out 2>&1
    xpaset -p DS9Test frame delete
    compare ${f}.rgb.out ${f}.rgb.sav
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
