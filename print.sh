echo
echo "*** print.sh ***"

echo "Starting DS9..."
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

doit() {
    echo $1
    xpaset -p DS9Test psprint palette $2
    xpaset -p DS9Test psprint level $3
    xpaset -p DS9Test psprint filename ps/ds9-$4-$2-$3.ps
    xpaset -p DS9Test psprint
}

rm -rf ps
mkdir ps

xpaset -p DS9Test scale zscale
#xpaset -p DS9Test psprint command '{gv -}'
xpaset -p DS9Test psprint destination file
xpaset -p DS9Test grid

if [ "$1" = "single" -o  -z "$1" ]; then
echo "Testing Single"

xpaset -p DS9Test fits fits/img.fits
xpaset -p DS9Test regions load regions/ds9.fk5.hms.reg

doit "..RGB Level 3" rgb 3 b
doit "..CMYK Level 3" cmyk 3 b
doit "..Gray Level 3" gray 3 b

doit "..RGB Level 2" rgb 2 b
doit "..CMYK Level 2" cmyk 2 b
doit "..Gray Level 2" gray 2 b

doit "..RGB Level 1" rgb 1 b
doit "..Gray Level 1" gray 1 b

echo "PASSED"
fi

if [ "$1" = "mosaic" -o  -z "$1" ]; then
echo "Testing Mosaic"

xpaset -p DS9Test mosaicimage iraf mosaic/mosaicimage.fits
xpaset -p DS9Test regions load regions/ds9.mosaic.fk5.hms.reg

doit "..RGB Level 3" rgb 3 m
doit "..CMYK Level 3" cmyk 3 m
doit "..Gray Level 3" gray 3 m

doit "..RGB Level 2" rgb 2 m
doit "..CMYK Level 2" cmyk 2 m
doit "..Gray Level 2" gray 2 m

doit "..RGB Level 1" rgb 1 m
doit "..Gray Level 1" gray 1 m

echo "PASSED"
fi

if [ "$1" = "rgb" -o  -z "$1" ]; then
echo "Testing RGB"

xpaset -p DS9Test rgb
xpaset -p DS9Test rgbcube rgbcube/float.fits

doit "..RGB Level 3" rgb 3 r
doit "..CMYK Level 3" cmyk 3 r
doit "..Gray Level 3" gray 3 r

doit "..RGB Level 2" rgb 2 r
doit "..CMYK Level 2" cmyk 2 r
doit "..Gray Level 2" gray 2 r

doit "..RGB Level 1" rgb 1 r
doit "..Gray Level 1" gray 1 r

echo "PASSED"
fi

echo "DONE"

if [ -z "$1" ]; then
xpaset -p DS9Test quit
fi

