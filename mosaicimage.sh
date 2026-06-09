KillIt () {
    i=1
    while [ "$i" -le 15 ]; do
      sleep 1
      if [ `xpaaccess DS9Test` = yes ]; then
	  if [ $slow = "1" ]; then
	      sleep 1
	  fi
	  xpaset -p DS9Test quit
	  break
      fi

      i=`expr $i + 1`
    done
}

StartDS9 () {
    if [ `xpaaccess DS9Test` = no ]; then
	ds9 -title DS9Test &

	i=1
	while [ "$i" -le 30 ]
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

# slow down?
slow=0
if [ "$1" = "slow" ]; then
    slow=1
    shift
fi

echo
echo "*** Mosaic Image ***"

# Command Line
if [ "$1" = "command" -o  -z "$1" ]; then
echo "Testing Command Line File"

echo " -mosaicimage"
ds9 -title DS9Test -mosaicimage mosaic/mosaicimage.fits &
KillIt
echo " -mosaicimage wcs"
ds9 -title DS9Test -mosaicimage wcs mosaic/mosaicimage.fits &
KillIt
echo " -mosaicimagewcs"
ds9 -title DS9Test -mosaicimagewcs mosaic/mosaicimage.fits &
KillIt
echo " -mosaicimage iraf"
ds9 -title DS9Test -mosaicimage iraf mosaic/mosaicimage.fits &
KillIt
echo " -mosaicimageiraf"
ds9 -title DS9Test -mosaicimageiraf mosaic/mosaicimage.fits &
KillIt
echo " -mosaicimage wfpc2"
ds9 -title DS9Test -mosaicimage wfpc2 mosaic/hst.fits &
KillIt
echo " -mosaicimagewfpc2"
ds9 -title DS9Test -mosaicimagewfpc2 mosaic/hst.fits &
KillIt

echo "PASSED"
fi

# Stdin
if [ "$1" = "stdin" -o  -z "$1" ]; then
echo "Testing Stdin File"

echo " -mosaicimage"
cat mosaic/mosaicimage.fits | timeout 10s ds9 -title DS9Test -mosaicimage -&
KillIt
echo " -mosaicimage wcs"
cat mosaic/mosaicimage.fits | timeout 10s ds9 -title DS9Test -mosaicimage wcs -&
KillIt
echo " -mosaicimagewcs"
cat mosaic/mosaicimage.fits | timeout 10s ds9 -title DS9Test -mosaicimagewcs -&
KillIt
echo " -mosaicimage iraf"
cat mosaic/mosaicimage.fits | timeout 10s ds9 -title DS9Test -mosaicimage iraf -&
KillIt
echo " -mosaicimageiraf"
cat mosaic/mosaicimage.fits | timeout 10s ds9 -title DS9Test -mosaicimageiraf -&
KillIt
echo " -mosaicimage wfpc2"
cat mosaic/hst.fits | timeout 10s ds9 -title DS9Test -mosaicimage wfpc2 -&
KillIt
echo " -mosaicimagewfpc2"
cat mosaic/hst.fits | timeout 10s ds9 -title DS9Test -mosaicimagewfpc2 -&
KillIt

echo "PASSED"
fi

# Save
if [ "$1" = "save" -o -z "$1" ]; then
echo "Testing Command Save"

echo " -mosaicimage"
opt=""
opt="$opt -save mosaicimage foo.fits -sleep .1"
opt="$opt -frame new -mosaicimage foo.fits"
if [ $slow = "1" ]; then
    opt="$opt -sleep 1"
fi
opt="$opt -frame delete -sleep .1"
eval ds9 -title DS9Test -tile -mosaicimage mosaic/mosaicimage.fits "$opt" -exit

echo " -mosaicimage wcs"
opt=""
opt="$opt -save mosaicimage wcs foo.fits -sleep .1"
opt="$opt -frame new -mosaicimage wcs foo.fits"
if [ $slow = "1" ]; then
    opt="$opt -sleep 1"
fi
opt="$opt -frame delete -sleep .1"
eval ds9 -title DS9Test -tile -mosaicimage wcs mosaic/mosaicimage.fits "$opt" -exit

echo " -mosaicimagewcs"
opt=""
opt="$opt -save mosaicimagewcs foo.fits -sleep .1"
opt="$opt -frame new -mosaicimagewcs foo.fits"
if [ $slow = "1" ]; then
    opt="$opt -sleep 1"
fi
opt="$opt -frame delete -sleep .1"
eval ds9 -title DS9Test -tile -mosaicimagewcs mosaic/mosaicimage.fits "$opt" -exit

echo "PASSED"
fi

# XPA
if [ "$1" = "xpa" -o  -z "$1" ]; then
echo "Testing XPA File"

StartDS9

echo " -mosaicimage"
xpaset -p DS9Test mosaicimage mosaic/mosaicimage.fits
if [ $slow = "1" ]; then
    sleep 1
fi
xpaset -p DS9Test frame clear

echo " -mosaicimage wcs"
xpaset -p DS9Test mosaicimage wcs mosaic/mosaicimage.fits
if [ $slow = "1" ]; then
    sleep 1
fi
xpaset -p DS9Test frame clear

echo " -mosaicimagewcs"
xpaset -p DS9Test mosaicimagewcs mosaic/mosaicimage.fits
if [ $slow = "1" ]; then
    sleep 1
fi
xpaset -p DS9Test frame clear

echo " -mosaicimage iraf"
xpaset -p DS9Test mosaicimage iraf mosaic/mosaicimage.fits
if [ $slow = "1" ]; then
    sleep 1
fi
xpaset -p DS9Test frame clear

echo " -mosaicimageiraf"
xpaset -p DS9Test mosaicimageiraf mosaic/mosaicimage.fits
if [ $slow = "1" ]; then
    sleep 1
fi
xpaset -p DS9Test frame clear

echo " -mosaicimage wfpc2"
xpaset -p DS9Test mosaicimage wfpc2 mosaic/hst.fits
if [ $slow = "1" ]; then
    sleep 1
fi
xpaset -p DS9Test frame clear

echo " -mosaicimagewfpc2"
xpaset -p DS9Test mosaicimagewfpc2 mosaic/hst.fits
if [ $slow = "1" ]; then
    sleep 1
fi
xpaset -p DS9Test frame clear

xpaset -p DS9Test quit
echo "PASSED"
fi

# XPA stdin
if [ "$1" = "xpastdin" -o  -z "$1" ]; then
echo "Testing XPA Stdin"

StartDS9

echo " -mosaicimage"
cat mosaic/mosaicimage.fits | xpaset DS9Test mosaicimage
if [ $slow = "1" ]; then
    sleep 1
fi
xpaset -p DS9Test frame clear

echo " -mosaicimage wcs"
cat mosaic/mosaicimage.fits | xpaset DS9Test mosaicimage wcs
if [ $slow = "1" ]; then
    sleep 1
fi
xpaset -p DS9Test frame clear

echo " -mosaicimagewcs"
cat mosaic/mosaicimage.fits | xpaset DS9Test mosaicimagewcs
if [ $slow = "1" ]; then
    sleep 1
fi
xpaset -p DS9Test frame clear

echo " -mosaicimage iraf"
cat mosaic/mosaicimage.fits | xpaset DS9Test mosaicimage iraf
if [ $slow = "1" ]; then
    sleep 1
fi
xpaset -p DS9Test frame clear

echo " -mosaicimageiraf"
cat mosaic/mosaicimage.fits | xpaset DS9Test mosaicimageiraf
if [ $slow = "1" ]; then
    sleep 1
fi
xpaset -p DS9Test frame clear

echo " -mosaicimage wfpc2"
cat mosaic/hst.fits | xpaset DS9Test mosaicimage wfpc2
if [ $slow = "1" ]; then
    sleep 1
fi
xpaset -p DS9Test frame clear

echo " -mosaicimagewfpc2"
cat mosaic/hst.fits | xpaset DS9Test mosaicimagewfpc2
if [ $slow = "1" ]; then
    sleep 1
fi
xpaset -p DS9Test frame clear

xpaset -p DS9Test quit
echo "PASSED"
fi

# XPA stdout
if [ "$1" = "xpastdout" -o  -z "$1" ]; then
echo "Testing XPA Stdout"

StartDS9

echo " -mosaicimage"
xpaset -p DS9Test tile
xpaset -p DS9Test mosaicimage mosaic/mosaicimage.fits
xpaget DS9Test mosaicimage > foo.fits
xpaset -p DS9Test frame new
xpaset -p DS9Test mosaicimage foo.fits
if [ $slow = "1" ]; then
    sleep 1
fi
xpaset -p DS9Test frame delete
xpaset -p DS9Test frame clear

echo " -mosaicimage wcs"
xpaset -p DS9Test tile
xpaset -p DS9Test mosaicimage wcs mosaic/mosaicimage.fits
xpaget DS9Test mosaicimage wcs > foo.fits
xpaset -p DS9Test frame new
xpaset -p DS9Test mosaicimage wcs foo.fits
if [ $slow = "1" ]; then
    sleep 1
fi
xpaset -p DS9Test frame delete
xpaset -p DS9Test frame clear

echo " -mosaicimagewcs"
xpaset -p DS9Test tile
xpaset -p DS9Test mosaicimagewcs mosaic/mosaicimage.fits
xpaget DS9Test mosaicimagewcs > foo.fits
xpaset -p DS9Test frame new
xpaset -p DS9Test mosaicimagewcs foo.fits
if [ $slow = "1" ]; then
    sleep 1
fi
xpaset -p DS9Test frame delete
xpaset -p DS9Test frame clear

xpaset -p DS9Test quit
echo "PASSED"
fi

rm -f foo.*
echo "DONE"
