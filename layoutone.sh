org='~/Downloads/ds9.darwinbigsurarm64.8.3b1/ds9'

echo "Starting..."

tt="one"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
eval "$org -title foo -restore layout/layoutone/$tt.bck&"
ds9 -title bar fits/img.fits -view colorbar no&
read
xpaset -p foo exit
xpaset -p bar exit
fi

tt="onecbh"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
eval "$org -title foo -restore layout/layoutone/$tt.bck&"
ds9 -title bar fits/img.fits&
read
xpaset -p foo exit
xpaset -p bar exit
fi

tt="onecbv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
eval "$org -title foo -restore layout/layoutone/$tt.bck&"
ds9 -title bar fits/img.fits -colorbar vertical&
read
xpaset -p foo exit
xpaset -p bar exit
fi

tt="onegrh"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
eval "$org -title foo -restore layout/layoutone/$tt.bck&"
ds9 -title bar fits/img.fits -view colorbar no -view graph horizontal yes&
read
xpaset -p foo exit
xpaset -p bar exit
fi

tt="onegrv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
eval "$org -title foo -restore layout/layoutone/$tt.bck&"
ds9 -title bar fits/img.fits -view colorbar no -view graph vertical yes&
read
xpaset -p foo exit
xpaset -p bar exit
fi

tt="onegrhgrv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
eval "$org -title foo -restore layout/layoutone/$tt.bck&"
ds9 -title bar fits/img.fits -view colorbar no -view graph horizontal yes -view graph vertical yes&
read
xpaset -p foo exit
xpaset -p bar exit
fi

tt="onecbhgrh"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
eval "$org -title foo -restore layout/layoutone/$tt.bck&"
ds9 -title bar fits/img.fits -view graph horizontal yes&
read
xpaset -p foo exit
xpaset -p bar exit
fi

tt="onecbhgrv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
eval "$org -title foo -restore layout/layoutone/$tt.bck&"
ds9 -title bar fits/img.fits -view graph vertical yes&
read
xpaset -p foo exit
xpaset -p bar exit
fi

tt="onecbhgrhgrv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
eval "$org -title foo -restore layout/layoutone/$tt.bck&"
ds9 -title bar fits/img.fits -view graph horizontal yes -view graph vertical yes&
read
xpaset -p foo exit
xpaset -p bar exit
fi

tt="onecbvgrh"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
eval "$org -title foo -restore layout/layoutone/$tt.bck&"
ds9 -title bar fits/img.fits -colorbar vertical -view graph horizontal yes&
read
xpaset -p foo exit
xpaset -p bar exit
fi

tt="onecbvgrv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
eval "$org -title foo -restore layout/layoutone/$tt.bck&"
ds9 -title bar fits/img.fits -colorbar vertical  -view graph vertical yes&
read
xpaset -p foo exit
xpaset -p bar exit
fi

tt="onecbvgrhgrv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
eval "$org -title foo -restore layout/layoutone/$tt.bck&"
ds9 -title bar fits/img.fits -colorbar vertical -view graph horizontal yes -view graph vertical yes&
read
xpaset -p foo exit
xpaset -p bar exit
fi

echo "Done"

