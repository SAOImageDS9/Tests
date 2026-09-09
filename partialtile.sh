StartDS9 () {
    if [ `xpaaccess DS9Test` = no ]; then
	timeout 1m ds9 -title DS9Test &

	i=1
	while [ "$i" -le 10 ]
	    do
	    sleep 2
	    if [ `xpaaccess DS9Test` = yes ]; then
		break
	    fi

	    i=`expr $i + 1`
	done
    fi
}

# Regression test for tiled-compression decoding of "edge" tiles, i.e.
# tiles whose actual pixel extent is smaller than ZTILEn because the
# image axis is not an even multiple of the tile size. Each fixture in
# partialtile/ is a 112x112 image (char/short/float) compressed with
# ZTILE1=ZTILE2=64, so the tiling (64+48) always leaves a right-edge,
# bottom-edge, and corner partial tile. 112x112 also divides evenly by
# 56, so the same source images could be retiled 56x56 for an
# exact-tile sanity check if ever needed.
#
# partialtile/<type>.fits is the uncompressed truth image.
# partialtile/<type>.<algo>.fits.fz is the same image, tile-compressed,
# where <algo> is one of: g (GZIP_1), g2 (GZIP_2), h (HCOMPRESS_1),
# p (PLIO_1), r (RICE_1) -- matching the suffix convention used in
# compress/. PLIO only supports 8/16-bit positive integers, so there
# are no float.p fixtures; float is GZIP-only (compressed with fpack's
# "-q 0" so it is exactly lossless, matching the other algorithms).
#
# Each fixture is loaded into ds9 and its full pixel array is compared
# against the truth image via XPA; any mismatch is a decompression bug.

echo
echo "*** PARTIALTILE ***"

StartDS9

where=partialtile
fail=0

dumptruth () {
    type=$1
    xpaset -p DS9Test frame new
    xpaset -p DS9Test file $where/${type}.fits
    xpaget DS9Test data image 1 1 112 112 no > ${type}.truth.out
    xpaset -p DS9Test frame delete
}

dumptruth char
dumptruth short
dumptruth float

for f in $where/*.fits.fz
do
    base=`basename $f .fits.fz`
    type=`echo $base | cut -d. -f1`

    xpaset -p DS9Test frame new
    xpaset -p DS9Test file $f
    xpaget DS9Test data image 1 1 112 112 no > ${base}.out
    xpaset -p DS9Test frame delete

    o=`diff ${type}.truth.out ${base}.out`
    if [ "$o" = "" ]; then
	echo " ${base}.fits.fz PASSED"
    else
	echo " ${base}.fits.fz FAILED"
	fail=1
    fi

    rm -f ${base}.out
done

rm -f char.truth.out short.truth.out float.truth.out

xpaset -p DS9Test quit

if [ $fail = "0" ]; then
    echo "PASSED"
else
    echo "FAILED"
    exit 1
fi
