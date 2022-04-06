echo
echo "*** analysis.sh ***"

echo "Starting DS9..."
if [ `xpaaccess ds9` = no ]
then
    ds9&
fi

i=1
while [ "$i" -le 30 ]
do
    sleep 2
    if [ `xpaaccess ds9` = yes ]
    then
	break
    fi

    i=`expr $i + 1`
done

# load default
xpaset -p ds9 scale zscale
xpaset -p ds9 fits fits/img.fits
xpaset -p ds9 regions file analysis/analysis.reg
xpaset -p ds9 analysis clear
xpaset -p ds9 analysis load analysis/analysis.ans

# Main
if [ "$1" = "help" -o  -z "$1" ]; then
echo "Help"
xpaset -p ds9 analysis 0
fi

# Web
if [ "$1" = "web" -o  -z "$1" ]; then
echo "Web"
xpaset -p ds9 analysis 1

echo "..web url"
xpaset -p ds9 analysis 2

echo "..web file"
xpaset -p ds9 analysis 3
fi

# Basics
if [ "$1" = "basics" -o  -z "$1" ]; then
echo "Basic"
xpaset -p ds9 analysis 4

echo "..escape macro"
xpaset -p ds9 analysis 5

echo "..non macro"
xpaset -p ds9 analysis 6

echo "..\$xpa"
xpaset -p ds9 analysis 7

echo "..\$xpa_method"
xpaset -p ds9 analysis 8

echo "..\$vo_method"
xpaset -p ds9 analysis 9

echo "..\$filename"
xpaset -p ds9 analysis 10

echo "..\$filename(root)"
xpaset -p ds9 analysis 11

echo "..\$filename(full)"
xpaset -p ds9 analysis 12

echo "..\$filedialog(open)"
xpaset -p ds9 analysis 13

echo "..\$filename(save)"
xpaset -p ds9 analysis 14

echo "..\$width \$height \$depth \$bitpix"
xpaset -p ds9 analysis 15

echo "..\$pan"
xpaset -p ds9 analysis 16

echo "..\$env \$dir"
xpaset -p ds9 analysis 17
fi

# Regions
if [ "$1" = "regions" -o  -z "$1" ]; then
echo "Regions"
xpaset -p ds9 analysis 18

echo "..\$regions"
xpaset -p ds9 analysis 19

echo "..\$regions wcs"
xpaset -p ds9 analysis 20

echo "..\$jnclude_regions_pixels"
xpaset -p ds9 analysis 21

echo "..\$filename $regions"
xpaset -p ds9 analysis 22

echo "..\$regions()"
xpaset -p ds9 analysis 23
fi

# Output
if [ "$1" = "output" -o  -z "$1" ]; then
echo "Output"
xpaset -p ds9 analysis 24

echo "..\$null"
xpaset -p ds9 analysis 25

echo "..\$text"
xpaset -p ds9 analysis 26

echo "..\$plot"
xpaset -p ds9 analysis 27

echo "..\$plot(title,x,y,xyey)"
xpaset -p ds9 analysis 28

echo "..\$plot(title,x,y,xyexey)"
xpaset -p ds9 analysis 29

echo "..\$plot(title,x,y,4)"
xpaset -p ds9 analysis 30

echo "..\$plot(title,x,y,5)"
xpaset -p ds9 analysis 31

echo "..\$plot(stdin)"
xpaset -p ds9 analysis 32

echo "..\$plot(stdin) text"
xpaset -p ds9 analysis 33

echo "..\$plot(stdin) error"
xpaset -p ds9 analysis 34

echo "..\$data"
xpaset -p ds9 analysis 35

echo "..\$jmage"
xpaset -p ds9 analysis 36

echo "..\$jmage(3d)"
xpaset -p ds9 analysis 37
fi

# Dialogs
if [ "$1" = "dialogs" -o  -z "$1" ]; then
echo "Dialog"
xpaset -p ds9 analysis 38

echo "..\$message(message)"
xpaset -p ds9 analysis 39

echo "..\$message(okcancel,message)"
xpaset -p ds9 analysis 40

echo "..\$messageok(message)"
xpaset -p ds9 analysis 41

echo "..\$messageok(okcancel,message)"
xpaset -p ds9 analysis 42

echo "..\$entry(message)"
xpaset -p ds9 analysis 43
fi

# Params
if [ "$1" = "params" -o  -z "$1" ]; then
echo "Param"
xpaset -p ds9 analysis 44

echo "..\$param"
xpaset -p ds9 analysis 45

echo "..\$param tab"
xpaset -p ds9 analysis 46

echo "..\$param macro"
xpaset -p ds9 analysis 47

echo "..\$param @file"
xpaset -p ds9 analysis 48
fi

# Network
if [ "$1" = "network" -o  -z "$1" ]; then
echo "Network"
xpaset -p ds9 analysis 49

echo "..\$url(http://)"
xpaset -p ds9 analysis 50
fi

echo "PASSED"

# Other
if [ "$1" = "other" -o  -z "$1" ]; then
xpaset -p ds9 analysis message {press 'x','y','z' to test interactive}
fi

echo "Done"
