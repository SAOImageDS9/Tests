KillIt () {
    i=1
    while [ "$i" -le 15 ]; do
      sleep 1
      if [ `xpaaccess DS9Test` = yes ]; then
	  if [ $slow = "1" ]; then
	      sleep 1
	  fi
	  xpaset -p DS9Test quit
	  break
      fi

      i=`expr $i + 1`
    done
}

StartDS9 () {
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
    sleep 1
}

# slow down?
slow=1
if [ "$1" = "slow" ]; then
    slow=1
    shift
fi

echo
echo "*** parse.sh ***"

echo ".. base"
ds9 -title DS9Test -log fits/table.fits &
KillIt

echo ".. [2]"
ds9 -title DS9Test -log fits/table.fits[2] &
KillIt

echo ".. [STDEVT]"
ds9 -title DS9Test -log fits/table.fits[STDEVT] &
KillIt

echo ".. [xmin:xmax,ymin:ymax]"
ds9 -title DS9Test -zscale fits/img.fits[100:300,100:300] &
KillIt

echo ".. [xmin:xmax,*]"
ds9 -title DS9Test -zscale fits/img.fits[100:300,*] &
KillIt

echo ".. [dim@xcen@ycen]"
ds9 -title DS9Test -zscale fits/img.fits[256@400@400] &
KillIt

echo ".. [bin=rawx,rawy]"
ds9 -title DS9Test -log fits/table.fits[bin=rawx,rawy] &
KillIt

echo ".. [STDEVT][xmin:xmax,ymin:ymax]"
ds9 -title DS9Test -log fits/table.fits[STDEVT][100:300,100:300] &
KillIt

echo ".. [STDEVT][bin=rawx,rawy]"
ds9 -title DS9Test -log fits/table.fits[STDEVT][bin=rawx,rawy] &
KillIt

echo ".. [STDEVT][bin=(rawx,rawy)]"
ds9 -title DS9Test -log 'fits/table.fits[STDEVT][bin=(rawx,rawy)]' &
KillIt

echo ".. [STDEVT][xmin:xmax,ymin:ymax][bin=rawx,rawy]"
ds9 -title DS9Test -log fits/table.fits[STDEVT][100:300,100:300][bin=rawx,rawy] &
KillIt

echo ".. [2,xmin:xmax,ymin:ymax]"
ds9 -title DS9Test -log fits/table.fits[2,100:300,100:300] &
KillIt

echo ".. [STDEVT,xmin:xmax,ymin:ymax]"
ds9 -title DS9Test -log fits/table.fits[STDEVT,100:300,100:300] &
KillIt

echo ".. [STDEVT,bin=rawx,rawy]"
ds9 -title DS9Test -log fits/table.fits[STDEVT,bin=rawx,rawy] &
KillIt

echo ".. [filter]"
ds9 -title DS9Test -log 'fits/table.fits[pha<5]' &
KillIt

echo ".. [STDEVT][filter]"
ds9 -title DS9Test -log 'fits/table.fits[STDEVT][pha<5]' &
KillIt

echo ".. array[xdim=256,ydim=256,bitpix=-32,arch=little,skip=0]"
ds9 -title DS9Test -array array/float_little.arr[xdim=256,ydim=256,bitpix=-32,arch=little,skip=0] &
KillIt

echo ".. array[dim=256,bitpix=-32,endian=little]"
ds9 -title DS9Test -array array/float_little.arr[dim=256,bitpix=-32,endian=little] &
KillIt

echo ".. array[dim=256,bitpix=-32,little]"
ds9 -title DS9Test -array array/float_little.arr[dim=256,bitpix=-32,little] &
KillIt

echo ".. array[dim=256,bitpix=-32,little][100:200,100:200]"
ds9 -title DS9Test -array array/float_little.arr[dim=256,bitpix=-32,little][100:200,100:200] &
KillIt

echo ".. array[array(r256l)]"
ds9 -title DS9Test -array 'array/float_little.arr[array(r256l)]' &
KillIt

echo ".. array[array(r256.256:0l)]"
ds9 -title DS9Test -array 'array/float_little.arr[array(r256.256:0l)]' &
KillIt

echo ".. hpx"
ds9 -title DS9Test fits/wmap.fits &
KillIt

echo ".. hpx[100:200,100:200]"
ds9 -title DS9Test fits/wmap.fits[100:200,100:200] &
KillIt

echo ".. hpx[system=equatorial,order=nested,layout=equatorial,col=1,quad=1]"
ds9 -title DS9Test fits/wmap.fits[system=equatorial,order=nested,layout=equatorial,col=1,quad=1] &
KillIt

echo ".. nrrd[100:200,100:200]"
ds9 -title DS9Test -nrrd nrrd/float_big_raw.nrrd[100:200,100:200] &
KillIt

echo ".. envi[100:200,100:200]"
ds9 -title DS9Test -envi envi/float_big.hdr envi/float_big.bsq[100:200,100:200] &
KillIt

echo "DONE"
