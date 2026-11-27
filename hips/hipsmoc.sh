#!/bin/bash
# HiPS Phase 2 checks: the coverage overlay (hips coverage, Analysis >
# HiPS Coverage) and mocorder=K on MOC files.
# Run from the top of the ds9 tree: Tests/hips/hipsmoc.sh
# Starts and stops its own ds9s (title HiPSMoc).

T=HiPSMoc
. Tests/hips/lib.sh
ERRS=1
FERMI=$TOP/Tests/hipsdata/data1/ancillary/missions/Fermi_Band4/HiPS
ABELL=$TOP/Tests/hipsdata/Abell1763_irac1
aux() { tcl '$current(frame) get contour aux count'; }
menu() { tcl '$ds9(mb).analysis entrycget {HiPS Coverage} -state'; }
# outline <file> <frame>: save the aux contours, in the MOC's frame
outline() { tcl "\$current(frame) contour save aux {$1} wcs $2" >/dev/null; }

rm -rf ~/.$T
start

echo "1. mocorder=K on a MOC file"
$X/xpaset -p $T fits "$ABELL/Moc.fits"
check "Abell MOC as is (MOCORDER 7: nside 128)" "$(size)" "640 640"
$X/xpaset -p $T fits "$ABELL/Moc.fits[mocorder=5]"
check "mocorder=5: coarser (nside 32)" "$(size)" "160 160"
$X/xpaset -p $T fits "$ABELL/Moc.fits[mocorder=9]"
check "mocorder=9: finer (nside 512)" "$(size)" "2560 2560"
# coverage area is kept when refining, grows (or stays) when coarsening
area() { rm -f $W/a.fits; $X/xpaset -p $T save fits $W/a.fits; "$PY" -I -c "import sys,numpy as np; from astropy.io import fits; print(int((fits.getdata(sys.argv[1])==1).sum()))" $W/a.fits; }
$X/xpaset -p $T fits "$ABELL/Moc.fits"; a7=$(area)
$X/xpaset -p $T fits "$ABELL/Moc.fits[mocorder=9]"; a9=$(area)
check "mocorder=9 covers the same cells (16 pixels per order-7 pixel)" "$a9" "$((a7*16))"
$X/xpaset -p $T fits "$ABELL/Moc.fits[mocorder=5]"; a5=$(area)
if [ "$((a5*16))" -ge "$a7" ]; then ok "mocorder=5 covers at least as much ($a5*16 >= $a7)"; else bad "mocorder=5 lost coverage: $a5*16 < $a7"; fi

echo "2. the overlay"
$X/xpaset -p $T hips "${ABELL}[norder=2,proj=TAN,fov=5]"
check "off at first" "$($X/xpaget $T hips coverage)" "no"
$X/xpaset -p $T hips coverage
check "on" "$($X/xpaget $T hips coverage)" "yes"
check "one aux contour" "$(aux)" "1"
check "still one frame" "$($X/xpaget $T frame all | tr -d ' ')" "1"
check "current frame unchanged" "$($X/xpaget $T frame)" "1"
outline $W/abell.ctr galactic
r=$("$PY" -I $H/mocref.py "$ABELL/Moc.fits" $W/abell.ctr 0.12); rc=$?
if [ $rc = 0 ]; then ok "Abell outline follows the MOC (galactic): $r"; else bad "Abell outline: $r"; fi
$X/xpaset -p $T hips coverage yes
check "yes again: still one" "$(aux)" "1"
$X/xpaset -p $T hips coverage no
check "off" "$($X/xpaget $T hips coverage)" "no"
check "no aux contours" "$(aux)" "0"

echo "3. the user's own aux contours are left alone"
cat > $W/user.ctr <<EOF
# Contour file format: DS9 version 7.5
global color=red width=2 dash=no dashlist=8 3
galactic
level=1
(
 92.5 73.0
 93.0 73.5
 92.0 73.5
 92.5 73.0
)
EOF
tcl "\$current(frame) contour load {$W/user.ctr}" >/dev/null
check "user's aux contour" "$(aux)" "1"
$X/xpaset -p $T hips coverage yes
check "plus coverage" "$(aux)" "2"
$X/xpaset -p $T hips coverage no
check "coverage off: the user's stays" "$(aux)" "1"
outline $W/left.ctr galactic
check "  and it is the user's (4 vertices)" "$(grep -c '^ *[0-9]' $W/left.ctr)" "4"
tcl '$current(frame) contour delete aux' >/dev/null

echo "4. a full-sky MOC; an equatorial MOC on a galactic survey"
$X/xpaset -p $T hips "${FERMI}[norder=2,proj=MOL]"
check "Fermi (moc_sky_fraction 1): menu disabled" "$(menu)" "disabled"
$X/xpaset -p $T hips coverage
check "Fermi (full-sky MOC): on" "$($X/xpaget $T hips coverage)" "yes"
check "  no edge, nothing drawn" "$(aux)" "0"
check "  menu enabled while on, to turn it off" "$(menu)" "normal"
$X/xpaset -p $T hips coverage no
check "  off" "$($X/xpaget $T hips coverage)" "no"
check "  menu disabled again" "$(menu)" "disabled"
tcl "\$current(frame) contour load {$W/user.ctr}" >/dev/null
$X/xpaset -p $T hips coverage yes
$X/xpaset -p $T hips coverage no
check "  on/off leaves another aux contour" "$(aux)" "1"

# an equatorial MOC (XRISM's, 221 cells) with galactic tiles (Fermi's)
mkdir -p $W/xmoc; for f in $FERMI/Norder* $FERMI/properties; do ln -s $f $W/xmoc/; done
ln -s $TOP/Tests/hipsdata/XRISM_RESOLVE/Moc.fits $W/xmoc/Moc.fits
$X/xpaset -p $T hips "$W/xmoc[norder=3,proj=MOL]"
tcl '$current(frame) contour delete aux' >/dev/null
$X/xpaset -p $T hips coverage
check "equatorial MOC on a galactic MOL: on" "$($X/xpaget $T hips coverage)/$(aux)" "yes/1"
outline $W/xrism.ctr fk5
r=$("$PY" -I $H/mocref.py "$TOP/Tests/hipsdata/XRISM_RESOLVE/Moc.fits" $W/xrism.ctr 0.12); rc=$?
if [ $rc = 0 ]; then ok "  outline follows the MOC (fk5): $r"; else bad "  outline: $r"; fi
$X/xpaset -p $T zoom to fit
$X/xpaset -p $T saveimage png $W/xrism.png
cp $W/xrism.png ${SHOT:-/dev/null} 2>/dev/null

echo "5. errors and state"
$X/xpaset -p $T frame new
tcl 'set ::errs {}' >/dev/null
$X/xpaset -p $T hips coverage
r=$(tcl 'lindex $::errs 0')
case "$r" in *"does not hold a HiPS"*) ok "empty frame: $r";; *) bad "empty frame: '$r'";; esac
check "  xpaget: no" "$($X/xpaget $T hips coverage)" "no"
mkdir -p $W/nomoc; for f in $FERMI/Norder* $FERMI/properties; do ln -s $f $W/nomoc/; done
$X/xpaset -p $T hips "$W/nomoc[norder=1]"
tcl 'set ::errs {}' >/dev/null
$X/xpaset -p $T hips coverage
r=$(tcl 'lindex $::errs 0')
case "$r" in *"no MOC"*) ok "no Moc.fits: $(echo "$r" | head -c 50)...";; *) bad "no Moc.fits: '$r'";; esac
tcl 'set ::errs {}' >/dev/null
check "menu: disabled for a HiPS without Moc.fits" "$(tcl '$ds9(mb).analysis entrycget {HiPS Coverage} -state')" "disabled"
check "frame numbering untouched (next new frame)" "$($X/xpaset -p $T frame new; $X/xpaget $T frame)" "3"
$X/xpaset -p $T frame delete
$X/xpaset -p $T frame 1
check "menu: enabled on a HiPS frame" "$(tcl '$ds9(mb).analysis entrycget {HiPS Coverage} -state')" "normal"
$X/xpaset -p $T frame 2
$X/xpaset -p $T frame clear
check "menu: disabled on an empty frame" "$(tcl '$ds9(mb).analysis entrycget {HiPS Coverage} -state')" "disabled"
$X/xpaset -p $T frame 1
$X/xpaset -p $T hips "${ABELL}[norder=2,proj=TAN,fov=5]"
tcl 'set hipscov(view) 1; HiPSCoverageMenu' >/dev/null
check "menu turns it on" "$($X/xpaget $T hips coverage)" "yes"
check "  checkbutton follows" "$(tcl 'set hipscov(view)')" "1"
$X/xpaset -p $T hips "${ABELL}[norder=1,proj=TAN,fov=5]"
check "a new load clears it" "$($X/xpaget $T hips coverage)/$(aux)" "no/0"

echo "6. backup/restore"
$X/xpaset -p $T frame delete all
$X/xpaset -p $T frame new
$X/xpaset -p $T hips "${ABELL}[norder=2,proj=TAN,fov=5]"
$X/xpaset -p $T hips coverage yes
outline $W/before.ctr galactic
$X/xpaset -p $T backup $W/b.bck
stop
start
$X/xpaset -p $T restore $W/b.bck
check "restored: coverage on" "$($X/xpaget $T hips coverage)" "yes"
check "  one aux contour" "$(aux)" "1"
outline $W/after.ctr galactic
check "  same outline (to 1e-6 deg)" "$("$PY" -I -c "
import sys, numpy as np
r = lambda f: np.array([[float(v) for v in l.split()] for l in open(f) if len(l.split())==2 and l.split()[0][0] in '-0123456789'])
a, b = r(sys.argv[1]), r(sys.argv[2])
d = np.abs(a-b).max(axis=1) if a.shape == b.shape else np.array([1e9]); i = int(d.argmax())
print('same' if d.max() < 1e-6 else f'differ {a.shape} {b.shape} max {d.max():.3g} at {i}: {a[i] if a.shape==b.shape else 0} {b[i] if a.shape==b.shape else 0}')" $W/before.ctr $W/after.ctr)" "same"
$X/xpaset -p $T hips coverage no
check "  and it can be turned off" "$(aux)" "0"
check "no unexpected errors" "$(tcl 'set ::errs')" ""
stop

echo "7. command line"
start -hips "${ABELL}[norder=2,proj=TAN,fov=5]" -hips coverage -zoom 2
for i in $(seq 1 40); do [ "$(size)" != "0 0" ] && break; nap; done
for i in $(seq 1 20); do [ "$($X/xpaget $T hips coverage)" = yes ] && break; nap; done
check "-hips <dir> -hips coverage" "$($X/xpaget $T hips coverage)/$(aux)" "yes/1"
check "  the HiPS is loaded" "$($X/xpaget $T hips)" "${ABELL}[norder=2,proj=TAN,fov=5]"
# -zoom 2 makes the HiPS window go deep (order 3), and the rebuild puts
# the zoom back to 1 (it keeps the on-screen scale). ds9 answers XPA
# while it is still working through its command line: wait for it
for i in $(seq 1 40); do [ "$(kw HIPSORD)" = 3 ] && break; nap; done
rm -f $W/z.fits; $X/xpaset -p $T save fits $W/z.fits
check "  and the next option still parsed (zoom 2: order 3 tiles)" "$(${PY:-$HOME/miniforge/envs/hpxtest/bin/python} -I -c "
from astropy.io import fits
print(sum('HiPS order 3' in str(c) for c in fits.getheader('$W/z.fits').get('HISTORY', [])))")" "1"
stop

[ -n "$KEEP" ] && cp -R $W/b.bck $W/b.bck.dir $W/before.ctr $W/after.ctr "$KEEP"/
finish
