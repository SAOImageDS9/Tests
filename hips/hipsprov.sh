#!/bin/bash
# HiPS Phase 2 checks: provenance in the image header. The HiPS reader
# writes HISTORY/COMMENT cards into the HEALPix table header (survey,
# order, tiles read, initial view, hips_pixel_cut); FitsHPX::initHeader
# copies them into the HPX image, and FitsHPXReproj::initHeader on into
# projection windows, so File > Header and File > Save carry them.
# Plain HEALPix files keep their table's HISTORY/COMMENT the same way.
# Run from the top of the ds9 tree: Tests/hips/hipsprov.sh
# Starts and stops its own ds9 (title HiPSProv).

TOP=$PWD
X=$TOP/bin
T=HiPSProv
PY=${PY:-$HOME/miniforge/envs/hpxtest/bin/python}
FERMI=$TOP/hips/data1/ancillary/missions/Fermi_Band4/HiPS
W=$(mktemp -d "${TMPDIR:-/tmp}/hipsprov.XXXXXX")
pass=0; fail=0
ok()  { pass=$((pass+1)); echo "  ok   $*"; }
bad() { fail=$((fail+1)); echo "  FAIL $*"; }
check() { if [ "$2" = "$3" ]; then ok "$1: $2"; else bad "$1: got '$2', want '$3'"; fi; }
nap() { perl -e 'select(undef,undef,undef,0.3)'; }
hdr() { $X/xpaget $T fits header; }
# hcount <pattern>: matching header lines
hcount() { hdr | grep -c "$1"; }

rm -rf ~/$T.auto ~/$T.auto.dir ~/.$T
PATH="$X:$PATH" $X/ds9 -title $T >/dev/null 2>&1 &
for i in $(seq 1 40); do [ "$($X/xpaget $T version 2>/dev/null)" != "" ] && break; nap; done

did=$(sed -n 's/^creator_did *= *//p' $FERMI/properties | head -1)

echo "1. HPX image"
$X/xpaset -p $T hips "${FERMI}[order=2]"
check "HiPS survey" "$(hcount "^HISTORY.*HiPS $did")" "1"
check "order, nside, tiles read" "$(hcount '^HISTORY.*order 2, nside 256, from fits tiles: 192 of 192 tiles read')" "1"
check "hips_pixel_cut" "$(hcount '^COMMENT.*hips_pixel_cut 2.0E-9 8.0E-7')" "1"
check "OBJECT still there" "$(hcount "^OBJECT  = 'Fermi-LAT 1-3 GeV")" "1"
check "no NUL bytes in the header" "$(hdr | "$PY" -I -c 'import sys; print(sys.stdin.buffer.read().count(0))')" "0"

echo "2. projection windows"
$X/xpaset -p $T hips "${FERMI}[order=2,proj=MOL]"
check "MOL: HiPS survey" "$(hcount "^HISTORY.*HiPS $did")" "1"
check "MOL: order line" "$(hcount '^HISTORY.*order 2, nside 256')" "1"
$X/xpaset -p $T hips "${FERMI}[order=2,proj=TAN]"
check "TAN: HiPS survey" "$(hcount "^HISTORY.*HiPS $did")" "1"
check "TAN: centre from the initial view" "$(hcount '^HISTORY.*from hips_initial_ra/dec (ICRS)')" "1"
$X/xpaset -p $T hips "${FERMI}[order=2,proj=TAN,lon0=10,lat0=10]"
check "TAN with lon0/lat0: no initial-view card" "$(hcount 'hips_initial_ra/dec')" "0"

echo "3. File > Save keeps it"
$X/xpaset -p $T hips "${FERMI}[order=1,proj=MOL]"
$X/xpaset -p $T save fits $W/s.fits
check "saved file: HISTORY HiPS" "$("$PY" -I -c "
import sys; from astropy.io import fits
h = fits.getheader(sys.argv[1])
print(sum(1 for c in h.get('HISTORY', []) if c.strip().startswith('= HiPS') or c.strip().startswith('HiPS')))" $W/s.fits)" "1"

echo "4. a plain HEALPix table with HISTORY/COMMENT"
"$PY" -I -c "
import sys, numpy as np
from astropy.io import fits
c = fits.Column(name='T', format='E', array=np.arange(12*16*16, dtype='f4'))
t = fits.BinTableHDU.from_columns([c])
for k, v in (('PIXTYPE','HEALPIX'),('ORDERING','RING'),('NSIDE',16),('COORDSYS','G'),('INDXSCHM','IMPLICIT')):
    t.header[k] = v
t.header.add_history('made by hipsprov.sh')
t.header.add_comment('a test comment')
fits.HDUList([fits.PrimaryHDU(), t]).writeto(sys.argv[1])" $W/hpx.fits
$X/xpaset -p $T fits $W/hpx.fits
check "HISTORY copied" "$(hcount '^HISTORY.*made by hipsprov.sh')" "1"
check "COMMENT copied" "$(hcount '^COMMENT.*a test comment')" "1"
$X/xpaset -p $T fits "$W/hpx.fits[proj=AIT]"
check "AIT window: HISTORY copied" "$(hcount '^HISTORY.*made by hipsprov.sh')" "1"

$X/xpaset -p $T exit
rm -rf "$W" ~/.$T
echo "PASSED $pass, FAILED $fail"
[ $fail = 0 ]
