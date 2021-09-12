org='~/Downloads/ds9.darwinbigsurarm64.8.3b1/ds9'

echo "Starting..."

tt="none"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo "$tt..."
eval "$org -title foo -restore layout/none/$tt.bck&"
ds9 -title bar -frame delete -view colorbar no&
read
xpaset -p foo exit
xpaset -p bar exit
fi

tt="cbh"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo "$tt..."
eval "$org -title foo -restore layout/none/$tt.bck&"
ds9 -title bar -frame delete &
read
xpaset -p foo exit
xpaset -p bar exit
fi

tt="cbv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo "$tt..."
eval "$org -title foo -restore layout/none/$tt.bck&"
ds9 -title bar -frame delete -colorbar vertical&
read
xpaset -p foo exit
xpaset -p bar exit
fi

tt="cbhgrh"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo "$tt..."
eval "$org -title foo -restore layout/none/$tt.bck&"
ds9 -title bar -frame delete -view graph horizontal yes&
read
xpaset -p foo exit
xpaset -p bar exit
fi

tt="cbhgrv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo "$tt..."
eval "$org -title foo -restore layout/none/$tt.bck&"
ds9 -title bar -frame delete -view graph vertical yes&
read
xpaset -p foo exit
xpaset -p bar exit
fi

tt="cbhgrhgrv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo "$tt..."
eval "$org -title foo -restore layout/none/$tt.bck&"
ds9 -title bar -frame delete -view graph horizontal yes -view graph vertical yes&
read
xpaset -p foo exit
xpaset -p bar exit
fi

tt="cbvgrh"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo "$tt..."
eval "$org -title foo -restore layout/none/$tt.bck&"
ds9 -title bar -frame delete -colorbar vertical -view graph horizontal yes&
read
xpaset -p foo exit
xpaset -p bar exit
fi

tt="cbvgrv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo "$tt..."
eval "$org -title foo -restore layout/none/$tt.bck&"
ds9 -title bar -frame delete -colorbar vertical  -view graph vertical yes&
read
xpaset -p foo exit
xpaset -p bar exit
fi

tt="cbvgrhgrv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo "$tt..."
eval "$org -title foo -restore layout/none/$tt.bck&"
ds9 -title bar -frame delete -colorbar vertical -view graph horizontal yes -view graph vertical yes&
read
xpaset -p foo exit
xpaset -p bar exit
fi

tt="grh"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo "$tt..."
eval "$org -title foo -restore layout/none/$tt.bck&"
ds9 -title bar -frame delete -view colorbar no -view graph horizontal yes&
read
xpaset -p foo exit
xpaset -p bar exit
fi

tt="grv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo "$tt..."
eval "$org -title foo -restore layout/none/$tt.bck&"
ds9 -title bar -frame delete -view colorbar no -view graph vertical yes&
read
xpaset -p foo exit
xpaset -p bar exit
fi

tt="grhgrv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo "$tt..."
eval "$org -title foo -restore layout/none/$tt.bck&"
ds9 -title bar -frame delete -view colorbar no -view graph horizontal yes -view graph vertical yes&
read
xpaset -p foo exit
xpaset -p bar exit
fi

echo "Done"

