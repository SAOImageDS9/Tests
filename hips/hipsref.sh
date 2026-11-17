#!/bin/bash
# HiPS reference-image checks: what ds9 shows, projected, against an
# independent projection of the same data. mkref.py rebuilds the NESTED
# HEALPix map of an order straight from the tiles (not ds9's reader);
# refcmp.py projects it with reproject_from_healpix (astropy-healpix,
# nearest-neighbour, as ds9 samples) onto the WCS of the image ds9
# saved, converting frames, and counts the pixels that agree.
# Run from the top of the ds9 tree: Tests/hips/hipsref.sh
# Starts and stops its own ds9 (title HiPSRef).

TOP=$PWD
X=$TOP/bin
T=HiPSRef
H=$TOP/Tests/hips
PY=${PY:-$HOME/miniforge/envs/hpxtest/bin/python}
FERMI=$TOP/hips/data1/ancillary/missions/Fermi_Band4/HiPS
ABELL=$TOP/hips/Abell1763_irac1
W=$(mktemp -d "${TMPDIR:-/tmp}/hipsref.XXXXXX")
pass=0; fail=0
ok()  { pass=$((pass+1)); echo "  ok   $*"; }
bad() { fail=$((fail+1)); echo "  FAIL $*"; }
nap() { perl -e 'select(undef,undef,undef,0.3)'; }
kw() { $X/xpaget $T fits header keyword $1; }
# agree <label> <ref map> <min % same value> <min % same NaN mask>
agree() {
    rm -f $W/d.fits; $X/xpaset -p $T save fits $W/d.fits
    read same mask n <<< "$("$PY" -I $H/refcmp.py $W/d.fits $2)"
    if [ -n "$n" ] && awk "BEGIN{exit !($same >= $3 && $mask >= $4)}"; then
	ok "$1: $same% same, $mask% same NaNs ($n px)"
    else
	bad "$1: $same% same (want >= $3), $mask% same NaNs (want >= $4), $n px"
    fi
}

"$PY" -I $H/mksynth.py $W >/dev/null
for k in 0 1 2 3; do "$PY" -I $H/mkref.py $FERMI $k $W/fermi$k.fits >/dev/null; done
for k in 1 2 3; do "$PY" -I $H/mkref.py $ABELL $k $W/abell$k.fits >/dev/null; done
for t in u8 f64; do "$PY" -I $H/mkref.py $W/synth_$t 1 $W/synth_$t.fits >/dev/null; done

rm -rf ~/$T.auto ~/$T.auto.dir ~/.$T
PATH="$X:$PATH" $X/ds9 -title $T >/dev/null 2>&1 &
for i in $(seq 1 40); do [ "$($X/xpaaccess -n $T)" -ge 1 ] && break; nap; done

echo "1. zenithal and conic windows (galactic Fermi map)"
$X/xpaset -p $T hips "${FERMI}[order=2,proj=tan,lon0=30,lat0=20,fov=40]"
agree "TAN, order 2" $W/fermi2.fits 99.9 99.9
$X/xpaset -p $T hips "${FERMI}[order=2,proj=sin,lon0=200,lat0=-60,fov=80]"
agree "SIN near the south pole" $W/fermi2.fits 99.9 99.9
$X/xpaset -p $T hips "${FERMI}[order=3,proj=zea,lon0=0,lat0=0,fov=30]"
agree "ZEA across the centre, order 3" $W/fermi3.fits 99.9 99.9
$X/xpaset -p $T hips "${FERMI}[order=1,proj=arc,lon0=0,lat0=90,fov=100]"
agree "ARC at the pole, order 1" $W/fermi1.fits 99.9 99.9
$X/xpaset -p $T hips "${FERMI}[order=2,proj=coe,lon0=120,lat0=45,fov=60]"
agree "COE" $W/fermi2.fits 99.9 99.9

echo "2. all-sky projections"
$X/xpaset -p $T hips "${FERMI}[order=1,proj=mol]"
agree "MOL, order 1" $W/fermi1.fits 99.9 99.9
$X/xpaset -p $T hips "${FERMI}[order=2,proj=ait,lon0=180]"
agree "AIT, lon0 180" $W/fermi2.fits 99.9 99.9
$X/xpaset -p $T hips "${FERMI}[order=1,proj=car]"
agree "CAR" $W/fermi1.fits 99.9 99.9

echo "3. an equatorial HiPS with partial coverage (Abell 1763)"
$X/xpaset -p $T hips "${ABELL}[order=2,proj=tan]"
agree "TAN at its initial view, order 2" $W/abell2.fits 99.9 99.9
$X/xpaset -p $T hips "${ABELL}[order=3,proj=tan]"
agree "  order 3" $W/abell3.fits 99.9 99.9

echo "4. integer and double tiles"
$X/xpaset -p $T hips "$W/synth_u8[order=1,proj=tan,lon0=100,lat0=10,fov=60]"
agree "BITPIX 8 (BLANK, BSCALE, BZERO)" $W/synth_u8.fits 99.9 99.9
$X/xpaset -p $T hips "$W/synth_f64[order=1,proj=mol]"
agree "BITPIX -64 (NaN), MOL" $W/synth_f64.fits 99.9 99.9

echo "5. deep windows: zoomed in past the loaded map"
$X/xpaset -p $T hips "${FERMI}[order=1,proj=tan,lon0=30,lat0=20,fov=20]"
$X/xpaset -p $T zoom to 4
k=$(kw HIPSORD)
if [ "$k" -gt 1 ] 2>/dev/null; then ok "deep: order $k"; else bad "deep: HIPSORD '$k'"; fi
agree "  the deep window, against order $k" $W/fermi$k.fits 99.9 99.9
# (orders past 3 would need a reference map at nside 8192 and more)
$X/xpaset -p $T hips "${ABELL}[order=1,proj=tan]"
$X/xpaset -p $T zoom to 4
k=$(kw HIPSORD)
if [ "$k" = 3 ]; then ok "Abell deep: order 3"; else bad "Abell deep: HIPSORD '$k', want 3"; fi
agree "  against order 3" $W/abell3.fits 99.9 99.9

$X/xpaset -p $T exit
for i in $(seq 1 20); do [ "$($X/xpaaccess -n $T)" = 0 ] && break; nap; done
rm -rf "$W" ~/.$T
echo "PASSED $pass, FAILED $fail"
[ $fail = 0 ]
