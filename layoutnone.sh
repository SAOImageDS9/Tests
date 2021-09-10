org='~/Downloads/ds9.darwinbigsurarm64.8.3b1/ds9'

echo "Starting..."

tt="one"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
eval "$org -title foo -restore layout/layoutnone/$tt.bck&"
ds9 -title bar -frame delete -view colorbar no&
read
xpaset -p foo exit
xpaset -p bar exit
fi

tt="onecbh"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
eval "$org -title foo -restore layout/layoutnone/$tt.bck&"
ds9 -title bar -frame delete &
read
xpaset -p foo exit
xpaset -p bar exit
fi

tt="onecbv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
eval "$org -title foo -restore layout/layoutnone/$tt.bck&"
ds9 -title bar -frame delete -colorbar vertical&
read
xpaset -p foo exit
xpaset -p bar exit
fi

tt="onegrh"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
eval "$org -title foo -restore layout/layoutnone/$tt.bck&"
ds9 -title bar -frame delete -view colorbar no -view graph horizontal yes&
read
xpaset -p foo exit
xpaset -p bar exit
fi

tt="onegrv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
eval "$org -title foo -restore layout/layoutnone/$tt.bck&"
ds9 -title bar -frame delete -view colorbar no -view graph vertical yes&
read
xpaset -p foo exit
xpaset -p bar exit
fi

tt="onegrhgrv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
eval "$org -title foo -restore layout/layoutnone/$tt.bck&"
ds9 -title bar -frame delete -view colorbar no -view graph horizontal yes -view graph vertical yes&
read
xpaset -p foo exit
xpaset -p bar exit
fi

tt="onecbhgrh"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
eval "$org -title foo -restore layout/layoutnone/$tt.bck&"
ds9 -title bar -frame delete -view graph horizontal yes&
read
xpaset -p foo exit
xpaset -p bar exit
fi

tt="onecbhgrv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
eval "$org -title foo -restore layout/layoutnone/$tt.bck&"
ds9 -title bar -frame delete -view graph vertical yes&
read
xpaset -p foo exit
xpaset -p bar exit
fi

tt="onecbhgrhgrv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
eval "$org -title foo -restore layout/layoutnone/$tt.bck&"
ds9 -title bar -frame delete -view graph horizontal yes -view graph vertical yes&
read
xpaset -p foo exit
xpaset -p bar exit
fi

tt="onecbvgrh"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
eval "$org -title foo -restore layout/layoutnone/$tt.bck&"
ds9 -title bar -frame delete -colorbar vertical -view graph horizontal yes&
read
xpaset -p foo exit
xpaset -p bar exit
fi

tt="onecbvgrv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
eval "$org -title foo -restore layout/layoutnone/$tt.bck&"
ds9 -title bar -frame delete -colorbar vertical  -view graph vertical yes&
read
xpaset -p foo exit
xpaset -p bar exit
fi

tt="onecbvgrhgrv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
eval "$org -title foo -restore layout/layoutnone/$tt.bck&"
ds9 -title bar -frame delete -colorbar vertical -view graph horizontal yes -view graph vertical yes&
read
xpaset -p foo exit
xpaset -p bar exit
fi

echo "Done"

