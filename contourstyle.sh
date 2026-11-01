#!/bin/zsh
# Per-level contour style tests (contour style, levels table, backup,
# 3D, mosaic, RGB), driven over XPA. Needs ds9 and the xpa tools on PATH.
# usage: contourstyle.sh
# Exits non-zero if any check fails. Work files go to a temp dir.

echo "Contour Style Tests"

X="xpaset"
G="xpaget"
D=DS9Test
IMG=fits/img.fits
CUBE=data/3d.fits
MOS=mosaic/ds9_8amp_2x2.fits
RGB=rgb
O=$(mktemp -d -t contourstyle)

pass=0; fail=0
ok()   { echo "PASSED $1"; pass=$((pass+1)); }
bad()  { echo "FAILED $1"; echo "       got: $2"; fail=$((fail+1)); }
eq()   { [[ "$2" == "$3" ]] && ok "$1" || bad "$1" "[$2] expected [$3]"; }
ne()   { [[ "$2" != "$3" ]] && ok "$1" || bad "$1" "both [$2]"; }
has()  { [[ "$2" == *"$3"* ]] && ok "$1" || bad "$1" "[$2] lacks [$3]"; }
sha()  { shasum -a 256 $1 | cut -c1-16; }
# run tcl in ds9, and return a value through a file
t()    { echo "$1" | $X $D tcl; }
tval() { t "set ::_f [open $O/tval w]; puts -nonewline \$::_f [eval {$1}]; close \$::_f"; cat $O/tval; }
snap() { $X -p $D saveimage png $O/$1.png; sha $O/$1.png; }
levlines() { grep '^level=' $1 | sort | uniq -c | sed 's/  */ /g' | tr '\n' ';'; }

launch() {
    $X -p $D exit 2>/dev/null
    for i in $(seq 1 300); do xpaaccess $D 2>/dev/null | grep -q yes || break; done
    (nohup ds9 -title $D "$@" > $O/ds9.log 2>&1 &)
    for i in $(seq 1 600); do xpaaccess $D 2>/dev/null | grep -q yes && break; done
}
# wait for the command line to be fully processed
settle() { for i in $(seq 1 600); do [[ -n "$(eval $1 2>/dev/null)" ]] && break; done; }
# wait until the current frame has contours, then let the canvas redraw
drawn() { for i in $(seq 1 600); do [[ "$(tval '$::current(frame) has contour' 2>/dev/null)" == 1 ]] && break; done; t 'update'; }

echo
echo "*** contourstyle.sh ***"

echo "== base frame: frame API"
launch -zscale $IMG -contour yes -contour nlevels 4
settle "$G $D contour levels"; drawn
base=$(snap base)
t '$::current(frame) contour style 0 red 3 -1 0 0'
t '$::current(frame) contour style 2 #0080ff 0 1 4 2'
eq "get contour style (overrides)" "$(tval '$::current(frame) get contour style')" "{0 red 3 -1 0 0} {2 #0080ff 0 1 4 2}"
eq "get contour style 2 (resolved)" "$(tval '$::current(frame) get contour style 2')" "#0080ff 1 1 4 2"
eq "get contour style 1 (global)" "$(tval '$::current(frame) get contour style 1')" "green 1 0 8 3"
styled=$(snap styled)
ne "styled render differs from base" $styled $base
$X -p $D contour save $O/styled.ctr
has ".ctr level= line carries style" "$(levlines $O/styled.ctr)" "color=#0080ff dash=1 dashlist=4 2"
$X -p $D contour color yellow
has "styles survive regeneration" "$(tval '$::current(frame) get contour style')" "{2 #0080ff 0 1 4 2}"
$X -p $D contour color green
eq "render same after color round trip" $(snap styled2) $styled
t '$::current(frame) contour style 2 clear'
eq "style <idx> clear" "$(tval '$::current(frame) get contour style')" "{0 red 3 -1 0 0}"
t '$::current(frame) contour style clear'
eq "style clear restores base render" $(snap cleared) $base
r=$(echo '$::current(frame) contour style 0 notacolor 1 -1 0 0' | $X $D tcl 2>&1)
has "invalid color rejected" "$r" "invalid color notacolor"
r=$(echo '$::current(frame) contour style -1 red 1 -1 0 0' | $X $D tcl 2>&1)
has "negative index rejected" "$r" "invalid contour style"
$X -p $D contour no
$X -p $D contour load $O/styled.ctr
# compare the files, not the renders: aux contours are drawn last level
# first, so where differently styled levels cross the top line differs
t "\$::current(frame) contour save aux {$O/aux.ctr} physical fk5"
cmp -s $O/styled.ctr $O/aux.ctr && ok "styled .ctr reloaded as aux saves identically" \
    || bad "styled .ctr reloaded as aux saves identically" "$(diff $O/styled.ctr $O/aux.ctr | head -3)"

echo "== command line, XPA, levels table"
launch -zscale $IMG -contour yes -contour nlevels 5 -contour style 0 red 3 \
    -contour style 1 'dash=yes dashlist=4 2' -contour style 3 yellow 4 yes 2 2 -contour open
settle "$G $D contour style | grep '^3 '"
eq "-contour style on command line" "$($G $D contour style | tr '\n' ';')" \
    "0 color=red width=3;1 dash=yes dashlist=4 2;3 color=yellow width=4 dash=yes dashlist=2 2;"
lv=$($G $D contour levels)
eq "xpaget contour levels is bare values" "$(echo $lv | grep -c '=') $(echo $lv | wc -l | tr -d ' ')" "0 5"
$X -p $D contour style 2 '{color=cyan width=2}'
has "xpaset keyword form" "$($G $D contour style | tr '\n' ';')" "2 color=cyan width=2;"
r=$($X -p $D contour style 9 red 2>&1)
has "out of range level rejected" "$r" "Invalid contour level"
eq "table matches frame" "$(tval 'lindex [ContourTableRead] 1')" \
    "{color=red width=3} {dash=yes dashlist=4 2} {color=cyan width=2} {color=yellow width=4 dash=yes dashlist=2 2} {}"
eq "Color menu: Default sits after the tearoff" "$(tval '$::dcontour(tbl).color0.menu entrycget 1 -label')" "Default"
t '$::dcontour(tbl).color4.menu invoke Magenta'
has "row menu restyles frame at once" "$($G $D contour style | tr '\n' ';')" "4 color=magenta;"
t '$::dcontour(tbl).color0.menu invoke Default'
eq "Default clears the row color" "$(tval '$::current(frame) get contour style 0')" "green 3 0 8 3"
live=$(snap live)
t ContourApplyDialog
eq "live restyle renders same as Apply" $(snap applied) $live
eq "swatch shows color" "$(tval '$::dcontour(tbl).swatch2 cget -background')" "cyan"
eq "swatch default shows global color" "$(tval '$::dcontour(tbl).swatch0 cget -background')" "green"
eq "no Add/Delete buttons" "$(tval 'llength [concat [info commands $::dcontour(tbl).del*] [info commands .ct.levels.add]]')" "0"
t 'set contour(numlevel) 3; ContourGenerateDialog'
eq "fewer levels keep first N styles" "$(tval 'lindex [ContourTableRead] 1')" \
    "width=3 {dash=yes dashlist=4 2} {color=cyan width=2}"
t 'set contour(numlevel) 5; ContourGenerateDialog; ContourApplyDialog'
eq "more levels get defaults" "$($G $D contour style | tr '\n' ';')" \
    "0 width=3;1 dash=yes dashlist=4 2;2 color=cyan width=2;"
$X -p $D contour save levels $O/t.lev
$X -p $D contour style clear
eq "style clear empties the table styles" "$($G $D contour style)" ""
$X -p $D contour load levels $O/t.lev
eq ".lev round trip" "$($G $D contour style | tr '\n' ';')" \
    "0 width=3;1 dash=yes dashlist=4 2;2 color=cyan width=2;"
$X -p $D contour levels "{$($G $D contour levels | tr '\n' ' ')}"
eq "contour levels keeps styles by index" "$($G $D contour style | tr '\n' ';')" \
    "0 width=3;1 dash=yes dashlist=4 2;2 color=cyan width=2;"
t 'ContourStyleClearDialog'
eq "Reset Level Styles" "$($G $D contour style)" ""

echo "== backup/restore (unset color)"
$X -p $D contour style 0 red 3
$X -p $D contour style 1 '{dash=yes dashlist=4 2}'
rm -rf $O/b.bck $O/b.bck.dir; $X -p $D backup $O/b.bck
has "backup writes empty color as {{}}" "$(grep 'contour style 1' $O/b.bck)" "contour style 1 {{}} 0 1 4 2"
$X -p $D contour style clear
$X -p $D restore $O/b.bck
eq "restore brings styles back" "$($G $D contour style | tr '\n' ';')" "0 color=red width=3;1 dash=yes dashlist=4 2;"
r1=$(snap bk_r1); $X -p $D restore $O/b.bck; r2=$(snap bk_r2)
eq "restore is repeatable" $r1 $r2
eq "table reflects restore" "$(tval 'lindex [ContourTableRead] 1')" "{color=red width=3} {dash=yes dashlist=4 2} {} {} {}"
t '$::current(frame) contour style clear'
rm -rf $O/u.bck $O/u.bck.dir; $X -p $D backup $O/u.bck
eq "unstyled backup has no style lines" "$(grep -c 'contour style' $O/u.bck)" "0"

echo "== invalid update keeps the previous style"
$X -p $D contour style clear
$X -p $D contour style 0 red 3
r=$($X -p $D contour style 0 notacolor 2>&1)
has "invalid style rejected" "$r" "Invalid contour level style"
eq "frame keeps the previous style" "$(tval '$::current(frame) get contour style')" "{0 red 3 -1 0 0}"
eq "table keeps the previous style" "$(tval 'lindex [ContourTableRead] 1 0')" "color=red width=3"

echo "== backup/restore with contours off"
$X -p $D contour no
$X -p $D contour style 1 cyan 2
rm -rf $O/off.bck $O/off.bck.dir; $X -p $D backup $O/off.bck
has "contours-off backup has styles" "$(grep 'contour style 1' $O/off.bck)" "contour style 1 cyan 2"
$X -p $D contour style clear
$X -p $D restore $O/off.bck
eq "contours-off restore keeps styles" "$($G $D contour style | tr '\n' ';')" "0 color=red width=3;1 color=cyan width=2;"
$X -p $D contour yes
eq "restored styles used when contours turn on" "$(tval '$::current(frame) get contour style')" "{0 red 3 -1 0 0} {1 cyan 2 -1 0 0}"

echo "== 3D cube, LOCAL scope slice change"
launch $CUBE -cube 1 -contour yes -contour scope local -contour nlevels 4 \
    -contour style 0 red -contour style 1 cyan -contour style 2 magenta -contour style 3 yellow
settle "$G $D contour style | grep '^3 '"
l1=$(tval '$::current(frame) get contour level')
$X -p $D contour save $O/c1.ctr
$X -p $D cube 20
l20=$(tval '$::current(frame) get contour level')
$X -p $D contour save $O/c20.ctr
ne "slice change regenerates levels" "$l1" "$l20"
eq "styles kept by index" "$(tval '$::current(frame) get contour style')" \
    "{0 red 0 -1 0 0} {1 cyan 0 -1 0 0} {2 magenta 0 -1 0 0} {3 yellow 0 -1 0 0}"
for s in 1 20; do
    n=$(grep -c '^level=' $O/c$s.ctr)
    eq "slice $s: every drawn level styled ($n)" "$(grep '^level=' $O/c$s.ctr | grep -vcE 'color=(red|cyan|magenta|yellow)')" "0"
done

echo "== mosaic (8 segments)"
launch -mosaicimage iraf $MOS -contour yes -contour nlevels 5
settle "$G $D contour levels | grep 61965"; drawn
mbase=$(snap mo_base)
$X -p $D contour style 1 red 3
$X -p $D contour style 3 '{color=cyan dash=yes dashlist=4 2}'
$X -p $D contour save $O/mo.ctr
eq "every segment styled" "$(levlines $O/mo.ctr)" \
    " 8 level=46029 ; 7 level=50013 color=red width=3 ; 7 level=53997 ; 6 level=57981 color=cyan dash=1 dashlist=4 2 ;"
mstyled=$(snap mo_styled)
ne "mosaic styled differs" $mstyled $mbase
$X -p $D contour color yellow; $X -p $D contour color green
eq "mosaic color round trip" $(snap mo_styled2) $mstyled
rm -rf $O/mo.bck $O/mo.bck.dir; $X -p $D backup $O/mo.bck
$X -p $D contour style clear
eq "mosaic clear == base" $(snap mo_clear) $mbase
$X -p $D restore $O/mo.bck
eq "mosaic restore == styled" $(snap mo_r) $mstyled

echo "== RGB (per channel)"
launch -rgb -red $RGB/red.fits -green $RGB/green.fits -blue $RGB/blue.fits -zoom to fit -rgb channel red
settle "$G $D rgb channel | grep red"; settle "$G $D fits size"
for c in red green blue; do
    $X -p $D rgb channel $c
    for i in $(seq 1 20); do
	$X -p $D contour yes; $X -p $D contour nlevels 4
	[[ "$($G $D contour)" == yes ]] && break
    done
done
for c in red green blue; do $X -p $D rgb channel $c; eq "$c channel contours on" "$($G $D contour)" yes; done
$X -p $D rgb channel red;   $X -p $D contour style 0 red 3
$X -p $D rgb channel green; $X -p $D contour style 1 green 2 yes
$X -p $D rgb channel blue;  $X -p $D contour style 2 '{color=#0080ff dash=yes dashlist=2 2}'
perch() { tval 'set fr $::current(frame); set sv [$fr get rgb channel]; set r {}; foreach c {red green blue} {$fr rgb channel $c; lappend r [$fr get contour style]}; $fr rgb channel $sv; set r'; }
want="{{0 red 3 -1 0 0}} {{1 green 2 1 0 0}} {{2 #0080ff 0 1 2 2}}"
eq "each channel keeps its own styles" "$(perch)" "$want"
$X -p $D rgb channel green
eq "table follows channel" "$(tval 'lindex [ContourTableRead] 1 1')" "color=green width=2 dash=yes"
for c in green blue; do $X -p $D rgb channel $c; eval "s_$c=\$(snap rgb_${c}_s)"; done
rm -rf $O/rgb.bck $O/rgb.bck.dir; $X -p $D backup $O/rgb.bck
for c in red green blue; do $X -p $D rgb channel $c; $X -p $D contour style clear; done
for c in green blue; do $X -p $D rgb channel $c; eval "c_$c=\$(snap rgb_${c}_c)"; done
ne "green styled differs from cleared" $s_green $c_green
ne "blue styled differs from cleared" $s_blue $c_blue
$X -p $D restore $O/rgb.bck; $X -p $D zoom to fit
eq "restore brings back every channel" "$(perch)" "$want"
for c in green blue; do $X -p $D rgb channel $c; eval "r_$c=\$(snap rgb_${c}_r)"; done
eq "green restored render == styled" $r_green $s_green
eq "blue restored render == styled" $r_blue $s_blue

echo "== contours off: styles stay with their frame/channel"
$X -p $D rgb channel red; $X -p $D contour no; $X -p $D contour style clear
$X -p $D rgb channel green
$X -p $D rgb channel red
eq "table shows this channel's styles, not the last one's" "$(tval 'lindex [ContourTableRead] 1')" "{} {} {} {}"
$X -p $D contour style 0 red 3
eq "style reaches the frame with contours off" "$(tval '$::current(frame) get contour style')" "{0 red 3 -1 0 0}"
$X -p $D rgb channel green; $X -p $D rgb channel red
eq "style survives switching away and back" "$(tval 'lindex [ContourTableRead] 1 0')" "color=red width=3"
rm -rf $O/rgboff.bck $O/rgboff.bck.dir; $X -p $D backup $O/rgboff.bck
$X -p $D contour style clear
$X -p $D restore $O/rgboff.bck
eq "contours-off RGB restore keeps styles" "$(tval '$::current(frame) get contour style')" "{0 red 3 -1 0 0}"
$X -p $D contour yes
eq "style used when contours turn on" "$(tval '$::current(frame) get contour style')" "{0 red 3 -1 0 0}"

$X -p $D exit
rm -rf $O
echo
echo "$pass passed, $fail failed"
[[ $fail == 0 ]]
