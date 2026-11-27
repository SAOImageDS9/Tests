#!/bin/bash
# HiPS Phase 3 checks: remote HiPS over HTTP (ds9/library/hipsnet.tcl),
# against a local server (Tests/hips/hipsserve.py), so no network is
# needed. Run from the top of the ds9 tree: Tests/hips/hipsnet.sh
# Starts and stops its own ds9 (title HiPSNet; its cache is
# ~/.HiPSNet/hips, removed at the end) and server.

T=HiPSNet
. Tests/hips/lib.sh
FERMI=$TOP/Tests/hipsdata/data1/ancillary/missions/Fermi_Band4/HiPS
ABELL=$TOP/Tests/hipsdata/Abell1763_irac1
CACHE=~/.$T/hips
# requests since the last mark: reqs [pattern]
# save the current frame's image, to compare: shot <name>
same() { "$PY" -I -c "
import sys, numpy as np; from astropy.io import fits
a, b = fits.getdata(sys.argv[1]), fits.getdata(sys.argv[2])
print('same' if a.shape == b.shape and np.array_equal(a, b, equal_nan=True) else f'differ {a.shape} {b.shape}')" $W/$1.fits $W/$2.fits; }

# what the server offers
mkdir -p $W/www
ln -s $FERMI $W/www/fermi
ln -s $ABELL $W/www/abell
"$PY" -I $H/mksynth.py $W/www >/dev/null
# a copy whose properties the test changes (new release)
cp -R $W/www/synth_f32 $W/www/rel

serve

start
errors

echo "1. quick look: properties and one Allsky"
mark
$X/xpaset -p $T hips "$U/fermi"
check "requests" "$(sort $W/log | tr '\n' ' ')" "200 /fermi/Norder3/Allsky.fits 200 /fermi/properties "
check "loaded at order 3 (Allsky, nside 512)" "$(size)" "2560 2560"
check "xpaget hips: the URL" "$($X/xpaget $T hips)" "$U/fermi"
shot remote3
$X/xpaset -p $T hips "${FERMI}[norder=3]"
shot local3
check "same image as the local HiPS" "$(same remote3 local3)" "same"
check "scale limits from the cached properties" "$($X/xpaget $T scale limits)" "2e-09 8e-07"

echo "1b. a few cached tiles don't replace a reduced Allsky"
# synth_reduced: order-1 Allsky of 8-px tiles (16-px tiles); the quick
# look reads it as norder=1. Tiles a deep window left in the cache (two
# here) cover a few patches only: the map must still be the Allsky
$X/xpaset -p $T hips "$U/synth_reduced"
d=$CACHE/127.0.0.1_$(cat $W/port)/synth_reduced
check "quick look: the reduced Allsky" "$(hdr | grep -o 'from Allsky.fits')" "from Allsky.fits"
mkdir -p $d/Norder1/Dir0
cp $W/www/synth_f32/Norder1/Dir0/Npix5.fits $W/www/synth_f32/Norder1/Dir0/Npix6.fits $d/Norder1/Dir0/
$X/xpaset -p $T hips "$U/synth_reduced"
check "  with 2 of its 48 tiles cached: still the Allsky" "$(hdr | grep -o 'from Allsky.fits\|from fits tiles: [0-9]* of [0-9]*')" "from Allsky.fits"
$X/xpaset -p $T hips "$d[norder=1]"
check "  the reader, asked for order 1 there: the Allsky" "$(hdr | grep -o 'from Allsky.fits\|from fits tiles: [0-9]* of [0-9]*')" "from Allsky.fits"
rm -rf $d/Norder1/Dir0

echo "2. norder=K: tiles"
mark
: > $W/log.conns
$X/xpaset -p $T hips "$U/fermi[norder=2]"
check "192 tiles fetched (full-sky MOC)" "$(reqs '^200 /fermi/Norder2/Dir0/Npix')" "192"
# each worker keeps its connection (keep-alive): at most one each
nc=$(grep -c . $W/log.conns)
if [ "$nc" -le "$(tcl 'set hipsnet(parallel)')" ]; then ok "  over $nc connections (keep-alive)"; else bad "  $nc connections for $(reqs .) requests"; fi
check "Moc.fits fetched" "$(reqs '^200 /fermi/Moc.fits')" "1"
check "order 2 Allsky asked for once (none there)" "$(reqs 'Norder2/Allsky.fits')" "1"
shot remote2
$X/xpaset -p $T hips "${FERMI}[norder=2]"
shot local2
check "same image as the local HiPS" "$(same remote2 local2)" "same"
mark
$X/xpaset -p $T hips "$U/fermi[norder=2,proj=MOL]"
check "again: only properties (cached)" "$(sort $W/log | tr '\n' ' ')" "200 /fermi/properties "
check "  with options (MOL, order 2)" "$(size)" "1418 710"

echo "3. the MOC limits the tiles"
mark
$X/xpaset -p $T hips "$U/abell[norder=1]"
want=$("$PY" -I -c "
import sys, numpy as np; from astropy.io import fits
u = fits.getdata(sys.argv[1], 1).field(0).astype(np.int64)
o = (np.floor(np.log2(u // 4)) // 2).astype(int); n = u - 4 * 4 ** o.astype(np.int64)
K = 1; s = set()
for oo, nn in zip(o, n):
    if oo >= K: s.add(int(nn) >> 2 * (oo - K))
    else: s.update(range(int(nn) << 2 * (K - oo), (int(nn) + 1) << 2 * (K - oo)))
print(len(s))" $ABELL/Moc.fits)
check "tiles asked for = MOC cells at order 1" "$(reqs 'abell/Norder1/Dir')" "$want"
shot ra1
$X/xpaset -p $T hips "${ABELL}[norder=1]"
shot la1
check "same image as the local HiPS" "$(same ra1 la1)" "same"
check "the reader's MOC cells (hipsinfo moc) agree" "$(tcl "llength [hipsinfo moc {$ABELL/Moc.fits} 1]")" "$want"
# a MOC that isn't NUNIQ (here marked RANGE, MOC 2.0) isn't misread as
# one: it limits nothing, so every tile of the order is asked for
mkdir -p $W/www/rmoc
for f in $ABELL/*; do [ "$(basename $f)" != Moc.fits ] && ln -s $f $W/www/rmoc/; done
"$PY" -I -c "
import sys; from astropy.io import fits
h = fits.open(sys.argv[1]); h[1].header['ORDERING'] = 'RANGE'; h.writeto(sys.argv[2])" $ABELL/Moc.fits $W/www/rmoc/Moc.fits
check "  hipsinfo moc refuses a RANGE MOC" "$(tcl "catch {hipsinfo moc {$W/www/rmoc/Moc.fits} 1}")" "1"
mark
$X/xpaset -p $T hips "$U/rmoc[norder=1]"
check "  a RANGE MOC limits nothing: all 48 tiles asked for" "$(reqs 'rmoc/Norder1/Dir')" "48"
tcl 'set ::errs {}' >/dev/null

echo "4. missing tiles (404) are blank and not asked for again"
mark
$X/xpaset -p $T hips "$U/synth_f32[norder=1]"
n404=$(reqs '^404 /synth_f32/Norder1/Dir')
check "404s for the absent tiles" "$n404" "3"
shot rs1
$X/xpaset -p $T hips "$W/www/synth_f32[norder=1]"
shot ls1
check "same image as the local HiPS" "$(same rs1 ls1)" "same"
mark
$X/xpaset -p $T hips "$U/synth_f32[norder=1]"
check "reload: no tile requests" "$(reqs 'Norder1/Dir')" "0"

echo "5. redirects"
mark
$X/xpaset -p $T hips "$U/redirect/synth_f32[norder=0]"
check "loaded through a redirect" "$(size)" "80 80"
check "  the redirect was followed" "$(reqs '^302 /redirect/synth_f32/properties')" "1"

echo "6. a new release empties the cache"
$X/xpaset -p $T hips "$U/rel[norder=1]"
d=$CACHE/127.0.0.1_$(cat $W/port)/rel
check "tiles cached" "$(ls $d/Norder1/Dir0 | wc -l | tr -d ' ')" "45"
sed -i.bak 's/^hips_release_date.*/hips_release_date = 2099-01-01T00:00Z/' $W/www/rel/properties
grep -q '^hips_release_date' $W/www/rel/properties || echo "hips_release_date = 2099-01-01T00:00Z" >> $W/www/rel/properties
mark
$X/xpaset -p $T hips "$U/rel[norder=1]"
check "all tiles fetched again" "$(reqs '^200 /rel/Norder1/Dir')" "45"

echo "7. errors"
tcl 'set ::errs {}' >/dev/null
$X/xpaset -p $T hips "http://127.0.0.1:1/nothing"
case "$(lasterr)" in *"can't read http://127.0.0.1:1/nothing/properties (no response)"*) ok "no server: $(lasterr)";; *) bad "no server: '$(lasterr)'";; esac
$X/xpaset -p $T hips "$U/nothere"
case "$(lasterr)" in *"properties (not found)"*) ok "no HiPS there: $(lasterr | head -c 80)";; *) bad "no HiPS there: '$(lasterr)'";; esac
tcl 'set hipsnet(maxbytes) 100000' >/dev/null
$X/xpaset -p $T hips "$U/abell[norder=3]"
case "$(lasterr)" in *"more than the limit"*) ok "too much to fetch: $(lasterr | head -c 90)";; *) bad "too much: '$(lasterr)'";; esac
tcl 'set hipsnet(maxbytes) [expr {wide(1)<<30}]' >/dev/null
tcl 'set ::errs {}' >/dev/null
# a deep norder= is refused before its tiles are listed (12*4^12 here)
cp -R $W/www/synth_f32 $W/www/deep
sed -i.bak 's/^hips_order .*/hips_order = 29/' $W/www/deep/properties
mark
t0=$(date +%s)
$X/xpaset -p $T hips "$U/deep[norder=12]"
dt=$(( $(date +%s) - t0 ))
case "$(lasterr)" in *"larger than the limit"*) ok "norder=12 remote: $(lasterr | sed 's/.*: HiPS: //')";; *) bad "norder=12 remote: '$(lasterr)'";; esac
if [ $dt -le 5 ]; then ok "  at once (${dt}s), no tiles asked for ($(reqs Norder12))"; else bad "  took ${dt}s"; fi
tcl 'set ::errs {}' >/dev/null
# something inside the fetch throws (a full disk, say): that load
# fails, and the next one is not refused as "another HiPS is being fetched"
tcl 'rename HiPSFetchAllsky HiPSFetchAllskyReal; proc HiPSFetchAllsky {args} {error "no space left on device"}' >/dev/null
$X/xpaset -p $T hips "$U/fermi"
case "$(lasterr)" in *"no space left"*) ok "a throw fails the load: $(lasterr | head -c 70)";; *) bad "a throw: '$(lasterr)'";; esac
check "  the load has ended" "$(tcl 'llength $hipsnet(fetches)')" "0"
tcl 'rename HiPSFetchAllsky {}; rename HiPSFetchAllskyReal HiPSFetchAllsky; set ::errs {}' >/dev/null
$X/xpaset -p $T hips "$U/fermi"
check "  the next load works" "$(lasterr)/$(size)" "/2560 2560"
check "  no temporary files left in the cache" "$(find $CACHE -name '*.new' | wc -l | tr -d ' ')" "0"
tcl 'set ::errs {}' >/dev/null

echo "8. cancel"
tcl 'set hipsnet(parallel) 1' >/dev/null
mark
# cancel as the second tile arrives (as the progress window's button
# would), watching the next load's own count
tcl 'set ::cn [expr {$hipsnet(fetchid)+1}]; proc ::cancelat {args} {if {[set ::hipsfetch${::cn}(done)] >= 2} {HiPSCancel}}; trace add variable ::hipsfetch${::cn}(done) write ::cancelat' >/dev/null
$X/xpaset -p $T hips "$U/slow/fermi[norder=2]"
case "$(lasterr)" in *cancelled*) ok "cancelled: $(lasterr | head -c 70)";; *) bad "cancel: '$(lasterr)'";; esac
# the server logs the path without /slow
got=$(reqs '^200 /fermi/Norder2/Dir')
total=192
if [ "$got" -ge 2 ] && [ "$got" -le 3 ] && [ "$got" -lt "$total" ]; then ok "stopped after $got of $total tiles"; else bad "stopped after $got of $total tiles"; fi
check "  no progress window left" "$(tcl 'winfo exists .hipsprogress')" "0"
tcl 'set hipsnet(parallel) 6; set ::errs {}' >/dev/null
mark
$X/xpaset -p $T hips "$U/slow/fermi[norder=2]"
check "then fetched in full" "$(lasterr)/$(size)" "/1280 1280"
check "  only the rest was asked for" "$(reqs '^200 /fermi/Norder2/Dir')" "$((192-got))"

echo "9. Open Recent, backup, coverage, file://"
$X/xpaset -p $T hips "$U/abell[norder=2,proj=TAN,fov=5]"
check "recent: the URL" "$(tcl 'lindex $irecent(list) 0')" "hips {$U/abell[norder=2,proj=TAN,fov=5]}"
$X/xpaset -p $T hips coverage
check "coverage of a remote HiPS" "$($X/xpaget $T hips coverage)/$(tcl '$current(frame) get contour aux count')" "yes/1"
$X/xpaset -p $T backup $W/b.bck
check "backup names the URL" "$(grep -c "HiPSRestore {$U/abell" $W/b.bck)" "1"
$X/xpaset -p $T frame delete all
$X/xpaset -p $T restore $W/b.bck
check "restored" "$($X/xpaget $T hips)/$($X/xpaget $T hips coverage)" "$U/abell[norder=2,proj=TAN,fov=5]/yes"
$X/xpaset -p $T frame delete all
$X/xpaset -p $T frame new
$X/xpaset -p $T hips "file://$FERMI[norder=1]"
check "file:// is local" "$(size)/$($X/xpaget $T hips)" "640 640/$FERMI[norder=1]"

echo "11. File > Open HiPS URL..."
tcl "proc EntryDialog {t m s v} {upvar \$v var; set var {$U/synth_f32}; return 1}" >/dev/null
tcl 'after idle {OpenHiPSURLDialog; set ::done 1}; set ::done 0' >/dev/null
for i in $(seq 1 30); do [ "$(tcl 'winfo exists .hipsopen')" = 1 ] && break; nap; done
check "the dialog opens on the remote HiPS" "$(tcl '.hipsopen.file.dir cget -text')" "$U/synth_f32"
check "Automatic is the quick look" "$(tcl 'set hpxed(orderlabel)')" "Automatic (quick look: the survey's all-sky image)"
check "orders from properties" "$(tcl 'set m .hipsopen.data.order.m; set r {}; for {set i 0} {$i <= [$m index end]} {incr i} {if {[$m type $i] == {radiobutton} && [string match {Order 1*} [$m entrycget $i -label]]} {set r [$m entrycget $i -label]}}; set r')" "Order 1: NSIDE 32, ~48 tiles, ~0.0 MB to fetch"
tcl 'set hpxed(order) 0; HiPSOpenOrderChanged; HiPSOpenOK' >/dev/null
# the load runs in the background
for i in $(seq 1 40); do [ "$(tcl 'set ::done')" = 1 ] && [ "$($X/xpaget $T hips)" = "$U/synth_f32[norder=0]" ] && break; nap; done
check "loaded at order 0" "$($X/xpaget $T hips)/$(size)" "$U/synth_f32[norder=0]/80 80"

echo "12. mirrors"
mkdir -p $W/www/mir
cp $W/www/synth_f32/properties $W/www/mir/
echo "hips_service_url_1 = $U/synth_f32" >> $W/www/mir/properties
mark
$X/xpaset -p $T hips "$U/half/mir[norder=1]"
# no Moc.fits here, so all 48 tiles are asked for; 3 are really missing
check "primary down (503): tiles from the mirror" "$(reqs '^503 /half/mir/Norder1/Dir')/$(reqs '^200 /synth_f32/Norder1/Dir')/$(reqs '^404 /synth_f32/Norder1/Dir')" "48/45/3"
shot mir1
$X/xpaset -p $T hips "$W/www/synth_f32[norder=1]"
shot loc1
check "same image as the local HiPS" "$(same mir1 loc1)" "same"
check "  and no error" "$(lasterr)" ""

echo "13. the cache"
d=$CACHE/127.0.0.1_$(cat $W/port)
check "loads stamp their HiPS" "$(ls -a $d/half/mir | grep -c '^.used$')" "1"
before=$(tcl 'llength [HiPSCacheList]')
tcl 'set phpxopen(hipscache) 0.01' >/dev/null
$X/xpaset -p $T hips "$U/synth_f32[norder=0]"
after=$(tcl 'llength [HiPSCacheList]')
check "a small cache keeps only what was just loaded" "$after" "1"
check "  the HiPS in use" "$(tcl 'lindex [HiPSCacheList] 0')" "$d/synth_f32"
if [ "$before" -gt 1 ]; then ok "  ($before HiPS before)"; else bad "  only $before HiPS cached before"; fi
# a HiPS shown in another frame is in use too, and zooming a deep
# window stamps it
$X/xpaset -p $T hips "$U/abell[norder=2,proj=TAN,lon0=92.7153,lat0=73.2733,fov=4]"
$X/xpaset -p $T frame new
$X/xpaset -p $T hips "$U/synth_f32[norder=0]"
check "a HiPS in another frame survives pruning" "$(tcl 'llength [HiPSCacheList]')" "2"
$X/xpaset -p $T frame first
touch -t 202001010000 $d/abell/.used
touch -t 202101010000 $W/ref
$X/xpaset -p $T zoom to 8
for i in $(seq 1 40); do [ "$(tcl 'expr {$hipsdeep(running)+[llength $hipsdeep(queue)]}')" = 0 ] && break; nap; done
if [ -n "$(find $d/abell/.used -newer $W/ref)" ]; then ok "  deep tiles arriving stamp it"; else bad "  deep tiles did not stamp .used"; fi
tcl 'set phpxopen(hipscache) 2048' >/dev/null
tcl 'HiPSCacheClear' >/dev/null
check "Clear HiPS Cache keeps the HiPS shown" "$(cd $d && ls | sort | tr '\n' ' ')" "abell synth_f32 "
$X/xpaset -p $T frame delete all
$X/xpaset -p $T frame new
tcl 'HiPSCacheClear' >/dev/null
check "Clear HiPS Cache" "$([ -e $CACHE ] && echo there || echo gone)" "gone"
$X/xpaset -p $T hips "$U/synth_f32[norder=0]"
check "  and loading again fetches again" "$(size)" "80 80"

echo "14. loads in the background, side by side"
# frame <n>: show frame n; fn: the current frame's number
fn() { $X/xpaget $T frame; }
idle() { for i in $(seq 1 120); do [ "$(tcl 'llength $hipsnet(fetches)')" = 0 ] && break; nap; done; }
$X/xpaset -p $T frame delete all
$X/xpaset -p $T frame new; fa=$(fn)
# crawl: 1 s a request
tcl "HiPSLoadAsync {$U/crawl/synth_f32[norder=0]}" >/dev/null
check "a dialog's load returns at once" "$($X/xpaget $T hips)" ""
$X/xpaset -p $T frame new; fb=$(fn)
tcl "HiPSLoadAsync {$U/slow/fermi[norder=1]}" >/dev/null
check "two loads at once" "$(tcl 'llength $hipsnet(fetches)')" "2"
nap; nap
check "  a progress line each" "$(tcl 'llength [winfo children .hipsprogress]')" "2"
# a blocking load meanwhile (XPA), into a third frame
$X/xpaset -p $T frame new; fc=$(fn)
$X/xpaset -p $T hips "$U/synth_f32[norder=0]"
check "a blocking load meanwhile" "$(size)" "80 80"
idle
check "  then each in the frame current when it started" \
  "$($X/xpaset -p $T frame $fa; $X/xpaget $T hips)|$($X/xpaset -p $T frame $fb; $X/xpaget $T hips)|$($X/xpaset -p $T frame $fc; $X/xpaget $T hips)" \
  "$U/crawl/synth_f32[norder=0]|$U/slow/fermi[norder=1]|$U/synth_f32[norder=0]"
check "  no progress window left" "$(tcl 'winfo exists .hipsprogress')" "0"
# cancelling one load leaves the other
$X/xpaset -p $T frame delete all
$X/xpaset -p $T frame new; fa=$(fn)
tcl "HiPSLoadAsync {$U/crawl/abell[norder=1]}" >/dev/null
ida=$(tcl 'set hipsnet(fetchid)')
$X/xpaset -p $T frame new; fb=$(fn)
tcl "HiPSLoadAsync {$U/slow/synth_f32[norder=1]}" >/dev/null
nap
tcl "HiPSFetchCancel $ida" >/dev/null
idle
check "cancel one: it isn't loaded, the other is" \
  "$($X/xpaset -p $T frame $fa; $X/xpaget $T hips)|$($X/xpaset -p $T frame $fb; $X/xpaget $T hips)" \
  "|$U/slow/synth_f32[norder=1]"
check "  a cancelled background load says nothing" "$(lasterr)" ""
# a cancel ends a request already in progress, not when it finishes
$X/xpaset -p $T frame delete all
$X/xpaset -p $T frame new
tcl "HiPSLoadAsync {$U/crawl/rel[norder=1]}" >/dev/null
nap
t=$(tcl 'set t0 [clock milliseconds]; HiPSCancel; while {[llength $hipsnet(fetches)]} {vwait hipsnet(fetches)}; expr {[clock milliseconds]-$t0}')
if [ "$t" -lt 600 ]; then ok "  cancel ends a 1 s request at once ($t ms)"; else bad "  cancel took $t ms"; fi
tcl 'set ::errs {}' >/dev/null

echo "15. a server that closes idle connections"
# real servers close a kept-alive connection after a few idle seconds;
# the workers' next requests must reconnect, not fail
mkdir -p $W/idle; ln -s $FERMI $W/idle/fermi
HIPSSERVE_IDLE=1 "$PY" -I $H/hipsserve.py $W/idle $W/iport $W/ilog &
HUB=$!
for i in $(seq 1 30); do [ -s $W/iport ] && break; nap; done
IU=http://127.0.0.1:$(cat $W/iport)
tcl 'set ::errs {}' >/dev/null
$X/xpaset -p $T hips "$IU/fermi[norder=1]"
c1=$(grep -c . $W/ilog.conns)
sleep 3
$X/xpaset -p $T hips "$IU/fermi[norder=2]"
check "after they were closed: every tile" "$(grep -c '^200 /fermi/Norder2/Dir0/Npix' $W/ilog)/$(size)/$(lasterr)" "192/1280 1280/"
c2=$(grep -c . $W/ilog.conns)
if [ $c2 -gt $c1 ]; then ok "  over new connections ($c1, then $((c2-c1)) more)"; else bad "  no new connections ($c1, $c2)"; fi
kill $HUB; wait $HUB 2>/dev/null; HUB=

echo "10. offline: the cache serves"
# (13 cleared the cache) fetch it, then stop the server
$X/xpaset -p $T hips "$U/fermi[norder=2]"
kill $SRV; wait $SRV 2>/dev/null
tcl 'set ::errs {}' >/dev/null
$X/xpaset -p $T hips "$U/fermi[norder=2]"
check "loaded with the server gone" "$(size)/$(lasterr)" "1280 1280/"

check "no unexpected errors" "$(tcl 'set ::errs')" ""
$X/xpaset -p $T exit
finish
