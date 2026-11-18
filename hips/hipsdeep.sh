#!/bin/bash
# HiPS Phase 5 checks: deep windows. A HiPS in a zenithal/conic window
# zooms into its deeper tiles (FitsHPXReproj deep source); a remote
# HiPS's missing visible tiles are fetched in the background
# (HiPSDeepWant) and the window refreshed. Values are checked tile by
# tile against the HiPS on disk (Tests/hips/deepcheck.py).
# Run from the top of the ds9 tree: Tests/hips/hipsdeep.sh
# Starts and stops its own ds9 (title HiPSDeep) and a local HTTP server.

TOP=$PWD
X=$TOP/bin
T=HiPSDeep
H=$TOP/Tests/hips
PY=${PY:-$HOME/miniforge/envs/hpxtest/bin/python}
ABELL=$TOP/hips/Abell1763_irac1
W=$(mktemp -d "${TMPDIR:-/tmp}/hipsdeep.XXXXXX")
pass=0; fail=0
ok()  { pass=$((pass+1)); echo "  ok   $*"; }
bad() { fail=$((fail+1)); echo "  FAIL $*"; }
check() { if [ "$2" = "$3" ]; then ok "$1: $2"; else bad "$1: got '$2', want '$3'"; fi; }
tcl() { rm -f $W/q; echo 'set f [open '$W'/q w]; puts $f ['"$1"']; close $f' | $X/xpaset $T tcl; cat $W/q 2>/dev/null; }
size() { tcl '$current(frame) get fits size'; }
nap() { perl -e 'select(undef,undef,undef,0.3)'; }
shot() { rm -f $W/$1.fits; $X/xpaset -p $T save fits $W/$1.fits; }
# the window's order, from its HISTORY ("map" if not deep)
order() { shot o; "$PY" -I -c "
from astropy.io import fits
h = fits.getheader('$W/o.fits')
o = [str(c).split('HiPS order')[1].split()[0] for c in h.get('HISTORY', []) if 'HiPS order' in str(c)]
print(o[0] if o else 'map')"; }
dcheck() { "$PY" -I $H/deepcheck.py "$1" $W/$2.fits; }
# wait for background deep fetches and their refresh to finish
idle() { for i in $(seq 1 ${1:-80}); do r=$(tcl 'list $hipsdeep(running) [llength $hipsdeep(queue)] [llength [array names hipsdeep timer,*]]'); [ "$r" = "0 0 0" ] && break; nap; done; }
V="proj=TAN,lon0=92.7153,lat0=73.2733,fov=4"

rm -rf ~/$T.auto ~/$T.auto.dir ~/.$T
PATH="$X:$PATH" $X/ds9 -title $T >/dev/null 2>&1 &
for i in $(seq 1 40); do [ "$($X/xpaaccess -n $T)" -ge 1 ] && break; nap; done
echo 'set ::errs {}; proc Error {m} {lappend ::errs $m}' | $X/xpaset $T tcl

echo "1. local: zooming in reads deeper tiles"
$X/xpaset -p $T hips "${ABELL}[$V]"
check "starts at the coarse map (order 2)" "$(order)" "map"
check "  HIPSORD keyword (View > Keyword): 2" "$($X/xpaget $T fits header keyword HIPSORD)" "2"
lim0=$($X/xpaget $T scale limits)
echo 'galactic; circle(92.70,73.28,0.05)' | $X/xpaset $T regions
reg0=$($X/xpaget $T regions -system wcs -sky galactic -skyformat degrees | grep circle)
$X/xpaset -p $T zoom to 2
check "zoom 2: order 3" "$(order)" "3"
check "  HIPSORD: 3" "$($X/xpaget $T fits header keyword HIPSORD)" "3"
shot l3
r=$(dcheck $ABELL l3); rc=$?
if [ $rc = 0 ]; then ok "  values = the tiles ($r)"; else bad "  $r"; fi
$X/xpaset -p $T zoom to 4
check "zoom 4 more: order 5 (nside 16384, past the 8192 map limit)" "$(order)" "5"
shot l5
r=$(dcheck $ABELL l5); rc=$?
if [ $rc = 0 ]; then ok "  values = the tiles ($r)"; else bad "  $r"; fi
check "scale limits unchanged (whole-map statistics)" "$($X/xpaget $T scale limits)" "$lim0"
$X/xpaset -p $T pan to 92.6 73.3 galactic
check "pan: still order 5" "$(order)" "5"
shot lp
r=$(dcheck $ABELL lp); rc=$?
if [ $rc = 0 ]; then ok "  values = the tiles ($r)"; else bad "  $r"; fi
reg1=$($X/xpaget $T regions -system wcs -sky galactic -skyformat degrees | grep circle)
check "a region keeps its sky position through the deep zooms and pan" "$reg1" "$reg0"
$X/xpaset -p $T regions delete all
$X/xpaset -p $T zoom to 0.0625
check "zoom out: back to the map" "$(order)" "map"
check "  HIPSORD: 2 again" "$($X/xpaget $T fits header keyword HIPSORD)" "2"

echo "2. which windows go deep"
$X/xpaset -p $T hips "${ABELL}[norder=1,$V]"
$X/xpaset -p $T zoom to 8
check "norder=1 is only the start: zoom 8 -> order 4" "$(order)" "4"
$X/xpaset -p $T hips "${ABELL}[proj=MOL]"
$X/xpaset -p $T zoom to 8
check "all-sky (MOL) never goes deep" "$(order)" "map"

echo "3. remote: the visible tiles are fetched in the background"
mkdir -p $W/www; ln -s $ABELL $W/www/abell
"$PY" -I $H/hipsserve.py $W/www $W/port $W/log &
SRV=$!
for i in $(seq 1 30); do [ -s $W/port ] && break; nap; done
U=http://127.0.0.1:$(cat $W/port)
$X/xpaset -p $T hips "$U/abell[$V]"
check "starts at the quick look" "$(order)" "map"
: > $W/log
r=$($X/xpaset -p $T zoom to 8 2>&1)
check "zoom: no XPA error" "$r" ""
idle
check "the window's tiles asked for (order 3)" "$(grep -c 'Norder3/Dir' $W/log)" "4"
check "  and their ancestors (orders 1, 2), nothing else" "$(grep -c 'Norder[12]/Dir' $W/log)/$(grep -Evc 'Norder[123]/Dir' $W/log)" "4/0"
check "refreshed: order 3" "$(order)" "3"
shot r3
r=$(dcheck $ABELL r3); rc=$?
if [ $rc = 0 ]; then ok "  values = the tiles ($r)"; else bad "  $r"; fi
: > $W/log
$X/xpaset -p $T zoom to 0.125
$X/xpaset -p $T zoom to 8
idle
check "again: nothing fetched (cached; 404s remembered)" "$(grep -c . $W/log)" "0"
echo "4. a new view drops the old one's waiting requests"
tcl 'set hipsnet(parallel) 1' >/dev/null
$X/xpaset -p $T hips "$U/slow/abell[$V]"
: > $W/log
$X/xpaset -p $T zoom to 32
first=$(tcl 'llength $hipsdeep(queue)')
$X/xpaset -p $T pan to 93.5 73.0 galactic
idle
tcl 'set hipsnet(parallel) 6' >/dev/null
o5=$(grep -c 'Norder5/Dir' $W/log)
if [ "$first" -gt 3 ]; then ok "the first view queued $first tiles"; else bad "the first view queued only $first"; fi
check "  the final window is order 5" "$(order)" "5"
shot st
r=$(dcheck $ABELL st); rc=$?
if [ $rc = 0 ]; then ok "  values = the tiles ($r)"; else bad "  $r"; fi
total=$(( $(grep -c . $W/log) ))
if [ "$total" -lt $((first + 12)) ]; then ok "  $total requests in all (the first view's queue was dropped)"; else bad "  $total requests: the first view's queue was fetched too"; fi

echo "5. the status line and cancel"
tcl 'set hipsnet(parallel) 2; set hipsdeep(statusdelay) 100' >/dev/null
$X/xpaset -p $T hips "$U/crawl/abell[$V]"
: > $W/log
check "idle: hips status 0" "$($X/xpaget $T hips status)" "0"
$X/xpaset -p $T zoom to 8
nap
n=$($X/xpaget $T hips status)
if [ "$n" -gt 0 ]; then ok "fetching: hips status $n"; else bad "fetching: hips status '$n'"; fi
check "  the status line is shown" "$(tcl 'HiPSDeepStatusShown')" "1"
check "  and says so" "$(tcl 'set hipsdeep(msg)')" "Fetching HiPS tiles: 0 / 8"
$X/xpaset -p $T saveimage png $W/during.png
r0=$(tcl 'set hipsdeep(refreshes)')
# the requests started so far (arrived + in flight), read and cancelled
# in one go: how many that is depends on timing (each answer takes 1 s,
# 2 at a time), but nothing may start after the cancel. HiPSCancelCmd is
# what hips cancel runs (the XPA path is checked below, when idle).
started=$(tcl 'set r [expr {$hipsdeep(done)+$hipsdeep(running)}]; HiPSCancelCmd; set r')
check "hips cancel: status 0" "$($X/xpaget $T hips status)" "0"
check "  the status line is gone" "$(tcl 'HiPSDeepStatusShown')" "0"
sleep 3
check "  only the requests started before it were made (of 8)" "$(grep -c 'Norder' $W/log)" "$started"
check "  no redraw when they arrive" "$(tcl 'set hipsdeep(refreshes)')" "$r0"
$X/xpaset -p $T saveimage png $W/after.png
[ -n "$KEEP" ] && cp $W/during.png $W/after.png "$KEEP"
check "  saveimage leaves the status line out" "$(shasum -a 256 < $W/during.png)" "$(shasum -a 256 < $W/after.png)"
$X/xpaset -p $T zoom to 16
nap
check "a new view fetches again, the line is back" "$(tcl 'HiPSDeepStatusShown')" "1"
tcl '$ds9(image).hipsdeep.cancel invoke' >/dev/null
check "  its Cancel button: status 0" "$($X/xpaget $T hips status)/$(tcl 'HiPSDeepStatusShown')" "0/0"
sleep 2
$X/xpaset -p $T hips cancel
check "  hips cancel when idle: nothing to do" "$($X/xpaget $T hips status)" "0"
tcl 'set hipsnet(parallel) 6' >/dev/null
$X/xpaset -p $T zoom to 8
idle 300
check "  all in: hips status 0" "$($X/xpaget $T hips status)" "0"
shot cb
r=$(dcheck $ABELL cb); rc=$?
if [ $rc = 0 ]; then ok "  zooming back fetches the rest ($r)"; else bad "  $r"; fi
check "  the status line went away by itself" "$(tcl 'HiPSDeepStatusShown')" "0"
echo "5a. clearing or deleting the frame drops its waiting requests"
tcl 'set hipsnet(parallel) 1' >/dev/null
for how in clear delete load; do
  $X/xpaset -p $T hips "$U/crawl/abell[$V]"
  $X/xpaset -p $T zoom to 8
  q=$(tcl 'llength $hipsdeep(queue)')
  : > $W/log
  case $how in
    clear) $X/xpaset -p $T frame clear;;
    delete) $X/xpaset -p $T frame delete; $X/xpaset -p $T frame new;;
    # another image in the frame: the queue is skipped as it comes up
    load) $X/xpaset -p $T hips "${ABELL}[proj=MOL]";;
  esac
  [ $how = load ] || check "frame $how: nothing waiting (of $q), the one in flight left" "$(tcl 'llength $hipsdeep(queue)')/$($X/xpaget $T hips status)" "0/1"
  idle 40
  n=$(grep -c 'Norder' $W/log)
  if [ "$n" -le 1 ]; then ok "  frame $how: only the request in flight finished ($n of $q)"; else bad "  frame $how: $n requests made after it (of $q)"; fi
done
tcl 'set hipsnet(parallel) 6' >/dev/null

echo "5b. a failing server: each tile asked for once, not in a loop"
$X/xpaset -p $T hips "$U/nodeep/abell[$V]"
: > $W/log
$X/xpaset -p $T zoom to 8
idle
sleep 2
idle
n1=$(grep -c '^503 .*Norder[3-9]' $W/log)
if [ "$n1" -gt 0 ]; then ok "the deep tiles failed ($n1 requests)"; else bad "no deep tile was asked for"; fi
check "  none asked for twice" "$(grep '^503 ' $W/log | sort | uniq -d | wc -l | tr -d ' ')" "0"
$X/xpaset -p $T zoom to 0.125
$X/xpaset -p $T zoom to 8
idle
check "  zooming back within a minute: not asked for again" "$(grep -c '^503 .*Norder[3-9]' $W/log)" "$n1"
$X/xpaset -p $T hips cancel
$X/xpaset -p $T zoom to 0.125
$X/xpaset -p $T zoom to 8
idle
n2=$(grep -c '^503 .*Norder[3-9]' $W/log)
if [ "$n2" -gt "$n1" ]; then ok "  after hips cancel they are tried again"; else bad "  after hips cancel: not tried again ($n2)"; fi
kill $SRV; wait $SRV 2>/dev/null

echo "6. colour: every channel goes deep"
$X/xpaset -p $T hips "$TOP/hips/XRISM_RESOLVE[proj=TAN,lon0=0,lat0=0,fov=30]"
$X/xpaset -p $T zoom to 8
s=""; for c in red green blue; do $X/xpaset -p $T rgb channel $c; s="$s $(order)"; done
$X/xpaset -p $T rgb channel red
check "red green blue orders" "$s" "$(o=$(order); echo " $o $o $o")"
case "$s" in *map*) bad "  a channel is not deep: $s";; *) ok "  deep in every channel";; esac

check "no errors" "$(tcl 'set ::errs')" ""
$X/xpaset -p $T exit
rm -rf "$W" ~/.$T
echo "PASSED $pass, FAILED $fail"
[ $fail = 0 ]
