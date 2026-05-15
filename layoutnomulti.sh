testit () {
    if [ `xpaaccess DS9Test` = no ]; then
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
    read
    echo -n "  numerics no"
    xpaset -p DS9Test colorbar numerics no
    read
    echo -n "  numerics yes"
    xpaset -p DS9Test colorbar numerics yes
    read
    echo -n "  fontsize 36"
    xpaset -p DS9Test colorbar fontsize 36
    read
    echo -n "  fontsize 9"
    xpaset -p DS9Test colorbar fontsize 9
    read
    echo -n "  row"
    xpaset -p DS9Test tile row
    read
    echo -n "  column"
    xpaset -p DS9Test tile column
    read
    echo -n "  grid"
    xpaset -p DS9Test tile grid
    read
    echo "...done"
    xpaset -p DS9Test exit
}

echo "Starting..."

tt="none"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
ds9 -title DS9Test -view multi no fits/img.fits fits/img.fits fits/img.fits fits/img.fits -view colorbar no&
testit
fi

tt="cbh"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
ds9 -title DS9Test -view multi no fits/img.fits fits/img.fits fits/img.fits fits/img.fits&
testit
fi

tt="cbv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
ds9 -title DS9Test -view multi no fits/img.fits fits/img.fits fits/img.fits fits/img.fits -colorbar vertical&
testit
fi

tt="cbhgrh"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
ds9 -title DS9Test -view multi no fits/img.fits fits/img.fits fits/img.fits fits/img.fits -view graph horizontal yes&
testit
fi

tt="cbhgrv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
ds9 -title DS9Test -view multi no fits/img.fits fits/img.fits fits/img.fits fits/img.fits -view graph vertical yes&
testit
fi

tt="cbhgrhgrv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
ds9 -title DS9Test -view multi no fits/img.fits fits/img.fits fits/img.fits fits/img.fits -view graph horizontal yes -view graph vertical yes&
testit
fi

tt="cbvgrh"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
ds9 -title DS9Test -view multi no fits/img.fits fits/img.fits fits/img.fits fits/img.fits -colorbar vertical -view graph horizontal yes&
testit
fi

tt="cbvgrv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
ds9 -title DS9Test -view multi no fits/img.fits fits/img.fits fits/img.fits fits/img.fits -colorbar vertical  -view graph vertical yes&
testit
fi

tt="cbvgrhgrv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
ds9 -title DS9Test -view multi no fits/img.fits fits/img.fits fits/img.fits fits/img.fits -colorbar vertical -view graph horizontal yes -view graph vertical yes&
testit
fi

tt="grh"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
ds9 -title DS9Test -view multi no fits/img.fits fits/img.fits fits/img.fits fits/img.fits -view colorbar no -view graph horizontal yes&
testit
fi

tt="grv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
ds9 -title DS9Test -view multi no fits/img.fits fits/img.fits fits/img.fits fits/img.fits -view colorbar no -view graph vertical yes&
testit
fi

tt="grhgrv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
ds9 -title DS9Test -view multi no fits/img.fits fits/img.fits fits/img.fits fits/img.fits -view colorbar no -view graph horizontal yes -view graph vertical yes&
testit
fi


