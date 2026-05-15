echo "Position Angle Tests"

echo "Starting DS9..."
if [ `xpaaccess DS9Test` = no ]; then
    ds9 -title DS9Test -zscale -mode region&

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

echo -n "Physical..."
xpaset -p DS9Test fits fits/img.fits
xpaset -p DS9Test region posang/phy.reg
xpaset -p DS9Test align no
read

echo -n "WCS Linear..."
xpaset -p DS9Test fits mosaic/ds9_2amp.fits[2]
xpaset -p DS9Test region posang/ds9_22.reg
xpaset -p DS9Test align yes
read

echo -n "WCS Linear FlipX.."
xpaset -p DS9Test fits mosaic/ds9_2amp.fits
xpaset -p DS9Test region posang/ds9_21.reg
xpaset -p DS9Test align yes
read

echo -n "WCS Celestial..."
xpaset -p DS9Test fits fits/img.fits
xpaset -p DS9Test region posang/img.reg
xpaset -p DS9Test align yes
read

echo -n "WCS Celestial FlipX..."
xpaset -p DS9Test fits wcs2/DECam.fits
xpaset -p DS9Test region posang/decam.reg
xpaset -p DS9Test align yes
read

echo "Done"
