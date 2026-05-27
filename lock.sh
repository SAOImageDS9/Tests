echo
echo "*** lock.sh ***"

if [ "$1" = "frame" -o -z "$1" ]; then
echo "Testing frame"
ds9 -title DS9Test -debug -zscale fits/img.fits fits/img.fits -tile -lock frame wcs -mode pan -exit
fi

if [ "$1" = "crosshair" -o -z "$1" ]; then
echo "Testing crosshair"
ds9 -title DS9Test -debug -zscale fits/img.fits fits/img.fits -tile -lock crosshair wcs -mode crosshair -exit
fi

if [ "$1" = "crop" -o -z "$1" ]; then
echo "Testing crop"
ds9 -title DS9Test -debug -zscale fits/img.fits -rgb fits/img.fits -green fits/img.fits -blue fits/img.fits -tile -lock crop wcs -crop open -mode crop -rgb lock crop yes -exit
ds9 -title DS9Test -debug -zscale data/3d.fits -3d data/3d.fits -3d vp 45 30 -tile -lock crop wcs -mode crop -exit
fi

if [ "$1" = "slice" -o -z "$1" ]; then
echo "Testing slice"
ds9 -title DS9Test -debug -zscale data/3d.fits -3d data/3d.fits -3d vp 45 30 -tile -lock slice -exit
fi

if [ "$1" = "bin" -o -z "$1" ]; then
echo "Testing bin"
ds9 -title DS9Test -debug -zscale fits/table.fits -rgb fits/table.fits -green fits/table.fits -blue fits/table.fits -tile -lock bin -bin open -rgb lock bin yes -exit
fi

if [ "$1" = "scale" -o -z "$1" ]; then
echo "Testing scale"
ds9 -title DS9Test -debug -zscale fits/img.fits -rgb fits/img.fits -green fits/img.fits -blue fits/img.fits -tile -lock scale -scale open -rgb lock scale yes -exit
fi

if [ "$1" = "color" -o -z "$1" ]; then
echo "Testing color"
ds9 -title DS9Test -debug -zscale fits/img.fits fits/img.fits -rgb -red fits/img.fits -green fits/img.fits -blue fits/img.fits -rgb lock colorbar yes -rgb -red fits/img.fits -green fits/img.fits -blue fits/img.fits  -rgb lock colorbar yes -tile -lock colorbar yes -cmap open -exit
fi

if [ "$1" = "block" -o -z "$1" ]; then
echo "Testing block"
ds9 -title DS9Test -debug -zscale fits/img.fits fits/img.fits -tile -lock block -block 4 -exit
fi

if [ "$1" = "smooth" -o -z "$1" ]; then
echo "Testing smooth"
ds9 -title DS9Test -debug -zscale fits/img.fits fits/img.fits -tile -lock smooth -smooth -exit
fi

echo "Done"
