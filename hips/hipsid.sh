#!/bin/bash
# HiPS Phase 6 checks: HiPS by ID and from the MocServer list
# (ds9/library/hipsnet.tcl, HiPSResolveID / HiPSListRecords), against a
# mock MocServer in Tests/hips/hipsserve.py, so no network is needed.
# Run from the top of the ds9 tree: Tests/hips/hipsid.sh
# Starts and stops its own ds9 (title HiPSID; its cache is ~/.HiPSID/hips,
# removed at the end) and server.

T=HiPSID
. Tests/hips/lib.sh
CACHE=~/.$T/hips
# wait until dialog w is up and waiting (DialogWait grabs it)

mkdir -p $W/www
"$PY" -I $H/mksynth.py $W/www >/dev/null
"$PY" -I $H/mkcube.py $W/www >/dev/null
cat > $W/www/registry.txt <<'REG'
ID                   = TEST/P/synth
obs_title            = Synthetic float survey
dataproduct_type     = image
hips_service_url     = {URL}/synth_f32
hips_service_url_1   = {URL}/mirror/synth_f32

ID                   = TEST/P/cube
obs_title            = A test cube
dataproduct_type     = cube
hips_service_url     = {URL}/cube

ID                   = test/P/Lower
obs_title            = Integer survey (16-bit)
dataproduct_type     = image
hips_service_url     = {URL}/synth_i16/

ID                   = TEST/C/table
obs_title            = A catalogue
dataproduct_type     = catalog
hips_service_url     = {URL}/table

ID                   = TEST/P/nourl
obs_title            = Registered, not served
dataproduct_type     = image
REG

serve

start
errors
tcl "set phpxopen(mocserver) $U/MocServer/query" >/dev/null

echo "1. what is an ID"
mkdir -p $W/AB/P/here
for c in "CDS/P/DSS2/color:1" "ivo://CDS/P/DSS2/color:1" "CDS/P/DSS2/color[norder=3]:1" \
	 "ESAVO/P/HST/ACS-blue:1" "$W/AB/P/here:0" "$U/synth_f32:0" "file:///a/P/b:0" \
	 "hips/data1/ancillary:0" "DSS2_red:0" "CDS/C/x:1"; do
    n=${c%:*}
    check "  $n" "$(tcl "HiPSIsID {$n}")" "${c##*:}"
done
check "  a relative directory that exists is a directory" \
    "$(tcl "apply {{} {set d [pwd]; cd $W; set r [HiPSIsID AB/P/here]; cd \$d; return \$r}}")" "0"

echo "2. xpaget hips list"
mark
check "image and cube HiPS with a URL, by ID" \
    "$($X/xpaget $T hips list | cut -f1 | tr '\n' ' ')" "TEST/P/cube test/P/Lower TEST/P/synth "
check "  the title after a tab" "$($X/xpaget $T hips list synth)" "$(printf 'TEST/P/synth\tSynthetic float survey')"
check "  two queries (image, cube), fields only" "$(reqs 'MocServer/query?')/$(reqs 'dataproduct_type=image&hips_service_url=\*&get=record&fields=ID,obs_title,dataproduct_type,hips_service_url')" "2/1"
check "  cached in mocserver.txt" "$(grep -c '^ID = ' $CACHE/mocserver.txt)" "3"
mark
check "a word matches ID or title, any case" "$($X/xpaget $T hips list INTEGER | cut -f1)" "test/P/Lower"
check "a glob" "$($X/xpaget $T hips list 'TEST/P/c*' | cut -f1)" "TEST/P/cube"
check "nothing matches" "$($X/xpaget $T hips list nosuch)" ""
check "  from the cache, no query" "$(reqs)" "0"
$X/xpaget $T hips list update >/dev/null
check "update queries again" "$(reqs 'MocServer/query?')" "2"
touch -t 202001010000 $CACHE/mocserver.txt
mark
$X/xpaget $T hips list >/dev/null
check "a list older than a day is fetched again" "$(reqs 'MocServer/query?')" "2"

echo "3. loading by ID"
mark
$X/xpaset -p $T hips TEST/P/synth
check "loaded (order 1's reduced Allsky)" "$(size)" "80 80"
check "xpaget hips: its URL" "$($X/xpaget $T hips)" "$U/synth_f32"
check "  resolved from the list, no query" "$(reqs MocServer)" "0"
check "in Open Recent as the URL" "$(tcl 'lindex $irecent(list) 0')" "hips $U/synth_f32"
$X/xpaset -p $T hips "ivo://TEST/P/synth[norder=0]"
check "ivo:// and options" "$($X/xpaget $T hips)/$(size)" "$U/synth_f32[norder=0]/80 80"
$X/xpaset -p $T hips test/p/lower
check "another case, trailing / dropped" "$($X/xpaget $T hips)" "$U/synth_i16"
$X/xpaset -p $T hips new TEST/P/cube
check "hips new, a cube" "$($X/xpaget $T frame)/$(tcl 'HiPSFrameName $current(frame)')" "2/$U/cube"
check "  the Cube dialog" "$(tcl 'winfo exists $icube(top)')" "1"
$X/xpaset -p $T frame delete all
$X/xpaset -p $T frame new

# a HiPS registered after the list was fetched: one query by ID, then
# remembered for the session
cat >> $W/www/registry.txt <<'REG'

ID                   = TEST/P/new
obs_title            = Registered later
dataproduct_type     = image
hips_service_url     = {URL}/synth_i32
REG
mark
$X/xpaset -p $T hips TEST/P/new
check "not in the list: asked by ID" "$(grep -c 'MocServer/query?ID=TEST/P/new&get=record' $W/log)/$($X/xpaget $T hips)" "1/$U/synth_i32"
mark
$X/xpaset -p $T hips TEST/P/new
check "  then remembered" "$(reqs MocServer)" "0"
check "  the query's file is removed" "$(ls $CACHE/mocserver-id.txt 2>/dev/null)" ""

echo "4. errors"
tcl 'set ::errs {}' >/dev/null
$X/xpaset -p $T hips TEST/P/none 2>/dev/null
check "an unknown ID" "$(lasterr)" "Unable to load HiPS TEST/P/none: no HiPS with the ID TEST/P/none"
$X/xpaset -p $T hips TEST/P/nourl 2>/dev/null
check "registered without a URL" "$(lasterr)" "Unable to load HiPS TEST/P/nourl: no HiPS with the ID TEST/P/nourl"
$X/xpaset -p $T hips TEST/C/table 2>/dev/null
check "a catalogue: resolved, then refused" "$(lasterr)" "Unable to load HiPS $U/table: can't read $U/table/properties (not found)"
tcl "set phpxopen(mocserver) {$U/down/MocServer/query}" >/dev/null
$X/xpaset -p $T hips TEST/P/other 2>/dev/null
check "the MocServer down" "$(lasterr)" "Unable to load HiPS TEST/P/other: can't query $U/down/MocServer/query (HTTP 503)"
tcl 'set ::errs {}' >/dev/null
mark
check "  a stale list still lists (from before TEST/P/new)" "$($X/xpaget $T hips list update | cut -f1 | tr '\n' ' ')" "TEST/P/cube test/P/Lower TEST/P/synth "
check "  and no error" "$(tcl 'set ::errs')" ""

echo "5. the next MocServer when one is down"
tcl "set phpxopen(mocserver) {$U/down/MocServer/query $U/MocServer/query}" >/dev/null
mark
$X/xpaget $T hips list update >/dev/null
check "503 then 200, for each query" "$(cut -d' ' -f1 $W/log | tr '\n' ' ')" "503 200 503 200 "
rm -f $CACHE/mocserver.txt
tcl "set phpxopen(mocserver) {$U/down/MocServer/query}" >/dev/null
r=$($X/xpaget $T hips list 2>&1)
check "no list at all: an error" "$(lasterr)" "HiPS list: can't query $U/down/MocServer/query (HTTP 503)"
tcl "set phpxopen(mocserver) $U/MocServer/query" >/dev/null
tcl 'set ::errs {}' >/dev/null

echo "6. File > Open HiPS URL... takes an ID"
tcl "rename EntryDialog EntryDialogOrig; proc EntryDialog {t m s v} {upvar \$v x; set x TEST/P/cube; return 1}" >/dev/null
tcl 'after idle {OpenHiPSURLDialog; set ::done 1}; set ::done 0' >/dev/null
opened .hipsopen
check "the Open HiPS dialog, for its URL" "$(tcl '.hipsopen.file.dir cget -text')" "$U/cube"
tcl 'set hpxed(order) 1; HiPSOpenOrderChanged; HiPSOpenOK' >/dev/null
# the load runs in the background
for i in $(seq 1 40); do [ "$(tcl 'set ::done')" = 1 ] && [ "$($X/xpaget $T hips)" = "$U/cube[norder=1]" ] && break; nap; done
check "  loaded" "$($X/xpaget $T hips)" "$U/cube[norder=1]"
tcl "rename EntryDialog {}; rename EntryDialogOrig EntryDialog" >/dev/null

echo "7. File > Open HiPS from List..."
tcl 'after idle {OpenHiPSListDialog; set ::done 1}; set ::done 0' >/dev/null
opened .hipslist
check "all listed, the first selected" "$(tcl 'set hipslist(count)')/$(tcl '$hipslist(tree) selection')" "4 / 4/TEST/P/cube"
check "  columns" "$(tcl '$hipslist(tree) item test/P/Lower -values')" "test/P/Lower {Integer survey (16-bit)} image"
tcl 'set hipslist(filter) float; HiPSListFill' >/dev/null
check "filtered by title" "$(tcl '$hipslist(tree) children {}')/$(tcl 'set hipslist(count)')" "TEST/P/synth/1 / 4"
tcl 'set hipslist(filter) {}; HiPSListFill' >/dev/null
check "  the selection kept when the filter widens" "$(tcl '$hipslist(tree) selection')" "TEST/P/synth"
tcl 'set hipslist(filter) nosuch; HiPSListFill; HiPSListOK' >/dev/null
check "  nothing to open: stays" "$(tcl 'winfo exists .hipslist')/$(tcl 'set hipslist(ok)')" "1/0"
tcl 'set hipslist(filter) 16-bit; HiPSListFill; HiPSListOK' >/dev/null
opened .hipsopen
check "Open: the Open HiPS dialog for its URL" "$(tcl '.hipsopen.file.dir cget -text')" "$U/synth_i16"
tcl 'HiPSOpenOK' >/dev/null
# the load runs in the background
for i in $(seq 1 40); do [ "$(tcl 'set ::done')" = 1 ] && [ "$($X/xpaget $T hips)" = "$U/synth_i16" ] && break; nap; done
check "  loaded" "$($X/xpaget $T hips)" "$U/synth_i16"
check "  the filter is kept for next time" "$(tcl 'set hipslist(filter)')" "16-bit"
tcl 'after idle {OpenHiPSListDialog; set ::done 1}; set ::done 0' >/dev/null
opened .hipslist
tcl 'set hipslist(ok) 0' >/dev/null
for i in $(seq 1 20); do [ "$(tcl 'set ::done')" = 1 ] && break; nap; done
check "Cancel: nothing loaded" "$(tcl 'winfo exists .hipslist')/$($X/xpaget $T hips)" "0/$U/synth_i16"

echo "8. a request made while a load waits gets its own answer"
# the load waits a second for its properties (/crawl/); the list is
# asked for from inside that wait, as a dialog or SAMP would (an XPA
# request waits for the load to finish, so it can't do this)
tcl 'set ::errs {}' >/dev/null
r=$(tcl "after 300 {set ::nested [llength [HiPSListRecords 1]]}; HiPSFetch {$U/crawl/synth_f32[norder=0]}")
check "the load: its cache directory" "$r" "$CACHE/127.0.0.1_$(cat $W/port)/crawl/synth_f32[norder=0]"
check "  the list asked for meanwhile: 4 HiPS" "$(tcl 'set ::nested')" "4"
check "  the properties are the HiPS's" "$(sed -n 's/^obs_title *= *//p' $CACHE/127.0.0.1_$(cat $W/port)/crawl/synth_f32/properties)" "$(sed -n 's/^obs_title *= *//p' $W/www/synth_f32/properties)"

check "no errors" "$(tcl 'set ::errs')" ""
$X/xpaset -p $T exit
for i in $(seq 1 20); do [ "$($X/xpaaccess -n $T)" = 0 ] && break; nap; done
finish
