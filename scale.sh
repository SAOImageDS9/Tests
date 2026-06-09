testit () {
    echo "Testing $1..."
    xpaset -p DS9Test scale $1
    xpaset -p DS9Test contour scale $1
    xpaset -p DS9Test file $2
    xpaset -p DS9Test contour yes
    read
    xpaset -p DS9Test frame clear
}

echo
echo "*** scale.sh ***"

echo "Starting DS9..."
if [ `xpaaccess DS9Test` = no ]; then
    ds9 -title DS9Test &

    i=1
    while [ "$i" -le 10 ]
    do
        sleep 2
        if [ `xpaaccess DS9Test` = yes ]
        then
	    break
        fi

        i=`expr $i + 1`
    done
fi

echo "Setup..."
xpaset -p DS9Test cmap i8
xpaset -p DS9Test contour nlevels 9
xpaset -p DS9Test contour color black

testit linear scale/linear.fits
testit log scale/pow.fits
testit pow scale/log.fits
testit sqrt scale/squ.fits
testit squared scale/sqrt.fits
testit asinh scale/sinh.fits
testit sinh scale/asinh.fits

echo "Testing histequ..."
xpaset -p DS9Test scale histequ
xpaset -p DS9Test contour scale histequ
xpaset -p DS9Test fits scale/linear.fits
xpaset -p DS9Test contour generate
xpaset -p DS9Test contour yes
read
xpaset -p DS9Test fits scale/log.fits
xpaset -p DS9Test contour generate
xpaset -p DS9Test contour yes
read
xpaset -p DS9Test fits scale/pow.fits
xpaset -p DS9Test contour generate
xpaset -p DS9Test contour yes
read
xpaset -p DS9Test fits scale/sqrt.fits
xpaset -p DS9Test contour generate
xpaset -p DS9Test contour yes
read
xpaset -p DS9Test fits scale/squ.fits
xpaset -p DS9Test contour generate
xpaset -p DS9Test contour yes
read
xpaset -p DS9Test fits scale/asinh.fits
xpaset -p DS9Test contour generate
xpaset -p DS9Test contour yes
read
xpaset -p DS9Test fits scale/sinh.fits
xpaset -p DS9Test contour generate
xpaset -p DS9Test contour yes
read
xpaset -p DS9Test frame clear

xpaset -p DS9Test quit

