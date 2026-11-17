#!/bin/bash
# HiPS Phase 2 checks: Open Recent and backup/restore of a HiPS frame.
# Run from the top of the ds9 tree:
#   Tests/hips/hipsbackup.sh
# Starts and stops its own ds9s (title HiPSBck, so the recent list is
# ~/.HiPSBck/recent.txt, which is removed at the end).

TOP=$PWD
X=$TOP/bin
T=HiPSBck
FERMI=$TOP/hips/data1/ancillary/missions/Fermi_Band4/HiPS
W=$(mktemp -d "${TMPDIR:-/tmp}/hipsbck.XXXXXX")
pass=0; fail=0
ok()  { pass=$((pass+1)); echo "  ok   $*"; }
bad() { fail=$((fail+1)); echo "  FAIL $*"; }
check() { if [ "$2" = "$3" ]; then ok "$1: $2"; else bad "$1: got '$2', want '$3'"; fi; }

# run Tcl in ds9 and print what it returns
tcl() { echo 'set f [open '$W'/q w]; puts $f ['"$1"']; close $f' | $X/xpaset $T tcl; cat $W/q; }
size()   { tcl '$current(frame) get fits size'; }
frames() { $X/xpaget $T frame all | wc -w | tr -d ' '; }
shot()   { $X/xpaset -p $T saveimage png $W/$1.png; shasum -a 256 $W/$1.png | cut -c1-16; }
start() {
    rm -rf ~/$T.auto ~/$T.auto.dir
    PATH="$X:$PATH" $X/ds9 -title $T "$@" >/dev/null 2>&1 &
    for i in $(seq 1 40); do [ "$($X/xpaaccess -n $T)" -ge 1 ] && break; perl -e 'select(undef,undef,undef,0.5)'; done
}
stop() {
    $X/xpaset -p $T exit
    for i in $(seq 1 20); do [ "$($X/xpaaccess -n $T)" = 0 ] && break; perl -e 'select(undef,undef,undef,0.5)'; done
}

rm -rf ~/.$T
start
echo "Open Recent"
N="${FERMI}[order=2,proj=MOL]"
$X/xpaset -p $T hips "$N"
check "loaded" "$(size)" "1418 710"
check "recent entry" "$(head -3 ~/.$T/recent.txt | tail -1)" "hips {$N}"
# long paths are shortened in the menu, keeping the HiPS name and options
check "menu label" "$(tcl 'RecentLabel [lindex $irecent(list) 0]' | sed 's|.*/||')" "HiPS[order=2,proj=MOL]  (HiPS)"
$X/xpaset -p $T frame delete
$X/xpaset -p $T frame new rgb
tcl 'RecentOpen [lindex $irecent(list) 0]' >/dev/null
check "reopened from an RGB frame into a new plain frame" "$(tcl '$current(frame) get type')" "base"
check "reopened size" "$(size)" "1418 710"
check "xpaget hips" "$($X/xpaget $T hips)" "$N"
check "reopen did not duplicate the entry" "$(grep -c '^hips' ~/.$T/recent.txt)" "1"
tcl 'RecentAdd hips '$W'/nosuchdir' >/dev/null
check "a missing directory is not recorded" "$(grep -c nosuchdir ~/.$T/recent.txt)" "0"
tcl 'RecentAdd hips '$FERMI'/properties' >/dev/null
check "a plain file is not recorded as a HiPS" "$(grep -c properties ~/.$T/recent.txt)" "0"

echo "backup"
$X/xpaset -p $T frame delete all
$X/xpaset -p $T frame new
$X/xpaset -p $T hips "$N"
$X/xpaset -p $T scale log
$X/xpaset -p $T scale limits 1e-9 1e-6
$X/xpaset -p $T cmap viridis
$X/xpaset -p $T zoom 0.5
$X/xpaset -p $T pan to 100 50 galactic
echo 'galactic; circle(100,50,5d)' | $X/xpaset $T regions
before=$(shot before)
$X/xpaset -p $T backup $W/b.bck
check "backup wrote no HiPS data" "$(find $W/b.bck.dir -name "*.fits*" | wc -l | tr -d ' ')" "0"
check "backup names the HiPS" "$(grep -cF "HiPSRestore {$N}" $W/b.bck)" "1"
stop

echo "restore into a fresh ds9"
start
$X/xpaset -p $T restore $W/b.bck
check "restored size" "$(size)" "1418 710"
check "xpaget hips" "$($X/xpaget $T hips)" "$N"
check "scale" "$($X/xpaget $T scale)" "log"
check "regions" "$($X/xpaget $T regions -system galactic | grep -c circle)" "1"
check "same picture" "$(shot after)" "$before"

# A backup whose HiPS has moved falls back to an Error box and a file
# dialog (BackupFindFile), both modal, so that case is checked by hand.

stop

rm -rf "$W" ~/.$T ~/$T.auto ~/$T.auto.dir
echo "PASSED $pass, FAILED $fail"
[ $fail = 0 ]
