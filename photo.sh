KillIt () {
    i=1
    while [ "$i" -le 10 ]; do
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

DoXPA () {
    echo "$1"
    xpaset -p DS9Test $2 $3
    if [ $slow = "1" ]; then
	sleep 1
    fi
    xpaset -p DS9Test frame clear
}

DoXPAStdin () {
    echo "$1"
    cat $3 | xpaset DS9Test $2
    if [ $slow = "1" ]; then
	sleep 1
    fi
    xpaset -p DS9Test frame clear
}

DoXPAStdout () {
    echo "..  $2"
    xpaset -p DS9Test tile
    xpaget DS9Test $2 > foo.$2
    xpaset -p DS9Test frame new $1
    xpaset -p DS9Test $2 foo.$2
    if [ $slow = "1" ]; then
	sleep 1
    fi
    xpaset -p DS9Test frame delete
}

initit () {
    echo "Testing $1"
    unset opt
}

testit () {
    echo "$2"
    opt="$opt -export $2 foo.$2 $3 -sleep .1"
    opt="$opt -frame new $1 foo.$2"
    if [ $slow = "1" ]; then
	opt="$opt -sleep 1"
    fi
    opt="$opt -frame delete -sleep .1"
}

doit () {
    eval ds9 -title DS9Test -tile $1 -tiff photo/rose.tiff "$opt" -exit
    echo "PASSED"
}

# AVM: the ICRS position of image pixels in photo/avm*, as printed by
# photo/mkavm.py
AVMPixels="1 1 202.5603792 47.2078485
227 149 202.4015576 47.2139330
114 75 202.4809730 47.2109182"

# AVMCheck name: the current frame has the AVM WCS
AVMCheck () {
    echo "$AVMPixels" | while read x y ra dec; do
	xpaset -p DS9Test pan to $x $y image
	rr=`xpaget DS9Test pan wcs icrs degrees`
	if echo "$rr $ra $dec" | awk '{d=($1-$3)*cos($4*3.14159265/180); e=$2-$4; exit !(NF==4 && d*d+e*e < 1e-12)}'; then
	    :
	else
	    echo "FAILED: $1: pixel $x $y is '$rr', expected '$ra $dec'"
	    echo "$1" >> avm.failed
	fi
    done
}

# AVMCheckNone name: the current frame has no WCS
AVMCheckNone () {
    xpaset -p DS9Test pan to 114 75 image
    rr=`xpaget DS9Test pan wcs icrs degrees`
    if [ -n "$rr" ]; then
	echo "FAILED: $1: expected no WCS, got '$rr'"
	echo "$1" >> avm.failed
    fi
}

# wait for a ds9 started in the background to register
WaitDS9 () {
    i=1
    while [ "$i" -le 20 ]; do
	sleep 1
	if [ `xpaaccess DS9Test` = yes ]; then
	    break
	fi
	i=`expr $i + 1`
    done
}

# quit ds9 and wait for it to go away
QuitDS9 () {
    xpaset -p DS9Test quit
    i=1
    while [ "$i" -le 20 ]; do
	if [ `xpaaccess DS9Test` = no ]; then
	    break
	fi
	sleep 1
	i=`expr $i + 1`
    done
}

# AVMLoad name type file [frametype]: load into a new frame
AVMLoad () {
    echo "..  $1"
    xpaset -p DS9Test frame delete all
    xpaset -p DS9Test frame new $4
    xpaset -p DS9Test $2 $3
}

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

# slow down?
slow=0
if [ "$1" = "slow" ]; then
    slow=1
    shift
fi

echo
echo "*** photo.sh ***"

# Command Line

if [ "$1" = "command" -o  -z "$1" ]; then
echo "Testing Command Line File"

echo ".. base"
echo "..  gif"
ds9 -title DS9Test -gif photo/rose.gif &
KillIt
echo "..  tiff"
ds9 -title DS9Test -tiff photo/rose.tiff &
KillIt
echo "..  jpeg"
ds9 -title DS9Test -jpeg photo/rose.jpeg &
KillIt
echo "..  png"
ds9 -title DS9Test -png photo/rose.png &
KillIt
echo ".. # backward compatibility"
echo "..  -photo"
ds9 -title DS9Test -photo photo/rose.tiff &
KillIt

echo ".. rgb"
echo "..  gif"
ds9 -title DS9Test -rgb -gif photo/rose.gif &
KillIt
echo "..  tiff"
ds9 -title DS9Test -rgb -tiff photo/rose.tiff &
KillIt
echo "..  jpeg"
ds9 -title DS9Test -rgb -jpeg photo/rose.jpeg &
KillIt
echo "..  png"
ds9 -title DS9Test -rgb -png photo/rose.png &
KillIt
echo ".. # backward compatibility"
echo "..  -photo"
ds9 -title DS9Test -rgb -photo photo/rose.tiff &
KillIt

echo ".. 3d"
echo "..  gif"
ds9 -title DS9Test -3d -gif photo/rose.gif &
KillIt
echo "..  tiff"
ds9 -title DS9Test -3d -tiff photo/rose.tiff &
KillIt
echo "..  jpeg"
ds9 -title DS9Test -3d -jpeg photo/rose.jpeg &
KillIt
echo "..  png"
ds9 -title DS9Test -3d -png photo/rose.png &
KillIt
echo ".. # backward compatibility"
echo "..  -photo"
ds9 -title DS9Test -3d -photo photo/rose.tiff &
KillIt

echo "PASSED"
fi

# Stdin

if [ "$1" = "stdin" -o  -z "$1" ]; then
echo "Testing Command Stdin"

echo ".. base"
echo "..  gif"
cat photo/rose.gif | ds9 -title DS9Test -gif - &
KillIt
echo "..  tiff"
cat photo/rose.tiff | ds9 -title DS9Test -tiff - &
KillIt
echo "..  jpeg"
cat photo/rose.jpeg | ds9 -title DS9Test -jpeg - &
KillIt
echo "..  png"
cat photo/rose.png | ds9 -title DS9Test -png - &
KillIt

echo ".. rgb"
echo "..  gif"
cat photo/rose.gif | ds9 -title DS9Test -rgb -gif - &
KillIt
echo "..  tiff"
cat photo/rose.tiff | ds9 -title DS9Test -rgb -tiff - &
KillIt
echo "..  jpeg"
cat photo/rose.jpeg | ds9 -title DS9Test -rgb -jpeg - &
KillIt
echo "..  png"
cat photo/rose.png | ds9 -title DS9Test -rgb -png - &
KillIt

echo ".. 3d"
echo "..  gif"
cat photo/rose.gif | ds9 -title DS9Test -3d -gif - &
KillIt
echo "..  tiff"
cat photo/rose.tiff | ds9 -title DS9Test -3d -tiff - &
KillIt
echo "..  jpeg"
cat photo/rose.jpeg | ds9 -title DS9Test -3d -jpeg - &
KillIt
echo "..  png"
cat photo/rose.png | ds9 -title DS9Test -3d -png - &
KillIt

echo "PASSED"
fi

# export

if [ "$1" = "export" -o -z "$1" ]; then
echo "Testing Command export"

initit ".. base"
testit "" gif
testit "" tiff
testit "" tiff none
testit "" jpeg
testit "" jpeg 100
testit "" png
doit ""

initit ".. rgb"
#testit rgb gif
testit rgb tiff
testit rgb tiff none
testit rgb jpeg
testit rgb jpeg 100
testit rgb png
doit "-frame delete -rgb"

fi

# XPA File
if [ "$1" = "xpa" -o  -z "$1" ]; then
echo "Testing XPA File"

StartDS9

echo ".. base"
DoXPA "..  gif" gif photo/rose.gif
DoXPA "..  jpeg" jpeg photo/rose.jpeg
DoXPA "..  tiff" tiff photo/rose.tiff
DoXPA "..  png" png photo/rose.png

echo ".. rgb"
xpaset -p DS9Test rgb
DoXPA "..  gif" gif photo/rose.gif
DoXPA "..  jpeg" jpeg photo/rose.jpeg
DoXPA "..  tiff" tiff photo/rose.tiff
DoXPA "..  png" png photo/rose.png

echo ".. 3d"
xpaset -p DS9Test 3d
DoXPA "..  gif" gif photo/rose.gif
DoXPA "..  jpeg" jpeg photo/rose.jpeg
DoXPA "..  tiff" tiff photo/rose.tiff
DoXPA "..  png" png photo/rose.png

xpaset -p DS9Test quit
echo "PASSED"
fi

# XPA stdin
if [ "$1" = "xpastdin" -o  -z "$1" ]; then
echo "Testing XPA Stdin"

StartDS9

echo ".. base"
DoXPAStdin "..  gif" gif photo/rose.gif
DoXPAStdin "..  jpeg" jpeg photo/rose.jpeg
DoXPAStdin "..  tiff" tiff photo/rose.tiff
DoXPAStdin "..  png" png photo/rose.png

echo ".. rgb"
xpaset -p DS9Test rgb
DoXPAStdin "..  gif" gif photo/rose.gif
DoXPAStdin "..  jpeg" jpeg photo/rose.jpeg
DoXPAStdin "..  tiff" tiff photo/rose.tiff
DoXPAStdin "..  png" png photo/rose.png

echo ".. 3d"
xpaset -p DS9Test 3d
DoXPAStdin "..  gif" gif photo/rose.gif
DoXPAStdin "..  jpeg" jpeg photo/rose.jpeg
DoXPAStdin "..  tiff" tiff photo/rose.tiff
DoXPAStdin "..  png" png photo/rose.png

xpaset -p DS9Test quit
echo "PASSED"
fi

# XPA stdout
if [ "$1" = "xpastdout" -o  -z "$1" ]; then
echo "Testing XPA Stdout"

StartDS9

echo ".. base"
xpaset -p DS9Test tiff photo/rose.tiff
DoXPAStdout "" gif
DoXPAStdout "" jpeg
DoXPAStdout "" tiff
DoXPAStdout "" png

echo ".. rgb"
xpaset -p DS9Test frame delete
xpaset -p DS9Test rgb
xpaset -p DS9Test tiff photo/rose.tiff
# not enough colors
#DoXPAStdout rgb gif
DoXPAStdout rgb jpeg
DoXPAStdout rgb tiff
DoXPAStdout rgb png

xpaset -p DS9Test quit
echo "PASSED"
fi

# AVM: WCS from Astronomy Visualization Metadata
if [ "$1" = "avm" -o  -z "$1" ]; then
echo "Testing AVM"
rm -f avm.failed

StartDS9

echo ".. formats"
AVMLoad "png" png photo/avm.png;            AVMCheck "png"
AVMLoad "png compressed" png photo/avmz.png; AVMCheck "png compressed"
AVMLoad "jpeg" jpeg photo/avm.jpeg;         AVMCheck "jpeg"
AVMLoad "jpeg extendedxmp" jpeg photo/avmext.jpeg; AVMCheck "jpeg extendedxmp"
AVMLoad "tiff" tiff photo/avm.tiff;         AVMCheck "tiff"
AVMLoad "gif" gif photo/avm.gif;            AVMCheck "gif"

echo ".. no wcs"
AVMLoad "no avm" png photo/rose.png;            AVMCheckNone "no avm"
AVMLoad "quality position" png photo/avmpos.png; AVMCheckNone "quality position"
AVMLoad "cropped" png photo/avmcrop.png;        AVMCheckNone "cropped"

echo ".. stdin"
xpaset -p DS9Test frame delete all
xpaset -p DS9Test frame new
cat photo/avm.png | xpaset DS9Test png
AVMCheck "stdin"

echo ".. rgb"
AVMLoad "rgb" png photo/avm.png rgb
for cc in red green blue; do
    xpaset -p DS9Test rgb channel $cc
    AVMCheck "rgb $cc"
done

echo ".. 3d"
AVMLoad "3d" png photo/avm.png 3d
AVMCheck "3d"

echo ".. header"
AVMLoad "header" png photo/avm.png
xpaset -p DS9Test header
xpaset -p DS9Test header close

QuitDS9

echo ".. command line"
echo "..  -png"
ds9 -title DS9Test -png photo/avm.png &
WaitDS9
AVMCheck "command line"
QuitDS9

if [ -f avm.failed ]; then
    echo "FAILED"
else
    echo "PASSED"
fi
rm -f avm.failed
fi

rm -f foo.*
echo "DONE"
