echo "XPA Tests"

echo "Starting DS9..."
if [ `xpaaccess DS9Test` = no ]; then
    ds9 -title DS9Test -title DS9Test -tcl&

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

testit () {
    if [ -f xpa/${1}.xpa ]
    then
	o=`diff xpa/${1}.xpa ${1}.out`
	if [ "$o" = "" ]
	then
	    echo "PASSED"
	else
            echo "FAILED"
	    echo "$o"
	fi
    else
        echo "PASSED"
    fi

    if [ $slow = "1" ]; then
	sleep 1
    fi
    #rm -rf ${1}.out

    xpaset -p DS9Test single
    xpaset -p DS9Test raise
}

echo
echo "*** xpa.sh ***"

delay=.5

# must be invoked
# console
# iexam
# print
# source
# tcl

#nvss
#vla
#2mass
#vo

# slow down?
slow=0
if [ "$1" = "slow" ]; then
    slow=1
    shift
fi

rm -f *.out
xpaset -p DS9Test scale zscale
xpaset -p DS9Test fits fits/img.fits

tt="2mass"
if [ "$1" = "$tt" ]; then
echo -n "$tt..."
xpaset -p DS9Test 2mass open
xpaset -p DS9Test 2mass close
xpaset -p DS9Test 2mass survey h
xpaget DS9Test 2mass survey >> ${tt}.out
xpaset -p DS9Test 2mass size 30 30 arcsec
xpaget DS9Test 2mass size >> ${tt}.out
xpaset -p DS9Test 2mass save no
xpaget DS9Test 2mass save >> ${tt}.out
xpaset -p DS9Test 2mass frame new
xpaget DS9Test 2mass frame >> ${tt}.out
xpaset -p DS9Test 2mass update frame
xpaset -p DS9Test 2mass m51
xpaset -p DS9Test 2mass name m51
xpaget DS9Test 2mass name >> ${tt}.out
xpaset -p DS9Test 2mass name clear
xpaset -p DS9Test 2mass 13:29:52.37 +47:11:40.8
# backward compatibility
xpaset -p DS9Test 2mass coord 13:29:52.37 +47:11:40.8 sexagesimal
xpaget DS9Test 2mass coord >> ${tt}.out
xpaset -p DS9Test 2mass update frame
xpaset -p DS9Test mode crosshair
xpaset -p DS9Test 2mass update crosshair
xpaset -p DS9Test 2mass close
xpaset -p DS9Test mode none
xpaset -p DS9Test frame delete
xpaset -p DS9Test frame delete
xpaset -p DS9Test frame delete
xpaset -p DS9Test frame delete
xpaset -p DS9Test frame delete
xpaset -p DS9Test frame delete
xpaset -p DS9Test frame delete

testit $tt
fi

tt="3d"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaset -p DS9Test 3d open
xpaset -p DS9Test 3d close
xpaset -p DS9Test 3d
xpaset -p DS9Test 3d view 45 30
xpaget DS9Test 3d view >> ${tt}.out
xpaget DS9Test 3d az >> ${tt}.out
xpaget DS9Test 3d el >> ${tt}.out
xpaget DS9Test 3d scale >> ${tt}.out
xpaget DS9Test 3d method >> ${tt}.out
xpaget DS9Test 3d background >> ${tt}.out
xpaget DS9Test 3d border >> ${tt}.out
xpaget DS9Test 3d border color >> ${tt}.out
xpaget DS9Test 3d compass >> ${tt}.out
xpaget DS9Test 3d compass color >> ${tt}.out
xpaget DS9Test 3d highlite >> ${tt}.out
xpaget DS9Test 3d highlite color >> ${tt}.out
xpaget DS9Test 3d lock >> ${tt}.out
xpaset -p DS9Test 3d view 45 30
xpaset -p DS9Test 3d az 45
xpaset -p DS9Test 3d el 30
xpaset -p DS9Test 3d scale 5
xpaset -p DS9Test 3d method mip
xpaset -p DS9Test 3d background azimuth
xpaset -p DS9Test 3d border yes
xpaset -p DS9Test 3d border color red
xpaset -p DS9Test 3d compass yes
xpaset -p DS9Test 3d compass color red
xpaset -p DS9Test 3d highlite yes
xpaset -p DS9Test 3d highlite color red
xpaset -p DS9Test 3d match
xpaset -p DS9Test 3d lock
xpaset -p DS9Test 3d lock no
xpaset -p DS9Test frame delete

xpaset -p DS9Test 3d
xpaset -p DS9Test fits data/ds9_counts_cube.fits
xpaset -p DS9Test 3d method fip
xpaset -p DS9Test 3d shade yes
xpaset -p DS9Test 3d shade ambient 0.25
xpaset -p DS9Test 3d shade strength 0.75
xpaset -p DS9Test 3d shade normal yes
xpaset -p DS9Test 3d shade normal strength 0.5
xpaget DS9Test 3d method >> ${tt}.out
xpaget DS9Test 3d shade >> ${tt}.out
xpaget DS9Test 3d shade ambient >> ${tt}.out
xpaget DS9Test 3d shade strength >> ${tt}.out
xpaget DS9Test 3d shade normal >> ${tt}.out
xpaget DS9Test 3d shade normal strength >> ${tt}.out
xpaset -p DS9Test 3d shade normal no
xpaset -p DS9Test 3d shade no
xpaset -p DS9Test frame delete

xpaset -p DS9Test 3d close
xpaset -p DS9Test cube close
testit $tt
fi

tt="about"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaget DS9Test about > /dev/null

testit $tt
fi

tt="align"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaget DS9Test align >> ${tt}.out
xpaset -p DS9Test align
xpaset -p DS9Test frame reset

testit $tt
fi

tt="analysis"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaset -p DS9Test analysis clear
xpaset -p DS9Test analysis analysis/analysis.ans
xpaget DS9Test analysis > /dev/null
xpaget DS9Test analysis task > /dev/null
#xpaget DS9Test analysis entry {hello world}
#xpaget DS9Test analysis message okcancel {hello world}
#xpaget -p ds9 analysis filedialog open
#xpaget -p ds9 analysis filedialog save

xpaset -p DS9Test analysis 0
xpaset -p DS9Test analysis task 1
xpaset -p DS9Test analysis task {Basic Help}
xpaset -p DS9Test analysis clear
xpaset -p DS9Test analysis load analysis/analysis.ans
xpaset -p DS9Test analysis clear load analysis/analysis.ans
xpaset -p DS9Test analysis clear
cat analysis/analysis.ans | xpaset DS9Test analysis load
xpaset -p DS9Test analysis clear
#xpaset -p DS9Test analysis message {This is a message}
xpaset -p DS9Test analysis text {This is text}
cat analysis/analysis.txt | xpaset DS9Test analysis text

testit $tt
fi

tt="array"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaset -p DS9Test frame new
xpaset -p DS9Test array array/float_big.arr[dim=256,bitpix=-32,endian=big]
cat array/float_big.arr | xpaset DS9Test array -[dim=256,bitpix=-32,endian=big]
xpaget DS9Test array little > /dev/null
xpaset -p DS9Test array mask array/float_big.arr[dim=256,bitpix=-32,endian=big]
xpaset -p DS9Test frame delete

# backward compatibility
xpaset -p DS9Test frame new rgb
cat rgb/rgb.arr | xpaset DS9Test array rgb -[dim=1600,bitpix=-32,endian=little]
xpaset -p DS9Test frame delete
cat rgb/rgb.arr | xpaset DS9Test array new rgb -[dim=1600,bitpix=-32,endian=little]
xpaset -p DS9Test frame delete
xpaset -p DS9Test rgb close

# backward compatibility
xpaset -p DS9Test frame new hls
cat hls/hls.arr | xpaset DS9Test array hls -[xdim=1389,ydim=1387,bitpix=-64,endian=little]
xpaset -p DS9Test frame delete
cat hls/hls.arr | xpaset DS9Test array new hls -[xdim=1389,ydim=1387,bitpix=-64,endian=little]
xpaset -p DS9Test frame delete
xpaset -p DS9Test hls close

# backward compatibility
xpaset -p DS9Test frame new hsv
cat hsv/hsv.arr | xpaset DS9Test array hsv -[xdim=1389,ydim=1387,bitpix=-64,endian=little]
xpaset -p DS9Test frame delete
cat hsv/hsv.arr | xpaset DS9Test array new hsv -[xdim=1389,ydim=1387,bitpix=-64,endian=little]
xpaset -p DS9Test frame delete
xpaset -p DS9Test hsv close

testit $tt
fi

# backward compatibility prefs
tt="bg"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt/background..."
xpaget DS9Test background >> ${tt}.out
xpaget DS9Test bg >> ${tt}.out
xpaset -p DS9Test background red
xpaset -p DS9Test background white

testit $tt
fi

tt="bookmark"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaset -p DS9Test bookmark clear
xpaset -p DS9Test bookmark add
xpaset -p DS9Test bookmark add {Source A}
xpaget DS9Test bookmark >> ${tt}.out
xpaget DS9Test bookmark 1 > /dev/null
xpaget DS9Test bookmark 2 > /dev/null
xpaset -p DS9Test bookmark goto 1
xpaset -p DS9Test bookmark delete 1
xpaset -p DS9Test bookmark save foo.bmrk
xpaset -p DS9Test bookmark clear
xpaset -p DS9Test bookmark load foo.bmrk
xpaget DS9Test bookmark >> ${tt}.out
xpaget DS9Test bookmark 1 > /dev/null
xpaset -p DS9Test bookmark goto 1
xpaset -p DS9Test bookmark clear

testit $tt
fi

tt="bin"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaset -p DS9Test fits new fits/table.fits
xpaset -p DS9Test single
xpaset -p DS9Test bin open
xpaset -p DS9Test bin factor 4
xpaset -p DS9Test bin factor 8 8
xpaset -p DS9Test scale log
xpaset -p DS9Test scale minmax
xpaset -p DS9Test bin buffersize 1024
xpaset -p DS9Test bin filter 'circle(4096,4096,200)'
xpaset -p DS9Test bin filter clear
xpaset -p DS9Test bin cols rawx rawy
xpaset -p DS9Test bin about center
xpaset -p DS9Test bin colsz x y pha
xpaset -p DS9Test bin depth 10
xpaset -p DS9Test bin about 4096 4096
xpaset -p DS9Test bin depth 1
xpaset -p DS9Test bin function sum
xpaset -p DS9Test bin in
xpaset -p DS9Test bin out
xpaset -p DS9Test bin to fit
xpaset -p DS9Test bin match
xpaset -p DS9Test bin lock yes
xpaset -p DS9Test bin lock no
xpaset -p DS9Test bin close
xpaget DS9Test bin about >> ${tt}.out
xpaget DS9Test bin buffersize >> ${tt}.out
xpaget DS9Test bin cols >> ${tt}.out
xpaget DS9Test bin factor >> ${tt}.out
xpaget DS9Test bin filter >> ${tt}.out
xpaget DS9Test bin function >> ${tt}.out
xpaget DS9Test bin lock >> ${tt}.out
xpaset -p DS9Test frame delete

testit $tt
fi

tt="blink"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaget DS9Test blink >> ${tt}.out
xpaget DS9Test blink interval >> ${tt}.out
xpaset -p DS9Test frame new
xpaset -p DS9Test blink
xpaset -p DS9Test blink yes
xpaset -p DS9Test blink interval .5
xpaset -p DS9Test single
xpaset -p DS9Test frame first
xpaset -p DS9Test frame next
xpaset -p DS9Test frame delete

testit $tt
fi

tt="block"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaset -p DS9Test block open
xpaset -p DS9Test block 4
xpaset -p DS9Test block 8 8
xpaset -p DS9Test block to 4
xpaset -p DS9Test block to 8 8
xpaset -p DS9Test block in
xpaset -p DS9Test block out
xpaset -p DS9Test block to fit
xpaset -p DS9Test block to 1
xpaset -p DS9Test block match
xpaset -p DS9Test block lock yes
xpaset -p DS9Test block lock no
xpaset -p DS9Test block close
xpaget DS9Test block >> ${tt}.out
xpaget DS9Test block lock >> ${tt}.out

testit $tt
fi

tt="catalog"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo "$tt/cat..."
echo " default..."
xpaset -p DS9Test catalog sao
xpaset -p DS9Test catalog cds 2mass
xpaget DS9Test catalog >> ${tt}.out
xpaset -p DS9Test catalog current sao

xpaset -p DS9Test catalog clear
xpaset -p DS9Test catalog close
xpaset -p DS9Test catalog clear
xpaset -p DS9Test catalog close

xpaset -p DS9Test catalog new
xpaset -p DS9Test catalog close
# backward compatibility
xpaset -p DS9Test catalog
xpaset -p DS9Test catalog close

xpaset -p DS9Test catalog cds "I/284"
xpaset -p DS9Test catalog clear
xpaset -p DS9Test catalog close

echo " save/load..."
xpaset -p DS9Test catalog cds 2mass
xpaset -p DS9Test catalog save foo.xml
xpaset -p DS9Test catalog load foo.xml
xpaset -p DS9Test catalog clear
xpaset -p DS9Test catalog close

echo " export/import..."
xpaset -p DS9Test catalog cds 2mass
xpaset -p DS9Test catalog export rdb foo.rdb
xpaset -p DS9Test catalog export tsv foo.tsv
xpaset -p DS9Test catalog import rdb foo.rdb
xpaset -p DS9Test catalog import tsv foo.tsv
xpaset -p DS9Test catalog clear
xpaset -p DS9Test catalog close
xpaset -p DS9Test catalog clear
xpaset -p DS9Test catalog close
xpaset -p DS9Test catalog clear
xpaset -p DS9Test catalog close

xpaset -p DS9Test frame new
xpaset -p DS9Test fits catfits/acisf00635N004_evt2.fits.gz
xpaset -p DS9Test catalog import fits catfits/cellout.fits
xpaset -p DS9Test catalog clear
xpaset -p DS9Test catalog close
xpaset -p DS9Test frame delete

echo " dialog..."
xpaset -p DS9Test catalog cds 2mass
xpaset -p DS9Test catalog plot '$Jmag' '$Hmag' '$e_Jmag' '$e_Hmag'
xpaset -p DS9Test catalog symbol condition '$Jmag>15'
xpaset -p DS9Test catalog symbol shape {boxcircle point}
xpaset -p DS9Test catalog symbol color red
xpaset -p DS9Test catalog symbol condition {}
xpaset -p DS9Test catalog symbol shape text
xpaset -p DS9Test catalog symbol font times
xpaset -p DS9Test catalog symbol fontsize 14
xpaset -p DS9Test catalog symbol fontweight bold
xpaset -p DS9Test catalog symbol fontslant italic
# backward compatibility
xpaset -p DS9Test catalog symbol fontstyle italic
xpaset -p DS9Test catalog symbol add
xpaset -p DS9Test catalog symbol remove
xpaset -p DS9Test catalog symbol load aux/ds9.sym
xpaset -p DS9Test catalog symbol save foo.sym
xpaset -p DS9Test catalog name m51
xpaset -p DS9Test catalog coordinate 202.48 47.21 fk5
# backward compatibility
xpaset -p DS9Test catalog 202.48 47.21 fk5
xpaset -p DS9Test catalog system wcs
xpaset -p DS9Test catalog sky fk5
xpaset -p DS9Test catalog skyformat degrees
xpaset -p DS9Test catalog radius 22 arcmin
# backward compatibility
xpaset -p DS9Test catalog size 20 24 arcmin
xpaset -p DS9Test catalog retrieve
xpaset -p DS9Test catalog regions
xpaset -p DS9Test region delete all
xpaset -p DS9Test catalog filter '$Jmag>15'
xpaset -p DS9Test catalog filter load aux/cat.flt
xpaset -p DS9Test catalog retrieve
xpaset -p DS9Test catalog cancel
#xpaset -p DS9Test catalog print
xpaset -p DS9Test catalog server sao
xpaset -p DS9Test catalog sort "Jmag" incr
xpaset -p DS9Test catalog maxrows 3000
xpaset -p DS9Test catalog allcols
xpaset -p DS9Test catalog allrows
xpaset -p DS9Test catalog ra "RAJ2000"
xpaset -p DS9Test catalog dec "DEJ2000"
xpaset -p DS9Test catalog psystem wcs
xpaset -p DS9Test catalog psky fk5
# backward compatibility
xpaset -p DS9Test catalog hide
xpaset -p DS9Test catalog show yes
xpaset -p DS9Test catalog panto no
xpaset -p DS9Test catalog edit yes
xpaset -p DS9Test catalog location 400
xpaset -p DS9Test catalog header
xpaset -p DS9Test catalog clear
xpaset -p DS9Test catalog close
xpaset -p DS9Test catalog 2mass
xpaset -p DS9Test catalog xmm
xpaset -p DS9Test catalog match function 1and2
xpaset -p DS9Test catalog match error 2 arcsec
xpaset -p DS9Test catalog match return 1only
xpaset -p DS9Test catalog match unique no
xpaset -p DS9Test catalog match 2mass xmm
xpaset -p DS9Test catalog match
xpaset -p DS9Test catalog clear
xpaset -p DS9Test catalog close
xpaset -p DS9Test catalog clear
xpaset -p DS9Test catalog close
xpaset -p DS9Test catalog clear
xpaset -p DS9Test catalog close
xpaset -p DS9Test catalog clear
xpaset -p DS9Test catalog close

testit $tt
fi

tt="cd"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaget DS9Test cd >> ${tt}.out
xpaset -p DS9Test cd .

testit $tt
fi

tt="cmap"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaget DS9Test cmap >> ${tt}.out
xpaget DS9Test cmap file >> ${tt}.out
xpaget DS9Test cmap invert >> ${tt}.out
xpaget DS9Test cmap value >> ${tt}.out
xpaget DS9Test cmap lock >> ${tt}.out
xpaset -p DS9Test cmap open
xpaset -p DS9Test cmap Heat
xpaset -p DS9Test cmap load aux/ds9.sao
# backward compatibility
xpaset -p DS9Test cmap file aux/ds9.sao
xpaset -p DS9Test cmap save foo.sao
xpaset -p DS9Test cmap invert yes
xpaset -p DS9Test cmap 5 .2
# backward compatibility
xpaset -p DS9Test cmap value 5 .2
# backward compatibility
xpaset -p DS9Test cmap match
# backward compatibility
xpaset -p DS9Test cmap lock yes
# backward compatibility
xpaset -p DS9Test cmap lock no
xpaset -p DS9Test cmap tag load aux/ds9.tag
xpaset -p DS9Test cmap tag save foo.tag
xpaset -p DS9Test cmap tag delete
xpaset -p DS9Test cmap Grey
xpaset -p DS9Test cmap close

testit $tt
fi

tt="colorbar"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaget DS9Test colorbar >> ${tt}.out
xpaget DS9Test colorbar show >> ${tt}.out
xpaget DS9Test colorbar orientation >> ${tt}.out
xpaget DS9Test colorbar position >> ${tt}.out
xpaget DS9Test colorbar label position >> ${tt}.out
xpaget DS9Test colorbar numerics >> ${tt}.out
xpaget DS9Test colorbar space >> ${tt}.out
xpaget DS9Test colorbar foreground >> ${tt}.out
xpaget DS9Test colorbar background >> ${tt}.out
xpaget DS9Test colorbar font >> ${tt}.out
xpaget DS9Test colorbar fontsize >> ${tt}.out
xpaget DS9Test colorbar fontweight >> ${tt}.out
xpaget DS9Test colorbar fontslant >> ${tt}.out
xpaget DS9Test colorbar size >> ${tt}.out
xpaget DS9Test colorbar ticks >> ${tt}.out

xpaset -p DS9Test colorbar no
xpaset -p DS9Test colorbar yes
xpaset -p DS9Test colorbar vertical
xpaset -p DS9Test colorbar horizontal
# backward compatibility
xpaset -p DS9Test colorbar orientation horizontal
xpaset -p DS9Test colorbar show no
xpaset -p DS9Test colorbar show yes
xpaset -p DS9Test colorbar position bottom
xpaset -p DS9Test colorbar label position natural
xpaset -p DS9Test colorbar position bottom
xpaset -p DS9Test colorbar label position opposite
xpaset -p DS9Test colorbar position top
xpaset -p DS9Test colorbar label position natural
xpaset -p DS9Test colorbar position top
xpaset -p DS9Test colorbar label position opposite
xpaset -p DS9Test colorbar position left
xpaset -p DS9Test colorbar label position natural
xpaset -p DS9Test colorbar position left
xpaset -p DS9Test colorbar label position opposite
xpaset -p DS9Test colorbar position right
xpaset -p DS9Test colorbar label position natural
xpaset -p DS9Test colorbar position right
xpaset -p DS9Test colorbar label position opposite
xpaset -p DS9Test colorbar position bottom
xpaset -p DS9Test colorbar label position natural
xpaset -p DS9Test colorbar foreground red
xpaset -p DS9Test colorbar background blue
xpaset -p DS9Test colorbar foreground theme
xpaset -p DS9Test colorbar background theme
xpaset -p DS9Test colorbar numerics no
xpaset -p DS9Test colorbar numerics yes
xpaset -p DS9Test colorbar space value
xpaset -p DS9Test colorbar space distance
xpaset -p DS9Test colorbar font times
xpaset -p DS9Test colorbar fontsize 30
xpaset -p DS9Test colorbar fontweight bold
xpaset -p DS9Test colorbar fontslant italic
# backward compatibility
xpaset -p DS9Test colorbar fontstyle italic
xpaset -p DS9Test colorbar size 30
xpaset -p DS9Test colorbar ticks 9
xpaset -p DS9Test colorbar width 0.5
xpaset -p DS9Test colorbar center 1
xpaset -p DS9Test colorbar match
xpaset -p DS9Test colorbar lock yes
xpaset -p DS9Test colorbar lock no

xpaset -p DS9Test colorbar font helvetica
xpaset -p DS9Test colorbar fontsize 10
xpaset -p DS9Test colorbar fontweight normal
xpaset -p DS9Test colorbar fontslant roman
xpaset -p DS9Test colorbar size 20
xpaset -p DS9Test colorbar ticks 11
xpaset -p DS9Test colorbar width 1
xpaset -p DS9Test colorbar center 0.5

testit $tt
fi

tt="console"
if [ "$1" = "$tt" ]; then
echo -n "$tt..."
xpaset -p DS9Test console

testit $tt
fi

tt="contour"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt/contours..."
xpaset -p DS9Test contour yes
xpaset -p DS9Test contour open

xpaget DS9Test contour >> ${tt}.out
xpaget DS9Test contour color >> ${tt}.out
xpaget DS9Test contour width >> ${tt}.out
xpaget DS9Test contour smooth >> ${tt}.out
xpaget DS9Test contour method >> ${tt}.out
xpaget DS9Test contour nlevels >> ${tt}.out
xpaget DS9Test contour scale >> ${tt}.out
xpaget DS9Test contour log exp >> ${tt}.out
xpaget DS9Test contour mode >> ${tt}.out
xpaget DS9Test contour scope >> ${tt}.out
xpaget DS9Test contour limits >> ${tt}.out
xpaget DS9Test contour levels >> ${tt}.out

xpaget DS9Test contour wcs fk5 >> /dev/null

# load/save
xpaset -p DS9Test contour clear
# backward compatibility
xpaset -p DS9Test contour load aux/ds9.con wcs fk5 red 2 no
sleep $delay
#
xpaset -p DS9Test contour clear
xpaset -p DS9Test contour load aux/ds9.ctr
sleep $delay
xpaset -p DS9Test contour save foo.ctr
xpaset -p DS9Test contour save foo.ctr wcs fk5

# paste
xpaset -p DS9Test contour clear
xpaset -p DS9Test frame new
xpaset -p DS9Test fits fits/img.fits
xpaset -p DS9Test tile
xpaset -p DS9Test contour yes
xpaset -p DS9Test contour copy
xpaset -p DS9Test frame first
xpaset -p DS9Test contour clear
xpaset -p DS9Test contour paste
sleep $delay
xpaset -p DS9Test contour paste wcs red 2 yes
sleep $delay
xpaset -p DS9Test contour clear
xpaset -p DS9Test contour paste
sleep $delay
xpaset -p DS9Test frame next
xpaset -p DS9Test frame delete

xpaset -p DS9Test contour clear
xpaset -p DS9Test contour load levels aux/ds9.ctr
# backward compatibility
xpaset -p DS9Test contour loadlevels aux/ds9.ctr
sleep $delay
xpaset -p DS9Test contour clear
# backward compatibility
xpaset -p DS9Test contour loadlevels aux/ds9.lev

xpaset -p DS9Test contour save levels foo.lev
# backward compatibility
xpaset -p DS9Test contour savelevels foo.lev

xpaset -p DS9Test contour clear
xpaset -p DS9Test contour yes
xpaset -p DS9Test contour convert
xpaset -p DS9Test region delete all

xpaset -p DS9Test contour clear
xpaset -p DS9Test contour yes
xpaset -p DS9Test contour color blue
xpaset -p DS9Test contour width 2
xpaset -p DS9Test contour smooth 5
xpaset -p DS9Test contour method block
xpaset -p DS9Test contour nlevels 10
xpaset -p DS9Test contour width 2
xpaset -p DS9Test contour scale sqrt
xpaset -p DS9Test contour log exp 1000
xpaset -p DS9Test contour mode zscale
xpaset -p DS9Test contour scope local
xpaset -p DS9Test contour limits 1 100
xpaset -p DS9Test contour levels 1 10 100 1000

xpaset -p DS9Test contour clear
xpaset -p DS9Test contour close

testit $tt
fi

tt="crop"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaset -p DS9Test mode crop
xpaset -p DS9Test crop open
xpaset -p DS9Test crop  978 970  356 308
xpaget DS9Test crop >> ${tt}.out
xpaget DS9Test crop wcs fk5 sexagesimal arcsec >> ${tt}.out
xpaget DS9Test crop lock >> ${tt}.out

xpaset -p DS9Test crop 978 970  356 308
xpaset -p DS9Test crop 978 970  356 308 physical

xpaset -p DS9Test crop 202.470451 47.19394108 0.0097 0.0084 wcs
xpaset -p DS9Test crop 202.470451 47.19394108 35.279606 30.522805 wcs arcsec
xpaset -p DS9Test crop 202.470451 47.19394108 0.0097 0.0084 fk5
xpaset -p DS9Test crop 202.470451 47.19394108 35.279606 30.522805 fk5 arcsec
xpaset -p DS9Test crop 202.470451 47.19394108 0.0097 0.0084 wcs fk5
xpaset -p DS9Test crop 202.470451 47.19394108 35.279606 30.522805 wcs fk5 arcsec

xpaset -p DS9Test crop 13:29:52.908 +47:11:38.19 0.0097 0.0084
xpaset -p DS9Test crop 13:29:52.908 +47:11:38.19 0.0097 0.0084 wcs
xpaset -p DS9Test crop 13:29:52.908 +47:11:38.19 35.279606 30.522805 wcs arcsec
xpaset -p DS9Test crop 13:29:52.908 +47:11:38.19 0.0097 0.0084 fk5
xpaset -p DS9Test crop 13:29:52.908 +47:11:38.19 35.279606 30.522805 fk5 arcsec
xpaset -p DS9Test crop 13:29:52.908 +47:11:38.19 0.0097 0.0084 wcs fk5
xpaset -p DS9Test crop 13:29:52.908 +47:11:38.19 35.279606 30.522805 wcs fk5 arcsec

xpaset -p DS9Test crop reset
xpaset -p DS9Test 3d
xpaset -p DS9Test fits data/3d.fits
xpaset -p DS9Test 3d vp 45 30
xpaset -p DS9Test crop 3d 25 75
xpaset -p DS9Test crop reset
xpaset -p DS9Test crop match wcs
xpaset -p DS9Test crop lock wcs
xpaset -p DS9Test crop lock none
xpaset -p DS9Test frame delete
xpaset -p DS9Test mode none

xpaset -p DS9Test crop close
xpaset -p DS9Test 3d close
xpaset -p DS9Test cube close
testit $tt
fi

tt="crosshair"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaset -p DS9Test mode crosshair
xpaget DS9Test crosshair >> ${tt}.out
xpaget DS9Test crosshair wcs fk5 sexagesimal >> ${tt}.out
xpaget DS9Test crosshair lock >> ${tt}.out

xpaset -p DS9Test crosshair 978 970
xpaset -p DS9Test crosshair 978 970 physical
xpaset -p DS9Test crosshair 202.470451 47.19394108 wcs
xpaset -p DS9Test crosshair 202.470451 47.19394108 fk5
xpaset -p DS9Test crosshair 202.470451 47.19394108 wcs fk5

xpaset -p DS9Test crosshair 13:29:52.908 +47:11:38.19
xpaset -p DS9Test crosshair 13:29:52.908 +47:11:38.19 wcs
xpaset -p DS9Test crosshair 13:29:52.908 +47:11:38.19 fk5
xpaset -p DS9Test crosshair 13:29:52.908 +47:11:38.19 wcs fk5

xpaset -p DS9Test crosshair match wcs
xpaset -p DS9Test crosshair lock wcs
xpaset -p DS9Test crosshair lock none
xpaset -p DS9Test mode none

testit $tt
fi

tt="cube"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt/datacube..."
xpaset -p DS9Test cube open
xpaset -p DS9Test cube close
xpaset -p DS9Test fits new data/3d.fits
xpaget DS9Test cube >> ${tt}.out
xpaget DS9Test cube wcs >> /dev/null
xpaget DS9Test cube interval >> ${tt}.out
xpaget DS9Test cube axis >> ${tt}.out
xpaget DS9Test cube lock >> ${tt}.out
xpaget DS9Test cube order >> ${tt}.out
xpaget DS9Test cube axes lock >> ${tt}.out
xpaset -p DS9Test cube 2
xpaset -p DS9Test cube interval .5
xpaset -p DS9Test cube axis 3
xpaset -p DS9Test cube play
xpaset -p DS9Test cube stop
xpaset -p DS9Test cube match wcs
xpaset -p DS9Test cube lock wcs
xpaset -p DS9Test cube lock none
xpaset -p DS9Test cube order 321
xpaset -p DS9Test cube order 123
xpaset -p DS9Test cube axes lock yes
xpaset -p DS9Test cube axes lock no
xpaset -p DS9Test frame delete

xpaset -p DS9Test cube close
testit $tt
fi

tt="cursor"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaset -p DS9Test mode crosshair
xpaset -p DS9Test cursor 10 10
xpaset -p DS9Test mode none

testit $tt
fi

tt="data"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaget DS9Test data image 450 520 3 3 yes >> ${tt}.out
xpaget DS9Test data physical 899 1039 6 6 no >> ${tt}.out
xpaget DS9Test data fk5 202.4709 47.19681 0.00016517 0.00016517 yes >> ${tt}.out
xpaget DS9Test data wcs fk5 202.4709 47.19681 0.00016517 0.00016517 no >> ${tt}.out

testit $tt
fi

tt="dsssao"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt/dss... skipped\n"
#~ xpaset -p DS9Test dsssao open
#~ xpaset -p DS9Test dsssao close
#~ xpaset -p DS9Test dsssao size 30 30 arcsec
#~ xpaget DS9Test dsssao size >> ${tt}.out
#~ xpaset -p DS9Test dsssao save no
#~ xpaget DS9Test dsssao save >> ${tt}.out
#~ xpaset -p DS9Test dsssao frame new
#~ xpaget DS9Test dsssao frame >> ${tt}.out
#~ xpaset -p DS9Test dsssao update frame
#~ xpaset -p DS9Test dsssao m51
#~ xpaset -p DS9Test dsssao name m51
#~ xpaget DS9Test dsssao name >> ${tt}.out
#~ xpaset -p DS9Test dsssao name clear
#~ xpaset -p DS9Test dsssao 13:29:52.37 +47:11:40.8
#~ # backward compatibility
#~ xpaset -p DS9Test dsssao coord 13:29:52.37 +47:11:40.8 sexagesimal
#~ xpaget DS9Test dsssao coord >> ${tt}.out
#~ xpaset -p DS9Test dsssao update frame
#~ xpaset -p DS9Test mode crosshair
#~ xpaset -p DS9Test dsssao update crosshair
#~ xpaset -p DS9Test dsssao close
#~ xpaset -p DS9Test mode none
#~ xpaset -p DS9Test frame delete
#~ xpaset -p DS9Test frame delete
#~ xpaset -p DS9Test frame delete
#~ xpaset -p DS9Test frame delete
#~ xpaset -p DS9Test frame delete
#~ xpaset -p DS9Test frame delete
#~ xpaset -p DS9Test frame delete
#~ testit $tt
fi

tt="dsseso"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaset -p DS9Test dsseso open
xpaset -p DS9Test dsseso close
xpaset -p DS9Test dsseso survey DSS1
xpaget DS9Test dsseso survey >> ${tt}.out
xpaset -p DS9Test dsseso size 30 30 arcsec
xpaget DS9Test dsseso size >> ${tt}.out
xpaset -p DS9Test dsseso save no
xpaget DS9Test dsseso save >> ${tt}.out
xpaset -p DS9Test dsseso frame new
xpaget DS9Test dsseso frame >> ${tt}.out
xpaset -p DS9Test dsseso update frame
xpaset -p DS9Test dsseso m51
xpaset -p DS9Test dsseso name m51
xpaget DS9Test dsseso name >> ${tt}.out
xpaset -p DS9Test dsseso name clear
xpaset -p DS9Test dsseso 13:29:52.37 +47:11:40.8
# backward compatibility
xpaset -p DS9Test dsseso coord 13:29:52.37 +47:11:40.8 sexagesimal
xpaget DS9Test dsseso coord >> ${tt}.out
xpaset -p DS9Test dsseso update frame
xpaset -p DS9Test mode crosshair
xpaset -p DS9Test dsseso update crosshair
xpaset -p DS9Test dsseso close
xpaset -p DS9Test mode none
xpaset -p DS9Test frame delete
xpaset -p DS9Test frame delete
xpaset -p DS9Test frame delete
xpaset -p DS9Test frame delete
xpaset -p DS9Test frame delete
xpaset -p DS9Test frame delete
xpaset -p DS9Test frame delete

testit $tt
fi

tt="dssstsci"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaset -p DS9Test dssstsci open
xpaset -p DS9Test dssstsci close
xpaset -p DS9Test dssstsci survey all
xpaget DS9Test dssstsci survey >> ${tt}.out
xpaset -p DS9Test dssstsci size 30 30 arcsec
xpaget DS9Test dssstsci size >> ${tt}.out
xpaset -p DS9Test dssstsci save no
xpaget DS9Test dssstsci save >> ${tt}.out
xpaset -p DS9Test dssstsci frame new
xpaget DS9Test dssstsci frame >> ${tt}.out
xpaset -p DS9Test dssstsci update frame
xpaset -p DS9Test dssstsci m51
xpaset -p DS9Test dssstsci name m51
xpaget DS9Test dssstsci name >> ${tt}.out
xpaset -p DS9Test dssstsci name clear
xpaset -p DS9Test dssstsci 13:29:52.37 +47:11:40.8
# backward compatibility
xpaset -p DS9Test dssstsci coord 13:29:52.37 +47:11:40.8 sexagesimal
xpaget DS9Test dssstsci coord >> ${tt}.out
xpaset -p DS9Test dssstsci update frame
xpaset -p DS9Test mode crosshair
xpaset -p DS9Test dssstsci update crosshair
xpaset -p DS9Test dssstsci close
xpaset -p DS9Test mode none
xpaset -p DS9Test frame delete
xpaset -p DS9Test frame delete
xpaset -p DS9Test frame delete
xpaset -p DS9Test frame delete
xpaset -p DS9Test frame delete
xpaset -p DS9Test frame delete
xpaset -p DS9Test frame delete

testit $tt
fi

tt="envi"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaset -p DS9Test frame new
xpaset -p DS9Test envi envi/cube_float_little.hdr envi/cube_float_little.bsq
xpaset -p DS9Test envi envi/cube_float_little.hdr
xpaset -p DS9Test frame delete
xpaset -p DS9Test envi new envi/cube_float_little.hdr envi/cube_float_little.bsq
xpaset -p DS9Test frame delete
testit $tt
fi

tt="export"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaset -p DS9Test export array foo.arr little
xpaset -p DS9Test export foo.arr
xpaset -p DS9Test export nrrd foo.nrrd big
xpaset -p DS9Test export foo.nrrd
xpaset -p DS9Test export gif foo.gif
xpaset -p DS9Test export foo.gif
xpaset -p DS9Test export tiff foo.tiff none
xpaset -p DS9Test export foo.tiff
xpaset -p DS9Test export jpeg foo.jpeg 10
xpaset -p DS9Test export foo.jpeg
xpaset -p DS9Test export png foo.png
xpaset -p DS9Test export foo.png

xpaset -p DS9Test frame new rgb
xpaset -p DS9Test rgbcube rgb/rgbcube.fits
xpaset -p DS9Test export rgbarray foo.arr little
xpaset -p DS9Test export foo.arr
xpaset -p DS9Test export foo.png
xpaset -p DS9Test frame delete
xpaset -p DS9Test rgb close

xpaset -p DS9Test frame new hls
xpaset -p DS9Test hlscube hls/hlscube.fits
xpaset -p DS9Test export hlsarray foo.arr little
xpaset -p DS9Test export foo.arr
xpaset -p DS9Test frame delete
xpaset -p DS9Test hls close

xpaset -p DS9Test frame new hsv
xpaset -p DS9Test hsvcube hsv/hsvcube.fits
xpaset -p DS9Test export hsvarray foo.arr little
xpaset -p DS9Test export foo.arr
xpaset -p DS9Test frame delete
xpaset -p DS9Test hsv close

testit $tt
fi

tt="fade"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaget DS9Test fade >> ${tt}.out
xpaget DS9Test fade interval >> ${tt}.out
xpaset -p DS9Test frame new
xpaset -p DS9Test fade
xpaset -p DS9Test fade yes
xpaset -p DS9Test fade interval 2
xpaset -p DS9Test single
xpaset -p DS9Test frame first
xpaset -p DS9Test frame next
xpaset -p DS9Test frame delete

testit $tt
fi

# backward compatibility
tt="file"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo "$tt...backward compatibility..."
xpaget DS9Test file >> ${tt}.out

echo -n " default..."
xpaset -p DS9Test frame new
xpaset -p DS9Test file fits/float.fits
xpaset -p DS9Test frame delete

xpaset -p DS9Test file new fits/float.fits
xpaset -p DS9Test file slice fits/float.fits
xpaset -p DS9Test file mask fits/float.fits
xpaset -p DS9Test frame delete
echo "PASSED"

echo -n " fits..."
xpaset -p DS9Test frame new
xpaset -p DS9Test file fits fits/float.fits
xpaset -p DS9Test frame delete

xpaset -p DS9Test file new fits fits/float.fits
xpaset -p DS9Test file fits slice fits/float.fits
xpaset -p DS9Test file mask fits fits/float.fits
xpaset -p DS9Test frame delete
echo "PASSED"

echo -n " url..."
xpaset -p DS9Test frame new
xpaset -p DS9Test file url http://ds9.si.edu/download/data/img.fits
xpaset -p DS9Test frame delete
echo "PASSED"

echo -n " mecube..."
xpaset -p DS9Test frame new
xpaset -p DS9Test file mecube mecube/float.fits
xpaset -p DS9Test frame delete

xpaset -p DS9Test file new mecube mecube/float.fits
xpaset -p DS9Test frame delete
echo "PASSED"

echo -n " multiframe..."
xpaset -p DS9Test frame new
xpaset -p DS9Test file multiframe mecube/float.fits
xpaset -p DS9Test frame delete
xpaset -p DS9Test frame delete
xpaset -p DS9Test frame delete
xpaset -p DS9Test single
echo "PASSED"

echo -n " mosaic..."
xpaset -p DS9Test frame new
xpaset -p DS9Test file mosaic mosaic/mosaicimage.fits
xpaset -p DS9Test frame clear
xpaset -p DS9Test file mosaic wcs mosaic/mosaicimage.fits
xpaset -p DS9Test frame clear
xpaset -p DS9Test file mosaic iraf mosaic/mosaicimage.fits
xpaset -p DS9Test frame delete

xpaset -p DS9Test file new mosaic mosaic/mosaicimage.fits
xpaset -p DS9Test file mask mosaic mosaic/mosaicimage.fits
xpaset -p DS9Test frame delete
echo "PASSED"

echo -n " mosaicimage..."
xpaset -p DS9Test frame new
xpaset -p DS9Test file mosaicimage mosaic/mosaicimage.fits
xpaset -p DS9Test frame clear
xpaset -p DS9Test file mosaicimage wcs mosaic/mosaicimage.fits
xpaset -p DS9Test frame clear
xpaset -p DS9Test file mosaicimage iraf mosaic/mosaicimage.fits
xpaset -p DS9Test frame clear
xpaset -p DS9Test file mosaicimage wfpc2 mosaic/hst.fits
xpaset -p DS9Test frame delete

xpaset -p DS9Test file new mosaicimage mosaic/mosaicimage.fits
xpaset -p DS9Test file mask mosaicimage mosaic/mosaicimage.fits
xpaset -p DS9Test frame delete
echo "PASSED"

echo -n " mosaicwcs..."
xpaset -p DS9Test frame new
xpaset -p DS9Test file mosaicwcs mosaic/mosaicimage.fits
xpaset -p DS9Test frame delete

xpaset -p DS9Test file new mosaicwcs mosaic/mosaicimage.fits
xpaset -p DS9Test file mask mosaicwcs mosaic/mosaicimage.fits
xpaset -p DS9Test frame delete
echo "PASSED"

echo -n " mosaiciraf..."
xpaset -p DS9Test frame new
xpaset -p DS9Test file mosaiciraf mosaic/mosaicimage.fits
xpaset -p DS9Test frame delete

xpaset -p DS9Test file new mosaiciraf mosaic/mosaicimage.fits
xpaset -p DS9Test file mask mosaiciraf mosaic/mosaicimage.fits
xpaset -p DS9Test frame delete
echo "PASSED"

echo -n " mosaicimagewcs..."
xpaset -p DS9Test frame new
xpaset -p DS9Test file mosaicimagewcs mosaic/mosaicimage.fits
xpaset -p DS9Test frame delete

xpaset -p DS9Test file new mosaicimagewcs mosaic/mosaicimage.fits
xpaset -p DS9Test file mask mosaicimagewcs mosaic/mosaicimage.fits
xpaset -p DS9Test frame delete
echo "PASSED"

echo -n " mosaicimageiraf..."
xpaset -p DS9Test frame new
xpaset -p DS9Test file mosaicimageiraf mosaic/mosaicimage.fits
xpaset -p DS9Test frame delete

xpaset -p DS9Test file new mosaicimageiraf mosaic/mosaicimage.fits
xpaset -p DS9Test file mask mosaicimageiraf mosaic/mosaicimage.fits
xpaset -p DS9Test frame delete
echo "PASSED"

echo -n " mosaicimagewfpc2..."
xpaset -p DS9Test frame new
xpaset -p DS9Test file mosaicimagewfpc2 mosaic/hst.fits
xpaset -p DS9Test frame delete

xpaset -p DS9Test file new mosaicimagewfpc2 mosaic/hst.fits
xpaset -p DS9Test file mask mosaicimagewfpc2 mosaic/hst.fits
xpaset -p DS9Test frame delete
echo "PASSED"

echo -n " array..."
xpaset -p DS9Test frame new
xpaset -p DS9Test file array array/float_big.arr[dim=256,bitpix=-32,endian=big]
xpaset -p DS9Test frame delete

xpaset -p DS9Test file new array array/float_big.arr[dim=256,bitpix=-32,endian=big]
xpaset -p DS9Test file mask array array/float_big.arr[dim=256,bitpix=-32,endian=big]
xpaset -p DS9Test frame delete
echo "PASSED"

echo -n " rgbarray..."
xpaset -p DS9Test frame new rgb
xpaset -p DS9Test file rgbarray rgb/rgb.arr[dim=1600,bitpix=-32,endian=little]
xpaset -p DS9Test frame delete

xpaset -p DS9Test file new rgbarray rgb/rgb.arr[dim=1600,bitpix=-32,endian=little]
xpaset -p DS9Test frame delete
echo "PASSED"

echo -n " rgbimage..."
xpaset -p DS9Test frame new rgb
xpaset -p DS9Test file rgbimage rgb/rgbimage.fits
xpaset -p DS9Test frame delete

xpaset -p DS9Test file new rgbimage rgb/rgbimage.fits
xpaset -p DS9Test frame delete
echo "PASSED"

echo -n " rgbcube..."
xpaset -p DS9Test frame new rgb
xpaset -p DS9Test file rgbcube rgb/rgbcube.fits
xpaset -p DS9Test frame delete

xpaset -p DS9Test file new rgbcube rgb/rgbcube.fits
xpaset -p DS9Test frame delete
echo "PASSED"

echo -n " hlsarray..."
xpaset -p DS9Test frame new hls
xpaset -p DS9Test file hlsarray hls/hls.arr[xdim=1389,ydim=1387,bitpix=-64,endian=little]
xpaset -p DS9Test frame delete

xpaset -p DS9Test file new hlsarray hls/hls.arr[xdim=1389,ydim=1387,bitpix=-64,endian=little]
xpaset -p DS9Test frame delete
echo "PASSED"

echo -n " hlsimage..."
xpaset -p DS9Test frame new hls
xpaset -p DS9Test file hlsimage hls/hlsimage.fits
xpaset -p DS9Test frame delete

xpaset -p DS9Test file new hlsimage hls/hlsimage.fits
xpaset -p DS9Test frame delete
echo "PASSED"

echo -n " hlscube..."
xpaset -p DS9Test frame new hls
xpaset -p DS9Test file hlscube hls/hlscube.fits
xpaset -p DS9Test frame delete

xpaset -p DS9Test file new hlscube hls/hlscube.fits
xpaset -p DS9Test frame delete
echo "PASSED"

echo -n " hsvarray..."
xpaset -p DS9Test frame new hsv
xpaset -p DS9Test file hsvarray hsv/hsv.arr[xdim=1389,ydim=1387,bitpix=-64,endian=little]
xpaset -p DS9Test frame delete

xpaset -p DS9Test file new hsvarray hsv/hsv.arr[xdim=1389,ydim=1387,bitpix=-64,endian=little]
xpaset -p DS9Test frame delete
echo "PASSED"

echo -n " hsvimage..."
xpaset -p DS9Test frame new hsv
xpaset -p DS9Test file hsvimage hsv/hsvimage.fits
xpaset -p DS9Test frame delete

xpaset -p DS9Test file new hsvimage hsv/hsvimage.fits
xpaset -p DS9Test frame delete
echo "PASSED"

echo -n " hsvcube..."
xpaset -p DS9Test frame new hsv
xpaset -p DS9Test file hsvcube hsv/hsvcube.fits
xpaset -p DS9Test frame delete

xpaset -p DS9Test file new hsvcube hsv/hsvcube.fits
xpaset -p DS9Test frame delete
echo "PASSED"

echo -n " photo..."
xpaset -p DS9Test frame new
xpaset -p DS9Test file photo photo/rose.tiff
xpaset -p DS9Test frame delete

xpaset -p DS9Test file new photo photo/rose.tiff
xpaset -p DS9Test file photo slice photo/rose.tiff
xpaset -p DS9Test frame delete
echo "PASSED"

echo -n " file save..."
xpaset -p DS9Test file save foo.fits
echo "PASSED"

echo -n " file save gz..."
xpaset -p DS9Test file save gz foo.fits.gz
echo "PASSED"

echo -n " file save resample..."
xpaset -p DS9Test file save resample foo.fits
echo "PASSED"

echo -n " file save resample gz..."
xpaset -p DS9Test file save resample gz foo.fits.gz
echo "PASSED"

xpaset -p DS9Test rgb close
xpaset -p DS9Test hls close
xpaset -p DS9Test hsv close
xpaset -p DS9Test cube close
testit $tt
fi

tt="fits"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaget DS9Test fits > /dev/null
xpaget DS9Test fits image > /dev/null
xpaget DS9Test fits slice > /dev/null

cat fits/table.fits | xpaset DS9Test fits new
xpaget DS9Test fits table > /dev/null
xpaset -p DS9Test frame delete

xpaset -p DS9Test frame new
xpaset -p DS9Test fits fits/float.fits
xpaset -p DS9Test frame delete

xpaset -p DS9Test fits new fits/float.fits
xpaset -p DS9Test fits slice fits/float.fits
xpaset -p DS9Test fits mask fits/float.fits
xpaset -p DS9Test frame delete

xpaget DS9Test fits size >> ${tt}.out
xpaget DS9Test fits width >> ${tt}.out
xpaget DS9Test fits height >> ${tt}.out
xpaget DS9Test fits depth >> ${tt}.out
xpaget DS9Test fits bitpix >> ${tt}.out
# backward compatibility
xpaget DS9Test fits type >> ${tt}.out
xpaget DS9Test fits size wcs fk5 arcsec >> ${tt}.out
xpaget DS9Test fits count >> ${tt}.out
xpaget DS9Test fits header >> /dev/null
xpaget DS9Test fits header 1 >> /dev/null
xpaget DS9Test fits header keyword BITPIX >> ${tt}.out
xpaget DS9Test fits header 1 keyword BITPIX >> ${tt}.out
xpaset -p DS9Test single

# backward compatibility
xpaget DS9Test fits image > /dev/null
xpaget DS9Test fits image gz > /dev/null
xpaget DS9Test fits resample > /dev/null
xpaget DS9Test fits resample gz > /dev/null
xpaset -p DS9Test frame new
xpaset -p DS9Test fits fits/table.fits
xpaget DS9Test fits table > /dev/null
xpaget DS9Test fits table gz> /dev/null
xpaset -p DS9Test frame delete

xpaset -p DS9Test frame new
cat mecube/float.fits | xpaset DS9Test fits mecube
xpaset -p DS9Test frame delete
cat mecube/float.fits | xpaset DS9Test fits new mecube
xpaset -p DS9Test frame delete

xpaset -p DS9Test frame new
cat mosaic/mosaicimage.fits | xpaset DS9Test fits mosaicimage
cat mosaic/mosaicimage.fits | xpaset DS9Test fits mosaicimage wcs
xpaset -p DS9Test frame delete
cat mosaic/mosaicimage.fits | xpaset DS9Test fits new mosaicimage
cat mosaic/mosaicimage.fits | xpaset DS9Test fits mask mosaicimage
xpaset -p DS9Test frame delete

xpaset -p DS9Test frame new
cat mosaic/mosaicimage.fits | xpaset DS9Test fits mosaicimagewcs
xpaset -p DS9Test frame delete
cat mosaic/mosaicimage.fits | xpaset DS9Test fits new mosaicimagewcs
cat mosaic/mosaicimage.fits | xpaset DS9Test fits mask mosaicimagewcs
xpaset -p DS9Test frame delete

xpaset -p DS9Test frame new
cat mosaic/mosaicimage.fits | xpaset DS9Test fits mosaicimageiraf
xpaset -p DS9Test frame delete
cat mosaic/mosaicimage.fits | xpaset DS9Test fits new mosaicimageiraf
cat mosaic/mosaicimage.fits | xpaset DS9Test fits mask mosaicimageiraf
xpaset -p DS9Test frame delete

xpaset -p DS9Test frame new
cat mosaic/hst.fits | xpaset DS9Test fits mosaicimagewfpc2
xpaset -p DS9Test frame delete
cat mosaic/hst.fits | xpaset DS9Test fits new mosaicimagewfpc2
cat mosaic/hst.fits | xpaset DS9Test fits mask mosaicimagewfpc2
xpaset -p DS9Test frame delete

xpaset -p DS9Test frame new rgb
cat rgb/rgbimage.fits | xpaset DS9Test fits rgbimage
xpaset -p DS9Test frame delete
cat rgb/rgbimage.fits | xpaset DS9Test fits new rgbimage
xpaset -p DS9Test frame delete

xpaset -p DS9Test frame new rgb
cat rgb/rgbcube.fits | xpaset DS9Test fits rgbcube
xpaset -p DS9Test frame delete
cat rgb/rgbcube.fits | xpaset DS9Test fits new rgbcube
xpaset -p DS9Test frame delete

xpaset -p DS9Test frame new hls
cat hls/hlsimage.fits | xpaset DS9Test fits hlsimage
xpaset -p DS9Test frame delete
cat hls/hlsimage.fits | xpaset DS9Test fits new hlsimage
xpaset -p DS9Test frame delete

xpaset -p DS9Test frame new hls
cat hls/hlscube.fits | xpaset DS9Test fits hlscube
xpaset -p DS9Test frame delete
cat hls/hlscube.fits | xpaset DS9Test fits new hlscube
xpaset -p DS9Test frame delete

xpaset -p DS9Test frame new hsv
cat hsv/hsvimage.fits | xpaset DS9Test fits hsvimage
xpaset -p DS9Test frame delete
cat hsv/hsvimage.fits | xpaset DS9Test fits new hsvimage
xpaset -p DS9Test frame delete

xpaset -p DS9Test frame new hsv
cat hsv/hsvcube.fits | xpaset DS9Test fits hsvcube
xpaset -p DS9Test frame delete
cat hsv/hsvcube.fits | xpaset DS9Test fits new hsvcube
xpaset -p DS9Test frame delete

xpaset -p DS9Test rgb close
xpaset -p DS9Test hls close
xpaset -p DS9Test hsv close
xpaset -p DS9Test cube close
testit $tt
fi

tt="footprint"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt/fp..."
xpaset -p DS9Test footprint cxc
#xpaset -p DS9Test footprint hla
xpaset -p DS9Test footprint current cxc

xpaget DS9Test footprint >> ${tt}.out
xpaset -p DS9Test footprint save foo.xml
xpaset -p DS9Test footprint export rdb foo.rdb
xpaset -p DS9Test footprint export tsv foo.tsv

xpaset -p DS9Test footprint name m51
xpaset -p DS9Test footprint coordinate 202.48 47.21 fk5
xpaset -p DS9Test footprint system wcs
xpaset -p DS9Test footprint sky fk5
xpaset -p DS9Test footprint skyformat degrees
xpaset -p DS9Test footprint radius 22 arcmin
# backward compatibility
xpaset -p DS9Test footprint size 20 24 arcmin
xpaset -p DS9Test footprint retrieve
xpaset -p DS9Test footprint crosshair
xpaset -p DS9Test footprint regions
xpaset -p DS9Test region delete all
xpaset -p DS9Test footprint filter '$ObsId<10000'
xpaset -p DS9Test footprint filter load aux/fp.flt
xpaset -p DS9Test footprint retrieve
xpaset -p DS9Test footprint cancel
#xpaset -p DS9Test footprint print
xpaset -p DS9Test footprint sort "ObsId" incr
# backward compatibility
xpaset -p DS9Test footprint hide
xpaset -p DS9Test footprint show yes
xpaset -p DS9Test footprint panto no

xpaset -p DS9Test footprint clear
xpaset -p DS9Test footprint close
xpaset -p DS9Test footprint clear
xpaset -p DS9Test footprint close

testit $tt
fi

tt="frame"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaget DS9Test frame lock >> ${tt}.out
xpaget DS9Test frame has amplifier >> ${tt}.out
xpaget DS9Test frame has datamin >> ${tt}.out
xpaget DS9Test frame has datasec >> ${tt}.out
xpaget DS9Test frame has detector >> ${tt}.out
xpaget DS9Test frame has grid >> ${tt}.out
xpaget DS9Test frame has iis >> ${tt}.out
xpaget DS9Test frame has irafmin >> ${tt}.out
xpaget DS9Test frame has physical >> ${tt}.out
xpaget DS9Test frame has smooth >> ${tt}.out
xpaget DS9Test frame has contour >> ${tt}.out
xpaget DS9Test frame has contour aux >> ${tt}.out
xpaget DS9Test frame has fits >> ${tt}.out
xpaget DS9Test frame has fits bin >> ${tt}.out
xpaget DS9Test frame has fits cube >> ${tt}.out
xpaget DS9Test frame has fits mosaic >> ${tt}.out
xpaget DS9Test frame has marker highlite >> ${tt}.out
xpaget DS9Test frame has marker paste >> ${tt}.out
xpaget DS9Test frame has marker select >> ${tt}.out
xpaget DS9Test frame has marker undo >> ${tt}.out
xpaget DS9Test frame has system physical >> ${tt}.out
xpaget DS9Test frame has wcs wcsa >> ${tt}.out
xpaget DS9Test frame has wcs celestial wcsa >> ${tt}.out
xpaget DS9Test frame has wcs linear wcsa >> ${tt}.out
xpaset -p DS9Test frame new rgb
xpaset -p DS9Test frame delete
xpaset -p DS9Test frame new hls
xpaset -p DS9Test frame delete
xpaset -p DS9Test frame new hsv
xpaset -p DS9Test frame delete
xpaset -p DS9Test frame new 3d
xpaset -p DS9Test frame delete
xpaset -p DS9Test frame new
xpaset -p DS9Test fits fits/img.fits
xpaset -p DS9Test tile
xpaget DS9Test frame > /dev/null
xpaget DS9Test frame frameno > /dev/null
xpaget DS9Test frame all > /dev/null
xpaget DS9Test frame active > /dev/null
xpaset -p DS9Test frame center
xpaset -p DS9Test frame center 1
xpaset -p DS9Test frame center all
xpaset -p DS9Test frame reset
xpaset -p DS9Test frame reset 1
xpaset -p DS9Test frame reset all
xpaset -p DS9Test frame refresh
xpaset -p DS9Test frame refresh 1
xpaset -p DS9Test frame refresh all
xpaset -p DS9Test frame hide
xpaset -p DS9Test frame hide 1
xpaset -p DS9Test frame hide all
xpaset -p DS9Test frame show
xpaset -p DS9Test frame show 1
xpaset -p DS9Test frame show all
xpaset -p DS9Test frame move first
xpaset -p DS9Test frame move back
xpaset -p DS9Test frame move forward
xpaset -p DS9Test frame move last
xpaset -p DS9Test frame first
xpaset -p DS9Test frame prev
xpaset -p DS9Test frame next
xpaset -p DS9Test frame last
xpaset -p DS9Test frame frameno 1
xpaset -p DS9Test frame 2
xpaset -p DS9Test frame match wcs
xpaset -p DS9Test frame lock wcs
xpaset -p DS9Test frame lock none
xpaset -p DS9Test frame clear
xpaset -p DS9Test frame clear 1
xpaset -p DS9Test frame clear all
xpaset -p DS9Test frame delete
xpaset -p DS9Test frame delete 1
xpaset -p DS9Test frame delete all
xpaset -p DS9Test fits new fits/img.fits

xpaset -p DS9Test rgb close
xpaset -p DS9Test hls close
xpaset -p DS9Test hsv close
xpaset -p DS9Test 3d close
xpaset -p DS9Test cube close
testit $tt
fi

tt="gif"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaset -p DS9Test frame new
xpaset -p DS9Test gif photo/rose.gif
cat photo/rose.gif | xpaset DS9Test gif
xpaget DS9Test gif > /dev/null
xpaset -p DS9Test frame delete

xpaset -p DS9Test gif new photo/rose.gif
xpaset -p DS9Test gif slice photo/rose.gif
xpaset -p DS9Test frame delete

xpaset -p DS9Test cube close

testit $tt
fi

tt="graph"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaget DS9Test graph grid >> ${tt}.out
xpaget DS9Test graph log >> ${tt}.out
xpaget DS9Test graph method >> ${tt}.out
xpaget DS9Test graph font >> ${tt}.out
xpaget DS9Test graph fontsize >> ${tt}.out
xpaget DS9Test graph fontweight >> ${tt}.out
xpaget DS9Test graph fontslant >> ${tt}.out
xpaget DS9Test graph size >> ${tt}.out
xpaget DS9Test graph thickness >> ${tt}.out

xpaset -p DS9Test graph open
xpaset -p DS9Test graph close
xpaset -p DS9Test graph grid yes
xpaset -p DS9Test graph log no
xpaset -p DS9Test graph method average
xpaset -p DS9Test graph font helvetica
xpaset -p DS9Test graph fontsize 9
xpaset -p DS9Test graph fontweight normal
xpaset -p DS9Test graph fontslant roman
xpaset -p DS9Test graph size 150
xpaset -p DS9Test graph thickness 1

testit $tt
fi

tt="grid"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaset -p DS9Test wcs wcs
xpaget DS9Test grid >> ${tt}.out

xpaget DS9Test grid type >> ${tt}.out
xpaget DS9Test grid system >> ${tt}.out
xpaget DS9Test grid sky >> ${tt}.out
xpaget DS9Test grid skyformat >> ${tt}.out

xpaget DS9Test grid grid >> ${tt}.out
xpaget DS9Test grid grid color >> ${tt}.out
xpaget DS9Test grid grid width >> ${tt}.out
xpaget DS9Test grid grid dash >> ${tt}.out
# backward compatibilty
xpaget DS9Test grid grid style >> ${tt}.out
xpaget DS9Test grid grid gap1 >> ${tt}.out
xpaget DS9Test grid grid gap2 >> ${tt}.out
xpaget DS9Test grid grid gap3 >> ${tt}.out

xpaget DS9Test grid axes >> ${tt}.out
xpaget DS9Test grid axes color >> ${tt}.out
xpaget DS9Test grid axes width >> ${tt}.out
xpaget DS9Test grid axes dash >> ${tt}.out
# backward compatibilty
xpaget DS9Test grid axes style >> ${tt}.out
xpaget DS9Test grid axes type >> ${tt}.out
xpaget DS9Test grid axes origin >> ${tt}.out

xpaget DS9Test grid format1 >> ${tt}.out
xpaget DS9Test grid format2 >> ${tt}.out

xpaget DS9Test grid tickmarks >> ${tt}.out
xpaget DS9Test grid tickmarks color >> ${tt}.out
xpaget DS9Test grid tickmarks width >> ${tt}.out
xpaget DS9Test grid tickmarks dash >> ${tt}.out
# backward compatibilty
xpaget DS9Test grid tickmarks style >> ${tt}.out

xpaget DS9Test grid border >> ${tt}.out
xpaget DS9Test grid border color >> ${tt}.out
xpaget DS9Test grid border width >> ${tt}.out
xpaget DS9Test grid border dash >> ${tt}.out
# backward compatibilty
xpaget DS9Test grid border style >> ${tt}.out

xpaget DS9Test grid numerics >> ${tt}.out
xpaget DS9Test grid numerics font >> ${tt}.out
xpaget DS9Test grid numerics fontsize >> ${tt}.out
xpaget DS9Test grid numerics fontweight >> ${tt}.out
xpaget DS9Test grid numerics fontslant >> ${tt}.out
# backward compatibilty
xpaget DS9Test grid numerics fontstyle >> ${tt}.out
xpaget DS9Test grid numerics color >> ${tt}.out
xpaget DS9Test grid numerics gap1 >> ${tt}.out
xpaget DS9Test grid numerics gap2 >> ${tt}.out
xpaget DS9Test grid numerics gap3 >> ${tt}.out
xpaget DS9Test grid numerics type >> ${tt}.out
xpaget DS9Test grid numerics vertical >> ${tt}.out

xpaget DS9Test grid title >> ${tt}.out
xpaget DS9Test grid title text >> ${tt}.out
xpaget DS9Test grid title def >> ${tt}.out
xpaget DS9Test grid title gap >> ${tt}.out
xpaget DS9Test grid title font >> ${tt}.out
xpaget DS9Test grid title fontsize >> ${tt}.out
xpaget DS9Test grid title fontweight >> ${tt}.out
xpaget DS9Test grid title fontslant >> ${tt}.out
# backward compatibilty
xpaget DS9Test grid title fontstyle >> ${tt}.out
xpaget DS9Test grid title color >> ${tt}.out

xpaget DS9Test grid labels >> ${tt}.out
xpaget DS9Test grid labels text1 >> ${tt}.out
xpaget DS9Test grid labels def1 >> ${tt}.out
xpaget DS9Test grid labels gap1 >> ${tt}.out
xpaget DS9Test grid labels text2 >> ${tt}.out
xpaget DS9Test grid labels def2 >> ${tt}.out
xpaget DS9Test grid labels gap2 >> ${tt}.out
xpaget DS9Test grid labels font >> ${tt}.out
xpaget DS9Test grid labels fontsize >> ${tt}.out
xpaget DS9Test grid labels fontweight >> ${tt}.out
xpaget DS9Test grid labels fontslant >> ${tt}.out
# backward compatibilty
xpaget DS9Test grid labels fontstyle >> ${tt}.out
xpaget DS9Test grid labels color >> ${tt}.out

xpaset -p DS9Test grid open
xpaset -p DS9Test grid close

xpaset -p DS9Test grid
xpaset -p DS9Test grid yes

xpaset -p DS9Test grid type analysis
xpaset -p DS9Test grid system wcs
xpaset -p DS9Test grid sky fk5
xpaset -p DS9Test grid skyformat degrees

xpaset -p DS9Test grid grid yes
xpaset -p DS9Test grid grid color red
xpaset -p DS9Test grid grid width 2
xpaset -p DS9Test grid grid dash yes
# backward compatibilty
xpaset -p DS9Test grid grid style 1
xpaset -p DS9Test grid grid gap1 .01
xpaset -p DS9Test grid grid gap2 .01
xpaset -p DS9Test grid grid gap3 .01

xpaset -p DS9Test grid axes yes
xpaset -p DS9Test grid axes color red
xpaset -p DS9Test grid axes width 2
xpaset -p DS9Test grid axes dash yes
# backward compatibilty
xpaset -p DS9Test grid axes style 1
xpaset -p DS9Test grid axes type exterior
xpaset -p DS9Test grid axes origin lll

xpaset -p DS9Test grid format1 d.2
xpaset -p DS9Test grid format2 d.2

xpaset -p DS9Test grid tickmarks yes
xpaset -p DS9Test grid tickmarks color red
xpaset -p DS9Test grid tickmarks width 2
xpaset -p DS9Test grid tickmarks dash yes
# backward compatibilty
xpaset -p DS9Test grid tickmarks style 1

xpaset -p DS9Test grid border yes
xpaset -p DS9Test grid border color red
xpaset -p DS9Test grid border width 2
xpaset -p DS9Test grid border dash yes
# backward compatibilty
xpaset -p DS9Test grid border style 1

xpaset -p DS9Test grid numerics yes
xpaset -p DS9Test grid numerics font courier
xpaset -p DS9Test grid numerics fontsize 12
xpaset -p DS9Test grid numerics fontweight bold
xpaset -p DS9Test grid numerics fontslant roman
# backward compatibilty
xpaset -p DS9Test grid numerics fontstyle italic
xpaset -p DS9Test grid numerics color red
xpaset -p DS9Test grid numerics gap1 10
xpaset -p DS9Test grid numerics gap2 10
xpaset -p DS9Test grid numerics gap3 10
xpaset -p DS9Test grid numerics type exterior
xpaset -p DS9Test grid numerics vertical yes

xpaset -p DS9Test grid title yes
xpaset -p DS9Test grid title text {Hello World}
xpaset -p DS9Test grid title def yes
xpaset -p DS9Test grid title gap 10
xpaset -p DS9Test grid title font courier
xpaset -p DS9Test grid title fontsize 12
xpaset -p DS9Test grid title fontweight bold
xpaset -p DS9Test grid title fontslant roman
# backward compatibilty
xpaset -p DS9Test grid title fontstyle italic
xpaset -p DS9Test grid title color red

xpaset -p DS9Test grid labels yes
xpaset -p DS9Test grid labels text1 {Hello World}
xpaset -p DS9Test grid labels def1 yes
xpaset -p DS9Test grid labels gap1 10
xpaset -p DS9Test grid labels text2 {Hello World}
xpaset -p DS9Test grid labels def2 yes
xpaset -p DS9Test grid labels gap2 10
xpaset -p DS9Test grid labels font courier
xpaset -p DS9Test grid labels fontsize 12
xpaset -p DS9Test grid labels fontweight bold
xpaset -p DS9Test grid labels fontslant roman
# backward compatibilty
xpaset -p DS9Test grid labels fontstyle italic
xpaset -p DS9Test grid labels color red

xpaset -p DS9Test grid save foo.grd
xpaset -p DS9Test grid load foo.grd
xpaset -p DS9Test grid reset

xpaset -p DS9Test grid no
xpaset -p DS9Test grid close

testit $tt
fi

tt="header"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaset -p DS9Test header
xpaset -p DS9Test header save foo.txt
xpaset -p DS9Test header close
xpaset -p DS9Test header 1
xpaset -p DS9Test header close 1

testit $tt
fi

tt="height"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaget DS9Test height >> /dev/null
xpaset -p DS9Test height 443

testit $tt
fi

tt="hls"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaset -p DS9Test hls open
xpaset -p DS9Test hls close
xpaset -p DS9Test hls
xpaget DS9Test hls channel >> ${tt}.out
xpaget DS9Test hls view hue >> ${tt}.out
xpaget DS9Test hls view lightness >> ${tt}.out
xpaget DS9Test hls view saturation >> ${tt}.out
xpaget DS9Test hls system >> ${tt}.out
xpaget DS9Test hls lock wcs >> ${tt}.out
xpaget DS9Test hls lock crop >> ${tt}.out
xpaget DS9Test hls lock slice >> ${tt}.out
xpaget DS9Test hls lock bin >> ${tt}.out
xpaget DS9Test hls lock scale >> ${tt}.out
xpaget DS9Test hls lock scalelimits >> ${tt}.out
xpaget DS9Test hls lock colorbar >> ${tt}.out
xpaget DS9Test hls lock block >> ${tt}.out
xpaget DS9Test hls lock smooth >> ${tt}.out
xpaset -p DS9Test hls lightness
xpaset -p DS9Test hls channel saturation
xpaset -p DS9Test hls view saturation off
xpaset -p DS9Test hls system wcs
xpaset -p DS9Test hls lock wcs yes
xpaset -p DS9Test hls lock wcs no
xpaset -p DS9Test hls lock crop yes
xpaset -p DS9Test hls lock crop no
xpaset -p DS9Test hls lock slice yes
xpaset -p DS9Test hls lock slice no
xpaset -p DS9Test hls lock bin yes
xpaset -p DS9Test hls lock bin no
xpaset -p DS9Test hls lock scale yes
xpaset -p DS9Test hls lock scale no
# will set to scale user mode
xpaset -p DS9Test hls lock scalelimits yes
xpaset -p DS9Test hls lock scalelimits no
xpaset -p DS9Test scale zscale
xpaset -p DS9Test hls lock colorbar yes
xpaset -p DS9Test hls lock colorbar no
xpaset -p DS9Test hls lock block yes
xpaset -p DS9Test hls lock block no
xpaset -p DS9Test hls lock smooth yes
xpaset -p DS9Test hls lock smooth no
xpaset -p DS9Test hls close
xpaset -p DS9Test frame delete

testit $tt
fi

tt="hlsimage"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaset -p DS9Test frame new hls
xpaset -p DS9Test hlsimage hls/hlsimage.fits
cat hls/hlsimage.fits | xpaset DS9Test hlsimage
xpaget DS9Test hlsimage > /dev/null
xpaset -p DS9Test frame delete

xpaset -p DS9Test hlsimage new hls/hlsimage.fits
xpaset -p DS9Test frame delete

xpaset -p DS9Test hls close
testit $tt
fi

tt="hlscube"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaset -p DS9Test frame new hls
xpaset -p DS9Test hlscube hls/hlscube.fits
cat hls/hlscube.fits | xpaset DS9Test hlscube
xpaget DS9Test hlscube > /dev/null
xpaset -p DS9Test frame delete

xpaset -p DS9Test hlscube new hls/hlscube.fits
xpaset -p DS9Test frame delete

xpaset -p DS9Test hls close
testit $tt
fi

tt="hsv"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaset -p DS9Test hsv open
xpaset -p DS9Test hsv close
xpaset -p DS9Test hsv
xpaget DS9Test hsv channel >> ${tt}.out
xpaget DS9Test hsv view hue >> ${tt}.out
xpaget DS9Test hsv view saturation >> ${tt}.out
xpaget DS9Test hsv view value >> ${tt}.out
xpaget DS9Test hsv system >> ${tt}.out
xpaget DS9Test hsv lock wcs >> ${tt}.out
xpaget DS9Test hsv lock crop >> ${tt}.out
xpaget DS9Test hsv lock slice >> ${tt}.out
xpaget DS9Test hsv lock bin >> ${tt}.out
xpaget DS9Test hsv lock scale >> ${tt}.out
xpaget DS9Test hsv lock scalelimits >> ${tt}.out
xpaget DS9Test hsv lock colorbar >> ${tt}.out
xpaget DS9Test hsv lock block >> ${tt}.out
xpaget DS9Test hsv lock smooth >> ${tt}.out
xpaset -p DS9Test hsv saturation
xpaset -p DS9Test hsv channel value
xpaset -p DS9Test hsv view value off
xpaset -p DS9Test hsv system wcs
xpaset -p DS9Test hsv lock wcs yes
xpaset -p DS9Test hsv lock wcs no
xpaset -p DS9Test hsv lock crop yes
xpaset -p DS9Test hsv lock crop no
xpaset -p DS9Test hsv lock slice yes
xpaset -p DS9Test hsv lock slice no
xpaset -p DS9Test hsv lock bin yes
xpaset -p DS9Test hsv lock bin no
xpaset -p DS9Test hsv lock scale yes
xpaset -p DS9Test hsv lock scale no
# will set to scale user mode
xpaset -p DS9Test hsv lock scalelimits yes
xpaset -p DS9Test hsv lock scalelimits no
xpaset -p DS9Test scale zscale
xpaset -p DS9Test hsv lock colorbar yes
xpaset -p DS9Test hsv lock colorbar no
xpaset -p DS9Test hsv lock block yes
xpaset -p DS9Test hsv lock block no
xpaset -p DS9Test hsv lock smooth yes
xpaset -p DS9Test hsv lock smooth no
xpaset -p DS9Test hsv close
xpaset -p DS9Test frame delete

testit $tt
fi

tt="hsvimage"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaset -p DS9Test frame new hsv
xpaset -p DS9Test hsvimage hsv/hsvimage.fits
cat hsv/hsvimage.fits | xpaset DS9Test hsvimage
xpaget DS9Test hsvimage > /dev/null
xpaset -p DS9Test frame delete

xpaset -p DS9Test hsvimage new hsv/hsvimage.fits
xpaset -p DS9Test frame delete

xpaset -p DS9Test hsv close
testit $tt
fi

tt="hsvcube"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaset -p DS9Test frame new hsv
xpaset -p DS9Test hsvcube hsv/hsvcube.fits
cat hsv/hsvcube.fits | xpaset DS9Test hsvcube
xpaget DS9Test hsvcube > /dev/null
xpaset -p DS9Test frame delete

xpaset -p DS9Test hsvcube new hsv/hsvcube.fits
xpaset -p DS9Test frame delete

xpaset -p DS9Test hsv close
testit $tt
fi

tt="iconify"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaget DS9Test iconify >> ${tt}.out
xpaset -p DS9Test iconify
xpaset -p DS9Test iconify yes
xpaset -p DS9Test iconify no

testit $tt
fi

tt="iis"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaget DS9Test iis filename >> ${tt}.out
xpaget DS9Test iis filename 1 >> ${tt}.out
xpaset -p DS9Test iis filename foo.fits
xpaset -p DS9Test iis filename foo.fits 1

testit $tt
fi

tt="iexam"
if [ "$1" = "$tt" ]; then
echo "$tt..."
echo "Select coordinate point:"
xpaget DS9Test iexam coordinate wcs fk5 degrees
echo "  ok"
sleep $delay
echo "Press key:"
xpaget DS9Test iexam key coordinate wcs fk5 degrees
echo "  ok"
sleep $delay
echo "Press either:"
xpaget DS9Test iexam any coordinate wcs fk5 degrees
echo "  ok"
sleep $delay
echo "Select value point:"
xpaget DS9Test iexam data
echo "  ok"
sleep $delay
echo "Press key:"
xpaget DS9Test iexam key data
echo "  ok"
sleep $delay
echo "Press any:"
xpaget DS9Test iexam any data
echo "  ok"
echo "Macro string:"
xpaget DS9Test iexam any {'Click at $x,$y in file $filename'}
echo "  ok"
sleep $delay

testit $tt
fi

tt="illustrate"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaget DS9Test illustrate >> /dev/null
xpaget DS9Test illustrate show >> ${tt}.out
xpaget DS9Test illustrate shape >> ${tt}.out
xpaget DS9Test illustrate color >> ${tt}.out
xpaget DS9Test illustrate fill >> ${tt}.out
xpaget DS9Test illustrate width >> ${tt}.out
xpaget DS9Test illustrate dash >> ${tt}.out

echo "circle 100 100 40 # color = red fill = yes" | xpaset DS9Test illustrate
echo "ellipse 100 200 40 20" | xpaset DS9Test illustrate
echo "box 200 100 40 20" | xpaset DS9Test illustrate
echo "polygon 200 200 200 250 250 250 250 200" | xpaset DS9Test illustrate
echo "line 300 200 300 250 # dash = yes line = 0 1" | xpaset DS9Test illustrate
echo "text 117.0 339.0 "BANG!" # color = yellow font = times fontsize = 48 angle = 45.0" | xpaset DS9Test illustrate
echo "image 100 100 regions/chandra.png" | xpaset DS9Test illustrate

xpaset -p DS9Test illustrate delete
xpaset -p DS9Test illustrate regions/ds9.seg
xpaset -p DS9Test illustrate delete
xpaset -p DS9Test illustrate load regions/ds9.seg
xpaset -p DS9Test illustrate save foo.seg
xpaset -p DS9Test illustrate select all
xpaset -p DS9Test illustrate save select foo.seg
xpaset -p DS9Test illustrate list
xpaset -p DS9Test illustrate list select
xpaset -p DS9Test illustrate list close
xpaset -p DS9Test illustrate show yes
xpaset -p DS9Test illustrate select none
xpaset -p DS9Test illustrate select invert
xpaset -p DS9Test illustrate select front
xpaset -p DS9Test illustrate select back
xpaset -p DS9Test illustrate move front
xpaset -p DS9Test illustrate move back
xpaset -p DS9Test illustrate delete select
xpaset -p DS9Test illustrate delete
xpaset -p DS9Test illustrate color red
xpaset -p DS9Test illustrate width 3
xpaset -p DS9Test illustrate dash no

xpaset -p DS9Test illustrate delete

xpaset -p DS9Test illustrate command {circle 100 100 20}
xpaset -p DS9Test illustrate select all
xpaset -p DS9Test illustrate copy
xpaset -p DS9Test illustrate cut
xpaset -p DS9Test illustrate paste
xpaset -p DS9Test illustrate undo
xpaset -p DS9Test illustrate delete

xpaset -p DS9Test illustrate load regions/ds9.seg
xpaset -p DS9Test illustrate select all
xpaset -p DS9Test illustrate open
xpaset -p DS9Test illustrate close
xpaset -p DS9Test illustrate delete

testit $tt
fi

tt="foo"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt/jpg..."


testit $tt
fi

tt="jpeg"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt/jpg..."
xpaset -p DS9Test frame new
xpaset -p DS9Test jpeg photo/rose.jpeg
cat photo/rose.jpeg | xpaset DS9Test jpeg
xpaget DS9Test jpeg > /dev/null
xpaset -p DS9Test frame delete

xpaset -p DS9Test jpeg new photo/rose.jpeg
xpaset -p DS9Test jpeg slice photo/rose.jpeg
xpaset -p DS9Test frame delete

testit $tt
fi

tt="lock"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaget DS9Test lock frame >> ${tt}.out
xpaget DS9Test lock crosshair >> ${tt}.out
xpaget DS9Test lock crop >> ${tt}.out
xpaget DS9Test lock slice >> ${tt}.out
xpaget DS9Test lock bin >> ${tt}.out
xpaget DS9Test lock axes >> ${tt}.out
xpaget DS9Test lock scale >> ${tt}.out
xpaget DS9Test lock scalelimits >> ${tt}.out
xpaget DS9Test lock colorbar >> ${tt}.out
xpaget DS9Test lock block >> ${tt}.out
xpaget DS9Test lock smooth >> ${tt}.out
xpaget DS9Test lock 3d >> ${tt}.out
xpaset -p DS9Test fits new fits/img.fits
xpaset -p DS9Test tile
xpaset -p DS9Test mode crosshair
xpaset -p DS9Test lock frame wcs
xpaset -p DS9Test lock frame none
xpaset -p DS9Test lock crosshair wcs
xpaset -p DS9Test crosshair 13:29:56 +47:11:38 wcs fk5
xpaset -p DS9Test lock crosshair none
xpaset -p DS9Test lock crop wcs
xpaset -p DS9Test lock crop none
xpaset -p DS9Test lock slice wcs
xpaset -p DS9Test lock slice none
xpaset -p DS9Test lock bin yes
xpaset -p DS9Test lock bin no
xpaset -p DS9Test lock axes yes
xpaset -p DS9Test lock axes no
xpaset -p DS9Test lock scale yes
xpaset -p DS9Test lock scale no
# will set to scale user mode
xpaset -p DS9Test lock scalelimits yes
xpaset -p DS9Test lock scalelimits no
xpaset -p DS9Test scale zscale
xpaset -p DS9Test lock colorbar yes
xpaset -p DS9Test lock colorbar no
xpaset -p DS9Test lock smooth yes
xpaset -p DS9Test lock smooth no
xpaset -p DS9Test lock 3d yes
xpaset -p DS9Test lock 3d no
xpaset -p DS9Test mode none
xpaset -p DS9Test frame delete
xpaset -p DS9Test wcs align no

testit $tt
fi

tt="lower"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaset -p DS9Test lower
xpaset -p DS9Test raise

testit $tt
fi

tt="magnifier"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaget DS9Test magnifier color >> ${tt}.out
xpaget DS9Test magnifier zoom >> ${tt}.out
xpaget DS9Test magnifier cursor >> ${tt}.out
xpaget DS9Test magnifier region >> ${tt}.out
xpaset -p DS9Test magnifier color white
xpaset -p DS9Test magnifier zoom 4
xpaset -p DS9Test magnifier cursor yes
xpaset -p DS9Test magnifier region yes

testit $tt
fi

tt="mask"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaget DS9Test mask color >> ${tt}.out
xpaget DS9Test mask mark >> ${tt}.out
xpaget DS9Test mask range >> ${tt}.out
xpaget DS9Test mask transparency >> ${tt}.out
xpaget DS9Test mask blend >> ${tt}.out
xpaget DS9Test mask system >> ${tt}.out
xpaset -p DS9Test mask open
xpaset -p DS9Test mask color cyan
xpaset -p DS9Test mask mark zero
xpaset -p DS9Test mask range 10 100
xpaset -p DS9Test mask transparency 25
xpaset -p DS9Test mask blend source
xpaset -p DS9Test mask blend multiply
xpaset -p DS9Test mask blend screen
xpaset -p DS9Test mask blend overlay
xpaset -p DS9Test mask blend darken
xpaset -p DS9Test mask blend lighten
xpaset -p DS9Test mask blend color-dodge
xpaset -p DS9Test mask blend color-burn
xpaset -p DS9Test mask blend hard-light
xpaset -p DS9Test mask blend soft-light
xpaset -p DS9Test mask blend difference
xpaset -p DS9Test mask blend exclusion
xpaset -p DS9Test mask blend hue
xpaset -p DS9Test mask blend saturation
xpaset -p DS9Test mask blend color
xpaset -p DS9Test mask blend luminosity
xpaset -p DS9Test mask system physical
xpaset -p DS9Test mask load fits/img.fits
sleep $delay
xpaset -p DS9Test mask clear
xpaset -p DS9Test mask close
sleep $delay

testit $tt
fi

tt="match"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaset -p DS9Test fits new fits/img.fits
xpaset -p DS9Test tile
xpaset -p DS9Test mode crosshair
xpaset -p DS9Test match frame wcs
xpaset -p DS9Test match frame image
xpaset -p DS9Test match crosshair wcs
xpaset -p DS9Test match crop wcs
xpaset -p DS9Test match slice wcs
xpaset -p DS9Test match bin
xpaset -p DS9Test match axes
xpaset -p DS9Test match scale
# will set to scale user mode
xpaset -p DS9Test match scalelimits
xpaset -p DS9Test match colorbar
xpaset -p DS9Test match block
xpaset -p DS9Test match smooth
xpaset -p DS9Test match 3d
xpaset -p DS9Test frame delete
xpaset -p DS9Test scale zscale
xpaset -p DS9Test mode none

testit $tt
fi

tt="mecube"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaset -p DS9Test frame new
xpaset -p DS9Test mecube mecube/float.fits
cat mecube/float.fits | xpaset DS9Test mecube
xpaget DS9Test mecube > /dev/null
xpaset -p DS9Test frame delete

xpaset -p DS9Test cube close
testit $tt
fi

tt="minmax"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaget DS9Test minmax >> ${tt}.out
xpaget DS9Test minmax mode >> ${tt}.out
xpaget DS9Test minmax interval >> ${tt}.out
xpaset -p DS9Test minmax scan
xpaset -p DS9Test minmax mode scan
xpaset -p DS9Test minmax interval 100
xpaset -p DS9Test minmax rescan

testit $tt
fi

tt="mode"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaget DS9Test mode >> ${tt}.out
xpaset -p DS9Test mode none
xpaset -p DS9Test mode region
# backward compatibility
xpaset -p DS9Test mode pointer
xpaset -p DS9Test mode crosshair
xpaset -p DS9Test mode colorbar
xpaset -p DS9Test mode pan
xpaset -p DS9Test mode zoom
xpaset -p DS9Test mode rotate
xpaset -p DS9Test mode catalog
xpaset -p DS9Test mode examine
xpaset -p DS9Test mode 3d
xpaset -p DS9Test mode none

testit $tt
fi

tt="mosaic"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaset -p DS9Test frame new
xpaset -p DS9Test mosaic mosaic/mosaicimage.fits
xpaget DS9Test mosaic > /dev/null
xpaset -p DS9Test frame clear
xpaset -p DS9Test mosaic wcs mosaic/mosaicimage.fits
xpaset -p DS9Test frame clear
cat mosaic/mosaicimage.fits | xpaset DS9Test mosaic wcs
xpaset -p DS9Test frame clear
xpaset -p DS9Test mosaic iraf mosaic/mosaicimage.fits
xpaset -p DS9Test frame clear
cat mosaic/mosaicimage.fits | xpaset DS9Test mosaic iraf
xpaset -p DS9Test frame delete

xpaset -p DS9Test mosaic new mosaic/mosaicimage.fits
xpaset -p DS9Test mosaic mask mosaic/mosaicimage.fits
xpaset -p DS9Test frame delete

testit $tt
fi

tt="mosaicimage"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaset -p DS9Test frame new
xpaset -p DS9Test mosaicimage mosaic/mosaicimage.fits
xpaget DS9Test mosaicimage > /dev/null
xpaset -p DS9Test frame clear
xpaset -p DS9Test mosaicimage wcs mosaic/mosaicimage.fits
xpaset -p DS9Test frame clear
cat mosaic/mosaicimage.fits | xpaset DS9Test mosaicimage wcs
xpaset -p DS9Test frame clear
xpaset -p DS9Test mosaicimage iraf mosaic/mosaicimage.fits
xpaset -p DS9Test frame clear
cat mosaic/mosaicimage.fits | xpaset DS9Test mosaicimage iraf
xpaset -p DS9Test frame clear
xpaset -p DS9Test mosaicimage wfpc2 mosaic/hst.fits
xpaset -p DS9Test frame clear
cat mosaic/hst.fits | xpaset DS9Test mosaicimage wfpc2
xpaset -p DS9Test frame delete

xpaset -p DS9Test mosaicimage new mosaic/mosaicimage.fits
xpaset -p DS9Test mosaicimage mask mosaic/mosaicimage.fits
xpaset -p DS9Test frame delete

testit $tt
fi

# backward compatibility
tt="mosaicwcs"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt...backward compatibility..."
xpaset -p DS9Test frame new
xpaset -p DS9Test mosaicwcs mosaic/mosaicimage.fits
xpaget DS9Test mosaicwcs > /dev/null
xpaset -p DS9Test frame clear
cat mosaic/mosaicimage.fits | xpaset DS9Test mosaicwcs
xpaset -p DS9Test frame delete

xpaset -p DS9Test mosaicwcs new mosaic/mosaicimage.fits
xpaset -p DS9Test mosaicwcs mask mosaic/mosaicimage.fits
xpaset -p DS9Test frame delete

testit $tt
fi

# backward compatibility
tt="mosaiciraf"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt...backward compatibility..."
xpaset -p DS9Test frame new
xpaset -p DS9Test mosaiciraf mosaic/mosaicimage.fits
xpaset -p DS9Test frame clear
cat mosaic/mosaicimage.fits | xpaset DS9Test mosaiciraf
xpaset -p DS9Test frame delete

xpaset -p DS9Test mosaiciraf new mosaic/mosaicimage.fits
xpaset -p DS9Test mosaiciraf mask mosaic/mosaicimage.fits
xpaset -p DS9Test frame delete

testit $tt
fi

# backward compatibility
tt="mosaicimagewcs"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt...backward compatibility..."
xpaset -p DS9Test frame new
xpaset -p DS9Test mosaicimagewcs mosaic/mosaicimage.fits
xpaget DS9Test mosaicimagewcs > /dev/null
xpaset -p DS9Test frame clear
cat mosaic/mosaicimage.fits | xpaset DS9Test mosaicimagewcs
xpaset -p DS9Test frame delete

xpaset -p DS9Test mosaicimagewcs new mosaic/mosaicimage.fits
xpaset -p DS9Test mosaicimagewcs mask mosaic/mosaicimage.fits
xpaset -p DS9Test frame delete

testit $tt
fi

# backward compatibility
tt="mosaicimageiraf"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt...backward compatibility..."
xpaset -p DS9Test frame new
xpaset -p DS9Test mosaicimageiraf mosaic/mosaicimage.fits
xpaset -p DS9Test frame clear
cat mosaic/mosaicimage.fits | xpaset DS9Test mosaicimageiraf
xpaset -p DS9Test frame delete

xpaset -p DS9Test mosaicimageiraf new mosaic/mosaicimage.fits
xpaset -p DS9Test mosaicimageiraf mask mosaic/mosaicimage.fits
xpaset -p DS9Test frame delete

testit $tt
fi

# backward compatibility
tt="mosaicimagewfpc2"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt...backward compatibility..."
xpaset -p DS9Test frame new
xpaset -p DS9Test mosaicimagewfpc2 mosaic/hst.fits
xpaset -p DS9Test frame clear
cat mosaic/hst.fits | xpaset DS9Test mosaicimagewfpc2
xpaset -p DS9Test frame delete

xpaset -p DS9Test mosaicimagewfpc2 new mosaic/hst.fits
xpaset -p DS9Test mosaicimagewfpc2 mask mosaic/hst.fits
xpaset -p DS9Test frame delete

testit $tt
fi

# movie will fail if moved from corner
tt="movie"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt/savempeg..."
xpaset -p DS9Test width 715
xpaset -p DS9Test height 450
xpaset -p DS9Test movie foo.gif
xpaset -p DS9Test movie frame foo.gif
xpaset -p DS9Test movie slice foo.gif
xpaset -p DS9Test movie frame 100 fade foo.gif
xpaset -p DS9Test frame new 3d
xpaset -p DS9Test movie 3d gif 100 foo.gif number 1 az from 0 az to 0 el from 0 el to 0 slice from 1 slice to 1 zoom from 1 zoom to 2 repeat 1
xpaset -p DS9Test frame delete

# backward compatibility
xpaset -p DS9Test savempeg foo.mpg

xpaset -p DS9Test 3d close
xpaset -p DS9Test cube close

xpaset -p DS9Test movie script gif movie.script script_xpa.gif
testit $tt
fi

tt="multiframe"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt/memf..."
xpaset -p DS9Test frame new
xpaset -p DS9Test multiframe mecube/float.fits
xpaset -p DS9Test frame delete
xpaset -p DS9Test frame delete
xpaset -p DS9Test frame delete

testit $tt
fi

tt="multicolor"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaset -p DS9Test multicolor
xpaset -p DS9Test layer color red
xpaset -p DS9Test fits data/i.fits
xpaset -p DS9Test layer create
xpaset -p DS9Test layer color green
xpaset -p DS9Test fits data/r.fits
xpaset -p DS9Test layer create
xpaset -p DS9Test layer color blue
xpaset -p DS9Test fits data/v.fits

xpaget DS9Test layer count >> ${tt}.out
xpaget DS9Test layer layerno >> ${tt}.out
xpaget DS9Test layer 1 color >> ${tt}.out
xpaget DS9Test layer 2 color >> ${tt}.out
xpaget DS9Test layer 3 color >> ${tt}.out
xpaget DS9Test layer blend >> ${tt}.out
xpaget DS9Test layer 3 transparency >> ${tt}.out
xpaget DS9Test layer view >> ${tt}.out

xpaset -p DS9Test layer 1
xpaget DS9Test layer layerno >> ${tt}.out
xpaset -p DS9Test layer layerno 2
xpaget DS9Test layer layerno >> ${tt}.out
xpaset -p DS9Test layer color cyan
xpaget DS9Test layer color >> ${tt}.out
xpaset -p DS9Test layer 2 color green
xpaget DS9Test layer 2 color >> ${tt}.out

xpaset -p DS9Test multicolor system image
xpaget DS9Test multicolor system >> ${tt}.out
xpaset -p DS9Test multicolor system physical
xpaget DS9Test multicolor system >> ${tt}.out
xpaset -p DS9Test multicolor system amplifier
xpaget DS9Test multicolor system >> ${tt}.out
xpaset -p DS9Test multicolor system detector
xpaget DS9Test multicolor system >> ${tt}.out
xpaset -p DS9Test multicolor system wcs
xpaget DS9Test multicolor system >> ${tt}.out
xpaset -p DS9Test multicolor system wcsa
xpaget DS9Test multicolor system >> ${tt}.out
xpaset -p DS9Test multicolor system wcsb
xpaget DS9Test multicolor system >> ${tt}.out
xpaset -p DS9Test multicolor system wcsc
xpaget DS9Test multicolor system >> ${tt}.out
xpaset -p DS9Test multicolor system wcsd
xpaget DS9Test multicolor system >> ${tt}.out
xpaset -p DS9Test multicolor system wcse
xpaget DS9Test multicolor system >> ${tt}.out
xpaset -p DS9Test multicolor system wcsf
xpaget DS9Test multicolor system >> ${tt}.out
xpaset -p DS9Test multicolor system wcsg
xpaget DS9Test multicolor system >> ${tt}.out
xpaset -p DS9Test multicolor system wcsh
xpaget DS9Test multicolor system >> ${tt}.out
xpaset -p DS9Test multicolor system wcsi
xpaget DS9Test multicolor system >> ${tt}.out
xpaset -p DS9Test multicolor system wcsj
xpaget DS9Test multicolor system >> ${tt}.out
xpaset -p DS9Test multicolor system wcsk
xpaget DS9Test multicolor system >> ${tt}.out
xpaset -p DS9Test multicolor system wcsl
xpaget DS9Test multicolor system >> ${tt}.out
xpaset -p DS9Test multicolor system wcsm
xpaget DS9Test multicolor system >> ${tt}.out
xpaset -p DS9Test multicolor system wcsn
xpaget DS9Test multicolor system >> ${tt}.out
xpaset -p DS9Test multicolor system wcso
xpaget DS9Test multicolor system >> ${tt}.out
xpaset -p DS9Test multicolor system wcsp
xpaget DS9Test multicolor system >> ${tt}.out
xpaset -p DS9Test multicolor system wcsq
xpaget DS9Test multicolor system >> ${tt}.out
xpaset -p DS9Test multicolor system wcsr
xpaget DS9Test multicolor system >> ${tt}.out
xpaset -p DS9Test multicolor system wcss
xpaget DS9Test multicolor system >> ${tt}.out
xpaset -p DS9Test multicolor system wcst
xpaget DS9Test multicolor system >> ${tt}.out
xpaset -p DS9Test multicolor system wcsu
xpaget DS9Test multicolor system >> ${tt}.out
xpaset -p DS9Test multicolor system wcsv
xpaget DS9Test multicolor system >> ${tt}.out
xpaset -p DS9Test multicolor system wcsw
xpaget DS9Test multicolor system >> ${tt}.out
xpaset -p DS9Test multicolor system wcsx
xpaget DS9Test multicolor system >> ${tt}.out
xpaset -p DS9Test multicolor system wcsy
xpaget DS9Test multicolor system >> ${tt}.out
xpaset -p DS9Test multicolor system wcsz
xpaget DS9Test multicolor system >> ${tt}.out
xpaset -p DS9Test multicolor system wcs
xpaget DS9Test multicolor system >> ${tt}.out

xpaset -p DS9Test multicolor lock wcs yes
xpaget DS9Test multicolor lock wcs >> ${tt}.out
xpaset -p DS9Test multicolor lock wcs no
xpaget DS9Test multicolor lock wcs >> ${tt}.out
xpaset -p DS9Test multicolor lock crop yes
xpaget DS9Test multicolor lock crop >> ${tt}.out
xpaset -p DS9Test multicolor lock crop no
xpaget DS9Test multicolor lock crop >> ${tt}.out
xpaset -p DS9Test multicolor lock slice yes
xpaget DS9Test multicolor lock slice >> ${tt}.out
xpaset -p DS9Test multicolor lock slice no
xpaget DS9Test multicolor lock slice >> ${tt}.out
xpaset -p DS9Test multicolor lock bin yes
xpaget DS9Test multicolor lock bin >> ${tt}.out
xpaset -p DS9Test multicolor lock bin no
xpaget DS9Test multicolor lock bin >> ${tt}.out
xpaset -p DS9Test multicolor lock scale yes
xpaget DS9Test multicolor lock scale >> ${tt}.out
xpaset -p DS9Test multicolor lock scale no
xpaget DS9Test multicolor lock scale >> ${tt}.out
xpaset -p DS9Test multicolor lock scalelimits yes
xpaget DS9Test multicolor lock scalelimits >> ${tt}.out
xpaset -p DS9Test multicolor lock scalelimits no
xpaget DS9Test multicolor lock scalelimits >> ${tt}.out
xpaset -p DS9Test multicolor lock colorbar yes
xpaget DS9Test multicolor lock colorbar >> ${tt}.out
xpaset -p DS9Test multicolor lock colorbar no
xpaget DS9Test multicolor lock colorbar >> ${tt}.out
xpaset -p DS9Test multicolor lock block yes
xpaget DS9Test multicolor lock block >> ${tt}.out
xpaset -p DS9Test multicolor lock block no
xpaget DS9Test multicolor lock block >> ${tt}.out
xpaset -p DS9Test multicolor lock smooth yes
xpaget DS9Test multicolor lock smooth >> ${tt}.out
xpaset -p DS9Test multicolor lock smooth no
xpaget DS9Test multicolor lock smooth >> ${tt}.out

xpaset -p DS9Test layer 2 blend source
xpaget DS9Test layer blend >> ${tt}.out
xpaset -p DS9Test layer blend multiply
xpaget DS9Test layer 2 blend >> ${tt}.out
xpaset -p DS9Test layer blend screen
xpaget DS9Test layer blend >> ${tt}.out
xpaset -p DS9Test layer blend overlay
xpaget DS9Test layer blend >> ${tt}.out
xpaset -p DS9Test layer blend darken
xpaget DS9Test layer blend >> ${tt}.out
xpaset -p DS9Test layer blend lighten
xpaget DS9Test layer blend >> ${tt}.out
xpaset -p DS9Test layer blend color-dodge
xpaget DS9Test layer blend >> ${tt}.out
xpaset -p DS9Test layer blend color-burn
xpaget DS9Test layer blend >> ${tt}.out
xpaset -p DS9Test layer blend hard-light
xpaget DS9Test layer blend >> ${tt}.out
xpaset -p DS9Test layer blend soft-light
xpaget DS9Test layer blend >> ${tt}.out
xpaset -p DS9Test layer blend difference
xpaget DS9Test layer blend >> ${tt}.out
xpaset -p DS9Test layer blend exclusion
xpaget DS9Test layer blend >> ${tt}.out
xpaset -p DS9Test layer blend hue
xpaget DS9Test layer blend >> ${tt}.out
xpaset -p DS9Test layer blend saturation
xpaget DS9Test layer blend >> ${tt}.out
xpaset -p DS9Test layer blend color
xpaget DS9Test layer blend >> ${tt}.out
xpaset -p DS9Test layer blend luminosity
xpaget DS9Test layer blend >> ${tt}.out

xpaset -p DS9Test layer transparency 0
xpaget DS9Test layer transparency >> ${tt}.out
xpaset -p DS9Test layer transparency 35
xpaget DS9Test layer transparency >> ${tt}.out
xpaset -p DS9Test layer 2 transparency 100
xpaget DS9Test layer 2 transparency >> ${tt}.out
xpaset -p DS9Test layer view no
xpaget DS9Test layer view >> ${tt}.out
xpaset -p DS9Test layer 2 view yes
xpaget DS9Test layer 2 view >> ${tt}.out

xpaset -p DS9Test layer 3 top
xpaget DS9Test layer 1 color >> ${tt}.out
xpaget DS9Test layer 2 color >> ${tt}.out
xpaget DS9Test layer 3 color >> ${tt}.out
xpaset -p DS9Test layer bottom
xpaget DS9Test layer 1 color >> ${tt}.out
xpaget DS9Test layer 2 color >> ${tt}.out
xpaget DS9Test layer 3 color >> ${tt}.out
xpaset -p DS9Test layer 3 up
xpaget DS9Test layer 1 color >> ${tt}.out
xpaget DS9Test layer 2 color >> ${tt}.out
xpaget DS9Test layer 3 color >> ${tt}.out
xpaset -p DS9Test layer down
xpaget DS9Test layer 1 color >> ${tt}.out
xpaget DS9Test layer 2 color >> ${tt}.out
xpaget DS9Test layer 3 color >> ${tt}.out

xpaset -p DS9Test layer 2 delete
xpaget DS9Test layer count >> ${tt}.out
xpaget DS9Test layer 1 color >> ${tt}.out
xpaget DS9Test layer 2 color >> ${tt}.out
xpaset -p DS9Test layer 2
xpaset -p DS9Test layer delete
xpaget DS9Test layer count >> ${tt}.out
xpaset -p DS9Test frame delete

testit $tt
fi

tt="nameserver"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaset -p DS9Test nameserver open
xpaset -p DS9Test nameserver close
xpaset -p DS9Test nameserver m51
xpaget DS9Test nameserver >> ${tt}.out
xpaget DS9Test nameserver server >> ${tt}.out
xpaget DS9Test nameserver skyformat >> ${tt}.out
xpaget DS9Test nameserver m51 >> ${tt}.out
xpaset -p DS9Test nameserver name m51
xpaset -p DS9Test nameserver server simbad-cds
xpaset -p DS9Test nameserver skyformat degrees
xpaset -p DS9Test mode crosshair
xpaset -p DS9Test nameserver crosshair
xpaset -p DS9Test nameserver pan
xpaset -p DS9Test nameserver close
xpaset -p DS9Test mode none
xpaset -p DS9Test frame reset

testit $tt
fi

# backward compatibility prefs
tt="nan"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaget DS9Test nan >> ${tt}.out
xpaset -p DS9Test nan blue
xpaset -p DS9Test nan white

testit $tt
fi

tt="notes"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaget DS9Test notes > /dev/null
xpaset -p DS9Test notes
xpaset -p DS9Test notes close
xpaset -p DS9Test notes open
xpaset -p DS9Test notes {Hello World}
xpaset -p DS9Test notes append {Last Line}
xpaset -p DS9Test notes insert {First Line}
xpaset -p DS9Test notes save foo.txt
xpaset -p DS9Test notes load foo.txt
sleep 1
xpaset -p DS9Test notes clear
sleep 1
xpaset -p DS9Test notes close

testit $tt
fi

tt="nrrd"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaset -p DS9Test frame new
xpaset -p DS9Test nrrd nrrd/float_big_raw.nrrd
cat nrrd/float_big_raw.nrrd | xpaset DS9Test nrrd
xpaget DS9Test nrrd > /dev/null
xpaget DS9Test nrrd big > /dev/null
xpaset -p DS9Test frame delete

xpaset -p DS9Test nrrd new nrrd/float_big_raw.nrrd
xpaset -p DS9Test nrrd mask nrrd/float_big_raw.nrrd
xpaset -p DS9Test frame delete

testit $tt
fi

tt="nvss"
if [ "$1" = "$tt" ]; then
echo -n "$tt..."
xpaset -p DS9Test nvss open
xpaset -p DS9Test nvss close
xpaset -p DS9Test nvss size 30 30 arcsec
xpaget DS9Test nvss size >> ${tt}.out
xpaset -p DS9Test nvss save no
xpaget DS9Test nvss save >> ${tt}.out
xpaset -p DS9Test nvss frame new
xpaget DS9Test nvss frame >> ${tt}.out
xpaset -p DS9Test nvss update frame
xpaset -p DS9Test nvss m51
xpaset -p DS9Test nvss name m51
xpaget DS9Test nvss name >> ${tt}.out
xpaset -p DS9Test nvss name clear
xpaset -p DS9Test nvss 13:29:52.37 +47:11:40.8
# backward compatibility
xpaset -p DS9Test nvss coord 13:29:52.37 +47:11:40.8 sexagesimal
xpaget DS9Test nvss coord >> ${tt}.out
xpaset -p DS9Test nvss update frame
xpaset -p DS9Test mode crosshair
xpaset -p DS9Test nvss update crosshair
xpaset -p DS9Test nvss close
xpaset -p DS9Test mode none
xpaset -p DS9Test frame delete
xpaset -p DS9Test frame delete
xpaset -p DS9Test frame delete
xpaset -p DS9Test frame delete
xpaset -p DS9Test frame delete
xpaset -p DS9Test frame delete
xpaset -p DS9Test frame delete

testit $tt
fi

tt="orient"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaset -p DS9Test orient open
xpaset -p DS9Test orient none
xpaset -p DS9Test orient x
xpaset -p DS9Test orient y
xpaset -p DS9Test orient xy
xpaset -p DS9Test orient close
xpaget DS9Test orient >> ${tt}.out
xpaset -p DS9Test frame reset

testit $tt
fi

tt="pagesetup"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaget DS9Test pspagesetup orient >> ${tt}.out
xpaget DS9Test pspagesetup scale >> ${tt}.out
xpaget DS9Test pspagesetup size >> ${tt}.out
xpaset -p DS9Test pspagesetup orient portrait
xpaset -p DS9Test pspagesetup scale 100
xpaset -p DS9Test pspagesetup size letter

testit $tt
fi

tt="pan"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaget DS9Test pan physical >> ${tt}.out
xpaget DS9Test pan wcs fk5 sexagesimal >> ${tt}.out
xpaset -p DS9Test pan open
xpaset -p DS9Test pan 100 100 image

xpaset -p DS9Test pan to 978 970
xpaset -p DS9Test pan to 978 970 physical
xpaset -p DS9Test pan to 202.470451 47.19394108 wcs
xpaset -p DS9Test pan to 202.470451 47.19394108 fk5
xpaset -p DS9Test pan to 202.470451 47.19394108 wcs fk5

xpaset -p DS9Test pan to 13:29:52.908 +47:11:38.19
xpaset -p DS9Test pan to 13:29:52.908 +47:11:38.19 wcs
xpaset -p DS9Test pan to 13:29:52.908 +47:11:38.19 fk5
xpaset -p DS9Test pan to 13:29:52.908 +47:11:38.19 wcs fk5

xpaset -p DS9Test pan close
xpaset -p DS9Test frame reset

testit $tt
fi

tt="pixeltable"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaget DS9Test pixeltable >> ${tt}.out
xpaset -p DS9Test pixeltable
xpaset -p DS9Test pixeltable yes
xpaset -p DS9Test pixeltable no
xpaset -p DS9Test pixeltable open
xpaset -p DS9Test pixeltable close

testit $tt
fi

tt="plot"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo "$tt..."

echo -n " gui..."
xpaset -p DS9Test plot line
xpaset -p DS9Test plot gui
sleep $delay
xpaset -p DS9Test plot close
echo "PASSED"

echo -n " empty plot..."
xpaset -p DS9Test plot line
xpaset -p DS9Test plot line foo
xpaget DS9Test plot >> ${tt}.out
sleep $delay
xpaset -p DS9Test plot close
xpaset -p DS9Test plot close
echo "PASSED"

echo -n " file name dim..."
xpaset -p DS9Test plot line plot/xy.dat xy
xpaset -p DS9Test plot line plot/xy.dat foo xy
xpaset -p DS9Test plot theme no
sleep $delay
xpaset -p DS9Test plot close
xpaset -p DS9Test plot close
echo "PASSED"

echo -n " file name title xaxis yaxis dim..."
xpaset -p DS9Test plot line plot/xy.dat {The Title} {X Axis} {Y Axis} xy
xpaset -p DS9Test plot line plot/xy.dat foo {The Title} {X Axis} {Y Axis} xy
xpaset -p DS9Test plot theme no
sleep $delay
xpaset -p DS9Test plot close
xpaset -p DS9Test plot close
echo "PASSED"

echo -n " stdin..."
cat plot/xy.dat | xpaset DS9Test plot line {The Title} {X Axis} {Y Axis} xy
cat plot/xy.dat | xpaset DS9Test plot line foo {The Title} {X Axis} {Y Axis} xy
xpaset -p DS9Test plot theme no
sleep $delay
xpaset -p DS9Test plot close
xpaset -p DS9Test plot close
echo "PASSED"

echo -n " stdin with header..."
cat plot/stdin.2.dat | xpaset DS9Test plot line stdin
cat plot/stdin.2.dat | xpaset DS9Test plot line foo stdin
xpaset -p DS9Test plot theme no
sleep $delay
xpaset -p DS9Test plot close
xpaset -p DS9Test plot close
echo "PASSED"

echo -n " data..."
xpaset -p DS9Test plot line
cat plot/xy.dat | xpaset DS9Test plot data xy
xpaset -p DS9Test plot theme no
sleep $delay
xpaset -p DS9Test plot close
echo "PASSED"

echo -n " save/load..."
xpaset -p DS9Test plot line plot/xy.dat xy
xpaset -p DS9Test plot save foo.dat
xpaset -p DS9Test plot theme no
sleep $delay
xpaset -p DS9Test plot close
echo "PASSED"

echo -n " add/delete graph..."
xpaset -p DS9Test plot line
xpaset -p DS9Test plot add graph line
xpaset -p DS9Test plot theme no
sleep $delay
xpaset -p DS9Test plot delete graph
xpaset -p DS9Test plot close
echo "PASSED"

echo -n " add/delete dataset..."
xpaset -p DS9Test plot line plot/xy.dat xy
xpaset -p DS9Test plot theme no
sleep $delay
xpaset -p DS9Test plot delete dataset
xpaset -p DS9Test plot close
echo "PASSED"

echo -n " layout..."
xpaset -p DS9Test plot line
xpaset -p DS9Test plot add graph line
xpaset -p DS9Test plot add graph bar
# backward compatibility
xpaset -p DS9Test plot add graph scatter
xpaget DS9Test plot layout >> /dev/null
xpaget DS9Test plot layout strip scale >> /dev/null
xpaset -p DS9Test plot theme no
sleep $delay
xpaset -p DS9Test plot layout row
xpaset -p DS9Test plot layout column
xpaset -p DS9Test plot layout strip
xpaset -p DS9Test plot layout strip scale 30
xpaset -p DS9Test plot layout grid
xpaset -p DS9Test plot close
echo "PASSED"

echo -n " duplicate..."
xpaset -p DS9Test plot line plot/xy.dat xy
xpaset -p DS9Test plot duplicate
xpaset -p DS9Test plot theme no
sleep $delay
xpaset -p DS9Test plot close
echo "PASSED"

echo -n " stats..."
xpaset -p DS9Test plot line plot/xy.dat xy
xpaget DS9Test plot stats >> /dev/null
xpaset -p DS9Test plot stats yes
xpaset -p DS9Test plot theme no
sleep $delay
xpaset -p DS9Test plot close
echo "PASSED"

echo -n " list..."
xpaset -p DS9Test plot line plot/xy.dat xy
xpaget DS9Test plot list >> /dev/null
xpaset -p DS9Test plot list yes
xpaset -p DS9Test plot theme no
sleep $delay
xpaset -p DS9Test plot close
echo "PASSED"

echo -n " backup/restore..."
xpaset -p DS9Test plot line plot/xy.dat xy
xpaset -p DS9Test plot theme no
xpaset -p DS9Test plot backup foo.plb
xpaset -p DS9Test plot restore foo.plb
xpaset -p DS9Test plot close
xpaset -p DS9Test plot restore foo.plb
sleep $delay
xpaset -p DS9Test plot close
echo "PASSED"

echo -n " pagesetup..."
xpaset -p DS9Test plot line plot/xy.dat xy
xpaset -p DS9Test plot pagesetup orient portrait
xpaset -p DS9Test plot pagesetup size letter
xpaset -p DS9Test plot theme no
sleep $delay
xpaset -p DS9Test plot close
echo "PASSED"

echo -n " print..."
xpaset -p DS9Test plot line plot/xy.dat xy
#xpaset -p DS9Test plot print
xpaset -p DS9Test plot print destination printer
xpaset -p DS9Test plot print command "lp"
xpaset -p DS9Test plot print filename "foo.ps"
xpaset -p DS9Test plot print color rgb
xpaset -p DS9Test plot theme no
sleep $delay
xpaset -p DS9Test plot close
echo "PASSED"

echo -n " mode..."
xpaset -p DS9Test plot line plot/xy.dat xy
xpaget DS9Test plot mode >> ${tt}.out
xpaset -p DS9Test plot mode pointer
xpaset -p DS9Test plot theme no
sleep $delay
xpaset -p DS9Test plot close
echo "PASSED"

echo -n " export..."
xpaset -p DS9Test plot line plot/xy.dat xy
#xpaset -p DS9Test plot export foo.gif
#xpaset -p DS9Test plot export gif foo.gif
#xpaset -p DS9Test plot export foo.tiff
#xpaset -p DS9Test plot export tiff foo.tiff
#xpaset -p DS9Test plot export foo.jpeg
#xpaset -p DS9Test plot export jpeg foo.jpeg
#xpaset -p DS9Test plot export foo.png
#xpaset -p DS9Test plot export png foo.png
xpaset -p DS9Test plot theme no
sleep $delay
xpaset -p DS9Test plot close
echo "PASSED"

echo -n " axis..."
xpaset -p DS9Test plot line plot/xy.dat xy
xpaset -p DS9Test plot axis x grid no
xpaset -p DS9Test plot axis x grid yes
xpaset -p DS9Test plot axis x log yes
xpaset -p DS9Test plot axis x log no
xpaset -p DS9Test plot axis x flip yes
xpaset -p DS9Test plot axis x flip no
xpaset -p DS9Test plot axis x auto no
xpaset -p DS9Test plot axis x min 1
xpaset -p DS9Test plot axis x max 100
xpaset -p DS9Test plot axis x format "%f"
xpaset -p DS9Test plot axis y grid no
xpaset -p DS9Test plot axis y grid yes
xpaset -p DS9Test plot axis y log yes
xpaset -p DS9Test plot axis y log no
xpaset -p DS9Test plot axis y flip yes
xpaset -p DS9Test plot axis y flip no
xpaset -p DS9Test plot axis y auto no
xpaset -p DS9Test plot axis y min 1
xpaset -p DS9Test plot axis y max 100
xpaset -p DS9Test plot axis y format "%f"
xpaget DS9Test plot axis x grid >> ${tt}.out
xpaget DS9Test plot axis x log >> ${tt}.out
xpaget DS9Test plot axis x flip >> ${tt}.out
xpaget DS9Test plot axis x auto >> ${tt}.out
xpaget DS9Test plot axis x min >> ${tt}.out
xpaget DS9Test plot axis x max >> ${tt}.out
xpaget DS9Test plot axis x format >> ${tt}.out
xpaget DS9Test plot axis y grid >> ${tt}.out
xpaget DS9Test plot axis y log >> ${tt}.out
xpaget DS9Test plot axis y flip >> ${tt}.out
xpaget DS9Test plot axis y auto >> ${tt}.out
xpaget DS9Test plot axis y min >> ${tt}.out
xpaget DS9Test plot axis y max >> ${tt}.out
xpaget DS9Test plot axis y format >> ${tt}.out
xpaset -p DS9Test plot theme no
sleep $delay
xpaset -p DS9Test plot close
echo "PASSED"

echo -n " foreground/background/grid color..."
xpaset -p DS9Test plot line plot/xy.dat xy
xpaget DS9Test plot foreground >> ${tt}.out
xpaget DS9Test plot background >> ${tt}.out
xpaget DS9Test plot grid color >> ${tt}.out
xpaset -p DS9Test plot foreground black
xpaset -p DS9Test plot background red
xpaset -p DS9Test plot grid color blue
xpaset -p DS9Test plot theme no
sleep $delay
xpaset -p DS9Test plot close
echo "PASSED"

echo -n " legend..."
xpaset -p DS9Test plot line plot/xy.dat xy
xpaget DS9Test plot legend >> ${tt}.out
xpaget DS9Test plot legend position >> ${tt}.out
xpaset -p DS9Test plot legend yes
xpaset -p DS9Test plot legend position left
xpaset -p DS9Test plot legend position right
xpaset -p DS9Test plot legend position bottom
xpaset -p DS9Test plot legend position top
xpaset -p DS9Test plot theme no
sleep $delay
xpaset -p DS9Test plot close
echo "PASSED"

echo -n " font..."
xpaset -p DS9Test plot line plot/xy.dat xy
xpaset -p DS9Test plot title {This is a Title}
xpaset -p DS9Test plot title xaxis {X Axis}
xpaset -p DS9Test plot title yaxis {Y Axis}
xpaset -p DS9Test plot title legend {This is the Legend}
xpaset -p DS9Test plot legend yes
xpaget DS9Test plot font title font >> ${tt}.out
xpaget DS9Test plot font title size >> ${tt}.out
xpaget DS9Test plot font title weight >> ${tt}.out
xpaget DS9Test plot font title slant >> ${tt}.out
# backward compatibility
xpaget DS9Test plot font title style >> ${tt}.out
xpaget DS9Test plot font labels font >> ${tt}.out
xpaget DS9Test plot font labels size >> ${tt}.out
xpaget DS9Test plot font labels weight >> ${tt}.out
xpaget DS9Test plot font labels slant >> ${tt}.out
# backward compatibility
xpaget DS9Test plot font labels style >> ${tt}.out
xpaget DS9Test plot font numbers font >> ${tt}.out
xpaget DS9Test plot font numbers size >> ${tt}.out
xpaget DS9Test plot font numbers weight >> ${tt}.out
xpaget DS9Test plot font numbers slant >> ${tt}.out
# backward compatibility
xpaget DS9Test plot font numbers style >> ${tt}.out
xpaget DS9Test plot font legend title font >> ${tt}.out
xpaget DS9Test plot font legend title size >> ${tt}.out
xpaget DS9Test plot font legend title weight >> ${tt}.out
xpaget DS9Test plot font legend title slant >> ${tt}.out
# backward compatibility
xpaget DS9Test plot font legend title style >> ${tt}.out
xpaget DS9Test plot font legend font >> ${tt}.out
xpaget DS9Test plot font legend size >> ${tt}.out
xpaget DS9Test plot font legend weight >> ${tt}.out
xpaget DS9Test plot font legend slant >> ${tt}.out
# backward compatibility
xpaget DS9Test plot font legend style >> ${tt}.out
xpaset -p DS9Test plot font title font times
xpaset -p DS9Test plot font title size 12
xpaset -p DS9Test plot font title weight bold
xpaset -p DS9Test plot font title slant roman
# backward compatibility
xpaset -p DS9Test plot font title style normal
xpaset -p DS9Test plot font labels font times
xpaset -p DS9Test plot font labels size 12
xpaset -p DS9Test plot font labels weight bold
xpaset -p DS9Test plot font labels slant roman
# backward compatibility
xpaset -p DS9Test plot font labels style normal
xpaset -p DS9Test plot font numbers font times
xpaset -p DS9Test plot font numbers size 12
xpaset -p DS9Test plot font numbers weight bold
xpaset -p DS9Test plot font numbers slant roman
# backward compatibility
xpaset -p DS9Test plot font numbers style normal
xpaset -p DS9Test plot font legend title font times
xpaset -p DS9Test plot font legend title size 12
xpaset -p DS9Test plot font legend title weight bold
xpaset -p DS9Test plot font legend title slant roman
# backward compatibility
xpaset -p DS9Test plot font legend title style normal
xpaset -p DS9Test plot font legend font times
xpaset -p DS9Test plot font legend size 12
xpaset -p DS9Test plot font legend weight bold
xpaset -p DS9Test plot font legend slant roman
# backward compatibility
xpaset -p DS9Test plot font legend style normal
xpaset -p DS9Test plot theme no
sleep $delay
xpaset -p DS9Test plot close
echo "PASSED"

echo -n " title..."
xpaset -p DS9Test plot line plot/xy.dat xy
xpaset -p DS9Test plot title {This is a Title}
xpaset -p DS9Test plot title x {X Axis}
xpaset -p DS9Test plot title y {Y Axis}
xpaset -p DS9Test plot title legend {This is the Legend}
xpaget DS9Test plot title >> ${tt}.out
xpaget DS9Test plot title x >> ${tt}.out
xpaget DS9Test plot title y >> ${tt}.out
xpaget DS9Test plot title legend >> ${tt}.out
xpaset -p DS9Test plot theme no
sleep $delay
xpaset -p DS9Test plot close
echo "PASSED"

echo -n " dataset..."
xpaset -p DS9Test plot line plot/xy.dat xy
xpaget DS9Test plot show >> ${tt}.out
xpaget DS9Test plot name >> ${tt}.out
xpaset -p DS9Test plot show no
xpaset -p DS9Test plot show yes
xpaset -p DS9Test plot legend yes
xpaset -p DS9Test plot name {This is a test}
xpaset -p DS9Test plot theme no
sleep $delay
xpaset -p DS9Test plot close
echo "PASSED"

echo -n " line dataset..."
xpaset -p DS9Test plot line plot/xy.dat xy
xpaget DS9Test plot line smooth >> ${tt}.out
xpaget DS9Test plot line color >> ${tt}.out
xpaget DS9Test plot line width >> ${tt}.out
xpaget DS9Test plot line dash >> ${tt}.out
xpaget DS9Test plot line fill >> ${tt}.out
xpaget DS9Test plot line fill color >> ${tt}.out
xpaget DS9Test plot line shape symbol >> ${tt}.out
xpaget DS9Test plot line shape size >> ${tt}.out
xpaget DS9Test plot line shape color >> ${tt}.out
xpaget DS9Test plot line shape fill >> ${tt}.out

xpaset -p DS9Test plot line smooth linear
xpaset -p DS9Test plot line smooth cubic
xpaset -p DS9Test plot line smooth quadratic
xpaset -p DS9Test plot line smooth catrom
xpaset -p DS9Test plot line color magenta
xpaset -p DS9Test plot line color "#2C8"
xpaset -p DS9Test plot line width 2
xpaset -p DS9Test plot line dash yes
xpaset -p DS9Test plot line fill yes
xpaset -p DS9Test plot line fill color green
xpaset -p DS9Test plot line shape symbol none
xpaset -p DS9Test plot line shape symbol square
xpaset -p DS9Test plot line shape symbol diamond
xpaset -p DS9Test plot line shape symbol plus
xpaset -p DS9Test plot line shape symbol splus
xpaset -p DS9Test plot line shape symbol scross
xpaset -p DS9Test plot line shape symbol triangle
xpaset -p DS9Test plot line shape symbol arrow
xpaset -p DS9Test plot line shape symbol circle
xpaset -p DS9Test plot line shape size 5
xpaset -p DS9Test plot line shape color cyan
xpaset -p DS9Test plot line shape fill yes

xpaset -p DS9Test plot theme no
sleep $delay
xpaset -p DS9Test plot close
echo "PASSED"

echo -n " bar dataset..."
xpaset -p DS9Test plot bar plot/xy.dat xy
xpaget DS9Test plot bar border color >> ${tt}.out
xpaget DS9Test plot bar border width >> ${tt}.out
xpaget DS9Test plot bar fill >> ${tt}.out
xpaget DS9Test plot bar color >> ${tt}.out
xpaget DS9Test plot bar width >> ${tt}.out

xpaset -p DS9Test plot bar border color magenta
xpaset -p DS9Test plot bar border width 1
xpaset -p DS9Test plot bar fill yes
xpaset -p DS9Test plot bar color black
xpaset -p DS9Test plot bar width 1

xpaset -p DS9Test plot theme no
sleep $delay
xpaset -p DS9Test plot close
echo "PASSED"

# backward compatibility
echo -n " scatter dataset..."
xpaset -p DS9Test plot scatter plot/xy.dat xy
xpaget DS9Test plot scatter symbol >> ${tt}.out
xpaget DS9Test plot scatter size >> ${tt}.out
xpaget DS9Test plot scatter color >> ${tt}.out
xpaget DS9Test plot scatter fill >> ${tt}.out

xpaset -p DS9Test plot scatter symbol square
xpaset -p DS9Test plot scatter symbol diamond
xpaset -p DS9Test plot scatter symbol plus
xpaset -p DS9Test plot scatter symbol splus
xpaset -p DS9Test plot scatter symbol scross
xpaset -p DS9Test plot scatter symbol triangle
xpaset -p DS9Test plot scatter symbol arrow
xpaset -p DS9Test plot scatter symbol circle
xpaset -p DS9Test plot scatter size 5
xpaset -p DS9Test plot scatter color cyan
xpaset -p DS9Test plot scatter fill yes

xpaset -p DS9Test plot theme no
sleep $delay
xpaset -p DS9Test plot close
echo "PASSED"

echo -n " error dataset..."
xpaset -p DS9Test plot line plot/xyexey.dat xyexey
xpaget DS9Test plot error >> ${tt}.out
xpaget DS9Test plot error cap >> ${tt}.out
xpaget DS9Test plot error color >> ${tt}.out
xpaget DS9Test plot error width >> ${tt}.out
xpaset -p DS9Test plot error no
xpaset -p DS9Test plot error yes
xpaset -p DS9Test plot error cap yes
xpaset -p DS9Test plot error cap no
xpaset -p DS9Test plot error color blue
xpaset -p DS9Test plot error width 2
xpaset -p DS9Test plot theme no
sleep $delay
xpaset -p DS9Test plot close
echo "PASSED"

echo -n " current..."
#   will fail if not first time thru
xpaset -p DS9Test plot line plot/xy.dat xy
xpaset -p DS9Test plot line plot/xy.dat xy
xpaset -p DS9Test plot load plot/xyey.dat xyey
xpaget DS9Test plot current >> ${tt}.out
xpaget DS9Test plot current graph >> ${tt}.out
xpaget DS9Test plot current dataset >> ${tt}.out
xpaset -p DS9Test plot current ap2
xpaset -p DS9Test plot current graph 1
xpaset -p DS9Test plot current dataset 1
xpaset -p DS9Test plot theme no
sleep $delay
xpaset -p DS9Test plot close
xpaset -p DS9Test plot close
echo "PASSED"

testit $tt
fi

tt="png"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaset -p DS9Test frame new
xpaset -p DS9Test png photo/rose.png
cat photo/rose.png | xpaset DS9Test png
xpaget DS9Test png > /dev/null
xpaset -p DS9Test frame delete

xpaset -p DS9Test png new photo/rose.png
xpaset -p DS9Test png slice photo/rose.png
xpaset -p DS9Test frame delete

testit $tt
fi

# backward compatibility prefs
tt="precision"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaget DS9Test precision >> ${tt}.out
xpaset -p DS9Test precision 8 7 4 3 8 7 5 3 8

testit $tt
fi

tt="prefs"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo "$tt..."
xpaset -p DS9Test prefs clear
xpaset -p DS9Test prefs irafalign yes

xpaget DS9Test prefs has bg >> ${tt}.out
xpaget DS9Test prefs bg >> ${tt}.out
xpaget DS9Test prefs bg color >> ${tt}.out
xpaget DS9Test prefs bgcolor >> ${tt}.out
xpaget DS9Test prefs nan >> ${tt}.out
xpaget DS9Test prefs nan color >> ${tt}.out
xpaget DS9Test prefs nancolor >> ${tt}.out
xpaget DS9Test prefs precision >> ${tt}.out
xpaget DS9Test prefs auto recovery >> ${tt}.out
xpaget DS9Test prefs auto recovery interval >> ${tt}.out
xpaget DS9Test prefs theme >> ${tt}.out
xpaget DS9Test prefs threads >> ${tt}.out
xpaget DS9Test prefs irafalign >> ${tt}.out

xpaset -p DS9Test prefs open
xpaset -p DS9Test prefs save
xpaset -p DS9Test prefs clear
xpaset -p DS9Test prefs close
xpaset -p DS9Test prefs bg no
xpaset -p DS9Test prefs bg color no
xpaset -p DS9Test prefs bgcolor no
xpaset -p DS9Test prefs bg white
xpaset -p DS9Test prefs bg color white
xpaset -p DS9Test prefs bgcolor white
xpaset -p DS9Test prefs nan white
xpaset -p DS9Test prefs nan color white
xpaset -p DS9Test prefs nancolor white
xpaset -p DS9Test prefs precision 8 7 4 3 8 7 5 3 8
xpaset -p DS9Test prefs auto recovery yes
xpaset -p DS9Test prefs auto recovery interval 5
xpaset -p DS9Test prefs theme default
xpaset -p DS9Test prefs threads 12
xpaset -p DS9Test prefs irafalign yes

testit $tt
fi

tt="preserve"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaget DS9Test preserve pan >> ${tt}.out
xpaget DS9Test preserve regions >> ${tt}.out
xpaset -p DS9Test preserve pan no
xpaset -p DS9Test preserve regions no

testit $tt
fi

# can only be run local
tt="print"
if [ "$1" = "$tt" ]; then
echo -n "$tt..."
xpaget DS9Test psprint destination >> ${tt}.out
xpaget DS9Test psprint command >> ${tt}.out
xpaget DS9Test psprint color >> ${tt}.out
xpaget DS9Test psprint level >> ${tt}.out
xpaget DS9Test psprint resolution >> ${tt}.out
#xpaset -p DS9Test psprint
xpaset -p DS9Test psprint destination printer
xpaset -p DS9Test psprint command lp
xpaset -p DS9Test psprint filename ds9.ps
xpaset -p DS9Test psprint color rgb
xpaset -p DS9Test psprint level 2
xpaset -p DS9Test psprint resolution 150

testit $tt
fi

tt="prism"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaset -p DS9Test prism
xpaget DS9Test prism  >> ${tt}.out
xpaset -p DS9Test prism close
xpaset -p DS9Test prism open
xpaset -p DS9Test prism close
xpaset -p DS9Test prism fits/img.fits
xpaset -p DS9Test prism clear
xpaset -p DS9Test prism close

xpaset -p DS9Test prism fits/table.fits
xpaset -p DS9Test prism export vot foo.vot
xpaset -p DS9Test prism export rdb foo.rdb
xpaset -p DS9Test prism export tsv foo.tsv
xpaset -p DS9Test prism import vot foo.vot
xpaset -p DS9Test prism import rdb foo.rdb
xpaset -p DS9Test prism import tsv foo.tsv
xpaset -p DS9Test prism close
xpaset -p DS9Test prism close
xpaset -p DS9Test prism close
xpaset -p DS9Test prism close

xpaset -p DS9Test prism fits/table.fits
xpaset -p DS9Test prism ext 1
xpaset -p DS9Test prism ext REJEVT
xpaset -p DS9Test prism first
xpaset -p DS9Test prism next
xpaset -p DS9Test prism prev
xpaset -p DS9Test prism last
xpaset -p DS9Test prism goto 501
xpaset -p DS9Test prism image
xpaset -p DS9Test frame delete
xpaset -p DS9Test prism mode newplot
xpaset -p DS9Test prism histogram PHA 40
xpaset -p DS9Test prism histogram PHA 40 0 4000
xpaset -p DS9Test prism plot X Y xy
xpaset -p DS9Test prism close

xpaset -p DS9Test plot close
xpaset -p DS9Test plot close
xpaset -p DS9Test plot close
xpaset -p DS9Test plot close
xpaset -p DS9Test plot close

xpaset -p DS9Test prism import xml data/ds9.xml
xpaset -p DS9Test prism plot Jmag Hmag xy
xpaset -p DS9Test prism histogram Jmag 10
xpaset -p DS9Test prism close

xpaset -p DS9Test plot close
xpaset -p DS9Test plot close

testit $tt
fi

tt="raise"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaset -p DS9Test lower
xpaset -p DS9Test raise

testit $tt
fi

tt="region"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt/region..."
xpaset -p DS9Test region delete
xpaset -p DS9Test region system physical
xpaset -p DS9Test region sky fk5
xpaset -p DS9Test region skyformat degrees
echo "physical;circle(957,1027,40) # tag=foo" | xpaset DS9Test region

xpaget DS9Test region >> ${tt}.out
xpaget DS9Test region epsilon >> ${tt}.out
xpaget DS9Test region show >> ${tt}.out
xpaget DS9Test region showtext >> ${tt}.out
xpaget DS9Test region centroid auto >> ${tt}.out
xpaget DS9Test region centroid radius >> ${tt}.out
xpaget DS9Test region centroid iteration >> ${tt}.out
xpaget DS9Test region -format pros -system wcs -sky fk5 -skyformat sexagesimal -prop edit 1 -group foo -strip yes >> ${tt}.out
xpaget DS9Test region include >> ${tt}.out
xpaget DS9Test region exclude >> ${tt}.out
xpaget DS9Test region source >> ${tt}.out
xpaget DS9Test region background >> ${tt}.out
xpaget DS9Test region selected >> ${tt}.out

xpaget DS9Test region format >> ${tt}.out
xpaget DS9Test region system >> ${tt}.out
xpaget DS9Test region sky >> ${tt}.out
xpaget DS9Test region skyformat >> ${tt}.out
xpaget DS9Test region strip >> ${tt}.out

xpaget DS9Test region shape >> ${tt}.out
xpaget DS9Test region color >> ${tt}.out
xpaget DS9Test region fill >> ${tt}.out
xpaget DS9Test region width >> ${tt}.out
xpaget DS9Test region dash >> ${tt}.out

xpaget DS9Test region font >> ${tt}.out
xpaget DS9Test region fontsize >> ${tt}.out
xpaget DS9Test region fontweight >> ${tt}.out
xpaget DS9Test region fontslant >> ${tt}.out

xpaget DS9Test region groups >> ${tt}.out

echo "image; circle 100 100 20" | xpaset DS9Test region
echo "fk5; circle 13:29:55 47:11:50 .5'" | xpaset DS9Test region
echo "physical; ellipse 100 100 20 40" | xpaset DS9Test region
echo "box 100 100 20 40 25" | xpaset DS9Test region
echo "image; line 100 100 200 400" | xpaset DS9Test region
echo "physical; ruler 200 300 200 400" | xpaset DS9Test region
echo "image; text 100 100 # text={Hello, World}" | xpaset DS9Test region
echo "fk4; boxcircle point 13:29:55 47:11:50" | xpaset DS9Test region
xpaset -p DS9Test region delete

xpaset -p DS9Test region regions/ds9.physical.reg
xpaset -p DS9Test region delete
xpaset -p DS9Test region load regions/ds9.physical.reg
xpaset -p DS9Test region delete
xpaset -p DS9Test region load 'regions/ds9.fk5*.reg'
xpaset -p DS9Test region delete
xpaset -p DS9Test region load all regions/ds9.physical.reg
xpaset -p DS9Test region delete load regions/ds9.physical.reg

xpaset -p DS9Test region save foo.reg
xpaset -p DS9Test region save select foo.reg
xpaset -p DS9Test region delete
xpaset -p DS9Test region list
xpaset -p DS9Test region list select
xpaset -p DS9Test region list close
xpaset -p DS9Test region delete

xpaset -p DS9Test region epsilon 5
xpaset -p DS9Test region show yes
xpaset -p DS9Test region showtext yes
xpaset -p DS9Test region centroid
xpaset -p DS9Test region centroid auto no
xpaset -p DS9Test region centroid radius 10
xpaset -p DS9Test region centroid iteration 30
xpaset -p DS9Test region move front
xpaset -p DS9Test region move back
xpaset -p DS9Test region select all
xpaset -p DS9Test region select none
xpaset -p DS9Test region select front
xpaset -p DS9Test region select back
xpaset -p DS9Test region delete
xpaset -p DS9Test region delete select
xpaset -p DS9Test region format ds9
xpaset -p DS9Test region system physical
xpaset -p DS9Test region sky fk5
xpaset -p DS9Test region skyformat degrees
xpaset -p DS9Test region strip no

xpaset -p DS9Test region shape circle
xpaset -p DS9Test region color green
xpaset -p DS9Test region fill no
xpaset -p DS9Test region width 1
xpaset -p DS9Test region dash no

xpaset -p DS9Test region font times
xpaset -p DS9Test region fontsize 24
xpaset -p DS9Test region fontweight bold
xpaset -p DS9Test region fontslant italic

xpaset -p DS9Test region edit yes
xpaset -p DS9Test region include

xpaset -p DS9Test region group new
xpaset -p DS9Test region group foo new
xpaset -p DS9Test region group foo update
xpaset -p DS9Test region group foo select
xpaset -p DS9Test region group foo color red
xpaset -p DS9Test region group foo copy
xpaset -p DS9Test region group foo delete
xpaset -p DS9Test region group foo cut
xpaset -p DS9Test region group foo font {times 14 bold}
xpaset -p DS9Test region group foo move 100 100
xpaset -p DS9Test region group foo movefront
xpaset -p DS9Test region group foo moveback
xpaset -p DS9Test region group foo property delete no

xpaset -p DS9Test region delete

xpaset -p DS9Test region command {circle 100 100 20}
xpaset -p DS9Test region select all
xpaset -p DS9Test region copy
xpaset -p DS9Test region cut
xpaset -p DS9Test region paste
xpaset -p DS9Test region paste wcs
xpaset -p DS9Test region undo
xpaset -p DS9Test region delete

xpaset -p DS9Test region load regions/ds9.physical.reg
xpaset -p DS9Test region select all
xpaset -p DS9Test region composite
xpaset -p DS9Test region dissolve
xpaset -p DS9Test region delete

xpaset -p DS9Test region command {circle 100 100 20}
xpaset -p DS9Test region analysis stats
xpaset -p DS9Test region analysis stats close
#xpaset -p DS9Test region analysis histogram save
xpaset -p DS9Test region analysis plot3d
xpaset -p DS9Test region analysis plot3d close
xpaset -p DS9Test region analysis surface3d
xpaset -p DS9Test region analysis surface3d close
xpaset -p DS9Test region savetemplate foo.tpl
xpaset -p DS9Test region delete
xpaset -p DS9Test region template foo.tpl
xpaset -p DS9Test region delete
xpaset -p DS9Test region template foo.tpl at 202.46963 47.19556 fk5
xpaset -p DS9Test region delete

xpaset -p DS9Test region load regions/ds9.physical.reg
xpaset -p DS9Test region select all
xpaset -p DS9Test region open
xpaset -p DS9Test region close
xpaset -p DS9Test region delete

testit $tt
fi

tt="rgb"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaset -p DS9Test rgb open
xpaset -p DS9Test rgb close
xpaset -p DS9Test rgb
xpaget DS9Test rgb channel >> ${tt}.out
xpaget DS9Test rgb view red >> ${tt}.out
xpaget DS9Test rgb view green >> ${tt}.out
xpaget DS9Test rgb view blue >> ${tt}.out
xpaget DS9Test rgb system >> ${tt}.out
xpaget DS9Test rgb lock wcs >> ${tt}.out
xpaget DS9Test rgb lock crop >> ${tt}.out
xpaget DS9Test rgb lock slice >> ${tt}.out
xpaget DS9Test rgb lock bin >> ${tt}.out
xpaget DS9Test rgb lock scale >> ${tt}.out
xpaget DS9Test rgb lock scalelimits >> ${tt}.out
xpaget DS9Test rgb lock colorbar >> ${tt}.out
xpaget DS9Test rgb lock block >> ${tt}.out
xpaget DS9Test rgb lock smooth >> ${tt}.out
xpaset -p DS9Test rgb green
xpaset -p DS9Test rgb channel blue
xpaset -p DS9Test rgb view blue off
xpaset -p DS9Test rgb system wcs
xpaset -p DS9Test rgb lock wcs yes
xpaset -p DS9Test rgb lock wcs no
xpaset -p DS9Test rgb lock crop yes
xpaset -p DS9Test rgb lock crop no
xpaset -p DS9Test rgb lock slice yes
xpaset -p DS9Test rgb lock slice no
xpaset -p DS9Test rgb lock bin yes
xpaset -p DS9Test rgb lock bin no
xpaset -p DS9Test rgb lock scale yes
xpaset -p DS9Test rgb lock scale no
# will set to scale user mode
xpaset -p DS9Test rgb lock scalelimits yes
xpaset -p DS9Test rgb lock scalelimits no
xpaset -p DS9Test scale zscale
xpaset -p DS9Test rgb lock colorbar yes
xpaset -p DS9Test rgb lock colorbar no
xpaset -p DS9Test rgb lock block yes
xpaset -p DS9Test rgb lock block no
xpaset -p DS9Test rgb lock smooth yes
xpaset -p DS9Test rgb lock smooth no
xpaset -p DS9Test rgb close
xpaset -p DS9Test frame delete

testit $tt
fi

tt="rgbarray"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaset -p DS9Test frame new rgb
xpaset -p DS9Test rgbarray rgbarray/float_big.rgb[dim=256,bitpix=-32,endian=big]
cat rgbarray/float_big.rgb | xpaset DS9Test rgbarray -[dim=256,bitpix=-32,endian=big]
xpaget DS9Test rgbarray big > /dev/null
xpaset -p DS9Test frame delete

xpaset -p DS9Test rgbarray new rgbarray/float_big.rgb[dim=256,bitpix=-32,endian=big]
xpaset -p DS9Test frame delete

xpaset -p DS9Test rgb close
testit $tt
fi

tt="rgbimage"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaset -p DS9Test frame new rgb
xpaset -p DS9Test rgbimage rgb/rgbimage.fits
cat rgb/rgbimage.fits | xpaset DS9Test rgbimage
xpaget DS9Test rgbimage > /dev/null
xpaset -p DS9Test frame delete

xpaset -p DS9Test rgbimage new rgb/rgbimage.fits
xpaset -p DS9Test frame delete

xpaset -p DS9Test rgb close
testit $tt
fi

tt="rgbcube"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaset -p DS9Test frame new rgb
xpaset -p DS9Test rgbcube rgb/rgbcube.fits
cat rgb/rgbcube.fits | xpaset DS9Test rgbcube
xpaget DS9Test rgbcube > /dev/null
xpaset -p DS9Test frame delete

xpaset -p DS9Test rgbcube new rgb/rgbcube.fits
xpaset -p DS9Test frame delete

xpaset -p DS9Test rgb close
testit $tt
fi

tt="rotate"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaget DS9Test rotate >> ${tt}.out
xpaset -p DS9Test rotate open
xpaset -p DS9Test rotate to 30
xpaset -p DS9Test rotate 15
xpaset -p DS9Test rotate close
xpaset -p DS9Test frame reset

testit $tt
fi

tt="samp"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "samp..."

xpaset -p DS9Test fits new fits/table.fits
#xpaset -p DS9Test samp connect
xpaset -p DS9Test samp broadcast
xpaset -p DS9Test samp broadcast table
xpaset -p DS9Test samp send topcat
xpaset -p DS9Test samp send table topcat
xpaset -p DS9Test samp hub info
xpaset -p DS9Test frame delete

testit $tt
fi

tt="save"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo "$tt/savefits..."

echo -n " fits..."
xpaset -p DS9Test save foo.fits
xpaset -p DS9Test save fits foo.fits
xpaset -p DS9Test save foo.fits image
xpaset -p DS9Test save fits foo.fits image
xpaset -p DS9Test save foo.fits slice
xpaset -p DS9Test save fits foo.fits slice
echo "PASSED"

echo -n " pixmask..."
xpaset -p DS9Test region command {circle 100 100 20}
xpaset -p DS9Test save pixmask foo.pixmask.fits
xpaset -p DS9Test region delete all
echo "PASSED"

xpaset -p DS9Test frame new
xpaset -p DS9Test fits fits/table.fits
xpaset -p DS9Test save foo.fits
xpaset -p DS9Test save fits foo.fits
xpaset -p DS9Test save foo.fits image
xpaset -p DS9Test save fits foo.fits image
xpaset -p DS9Test save foo.fits table
xpaset -p DS9Test save fits foo.fits table
xpaset -p DS9Test frame delete
echo "PASSED"

echo -n " mecube..."
xpaset -p DS9Test frame new
xpaset -p DS9Test mecube mecube/float.fits
xpaset -p DS9Test save mecube foo.fits
xpaset -p DS9Test frame delete
echo "PASSED"

echo -n " mosaicimage..."
xpaset -p DS9Test frame new
xpaset -p DS9Test mosaicimage mosaic/mosaicimage.fits
xpaset -p DS9Test save mosaicimage foo.fits
xpaset -p DS9Test frame delete
echo "PASSED"

echo -n " mosaic..."
xpaset -p DS9Test frame new
xpaset -p DS9Test mosaicimage mosaic/mosaicimage.fits
xpaset -p DS9Test save mosaic foo.fits
xpaset -p DS9Test frame delete
echo "PASSED"

echo -n " rgbimage..."
xpaset -p DS9Test frame new rgb
xpaset -p DS9Test rgbimage rgb/rgbimage.fits
xpaset -p DS9Test save rgbimage foo.fits
xpaset -p DS9Test frame delete
echo "PASSED"

echo -n " rgbcube..."
xpaset -p DS9Test frame new rgb
xpaset -p DS9Test rgbcube rgb/rgbcube.fits
xpaset -p DS9Test save rgbcube foo.fits
xpaset -p DS9Test frame delete
echo "PASSED"

echo -n " hlsimage..."
xpaset -p DS9Test frame new hls
xpaset -p DS9Test hlsimage hls/hlsimage.fits
xpaset -p DS9Test save hlsimage foo.fits
xpaset -p DS9Test frame delete
echo "PASSED"

echo -n " hlscube..."
xpaset -p DS9Test frame new hls
xpaset -p DS9Test hlscube hls/hlscube.fits
xpaset -p DS9Test save hlscube foo.fits
xpaset -p DS9Test frame delete
echo "PASSED"

echo -n " hsvimage..."
xpaset -p DS9Test frame new hsv
xpaset -p DS9Test hsvimage hsv/hsvimage.fits
xpaset -p DS9Test save hsvimage foo.fits
xpaset -p DS9Test frame delete
echo "PASSED"

echo -n " hsvcube..."
xpaset -p DS9Test frame new hsv
xpaset -p DS9Test hsvcube hsv/hsvcube.fits
xpaset -p DS9Test save hsvcube foo.fits
xpaset -p DS9Test frame delete
echo "PASSED"

# backward compatibility
echo -n " savefits..."
xpaset -p DS9Test savefits foo.fits
echo "PASSED"

xpaset -p DS9Test rgb close
xpaset -p DS9Test hls close
xpaset -p DS9Test hsv close
xpaset -p DS9Test cube close
testit $tt
fi

tt="saveimage"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaset -p DS9Test saveimage fits foo.fits
xpaset -p DS9Test saveimage foo.fits
xpaset -p DS9Test saveimage eps foo.eps
xpaset -p DS9Test saveimage foo.eps
#xpaset -p DS9Test saveimage foo.gif
xpaset -p DS9Test saveimage tiff foo.tiff none
xpaset -p DS9Test saveimage foo.tiff
xpaset -p DS9Test saveimage jpeg foo.jpeg 100
xpaset -p DS9Test saveimage foo.jpeg
xpaset -p DS9Test saveimage png foo.png
xpaset -p DS9Test saveimage foo.png

# backward compatibility
xpaset -p DS9Test saveimage tiff none foo.tiff
xpaset -p DS9Test saveimage jpeg 100 foo.jpeg
#xpaset -p DS9Test saveimage mpeg foo.mpeg

testit $tt
fi

tt="scale"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaget DS9Test scale >> ${tt}.out
xpaget DS9Test scale log exp >> ${tt}.out
xpaget DS9Test scale limits >> ${tt}.out
xpaget DS9Test scale mode >> ${tt}.out
xpaget DS9Test scale scope >> ${tt}.out
xpaget DS9Test scale datasec >> ${tt}.out
xpaget DS9Test scale lock >> ${tt}.out
xpaget DS9Test scale lock limits >> ${tt}.out
xpaset -p DS9Test scale open
xpaset -p DS9Test scale minmax
xpaset -p DS9Test scale linear
xpaset -p DS9Test scale log
xpaset -p DS9Test scale pow
xpaset -p DS9Test scale sqrt
xpaset -p DS9Test scale squared
xpaset -p DS9Test scale asinh
xpaset -p DS9Test scale sinh
xpaset -p DS9Test scale histequ
xpaset -p DS9Test scale log exp 1000
xpaset -p DS9Test scale log exp 10000
xpaset -p DS9Test scale linear
xpaset -p DS9Test scale minmax
xpaset -p DS9Test scale zscale
xpaset -p DS9Test scale zmax
xpaset -p DS9Test scale user
xpaset -p DS9Test scale mode zscale
xpaset -p DS9Test scale mode zmax
xpaset -p DS9Test scale mode 95
xpaset -p DS9Test scale mode minmax
# will set to scale user mode
xpaset -p DS9Test scale limits 0 100
xpaset -p DS9Test scale global
xpaset -p DS9Test scale local
xpaset -p DS9Test scale scope global
xpaset -p DS9Test scale scope local
xpaset -p DS9Test scale mode minmax
xpaset -p DS9Test scale linear
xpaset -p DS9Test scale zscale
xpaset -p DS9Test scale datasec yes
xpaset -p DS9Test scale match
xpaset -p DS9Test scale match limits
xpaset -p DS9Test scale lock yes
xpaset -p DS9Test scale lock no
# will set to scale user mode
xpaset -p DS9Test scale lock limits yes
xpaset -p DS9Test scale lock limits no
xpaset -p DS9Test scale zscale
xpaset -p DS9Test scale close

testit $tt
fi

tt="single"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaget DS9Test single >> ${tt}.out
xpaset -p DS9Test tile
xpaget DS9Test single >> ${tt}.out
xpaset -p DS9Test single
xpaget DS9Test single >> ${tt}.out

testit $tt
fi

tt="shm"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt...no test..."

testit $tt
fi

tt="sia"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaset -p DS9Test sia mast
xpaset -p DS9Test sia cxc
xpaset -p DS9Test sia current mast

xpaset -p DS9Test sia registry
xpaset -p DS9Test sia registry filter Chandra
xpaset -p DS9Test sia registry ivoid ivo://cxc.harvard.edu/cda.siap
xpaset -p DS9Test sia registry load
xpaset -p DS9Test sia registry clear
xpaset -p DS9Test sia registry retrieve

xpaget DS9Test sia >> ${tt}.out
xpaset -p DS9Test sia save foo.xml
xpaset -p DS9Test sia export rdb foo.rdb
xpaset -p DS9Test sia export tsv foo.tsv

xpaset -p DS9Test sia name m51
xpaset -p DS9Test sia coordinate 202.48 47.21 fk5
xpaset -p DS9Test sia system wcs
xpaset -p DS9Test sia sky fk5
xpaset -p DS9Test sia skyformat degrees
xpaset -p DS9Test sia radius 22 arcmin
# backward compatibility
xpaset -p DS9Test sia size 20 24 arcmin
xpaset -p DS9Test sia retrieve
xpaset -p DS9Test sia crosshair
xpaset -p DS9Test sia save foo.xml
xpaset -p DS9Test sia cancel
#xpaset -p DS9Test sia print
xpaset -p DS9Test sia close
xpaset -p DS9Test sia close

testit $tt
fi

tt="skyview"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaset -p DS9Test skyview open
xpaset -p DS9Test skyview close
xpaset -p DS9Test skyview survey DSS
xpaget DS9Test skyview survey >> ${tt}.out
xpaset -p DS9Test skyview size 30 30 arcsec
xpaget DS9Test skyview size >> ${tt}.out
xpaset -p DS9Test skyview pixels 600 600
xpaget DS9Test skyview pixels >> ${tt}.out
xpaset -p DS9Test skyview save no
xpaget DS9Test skyview save >> ${tt}.out
xpaset -p DS9Test skyview frame new
xpaget DS9Test skyview frame >> ${tt}.out
xpaset -p DS9Test skyview update frame
xpaset -p DS9Test skyview m51
xpaset -p DS9Test skyview name m51
xpaget DS9Test skyview name >> ${tt}.out
xpaset -p DS9Test skyview name clear
xpaset -p DS9Test skyview 13:29:52.37 +47:11:40.8
# backward compatibility
xpaset -p DS9Test skyview coord 13:29:52.37 +47:11:40.8 sexagesimal
xpaget DS9Test skyview coord >> ${tt}.out
xpaset -p DS9Test skyview update frame
xpaset -p DS9Test mode crosshair
xpaset -p DS9Test skyview update crosshair
xpaset -p DS9Test skyview close
xpaset -p DS9Test mode none
xpaset -p DS9Test frame delete
xpaset -p DS9Test frame delete
xpaset -p DS9Test frame delete
xpaset -p DS9Test frame delete
xpaset -p DS9Test frame delete
xpaset -p DS9Test frame delete
xpaset -p DS9Test frame delete

testit $tt
fi

tt="sleep"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaset -p DS9Test sleep
xpaset -p DS9Test sleep 2

testit $tt
fi

tt="smooth"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaget DS9Test smooth >> ${tt}.out
xpaget DS9Test smooth function >> ${tt}.out
xpaget DS9Test smooth radius >> ${tt}.out
xpaget DS9Test smooth radiusminor >> ${tt}.out
xpaget DS9Test smooth sigma >> ${tt}.out
xpaget DS9Test smooth sigmaminor >> ${tt}.out
xpaget DS9Test smooth angle >> ${tt}.out
xpaset -p DS9Test smooth open
xpaset -p DS9Test smooth
xpaset -p DS9Test smooth yes
xpaset -p DS9Test smooth function elliptic
xpaset -p DS9Test smooth radius 4
xpaset -p DS9Test smooth radiusminor 2
xpaset -p DS9Test smooth sigma 2
xpaset -p DS9Test smooth sigmaminor 2
xpaset -p DS9Test smooth angle 45
xpaset -p DS9Test smooth match
xpaset -p DS9Test smooth lock yes
xpaset -p DS9Test smooth lock no
xpaset -p DS9Test smooth no
xpaset -p DS9Test smooth close

testit $tt
fi

# can only be run local
tt="source"
if [ "$1" = "$tt" ]; then
echo -n "$tt..."
xpaset -p DS9Test source aux/source.tcl

testit $tt
fi

# can only be run local
tt="tcl"
if [ "$1" = "$tt" ]; then
echo -n "$tt..."
cat aux/hello.tcl | xpaset DS9Test tcl
echo 'puts "Hello World"' | xpaset DS9Test tcl
xpaset -p DS9Test tcl {puts {Hello Again, World}}

testit $tt
fi

# backward compatibility prefs
tt="theme"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaget DS9Test theme >> ${tt}.out
xpaset -p DS9Test theme default

testit $tt
fi

# backward compatibility prefs
tt="threads"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaget DS9Test threads >> ${tt}.out
xpaset -p DS9Test threads 12

testit $tt
fi

tt="tiff"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt/tif..."
xpaset -p DS9Test frame new
xpaset -p DS9Test tiff photo/rose.tiff
cat photo/rose.tiff | xpaset DS9Test tiff
xpaget DS9Test tiff > /dev/null
xpaget DS9Test tiff jpeg > /dev/null
xpaset -p DS9Test frame delete

xpaset -p DS9Test tiff new photo/rose.tiff
xpaset -p DS9Test tiff slice photo/rose.tiff
xpaset -p DS9Test frame delete

testit $tt
fi

tt="tile"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaget DS9Test tile >> ${tt}.out
xpaget DS9Test tile mode >> ${tt}.out
xpaget DS9Test tile grid mode >> ${tt}.out
xpaget DS9Test tile grid direction >> ${tt}.out
xpaset -p DS9Test fits new fits/img.fits
xpaset -p DS9Test fits new fits/img.fits
xpaset -p DS9Test tile
xpaset -p DS9Test tile yes
xpaset -p DS9Test tile row
xpaset -p DS9Test tile column
xpaset -p DS9Test tile grid
xpaset -p DS9Test tile grid mode automatic
xpaset -p DS9Test tile grid direction x
xpaset -p DS9Test frame delete
xpaset -p DS9Test frame delete

testit $tt
fi

tt="update"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaset -p DS9Test update
xpaset -p DS9Test update 1 100 100 300 400

testit $tt
fi

tt="url"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaset -p DS9Test frame new
xpaset -p DS9Test url http://ds9.si.edu/download/data/img.fits
xpaset -p DS9Test frame delete
testit $tt
fi

tt="version"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaget DS9Test version >> /dev/null

testit $tt
fi

tt="view"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaget DS9Test view layout >> ${tt}.out
xpaget DS9Test view multi >> ${tt}.out
xpaget DS9Test view keyvalue >> ${tt}.out
xpaget DS9Test view info >> ${tt}.out
xpaget DS9Test view panner >> ${tt}.out
xpaget DS9Test view magnifier >> ${tt}.out
xpaget DS9Test view buttons >> ${tt}.out
xpaget DS9Test view icons >> ${tt}.out
xpaget DS9Test view colorbar >> ${tt}.out
xpaget DS9Test view graph horizontal >> ${tt}.out
xpaget DS9Test view graph vertical >> ${tt}.out
xpaget DS9Test view filename >> ${tt}.out
xpaget DS9Test view object >> ${tt}.out
xpaget DS9Test view keyword >> ${tt}.out
xpaget DS9Test view minmax >> ${tt}.out
xpaget DS9Test view lowhigh >> ${tt}.out
xpaget DS9Test view units >> ${tt}.out
xpaget DS9Test view wcs >> ${tt}.out
xpaget DS9Test view detector >> ${tt}.out
xpaget DS9Test view amplifier >> ${tt}.out
xpaget DS9Test view physical >> ${tt}.out
xpaget DS9Test view image >> ${tt}.out
xpaget DS9Test view frame >> ${tt}.out

xpaget DS9Test view red >> ${tt}.out
xpaget DS9Test view green >> ${tt}.out
xpaget DS9Test view blue >> ${tt}.out

xpaget DS9Test view rgb red >> ${tt}.out
xpaget DS9Test view rgb green >> ${tt}.out
xpaget DS9Test view rgb blue >> ${tt}.out

xpaget DS9Test view hls hue >> ${tt}.out
xpaget DS9Test view hls lightness >> ${tt}.out
xpaget DS9Test view hls saturation >> ${tt}.out

xpaget DS9Test view hsv hue >> ${tt}.out
xpaget DS9Test view hsv saturation >> ${tt}.out
xpaget DS9Test view hsv value >> ${tt}.out

xpaset -p DS9Test tile
xpaset -p DS9Test frame new
xpaset -p DS9Test file fits/img.fits
xpaset -p DS9Test view multi no
sleep $delay
xpaset -p DS9Test view multi yes
sleep $delay
xpaset -p DS9Test colorbar orientation vertical
sleep $delay
xpaset -p DS9Test colorbar orientation horizontal
xpaset -p DS9Test frame delete
xpaset -p DS9Test single

xpaset -p DS9Test view layout vertical
sleep $delay
xpaset -p DS9Test view layout basic
sleep $delay
xpaset -p DS9Test view layout advanced
sleep $delay
xpaset -p DS9Test view layout horizontal
sleep $delay

xpaset -p DS9Test view keyvalue BITPIX

xpaset -p DS9Test view info no
xpaset -p DS9Test view info yes
xpaset -p DS9Test view panner no
xpaset -p DS9Test view panner yes
xpaset -p DS9Test view magnifier no
xpaset -p DS9Test view magnifier yes
xpaset -p DS9Test view buttons no
xpaset -p DS9Test view buttons yes
xpaset -p DS9Test view icons no
xpaset -p DS9Test view icons yes
xpaset -p DS9Test view colorbar no
xpaset -p DS9Test view colorbar yes
xpaset -p DS9Test view graph horizontal yes
xpaset -p DS9Test view graph horizontal no
xpaset -p DS9Test view graph vertical yes
xpaset -p DS9Test view graph vertical no
xpaset -p DS9Test view filename no
xpaset -p DS9Test view filename yes
xpaset -p DS9Test view object no
xpaset -p DS9Test view object yes
xpaset -p DS9Test view keyword yes
xpaset -p DS9Test view keyword no
xpaset -p DS9Test view minmax yes
xpaset -p DS9Test view minmax no
xpaset -p DS9Test view lowhigh yes
xpaset -p DS9Test view lowhigh no
xpaset -p DS9Test view units yes
xpaset -p DS9Test view units no
xpaset -p DS9Test view wcs no
xpaset -p DS9Test view wcs yes
xpaset -p DS9Test view wcsa yes
xpaset -p DS9Test view wcsa no
xpaset -p DS9Test view detector yes
xpaset -p DS9Test view detector no
xpaset -p DS9Test view amplifier yes
xpaset -p DS9Test view amplifier no
xpaset -p DS9Test view physical no
xpaset -p DS9Test view physical yes
xpaset -p DS9Test view image no
xpaset -p DS9Test view image yes
xpaset -p DS9Test view frame no
xpaset -p DS9Test view frame yes
sleep $delay

xpaset -p DS9Test frame new rgb
xpaset -p DS9Test view rgb red no
xpaset -p DS9Test view rgb red yes
xpaset -p DS9Test view rgb green no
xpaset -p DS9Test view rgb green yes
xpaset -p DS9Test view rgb blue no
xpaset -p DS9Test view rgb blue yes
xpaset -p DS9Test frame delete
sleep $delay

xpaset -p DS9Test frame new hls
xpaset -p DS9Test view hls hue no
xpaset -p DS9Test view hls hue yes
xpaset -p DS9Test view hls lightness no
xpaset -p DS9Test view hls lightness yes
xpaset -p DS9Test view hls saturation no
xpaset -p DS9Test view hls saturation yes
xpaset -p DS9Test frame delete
sleep $delay

xpaset -p DS9Test frame new hsv
xpaset -p DS9Test view hsv hue no
xpaset -p DS9Test view hsv hue yes
xpaset -p DS9Test view hsv saturation no
xpaset -p DS9Test view hsv saturation yes
xpaset -p DS9Test view hsv value no
xpaset -p DS9Test view hsv value yes
xpaset -p DS9Test frame delete
sleep $delay

xpaset -p DS9Test rgb close
xpaset -p DS9Test hls close
xpaset -p DS9Test hsv close
testit $tt
fi

tt="vla"
if [ "$1" = "$tt" ]; then
echo -n "$tt..."
xpaset -p DS9Test vla open
xpaset -p DS9Test vla close
xpaset -p DS9Test vla size 30 30 arcsec
xpaget DS9Test vla size >> ${tt}.out
xpaset -p DS9Test vla save no
xpaget DS9Test vla save >> ${tt}.out
xpaset -p DS9Test vla frame new
xpaget DS9Test vla frame >> ${tt}.out
xpaset -p DS9Test vla survey first
xpaget DS9Test vla survey >> ${tt}.out
xpaset -p DS9Test vla update frame
xpaset -p DS9Test vla m51
xpaset -p DS9Test vla name m51
xpaget DS9Test vla name >> ${tt}.out
xpaset -p DS9Test vla name clear
xpaset -p DS9Test vla 13:29:52.37 +47:11:40.8
# backward compatibility
xpaset -p DS9Test vla coord 13:29:52.37 +47:11:40.8 sexagesimal
xpaget DS9Test vla coord >> ${tt}.out
xpaset -p DS9Test vla update frame
xpaset -p DS9Test mode crosshair
xpaset -p DS9Test vla update crosshair
xpaset -p DS9Test vla close
xpaset -p DS9Test mode none
xpaset -p DS9Test frame delete
xpaset -p DS9Test frame delete
xpaset -p DS9Test frame delete
xpaset -p DS9Test frame delete
xpaset -p DS9Test frame delete
xpaset -p DS9Test frame delete
xpaset -p DS9Test frame delete

testit $tt
fi

tt="vlss"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaset -p DS9Test vlss open
xpaset -p DS9Test vlss close
xpaset -p DS9Test vlss size 30 30 arcsec
xpaget DS9Test vlss size >> ${tt}.out
xpaset -p DS9Test vlss save no
xpaget DS9Test vlss save >> ${tt}.out
xpaset -p DS9Test vlss frame new
xpaget DS9Test vlss frame >> ${tt}.out
xpaset -p DS9Test vlss update frame
xpaset -p DS9Test vlss m51
xpaset -p DS9Test vlss name m51
xpaget DS9Test vlss name >> ${tt}.out
xpaset -p DS9Test vlss name clear
xpaset -p DS9Test vlss 13:29:52.37 +47:11:40.8
# backward compatibility
xpaset -p DS9Test vlss coord 13:29:52.37 +47:11:40.8 sexagesimal
xpaget DS9Test vlss coord >> ${tt}.out
xpaset -p DS9Test vlss update frame
xpaset -p DS9Test mode crosshair
xpaset -p DS9Test vlss update crosshair
xpaset -p DS9Test vlss close
xpaset -p DS9Test mode none
xpaset -p DS9Test frame delete
xpaset -p DS9Test frame delete
xpaset -p DS9Test frame delete
xpaset -p DS9Test frame delete
xpaset -p DS9Test frame delete
xpaset -p DS9Test frame delete
xpaset -p DS9Test frame delete

testit $tt
fi

tt="vo"
if [ "$1" = "$tt" ]; then
echo -n "$tt..."
xpaget DS9Test vo method >> ${tt}.out
xpaget DS9Test vo server >> ${tt}.out
xpaget DS9Test vo internal >> ${tt}.out
xpaget DS9Test vo delay >> ${tt}.out
xpaget DS9Test vo connect >> ${tt}.out
xpaget DS9Test vo >> /dev/null
xpaset -p DS9Test vo open
xpaset -p DS9Test vo method mime
xpaset -p DS9Test vo server "http://cxc.harvard.edu/chandraed/list.txt"
xpaset -p DS9Test vo internal yes
xpaset -p DS9Test vo delay 15
xpaset -p DS9Test vo connect foo
xpaset -p DS9Test vo xray1.physics.rutgers
xpaset -p DS9Test vo disconnect xray1.physics.rutgers
xpaset -p DS9Test vo close
xpaset -p DS9Test web close

testit $tt
fi

tt="wcs"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaget DS9Test wcs >> ${tt}.out
xpaget DS9Test wcs system >> ${tt}.out
xpaget DS9Test wcs sky >> ${tt}.out
xpaget DS9Test wcs skyformat >> ${tt}.out
xpaget DS9Test wcs align >> ${tt}.out
xpaset -p DS9Test wcs open
xpaset -p DS9Test wcs wcs
xpaset -p DS9Test wcs align yes
xpaset -p DS9Test wcs system wcs
xpaset -p DS9Test wcs sky galactic
xpaset -p DS9Test wcs skyformat sexagesimal
xpaset -p DS9Test wcs align no
xpaset -p DS9Test wcs sky fk5
xpaset -p DS9Test wcs skyformat degrees
xpaset -p DS9Test wcs load aux/image.wcs
xpaset -p DS9Test wcs save foo.wcs
xpaset -p DS9Test wcs save 1 foo.wcs
cat aux/image.wcs | xpaset DS9Test wcs append
cat aux/image.wcs | xpaset DS9Test wcs replace
xpaset -p DS9Test wcs append aux/image.wcs
xpaset -p DS9Test wcs replace aux/image.wcs
xpaset -p DS9Test wcs reset
xpaset -p DS9Test wcs skyformat sexagesimal
xpaset -p DS9Test wcs close

testit $tt
fi

tt="web"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaset -p DS9Test web ds9.si.edu/doc/acknowledgment.html
sleep $delay
xpaget DS9Test web >> ${tt}.out
xpaset -p DS9Test web new foobar ds9.si.edu/doc/helpdesk.html
sleep $delay
xpaset -p DS9Test web hvweb click back
sleep $delay
xpaset -p DS9Test web click forward
xpaset -p DS9Test web clear
xpaset -p DS9Test web close
xpaset -p DS9Test web close

testit $tt
fi

tt="width"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaget DS9Test width >> /dev/null
xpaset -p DS9Test width 600


testit $tt
fi

sleep 2

tt="xpa"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaget DS9Test xpa >> /dev/null
xpaget DS9Test xpa info >> /dev/null
#xpaset -p DS9Test xpa connect
#xpaset -p DS9Test xpa disconnect
xpaset -p DS9Test xpa info

testit $tt
fi

tt="zscale"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaget DS9Test zscale contrast >> ${tt}.out
xpaget DS9Test zscale sample >> ${tt}.out
xpaget DS9Test zscale line >> ${tt}.out
xpaset -p DS9Test zscale contrast .25
xpaset -p DS9Test zscale sample 600
xpaset -p DS9Test zscale line 120

testit $tt
fi

tt="zoom"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaset -p DS9Test zoom open
xpaset -p DS9Test zoom 2
xpaset -p DS9Test zoom 2 4
xpaset -p DS9Test zoom to 4
xpaset -p DS9Test zoom to 2 4
xpaset -p DS9Test zoom in
xpaset -p DS9Test zoom out
xpaset -p DS9Test zoom to fit
xpaset -p DS9Test zoom close
xpaget DS9Test zoom > /dev/null
xpaset -p DS9Test frame reset

testit $tt
fi

# do this last
tt="backup"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt..."
xpaset -p DS9Test backup foo.bck
xpaset -p DS9Test restore foo.bck

testit $tt
fi

tt="exit"
if [ "$1" = "$tt" -o -z "$1" ]; then
echo -n "$tt/quit..."
xpaset -p DS9Test quit
fi

rm -rf foo.*
echo "DONE"
