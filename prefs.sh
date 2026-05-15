echo "Prefs Tests"

doit() {
    if [ `xpaaccess DS9Test` = no ]; then
	ds9 -title DS9Test &

	i=1
	while [ "$i" -le 30 ]; do
	    sleep 2
	    if [ `xpaaccess DS9Test` = yes ]; then
		break
	    fi

	    i=`expr $i + 1`
	done
    fi
}

echo
echo "*** prefs.sh ***"

rm -rf ~/.ds9

for f in prefs/*.prf
do
echo "Testing $f"
rm -f ~/.ds9.prf
cp $f ~/.ds9.prf
doit
xpaset -p DS9Test exit
rm -f ~/.ds9.prf
echo "PASSED"
done
