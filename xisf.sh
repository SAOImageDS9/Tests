#!/bin/sh
# Native XISF loading (TODO_XISF.md), through ds9's own `xisf' command.
#
#   ./xisf.sh            all phases
#   ./xisf.sh xpa        every fixture against its baseline
#   ./xisf.sh command    one ds9 launch per fixture, -xisf on the command line
#   ./xisf.sh mask       mask layers leave the image alone
#   ./xisf.sh extra      image selection, errors, header viewer, backup
#
# There is deliberately no `save' mode. The baselines are not this
# reader's output: xisf/make_baselines.sh records each one from the
# fixture's FITS twin in ds9, before the reader existed, so a pass means
# the XISF load reproduces exactly what ds9 shows for the FITS equivalent.
# Regenerating them from the reader would make that check a rubber stamp.

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
    # keep Error/Warning from opening dialogs nothing can dismiss
    printf 'set pds9(confirm) 0\n' | xpaset DS9Test tcl
}

# The probe, lifted from asdf.sh so the two suites cannot drift: an XISF
# baseline means the same as an ASDF one.
eval "`awk '/^probe \(\) \{/,/^\}/' asdf.sh`"

testit () {
    f=$1
    echo " ${f#$where/}"

    xpaset -p DS9Test frame new
    xpaset -p DS9Test $what $f > /dev/null 2>&1
    probe > ${f}.out 2>&1
    xpaset -p DS9Test frame delete

    if [ ! -f ${f}.sav ]; then
	echo "  NO BASELINE -- run xisf/make_baselines.sh"
	rm -f ${f}.out
	nobase=`expr $nobase + 1`
	return
    fi

    o=`diff -w ${f}.sav ${f}.out`
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

check () {
    # check <label> <expected> <actual>
    if [ "$2" = "$3" ]; then
	echo "  PASSED $1"
	cpassed=`expr $cpassed + 1`
    else
	echo "  FAILED $1"
	echo "    expected: $2"
	echo "    actual:   $3"
	cfailed=`expr $cfailed + 1`
    fi
}

# `xpaset tcl' returns nothing and evaluates a line at a time, so a value
# comes back through a file and scripts are newline separated.
probe_tcl () {
    printf 'set ch [open %s w]\nputs $ch [%s]\nclose $ch\n' "$tmp" "$1" \
	| xpaset DS9Test tcl
    cat $tmp
}

where=xisf
what=xisf
mode=$1

files=`find $where -name "*.xisf" -type f | sort`
if [ -z "$files" ]; then
    echo "No *.xisf files found under $where/"
    exit 1
fi

echo
echo "*** XISF ***"
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
    $tmout ds9 -title DS9Test -xisf $f -sleep .1 -exit > /dev/null 2>&1
done
echo "PASSED"
fi

# Mask layers: a second load into a frame that already holds an image. The
# first load must survive it - its WCS, and the file the header viewer
# shows - which no single-file probe can see.
if [ "$mode" = "mask" -o -z "$mode" ]; then
echo "Testing Mask Layers"
StartDS9
cpassed=0
cfailed=0
tmp=`mktemp`

xpaset -p DS9Test frame new
xpaset -p DS9Test xisf $where/wcs/layer1_tan_northup.xisf
xpaset -p DS9Test crosshair 32 24 image
before=`xpaget DS9Test crosshair wcs icrs degrees`
xpaset -p DS9Test xisf mask $where/wcs/layer1_tan.xisf
xpaset -p DS9Test crosshair 32 24 image
check "xisf mask leaves the image WCS alone" \
    "$before" "`xpaget DS9Test crosshair wcs icrs degrees`"
check "xisf mask leaves the header file alone" "layer1_tan_northup.xisf" \
    "`probe_tcl 'file tail $xisf(file,$current(frame))'`"
check "the mask is applied" "nonzero" "`xpaget DS9Test mask mark`"
xpaset -p DS9Test mask clear
xpaset -p DS9Test frame delete

xpaset -p DS9Test frame new
xpaset -p DS9Test fits fits/float.fits
xpaset -p DS9Test xisf mask $where/formats/float32.xisf
check "xisf mask on a FITS image records no XISF file" "0" \
    "`probe_tcl 'info exists xisf(file,$current(frame))'`"
xpaset -p DS9Test mask clear
xpaset -p DS9Test frame delete

rm -f $tmp
xpaset -p DS9Test quit
echo "$cpassed passed, $cfailed failed"
[ "$cfailed" = "0" ] && echo "PASSED" || echo "FAILED"
fi

# What only the UI and scripting layer can get wrong.
if [ "$mode" = "extra" -o -z "$mode" ]; then
echo "Testing Selection, Errors, Header, Backup"
StartDS9
cpassed=0
cfailed=0
tmp=`mktemp`

# an image picked by id, and by index, through "<file>:<image>"
xpaset -p DS9Test frame new
xpaset -p DS9Test xisf $where/location/multi_three.xisf:small
check "file:id selects the image" "32 24" "`xpaget DS9Test fits size`"
check "file:id is what ds9 reports as the file" "multi_three.xisf:small" \
    "`xpaget DS9Test file | xargs basename`"
xpaset -p DS9Test frame delete
xpaset -p DS9Test frame new
xpaset -p DS9Test xisf $where/location/multi_three.xisf:2
check "file:index selects the image (RGB, 3 planes)" "64 48 3" \
    "`xpaget DS9Test fits size` `xpaget DS9Test fits depth`"
xpaset -p DS9Test frame delete

# `xisf new' makes a frame of its own
n0=`xpaget DS9Test frame all | wc -w`
xpaset -p DS9Test xisf new $where/formats/uint8.xisf
check "xisf new adds a frame" "`expr $n0 + 1`" \
    "`xpaget DS9Test frame all | wc -w | tr -d ' '`"
xpaset -p DS9Test frame delete

# the reader's own reason reaches the caller, including a refusal only
# the block decoder can make
xpaset -p DS9Test frame new
msg=`xpaset -p DS9Test xisf $where/formats/complex32.xisf 2>&1`
check "a refusal says why" "yes" \
    "`echo "$msg" | grep -q 'Complex32 samples are not supported' && echo yes`"
msg=`xpaset -p DS9Test xisf $where/checksum/sha256_bad.xisf 2>&1`
check "a bad checksum says so" "yes" \
    "`echo "$msg" | grep -q 'checksum mismatch' && echo yes`"
xpaset -p DS9Test frame delete

# the header viewer: the FITS header FitsXisf built, then the XML
xpaset -p DS9Test frame new
xpaset -p DS9Test xisf $where/header/keywords.xisf
printf 'DisplayHeader 1 test\n' | xpaset DS9Test tcl
hv='[set hd-$current(frame)-1(text)] get 1.0 end'
check "header viewer shows the FITS header" "yes" \
    "`probe_tcl "$hv" | grep -q \"^OBJECT  = 'M31 & friends'\" && echo yes`"
check "header viewer shows the XISF XML" "yes" \
    "`probe_tcl "$hv" | grep -q '<FITSKeyword name=\"OBJECT\"' && echo yes`"
printf 'DestroyHeader $current(frame)\n' | xpaset DS9Test tcl
xpaset -p DS9Test frame delete

# backup and restore: the frame is rebuilt from the XISF file itself
bdir=`mktemp -d ./_xisfbackup.XXXXXX`
xpaset -p DS9Test frame delete all
xpaset -p DS9Test frame new
xpaset -p DS9Test xisf $where/wcs/layer1_tan_northup.xisf
xpaset -p DS9Test crosshair 32 24 image
before="`xpaget DS9Test fits size` `xpaget DS9Test crosshair wcs icrs degrees`"
xpaset -p DS9Test backup `pwd`/$bdir/x.bck
xpaset -p DS9Test frame delete all
xpaset -p DS9Test restore `pwd`/$bdir/x.bck
xpaset -p DS9Test crosshair 32 24 image
check "backup and restore keep pixels and WCS" "$before" \
    "`xpaget DS9Test fits size` `xpaget DS9Test crosshair wcs icrs degrees`"
check "the restored frame is the XISF file" "layer1_tan_northup.xisf" \
    "`xpaget DS9Test file | xargs basename`"
rm -rf $bdir
xpaset -p DS9Test frame delete all

rm -f $tmp
xpaset -p DS9Test quit
echo "$cpassed passed, $cfailed failed"
[ "$cfailed" = "0" ] && echo "PASSED" || echo "FAILED"
fi

if [ "$mode" = "xpa" -o -z "$mode" ]; then
echo "Testing XPA File"
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
