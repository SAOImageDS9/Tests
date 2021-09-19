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
    echo "...done"
    xpaset -p foo exit
    xpaset -p bar exit
}

echo "Starting..."

tt="none"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
eval "$org -title foo -restore layout/none/$tt.bck&"
ds9 -title bar -frame delete -view colorbar no&
testit
fi

tt="cbh"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
eval "$org -title foo -restore layout/none/$tt.bck&"
ds9 -title bar -frame delete &
testit
fi

tt="cbv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
eval "$org -title foo -restore layout/none/$tt.bck&"
ds9 -title bar -frame delete -colorbar vertical&
testit
fi

tt="cbhgrh"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
eval "$org -title foo -restore layout/none/$tt.bck&"
ds9 -title bar -frame delete -view graph horizontal yes&
testit
fi

tt="cbhgrv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
eval "$org -title foo -restore layout/none/$tt.bck&"
ds9 -title bar -frame delete -view graph vertical yes&
testit
fi

tt="cbhgrhgrv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
eval "$org -title foo -restore layout/none/$tt.bck&"
ds9 -title bar -frame delete -view graph horizontal yes -view graph vertical yes&
testit
fi

tt="cbvgrh"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
eval "$org -title foo -restore layout/none/$tt.bck&"
ds9 -title bar -frame delete -colorbar vertical -view graph horizontal yes&
testit
fi

tt="cbvgrv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
eval "$org -title foo -restore layout/none/$tt.bck&"
ds9 -title bar -frame delete -colorbar vertical  -view graph vertical yes&
testit
fi

tt="cbvgrhgrv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
eval "$org -title foo -restore layout/none/$tt.bck&"
ds9 -title bar -frame delete -colorbar vertical -view graph horizontal yes -view graph vertical yes&
testit
fi

tt="grh"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
eval "$org -title foo -restore layout/none/$tt.bck&"
ds9 -title bar -frame delete -view colorbar no -view graph horizontal yes&
testit
fi

tt="grv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
eval "$org -title foo -restore layout/none/$tt.bck&"
ds9 -title bar -frame delete -view colorbar no -view graph vertical yes&
testit
fi

tt="grhgrv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
eval "$org -title foo -restore layout/none/$tt.bck&"
ds9 -title bar -frame delete -view colorbar no -view graph horizontal yes -view graph vertical yes&
testit
fi

