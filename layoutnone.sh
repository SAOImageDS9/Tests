org='~/Downloads/ds9.darwinbigsurarm64.8.3b1/ds9'

echo "Starting..."

tt="none"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
eval "$org -title foo -restore layout/layoutnone/$tt.bck&"
ds9 -title bar -frame delete -view colorbar no&
read
xpaset -p foo exit
xpaset -p bar exit
fi

tt="nonecbh"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
eval "$org -title foo -restore layout/layoutnone/$tt.bck&"
ds9 -title bar -frame delete &
read
xpaset -p foo exit
xpaset -p bar exit
fi

tt="nonecbv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
eval "$org -title foo -restore layout/layoutnone/$tt.bck&"
ds9 -title bar -frame delete -colorbar vertical&
read
xpaset -p foo exit
xpaset -p bar exit
fi

tt="nonegrh"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
eval "$org -title foo -restore layout/layoutnone/$tt.bck&"
ds9 -title bar -frame delete -view colorbar no -view graph horizontal yes&
read
xpaset -p foo exit
xpaset -p bar exit
fi

tt="nonegrv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
eval "$org -title foo -restore layout/layoutnone/$tt.bck&"
ds9 -title bar -frame delete -view colorbar no -view graph vertical yes&
read
xpaset -p foo exit
xpaset -p bar exit
fi

tt="nonegrhgrv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
eval "$org -title foo -restore layout/layoutnone/$tt.bck&"
ds9 -title bar -frame delete -view colorbar no -view graph horizontal yes -view graph vertical yes&
read
xpaset -p foo exit
xpaset -p bar exit
fi

tt="nonecbhgrh"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
eval "$org -title foo -restore layout/layoutnone/$tt.bck&"
ds9 -title bar -frame delete -view graph horizontal yes&
read
xpaset -p foo exit
xpaset -p bar exit
fi

tt="nonecbhgrv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
eval "$org -title foo -restore layout/layoutnone/$tt.bck&"
ds9 -title bar -frame delete -view graph vertical yes&
read
xpaset -p foo exit
xpaset -p bar exit
fi

tt="nonecbhgrhgrv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
eval "$org -title foo -restore layout/layoutnone/$tt.bck&"
ds9 -title bar -frame delete -view graph horizontal yes -view graph vertical yes&
read
xpaset -p foo exit
xpaset -p bar exit
fi

tt="nonecbvgrh"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
eval "$org -title foo -restore layout/layoutnone/$tt.bck&"
ds9 -title bar -frame delete -colorbar vertical -view graph horizontal yes&
read
xpaset -p foo exit
xpaset -p bar exit
fi

tt="nonecbvgrv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
eval "$org -title foo -restore layout/layoutnone/$tt.bck&"
ds9 -title bar -frame delete -colorbar vertical  -view graph vertical yes&
read
xpaset -p foo exit
xpaset -p bar exit
fi

tt="nonecbvgrhgrv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
eval "$org -title foo -restore layout/layoutnone/$tt.bck&"
ds9 -title bar -frame delete -colorbar vertical -view graph horizontal yes -view graph vertical yes&
read
xpaset -p foo exit
xpaset -p bar exit
fi

echo "Done"

