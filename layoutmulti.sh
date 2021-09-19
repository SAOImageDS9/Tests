org='~/Downloads/ds9.darwinbigsurarm64.8.3b1/ds9'

testit () {
    read
    echo -n "  numerics no"
    xpaset -p bar colorbar numerics no
    read
    echo -n "  numerics yes"
    xpaset -p bar colorbar numerics yes
    read
    echo -n "  fontsize 36"
    xpaset -p bar colorbar fontsize 36
    read
    echo -n "  fontsize 9"
    xpaset -p bar colorbar fontsize 9
    read
    echo -n "  row"
    xpaset -p bar tile row
    read
    echo -n "  column"
    xpaset -p bar tile column
    read
    echo -n "  grid"
    xpaset -p bar tile grid
    read
    echo "...done"
    xpaset -p bar exit
}

echo "Starting..."

tt="none"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
ds9 -title bar fits/img.fits fits/img.fits fits/img.fits fits/img.fits -view colorbar no&
testit
fi

tt="cbh"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
ds9 -title bar fits/img.fits fits/img.fits fits/img.fits fits/img.fits&
testit
fi

tt="cbv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
ds9 -title bar fits/img.fits fits/img.fits fits/img.fits fits/img.fits -colorbar vertical&
testit
fi

tt="cbhgrh"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
ds9 -title bar fits/img.fits fits/img.fits fits/img.fits fits/img.fits -view graph horizontal yes&
testit
fi

tt="cbhgrv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
ds9 -title bar fits/img.fits fits/img.fits fits/img.fits fits/img.fits -view graph vertical yes&
testit
fi

tt="cbhgrhgrv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
ds9 -title bar fits/img.fits fits/img.fits fits/img.fits fits/img.fits -view graph horizontal yes -view graph vertical yes&
testit
fi

tt="cbvgrh"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
ds9 -title bar fits/img.fits fits/img.fits fits/img.fits fits/img.fits -colorbar vertical -view graph horizontal yes&
testit
fi

tt="cbvgrv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
ds9 -title bar fits/img.fits fits/img.fits fits/img.fits fits/img.fits -colorbar vertical  -view graph vertical yes&
testit
fi

tt="cbvgrhgrv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
ds9 -title bar fits/img.fits fits/img.fits fits/img.fits fits/img.fits -colorbar vertical -view graph horizontal yes -view graph vertical yes&
testit
fi

tt="grh"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
ds9 -title bar fits/img.fits fits/img.fits fits/img.fits fits/img.fits -view colorbar no -view graph horizontal yes&
testit
fi

tt="grv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
ds9 -title bar fits/img.fits fits/img.fits fits/img.fits fits/img.fits -view colorbar no -view graph vertical yes&
testit
fi

tt="grhgrv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
ds9 -title bar fits/img.fits fits/img.fits fits/img.fits fits/img.fits -view colorbar no -view graph horizontal yes -view graph vertical yes&
testit
fi

