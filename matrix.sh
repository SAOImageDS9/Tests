echo
echo "*** matrix.sh ***"

echo "test panner,center,zoom"
ds9 -title DS9Test data/5x5.fits
echo "PASSED"

echo "testing DATASEC"
ds9 -title DS9Test mosaic/ds9_2amp.fits
echo "PASSED"

echo "Done"


