
echo "SAMP Hub Tests"

echo "Starting DS9..."
ds9 -debug -zscale fits/img.fits&
echo "click return to start"
read

testit () {
    echo 
    echo "Testing $1"
    tclsh samp.tcl $debug block $msg < samp/${1}.samp
    echo "PASSED"
}

doit () {
    if [ "$1" = "$2" -o  -z "$1" ]; then
    testit "$2"
    fi
}

echo
echo "*** hub.sh ***"

# debug?
debug=
if [ "$1" = "debug" ]; then
    debug=$1
    shift
fi

# proc
msg=call
case $1 in
    notify | notifyAll | call | callAll | callAndWait)
    msg=$1
    shift
    ;;
esac

doit "$1" view-set

rm -rf foo.*
