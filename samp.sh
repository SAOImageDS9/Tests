
echo "SAMP Tests"

echo "Starting DS9..."
ds9 -debug -zscale fits/img.fits&
echo "click return to start"
read

testit () {
    echo $msg
    echo 
    echo "Testing $1"
    tclsh samp.tcl $debug block $msg < samp/${1}.samp
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

#2mass
#vo

# debug?
debug=
if [ "$1" = "debug" ]; then
    debug=$1
    shift
fi

# proc
msg=callAndWait
case $1 in
    notify | notifyAll | call | callAll | callAndWait)
    msg=$1
    shift
    ;;
esac

#doit "$1" 2mass
doit "$1" 3d
doit "$1" about
doit "$1" align
doit "$1" analysis
doit "$1" array
# backward compatibility prefs
doit "$1" bg
doit "$1" bin
doit "$1" blink
doit "$1" block
doit "$1" catalog
doit "$1" cd
doit "$1" cmap
doit "$1" colorbar
doit "$1" console
doit "$1" contour
doit "$1" crop
doit "$1" crosshair
doit "$1" cube
doit "$1" cursor
doit "$1" data
doit "$1" dsssao
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
doit "$1" nameserver
# backward compatibility prefs
doit "$1" nan
doit "$1" notes
doit "$1" nrrd
doit "$1" nvss
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
doit "$1" rgb
doit "$1" rgbarray
doit "$1" rgbcube
doit "$1" rgbimage
doit "$1" rotate
doit "$1" samp
doit "$1" save
doit "$1" saveimage
doit "$1" scale
# backward compatibility
doit "$1" sfits
doit "$1" single
# no tests
#doit "$1" shm
doit "$1" sia
doit "$1" skyview
doit "$1" sleep
# no tests
#doit "$1" smosaic
# no tests
#doit "$1" smosaicwcs
# no tests
#doit "$1" smosaiciraf
doit "$1" smooth
doit "$1" source
# backward compatibility
doit "$1" srgbcube
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
doit "$1" vla
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
