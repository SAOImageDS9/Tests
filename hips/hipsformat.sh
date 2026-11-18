#!/bin/bash
# HiPS checks: format= (which tiles to read when a HiPS has several
# kinds; fitsy/hips.C, which the Tcl side asks through hipsinfo format), the Open HiPS dialog's Tiles
# choice, and hips close. Run from the top of the ds9 tree:
#   Tests/hips/hipsformat.sh
# Starts and stops its own ds9 (title HiPSFormat; cache ~/.HiPSFormat,
# removed at the end) and a local HTTP server.

T=HiPSFormat
. Tests/hips/lib.sh
same() { "$PY" -I -c "
import sys, numpy as np; from astropy.io import fits
a, b = fits.getdata(sys.argv[1]), fits.getdata(sys.argv[2])
print('same' if a.shape == b.shape and np.array_equal(a, b, equal_nan=True) else 'differ')" $W/$1.fits $W/$2.fits; }
# where the values came from, as the header's HISTORY says
src() { $X/xpaget $T fits header | grep -o 'from [A-Za-z]*[. ][a-z]*' | head -1; }

"$PY" -I $H/mkpng.py $W >/dev/null
# one HiPS with the same pixels as FITS, PNG and JPEG tiles
M=$W/multi
mkdir $M
for d in pjpg ppng pfits; do (cd $W/$d && tar cf - Norder*) | (cd $M && tar xf -); done
sed 's/^hips_tile_format.*/hips_tile_format = png jpeg fits/' $W/pfits/properties > $M/properties
grep -q '^hips_pixel_cut' $M/properties || echo 'hips_pixel_cut = 10 200' >> $M/properties
# a colour HiPS that also has FITS tiles (their luminance)
C=$W/cmulti
mkdir $C
for d in prgb prgbl; do (cd $W/$d && tar cf - Norder*) | (cd $C && tar xf -); done
sed 's/^hips_tile_format.*/hips_tile_format = png fits/' $W/pcol/properties > $C/properties
grep -q '^dataproduct_subtype' $C/properties || echo 'dataproduct_subtype = color' >> $C/properties

start
errors

echo "1. format= picks the tiles"
$X/xpaset -p $T hips "$M[norder=0]"
check "automatic: FITS" "$(src)" "from fits tiles"
shot f
$X/xpaset -p $T hips "$M[norder=0,format=png]"
check "format=png" "$(src)" "from png tiles"
shot p
check "  the same pixels" "$(same f p)" "same"
check "  xpaget hips keeps it" "$($X/xpaget $T hips)" "$M[norder=0,format=png]"
$X/xpaset -p $T hips "$M[norder=0,format=jpeg]"
check "format=jpeg" "$(src)" "from jpg tiles"
$X/xpaset -p $T hips "$M[format=JPG,norder=0]"
check "format=JPG (any case, jpg)" "$(src)" "from jpg tiles"
$X/xpaset -p $T hips "$M[norder=1,format=png]"
check "order 1, png: its Allsky.png" "$(src)" "from Allsky.png"
$X/xpaset -p $T hips "$M[norder=0,format=FITS]"
check "format=FITS" "$(src)" "from fits tiles"

echo "2. the scale limits follow the tiles"
$X/xpaset -p $T scale mode minmax
$X/xpaset -p $T hips "$M[norder=0]"
check "FITS: hips_pixel_cut" "$($X/xpaget $T scale limits)" "$(sed -n 's/^hips_pixel_cut *= *//p' $M/properties)"
$X/xpaset -p $T hips "$M[norder=0,format=png]"
check "PNG: 0-255" "$($X/xpaget $T scale limits)" "0 255"
$X/xpaset -p $T scale mode minmax

echo "3. refusals"
tcl 'set ::errs {}' >/dev/null
$X/xpaset -p $T hips "$M[format=gif]" 2>/dev/null
check "not a tile format" "$(lasterr)" "Unable to load HiPS $M[format=gif]: format= is fits, png or jpeg"
$X/xpaset -p $T hips "$W/pfits[format=png]" 2>/dev/null
check "not listed" "$(lasterr)" "Unable to load HiPS $W/pfits[format=png]: no PNG tiles (hips_tile_format = fits)"
tcl 'set ::errs {}' >/dev/null

echo "4. colour"
$X/xpaset -p $T frame delete all
$X/xpaset -p $T frame new
$X/xpaset -p $T hips "$C[norder=0]"
check "a colour HiPS with FITS tiles: their data, a plain frame" "$(tcl '$current(frame) get type')/$(src)" "base/from fits tiles"
$X/xpaset -p $T hips "$C[norder=0,format=png]"
check "format=png: colour, an RGB frame" "$(tcl '$current(frame) get type')/$($X/xpaget $T frame)" "rgb/2"

echo "5. remote: only the tiles asked for"
mkdir -p $W/www; ln -s $M $W/www/multi
serve
$X/xpaset -p $T frame delete all
$X/xpaset -p $T frame new
mark
$X/xpaset -p $T hips "$U/multi[format=png]"
check "quick look: Allsky.png" "$(grep -c 'Allsky' $W/log)/$(grep -c 'Allsky.png' $W/log)/$(src)" "1/1/from Allsky.png"
mark
$X/xpaset -p $T hips "$U/multi[norder=0,format=jpeg]"
check "order 0 jpeg: jpg tiles only (no Moc.fits: all 12 asked, 11 there)" "$(grep -c 'Npix' $W/log)/$(grep -c 'Npix[0-9]*\.jpg' $W/log)/$(grep -c '^200 .*Npix' $W/log)/$(src)" "12/12/11/from jpg tiles"
# deep window: zoomed in, order 1 tiles, still png
rm -rf ~/.$T/hips
$X/xpaset -p $T hips "$U/multi[norder=0,format=png,proj=tan,lon0=45,lat0=30,fov=40]"
mark
$X/xpaset -p $T zoom to 8
for i in $(seq 1 40); do [ "$($X/xpaget $T hips status)" = 0 ] && [ "$(tcl 'set hipsdeep(running)')" = 0 ] && break; nap; done
check "deep tiles fetched as png" "$( [ $(grep -c 'Norder1/.*Npix' $W/log) -gt 0 ] && echo some)/$(grep -c 'Npix[0-9]*\.\(fits\|jpg\)' $W/log)" "some/0"
# a tile missing only as PNG is still fetched as FITS
cp -R $M $W/www/fmix; rm $W/www/fmix/Norder0/Dir0/Npix3.png
$X/xpaset -p $T hips "$U/fmix[norder=0,format=png]"
mark
$X/xpaset -p $T hips "$U/fmix[norder=0,format=fits]"
check "png 404 then fits: Npix3.fits asked for" "$(grep -c '^200 /fmix/Norder0/Dir0/Npix3.fits' $W/log)" "1"
# an unusable (truncated) Allsky is not kept, nor asked for again
cp -R $M $W/www/badsky
head -c 100 $M/Norder1/Allsky.png > $W/www/badsky/Norder1/Allsky.png
d=~/.$T/hips/127.0.0.1_$(cat $W/port)/badsky/Norder1
mark
$X/xpaset -p $T hips "$U/badsky[format=png]"
check "truncated Allsky.png: not cached, remembered" "$(ls $d/Allsky.png 2>/dev/null | wc -l | tr -d ' ')/$(ls -a $d | grep -c '^.noallsky.png$')" "0/1"
mark
$X/xpaset -p $T hips "$U/badsky[format=png]"
check "  not asked for again" "$(grep -c 'Allsky' $W/log)" "0"
tcl 'set ::errs {}' >/dev/null
kill $SRV; wait $SRV 2>/dev/null

echo "6. backup/restore keeps format="
$X/xpaset -p $T frame delete all
$X/xpaset -p $T frame new
$X/xpaset -p $T hips "$M[norder=0,format=png]"
$X/xpaset -p $T backup $W/b.bck
$X/xpaset -p $T frame delete all
$X/xpaset -p $T restore $W/b.bck
check "restored" "$($X/xpaget $T hips)/$(src)" "$M[norder=0,format=png]/from png tiles"

echo "7. hips close"
# (multi has no Moc.fits: the outline is the whole sky, and an error)
$X/xpaset -p $T hips coverage yes
tcl 'set ::errs {}' >/dev/null
$X/xpaset -p $T hips close
check "the frame is empty" "$($X/xpaget $T hips)/$(tcl '$current(frame) has fits')/$($X/xpaget $T frame all | tr -d ' ')" "/0/1"
$X/xpaset -p $T fits $W/f.fits
$X/xpaset -p $T hips close
check "not a HiPS: left alone" "$(tcl '$current(frame) has fits')" "1"
$X/xpaset -p $T frame delete all
$X/xpaset -p $T frame new
$X/xpaset -p $T hips "$C[norder=0,format=png]"
$X/xpaset -p $T hips close
check "an RGB frame of a colour HiPS" "$(tcl '$current(frame) has fits')" "0"

echo "8. the Open HiPS dialog's Tiles choice"
# dialog <dir> <setup tcl> <finish tcl>: print what it returned
dialog() {
    tcl "after idle {set ::res [HiPSOpenParamsDialog {$1}]; set ::done 1}; set ::done 0" >/dev/null
    opened .hipsopen
    [ -n "$2" ] && tcl "$2" >/dev/null
    tcl "$3" >/dev/null
    for i in $(seq 1 20); do [ "$(tcl 'set ::done')" = 1 ] && break; nap; done
    tcl 'set ::res'
}
check "several: Tiles shown, FITS first" \
    "$(dialog $M 'set ::st [winfo ismapped .hipsopen.data.tiles]/$hpxed(extlabel)/[.hipsopen.data.tiles.m index end]' 'set hpxed(ok) 0' >/dev/null; tcl 'set ::st')" \
    "1/FITS (data values)/3"
check "one kind: no Tiles" "$(dialog $W/pfits 'set ::st [winfo ismapped .hipsopen.data.tiles]' 'set hpxed(ok) 0' >/dev/null; tcl 'set ::st')" "0"
check "the automatic choice: no format=" "$(dialog $M 'set hpxed(order) 0; HiPSOpenOrderChanged' HiPSOpenOK)" "$M[norder=0]"
check "PNG: format=png" "$(dialog $M 'set hpxed(ext) png; HiPSOpenExtChanged; set hpxed(order) 0; HiPSOpenOrderChanged' HiPSOpenOK)" "$M[norder=0,format=png]"
check "JPEG: format=jpeg" "$(dialog $M 'set hpxed(ext) jpg; HiPSOpenExtChanged' HiPSOpenOK)" "$M[format=jpeg]"
check "  the cut line hidden, the reading line says so" \
    "$(dialog $M 'set hpxed(ext) png; HiPSOpenExtChanged; set ::st [winfo ismapped .hipsopen.file.cut]/$hpxed(reading)' 'set hpxed(ok) 0' >/dev/null; tcl 'set ::st')" \
    "0/Reading png: display values 0-255"
check "colour HiPS on png says RGB" \
    "$(dialog $C 'set hpxed(ext) png; HiPSOpenExtChanged; set ::st $hpxed(reading)' 'set hpxed(ok) 0' >/dev/null; tcl 'set ::st')" \
    "Reading png: colour, into an RGB frame"
# PNG tiles for order 0 only: switching rescans
rm -f $M/Norder1/Allsky.png $M/Norder1/Dir0/*.png
check "the orders are those of the tiles chosen" \
    "$(dialog $M 'set m .hipsopen.data.order.m; set a [$m entrycget [$m index {Order 1*}] -state]; set hpxed(ext) png; HiPSOpenExtChanged; set ::st $a/[$m entrycget [$m index {Order 1*}] -label]/[$m entrycget [$m index {Order 1*}] -state]' 'set hpxed(ok) 0' >/dev/null; tcl 'set ::st')" \
    "normal/Order 1: no tiles/disabled"

check "no errors" "$(tcl 'set ::errs')" ""
$X/xpaset -p $T exit
for i in $(seq 1 20); do [ "$($X/xpaaccess -n $T)" = 0 ] && break; nap; done
finish
