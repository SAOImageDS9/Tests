org='~/Downloads/ds9.darwinbigsurarm64.8.3b1/ds9'

echo "Starting..."

tt="nomulti"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
eval "$org -title foo -restore layout/nomulti/$tt.bck&"
ds9 -title bar -view multi no -tile fits/img.fits fits/img.fits fits/img.fits fits/img.fits -view colorbar no&
read
xpaset -p foo exit
xpaset -p bar exit
fi

tt="nomulticbh"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
eval "$org -title foo -restore layout/nomulti/$tt.bck&"
ds9 -title bar -view multi no -tile fits/img.fits fits/img.fits fits/img.fits fits/img.fits&
read
xpaset -p foo exit
xpaset -p bar exit
fi

tt="nomulticbv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
eval "$org -title foo -restore layout/nomulti/$tt.bck&"
ds9 -title bar -view multi no -tile fits/img.fits fits/img.fits fits/img.fits fits/img.fits -colorbar vertical&
read
xpaset -p foo exit
xpaset -p bar exit
fi

tt="nomultigrh"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
eval "$org -title foo -restore layout/nomulti/$tt.bck&"
ds9 -title bar -view multi no -tile fits/img.fits fits/img.fits fits/img.fits fits/img.fits -view colorbar no -view graph horizontal yes&
read
xpaset -p foo exit
xpaset -p bar exit
fi

tt="nomultigrv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
eval "$org -title foo -restore layout/nomulti/$tt.bck&"
ds9 -title bar -view multi no -tile fits/img.fits fits/img.fits fits/img.fits fits/img.fits -view colorbar no -view graph vertical yes&
read
xpaset -p foo exit
xpaset -p bar exit
fi

tt="nomultigrhgrv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
eval "$org -title foo -restore layout/nomulti/$tt.bck&"
ds9 -title bar -view multi no -tile fits/img.fits fits/img.fits fits/img.fits fits/img.fits -view colorbar no -view graph horizontal yes -view graph vertical yes&
read
xpaset -p foo exit
xpaset -p bar exit
fi

tt="nomulticbhgrh"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
eval "$org -title foo -restore layout/nomulti/$tt.bck&"
ds9 -title bar -view multi no -tile fits/img.fits fits/img.fits fits/img.fits fits/img.fits -view graph horizontal yes&
read
xpaset -p foo exit
xpaset -p bar exit
fi

tt="nomulticbhgrv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
eval "$org -title foo -restore layout/nomulti/$tt.bck&"
ds9 -title bar -view multi no -tile fits/img.fits fits/img.fits fits/img.fits fits/img.fits -view graph vertical yes&
read
xpaset -p foo exit
xpaset -p bar exit
fi

tt="nomulticbhgrhgrv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
eval "$org -title foo -restore layout/nomulti/$tt.bck&"
ds9 -title bar -view multi no -tile fits/img.fits fits/img.fits fits/img.fits fits/img.fits -view graph horizontal yes -view graph vertical yes&
read
xpaset -p foo exit
xpaset -p bar exit
fi

tt="nomulticbvgrh"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
eval "$org -title foo -restore layout/nomulti/$tt.bck&"
ds9 -title bar -view multi no -tile fits/img.fits fits/img.fits fits/img.fits fits/img.fits -colorbar vertical -view graph horizontal yes&
read
xpaset -p foo exit
xpaset -p bar exit
fi

tt="nomulticbvgrv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
eval "$org -title foo -restore layout/nomulti/$tt.bck&"
ds9 -title bar -view multi no -tile fits/img.fits fits/img.fits fits/img.fits fits/img.fits -colorbar vertical  -view graph vertical yes&
read
xpaset -p foo exit
xpaset -p bar exit
fi

tt="nomulticbvgrhgrv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
eval "$org -title foo -restore layout/nomulti/$tt.bck&"
ds9 -title bar -view multi no -tile fits/img.fits fits/img.fits fits/img.fits fits/img.fits -colorbar vertical -view graph horizontal yes -view graph vertical yes&
read
xpaset -p foo exit
xpaset -p bar exit
fi

echo "Done"

