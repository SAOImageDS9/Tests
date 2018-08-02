echo "Position Angle Tests"

echo "Starting DS9..."
if [ `xpaaccess ds9` = no ]; then
    ds9 -zscale -mode region&

    i=1
    while [ "$i" -le 30 ]
	do
	sleep 2
	if [ `xpaaccess ds9` = yes ]; then
	    break
	fi

	i=`expr $i + 1`
    done
fi

echo -n "Physical..."
xpaset -p ds9 fits data/img.fits
xpaset -p ds9 region posang/phy.reg
xpaset -p ds9 align no
read

echo -n "WCS Linear..."
xpaset -p ds9 fits mosaic/ds9_2amp.fits[2]
xpaset -p ds9 region posang/ds9_22.reg
xpaset -p ds9 align yes
read

echo -n "WCS Linear FlipX.."
xpaset -p ds9 fits mosaic/ds9_2amp.fits
xpaset -p ds9 region posang/ds9_21.reg
xpaset -p ds9 align yes
read

echo -n "WCS Celestial..."
xpaset -p ds9 fits data/img.fits
xpaset -p ds9 region posang/img.reg
xpaset -p ds9 align yes
read

echo -n "WCS Celestial FlipX..."
xpaset -p ds9 fits wcs2/DECam.fits
xpaset -p ds9 region posang/decam.reg
xpaset -p ds9 align yes
read

echo "Done"
