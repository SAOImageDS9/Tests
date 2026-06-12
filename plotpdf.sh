echo "PDF Plot Tests"

title=DS9Test


echo "Starting DS9..."
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

    xpaset -p ${title} single
    xpaset -p ${title} raise
}

num_out=1
/bin/rm -rf pdf_out
mkdir pdf_out

close() {
   printf ""
   zero_pad=`printf "%03d" $num_out`
   xpaset -p ${title} plot export pdf pdf_out/${zero_pad}.pdf
   num_out=$((num_out+1))
   xpaset -p ${title} plot close
}




echo
echo "*** plotpdf.sh ***"

delay=.5


# slow down?
slow=0
if [ "$1" = "slow" ]; then
    slow=1
    shift
fi




rm -f *.out
xpaset -p ${title} scale zscale
xpaset -p ${title} fits fits/img.fits


echo -n " gui..."
xpaset -p ${title} plot line
xpaset -p ${title} plot gui
sleep $delay
close
echo "PASSED"

echo -n " empty plot..."
xpaset -p ${title} plot line
xpaset -p ${title} plot line foo
xpaget ${title} plot >> ${tt}.out
sleep $delay
close
close
echo "PASSED"

echo -n " file name dim..."
xpaset -p ${title} plot line plot/xy.dat xy
xpaset -p ${title} plot line plot/xy.dat foo xy
xpaset -p ${title} plot theme no
sleep $delay
close
close
echo "PASSED"

echo -n " file name title xaxis yaxis dim..."
xpaset -p ${title} plot line plot/xy.dat {The Title} {X Axis} {Y Axis} xy
xpaset -p ${title} plot line plot/xy.dat foo {The Title} {X Axis} {Y Axis} xy
xpaset -p ${title} plot theme no
sleep $delay
close
close
echo "PASSED"

echo -n " stdin..."
cat plot/xy.dat | xpaset ${title} plot line {The Title} {X Axis} {Y Axis} xy
cat plot/xy.dat | xpaset ${title} plot line foo {The Title} {X Axis} {Y Axis} xy
xpaset -p ${title} plot theme no
sleep $delay
close
close
echo "PASSED"

echo -n " stdin with header..."
cat plot/stdin.2.dat | xpaset ${title} plot line stdin
cat plot/stdin.2.dat | xpaset ${title} plot line foo stdin
xpaset -p ${title} plot theme no
sleep $delay
close
close
echo "PASSED"

echo -n " data..."
xpaset -p ${title} plot line
cat plot/xy.dat | xpaset ${title} plot data xy
xpaset -p ${title} plot theme no
sleep $delay
close
echo "PASSED"

echo -n " save/load..."
xpaset -p ${title} plot line plot/xy.dat xy
xpaset -p ${title} plot save foo.dat
xpaset -p ${title} plot theme no
sleep $delay
close
echo "PASSED"

echo -n " add/delete graph..."
xpaset -p ${title} plot line
xpaset -p ${title} plot add graph line
xpaset -p ${title} plot theme no
sleep $delay
xpaset -p ${title} plot delete graph
close
echo "PASSED"

echo -n " add/delete dataset..."
xpaset -p ${title} plot line plot/xy.dat xy
xpaset -p ${title} plot theme no
sleep $delay
xpaset -p ${title} plot delete dataset
close
echo "PASSED"

echo -n " layout..."
xpaset -p ${title} plot line
xpaset -p ${title} plot add graph line
xpaset -p ${title} plot add graph bar
# backward compatibility
xpaset -p ${title} plot add graph scatter
xpaget ${title} plot layout >> /dev/null
xpaget ${title} plot layout strip scale >> /dev/null
xpaset -p ${title} plot theme no
sleep $delay
xpaset -p ${title} plot layout row
xpaset -p ${title} plot layout column
xpaset -p ${title} plot layout strip
xpaset -p ${title} plot layout strip scale 30
xpaset -p ${title} plot layout grid
close
echo "PASSED"

echo -n " duplicate..."
xpaset -p ${title} plot line plot/xy.dat xy
xpaset -p ${title} plot duplicate
xpaset -p ${title} plot theme no
sleep $delay
close
echo "PASSED"

echo -n " stats..."
xpaset -p ${title} plot line plot/xy.dat xy
xpaget ${title} plot stats >> /dev/null
xpaset -p ${title} plot stats yes
xpaset -p ${title} plot theme no
sleep $delay
close
echo "PASSED"

echo -n " list..."
xpaset -p ${title} plot line plot/xy.dat xy
xpaget ${title} plot list >> /dev/null
xpaset -p ${title} plot list yes
xpaset -p ${title} plot theme no
sleep $delay
close
echo "PASSED"

echo -n " backup/restore..."
xpaset -p ${title} plot line plot/xy.dat xy
xpaset -p ${title} plot theme no
xpaset -p ${title} plot backup foo.plb
xpaset -p ${title} plot restore foo.plb
close
xpaset -p ${title} plot restore foo.plb
sleep $delay
close
echo "PASSED"

echo -n " pagesetup..."
xpaset -p ${title} plot line plot/xy.dat xy
xpaset -p ${title} plot pagesetup orient portrait
xpaset -p ${title} plot pagesetup size letter
xpaset -p ${title} plot theme no
sleep $delay
close
echo "PASSED"

echo -n " print..."
xpaset -p ${title} plot line plot/xy.dat xy
#xpaset -p ${title} plot print
xpaset -p ${title} plot print destination printer
xpaset -p ${title} plot print command "lp"
xpaset -p ${title} plot print filename "foo.ps"
xpaset -p ${title} plot print color rgb
xpaset -p ${title} plot theme no
sleep $delay
close
echo "PASSED"

echo -n " mode..."
xpaset -p ${title} plot line plot/xy.dat xy
xpaget ${title} plot mode >> ${tt}.out
xpaset -p ${title} plot mode pointer
xpaset -p ${title} plot theme no
sleep $delay
close
echo "PASSED"


echo -n " axis..."
xpaset -p ${title} plot line plot/xy.dat xy
xpaset -p ${title} plot axis x grid no
xpaset -p ${title} plot axis x grid yes
xpaset -p ${title} plot axis x log yes
xpaset -p ${title} plot axis x log no
xpaset -p ${title} plot axis x flip yes
xpaset -p ${title} plot axis x flip no
xpaset -p ${title} plot axis x auto no
xpaset -p ${title} plot axis x min 1
xpaset -p ${title} plot axis x max 100
xpaset -p ${title} plot axis x format "%f"
xpaset -p ${title} plot axis y grid no
xpaset -p ${title} plot axis y grid yes
xpaset -p ${title} plot axis y log yes
xpaset -p ${title} plot axis y log no
xpaset -p ${title} plot axis y flip yes
xpaset -p ${title} plot axis y flip no
xpaset -p ${title} plot axis y auto no
xpaset -p ${title} plot axis y min 1
xpaset -p ${title} plot axis y max 100
xpaset -p ${title} plot axis y format "%f"
xpaget ${title} plot axis x grid >> ${tt}.out
xpaget ${title} plot axis x log >> ${tt}.out
xpaget ${title} plot axis x flip >> ${tt}.out
xpaget ${title} plot axis x auto >> ${tt}.out
xpaget ${title} plot axis x min >> ${tt}.out
xpaget ${title} plot axis x max >> ${tt}.out
xpaget ${title} plot axis x format >> ${tt}.out
xpaget ${title} plot axis y grid >> ${tt}.out
xpaget ${title} plot axis y log >> ${tt}.out
xpaget ${title} plot axis y flip >> ${tt}.out
xpaget ${title} plot axis y auto >> ${tt}.out
xpaget ${title} plot axis y min >> ${tt}.out
xpaget ${title} plot axis y max >> ${tt}.out
xpaget ${title} plot axis y format >> ${tt}.out
xpaset -p ${title} plot theme no
sleep $delay
close
echo "PASSED"

echo -n " foreground/background/grid color..."
xpaset -p ${title} plot line plot/xy.dat xy
xpaget ${title} plot foreground >> ${tt}.out
xpaget ${title} plot background >> ${tt}.out
xpaget ${title} plot grid color >> ${tt}.out
xpaset -p ${title} plot foreground black
xpaset -p ${title} plot background red
xpaset -p ${title} plot grid color blue
xpaset -p ${title} plot theme no
sleep $delay
close
echo "PASSED"

echo -n " legend..."
xpaset -p ${title} plot line plot/xy.dat xy
xpaget ${title} plot legend >> ${tt}.out
xpaget ${title} plot legend position >> ${tt}.out
xpaset -p ${title} plot legend yes
xpaset -p ${title} plot legend position left
xpaset -p ${title} plot legend position right
xpaset -p ${title} plot legend position bottom
xpaset -p ${title} plot legend position top
xpaset -p ${title} plot theme no
sleep $delay
close
echo "PASSED"

echo -n " font..."
xpaset -p ${title} plot line plot/xy.dat xy
xpaset -p ${title} plot title {This is a Title}
xpaset -p ${title} plot title xaxis {X Axis}
xpaset -p ${title} plot title yaxis {Y Axis}
xpaset -p ${title} plot title legend {This is the Legend}
xpaset -p ${title} plot legend yes
xpaget ${title} plot font title font >> ${tt}.out
xpaget ${title} plot font title size >> ${tt}.out
xpaget ${title} plot font title weight >> ${tt}.out
xpaget ${title} plot font title slant >> ${tt}.out
# backward compatibility
xpaget ${title} plot font title style >> ${tt}.out
xpaget ${title} plot font labels font >> ${tt}.out
xpaget ${title} plot font labels size >> ${tt}.out
xpaget ${title} plot font labels weight >> ${tt}.out
xpaget ${title} plot font labels slant >> ${tt}.out
# backward compatibility
xpaget ${title} plot font labels style >> ${tt}.out
xpaget ${title} plot font numbers font >> ${tt}.out
xpaget ${title} plot font numbers size >> ${tt}.out
xpaget ${title} plot font numbers weight >> ${tt}.out
xpaget ${title} plot font numbers slant >> ${tt}.out
# backward compatibility
xpaget ${title} plot font numbers style >> ${tt}.out
xpaget ${title} plot font legend title font >> ${tt}.out
xpaget ${title} plot font legend title size >> ${tt}.out
xpaget ${title} plot font legend title weight >> ${tt}.out
xpaget ${title} plot font legend title slant >> ${tt}.out
# backward compatibility
xpaget ${title} plot font legend title style >> ${tt}.out
xpaget ${title} plot font legend font >> ${tt}.out
xpaget ${title} plot font legend size >> ${tt}.out
xpaget ${title} plot font legend weight >> ${tt}.out
xpaget ${title} plot font legend slant >> ${tt}.out
# backward compatibility
xpaget ${title} plot font legend style >> ${tt}.out
xpaset -p ${title} plot font title font times
xpaset -p ${title} plot font title size 12
xpaset -p ${title} plot font title weight bold
xpaset -p ${title} plot font title slant roman
# backward compatibility
xpaset -p ${title} plot font title style normal
xpaset -p ${title} plot font labels font times
xpaset -p ${title} plot font labels size 12
xpaset -p ${title} plot font labels weight bold
xpaset -p ${title} plot font labels slant roman
# backward compatibility
xpaset -p ${title} plot font labels style normal
xpaset -p ${title} plot font numbers font times
xpaset -p ${title} plot font numbers size 12
xpaset -p ${title} plot font numbers weight bold
xpaset -p ${title} plot font numbers slant roman
# backward compatibility
xpaset -p ${title} plot font numbers style normal
xpaset -p ${title} plot font legend title font times
xpaset -p ${title} plot font legend title size 12
xpaset -p ${title} plot font legend title weight bold
xpaset -p ${title} plot font legend title slant roman
# backward compatibility
xpaset -p ${title} plot font legend title style normal
xpaset -p ${title} plot font legend font times
xpaset -p ${title} plot font legend size 12
xpaset -p ${title} plot font legend weight bold
xpaset -p ${title} plot font legend slant roman
# backward compatibility
xpaset -p ${title} plot font legend style normal
xpaset -p ${title} plot theme no
sleep $delay
close
echo "PASSED"

echo -n " title..."
xpaset -p ${title} plot line plot/xy.dat xy
xpaset -p ${title} plot title {This is a Title}
xpaset -p ${title} plot title x {X Axis}
xpaset -p ${title} plot title y {Y Axis}
xpaset -p ${title} plot title legend {This is the Legend}
xpaget ${title} plot title >> ${tt}.out
xpaget ${title} plot title x >> ${tt}.out
xpaget ${title} plot title y >> ${tt}.out
xpaget ${title} plot title legend >> ${tt}.out
xpaset -p ${title} plot theme no
sleep $delay
close
echo "PASSED"

echo -n " dataset..."
xpaset -p ${title} plot line plot/xy.dat xy
xpaget ${title} plot show >> ${tt}.out
xpaget ${title} plot name >> ${tt}.out
xpaset -p ${title} plot show no
xpaset -p ${title} plot show yes
xpaset -p ${title} plot legend yes
xpaset -p ${title} plot name {This is a test}
xpaset -p ${title} plot theme no
sleep $delay
close
echo "PASSED"

echo -n " line dataset..."
xpaset -p ${title} plot line plot/xy.dat xy
xpaget ${title} plot line smooth >> ${tt}.out
xpaget ${title} plot line color >> ${tt}.out
xpaget ${title} plot line width >> ${tt}.out
xpaget ${title} plot line dash >> ${tt}.out
xpaget ${title} plot line fill >> ${tt}.out
xpaget ${title} plot line fill color >> ${tt}.out
xpaget ${title} plot line shape symbol >> ${tt}.out
xpaget ${title} plot line shape size >> ${tt}.out
xpaget ${title} plot line shape color >> ${tt}.out
xpaget ${title} plot line shape fill >> ${tt}.out

xpaset -p ${title} plot line smooth linear
xpaset -p ${title} plot line smooth cubic
xpaset -p ${title} plot line smooth quadratic
xpaset -p ${title} plot line smooth catrom
xpaset -p ${title} plot line color magenta
xpaset -p ${title} plot line color "#2C8"
xpaset -p ${title} plot line width 2
xpaset -p ${title} plot line dash yes
xpaset -p ${title} plot line fill yes
xpaset -p ${title} plot line fill color green
xpaset -p ${title} plot line shape symbol none
xpaset -p ${title} plot line shape symbol square
xpaset -p ${title} plot line shape symbol diamond
xpaset -p ${title} plot line shape symbol plus
xpaset -p ${title} plot line shape symbol splus
xpaset -p ${title} plot line shape symbol scross
xpaset -p ${title} plot line shape symbol triangle
xpaset -p ${title} plot line shape symbol arrow
xpaset -p ${title} plot line shape symbol circle
xpaset -p ${title} plot line shape size 5
xpaset -p ${title} plot line shape color cyan
xpaset -p ${title} plot line shape fill yes

xpaset -p ${title} plot theme no
sleep $delay
close
echo "PASSED"

echo -n " bar dataset..."
xpaset -p ${title} plot bar plot/xy.dat xy
xpaget ${title} plot bar border color >> ${tt}.out
xpaget ${title} plot bar border width >> ${tt}.out
xpaget ${title} plot bar fill >> ${tt}.out
xpaget ${title} plot bar color >> ${tt}.out
xpaget ${title} plot bar width >> ${tt}.out

xpaset -p ${title} plot bar border color magenta
xpaset -p ${title} plot bar border width 1
xpaset -p ${title} plot bar fill yes
xpaset -p ${title} plot bar color black
xpaset -p ${title} plot bar width 1

xpaset -p ${title} plot theme no
sleep $delay
close
echo "PASSED"

# backward compatibility
echo -n " scatter dataset..."
xpaset -p ${title} plot scatter plot/xy.dat xy
xpaget ${title} plot scatter symbol >> ${tt}.out
xpaget ${title} plot scatter size >> ${tt}.out
xpaget ${title} plot scatter color >> ${tt}.out
xpaget ${title} plot scatter fill >> ${tt}.out

xpaset -p ${title} plot scatter symbol square
xpaset -p ${title} plot scatter symbol diamond
xpaset -p ${title} plot scatter symbol plus
xpaset -p ${title} plot scatter symbol splus
xpaset -p ${title} plot scatter symbol scross
xpaset -p ${title} plot scatter symbol triangle
xpaset -p ${title} plot scatter symbol arrow
xpaset -p ${title} plot scatter symbol circle
xpaset -p ${title} plot scatter size 5
xpaset -p ${title} plot scatter color cyan
xpaset -p ${title} plot scatter fill yes

xpaset -p ${title} plot theme no
sleep $delay
close
echo "PASSED"

echo -n " error dataset..."
xpaset -p ${title} plot line plot/xyexey.dat xyexey
xpaget ${title} plot error >> ${tt}.out
xpaget ${title} plot error cap >> ${tt}.out
xpaget ${title} plot error color >> ${tt}.out
xpaget ${title} plot error width >> ${tt}.out
xpaset -p ${title} plot error no
xpaset -p ${title} plot error yes
xpaset -p ${title} plot error cap yes
xpaset -p ${title} plot error cap no
xpaset -p ${title} plot error color blue
xpaset -p ${title} plot error width 2
xpaset -p ${title} plot theme no
sleep $delay
close
echo "PASSED"

echo -n " current..."
#   will fail if not first time thru
xpaset -p ${title} plot line plot/xy.dat xy
xpaset -p ${title} plot line plot/xy.dat xy
xpaset -p ${title} plot load plot/xyey.dat xyey
xpaget ${title} plot current >> ${tt}.out
xpaget ${title} plot current graph >> ${tt}.out
xpaget ${title} plot current dataset >> ${tt}.out
xpaset -p ${title} plot current ap2
xpaset -p ${title} plot current graph 1
xpaset -p ${title} plot current dataset 1
xpaset -p ${title} plot theme no
sleep $delay
close
close
echo "PASSED"



xpaset -p DS9Test quit
echo "DONE"
