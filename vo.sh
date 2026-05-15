echo
echo "*** vo.sh ***"

echo "Starting DS9..."
if [ `xpaaccess DS9Test` = no ]; then
    ds9 -title DS9Test &

    i=1
    while [ "$i" -le 30 ]
	do
	sleep 2
	if [ `xpaaccess DS9Test` = yes ]; then
	    break
	fi

	i=`expr $i + 1`
    done
fi

doit () {
    dd=1
    ddd=4

    xpaset -p DS9Test vo xray1.physics.rutgers
#    xpaset -p DS9Test vo rinzai.rutgers.edu
    xpaset -p DS9Test web click 4
    sleep $ddd
    xpaset -p DS9Test web click back
    xpaset -p DS9Test raise

    echo "..Overview of Chandra-Ed Analysis Tools"
    xpaset -p DS9Test analysis 0
    sleep $dd

    echo "..Radial Profile Plot"
    xpaset -p DS9Test regions regions/vo2.reg
    xpaset -p DS9Test analysis 1
    sleep $dd

    echo "..Counts in Regions"
    xpaset -p DS9Test regions deleteall
    xpaset -p DS9Test regions regions/vo1.reg
    xpaset -p DS9Test analysis 2
    sleep $dd

    echo "..Quick Energy Spectrum Plot"
    xpaset -p DS9Test analysis 3
    sleep $dd

    echo "..Quick Light Curve Plot"
    xpaset -p DS9Test analysis 4
    sleep $dd

    echo "..Histogram Plot"
    xpaset -p DS9Test analysis 5
    sleep $dd

    echo "..Column Histogram"
    xpaset -p DS9Test analysis 6
    sleep $dd

    echo "..Refine (Centroid) Position"
    xpaset -p DS9Test analysis 7
    sleep $ddd

    echo "..Imexam"
    xpaset -p DS9Test analysis 8
    sleep $ddd

    echo "..Rebin image"
    xpaset -p DS9Test analysis 9
    sleep $ddd
    sleep $ddd
    xpaset -p DS9Test frame delete

    echo "..Energy Filter"
    xpaset -p DS9Test analysis 10
    sleep $ddd
    sleep $ddd
    xpaset -p DS9Test frame delete

    echo "..Time Filter"
    xpaset -p DS9Test analysis 11
    sleep $ddd
    sleep $ddd
    xpaset -p DS9Test frame delete

    echo "..Column Filter"
    xpaset -p DS9Test analysis 12
    sleep $ddd
    sleep $ddd
    xpaset -p DS9Test frame delete

    echo "..CIAO/Sherpa Spectral Fit"
    xpaset -p DS9Test analysis 13
    sleep $ddd

    echo "..FTOOLS/Light Curve"
    xpaset -p DS9Test analysis 14
    sleep $ddd

    echo "..FTOOLS/Power Spectrum"
    xpaset -p DS9Test analysis 15
    sleep $ddd

    echo "..FTOOLS/Period Fold"
    xpaset -p DS9Test analysis 16
    sleep $ddd

    xpaset -p DS9Test regions deleteall
    xpaset -p DS9Test frame clear

    xpaset -p DS9Test vo disconnect chandra-ed
    xpaset -p DS9Test web close

    echo "PASSED"
}

if [ "$1" = "xpa" ]; then
    echo "Testing xpa"
    xpaset -p DS9Test vo method xpa
    doit
fi

if [ "$1" = "mime" ]; then
    echo "Testing mime"
    xpaset -p DS9Test vo method mime
    doit
fi

xpaset -p DS9Test exit

echo "DONE"
