#!/bin/bash
# HiPS over SAMP: ds9.set / ds9.get with the hips command, through a
# private astropy hub (Tests/hips/samphub.py, its own lockfile, so
# ~/.samp and any running hub are left alone). The command goes through
# the same parser as XPA; these check the SAMP path end to end, and that
# the answers (one line, or a file for hips list) arrive.
# Run from the top of the ds9 tree: Tests/hips/hipssamp.sh
# Starts and stops its own hub, ds9 (title HiPSSamp) and HTTP server.

T=HiPSSamp
. Tests/hips/lib.sh
FERMI=$TOP/hips/data1/ancillary/missions/Fermi_Band4/HiPS
sset() { "$PY" -I $H/sampcall.py $W/lock "$NAME" set "$1"; }
sget() { "$PY" -I $H/sampcall.py $W/lock "$NAME" get "$1"; }

"$PY" -I $H/samphub.py $W/lock 2>/dev/null &
HUB=$!
for i in $(seq 1 30); do [ -s $W/lock ] && break; nap; done

mkdir -p $W/www
"$PY" -I $H/mksynth.py $W/www >/dev/null
cat > $W/www/registry.txt <<'REG'
ID                   = TEST/P/synth
obs_title            = Synthetic float survey
dataproduct_type     = image
hips_service_url     = {URL}/synth_f32

ID                   = TEST/P/i16
obs_title            = Integer survey
dataproduct_type     = image
hips_service_url     = {URL}/synth_i16
REG
serve

DS9ENV="SAMP_HUB=std-lockurl:file://$W/lock" start
tcl "set phpxopen(mocserver) $U/MocServer/query" >/dev/null
$X/xpaset -p $T samp connect
for i in $(seq 1 30); do [ "$(tcl 'info exists samp(private)')" = 1 ] && break; nap; done
NAME=$(tcl 'set ds9(app)')

echo "1. connected"
check "ds9 is on the private hub" "$(tcl 'info exists samp(private)')" "1"

echo "2. load and ask"
check "ds9.set hips <dir>" "$(sset "hips $FERMI[norder=2]")" ""
check "ds9.get hips" "$(sget hips)" "$FERMI[norder=2]"
check "  the frame" "$(tcl '$current(frame) get fits size')" "1280 1280"
sset "hips new $FERMI[norder=1,proj=mol,lon0=180]" >/dev/null
check "hips new, projection options" "$(sget frame)/$(sget hips)" "2/$FERMI[norder=1,proj=mol,lon0=180]"
check "a URL" "$(sset "hips $U/synth_f32[norder=0]"; sget hips)" "$U/synth_f32[norder=0]"
check "an ID" "$(sset 'hips TEST/P/i16[norder=1]'; sget hips)" "$U/synth_i16[norder=1]"
check "format=" "$(sset "hips $U/synth_f32[norder=0,format=fits]"; sget hips)" "$U/synth_f32[norder=0,format=fits]"

echo "3. the other hips commands"
check "hips list (a file over SAMP, one per line)" "$(sget 'hips list' | cut -f1 | tr '\n' ' ')" "TEST/P/i16 TEST/P/synth "
check "hips list with a pattern" "$(sget 'hips list integer')" "$(printf 'TEST/P/i16\tInteger survey')"
check "hips status" "$(sget 'hips status')" "0"
check "hips cancel" "$(sset 'hips cancel')" ""
sset "hips $FERMI[norder=2]" >/dev/null
check "hips coverage yes" "$(sset 'hips coverage yes'; sget 'hips coverage')" "yes"
check "hips coverage no" "$(sset 'hips coverage no'; sget 'hips coverage')" "no"
check "hips close" "$(sset 'hips close'; sget hips)/$(tcl '$current(frame) has fits')" "/0"

echo "4. errors come back as SAMP errors"
r=$(sset "hips $W/nosuch")
check "a missing directory" "${r%%:*}" "ERROR"
r=$(sset "hips TEST/P/none")
check "an unknown ID" "$r" "ERROR: Unable to load HiPS TEST/P/none: no HiPS with the ID TEST/P/none"
r=$(sset "hips $FERMI[format=gif]")
check "a bad format=" "$r" "ERROR: Unable to load HiPS $FERMI[format=gif]: format= is fits, png or jpeg"
check "  and ds9 still answers" "$(sset "hips $FERMI[norder=0]"; sget hips)" "$FERMI[norder=0]"

$X/xpaset -p $T exit
for i in $(seq 1 20); do [ "$($X/xpaaccess -n $T)" = 0 ] && break; nap; done
finish
