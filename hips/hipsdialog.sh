#!/bin/bash
# HiPS Phase 2 checks: File > Open HiPS... (OpenHiPSDialog, hips.tcl).
# Run from the top of the ds9 tree:
#   Tests/hips/hipsdialog.sh
# Starts and stops its own ds9 (title HiPSDlg). Error and
# tk_chooseDirectory are replaced by stubs, so nothing modal appears;
# the dialog itself waits in the event loop, so it is driven over XPA.
#  1. the dialog's order list (nside, source) and its Automatic entry
#     agree with what the reader really loads, for every sample HiPS
#  2. the dialog's result for chosen order/projection, bad input, cancel
#  3. refusals before the dialog (no readable tile format, not a HiPS)
#  4. the menu command end to end, from an RGB frame

TOP=$PWD
X=$TOP/bin
T=HiPSDlg
H=$TOP/Tests/hips
PY=${PY:-$HOME/miniforge/envs/hpxtest/bin/python}
FERMI=$TOP/hips/data1/ancillary/missions/Fermi_Band4/HiPS
W=$(mktemp -d "${TMPDIR:-/tmp}/hipsdlg.XXXXXX")
pass=0; fail=0
ok()  { pass=$((pass+1)); echo "  ok   $*"; }
bad() { fail=$((fail+1)); echo "  FAIL $*"; }
check() { if [ "$2" = "$3" ]; then ok "$1: $2"; else bad "$1: got '$2', want '$3'"; fi; }

# run Tcl in ds9 (at global level) and print its result
tcl() { rm -f $W/q; echo 'set f [open '$W'/q w]; puts $f ['"$1"']; close $f' | $X/xpaset $T tcl; cat $W/q 2>/dev/null; }
size() { tcl '$current(frame) get fits size'; }
nap() { perl -e 'select(undef,undef,undef,0.3)'; }

"$PY" -I $H/mksynth.py $W >/dev/null

rm -rf ~/$T.auto ~/$T.auto.dir ~/.$T
PATH="$X:$PATH" $X/ds9 -title $T >/dev/null 2>&1 &
for i in $(seq 1 40); do [ "$($X/xpaaccess -n $T)" -ge 1 ] && break; nap; done

# stubs: errors are collected, the directory chooser returns ::pick
cat <<EOF | $X/xpaset $T tcl
set ::errs {}
proc Error {m} {lappend ::errs \$m}
proc tk_chooseDirectory {args} {return \$::pick}
proc probe {dir} {
    set props [HiPSReadProperties \$dir]
    set width [HiPSProp \$props hips_tile_width 512]
    set maxorder [HiPSProp \$props hips_order 29]
    # the dialog's scan (its Automatic is the reader's, hipsinfo describe)
    set scan [HiPSOpenScan \$dir {} \$props [hipsinfo format \$dir]]
    set orders {}
    set auto {}
    if {\$scan != {}} {
	set orders [dict get \$scan orders]
	set auto [dict get \$scan auto]
    }
    set rr {}
    if {\$auto != {}} {
	lappend rr [list auto [dict get \$auto order] [dict get \$auto nside] [dict get \$auto source]]
    } else {
	lappend rr [list auto]
    }
    foreach oo \$orders {
	if {[dict get \$oo order] <= \$maxorder} {
	    lappend rr [list [dict get \$oo order] [dict get \$oo nside] [dict get \$oo source]]
	}
    }
    return [join \$rr \n]
}
EOF

echo "1. the dialog's orders agree with the reader"
# probe <name> <dir>: every order up to nside 2048, and Automatic
probe() {
    local name=$1 dir=$2
    local rr=$(tcl "probe {$dir}")
    echo "     $name: $(echo $rr | tr '\n' ' ')"
    # while-read in a pipe runs in a subshell: tally its checks via a file
    echo "$rr" | while read k n src extra; do
	[ -z "$k" ] && continue
	if [ "$k" = auto ]; then
	    $X/xpaset -p $T frame clear
	    tcl "ImportHiPSFile {$dir}" >/dev/null
	    got=$(size)
	    if [ -z "$n" ]; then
		check "$name Automatic: none, and the load fails" "$got" "0 0"
		check "$name   with the reader's reason" "$(tcl 'string match {*small enough*} [lindex $::errs end]')" "1"
	    else
		check "$name Automatic: order $n ($extra)" "$got" "$((5*src)) $((5*src))"
	    fi
	    tcl 'set ::errs {}' >/dev/null
	elif [ -n "$src" ] && [ "$n" -le 2048 ]; then
	    $X/xpaset -p $T frame clear
	    tcl "ImportHiPSFile {${dir}[norder=$k]}" >/dev/null
	    check "$name order $k ($src)" "$(size)" "$((5*n)) $((5*n))"
	fi
    done > $W/probe.out
    cat $W/probe.out
    pass=$((pass+$(grep -c '^  ok' $W/probe.out)))
    fail=$((fail+$(grep -c '^  FAIL' $W/probe.out)))
}
probe Fermi "$FERMI"
probe Abell1763 "$TOP/hips/Abell1763_irac1"
probe DSS2 "$TOP/hips/DSS2_red"
probe synth_f32 "$W/synth_f32"
probe synth_reduced "$W/synth_reduced"
tcl 'set ::errs {}' >/dev/null

echo "2. the dialog's result"
# dialog <setup tcl> <finish tcl>: open the dialog, run setup in it, then
# finish (HiPSOpenOK or Cancel), and print what it returned
dialog() {
    tcl "after idle {set ::res [HiPSOpenParamsDialog {$1}]; set ::done 1}; set ::done 0" >/dev/null
    for i in $(seq 1 20); do [ "$(tcl 'winfo exists .hipsopen')" = 1 ] && break; nap; done
    [ -n "$2" ] && tcl "$2" >/dev/null
    tcl "$3" >/dev/null
    for i in $(seq 1 20); do [ "$(tcl 'set ::done')" = 1 ] && break; nap; done
    tcl 'set ::res'
}
check "defaults: the bare directory" "$(dialog "$FERMI" "" HiPSOpenOK)" "$FERMI"
check "order 2, Mollweide, lon0 180" \
    "$(dialog "$FERMI" 'set hpxed(order) 2; HiPSOpenOrderChanged; set hpxed(proj) mol; HPXOpenProjChanged; set hpxed(lon0) 180' HiPSOpenOK)" \
    "${FERMI}[norder=2,proj=mol,lon0=180]"
check "gnomonic window" \
    "$(dialog "$FERMI" 'set hpxed(proj) tan; HPXOpenProjChanged; set hpxed(lon0) 83.6; set hpxed(lat0) -5; set hpxed(fov) 20' HiPSOpenOK)" \
    "${FERMI}[proj=tan,lon0=83.6,lat0=-5,fov=20]"
# only the projection carries over; the centre and fov start from the
# survey's initial view (Tests/hips/hipsview.sh), the order from Automatic
check "the projection is remembered, not the centre or order" \
    "$(dialog "$FERMI" "" HiPSOpenOK)" "${FERMI}[proj=tan]"
tcl 'set hipsopen(proj) hpx' >/dev/null
r=$(dialog "$FERMI" 'set hpxed(proj) tan; HPXOpenProjChanged; set hpxed(lat0) 100; HiPSOpenOK; set ::bad $::errs; set ::errs {}' 'set hpxed(ok) 0')
check "lat0 100 refused, dialog stays open" "$(tcl 'set ::bad')" "{Latitude must be between -90 and 90}"
check "then cancel: nothing" "$r" ""
dialog "$FERMI" 'set ::lab $hpxed(orderlabel)' 'set hpxed(ok) 0' >/dev/null
check "automatic label" "$(tcl 'set ::lab')" \
    "Automatic (Order 3: NSIDE 512, Allsky, 12 MB)"
dialog "$TOP/hips/DSS2_red" 'set ::lab $hpxed(orderlabel); set ::st [.hipsopen.data.order.m entrycget Automatic* -state]' 'set hpxed(ok) 0' >/dev/null
check "DSS2: Automatic disabled" "$(tcl 'set ::st')" "disabled"
check "DSS2: starts at the smallest order" "$(tcl 'set ::lab')" \
    "Order 3: NSIDE 4096, $(ls $TOP/hips/DSS2_red/Norder3/Dir*/Npix*.fits | wc -l | tr -d ' ')/768 tiles, 768 MB, Allsky unreadable"

echo "3. refused before the dialog"
mkdir -p $W/webp
sed 's/^hips_tile_format.*/hips_tile_format = webp/' $FERMI/properties > $W/webp/properties
dialog "$W/webp" "" "" >/dev/null
check "no FITS, PNG or JPEG tiles" "$(tcl 'lindex $::errs 0')" \
    "Unable to load HiPS $W/webp: no FITS, PNG or JPEG tiles (hips_tile_format = webp)"
check "  and no dialog" "$(tcl 'winfo exists .hipsopen')" "0"
tcl 'set ::errs {}' >/dev/null
dialog "$TOP/hips" "" "" >/dev/null
check "not a HiPS" "$(tcl 'lindex $::errs 0')" \
    "Unable to load HiPS $TOP/hips: no readable properties file"
tcl 'set ::errs {}' >/dev/null

echo "4. File > Open HiPS... from an RGB frame"
$X/xpaset -p $T frame delete all
$X/xpaset -p $T frame new rgb
tcl "set ::pick {$FERMI/Norder2}" >/dev/null
tcl 'after idle {OpenHiPSDialog; set ::done 1}; set ::done 0' >/dev/null
for i in $(seq 1 20); do [ "$(tcl 'winfo exists .hipsopen')" = 1 ] && break; nap; done
tcl 'set hpxed(order) 1; HiPSOpenOrderChanged; HiPSOpenOK' >/dev/null
for i in $(seq 1 40); do [ "$(tcl 'set ::done')" = 1 ] && break; nap; done
check "a Norder directory picks its HiPS; new plain frame" "$(tcl '$current(frame) get type')" "base"
check "loaded order 1" "$(size)" "640 640"
check "xpaget hips" "$($X/xpaget $T hips)" "${FERMI}[norder=1]"
check "in Open Recent" "$(tcl 'lindex $irecent(list) 0')" "hips {${FERMI}[norder=1]}"
check "next chooser starts beside the HiPS" "$(tcl 'set hipsopen(dir)')" "$(dirname $FERMI)"
check "no errors" "$(tcl 'set ::errs')" ""

$X/xpaset -p $T exit
rm -rf "$W" ~/.$T
echo "PASSED $pass, FAILED $fail"
[ $fail = 0 ]
