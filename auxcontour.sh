#!/bin/bash
# Loaded (aux) contour set tests: the frame commands that list, restyle,
# reset, rename, save and delete each loaded contour file or paste
# (get contour aux, contour aux style/reset/name, contour delete/save aux
# <id>), mosaic files, Convert to Polygons and HEALPix recentring.
# Driven over XPA; needs ds9 and the xpa tools on PATH. Run from Tests/.
# usage: auxcontour.sh
# Exits non-zero if any check fails. Work files go to a temp dir.

echo "Aux Contour Set Tests"

T=$PWD
X="xpaset"
G="xpaget"
D=DS9Test
O=$(mktemp -d "${TMPDIR:-/tmp}/auxcontour.XXXXXX")

launch() {
    $X -p $D exit 2>/dev/null
    for i in $(seq 1 300); do xpaaccess $D 2>/dev/null | grep -q yes || break; done
    rm -rf ~/$D.auto ~/$D.auto.dir
    (nohup ds9 -title $D -geometry 900x900 > $O/ds9.log 2>&1 &)
    for i in $(seq 1 600); do xpaaccess $D 2>/dev/null | grep -q yes && break; done
}

pass=0; fail=0
ok()  { echo "PASSED $1"; pass=$((pass+1)); }
bad() { echo "FAILED $1"; echo "       got: $2"; fail=$((fail+1)); }
eq()  { [[ "$2" == "$3" ]] && ok "$1" || bad "$1" "[$2] expected [$3]"; }
ne()  { [[ "$2" != "$3" ]] && ok "$1" || bad "$1" "both [$2]"; }
has() { [[ "$2" == *"$3"* ]] && ok "$1" || bad "$1" "[$2] lacks [$3]"; }
# frame command -> its result, or ERR:message
f() {
  printf 'set ch [open %s/f.txt w]\nif {[catch {$current(frame) %s} rr]} {puts -nonewline $ch "ERR:$rr"} else {puts -nonewline $ch $rr}\nclose $ch\n' "$O" "$1" | $X $D tcl 2>/dev/null
  cat $O/f.txt
}
# any tcl -> its result
tc() {
  printf 'set ch [open %s/f.txt w]\nif {[catch {%s} rr]} {puts -nonewline $ch "ERR:$rr"} else {puts -nonewline $ch $rr}\nclose $ch\n' "$O" "$1" | $X $D tcl 2>/dev/null
  cat $O/f.txt
}
lastid() { tc 'lindex [lindex [$current(frame) get contour aux] end] 0'; }
snap() { $X -p $D saveimage png $O/$1.png; shasum -a 256 $O/$1.png | cut -c1-16; }

CTR=$T/aux/ds9.ctr

echo
echo "*** auxcontour.sh ***"
launch
$X -p $D width 800
$X -p $D height 800

echo "== list, rows, as loaded"
$X -p $D fits $T/fits/img.fits
eq "no sets" "`f 'get contour aux'`" ""
blank=`snap blank`
f "contour load {$CTR}" > /dev/null
eq "list after load" "`f 'get contour aux'`" "{1 ds9.ctr 5}"
s1=`f 'get contour aux style 1'`
eq "rows of set 1" "$s1" "{-1 blue 1 0 8 3} {15.78775 red 1 0 8 3} {32.5755 yellow 1 0 8 3} {49.36325 cyan 1 0 8 3} {66.151 magenta 1 0 8 3}"
only1=`snap only1`
f "contour load {$CTR} red 2 yes" > /dev/null
eq "list after 2nd load" "`f 'get contour aux'`" "{1 ds9.ctr 5} {2 ds9.ctr 5}"
eq "override is set 2's style" "`f 'get contour aux style 2' | cut -c1-36`" "{-1 red 2 1 8 3} {15.78775 red 2 1 8"
both=`snap both`

echo "== restyle one row, reset it"
f 'contour aux style 1 2 white 3 1 4 2' > /dev/null
eq "row 2 restyled" "`tc 'lindex [$current(frame) get contour aux style 1] 2'`" "32.5755 white 3 1 4 2"
eq "row 1 untouched" "`tc 'lindex [$current(frame) get contour aux style 1] 1'`" "15.78775 red 1 0 8 3"
eq "set 2 untouched" "`f 'get contour aux style 2' | cut -c1-17`" "{-1 red 2 1 8 3} "
ne "restyle changes the render" "`snap r0`" "$both"
f 'contour aux reset 1 2' > /dev/null
eq "reset row: style" "`f 'get contour aux style 1'`" "$s1"
eq "reset row: render" "`snap r0b`" "$both"

echo "== restyle all, reset all"
f 'contour aux style 1 all white 2 0 8 3' > /dev/null
eq "all rows restyled" "`f 'get contour aux style 1'`" "{-1 white 2 0 8 3} {15.78775 white 2 0 8 3} {32.5755 white 2 0 8 3} {49.36325 white 2 0 8 3} {66.151 white 2 0 8 3}"
f 'contour aux reset 1' > /dev/null
eq "reset all: render" "`snap rab`" "$both"
f 'contour aux style 2 all white 1 0 8 3' > /dev/null
f 'contour aux reset 2' > /dev/null
eq "reset to the load override" "`f 'get contour aux style 2' | cut -c1-17`" "{-1 red 2 1 8 3} "

echo "== errors leave everything alone"
before=`f 'get contour aux style 1'`
has "bad color" "`f 'contour aux style 1 0 notacolor 1 0 8 3'`" "ERR:invalid color"
has "unknown set" "`f 'contour aux style 9 0 red 1 0 8 3'`" "ERR:no loaded contour set 9"
has "row out of range" "`f 'contour aux style 1 5 red 1 0 8 3'`" "ERR:no row 5"
has "width 0" "`f 'contour aux style 1 0 red 0 0 8 3'`" "ERR:invalid contour style"
has "dash list 0" "`f 'contour aux style 1 0 red 1 1 0 3'`" "ERR:invalid contour style"
has "reset unknown set" "`f 'contour aux reset 9'`" "ERR:no loaded contour set"
has "get style unknown set" "`f 'get contour aux style 9'`" "ERR:no loaded contour set"
has "delete unknown set" "`f 'contour delete aux 9'`" "ERR:no loaded contour set"
eq "no partial change" "`f 'get contour aux style 1'`" "$before"

echo "== rename"
f 'contour aux name 2 {{my set}}' > /dev/null
eq "rename" "`f 'get contour aux'`" "{1 ds9.ctr 5} {2 {my set} 5}"

echo "== save one set, delete by id"
f "contour save aux 1 {$O/one.ctr} wcs fk5" > /dev/null
f "contour save aux {$O/all.ctr} wcs fk5" > /dev/null
eq "save one set: levels" "`grep -c '^level' $O/one.ctr`" "5"
eq "save all: levels" "`grep -c '^level' $O/all.ctr`" "10"
eq "save one set: header" "`grep '^# levels' $O/one.ctr`" "# levels=( -1 15.7878 32.5755 49.3633 66.151 )"
f 'contour delete aux 2' > /dev/null
eq "delete set 2: list" "`f 'get contour aux'`" "{1 ds9.ctr 5}"
eq "delete set 2: render" "`snap d2`" "$only1"
f 'contour delete aux 1' > /dev/null
eq "delete set 1: has" "`f 'has contour aux'`" "0"
eq "delete set 1: render" "`snap d1`" "$blank"
f "contour load {$O/one.ctr}" > /dev/null
eq "ids not reused" "`f 'get contour aux'`" "{3 one.ctr 5}"
eq "saved set reloads the same" "`snap rl`" "$only1"
f 'contour delete aux' > /dev/null

echo "== empty file: no set"
: > $O/empty.ctr
f "contour load {$O/empty.ctr}" > /dev/null
eq "empty file adds no set" "`f 'get contour aux'`" ""

echo "== restyle, then convert to polygons"
f "contour load {$CTR}" > /dev/null
eq "a failed load uses no id" "`lastid`" "4"
f "contour aux style `lastid` all orange 2 0 8 3" > /dev/null
f 'contour create polygon' > /dev/null
reg=`$G $D regions -format ds9 -system wcs -sky fk5`
eq "polygons: no sets left" "`f 'get contour aux'`" ""
has "polygons take the restyled color" "$reg" "color=orange width=2"
eq "polygons: none in the file colors" "`echo "$reg" | grep -c 'color=red'`" "0"
$X -p $D regions delete all

echo "== mosaic file: one row per level value"
$X -p $D frame new
$X -p $D mosaicimage iraf $T/mosaic/ds9_8amp_2x2.fits
$X -p $D contour nlevels 3
$X -p $D contour yes
$X -p $D contour save $O/mos.ctr wcs fk5
$X -p $D contour no
nlev=`grep -c '^level' $O/mos.ctr`
f "contour load {$O/mos.ctr}" > /dev/null
eq "mosaic file: one row per distinct level" "`tc 'lindex [lindex [$current(frame) get contour aux] end] 2'`" "`grep '^level' $O/mos.ctr | sort -u | wc -l | tr -d ' '`"
ok "mosaic file has $nlev level blocks"
mid=`lastid`
lv=`tc 'lindex [lindex [$current(frame) get contour aux style '$mid'] 0] 0'`
ne "mosaic: got a level" "$lv" ""
f "contour aux style $mid 0 magenta 1 0 8 3" > /dev/null
f "contour save aux $mid {$O/mos2.ctr} wcs fk5" > /dev/null
n0=`grep -c "^level=$lv " $O/mos.ctr`
eq "mosaic row edit hits every tile" "`grep -c "^level=$lv color=magenta" $O/mos2.ctr`" "$n0"
$X -p $D frame delete

echo "== HEALPix: restyle survives a recentre"
# deleted sets' levels must not haunt a later load: their freed
# addresses get reused, and the sky copies are keyed by address
aw="$T/fits/wmap_ring.fits[system=galactic,proj=tan,fov=40"
$X -p $D frame delete all
$X -p $D frame new
$X -p $D fits "$aw]"
$X -p $D scale log
$X -p $D contour smooth 4
$X -p $D contour nlevels 3
$X -p $D contour yes
$X -p $D contour save $O/hpx.ctr wcs galactic
$X -p $D contour no
$X -p $D contour smooth 1
$X -p $D contour nlevels 5
hshot() { $X -p $D pan to $2 $3 wcs galactic; $X -p $D zoom to 2; snap $1; }
for i in 1 2 3; do
  f "contour load {$O/hpx.ctr}" > /dev/null
  id=`lastid`
  f "update fits center 10 5" > /dev/null
  f "update fits center 0 0" > /dev/null
  f "contour delete aux $id" > /dev/null
done
f "contour load {$O/hpx.ctr}" > /dev/null
id=`lastid`
f "contour aux style $id all red 2 0 8 3" > /dev/null
f "update fits center 10 5" > /dev/null
eq "hpx: style kept across recentre" "`tc 'lrange [lindex [$current(frame) get contour aux style '$id'] 0] 1 2'`" "red 2"
after=`hshot hpxa 10 5`
$X -p $D frame delete all
$X -p $D frame new
$X -p $D fits "$aw,lon0=10,lat0=5]"
$X -p $D scale log
f "contour load {$O/hpx.ctr}" > /dev/null
id=`lastid`
f "contour aux style $id all red 2 0 8 3" > /dev/null
eq "hpx: after deletes + recentre renders like a fresh load" "`hshot hpxf 10 5`" "$after"

echo "== Contour Parameters dialog"
$X -p $D frame delete all
$X -p $D frame new
$X -p $D fits $T/fits/img.fits
$X -p $D contour nlevels 4
$X -p $D contour yes
tc 'ContourDialog' > /dev/null
v() { tc "set ::dcontour($1)"; }
# menu helpers in ds9: invoke an entry by its exact label (Tk would take
# a label like 3 as an index), and list the entries' labels
tc 'proc ::auxmi {m lab} {
  for {set i 0} {$i <= [$m index end]} {incr i} {
    if {[$m type $i] ni {separator tearoff} && [$m entrycget $i -label] eq $lab} {
      return [$m invoke $i]
    }
  }
  error "no entry $lab"
}
proc ::auxml {m} {
  set rr {}
  for {set i 0} {$i <= [$m index end]} {incr i} {
    if {[$m type $i] ni {separator tearoff}} {lappend rr [$m entrycget $i -label]}
  }
  return $rr
}' > /dev/null
sets() { tc 'auxml $::dcontour(setmb).menu'; }
eq "dialog: starts on Generated" "`v setlabel`" "Generated"
eq "dialog: generated rows" "`v nrow`" "4"
# File > Open, keep the file's styles
tc "after 300 {set ::ed(original) 1; set ::ed(ok) 1}; ContourLoadNewDialog {$CTR}" > /dev/null
id=`lastid`
eq "dialog: a load selects the new set" "`v set`" "$id"
eq "dialog: set label" "`v setlabel`" "$id: ds9.ctr"
eq "dialog: one row per level" "`v nrow`" "5"
eq "dialog: rows show the set" "`v lev,1` `v color,1` `v width,1` `v dash,1`" "15.78775 red 1 solid"
eq "dialog: levels read-only" "`tc '$::dcontour(tbl).lev0 cget -state'`" "readonly"
eq "dialog: As Loaded, not Default" "`tc 'lindex [auxml $::dcontour(tbl).color0.menu] 0'` / `tc 'lindex [auxml $::dcontour(tbl).width0.menu] 0'` / `tc 'lindex [auxml $::dcontour(tbl).dash0.menu] 0'`" "As Loaded / As Loaded / As Loaded"
eq "dialog: Apply, Generate disabled" "`tc '.ct.buttons.apply cget -state'` `tc '.ct.buttons.generate cget -state'`" "disabled disabled"
eq "dialog: Levels slider disabled" "`tc '.ct.param.nslider.slider instate disabled'`" "1"
eq "dialog: Scale menu disabled" "`tc '.ctmb entrycget [.ctmb index Scale] -state'`" "disabled"
eq "dialog: Generate menu entry disabled" "`tc '.ctmb.file entrycget Generate -state'`" "disabled"
eq "dialog: Reset Level Styles enabled" "`tc '.ctmb.color entrycget {Reset Level Styles} -state'`" "normal"
eq "dialog: global colors disabled" "`tc '.ctmb.color entrycget Red -state'`" "disabled"
eq "dialog: Clear, Close enabled" "`tc '.ct.buttons.clear cget -state'` `tc '.ct.buttons.close cget -state'`" "normal normal"

tc 'auxmi $::dcontour(tbl).color2.menu Magenta' > /dev/null
eq "dialog: row color reaches the set" "`tc 'lindex [$current(frame) get contour aux style '$id'] 2 1'`" "magenta"
eq "dialog: swatch follows" "`tc '$::dcontour(tbl).swatch2 cget -background'`" "magenta"
tc 'auxmi $::dcontour(tbl).color2.menu {As Loaded}' > /dev/null
eq "dialog: As Loaded restores the row" "`tc 'lindex [$current(frame) get contour aux style '$id'] 2 1'` `v color,2`" "yellow yellow"
tc 'auxmi $::dcontour(tbl).width1.menu 3' > /dev/null
tc '$::dcontour(applyall) invoke' > /dev/null
eq "dialog: Apply Style to All" "`tc 'lsort -unique [lmap r [$current(frame) get contour aux style '$id'] {lrange $r 1 2}]'`" "{red 3}"
tc 'auxmi .ctmb.color {Reset Level Styles}' > /dev/null
eq "dialog: Reset Level Styles" "`tc 'lmap r [$current(frame) get contour aux style '$id'] {lindex $r 1}'`" "blue red yellow cyan magenta"
eq "dialog: table follows reset" "`v color,4` `v width,4`" "magenta 1"

tc 'auxmi $::dcontour(setmb).menu Generated' > /dev/null
eq "dialog: back to Generated" "`v setlabel` `v set`" "Generated "
# an edit not applied yet must survive looking at a loaded set
fvlev=`v lev,1`
tc 'set ::dcontour(lev,1) 123' > /dev/null
tc "auxmi \$::dcontour(setmb).menu {$id: ds9.ctr}" > /dev/null
eq "dialog: set chosen from the menu" "`v set`" "$id"
tc 'auxmi $::dcontour(setmb).menu Generated' > /dev/null
eq "dialog: unapplied edit kept" "`v lev,1`" "123"
eq "dialog: Apply enabled again" "`tc '.ct.buttons.apply cget -state'` `tc '.ctmb entrycget [.ctmb index Scale] -state'`" "normal normal"
eq "dialog: Default is back" "`tc 'lindex [auxml $::dcontour(tbl).color0.menu] 0'`" "Default"
tc "set ::dcontour(lev,1) $fvlev" > /dev/null

tc "ContourSetSelect $id" > /dev/null
$X -p $D contour nlevels 3
eq "dialog: a levels command shows Generated" "`v set` `v nrow`" " 3"
eq "dialog: and leaves the set alone" "`f 'get contour aux'`" "{$id ds9.ctr 5}"
tc "ContourSetSelect $id" > /dev/null
$X -p $D contour no
eq "dialog: contours off shows Generated" "`v set`" ""
$X -p $D contour yes
tc "ContourSetSelect $id" > /dev/null
tc '.ct.buttons.clear invoke' > /dev/null
eq "dialog: Clear deletes just the set" "`f 'get contour aux'` `f 'has contour'`" " 1"
eq "dialog: Clear goes back to Generated" "`v setlabel`" "Generated"

# Copy Contours here, paste into a new frame
tc 'ContourCCopyDialog' > /dev/null
src=`tc 'set ::current(frame)'`
$X -p $D frame new
$X -p $D fits $T/fits/img.fits
tc "after 300 {set ::ed2(original) 1; set ::ed2(ok) 1}; ContourCPasteDialog" > /dev/null
pid=`lastid`
eq "dialog: a paste is named for its frame" "`v setlabel`" "$pid: paste $src"
eq "dialog: paste selected" "`v set`" "$pid"
$X -p $D frame first
eq "dialog: frame change shows Generated" "`v set` `v setlabel`" " Generated"
eq "dialog: menu lists this frame's sets" "`sets`" "Generated"
$X -p $D frame last
eq "dialog: menu lists the other frame's set" "`sets`" "Generated {$pid: paste $src}"

# rgb: sets are per channel
$X -p $D frame delete all
$X -p $D rgb
$X -p $D rgb channel red
$X -p $D fits $T/fits/img.fits
tc "after 300 {set ::ed(original) 1; set ::ed(ok) 1}; ContourLoadNewDialog {$CTR}" > /dev/null
eq "rgb: red channel's set selected" "`v setlabel`" "1: ds9.ctr"
$X -p $D rgb channel green
eq "rgb: other channel shows Generated" "`v set` `sets`" " Generated"
$X -p $D rgb channel red
eq "rgb: back on red, set listed" "`sets`" "Generated {1: ds9.ctr}"
tc 'ContourSetSelect 1' > /dev/null
eq "rgb: set selected again" "`v set`" "1"
$X -p $D frame delete all
eq "no frame: Generated, nothing listed" "`v set` `sets`" " "
$X -p $D frame new
tc 'ContourDestroyDialog' > /dev/null

echo "== backup / restore: a file per set"
$X -p $D frame delete all
$X -p $D frame new
$X -p $D fits $T/fits/img.fits
# linear: a backup rounds the generated contours' levels to 6 digits, and
# log-spaced levels then regenerate slightly differently
$X -p $D scale linear
$X -p $D contour scale linear
$X -p $D contour nlevels 3
$X -p $D contour yes
f "contour load {$CTR}" > /dev/null
a=`lastid`
f "contour aux style $a 2 white 3 1 4 2" > /dev/null
f "contour load {$CTR} red 2 yes" > /dev/null
b=`lastid`
f "contour aux name $b {{my set}}" > /dev/null
# physical, as the backup writes it: a paste through fk5 lands up to
# ~1e-4 pixel off the backup's 8 digits, enough to flip a pixel or two
tc 'set ::cc [$current(frame) get contour physical fk5]' > /dev/null
f 'contour paste cc' > /dev/null
p=`lastid`
f "contour aux name $p {{paste Frame1}}" > /dev/null
list0=`tc 'lmap s [$current(frame) get contour aux] {lrange $s 1 end}'`
sty0=`tc 'lmap s [$current(frame) get contour aux] {$current(frame) get contour aux style [lindex $s 0]}'`
img0=`snap bk0`
rm -rf $O/bk.bck $O/bk.bck.dir
$X -p $D backup $O/bk.bck
eq "backup: a file per set" "`ls $O/bk.bck.dir/Frame1 | grep '^aux' | sort | tr '\n' ' '`" "aux$a.ctr aux$b.ctr aux$p.ctr "
has "backup: names restored, guarded" "`cat $O/bk.bck`" "catch {Frame1 contour aux name [lindex [lindex [Frame1 get contour aux] end] 0] {{my set}}}"
$X -p $D frame delete all
$X -p $D restore $O/bk.bck
eq "restore: sets and names" "`tc 'lmap s [$current(frame) get contour aux] {lrange $s 1 end}'`" "$list0"
eq "restore: styles" "`tc 'lmap s [$current(frame) get contour aux] {$current(frame) get contour aux style [lindex $s 0]}'`" "$sty0"
eq "restore: render" "`snap bk1`" "$img0"
eq "restore: generated contours too" "`f 'has contour'`" "1"
# a second backup over the first leaves no stale set files
f "contour delete aux `lastid`" > /dev/null
$X -p $D backup $O/bk.bck
eq "backup again: old set files gone" "`ls $O/bk.bck.dir/Frame1 | grep -c '^aux'`" "2"

echo "== backup / restore: rgb channels keep their own sets"
$X -p $D frame delete all
$X -p $D rgb
$X -p $D rgb channel red
$X -p $D fits $T/fits/img.fits
f "contour load {$CTR}" > /dev/null
f "contour aux name `lastid` {{red set}}" > /dev/null
$X -p $D rgb channel blue
$X -p $D fits $T/fits/img.fits
f "contour load {$CTR} cyan 2 no" > /dev/null
f "contour aux name `lastid` {{blue set}}" > /dev/null
$X -p $D rgb channel red
rgb0=`snap rgb0`
rm -rf $O/rgb.bck $O/rgb.bck.dir
$X -p $D backup $O/rgb.bck
$X -p $D frame delete all
$X -p $D restore $O/rgb.bck
$X -p $D rgb channel red
eq "rgb restore: red's set" "`tc 'lmap s [$current(frame) get contour aux] {lindex $s 1}'`" "{red set}"
eq "rgb restore: red's styles" "`tc 'lindex [$current(frame) get contour aux style 1] 1 1'`" "red"
$X -p $D rgb channel green
eq "rgb restore: green has none" "`f 'get contour aux'`" ""
$X -p $D rgb channel blue
eq "rgb restore: blue's set" "`tc 'lmap s [$current(frame) get contour aux] {lindex $s 1}'`" "{blue set}"
eq "rgb restore: blue's styles" "`tc 'lrange [lindex [$current(frame) get contour aux style 1] 1] 1 2'`" "cyan 2"
$X -p $D rgb channel red
eq "rgb restore: render" "`snap rgb1`" "$rgb0"
$X -p $D frame delete all
$X -p $D frame new

echo "== XPA: contour aux"
$X -p $D frame delete all
$X -p $D frame new
$X -p $D fits $T/fits/img.fits
$X -p $D contour load $CTR
$X -p $D contour load $CTR
eq "xpaget contour aux" "`$G $D contour aux`" "1 ds9.ctr 5
2 ds9.ctr 5"
eq "xpaget contour aux style" "`$G $D contour aux style 1 | sed -n 2p`" "1 15.78775 color=red width=1 dash=no dashlist=8 3"
$X -p $D contour aux style 1 2 white 3 yes 4 2
eq "positional style" "`$G $D contour aux style 1 | sed -n 3p`" "2 32.5755 color=white width=3 dash=yes dashlist=4 2"
$X -p $D contour aux style 1 all '{width=2}'
eq "keyword style, all rows, rest kept" "`$G $D contour aux style 1 | cut -d' ' -f3- | tr '\n' ';'`" "color=blue width=2 dash=no dashlist=8 3;color=red width=2 dash=no dashlist=8 3;color=white width=2 dash=yes dashlist=4 2;color=cyan width=2 dash=no dashlist=8 3;color=magenta width=2 dash=no dashlist=8 3;"
$X -p $D contour aux style 2 0 '{color=orange dash=yes}'
eq "keyword style, one row" "`$G $D contour aux style 2 | sed -n 1p`" "0 -1 color=orange width=1 dash=yes dashlist=8 3"
eq "other set untouched" "`$G $D contour aux style 1 | sed -n 1p`" "0 -1 color=blue width=2 dash=no dashlist=8 3"
$X -p $D contour aux reset 1 2
eq "reset row" "`$G $D contour aux style 1 | sed -n 3p`" "2 32.5755 color=yellow width=1 dash=no dashlist=8 3"
$X -p $D contour aux reset 1
eq "reset set" "`$G $D contour aux style 1 | sed -n 1p`" "0 -1 color=blue width=1 dash=no dashlist=8 3"
$X -p $D contour aux name 2 '{my set}'
$X -p $D contour aux name 1 renamed
eq "rename" "`$G $D contour aux`" "1 renamed 5
2 {my set} 5"
$X -p $D contour aux save 2 $O/xpa2.ctr wcs fk5
eq "save one set" "`grep -c '^level' $O/xpa2.ctr` `grep -c '^fk5' $O/xpa2.ctr`" "5 1"
has "error: unknown set" "`$X -p $D contour aux style 9 0 red 2>&1`" "no loaded contour set 9"
has "error: bad row" "`$X -p $D contour aux style 1 7 red 2>&1`" "Invalid contour level: 7"
has "error: bad color" "`$X -p $D contour aux style 1 0 notacolor 2>&1`" "invalid color notacolor"
has "error: get unknown set" "`$G $D contour aux style 9 2>&1`" "no loaded contour set 9"
eq "errors changed nothing" "`$G $D contour aux style 1 | sed -n 1p`" "0 -1 color=blue width=1 dash=no dashlist=8 3"
$X -p $D contour aux delete 1
eq "delete" "`$G $D contour aux`" "2 {my set} 5"
# the new keywords don't change the existing commands
$X -p $D contour nlevels 3
$X -p $D contour yes
eq "contour levels still parse" "`$G $D contour levels | tr '\n' ' '`" "-10 1693 3396  "
$X -p $D contour style 1 red 2
eq "contour style still parses" "`$G $D contour style`" "1 color=red width=2"
$X -p $D contour save $O/names.ctr
eq "a file named like a new keyword still saves" "`test -s $O/names.ctr && head -1 $O/names.ctr`" "# Contour file format: DS9 version 7.5"
$X -p $D contour clear

$X -p $D exit
echo "== command line: -contour aux"
(nohup ds9 -title $D -geometry 900x900 $T/fits/img.fits -contour load $CTR \
   -contour aux style 1 all 'color=green width=3' -contour aux name 1 'cmd line' \
   > $O/ds9.log 2>&1 &)
for i in $(seq 1 600); do xpaaccess $D 2>/dev/null | grep -q yes && break; done
for i in $(seq 1 600); do [[ -n "`$G $D contour aux 2>/dev/null`" ]] && break; done
eq "command line: set styled and named" "`$G $D contour aux` / `$G $D contour aux style 1 | sed -n 1p`" "1 {cmd line} 5 / 0 -1 color=green width=3 dash=no dashlist=8 3"
$X -p $D exit

rm -rf $O
echo
echo "$pass passed, $fail failed"
[[ $fail == 0 ]]
