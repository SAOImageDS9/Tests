#!/bin/bash
# HiPS tiles are often unpadded FITS. Checks that fitsy loads unpadded
# and truncated files with every load method, and that asking for a
# missing extension of a short file fails cleanly instead of crashing
# (the fitsy map.C/mapincr.C size_t underflow fixed 2026-11-15).
#
# Run from the top of the ds9 tree:
#   Tests/hips/hipspad.sh
# Needs the hpxtest conda env (PY). Starts its own ds9 (title HiPSPad*),
# restarting it if a load kills it.

# a new title each start (a crash leaves the old one's files); the
# work directory is kept when a check fails
T=HiPSPad
KEEPFAIL=1
. Tests/hips/lib.sh
TILE=$TOP/Tests/hipsdata/data1/ancillary/missions/Fermi_Band4/HiPS/Norder3/Dir0/Npix0.fits

# --- test files ---
mkdir -p $W/pad $W/out
"$PY" -I $H/mkpad.py $W/pad $TILE $(getconf PAGESIZE) >/dev/null
"$PY" -I $H/mkext.py $W/pad >/dev/null
# a file missing data bytes, not just its padding
head -c $((2880+1048576-40000)) $W/pad/f512_nopad.fits > $W/pad/trunc.fits

start() {
  T=HiPSPad$$_$RANDOM; rm -rf ~/$T.auto ~/$T.auto.dir
  PATH="$X:$PATH" $X/ds9 -title $T >/dev/null 2>&1 & pid=$!; DS9PID=$pid
  for i in $(seq 1 40); do [ "$($X/xpaaccess -n $T)" -ge 1 ] && break; nap; done
  echo "source $H/padtest.tcl" | $X/xpaset $T tcl
}
alive() { kill -0 $pid 2>/dev/null; }
died() { wait $pid 2>/dev/null; rm -rf ~/$T.auto ~/$T.auto.dir; start; }

start
echo "primary images: every file x every load method, saved and compared"
LOG=$W/padtest.log
for f in fermi_pad fermi_nopad i16_pad i16_nopad f512_pad f512_nopad page_pad page_nopad; do
  for m in mmapincr mmap alloc allocgz channel var; do
    echo "padtest {$W/pad/$f.fits} $m {$W/out/${f}_$m.fits} {$LOG}" | $X/xpaset $T tcl >/dev/null 2>&1
    if ! alive; then bad "$f $m: ds9 died"; died; continue; fi
    l=$(grep "^$f.fits $m " $LOG | tail -1)
    case "$l" in *"rc=0 has=1 "*) ok "$f $m";; *) bad "$f $m: $l";; esac
  done
done
r=$("$PY" -I $H/padcmp.py $W | grep "images compared")
case "$r" in "48 saved images compared, 0 mismatches") ok "$r";; *) bad "$r";; esac

echo "extensions and truncated files: load, read every pixel, render"
# one <spec> <method> <want has> [mosaic]
one() {
  local spec=$1 m=$2 want=$3 pre="" cmd
  [ "$4" = mosaic ] && pre="mosaic wcs"
  case $m in
    # alloc parses the name, [ext] and all, from its last argument
    alloc) cmd="\$current(frame) load fits $pre {$W/pad/$spec} $m {$W/pad/$spec}";;
    *) cmd="\$current(frame) load fits $pre {$W/pad/$spec} $m";;
  esac
  rm -f $W/res.txt
  echo "\$current(frame) clear" | $X/xpaset $T tcl >/dev/null 2>&1
  echo "$cmd" | $X/xpaset $T tcl >/dev/null 2>&1
  # the clip scan reads every pixel, so a bad mapping faults now
  echo "set f [open $W/res.txt w]; puts \$f \"[\$current(frame) has fits] [\$current(frame) get clip]\"; close \$f" | $X/xpaset $T tcl >/dev/null 2>&1
  $X/xpaset -p $T saveimage png $W/res.png >/dev/null 2>&1
  nap
  if ! alive; then bad "$spec $m $4: ds9 died"; died; return; fi
  local has=$(cut -d' ' -f1 $W/res.txt 2>/dev/null)
  if [ "$has" = "$want" ]; then ok "$spec $m $4: has fits $has"
  else bad "$spec $m $4: has fits '$has', want $want"; fi
}
for m in mmapincr mmap alloc; do
  # former crashes: must fail cleanly
  for s in 'page_nopad.fits[1]' 'page_nopad.fits[FOO]' 'fermi_nopad.fits[1]' trunc.fits; do one "$s" $m 0; done
  # controls
  for s in page_nopad.fits fermi_nopad.fits f512_nopad.fits; do one "$s" $m 1; done
  # real extensions, padded and with an unpadded last HDU
  for f in mext_pad mext_nopad; do
    for e in '' '[1]' '[2]' '[A]' '[B]'; do one "$f.fits$e" $m 1; done
    for e in '[3]' '[C]'; do one "$f.fits$e" $m 0; done
    one "$f.fits" $m 1 mosaic
  done
done

$X/xpaset -p $T exit
for i in $(seq 1 40); do alive || break; nap; done
finish
