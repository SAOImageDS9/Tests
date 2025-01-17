testit () {
    read
    echo -n "  numerics no"
    xpaset -p ds9 colorbar numerics no
    read
    echo -n "  numerics yes"
    xpaset -p ds9 colorbar numerics yes
    read
    echo -n "  fontsize 36"
    xpaset -p ds9 colorbar fontsize 36
    read
    echo -n "  fontsize 9"
    xpaset -p ds9 colorbar fontsize 9
    read
    echo -n "  row"
    xpaset -p ds9 tile row
    read
    echo -n "  column"
    xpaset -p ds9 tile column
    read
    echo -n "  grid"
    xpaset -p ds9 tile grid
    read
    echo "...done"
    xpaset -p ds9 exit
}

echo "Starting..."

tt="none"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
ds9 -view multi no fits/img.fits fits/img.fits fits/img.fits fits/img.fits -view colorbar no&
testit
fi

tt="cbh"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
ds9 -view multi no fits/img.fits fits/img.fits fits/img.fits fits/img.fits&
testit
fi

tt="cbv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
ds9 -view multi no fits/img.fits fits/img.fits fits/img.fits fits/img.fits -colorbar vertical&
testit
fi

tt="cbhgrh"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
ds9 -view multi no fits/img.fits fits/img.fits fits/img.fits fits/img.fits -view graph horizontal yes&
testit
fi

tt="cbhgrv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
ds9 -view multi no fits/img.fits fits/img.fits fits/img.fits fits/img.fits -view graph vertical yes&
testit
fi

tt="cbhgrhgrv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
ds9 -view multi no fits/img.fits fits/img.fits fits/img.fits fits/img.fits -view graph horizontal yes -view graph vertical yes&
testit
fi

tt="cbvgrh"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
ds9 -view multi no fits/img.fits fits/img.fits fits/img.fits fits/img.fits -colorbar vertical -view graph horizontal yes&
testit
fi

tt="cbvgrv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
ds9 -view multi no fits/img.fits fits/img.fits fits/img.fits fits/img.fits -colorbar vertical  -view graph vertical yes&
testit
fi

tt="cbvgrhgrv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
ds9 -view multi no fits/img.fits fits/img.fits fits/img.fits fits/img.fits -colorbar vertical -view graph horizontal yes -view graph vertical yes&
testit
fi

tt="grh"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
ds9 -view multi no fits/img.fits fits/img.fits fits/img.fits fits/img.fits -view colorbar no -view graph horizontal yes&
testit
fi

tt="grv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
ds9 -view multi no fits/img.fits fits/img.fits fits/img.fits fits/img.fits -view colorbar no -view graph vertical yes&
testit
fi

tt="grhgrv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
ds9 -view multi no fits/img.fits fits/img.fits fits/img.fits fits/img.fits -view colorbar no -view graph horizontal yes -view graph vertical yes&
testit
fi


