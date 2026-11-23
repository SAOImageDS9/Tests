#!/bin/zsh
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
O=$(mktemp -d -t auxcontour)

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
eq "polygons: none in the file colors" "`echo $reg | grep -c 'color=red'`" "0"
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

$X -p $D exit
rm -rf $O
echo
echo "$pass passed, $fail failed"
[[ $fail == 0 ]]
