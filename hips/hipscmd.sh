#!/bin/bash
# HiPS Phase 2 checks: the -hips command-line option and the hips
# XPA command (set and get). Run from the top of the ds9 tree:
#   Tests/hips/hipscmd.sh
# Starts and stops its own ds9 (title HiPSCmd).

TOP=$PWD
X=$TOP/bin
T=HiPSCmd
FERMI=$TOP/hips/data1/ancillary/missions/Fermi_Band4/HiPS
W=$(mktemp -d "${TMPDIR:-/tmp}/hipscmd.XXXXXX")
pass=0; fail=0
ok()  { pass=$((pass+1)); echo "  ok   $*"; }
bad() { fail=$((fail+1)); echo "  FAIL $*"; }
# check <name> <got> <want>
check() { if [ "$2" = "$3" ]; then ok "$1: $2"; else bad "$1: got '$2', want '$3'"; fi; }

size()   { echo 'set f [open '$W'/q w]; puts $f [$current(frame) get fits size]; close $f' | $X/xpaset $T tcl; cat $W/q; }
frames() { $X/xpaget $T frame all | wc -w | tr -d ' '; }

rm -rf ~/$T.auto ~/$T.auto.dir
echo "command line: -hips <dir>[order=2]"
PATH="$X:$PATH" $X/ds9 -title $T -hips "${FERMI}[order=2]" >/dev/null 2>&1 &
for i in $(seq 1 40); do [ "$($X/xpaaccess -n $T)" -ge 1 ] && break; perl -e 'select(undef,undef,undef,0.5)'; done
# ds9 answers XPA before it has worked through its command line
for i in $(seq 1 40); do [ "$(size)" != "0 0" ] && break; perl -e 'select(undef,undef,undef,0.5)'; done
check "loaded at order 2 (nside 256)" "$(size)" "1280 1280"
check "xpaget hips" "$($X/xpaget $T hips)" "${FERMI}[order=2]"

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
r=$($X/xpaset -p $T hips "${FERMI}[order=7]" 2>&1)
case "$r" in *"Unable to load HiPS"*"deeper than hips_order"*) ok "too deep: $(echo "$r" | head -c 100)";; *) bad "too deep: '$r'";; esac

$X/xpaset -p $T exit
rm -rf "$W"
echo "PASSED $pass, FAILED $fail"
[ $fail = 0 ]
