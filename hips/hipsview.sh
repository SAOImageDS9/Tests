#!/bin/bash
# HiPS Phase 2 checks: defaults from properties.
#  - hips_initial_ra/dec/fov centre a zenithal window that has no
#    lon0/lat0 (fov: no fov=), rotated from ICRS into hips_frame
#    (FitsHiPS::initialView, and HiPSInitialView in the dialog), both
#    checked against astropy; not for all-sky projections or when
#    lon0= or lat0= is given
#  - hips_pixel_cut becomes the user scale limits (pref phpxopen(hipscut))
#  - the Open HiPS dialog shows the initial view and writes lon0/lat0/fov
#    only when they differ from it
# Run from the top of the ds9 tree: Tests/hips/hipsview.sh
# Starts and stops its own ds9 (title HiPSView).

TOP=$PWD
X=$TOP/bin
T=HiPSView
PY=${PY:-$HOME/miniforge/envs/hpxtest/bin/python}
FERMI=$TOP/hips/data1/ancillary/missions/Fermi_Band4/HiPS
ABELL=$TOP/hips/Abell1763_irac1
W=$(mktemp -d "${TMPDIR:-/tmp}/hipsview.XXXXXX")
pass=0; fail=0
ok()  { pass=$((pass+1)); echo "  ok   $*"; }
bad() { fail=$((fail+1)); echo "  FAIL $*"; }
check() { if [ "$2" = "$3" ]; then ok "$1: $2"; else bad "$1: got '$2', want '$3'"; fi; }
# near <name> <got "a b"> <want "a b"> <tol>: each pair of numbers within tol
near() {
    if [ -n "$2" ] && "$PY" -I -c "import sys; g=[float(x) for x in sys.argv[1].split()]; w=[float(x) for x in sys.argv[2].split()]; t=float(sys.argv[3]); sys.exit(0 if len(g)==len(w) and all(min(abs(a-b),abs(abs(a-b)-360))<=t for a,b in zip(g,w)) else 1)" "$2" "$3" "$4"
    then ok "$1: $2"; else bad "$1: got '$2', want '$3' (to $4)"; fi
}
tcl() { rm -f $W/q; echo 'set f [open '$W'/q w]; puts $f ['"$1"']; close $f' | $X/xpaset $T tcl; cat $W/q 2>/dev/null; }
size() { tcl '$current(frame) get fits size'; }
nap() { perl -e 'select(undef,undef,undef,0.3)'; }
# the sky position at the image centre, in the survey's frame
pan() { $X/xpaget $T pan wcs $1 degrees; }

# astropy: ICRS -> frame
sky() { "$PY" -I -c "
import sys
from astropy.coordinates import SkyCoord, BarycentricMeanEcliptic
import astropy.units as u
c = SkyCoord(float(sys.argv[1])*u.deg, float(sys.argv[2])*u.deg, frame='icrs')
f = sys.argv[3]
if f == 'galactic': c = c.galactic; print(f'{c.l.deg:.6f} {c.b.deg:.6f}')
elif f == 'ecliptic': c = c.transform_to(BarycentricMeanEcliptic(equinox='J2000')); print(f'{c.lon.deg:.6f} {c.lat.deg:.6f}')
else: print(f'{c.ra.deg:.6f} {c.dec.deg:.6f}')
" "$@"; }

# an ecliptic copy of Fermi (same tiles; only the properties differ)
mkdir -p $W/ecl
for f in $FERMI/Norder*; do ln -s $f $W/ecl/; done
sed 's/^hips_frame .*/hips_frame = ecliptic/' $FERMI/properties > $W/ecl/properties
# an equatorial copy without a pixel cut
mkdir -p $W/equ
for f in $FERMI/Norder*; do ln -s $f $W/equ/; done
grep -v '^hips_pixel_cut\|^hips_frame' $FERMI/properties > $W/equ/properties
echo "hips_frame = equatorial" >> $W/equ/properties

rm -rf ~/$T.auto ~/$T.auto.dir ~/.$T
PATH="$X:$PATH" $X/ds9 -title $T >/dev/null 2>&1 &
for i in $(seq 1 40); do [ "$($X/xpaaccess -n $T)" -ge 1 ] && break; nap; done
cat <<EOF | $X/xpaset $T tcl
set ::errs {}
proc Error {m} {lappend ::errs \$m}
EOF

echo "1. ICRS -> hips_frame, reader and dialog, against astropy"
# the reader's window centre is checked by the sky position at the
# image centre (pan), to about a map pixel (order 3: 0.11 deg)
for c in "Fermi:$FERMI:galactic:270.0:-25.0:0.15:3" "Abell:$ABELL:galactic:203.95:41.15:0.05:2" \
         "ecliptic copy:$W/ecl:ecliptic:270.0:-25.0:0.15:3" "equatorial copy:$W/equ:fk5:270.0:-25.0:0.15:3"; do
    IFS=: read name dir frame ra dec tol order <<< "$c"
    want=$(sky $ra $dec $frame)
    $X/xpaset -p $T hips "${dir}[norder=$order,proj=TAN]"
    near "$name: window centre (pan $frame)" "$(pan $frame)" "$want" $tol
    near "$name: dialog's centre" "$(tcl "set v [HiPSInitialView [HiPSReadProperties {$dir}]]; list [dict get \$v lon] [dict get \$v lat]")" "$want" 1e-5
done

echo "2. when the initial view applies"
$X/xpaset -p $T hips "${FERMI}[norder=3,proj=ZEA]"
near "ZEA: centred too" "$(pan galactic)" "$(sky 270 -25 galactic)" 0.15
$X/xpaset -p $T hips "${FERMI}[norder=3,proj=MOL]"
near "MOL (all-sky): centre 0 0, not the initial view" "$(pan galactic)" "0 0" 0.15
$X/xpaset -p $T hips "${FERMI}[norder=3,proj=TAN,lon0=0]"
near "lon0=0 given: centre 0 0" "$(pan galactic)" "0 0" 0.15
$X/xpaset -p $T hips "${FERMI}[norder=3,proj=TAN,lat0=10]"
near "lat0=10 given: centre 0 10" "$(pan galactic)" "0 10" 0.15
# fov: from properties unless given, clamped to the projection
$X/xpaset -p $T hips "${FERMI}[norder=2,proj=TAN,lon0=10,lat0=10]"
a=$(size)
$X/xpaset -p $T hips "${FERMI}[norder=2,proj=TAN,lon0=10,lat0=10,fov=58.6323014283504]"
check "fov from hips_initial_fov when centre given" "$a" "$(size)"
sed 's/^hips_initial_fov .*/hips_initial_fov = 360.5/' $FERMI/properties > $W/fov.props
mkdir -p $W/wide; for f in $FERMI/Norder*; do ln -s $f $W/wide/; done; cp $W/fov.props $W/wide/properties
$X/xpaset -p $T hips "${W}/wide[norder=2,proj=TAN]"
a=$(size)
$X/xpaset -p $T hips "${W}/wide[norder=2,proj=TAN,fov=170]"
check "fov 360.5 clamped to TAN's 170" "$a" "$(size)"
$X/xpaset -p $T hips "${W}/wide[norder=2,proj=ZEA]"
a=$(size)
$X/xpaset -p $T hips "${W}/wide[norder=2,proj=ZEA,fov=360]"
check "fov 360.5 clamped to ZEA's 360" "$a" "$(size)"

echo "3. hips_pixel_cut"
$X/xpaset -p $T scale mode minmax
$X/xpaset -p $T hips "${FERMI}[norder=1]"
check "scale mode user" "$($X/xpaget $T scale mode)" "user"
check "limits from hips_pixel_cut" "$($X/xpaget $T scale limits)" "2e-09 8e-07"
$X/xpaset -p $T scale mode minmax
$X/xpaset -p $T hips "${W}/equ[norder=1]"
check "no hips_pixel_cut: scale untouched" "$($X/xpaget $T scale mode)" "minmax"
tcl 'set phpxopen(hipscut) 0' >/dev/null
$X/xpaset -p $T hips "${FERMI}[norder=1]"
check "pref off: scale untouched" "$($X/xpaget $T scale mode)" "minmax"
tcl 'set phpxopen(hipscut) 1' >/dev/null
$X/xpaset -p $T exit
for i in $(seq 1 20); do [ "$($X/xpaaccess -n $T)" = 0 ] && break; nap; done
rm -rf ~/$T.auto ~/$T.auto.dir
PATH="$X:$PATH" $X/ds9 -title $T -hips "${FERMI}[norder=1]" -scale limits 1e-8 1e-7 >/dev/null 2>&1 &
for i in $(seq 1 40); do [ "$($X/xpaaccess -n $T)" -ge 1 ] && break; nap; done
for i in $(seq 1 40); do [ "$(size)" != "0 0" ] && break; nap; done
nap; nap
check "-scale limits after -hips wins" "$($X/xpaget $T scale limits)" "1e-08 1e-07"
cat <<EOF | $X/xpaset $T tcl
set ::errs {}
proc Error {m} {lappend ::errs \$m}
EOF

echo "4. the dialog"
dialog() {
    tcl "after idle {set ::res [HiPSOpenParamsDialog {$1}]; set ::done 1}; set ::done 0" >/dev/null
    for i in $(seq 1 20); do [ "$(tcl 'winfo exists .hipsopen')" = 1 ] && break; nap; done
    [ -n "$2" ] && tcl "$2" >/dev/null
    tcl "$3" >/dev/null
    for i in $(seq 1 20); do [ "$(tcl 'set ::done')" = 1 ] && break; nap; done
    tcl 'set ::res'
}
tcl 'set hipsopen(proj) tan' >/dev/null
dialog "$FERMI" 'set ::fv [list $hpxed(lon0) $hpxed(lat0) $hpxed(fov)]; set ::v [.hipsopen.file.view cget -text]; set ::c [.hipsopen.file.cut cget -text]' 'set hpxed(ok) 0' >/dev/null
near "TAN starts at the initial view" "$(tcl 'set ::fv')" "$(sky 270 -25 galactic) 58.632301" 1e-5
check "initial view shown" "$(tcl 'set ::v')" "Initial view: RA 270.0 Dec -25.0 (ICRS), fov 58.632301"
check "suggested limits shown" "$(tcl 'set ::c')" "Suggested scale limits: 2.0E-9 8.0E-7"
check "untouched: just proj=tan" "$(dialog "$FERMI" "" HiPSOpenOK)" "${FERMI}[proj=tan]"
check "lat0 changed: lon0 and lat0 written" \
    "$(dialog "$FERMI" 'set hpxed(lat0) 0' HiPSOpenOK)" \
    "${FERMI}[proj=tan,lon0=$(tcl 'HiPSOpenFmt [dict get [HiPSInitialView [HiPSReadProperties {'$FERMI'}]] lon]'),lat0=0]"
check "fov 90 (TAN's own default) written" "$(dialog "$FERMI" 'set hpxed(fov) 90' HiPSOpenOK)" "${FERMI}[proj=tan,fov=90]"
check "centre 0 0 written" "$(dialog "$FERMI" 'set hpxed(lon0) 0; set hpxed(lat0) 0' HiPSOpenOK)" "${FERMI}[proj=tan,lon0=0,lat0=0]"
dialog "$FERMI" 'set hpxed(lon0) 5; set hpxed(proj) zea; HiPSOpenProjChanged; set ::a $hpxed(lon0); set hpxed(proj) mol; HiPSOpenProjChanged; set ::b $hpxed(lon0); set hpxed(proj) tan; HiPSOpenProjChanged; set ::c [list $hpxed(lon0) $hpxed(fov)]' 'set hpxed(ok) 0' >/dev/null
check "TAN -> ZEA keeps the centre" "$(tcl 'set ::a')" "5"
check "-> MOL keeps lon0" "$(tcl 'set ::b')" "5"
near "-> TAN again: back to the initial view" "$(tcl 'set ::c')" "$(sky 270 -25 galactic | cut -d' ' -f1) 58.632301" 1e-5
dialog "$W/wide" 'set hpxed(proj) zea; HiPSOpenProjChanged; set hpxed(proj) tan; HiPSOpenProjChanged; set ::fv $hpxed(fov)' 'set hpxed(ok) 0' >/dev/null
check "ZEA 360 -> TAN: fov clamped to 170" "$(tcl 'set ::fv')" "170"
check "untouched clamped fov: not written" "$(dialog "$W/wide" "" HiPSOpenOK)" "$W/wide[proj=tan]"
tcl 'set hipsopen(proj) mol' >/dev/null
check "MOL: as the HEALPix dialog" "$(dialog "$FERMI" 'set hpxed(lon0) 180' HiPSOpenOK)" "${FERMI}[proj=mol,lon0=180]"
tcl "set hipsopen(proj) tan" >/dev/null
check "no initial view (equatorial copy has one): name" "$(dialog "$W/equ" "" HiPSOpenOK)" "$W/equ[proj=tan]"
check "no errors" "$(tcl 'set ::errs')" ""

$X/xpaset -p $T exit
rm -rf "$W" ~/.$T
echo "PASSED $pass, FAILED $fail"
[ $fail = 0 ]
