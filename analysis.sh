echo
echo "*** analysis.sh ***"

echo "Starting DS9..."
if [ `xpaaccess DS9Test` = no ]
then
    ds9 -title DS9Test &
fi

i=1
while [ "$i" -le 30 ]
do
    sleep 2
    if [ `xpaaccess DS9Test` = yes ]
    then
	break
    fi

    i=`expr $i + 1`
done

# load default
xpaset -p DS9Test scale zscale
xpaset -p DS9Test fits fits/img.fits
xpaset -p DS9Test regions file analysis/analysis.reg
xpaset -p DS9Test analysis clear
xpaset -p DS9Test analysis load analysis/analysis.ans

# Main
if [ "$1" = "help" -o  -z "$1" ]; then
echo "Help"
xpaset -p DS9Test analysis 0
fi

# Web
if [ "$1" = "web" -o  -z "$1" ]; then
echo "Web"
xpaset -p DS9Test analysis 1

echo "..web url"
xpaset -p DS9Test analysis 2

echo "..web file"
xpaset -p DS9Test analysis 3
fi

# Basics
if [ "$1" = "basics" -o  -z "$1" ]; then
echo "Basic"
xpaset -p DS9Test analysis 4

echo "..escape macro"
xpaset -p DS9Test analysis 5

echo "..non macro"
xpaset -p DS9Test analysis 6

echo "..\$xpa"
xpaset -p DS9Test analysis 7

echo "..\$xpa_method"
xpaset -p DS9Test analysis 8

echo "..\$vo_method"
xpaset -p DS9Test analysis 9

echo "..\$filename"
xpaset -p DS9Test analysis 10

echo "..\$filename(root)"
xpaset -p DS9Test analysis 11

echo "..\$filename(full)"
xpaset -p DS9Test analysis 12

echo "..\$filedialog(open)"
xpaset -p DS9Test analysis 13

echo "..\$filename(save)"
xpaset -p DS9Test analysis 14

echo "..\$width \$height \$depth \$bitpix"
xpaset -p DS9Test analysis 15

echo "..\$pan"
xpaset -p DS9Test analysis 16

echo "..\$env \$dir"
xpaset -p DS9Test analysis 17
fi

# Regions
if [ "$1" = "regions" -o  -z "$1" ]; then
echo "Regions"
xpaset -p DS9Test analysis 18

echo "..\$regions"
xpaset -p DS9Test analysis 19

echo "..\$regions wcs"
xpaset -p DS9Test analysis 20

echo "..\$jnclude_regions_pixels"
xpaset -p DS9Test analysis 21

echo "..\$filename $regions"
xpaset -p DS9Test analysis 22

echo "..\$regions()"
xpaset -p DS9Test analysis 23
fi

# Output
if [ "$1" = "output" -o  -z "$1" ]; then
echo "Output"
xpaset -p DS9Test analysis 24

echo "..\$null"
xpaset -p DS9Test analysis 25

echo "..\$text"
xpaset -p DS9Test analysis 26

echo "..\$plot"
xpaset -p DS9Test analysis 27

echo "..\$plot(title,x,y,xyey)"
xpaset -p DS9Test analysis 28

echo "..\$plot(title,x,y,xyexey)"
xpaset -p DS9Test analysis 29

echo "..\$plot(title,x,y,4)"
xpaset -p DS9Test analysis 30

echo "..\$plot(title,x,y,5)"
xpaset -p DS9Test analysis 31

echo "..\$plot(stdin)"
xpaset -p DS9Test analysis 32

echo "..\$plot(stdin) text"
xpaset -p DS9Test analysis 33

echo "..\$plot(stdin) error"
xpaset -p DS9Test analysis 34

echo "..\$data"
xpaset -p DS9Test analysis 35

echo "..\$jmage"
xpaset -p DS9Test analysis 36

echo "..\$jmage(3d)"
xpaset -p DS9Test analysis 37
fi

# Dialogs
if [ "$1" = "dialogs" -o  -z "$1" ]; then
echo "Dialog"
xpaset -p DS9Test analysis 38

echo "..\$message(message)"
xpaset -p DS9Test analysis 39

echo "..\$message(okcancel,message)"
xpaset -p DS9Test analysis 40

echo "..\$messageok(message)"
xpaset -p DS9Test analysis 41

echo "..\$messageok(okcancel,message)"
xpaset -p DS9Test analysis 42

echo "..\$entry(message)"
xpaset -p DS9Test analysis 43
fi

# Params
if [ "$1" = "params" -o  -z "$1" ]; then
echo "Param"
xpaset -p DS9Test analysis 44

echo "..\$param"
xpaset -p DS9Test analysis 45

echo "..\$param tab"
xpaset -p DS9Test analysis 46

echo "..\$param macro"
xpaset -p DS9Test analysis 47

echo "..\$param @file"
xpaset -p DS9Test analysis 48
fi

# Network
if [ "$1" = "network" -o  -z "$1" ]; then
echo "Network"
xpaset -p DS9Test analysis 49

echo "..\$url(http://)"
xpaset -p DS9Test analysis 50
fi

echo "PASSED"

# Other
if [ "$1" = "other" -o  -z "$1" ]; then
xpaset -p DS9Test analysis message {press 'x','y','z' to test interactive}
fi

echo "Done"
