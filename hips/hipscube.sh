#!/bin/bash
# HiPS Phase 4 checks: cubes. The reader builds one frame at a time
# (slice=, default hips_cube_firstframe); ds9's Cube dialog and the cube
# command drive it through CubeFrame / HiPSCubeAnswer (hips.tcl), and a
# new slice reloads the HiPS there keeping the view.
# Run from the top of the ds9 tree: Tests/hips/hipscube.sh
# Starts and stops its own ds9s (title HiPSCube) and a local HTTP server.

TOP=$PWD
X=$TOP/bin
T=HiPSCube
H=$TOP/Tests/hips
PY=${PY:-$HOME/miniforge/envs/hpxtest/bin/python}
LAB=$TOP/hips/LABHI_cube
W=$(mktemp -d "${TMPDIR:-/tmp}/hipscube.XXXXXX")
pass=0; fail=0
ok()  { pass=$((pass+1)); echo "  ok   $*"; }
bad() { fail=$((fail+1)); echo "  FAIL $*"; }
check() { if [ "$2" = "$3" ]; then ok "$1: $2"; else bad "$1: got '$2', want '$3'"; fi; }
tcl() { rm -f $W/q; echo 'set f [open '$W'/q w]; puts $f ['"$1"']; close $f' | $X/xpaset $T tcl; cat $W/q 2>/dev/null; }
nap() { perl -e 'select(undef,undef,undef,0.3)'; }
kw() { $X/xpaget $T fits header keyword $1; }
shot() { rm -f $W/$1.fits; $X/xpaset -p $T save fits $W/$1.fits; }
# the frame and order the values come from (mkcube.py's encoding), at
# the image centre: "frame order"
code() { shot c; "$PY" -I -c "
import numpy as np; from astropy.io import fits
d = fits.getdata('$W/c.fits'); ny, nx = d.shape
v = d[ny//2-20:ny//2+20, nx//2-20:nx//2+20]; v = v[np.isfinite(v)]
v = int(np.median(np.floor(v)))
print(v // 1000, (v % 1000) // 100)"; }
start() {
    rm -rf ~/$T.auto ~/$T.auto.dir
    PATH="$X:$PATH" $X/ds9 -title $T "$@" >/dev/null 2>&1 &
    for i in $(seq 1 40); do [ "$($X/xpaaccess -n $T)" -ge 1 ] && break; nap; done
    echo 'set ::errs {}; proc Error {m} {lappend ::errs $m}' | $X/xpaset $T tcl
}
stop() {
    $X/xpaset -p $T exit
    for i in $(seq 1 20); do [ "$($X/xpaaccess -n $T)" = 0 ] && break; nap; done
}

"$PY" -I $H/mkcube.py $W >/dev/null
C=$W/cube
rm -rf ~/.$T
start

echo "1. load: the first frame, and the Cube dialog"
$X/xpaset -p $T hips "$C"
check "hips_cube_firstframe 2: slice 3" "$(kw HIPSSLIC)/$(kw HIPSDPTH)" "3/5"
check "  its values" "$(code)" "2 2"
check "  third-axis value (1000 + 2*250 m/s)" "$(kw HIPSZVAL)" "1500"
check "the Cube dialog opened" "$(tcl 'winfo exists $icube(top)')" "1"
check "  it sees 3 axes, 5 frames" "$(tcl 'CubeFrame $current(frame) get fits naxes')/$(tcl 'CubeFrame $current(frame) get fits depth 2')" "3/5"
check "xpaget cube (1-based)" "$($X/xpaget $T cube)" "3"

echo "2. moving through the cube"
$X/xpaset -p $T cube next
check "cube next: slice 4 (frame 3)" "$(kw HIPSSLIC)/$(code)" "4/3 2"
$X/xpaset -p $T cube prev
$X/xpaset -p $T cube prev
check "cube prev x2: slice 2 (frame 1)" "$(kw HIPSSLIC)/$(code)" "2/1 2"
$X/xpaset -p $T cube first
check "cube first: slice 1 (frame 0)" "$(kw HIPSSLIC)/$(code)" "1/0 2"
$X/xpaset -p $T cube last
check "cube last: slice 5 (frame 4)" "$(kw HIPSSLIC)/$(code)" "5/4 2"
$X/xpaset -p $T cube 2
check "cube 2: slice 2, as the Cube dialog counts" "$(kw HIPSSLIC)/$($X/xpaget $T cube)" "2/2"
$X/xpaset -p $T cube 1750 wcs
check "cube 1750 wcs (m/s): slice 4" "$(kw HIPSSLIC)" "4"
check "xpaget cube wcs" "$($X/xpaget $T cube wcs)" "1750"
check "xpaget hips names the slice (1-based)" "$($X/xpaget $T hips)" "$C[slice=4]"

echo "3. the view is kept"
$X/xpaset -p $T hips "$C[norder=0,proj=TAN,lon0=45,lat0=30,fov=40]"
$X/xpaset -p $T pan to 50 32 fk5
z0=$($X/xpaget $T zoom); p0=$($X/xpaget $T pan wcs fk5 degrees)
$X/xpaset -p $T cube next
check "zoom kept" "$($X/xpaget $T zoom)" "$z0"
p1=$($X/xpaget $T pan wcs fk5 degrees)
if "$PY" -I -c "import sys; a=[float(x) for x in '$p0'.split()]; b=[float(x) for x in '$p1'.split()]; sys.exit(0 if max(abs(a[0]-b[0]), abs(a[1]-b[1])) < 0.01 else 1)"; then ok "pan kept: $p1"; else bad "pan: $p0 -> $p1"; fi

echo "4. deep windows follow the cube"
$X/xpaset -p $T zoom to 4
check "deep: order 2 tiles of frame 3" "$(kw HIPSORD)/$(code)" "2/3 2"
$X/xpaset -p $T cube next
check "next frame, still deep: slice 5, order 2" "$(kw HIPSSLIC)/$(code)" "5/4 2"

echo "5. backup/restore keeps the slice"
$X/xpaset -p $T frame delete all
$X/xpaset -p $T hips "$C"
$X/xpaset -p $T cube 1
$X/xpaset -p $T backup $W/b.bck
stop
start
$X/xpaset -p $T restore $W/b.bck
check "restored at slice 1" "$(kw HIPSSLIC)/$(code)" "1/0 2"

echo "6. remote cubes fetch the frame's files"
mkdir -p $W/www; ln -s $C $W/www/cube
"$PY" -I $H/hipsserve.py $W/www $W/port $W/log &
SRV=$!
for i in $(seq 1 30); do [ -s $W/port ] && break; nap; done
U=http://127.0.0.1:$(cat $W/port)
$X/xpaset -p $T hips "$U/cube[norder=1]"
check "remote first frame" "$(kw HIPSSLIC)/$(code)" "3/2 1"
check "  fetched its _2 tiles" "$(grep -c '^200 /cube/Norder1/Dir0/Npix[0-9]*_2.fits' $W/log)" "48"
: > $W/log
$X/xpaset -p $T cube next
check "next: slice 4" "$(kw HIPSSLIC)/$(code)" "4/3 1"
check "  fetched its _3 tiles only (and asked for Allsky_3)" "$(grep -c 'Npix[0-9]*_3.fits' $W/log)/$(grep -c 'Npix' $W/log)/$(grep -c 'Allsky_3' $W/log)" "48/48/1"
kill $SRV; wait $SRV 2>/dev/null

echo "7. LAB HI (a real cube, PNG)"
$X/xpaset -p $T frame delete all
$X/xpaset -p $T hips "$LAB"
check "first frame 445 (~0 km/s): slice 446" "$(kw HIPSSLIC)" "446"
$X/xpaset -p $T cube 2
check "cube 2: slice 2" "$(kw HIPSSLIC)" "2"
shot lab1
$X/xpaset -p $T hips "$LAB[slice=2]"
shot lab1d
check "  same as loading slice=2" "$("$PY" -I -c "
import numpy as np; from astropy.io import fits
a, b = fits.getdata('$W/lab1.fits'), fits.getdata('$W/lab1d.fits')
print('same' if np.array_equal(a, b, equal_nan=True) else 'differ')")" "same"

echo "8. lock slice: HiPS cube frames, and with a FITS cube"
$X/xpaset -p $T frame delete all
# a FITS cube on a finer grid: 9 planes, 1000 m/s at plane 1, 125 m/s steps
"$PY" -I -c "
import numpy as np; from astropy.io import fits
d = np.arange(9, dtype=np.float32)[:, None, None] * np.ones((1, 8, 8), np.float32)
h = fits.PrimaryHDU(d).header
h.update(CTYPE1='RA---TAN', CTYPE2='DEC--TAN', CRVAL1=45., CRVAL2=30., CRPIX1=4.5,
         CRPIX2=4.5, CDELT1=-0.1, CDELT2=0.1, CTYPE3='VRAD', CUNIT3='m/s',
         CRVAL3=1000., CRPIX3=1., CDELT3=125.)
fits.PrimaryHDU(d, h).writeto('$W/fcube.fits', overwrite=True)"
$X/xpaset -p $T hips "$C"
$X/xpaset -p $T hips new "$C[proj=TAN,lon0=45,lat0=30,fov=40]"
$X/xpaset -p $T zoom to 4
$X/xpaset -p $T frame new
$X/xpaset -p $T fits $W/fcube.fits
slices() { s=""; for f in 1 2 3; do $X/xpaset -p $T frame $f; s="$s $($X/xpaget $T cube)"; done; echo $s; }
$X/xpaset -p $T frame 1
$X/xpaset -p $T lock slice image
check "lock slice image: all at image slice 3" "$(slices)" "3 3 3"
$X/xpaset -p $T frame 1
$X/xpaset -p $T cube next
check "  cube next in a HiPS frame: all follow" "$(slices)" "4 4 4"
$X/xpaset -p $T frame 2
check "  the deep window followed, still deep" "$(kw HIPSSLIC)/$(kw HIPSORD)/$(code)" "4/2/3 2"
$X/xpaset -p $T lock slice wcs
$X/xpaset -p $T frame 3
$X/xpaset -p $T cube 1750 wcs
check "lock slice wcs: FITS at 1750 m/s (plane 7), HiPS frames at frame 3" "$(slices)" "4 4 7"
$X/xpaset -p $T frame 3
check "  xpaget cube wcs on the FITS cube" "$($X/xpaget $T cube wcs)" "1750"
$X/xpaset -p $T frame 1
$X/xpaset -p $T cube 2000 wcs
check "  cube 2000 wcs in a HiPS frame: FITS at plane 9" "$(slices)" "5 5 9"
$X/xpaset -p $T frame 1
$X/xpaset -p $T cube first
check "  cube first: 1000 m/s everywhere" "$(slices)" "1 1 1"
$X/xpaset -p $T lock slice none
$X/xpaset -p $T frame 1
$X/xpaset -p $T cube next
check "lock slice none: only the current frame moves" "$(slices)" "2 1 1"
$X/xpaset -p $T frame 3
$X/xpaset -p $T cube 1500 wcs
$X/xpaset -p $T match slice wcs
check "match slice wcs from the FITS cube (1500 m/s)" "$(slices)" "3 3 5"
$X/xpaset -p $T frame 1
$X/xpaset -p $T cube play
sleep 3
$X/xpaset -p $T cube stop
p1=$($X/xpaget $T cube)
sleep 1
check "cube play moves through the HiPS frames, stop stops" "$( [ "$p1" != 3 ] && echo moved)/$($X/xpaget $T cube)" "moved/$p1"

echo "9. data_cube_bunit3 = null (as several CDS cubes have it): no unit"
mkdir -p $W/nullcube
sed 's/^data_cube_bunit3.*/data_cube_bunit3 = null/' $C/properties > $W/nullcube/properties
for d in $C/Norder*; do ln -s $d $W/nullcube/; done
$X/xpaset -p $T frame delete all
$X/xpaset -p $T hips "$W/nullcube"
check "  the Cube dialog's axis name" "$(tcl 'CubeFrame $current(frame) get fits header keyword CTYPE3')" "HiPS frame"
check "  HIPSZVAL's comment" "$($X/xpaget $T fits header | grep '^HIPSZVAL' | sed 's|.*/ *||; s| *$||')" "frame value"

echo "10. slice= counts from 1"
$X/xpaset -p $T frame delete all
$X/xpaset -p $T hips "$C[slice=1]"
check "slice=1: the first frame (no file suffix)" "$(kw HIPSSLIC)/$(code)/$($X/xpaget $T cube)" "1/0 2/1"
$X/xpaset -p $T hips "$C[slice=5]"
check "slice=5: the last" "$(kw HIPSSLIC)/$(code)/$($X/xpaget $T cube)" "5/4 2/5"
tcl 'set ::errs {}' >/dev/null
for s in 0 6; do
  $X/xpaset -p $T hips "$C[slice=$s]" 2>/dev/null
  case "$(tcl 'lindex $::errs end')" in *"slice $s is outside the cube (1-5)"*) ok "slice=$s refused";; *) bad "slice=$s: '$(tcl 'lindex $::errs end')'";; esac
done
tcl 'set ::errs {}' >/dev/null
$X/xpaset -p $T hips "$TOP/Tests/fits/hips[slice=1]"
check "slice=1 on an image HiPS: fine" "$(tcl 'set ::errs')/$($X/xpaget $T hips)" "/$TOP/Tests/fits/hips[slice=1]"
$X/xpaset -p $T hips "$TOP/Tests/fits/hips[slice=2]" 2>/dev/null
case "$(tcl 'lindex $::errs end')" in *"slice= needs a cube HiPS"*) ok "slice=2 on an image HiPS refused";; *) bad "slice=2 on an image: '$(tcl 'lindex $::errs end')'";; esac
tcl 'set ::errs {}' >/dev/null

check "no errors" "$(tcl 'set ::errs')" ""
stop
rm -rf "$W" ~/.$T
echo "PASSED $pass, FAILED $fail"
[ $fail = 0 ]
