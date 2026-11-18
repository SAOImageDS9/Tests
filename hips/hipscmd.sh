#!/bin/bash
# HiPS Phase 2 checks: the -hips command-line option and the hips
# XPA command (set and get). Run from the top of the ds9 tree:
#   Tests/hips/hipscmd.sh
# Starts and stops its own ds9 (title HiPSCmd).

T=HiPSCmd
. Tests/hips/lib.sh
FERMI=$TOP/hips/data1/ancillary/missions/Fermi_Band4/HiPS
# check <name> <got> <want>

rm -rf ~/$T.auto ~/$T.auto.dir
echo "command line: -hips <dir>[norder=2]"
PATH="$X:$PATH" $X/ds9 -title $T -hips "${FERMI}[norder=2]" >/dev/null 2>&1 &
for i in $(seq 1 40); do [ "$($X/xpaaccess -n $T)" -ge 1 ] && break; perl -e 'select(undef,undef,undef,0.5)'; done
# ds9 answers XPA before it has worked through its command line
for i in $(seq 1 40); do [ "$(size)" != "0 0" ] && break; perl -e 'select(undef,undef,undef,0.5)'; done
check "loaded at order 2 (nside 256)" "$(size)" "1280 1280"
check "xpaget hips" "$($X/xpaget $T hips)" "${FERMI}[norder=2]"

echo "xpaset hips"
$X/xpaset -p $T hips "${FERMI}[proj=MOL]"
check "proj=MOL in the current frame" "$(size)" "2834 1418"
check "xpaget hips" "$($X/xpaget $T hips)" "${FERMI}[proj=MOL]"
check "still one frame" "$(frames)" "1"

$X/xpaset -p $T hips new "$FERMI"
check "hips new: a second frame" "$(frames)" "2"
check "default order 3 (nside 512)" "$(size)" "2560 2560"
check "xpaget hips" "$($X/xpaget $T hips)" "$FERMI"

echo "a FITS file replaces the HiPS"
${PY:-$HOME/miniforge/envs/hpxtest/bin/python} -I -c "import numpy as np; from astropy.io import fits; fits.PrimaryHDU(np.zeros((10,10),'f4')).writeto('$W/img.fits')"
$X/xpaset -p $T fits "$W/img.fits"
check "xpaget hips after a FITS load" "$($X/xpaget $T hips)" ""

echo "errors"
r=$($X/xpaset -p $T hips "$TOP/hips" 2>&1)
case "$r" in *"Unable to load HiPS"*"can't read"*) ok "not a HiPS: $(echo "$r" | head -c 100)";; *) bad "not a HiPS: '$r'";; esac
r=$($X/xpaset -p $T hips "${FERMI}[norder=7]" 2>&1)
case "$r" in *"Unable to load HiPS"*"deeper than hips_order"*) ok "too deep: $(echo "$r" | head -c 100)";; *) bad "too deep: '$r'";; esac

echo "HiPS options elsewhere are refused, not ignored"
# err <spec>: the load's error, from Unable to load on
err() { $X/xpaset -p $T fits "$1" 2>&1 | sed 's/.*Unable to load/Unable to load/; s/ (DS9:.*//; s|/[^ ]*/||'; }
check "norder= on an image" "$(err "$W/img.fits[norder=2]")" "Unable to load fits  img.fits[norder=2]: norder= is for a HiPS (the hips command)"
check "slice= on a HEALPix table" "$(err "$TOP/Tests/fits/wmap.fits[slice=2]")" "Unable to load fits  wmap.fits[slice=2]: slice= is for a HiPS (the hips command)"
check "format= on a HEALPix table" "$(err "$TOP/Tests/fits/wmap.fits[format=png]")" "Unable to load fits  wmap.fits[format=png]: format= is for a HiPS (the hips command)"
check "mocorder= on a map that isn't a MOC" "$(err "$TOP/Tests/fits/wmap.fits[mocorder=3]")" "Unable to load fits  wmap.fits[mocorder=3]: HEALPix: mocorder= is for a MOC (ORDERING = NUNIQ)"
$X/xpaset -p $T fits "$TOP/hips/Abell1763_irac1/Moc.fits[mocorder=5]"
check "  and on a MOC it still works" "$(size)" "160 160"
r=$(echo '$current(frame) load hipz /nowhere' | $X/xpaset $T tcl 2>&1)
case "$r" in *"load: unknown type"*) ok "frame load, a misspelled type: $(echo "$r" | sed 's/XPA.ERROR //; s/ (DS9:.*//')";; *) bad "frame load hipz: '$r'";; esac

echo "the hips command's grammar"
$X/xpaset -p $T hips "${FERMI}[norder=1]"
check "xpaget hips" "$($X/xpaget $T hips)" "${FERMI}[norder=1]"
check "xpaget hips coverage" "$($X/xpaget $T hips coverage)" "no"
check "xpaget hips status" "$($X/xpaget $T hips status)" "0"
r=$($X/xpaget $T hips bogus 2>&1)
case "$r" in *XPA\$ERROR*) ok "xpaget hips bogus: an error";; *) bad "xpaget hips bogus: '$r'";; esac
r=$($X/xpaget $T hips status extra 2>&1)
case "$r" in *XPA\$ERROR*) ok "xpaget hips status extra: an error";; *) bad "xpaget hips status extra: '$r'";; esac
for w in status list; do
  r=$($X/xpaset -p $T hips $w 2>&1)
  case "$r" in *XPA\$ERROR*) ok "xpaset hips $w: an error";; *) bad "xpaset hips $w: '$r'";; esac
  check "  nothing loaded" "$($X/xpaget $T hips)" "${FERMI}[norder=1]"
done
$X/xpaset -p $T exit
finish
