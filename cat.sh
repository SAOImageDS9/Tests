echo "Catalog Line Options Tests"

testit () {
    echo "Testing $1"
    unset opt
    opt="$opt $1 -sleep 1"
}

doit () {
    eval ds9 -zscale fits/img.fits "$opt" -exit
    echo "PASSED"
    echo ""
}

echo
echo "*** cat.sh ***"

tt="-cat 2mass -header"
testit "$tt"
doit

tt="-cat 2mass -cat sky fk4 -header"
testit "$tt"
doit

tt="-cat 2mass -cat iras -header"
testit "$tt"
doit

tt="-cat 2mass -cat sky fk4 -cat iras -header"
testit "$tt"
doit

