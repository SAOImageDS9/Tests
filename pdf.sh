printf "\nPDF Tests"

title=ZAPHOD

printf "\nStarting DS9..."
if [ `xpaaccess ${title}` = no ]; then
    ds9 -title ${title} -title ${title} -tcl&

    i=1
    while [ "$i" -le 10 ]
	do
	sleep 2
	if [ `xpaaccess ${title}` = yes ]; then
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
	    printf "\nPASSED"
	else
            printf "\nFAILED"
	    printf "\n$o"
	fi
    else
        printf "\nPASSED"
    fi

    if [ $slow = "1" ]; then
	sleep 1
    fi
    #rm -rf ${1}.out

    xpaset -p ${title} single
    xpaset -p ${title} raise
}

num_out=1
/bin/rm -rf pdf_out_img
mkdir pdf_out_img
snap_pdf() {
   printf "%d " $num_out
   zero_pad=`printf "%03d" $num_out`
   xpaset -p ${title} saveimage pdf pdf_out_img/${zero_pad}.pdf
   num_out=$((num_out+1))
}

echo
printf "\n*** pdf.sh ***\n"

delay=.5


# slow down?
slow=0
if [ "$1" = "slow" ]; then
    slow=1
    shift
fi

tt="Setup"
printf "\n$tt..."

rm -f *.out
xpaset -p ${title} scale zscale
xpaset -p ${title} fits fits/img.fits
snap_pdf


tt="background"
printf "\n$tt..."
xpaset -p ${title} background red
snap_pdf

tt="bin"
printf "\n$tt..."
xpaset -p ${title} fits new fits/table.fits
xpaset -p ${title} single
snap_pdf
xpaset -p ${title} frame delete


tt="catalog"
printf "\n$tt/cat..."
printf "\n default..."
xpaset -p ${title} catalog sao
snap_pdf
xpaset -p ${title} catalog clear
xpaset -p ${title} catalog close



tt="cmap"
printf "\n$tt..."
xpaset -p ${title} cmap tag load aux/ds9.tag
snap_pdf
xpaset -p ${title} cmap tag delete


tt="colorbar"
printf "\n$tt..."

xpaset -p ${title} colorbar no
snap_pdf
xpaset -p ${title} colorbar yes
snap_pdf
xpaset -p ${title} colorbar vertical
snap_pdf
xpaset -p ${title} colorbar horizontal
snap_pdf
xpaset -p ${title} colorbar numerics no
snap_pdf
xpaset -p ${title} colorbar numerics yes
snap_pdf
xpaset -p ${title} colorbar space value
snap_pdf
xpaset -p ${title} colorbar space distance
snap_pdf
xpaset -p ${title} colorbar font times
snap_pdf
xpaset -p ${title} colorbar fontsize 30
snap_pdf
xpaset -p ${title} colorbar fontweight bold
snap_pdf
xpaset -p ${title} colorbar fontslant italic
snap_pdf


xpaset -p ${title} colorbar size 30
snap_pdf
xpaset -p ${title} colorbar ticks 9
snap_pdf
xpaset -p ${title} colorbar width 0.5
snap_pdf
xpaset -p ${title} colorbar center 1
snap_pdf

xpaset -p ${title} colorbar font helvetica
snap_pdf
xpaset -p ${title} colorbar fontsize 10
snap_pdf
xpaset -p ${title} colorbar fontweight normal
snap_pdf
xpaset -p ${title} colorbar fontslant roman
snap_pdf
xpaset -p ${title} colorbar size 20
snap_pdf
xpaset -p ${title} colorbar ticks 11
snap_pdf
xpaset -p ${title} colorbar width 1
snap_pdf
xpaset -p ${title} colorbar center 0.5
snap_pdf


tt="contour"
printf "\n$tt/contours..."
xpaset -p ${title} contour yes
snap_pdf


xpaset -p ${title} contour clear
xpaset -p ${title} contour load aux/ds9.con wcs fk5 red 2 no
snap_pdf

xpaset -p ${title} contour clear
xpaset -p ${title} contour yes
xpaset -p ${title} contour color blue
snap_pdf

xpaset -p ${title} contour width 2
snap_pdf
xpaset -p ${title} contour smooth 5
snap_pdf
xpaset -p ${title} contour method block
snap_pdf
xpaset -p ${title} contour nlevels 10
snap_pdf
xpaset -p ${title} contour width 2
snap_pdf
xpaset -p ${title} contour clear
xpaset -p ${title} contour close




tt="crosshair"
printf "\n$tt..."
xpaset -p ${title} mode crosshair
xpaset -p ${title} crosshair 978 970
snap_pdf
xpaset -p ${title} mode none


tt="cube"
printf "\n$tt/datacube..."
xpaset -p ${title} cube open
xpaset -p ${title} cube close
xpaset -p ${title} fits new data/3d.fits
snap_pdf
xpaset -p ${title} frame delete
xpaset -p ${title} cube close


# backward compatibility
tt="file"
printf "\n$tt..."

printf "\n rgbimage..."
xpaset -p ${title} frame new rgb
xpaset -p ${title} file rgbimage rgb/rgbimage.fits
snap_pdf
xpaset -p ${title} frame delete

printf "\n hlsimage..."
xpaset -p ${title} frame new hls
xpaset -p ${title} file hlsimage hls/hlsimage.fits
snap_pdf
xpaset -p ${title} frame delete

printf "\n hsvimage..."
xpaset -p ${title} frame new hsv
xpaset -p ${title} file hsvimage hsv/hsvimage.fits
snap_pdf
xpaset -p ${title} frame delete

xpaset -p ${title} rgb close
xpaset -p ${title} hls close
xpaset -p ${title} hsv close


tt="footprint"
printf "\n$tt/fp..."
xpaset -p ${title} footprint cxc
snap_pdf
xpaset -p ${title} footprint clear
xpaset -p ${title} footprint close



tt="frame"
printf "\n$tt..."
xpaset -p ${title} fits new fits/img.fits
frm_no=`xpaget ${title} frame`
xpaset -p ${title} tile
snap_pdf
xpaset -p ${title} frame delete $frm_no


tt="graph"
printf "\n$tt..."

xpaset -p ${title} view graph horizontal yes
snap_pdf

xpaset -p ${title} view graph vertical yes
snap_pdf

xpaset -p ${title} view graph horizontal no
snap_pdf

xpaset -p ${title} view graph vertical no
xpaset -p ${title} view graph horizontal yes
xpaset -p ${title} graph grid yes
snap_pdf

xpaset -p ${title} graph grid no
snap_pdf

xpaset -p ${title} graph grid yes
xpaset -p ${title} graph log no
snap_pdf
xpaset -p ${title} graph log yes
snap_pdf

xpaset -p ${title} graph font helvetica
snap_pdf
xpaset -p ${title} graph fontsize 9
snap_pdf
xpaset -p ${title} graph fontweight normal
snap_pdf
xpaset -p ${title} graph fontslant roman
snap_pdf
xpaset -p ${title} graph size 150
snap_pdf
xpaset -p ${title} graph thickness 1
snap_pdf
xpaset -p ${title} view graph horizontal no



tt="grid"
printf "\n$tt..."
xpaset -p ${title} wcs wcs

xpaset -p ${title} grid yes
snap_pdf

xpaset -p ${title} grid type analysis
snap_pdf

xpaset -p ${title} grid grid yes
snap_pdf
xpaset -p ${title} grid grid color red
snap_pdf
xpaset -p ${title} grid grid width 2
snap_pdf
xpaset -p ${title} grid grid dash yes
snap_pdf

xpaset -p ${title} grid grid style 1
snap_pdf
xpaset -p ${title} grid grid gap1 .01
snap_pdf
xpaset -p ${title} grid grid gap2 .01
snap_pdf
xpaset -p ${title} grid grid gap3 .01
snap_pdf

xpaset -p ${title} grid axes yes
snap_pdf
xpaset -p ${title} grid axes color red
snap_pdf
xpaset -p ${title} grid axes width 2
snap_pdf
xpaset -p ${title} grid axes dash yes
snap_pdf
xpaset -p ${title} grid axes style 1
snap_pdf
xpaset -p ${title} grid axes type exterior
snap_pdf
xpaset -p ${title} grid axes origin lll
snap_pdf


xpaset -p ${title} grid tickmarks yes
snap_pdf
xpaset -p ${title} grid tickmarks color red
snap_pdf
xpaset -p ${title} grid tickmarks width 2
snap_pdf
xpaset -p ${title} grid tickmarks dash yes
snap_pdf

xpaset -p ${title} grid tickmarks style 1
snap_pdf

xpaset -p ${title} grid border yes
snap_pdf
xpaset -p ${title} grid border color red
snap_pdf
xpaset -p ${title} grid border width 2
snap_pdf
xpaset -p ${title} grid border dash yes
snap_pdf

xpaset -p ${title} grid numerics yes
snap_pdf
xpaset -p ${title} grid numerics font courier
snap_pdf
xpaset -p ${title} grid numerics fontsize 12
snap_pdf
xpaset -p ${title} grid numerics fontweight bold
snap_pdf
xpaset -p ${title} grid numerics fontslant roman
snap_pdf

xpaset -p ${title} grid numerics fontstyle italic
snap_pdf
xpaset -p ${title} grid numerics color red
snap_pdf
xpaset -p ${title} grid numerics gap1 10
snap_pdf
xpaset -p ${title} grid numerics gap2 10
snap_pdf
xpaset -p ${title} grid numerics gap3 10
snap_pdf
xpaset -p ${title} grid numerics type exterior
snap_pdf
xpaset -p ${title} grid numerics vertical yes
snap_pdf

xpaset -p ${title} grid title yes
snap_pdf
xpaset -p ${title} grid title text {Hello World}
snap_pdf
xpaset -p ${title} grid title def yes
snap_pdf
xpaset -p ${title} grid title gap 10
snap_pdf
xpaset -p ${title} grid title font courier
snap_pdf
xpaset -p ${title} grid title fontsize 12
snap_pdf
xpaset -p ${title} grid title fontweight bold
snap_pdf
xpaset -p ${title} grid title fontslant roman
snap_pdf

xpaset -p ${title} grid labels yes
snap_pdf
xpaset -p ${title} grid labels text1 {Hello World}
snap_pdf
xpaset -p ${title} grid labels def1 yes
snap_pdf
xpaset -p ${title} grid labels gap1 10
snap_pdf
xpaset -p ${title} grid labels text2 {Hello World}
snap_pdf
xpaset -p ${title} grid labels def2 yes
snap_pdf
xpaset -p ${title} grid labels gap2 10
snap_pdf
xpaset -p ${title} grid labels font courier
snap_pdf
xpaset -p ${title} grid labels fontsize 12
snap_pdf
xpaset -p ${title} grid labels fontweight bold
snap_pdf
xpaset -p ${title} grid labels fontslant roman
snap_pdf

xpaset -p ${title} grid reset
xpaset -p ${title} grid no
xpaset -p ${title} grid close


tt="height"
printf "\n$tt..."
xpaset -p ${title} height 443
snap_pdf


tt="illustrate"
printf "\n$tt..."

printf "\ncircle 100 100 40 # color = red fill = yes" | xpaset ${title} illustrate
printf "\nellipse 100 200 40 20" | xpaset ${title} illustrate
printf "\nbox 200 100 40 20" | xpaset ${title} illustrate
printf "\npolygon 200 200 200 250 250 250 250 200" | xpaset ${title} illustrate
printf "\nline 300 200 300 250 # dash = yes line = 0 1" | xpaset ${title} illustrate
printf "\ntext 117.0 339.0 "BANG!" # color = yellow font = times fontsize = 48 angle = 45.0" | xpaset ${title} illustrate
printf "\nimage 100 100 regions/chandra.png" | xpaset ${title} illustrate
snap_pdf

xpaset -p ${title} illustrate delete all
xpaset -p ${title} illustrate regions/ds9.seg
snap_pdf
xpaset -p ${title} illustrate delete all


tt="mask"
printf "\n$tt..."
xpaset -p ${title} mask open
xpaset -p ${title} mask color cyan
xpaset -p ${title} mask mark zero
xpaset -p ${title} mask range 10 100
xpaset -p ${title} mask transparency 25
xpaset -p ${title} mask blend source
xpaset -p ${title} mask blend screen
xpaset -p ${title} mask system physical
xpaset -p ${title} mask load fits/img.fits
sleep $delay
snap_pdf
xpaset -p ${title} mask clear
xpaset -p ${title} mask close
sleep $delay



tt="region"
printf "\n$tt/region..."
xpaset -p ${title} region delete
xpaset -p ${title} region system physical
xpaset -p ${title} region sky fk5
xpaset -p ${title} region skyformat degrees
printf "\nphysical;circle(957,1027,40) # tag=foo" | xpaset ${title} region
snap_pdf

printf "\nimage; circle 100 100 20" | xpaset ${title} region
printf "\nfk5; circle 13:29:55 47:11:50 .5'" | xpaset ${title} region
printf "\nphysical; ellipse 100 100 20 40" | xpaset ${title} region
printf "\nbox 100 100 20 40 25" | xpaset ${title} region
printf "\nimage; line 100 100 200 400" | xpaset ${title} region
printf "\nphysical; ruler 200 300 200 400" | xpaset ${title} region
printf "\nimage; text 100 100 # text={Hello, World}" | xpaset ${title} region
printf "\nfk4; boxcircle point 13:29:55 47:11:50" | xpaset ${title} region
snap_pdf
xpaset -p ${title} region delete

xpaset -p ${title} region regions/ds9.physical.reg
snap_pdf
xpaset -p ${title} region delete
xpaset -p ${title} region load regions/ds9.physical.reg
snap_pdf
xpaset -p ${title} region delete


tt="reveal"
printf "\n$tt..."
xpaset -p ${title} fits new fits/img.fits
xpaset -p ${title} cmap bb
xpaset -p ${title} reveal
snap_pdf

xpaset -p ${title} reveal split .25
snap_pdf

xpaset -p ${title} reveal split .75
snap_pdf

xpaset -p ${title} reveal bar no
snap_pdf

xpaset -p ${title} reveal bar yes
snap_pdf

xpaset -p ${title} single
xpaset -p ${title} frame delete


tt="tile"
printf "\n$tt..."
xpaset -p ${title} fits new fits/img.fits
xpaset -p ${title} fits new fits/img.fits
xpaset -p ${title} tile
xpaset -p ${title} tile yes
snap_pdf

xpaset -p ${title} tile row
snap_pdf

xpaset -p ${title} tile column
snap_pdf

xpaset -p ${title} tile grid
snap_pdf

xpaset -p ${title} tile grid mode automatic
snap_pdf

xpaset -p ${title} tile grid direction x
snap_pdf

xpaset -p ${title} frame delete
xpaset -p ${title} frame delete


tt="width"
printf "\n$tt..."
xpaset -p ${title} width 600
snap_pdf

tt="exit"
printf "\n$tt/quit..."
xpaset -p ${title} quit

printf "\nDONE\n"
