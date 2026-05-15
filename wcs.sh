echo
echo "*** wcs.sh ***"

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


xpaset -p DS9Test grid on
xpaset -p DS9Test grid system wcs
xpaset -p DS9Test scale zscale
xpaset -p DS9Test wcs skyformat degrees

for f in wcs/*.fits
do
echo $f
xpaset -p DS9Test fits $f
read
xpaset -p DS9Test align
read
done

xpaset -p DS9Test quit
echo "DONE"


