
echo "SAMP Set Tests"

echo "Starting DS9..."
ds9 -debug -zscale fits/img.fits&
echo "click return to start"
read

testit () {
    echo 
    echo "Testing $1"
    tclsh samp.tcl $debug block $pp < samp/${1}.samp
    echo "PASSED"
}

doit () {
    if [ "$1" = "$2" -o  -z "$1" ]; then
    testit "$2"
    fi
    if [ $slow = "1" ]; then
	sleep 1
    fi
}

echo
echo "*** samp.sh ***"

# slow down?
slow=0
if [ "$1" = "slow" ]; then
    slow=1
    shift
fi

# debug?
debug=
if [ "$1" = "debug" ]; then
    debug=$1
    shift
fi

# proc
pp=call
case $1 in
    notify | notifyAll | call | callAll | callAndWait)
    pp=$1
    shift
    ;;
esac

doit "$1" view-set

rm -rf foo.*
