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

echo " -mosaic"
ds9 -title DS9Test -mosaic mosaic/mosaicimage.fits &
KillIt
echo " -mosaic wcs"
ds9 -title DS9Test -mosaic wcs mosaic/mosaicimage.fits &
KillIt
echo " -mosaicwcs"
ds9 -title DS9Test -mosaicwcs mosaic/mosaicimage.fits &
KillIt
echo " -mosaic iraf"
ds9 -title DS9Test -mosaic iraf mosaic/mosaicimage.fits &
KillIt
echo " -mosaiciraf"
ds9 -title DS9Test -mosaiciraf mosaic/mosaicimage.fits &
KillIt

echo "PASSED"
fi

# Stdin
if [ "$1" = "stdin" -o  -z "$1" ]; then
echo "Testing Stdin File"

echo " -mosaic"
cat mosaic/mosaicimage.fits | timeout 10s ds9 -title DS9Test -mosaic -&
KillIt
echo " -mosaic wcs"
cat mosaic/mosaicimage.fits | timeout 10s ds9 -title DS9Test -mosaic wcs -&
KillIt
echo " -mosaicwcs"
cat mosaic/mosaicimage.fits | timeout 10s ds9 -title DS9Test -mosaicwcs -&
KillIt
echo " -mosaic iraf"
cat mosaic/mosaicimage.fits | timeout 10s ds9 -title DS9Test -mosaic iraf -&
KillIt
echo " -mosaiciraf"
cat mosaic/mosaicimage.fits | timeout 10s ds9 -title DS9Test -mosaiciraf -&
KillIt

echo "PASSED"
fi

# Save
if [ "$1" = "save" -o -z "$1" ]; then
echo "Testing Command Save"

echo " -mosaic"
opt=""
opt="$opt -save mosaic foo.fits -sleep .1"
opt="$opt -frame new -mosaic foo.fits"
if [ $slow = "1" ]; then
    opt="$opt -sleep 1"
fi
opt="$opt -frame delete -sleep .1"
eval ds9 -title DS9Test -tile -mosaic mosaic/mosaicimage.fits "$opt" -exit

echo " -mosaic wcs"
opt=""
opt="$opt -save mosaic wcs foo.fits -sleep .1"
opt="$opt -frame new -mosaic wcs foo.fits"
if [ $slow = "1" ]; then
    opt="$opt -sleep 1"
fi
opt="$opt -frame delete -sleep .1"
eval ds9 -title DS9Test -tile -mosaic wcs mosaic/mosaicimage.fits "$opt" -exit

echo " -mosaicwcs"
opt=""
opt="$opt -save mosaicwcs foo.fits -sleep .1"
opt="$opt -frame new -mosaicwcs foo.fits"
if [ $slow = "1" ]; then
    opt="$opt -sleep 1"
fi
opt="$opt -frame delete -sleep .1"
eval ds9 -title DS9Test -tile -mosaicwcs mosaic/mosaicimage.fits "$opt" -exit

echo "PASSED"
fi

# XPA
if [ "$1" = "xpa" -o  -z "$1" ]; then
echo "Testing XPA File"

StartDS9

echo " -mosaic"
xpaset -p DS9Test mosaic mosaic/mosaicimage.fits
if [ $slow = "1" ]; then
    sleep 1
fi
xpaset -p DS9Test frame clear

echo " -mosaic wcs"
xpaset -p DS9Test mosaic wcs mosaic/mosaicimage.fits
if [ $slow = "1" ]; then
    sleep 1
fi
xpaset -p DS9Test frame clear

echo " -mosaicwcs"
xpaset -p DS9Test mosaicwcs mosaic/mosaicimage.fits
if [ $slow = "1" ]; then
    sleep 1
fi
xpaset -p DS9Test frame clear

echo " -mosaic iraf"
xpaset -p DS9Test mosaic iraf mosaic/mosaicimage.fits
if [ $slow = "1" ]; then
    sleep 1
fi
xpaset -p DS9Test frame clear

echo " -mosaiciraf"
xpaset -p DS9Test mosaiciraf mosaic/mosaicimage.fits
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

echo " -mosaic"
cat mosaic/mosaicimage.fits | xpaset DS9Test mosaic
if [ $slow = "1" ]; then
    sleep 1
fi
xpaset -p DS9Test frame clear

echo " -mosaic wcs"
cat mosaic/mosaicimage.fits | xpaset DS9Test mosaic wcs
if [ $slow = "1" ]; then
    sleep 1
fi
xpaset -p DS9Test frame clear

echo " -mosaicwcs"
cat mosaic/mosaicimage.fits | xpaset DS9Test mosaicwcs
if [ $slow = "1" ]; then
    sleep 1
fi
xpaset -p DS9Test frame clear

echo " -mosaic iraf"
cat mosaic/mosaicimage.fits | xpaset DS9Test mosaic iraf
if [ $slow = "1" ]; then
    sleep 1
fi
xpaset -p DS9Test frame clear

echo " -mosaiciraf"
cat mosaic/mosaicimage.fits | xpaset DS9Test mosaiciraf
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

echo " -mosaic"
xpaset -p DS9Test tile
xpaset -p DS9Test mosaic mosaic/mosaicimage.fits
xpaget DS9Test mosaic > foo.fits
xpaset -p DS9Test frame new
xpaset -p DS9Test mosaic foo.fits
if [ $slow = "1" ]; then
    sleep 1
fi
xpaset -p DS9Test frame delete
xpaset -p DS9Test frame clear

echo " -mosaic wcs"
xpaset -p DS9Test tile
xpaset -p DS9Test mosaic wcs mosaic/mosaicimage.fits
xpaget DS9Test mosaic wcs > foo.fits
xpaset -p DS9Test frame new
xpaset -p DS9Test mosaic wcs foo.fits
if [ $slow = "1" ]; then
    sleep 1
fi
xpaset -p DS9Test frame delete
xpaset -p DS9Test frame clear

echo " -mosaicwcs"
xpaset -p DS9Test tile
xpaset -p DS9Test mosaicwcs mosaic/mosaicimage.fits
xpaget DS9Test mosaicwcs > foo.fits
xpaset -p DS9Test frame new
xpaset -p DS9Test mosaicwcs foo.fits
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
