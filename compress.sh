echo
echo "*** COMPRESS ***"

for f in compress/*
do
    echo " ${f#compress/}"
    rm -f foo.fits
    funpack -O foo.fits $f
    timeout 10s ds9 -title DS9Test $f foo.fits -mode crosshair -lock crosshair image -lock scale -lock colorbar -lock frame image -lock slice -exit
done

echo "PASSED"
