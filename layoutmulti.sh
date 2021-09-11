org='~/Downloads/ds9.darwinbigsurarm64.8.3b1/ds9'

echo "Starting..."

tt="multi"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
ds9 -title bar -tile fits/img.fits fits/img.fits fits/img.fits fits/img.fits -view colorbar no&
read
xpaset -p bar exit
fi

tt="multicbh"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
ds9 -title bar -tile fits/img.fits fits/img.fits fits/img.fits fits/img.fits&
read
xpaset -p bar exit
fi

tt="multicbv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
ds9 -title bar -tile fits/img.fits fits/img.fits fits/img.fits fits/img.fits -colorbar vertical&
read
xpaset -p bar exit
fi

tt="multigrh"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
ds9 -title bar -tile fits/img.fits fits/img.fits fits/img.fits fits/img.fits -view colorbar no -view graph horizontal yes&
read
xpaset -p bar exit
fi

tt="multigrv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
ds9 -title bar -tile fits/img.fits fits/img.fits fits/img.fits fits/img.fits -view colorbar no -view graph vertical yes&
read
xpaset -p bar exit
fi

tt="multigrhgrv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
ds9 -title bar -tile fits/img.fits fits/img.fits fits/img.fits fits/img.fits -view colorbar no -view graph horizontal yes -view graph vertical yes&
read
xpaset -p bar exit
fi

tt="multicbhgrh"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
ds9 -title bar -tile fits/img.fits fits/img.fits fits/img.fits fits/img.fits -view graph horizontal yes&
read
xpaset -p bar exit
fi

tt="multicbhgrv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
ds9 -title bar -tile fits/img.fits fits/img.fits fits/img.fits fits/img.fits -view graph vertical yes&
read
xpaset -p bar exit
fi

tt="multicbhgrhgrv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
ds9 -title bar -tile fits/img.fits fits/img.fits fits/img.fits fits/img.fits -view graph horizontal yes -view graph vertical yes&
read
xpaset -p bar exit
fi

tt="multicbvgrh"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
ds9 -title bar -tile fits/img.fits fits/img.fits fits/img.fits fits/img.fits -colorbar vertical -view graph horizontal yes&
read
xpaset -p bar exit
fi

tt="multicbvgrv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
ds9 -title bar -tile fits/img.fits fits/img.fits fits/img.fits fits/img.fits -colorbar vertical  -view graph vertical yes&
read
xpaset -p bar exit
fi

tt="multicbvgrhgrv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
ds9 -title bar -tile fits/img.fits fits/img.fits fits/img.fits fits/img.fits -colorbar vertical -view graph horizontal yes -view graph vertical yes&
read
xpaset -p bar exit
fi

echo "Done"

