
echo "SAMP Tests"

startit () {
    echo "Starting DS9..."
    echo "ds9 -title DS9Test -debug $samp -debug $samphub -zscale"
    ds9 -title DS9Test -debug $samp -debug $samphub -zscale&
    #~ echo "click return to start"
    #~ read
    i=1
    while test $i -lt 20
    do
      sleep 2
      if test `xpaaccess DS9Test` = "yes"
      then
          break
      fi
      i=`expr $i + 1`
    done


}

# each test starts from a clean slate with just fits/img.fits loaded,
# so a failure in one test can not leave the wrong (or no) frames
# behind for the next one
starttest () {
    xpaset -p DS9Test frame delete all
    xpaset -p DS9Test frame new
    xpaset -p DS9Test fits fits/img.fits
}

endtest () {
    xpaset -p DS9Test frame delete all
}

testit () {
    echo
    echo "Testing $1"
    if [ "$1" != "exit" ]; then
	starttest
    fi
    tclsh samp.tcl $debug block $msg < samp/${1}.samp
    rr=$?
    # on 125 leave ds9 as is for inspection
    if [ "$1" != "exit" -a $rr -ne 125 ]; then
	endtest
    fi
    case $rr in
	124)
	    echo "FAILED: $1 had timeouts"
	    failed="$failed $1"
	    return
	    ;;
	125)
	    # too many consecutive timeouts, ds9 is likely wedged, so
	    # stop here and leave it running for inspection
	    echo "FAILED: $1 had timeouts, giving up"
	    echo "Timeouts in:$failed $1"
	    echo "stop ds9 with: xpaset -p DS9Test exit"
	    rm -f $SAMP_STREAK_FILE
	    exit 1
	    ;;
    esac
    echo "PASSED"
}

doit () {
    if [ "$1" = "$2" -o  -z "$1" ]; then
    testit "$2"
    fi
}

echo
echo "*** samp.sh ***"

# must be invoked
# iexam
# nvss
# vla
# 2mass
# vo

# debug?
debug=
samp=
samphub=
if [ "$1" = "debug" ]; then
    debug=$1
    samp=samp
    samphub=samphub
    shift
fi

# proc
msg=call
case $1 in
    notify | notifyAll | call | callAll | callAndWait)
    msg=$1
    shift
    ;;
esac

# consecutive timeout count, shared across samp.tcl runs
SAMP_STREAK_FILE=foo.streak
export SAMP_STREAK_FILE
rm -f $SAMP_STREAK_FILE

startit

#doit "$1" 2mass
doit "$1" 3d
doit "$1" about
doit "$1" align
doit "$1" analysis
doit "$1" array
#doit "$1" asdf
# backward compatibility prefs
doit "$1" bg
doit "$1" bookmark
doit "$1" bin
doit "$1" blink
doit "$1" block
doit "$1" catalog
doit "$1" cd
doit "$1" cmap
doit "$1" colorbar
#doit "$1" console
doit "$1" contour
doit "$1" crop
doit "$1" crosshair
doit "$1" cube
doit "$1" cursor
doit "$1" data
#~ doit "$1" dsssao
doit "$1" dsseso
doit "$1" dssstsci
doit "$1" export
doit "$1" fade
# backward compatibility
doit "$1" file
doit "$1" fits
doit "$1" footprint
doit "$1" frame
doit "$1" gif
doit "$1" graph
doit "$1" grid
doit "$1" header
doit "$1" height
doit "$1" hls
doit "$1" hlsarray
doit "$1" hlsimage
doit "$1" hlscube
doit "$1" hsv
doit "$1" hsvarray
doit "$1" hsvimage
doit "$1" hsvcube
doit "$1" iconify
doit "$1" iis
doit "$1" illustrate
# interactive
#doit "$1" iexam
doit "$1" jpeg
doit "$1" lock
doit "$1" lower
doit "$1" magnifier
doit "$1" mask
doit "$1" match
doit "$1" mecube
doit "$1" minmax
doit "$1" mode
doit "$1" mosaic
doit "$1" mosaicimage
# backward compatibility
doit "$1" mosaicwcs
# backward compatibility
doit "$1" mosaiciraf
# backward compatibility
doit "$1" mosaicimagewcs
# backward compatibility
doit "$1" mosaicimageiraf
# backward compatibility
doit "$1" mosaicimagewfpc2
doit "$1" movie
doit "$1" multiframe
doit "$1" multicolor
doit "$1" nameserver
# backward compatibility prefs
doit "$1" nan
doit "$1" notes
doit "$1" nrrd
#doit "$1" nvss
doit "$1" orient
doit "$1" pagesetup
doit "$1" pan
doit "$1" pixeltable
doit "$1" plot
doit "$1" png
# backward compatibility prefs
doit "$1" precision
doit "$1" prefs
doit "$1" preserve
doit "$1" print
doit "$1" prism
doit "$1" raise
doit "$1" regions
doit "$1" reveal
doit "$1" rgb
doit "$1" rgbarray
doit "$1" rgbimage
doit "$1" rgbcube
doit "$1" rotate
doit "$1" samp
doit "$1" save
doit "$1" saveimage
doit "$1" scale
doit "$1" single
# no tests
#doit "$1" shm
doit "$1" sia
doit "$1" skyview
doit "$1" sleep
doit "$1" smooth
doit "$1" source
doit "$1" tcl
# backward compatibility prefs
doit "$1" theme
# backward compatibility prefs
doit "$1" threads
doit "$1" tiff
doit "$1" tile
doit "$1" update
doit "$1" url
doit "$1" version
doit "$1" view
#doit "$1" vla
doit "$1" vlss
#doit "$1" vo
doit "$1" wcs
doit "$1" web
doit "$1" width
doit "$1" xpa
doit "$1" zscale
doit "$1" zoom

# do this last
doit "$1" backup
doit "$1" exit

rm -rf foo.*

if [ -n "$failed" ]; then
    echo
    echo "Timeouts in:$failed"
    exit 1
fi
