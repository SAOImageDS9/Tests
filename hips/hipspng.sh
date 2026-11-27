#!/bin/bash
# HiPS Phase 3 checks: PNG and JPEG tiles (fitsy/hips.C readPhoto, and
# the Tcl side asks it, hipsinfo format). Run from the top of the ds9 tree:
#   Tests/hips/hipspng.sh
# Starts and stops its own ds9 (title HiPSPng) and a local HTTP server.

T=HiPSPng
. Tests/hips/lib.sh
FERMI=$TOP/Tests/hipsdata/data1/ancillary/missions/Fermi_Band4/HiPS
# cmp <a> <b> <tol>: same NaNs, values within tol
cmp() { "$PY" -I -c "
import sys, numpy as np; from astropy.io import fits
a, b = fits.getdata(sys.argv[1]), fits.getdata(sys.argv[2]); t = float(sys.argv[3])
if a.shape != b.shape: print(f'shape {a.shape} {b.shape}'); sys.exit()
na, nb = np.isnan(a), np.isnan(b)
if (na != nb).any(): print(f'NaN differ at {int((na != nb).sum())} pixels'); sys.exit()
d = np.abs(a[~na] - b[~na]).max() if (~na).any() else 0
print('same' if d <= t else f'max diff {d}')" $W/$1.fits $W/$2.fits $3; }

"$PY" -I $H/mkpng.py $W >/dev/null

start
errors

echo "1. PNG tiles = FITS tiles"
for o in 0 1; do
    $X/xpaset -p $T hips "$W/pfits[norder=$o]"; shot f$o
    $X/xpaset -p $T hips "$W/ppng[norder=$o]"; shot p$o
    check "order $o: PNG (grey + alpha) equals FITS, alpha 0 = NaN" "$(cmp f$o p$o 0)" "same"
done
check "order 1 came from Allsky.png" "$(hdr | grep -c 'from Allsky.png')" "1"
$X/xpaset -p $T hips "$W/ppng[norder=0]"
check "order 0 from png tiles" "$(hdr | grep -c 'from png tiles: 11 of 12')" "1"
check "display-level note in the header" "$(hdr | grep -c 'png display levels 0-255')" "1"
check "no hips_pixel_cut comment (physical units)" "$(hdr | grep -c 'hips_pixel_cut')" "0"
$X/xpaset -p $T scale mode minmax
$X/xpaset -p $T hips "$W/ppng"
check "PNG: limits 0-255, not the (physical) cut" "$($X/xpaget $T scale mode)/$($X/xpaget $T scale limits)" "user/0 255"
$X/xpaset -p $T hips "$W/pfits"
check "  but is to FITS" "$($X/xpaget $T scale mode)" "user"
$X/xpaset -p $T scale mode minmax

echo "2. JPEG"
$X/xpaset -p $T hips "$W/pfits[norder=0]"; shot f0
$X/xpaset -p $T hips "$W/pjpg[norder=0]"; shot j0
r=$("$PY" -I -c "
import sys, numpy as np; from astropy.io import fits
a, b = fits.getdata(sys.argv[1]), fits.getdata(sys.argv[2])
ok = ~np.isnan(a)
d = np.abs(a[ok] - b[ok])
# JPEG has no alpha: its NaNs are the FITS ones minus the blank pixels
sub = bool((np.isnan(b) <= np.isnan(a)).all())
print(f'{np.median(d):.1f} {sub} {int(np.isnan(a).sum() - np.isnan(b).sum())}')" $W/f0.fits $W/j0.fits)
read med sub nblank <<< "$r"
if "$PY" -I -c "import sys; sys.exit(0 if float('$med') <= 3 else 1)"; then ok "JPEG close to FITS (median |diff| $med)"; else bad "JPEG median |diff| $med"; fi
check "  JPEG NaNs are a subset of the FITS ones" "$sub" "True"
# (some map pixels appear twice in the HPX image, at facet edges)
if [ "$nblank" -gt 0 ]; then ok "  the blank pixels ($nblank in the image) have values in JPEG"; else bad "  blank pixels with values: $nblank"; fi

echo "3. colour PNG: luminance"
$X/xpaset -p $T hips "$W/prgbl[norder=0]"; shot l0
$X/xpaset -p $T hips "$W/prgb[norder=0]"; shot c0
check "RGB PNG = its luminance (Rec. 601)" "$(cmp l0 c0 1e-4)" "same"

echo "4. the Open HiPS dialog"
dialog() {
    tcl "after idle {set ::res [HiPSOpenParamsDialog {$1}]; set ::done 1}; set ::done 0" >/dev/null
    for i in $(seq 1 20); do [ "$(tcl 'winfo exists .hipsopen')" = 1 ] && break; nap; done
    [ -n "$2" ] && tcl "$2" >/dev/null
    tcl "$3" >/dev/null
    for i in $(seq 1 20); do [ "$(tcl 'set ::done')" = 1 ] && break; nap; done
    tcl 'set ::res'
}
dialog "$W/ppng" 'set ::lab $hpxed(orderlabel); set ::desc [.hipsopen.file.desc cget -text]/$hpxed(reading)' 'set hpxed(ok) 0' >/dev/null
check "orders from png files" "$(tcl 'set ::lab')" "Automatic (Order 1: NSIDE 32, Allsky, 0.0 MB)"
check "header says display values" "$(tcl 'set ::desc')" "equatorial, orders 0-1, tile 16, png/Reading png: display values 0-255"
dialog "$TOP/Tests/hipsdata/XRISM_RESOLVE" "" 'set hpxed(ok) 0' >/dev/null
check "XRISM (png only) is accepted" "$(tcl 'llength $::errs')" "0"

echo "5. real samples"
mkdir -p $W/fpng; for f in $FERMI/Norder* $FERMI/Moc.fits; do ln -s $f $W/fpng/; done
sed 's/^hips_tile_format.*/hips_tile_format = png/' $FERMI/properties > $W/fpng/properties
$X/xpaset -p $T hips "$W/fpng"
check "Fermi from Allsky.png" "$(size)/$(hdr | grep -c 'from Allsky.png')" "2560 2560/1"
$X/xpaset -p $T hips "$W/fpng[norder=2]"
check "Fermi from png tiles at order 2" "$(size)/$(hdr | grep -c 'from png tiles: 192 of 192')" "1280 1280/1"
$X/xpaset -p $T hips "$TOP/Tests/hipsdata/XRISM_RESOLVE[proj=MOL]"
check "XRISM (png only), automatic: order 2 tiles" "$(hdr | grep -c 'order 2, nside 2048, from png tiles: 2 of 192')/$(lasterr)" "1/"
$X/xpaset -p $T hips "$TOP/Tests/hipsdata/XRISM_RESOLVE[norder=3]"
check "XRISM order 3: its tile, not the reduced Allsky" "$(hdr | grep -c 'from png tiles: 1 of 768')" "1"

echo "6. remote PNG"
mkdir -p $W/www; ln -s $W/ppng $W/www/ppng
serve
$X/xpaset -p $T hips "$U/ppng[norder=0]"; shot r0
$X/xpaset -p $T hips "$W/ppng[norder=0]"; shot p0
check "remote PNG tiles = local" "$(cmp r0 p0 0)" "same"
check "  fetched .png tiles" "$(grep -c '^200 /ppng/Norder0/Dir0/Npix.*\.png' $W/log)" "11"
check "  one 404 (missing tile 5)" "$(grep -c '^404 /ppng/Norder0/Dir0/Npix5.png' $W/log)" "1"
$X/xpaset -p $T hips "$U/ppng"
check "remote quick look: Allsky.png" "$(grep -c '^200 /ppng/Norder1/Allsky.png' $W/log)" "1"
kill $SRV; wait $SRV 2>/dev/null

check "no unexpected errors" "$(tcl 'set ::errs')" ""
$X/xpaset -p $T exit
finish
