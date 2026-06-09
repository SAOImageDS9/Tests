echo
echo "*** COMPRESS2 ***"

for f in compress2/*
do
    echo " ${f#compress2/}"
    rm -f foo.fits
    funpack -O foo.fits $f
    timeout 10s ds9 -title DS9Test $f foo.fits -mode crosshair -lock crosshair image -lock scale -lock colorbar -lock frame image -lock slice -exit
done

echo "PASSED"
