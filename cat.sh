echo "Catalog Line Options Tests"

testit () {
    echo "Testing $1"
    unset opt
    opt="$opt $1 -sleep 1"
}

doit () {
    eval ds9 -title DS9Test -zscale fits/img.fits "$opt" -exit
    echo "PASSED"
    echo ""
}

echo
echo "*** cat.sh ***"

tt="-cat 2mass -header"
testit "$tt"
doit

tt="-cat 2mass -cat sky fk4 -header"
testit "$tt"
doit

tt="-cat 2mass -cat iras -header"
testit "$tt"
doit

tt="-cat 2mass -cat sky fk4 -cat iras -header"
testit "$tt"
doit


# glyph symbols, with a local catalog (no network). Each run converts the
# catalog to regions and compares them with the expected file in aux/.
glyphit () {
    echo "Testing glyph $1"
    out=foo.glyph.reg
    exp=$1
    shift
    rm -f $out
    ds9 -title DS9Test -zscale fits/img.fits \
	-catalog import tsv aux/glyph.tsv "$@" \
	-catalog regions -regions system image -regions save $out -exit
    o=`diff -w $exp $out`
    if [ "$o" = "" ]; then
	echo "PASSED"
    else
	echo "FAILED"
	echo "$o"
    fi
    rm -f $out
    echo ""
}

# per row image file from a column, native size
glyphit aux/glyph.native.reg \
    -catalog symbol shape glyph \
    -catalog symbol glyph 'regions/glyph_$type.png'
# width only keeps the aspect ratio
glyphit aux/glyph.size.reg \
    -catalog symbol shape glyph \
    -catalog symbol glyph 'regions/glyph_$type.png' \
    -catalog symbol size 24
# width and height
glyphit aux/glyph.size2.reg \
    -catalog symbol shape glyph \
    -catalog symbol glyph 'regions/glyph_$type.png' \
    -catalog symbol size 24 -catalog symbol size2 12
# symbol file with a glyph column and a condition
glyphit aux/glyph.sym.reg \
    -catalog symbol load aux/glyph.sym
# symbol file from before glyphs (no glyph, width, dash or font columns)
glyphit aux/glyph.oldsym.reg \
    -catalog symbol load aux/ds9.sym \
    -catalog symbol shape glyph \
    -catalog symbol glyph regions/glyph_dot.png

echo "Testing glyph default image"
rm -f foo.glyph.reg
ds9 -title DS9Test -zscale fits/img.fits \
    -catalog import tsv aux/glyph.tsv -catalog symbol shape glyph \
    -catalog regions -regions system image -regions save foo.glyph.reg -exit
n=`grep -c 'glyph(.*doc/sun.png' foo.glyph.reg`
if [ "$n" = "5" ]; then echo "PASSED"; else echo "FAILED"; cat foo.glyph.reg; fi
rm -f foo.glyph.reg
echo ""

echo "Testing glyph symbol file round trip"
rm -f foo.glyph.sym
ds9 -title DS9Test -zscale fits/img.fits \
    -catalog import tsv aux/glyph.tsv \
    -catalog symbol load aux/glyph.sym \
    -catalog symbol save foo.glyph.sym -exit
o=`diff -w aux/glyph.sym foo.glyph.sym`
if [ "$o" = "" ]; then echo "PASSED"; else echo "FAILED"; echo "$o"; fi
rm -f foo.glyph.sym
echo ""
