#!/bin/bash
# HiPS Phase 3 checks: colour HiPS (dataproduct_subtype = color, PNG/JPEG
# tiles) load into an RGB frame, one HEALPix map per channel. Run from
# the top of the ds9 tree: Tests/hips/hipscolour.sh
# Starts and stops its own ds9s (title HiPSCol) and a local HTTP server.

T=HiPSCol
. Tests/hips/lib.sh
ERRS=1
ftype() { tcl '$current(frame) get type'; }
cmp() { "$PY" -I -c "
import sys, numpy as np; from astropy.io import fits
a, b = fits.getdata(sys.argv[1]), fits.getdata(sys.argv[2])
if a.shape != b.shape: print(f'shape {a.shape} {b.shape}'); sys.exit()
na, nb = np.isnan(a), np.isnan(b)
if (na != nb).any(): print(f'NaN differ at {int((na != nb).sum())} pixels'); sys.exit()
print('same' if np.array_equal(a[~na], b[~na]) else f'max diff {np.abs(a[~na]-b[~na]).max()}')" $W/$1.fits $W/$2.fits; }
# channels <prefix>: save each channel of the current RGB frame
channels() {
    for c in red green blue; do $X/xpaset -p $T rgb channel $c; shot $1$c; done
    $X/xpaset -p $T rgb channel red
}

"$PY" -I $H/mkpng.py $W >/dev/null
# references: each channel as its own FITS HiPS, at order 0 and 1
rm -rf ~/.$T
start
for o in 0 1; do
    for c in r g b; do $X/xpaset -p $T hips "$W/pc$c[norder=$o]"; shot ref$o$c; done
done
$X/xpaset -p $T frame delete all
$X/xpaset -p $T frame new

echo "1. a colour HiPS goes to an RGB frame"
$X/xpaset -p $T hips "$W/pcol[norder=0]"
check "new RGB frame" "$(ftype)/$(nframes)" "rgb/2"
channels a
check "red = the red levels" "$(cmp ared ref0r)" "same"
check "green = the green levels" "$(cmp agreen ref0g)" "same"
check "blue = the blue levels" "$(cmp ablue ref0b)" "same"
check "header names the channel" "$(hdr | grep -c 'the red channel of the colour tiles')" "1"
check "xpaget hips" "$($X/xpaget $T hips)" "$W/pcol[norder=0]"
check "current channel kept (red)" "$($X/xpaget $T rgb channel)" "red"
lim=""; for c in red green blue; do $X/xpaset -p $T rgb channel $c; lim="$lim $($X/xpaget $T scale limits)"; done
$X/xpaset -p $T rgb channel red
check "every channel 0-255" "$lim" " 0 255 0 255 0 255"

echo "2. into the current RGB frame; Allsky; projections"
$X/xpaset -p $T hips "$W/pcol"
check "same frame reused" "$(ftype)/$(nframes)" "rgb/2"
channels b
check "order 1 (Allsky.png is grey here: none; tiles) red" "$(cmp bred ref1r)" "same"
check "  blue" "$(cmp bblue ref1b)" "same"
$X/xpaset -p $T hips "$W/pcol[norder=1,proj=TAN,fov=60]"
s=""; for c in red green blue; do $X/xpaset -p $T rgb channel $c; s="$s $(size)"; done
check "TAN: three windows the same size" "$s" " $(size) $(size) $(size)"
$X/xpaset -p $T rgb channel red

echo "3. a grey HiPS in an RGB frame goes to a plain frame"
$X/xpaset -p $T hips "$W/ppng[norder=0]"
check "new plain frame" "$(ftype)/$(nframes)" "base/3"

echo "4. Open Recent and the dialog"
tcl 'RecentOpen [list hips {'$W'/pcol[norder=0]}]' >/dev/null
check "Open Recent from a plain frame: RGB frame" "$(ftype)/$(nframes)" "rgb/4"
tcl "after idle {set ::res [HiPSOpenParamsDialog {$W/pcol}]; set ::done 1}; set ::done 0" >/dev/null
for i in $(seq 1 40); do [ "$(tcl 'grab current')" = .hipsopen ] && break; nap; done
check "dialog says colour" "$(tcl '.hipsopen.data.reading cget -text')" "Reading png: colour, into an RGB frame"
tcl 'set hpxed(ok) 0' >/dev/null

echo "5. backup/restore"
$X/xpaset -p $T frame delete all
$X/xpaset -p $T hips "$W/pcol[norder=1]"
channels c
$X/xpaset -p $T backup $W/b.bck
check "backup restores the HiPS once" "$(grep -c 'HiPSRestore' $W/b.bck)" "1"
stop
start
$X/xpaset -p $T restore $W/b.bck
check "restored: one RGB frame" "$(ftype)/$(nframes)" "rgb/1"
channels d
check "  red" "$(cmp dred cred)" "same"
check "  green" "$(cmp dgreen cgreen)" "same"
check "  blue" "$(cmp dblue cblue)" "same"

echo "6. remote colour HiPS"
mkdir -p $W/www; ln -s $W/pcol $W/www/pcol
serve
$X/xpaset -p $T hips "$U/pcol[norder=0]"
channels e
check "remote: red" "$(cmp ered ref0r)" "same"
check "remote: blue" "$(cmp eblue ref0b)" "same"
check "  each tile fetched once" "$(grep -c '^200 /pcol/Norder0/Dir0/Npix' $W/log)" "11"
kill $SRV; wait $SRV 2>/dev/null

echo "7. XRISM (a real colour HiPS)"
$X/xpaset -p $T frame delete all
$X/xpaset -p $T hips "$TOP/hips/XRISM_RESOLVE[norder=3]"
check "RGB frame, order 3" "$(ftype)/$(size)" "rgb/20480 20480"
$X/xpaset -p $T hips "$TOP/hips/XRISM_RESOLVE[proj=MOL]"
check "MOL" "$(ftype)/$(nframes)/$(lasterr)" "rgb/1/"

echo "8. the coverage overlay of a colour HiPS is the frame's"
# aux <channel>: that channel's aux contours (the current one is put back)
echo 'proc ::auxn {c} {global current; set f $current(frame); set o [$f get rgb channel]; $f rgb channel $c; set n [$f get contour aux count]; $f rgb channel $o; return $n}' | $X/xpaset $T tcl
aux() { tcl "auxn $1"; }
$X/xpaset -p $T rgb channel green
$X/xpaset -p $T hips coverage yes
cov=""; for c in red green blue; do $X/xpaset -p $T rgb channel $c; cov="$cov $($X/xpaget $T hips coverage)"; done
check "on from green: on in every channel" "$cov" " yes yes yes"
check "  drawn once, in red" "$(aux red)/$(aux green)/$(aux blue)" "1/0/0"
$X/xpaset -p $T backup $W/c.bck
check "  the backup restores it" "$(grep -c 'HiPSRestore.* 0$' $W/c.bck)" "1"
$X/xpaset -p $T hips coverage no
check "off from blue" "$($X/xpaget $T hips coverage)/$(aux red)" "no/0"
$X/xpaset -p $T hips coverage yes
$X/xpaset -p $T hips "$TOP/hips/XRISM_RESOLVE[proj=MOL]"
check "loading again: off" "$($X/xpaget $T hips coverage)" "no"
$X/xpaset -p $T frame delete all
$X/xpaset -p $T restore $W/c.bck
check "restored: on" "$($X/xpaget $T hips coverage)/$(aux red)" "yes/1"
$X/xpaset -p $T hips coverage no
check "  and off again" "$($X/xpaget $T hips coverage)/$(aux red)" "no/0"

echo "9. each file decoded once, for all channels, and kept across rebuilds"
# a copy: new paths, so nothing of it is cached yet
cp -R $W/pcol $W/pcol2
# count decodes (image create photo -file) of pcol2 files from here on
# (not ds9's own icons)
echo 'rename ::image ::image_real; set ::dec {}; proc ::image {args} {if {[lrange $args 0 2] eq {create photo -file} && [string match */pcol2/* [lindex $args 3]]} {lappend ::dec [lindex $args 3]}; uplevel 1 ::image_real $args}' | $X/xpaset $T tcl
# dec: "<decodes> <distinct files>" since the last call
dec() { tcl 'set n "[llength $::dec] [llength [lsort -unique $::dec]]"; set ::dec {}; set n'; }
$X/xpaset -p $T hips "$W/pcol2[norder=0]"
check "load: 11 tiles, each decoded once" "$(dec)" "11 11"
$X/xpaset -p $T hips "$W/pcol2[norder=0]"
check "load again: none" "$(dec)" "0 0"
V="norder=0,proj=TAN,lon0=40,lat0=20,fov=40"
$X/xpaset -p $T hips "$W/pcol2[$V]"
$X/xpaset -p $T zoom to 4
d=$(dec); n=${d% *}
check "deep window: its order-1 tiles each decoded once" "$( [ $n -gt 0 ] && echo "$d")" "$n $n"
channels deep
$X/xpaset -p $T block to 2
$X/xpaset -p $T block to 1
$X/xpaset -p $T pan to 41 21 fk5
$X/xpaset -p $T pan to 40 20 fk5
# a new window (each window had its own cache before)
$X/xpaset -p $T hips "$W/pcol2[$V]"
$X/xpaset -p $T zoom to 4
check "block change, pans, the window built again: none" "$(dec)" "0 0"
# the deep channels against each channel as its own FITS HiPS
for c in r g b; do
    $X/xpaset -p $T frame new
    $X/xpaset -p $T hips "$W/pc$c[$V]"
    $X/xpaset -p $T zoom to 4
    shot dref$c
    $X/xpaset -p $T frame delete
done
check "deep red = the red levels" "$(cmp deepred drefr)" "same"
check "  green" "$(cmp deepgreen drefg)" "same"
check "  blue" "$(cmp deepblue drefb)" "same"
dec >/dev/null
# rewritten tiles (new files, as a fetch writes them) are read afresh
for f in $W/pcol2/Norder1/Dir0/*.png; do cp $f $W/x.png; mv $W/x.png $f; done
$X/xpaset -p $T hips "$W/pcol2[$V]"
$X/xpaset -p $T zoom to 4
check "rewritten tiles decoded again, once each" "$(dec)" "$n $n"

check "no unexpected errors" "$(tcl 'set ::errs')" ""
stop
[ -n "$KEEP" ] && cp -R $W/c.bck* "$KEEP"
finish
