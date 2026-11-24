#!/bin/zsh
# GHS (Generalized Hyperbolic Stretch) scale tests: the transfer curve
# (tksao/frame/ghs.h, compiled standalone), set/get over XPA and the
# command line, rendering and banding, colorbar inverse, match/lock,
# backup/restore, contours, RGB and 3D frames, the GHS Parameters dialog,
# and the scale function and LP/SP/HP handles on the Scale dialog graph.
# Needs ds9 and the xpa tools on PATH, and a C++ compiler for the curve
# checks (skipped if ../tksao/frame/ghs.h or c++ is missing).
# usage: ghs.sh
# Exits non-zero if any check fails. Work files go to a temp dir.

echo "GHS Scale Tests"
zmodload zsh/mathfunc

X="xpaset"
G="xpaget"
D=DS9Test
SKY=ghs/sky.fits          # made by ghs/mksky.py; minmax 92.5 .. 100105.8
O=$(mktemp -d -t ghs)

pass=0; fail=0
ok()   { echo "PASSED $1"; pass=$((pass+1)); }
bad()  { echo "FAILED $1"; echo "       got: $2"; fail=$((fail+1)); }
eq()   { [[ "$2" == "$3" ]] && ok "$1" || bad "$1" "[$2] expected [$3]"; }
ne()   { [[ "$2" != "$3" ]] && ok "$1" || bad "$1" "both [$2]"; }
has()  { [[ "$2" == *"$3"* ]] && ok "$1" || bad "$1" "[$2] lacks [$3]"; }
# numeric test, e.g. num "name" "$v < 20"
num()  { (( $2 )) && ok "$1" || bad "$1" "$2 is false"; }
sha()  { shasum -a 256 $1 | cut -c1-16; }
# run tcl in ds9, and return a value through a file
t()    { echo "$1" | $X $D tcl; }
tval() { t "set ::_f [open $O/tval w]; puts -nonewline \$::_f [eval {$1}]; close \$::_f"; cat $O/tval; }
snap() { $X -p $D saveimage png $O/$1.png; sha $O/$1.png; }
# export writes the frame at one pixel per data pixel (via savePhoto)
xport() { $X -p $D export png $O/$1.png; }

launch() {
    $X -p $D exit 2>/dev/null
    for i in $(seq 1 300); do xpaaccess $D 2>/dev/null | grep -q yes || break; done
    (nohup ds9 -title $D "$@" > $O/ds9.log 2>&1 &)
    for i in $(seq 1 600); do xpaaccess $D 2>/dev/null | grep -q yes && break; done
}
# wait for the command line to be fully processed
settle() { for i in $(seq 1 600); do [[ -n "$(eval $1 2>/dev/null)" ]] && break; done; }

# Tcl helpers loaded into ds9
helpers() {
    cat > $O/helpers.tcl <<'EOF'
# grey levels in a sky patch of an exported png (data x 200-249, y 200-249;
# png rows are flipped). Returns the number of levels holding >= 0.5% of
# the patch, so a few star or noise pixels don't count.
proc skylevels {file} {
    set ph [image create photo -file $file]
    set hh [image height $ph]
    for {set yy 200} {$yy < 250} {incr yy} {
	for {set xx 200} {$xx < 250} {incr xx} {
	    incr cnt([lindex [$ph get $xx [expr {$hh-1-$yy}]] 0])
	}
    }
    image delete $ph
    set nn 0
    foreach kk [array names cnt] {if {$cnt($kk) >= 13} {incr nn}}
    return $nn
}
# largest per-pixel grey difference between two pngs
proc maxdiff {a b} {
    set pa [image create photo -file $a]
    set pb [image create photo -file $b]
    set mx 0
    for {set yy 0} {$yy < [image height $pa]} {incr yy 3} {
	for {set xx 0} {$xx < [image width $pa]} {incr xx 3} {
	    set dd [expr {abs([lindex [$pa get $xx $yy] 0]-[lindex [$pb get $xx $yy] 0])}]
	    if {$dd > $mx} {set mx $dd}
	}
    }
    image delete $pa $pb
    return $mx
}
# 1 if the list is non-decreasing
proc rising {ll} {
    set pp -Inf
    foreach vv $ll {if {$vv < $pp} {return 0}; set pp $vv}
    return 1
}
# synthesize a real mouse drag on GHS handle mm to data value x2, so BLT's
# own marker picking and stacking are exercised
proc drag {mm x2} {
    set g $::dscale(hist)
    set c [$g marker cget $::dscale(ghs${mm}handle) -coords]
    set x0 [expr {round([$g axis transform x [lindex $c 0]])}]
    set y0 [expr {round([$g axis transform y2 [lindex $c 1]])}]
    switch -- [$g marker cget $::dscale(ghs${mm}handle) -anchor] {
	s {incr y0 -8}
	n {incr y0 8}
    }
    set x1 [expr {round([$g axis transform x $x2])}]
    event generate $g <Enter> -x $x0 -y $y0
    event generate $g <Motion> -x $x0 -y $y0
    event generate $g <ButtonPress-1> -x $x0 -y $y0
    foreach f {.25 .5 .75 1} {
	event generate $g <B1-Motion> -x [expr {round($x0+($x1-$x0)*$f)}] \
	    -y $y0 -state 256
	update
    }
    event generate $g <ButtonRelease-1> -x $x1 -y $y0
    update
}
EOF
    t "source $O/helpers.tcl"
}

echo
echo "*** ghs.sh ***"

echo "== curve (ghs.h)"
if [[ -f ../tksao/frame/ghs.h ]] && command -v c++ > /dev/null; then
    if c++ -std=c++11 -O2 -I../tksao/frame ghs/ghscurve.C -o $O/ghscurve 2> $O/cc.log; then
	$O/ghscurve > $O/curve.out
	cat $O/curve.out | grep -v ' failed$'
	pass=$((pass+$(grep -c '^PASSED' $O/curve.out)))
	fail=$((fail+$(grep -c '^FAILED' $O/curve.out)))
    else
	bad "ghscurve.C compiles" "$(head -3 $O/cc.log)"
    fi
else
    echo "SKIPPED (no ../tksao/frame/ghs.h or c++)"
fi

echo "== XPA set/get"
launch $SKY
settle "$G $D scale"
helpers
eq "default scale type" "$($G $D scale)" "linear"
eq "default parameters" "$($G $D scale ghs)" "5 0 auto auto auto"
$X -p $D scale ghs
eq "scale ghs selects GHS" "$($G $D scale)" "ghs"
$X -p $D scale ghs stretch 8
$X -p $D scale ghs intensity 5
$X -p $D scale ghs sp 101.1
$X -p $D scale ghs lp 99
$X -p $D scale ghs hp 200
eq "xpaget scale ghs" "$($G $D scale ghs)" "8 5 101.1 99 200"
eq "xpaget scale ghs stretch" "$($G $D scale ghs stretch)" "8"
eq "xpaget scale ghs intensity" "$($G $D scale ghs intensity)" "5"
eq "xpaget scale ghs sp" "$($G $D scale ghs sp)" "101.1"
eq "xpaget scale ghs lp" "$($G $D scale ghs lp)" "99"
eq "xpaget scale ghs hp" "$($G $D scale ghs hp)" "200"
eq "frame holds the parameters" "$(tval '$::current(frame) get colorscale ghs')" "8 5 101.1 99 200"
$X -p $D scale ghs lp auto
$X -p $D scale ghs hp auto
eq "auto round trip" "$($G $D scale ghs)" "8 5 101.1 auto auto"
$X -p $D scale linear
$X -p $D scale ghs stretch 6
eq "setting a parameter keeps the scale type" "$($G $D scale)" "linear"
eq "... but stores the parameter" "$($G $D scale ghs stretch)" "6"
r=$($X -p $D scale ghs sp foo 2>&1)
has "non-numeric sp rejected" "$r" "parse error"
r=$($X -p $D scale ghs stretch auto 2>&1)
has "auto stretch rejected" "$r" "parse error"
r=$(echo '$::current(frame) colorscale ghs 5 0 foo auto auto' | $X $D tcl 2>&1)
has "frame command rejects bad value" "$r" "error"
$X -p $D scale ghs stretch 8
$X -p $D scale ghs
$X -p $D contour scale ghs
eq "contour scale ghs" "$($G $D contour scale)" "ghs"

echo "== command line"
launch $SKY -scale ghs -scale ghs stretch 7 -scale ghs intensity 3 -scale ghs sp 101.5 -scale ghs hp 400
settle "$G $D scale ghs | grep 400"
helpers
eq "-scale ghs ..." "$($G $D scale) $($G $D scale ghs)" "ghs 7 3 101.5 auto 400"

echo "== rendering (minmax limits; sky is narrower than a 16384-entry table step)"
$X -p $D scale linear
$X -p $D scale minmax
xport lin
$X -p $D scale ghs stretch 0
$X -p $D scale ghs sp auto
$X -p $D scale ghs hp auto
$X -p $D scale ghs
xport id
num "stretch 0 renders like linear (<= 1 grey level)" "$(tval "maxdiff $O/id.png $O/lin.png") <= 1"
$X -p $D scale ghs stretch 8
$X -p $D scale ghs intensity 5
$X -p $D scale ghs sp 101.1
xport s8
ne "stretch 8 differs from linear" "$(sha $O/s8.png)" "$(sha $O/lin.png)"
lv=$(tval "skylevels $O/s8.png")
num "stretch 8: sky noise spread over >= 15 grey levels (old table: 2) [$lv]" "$lv >= 15"
num "linear: sky is flat [$(tval "skylevels $O/lin.png")]" "$(tval "skylevels $O/lin.png") <= 2"
for b in -1 -3 0 1 12; do
    $X -p $D scale ghs intensity $b
    xport b$b
done
ne "b=-1 differs from b=0" "$(sha $O/b-1.png)" "$(sha $O/b0.png)"
ne "b=-3 differs from b=-1" "$(sha $O/b-3.png)" "$(sha $O/b-1.png)"
ne "b=1 differs from b=12" "$(sha $O/b1.png)" "$(sha $O/b12.png)"
$X -p $D scale ghs intensity 5
s1=$(snap screen8)
$X -p $D scale ghs stretch 4
ne "stretch change re-renders the canvas" "$(snap screen4)" "$s1"
$X -p $D scale ghs stretch 8
$X -p $D scale mode 99.5
eq "clip mode change keeps GHS" "$($G $D scale) $($G $D scale ghs)" "ghs 8 5 101.1 auto auto"
xport c995
ne "new limits re-render" "$(sha $O/c995.png)" "$(sha $O/s8.png)"
$X -p $D scale mode minmax

echo "== colorbar / inverse"
lims=($($G $D scale limits))
lev=$(tval "\$::current(frame) get colorscale level 5 $lims[1] $lims[2] ghs 1000")
levs=(${=lev})
eq "inverse has 5 levels" "${#levs}" "5"
eq "inverse is non-decreasing" "$(tval "rising {$lev}")" "1"
num "inverse starts at low [$levs[1]]" "abs($levs[1] - $lims[1]) < 1e-3"
num "inverse ends at high [$levs[5]]" "abs($levs[5] - $lims[2]) < 1"
num "inverse bunches near the sky: 25% level < 110 [$levs[2]]" "$levs[2] < 110"
linlev=($(tval "\$::current(frame) get colorscale level 5 $lims[1] $lims[2] linear 1000"))
num "linear 25% level is far above [$linlev[2]]" "$linlev[2] > 20000"
# colorbar labels come from the inverse; contrast/bias recolours the cells
# but must not move the labels
cbv='lassign [$::ds9(canvas) bbox $::current(colorbar)] x0 y0 x1 y1; lmap fr {.1 .25 .5 .75 .9} {$::current(colorbar) get value [expr {round($x0+($x1-$x0)*$fr)}] [expr {($y0+$y1)/2}]}'
cb1=$(tval "$cbv")
cbs=(${=cb1})
num "colorbar values follow the GHS curve: 25% < 110, 75% > 500 [$cb1]" "$cbs[2] < 110 && $cbs[4] > 500"
$X -p $D cmap value 2 0.3
eq "colorbar values unchanged by contrast/bias" "$(tval "$cbv")" "$cb1"
$X -p $D cmap value 1 0.5

echo "== match / lock"
$X -p $D frame new
$X -p $D fits $SKY
$X -p $D scale linear
$X -p $D scale ghs stretch 3
$X -p $D frame first
$X -p $D scale match
$X -p $D frame last
eq "scale match copies type and parameters" "$($G $D scale) $($G $D scale ghs)" "ghs 8 5 101.1 auto auto"
$X -p $D scale lock yes
$X -p $D scale ghs stretch 4.5
$X -p $D frame first
eq "scale lock propagates parameters" "$($G $D scale ghs stretch)" "4.5"
$X -p $D scale lock no
$X -p $D scale ghs stretch 8
$X -p $D frame last
$X -p $D frame delete
$X -p $D frame first

echo "== backup / restore"
rm -rf $O/b.bck $O/b.bck.dir
$X -p $D backup $O/b.bck
has "backup writes the parameters" "$(grep 'colorscale ghs ' $O/b.bck)" "colorscale ghs 8 5 101.1 auto auto"
$X -p $D scale linear
$X -p $D scale ghs stretch 2
$X -p $D restore $O/b.bck
settle "$G $D scale | grep ghs"
eq "restore brings them back" "$($G $D scale) $($G $D scale ghs)" "ghs 8 5 101.1 auto auto"
helpers

echo "== contours"
$X -p $D contour scale ghs
$X -p $D contour mode minmax
$X -p $D contour nlevels 5
$X -p $D contour yes
$X -p $D contour generate
cl=($($G $D contour levels))
eq "5 contour levels" "${#cl}" "5"
num "contour levels bunch near the sky: 2nd < 150 [$cl[2]]" "$cl[2] < 150"
$X -p $D contour no

echo "== RGB frame"
$X -p $D frame new rgb
$X -p $D rgb channel red
$X -p $D fits $SKY
$X -p $D rgb channel green
$X -p $D fits $SKY
$X -p $D rgb lock scale no
$X -p $D rgb channel red
$X -p $D scale minmax
$X -p $D scale ghs stretch 8
$X -p $D scale ghs sp 101.1
$X -p $D scale ghs
$X -p $D rgb channel green
$X -p $D scale linear
eq "green channel keeps its own scale" "$($G $D scale)" "linear"
$X -p $D rgb channel red
eq "red channel is GHS" "$($G $D scale) $($G $D scale ghs stretch)" "ghs 8"
rg=$(snap rgbghs)
$X -p $D scale linear
ne "GHS on a channel changes the RGB render" "$(snap rgblin)" "$rg"
$X -p $D frame delete
$X -p $D frame first

echo "== 3D frame"
$X -p $D frame new 3d
$X -p $D fits $SKY
$X -p $D scale minmax
$X -p $D scale linear
l3=$(snap 3dlin)
$X -p $D scale ghs
eq "3D frame accepts GHS" "$($G $D scale)" "ghs"
ne "GHS changes the 3D render" "$(snap 3dghs)" "$l3"
$X -p $D frame delete
$X -p $D frame first

echo "== GHS Parameters dialog"
$X -p $D scale linear
$X -p $D scale ghs stretch 8
t ScaleGhsDialog
eq "dialog is not modal (XPA still answers)" "$(tval 'winfo exists .ghs')" "1"
t 'set ::dghs(stretch) 6.123456; ScaleGhsLiveDialog; set ::dghs(stretch) 6.2; ScaleGhsLiveDialog; update'
eq "slider applies live and selects GHS" "$($G $D scale) $($G $D scale ghs stretch)" "ghs 6.2"
t 'set ::dghs(stretch) 6.123456; ScaleGhsLiveDialog; update'
eq "slider value rounded to 0.01" "$(tval 'set ::dghs(stretch)')" "6.12"
t 'set ::dghs(sp) 105; ScaleGhsApplyDialog'
eq "Apply takes the entries" "$($G $D scale ghs sp)" "105"
t 'set ::dghs(sp) bogus; set ::dghs(intensity) 2; ScaleGhsLiveDialog; update'
eq "invalid entry: live update does nothing" "$($G $D scale ghs)" "6.12 5 105 auto auto"
t 'ScaleGhsResetDialog; update'
eq "Reset restores parameters and scale type" "$($G $D scale) $($G $D scale ghs)" "linear 8 5 101.1 auto auto"
$X -p $D scale ghs sp 103
eq "dialog follows the frame" "$(tval 'set ::dghs(sp)')" "103"
t ScaleGhsDestroyDialog
eq "Close removes it" "$(tval 'winfo exists .ghs')" "0"
$X -p $D scale ghs sp 101.1

echo "== Scale dialog graph"
# user limits, so one graph pixel is under a data unit (with minmax it is ~280)
$X -p $D scale limits 90 300
$X -p $D scale open
t 'set ::scale(xaxis) current; ScaleXAxisDialog; update'
eq "curve drawn for linear" "$(tval '$::dscale(hist) element cget curve -hide')" "0"
eq "curve has 259 points" "$(tval '$::dscale(curvex) length')" "259"
eq "curve y runs 0 to 1" "$(tval 'list [$::dscale(curvey) index 0] [$::dscale(curvey) index end]')" "0.0 1.0"
eq "curve drawn on top of the histogram" "$(tval 'lindex [$::dscale(hist) element show] 0')" "curve"
eq "no handles for linear" "$(tval '$::dscale(hist) marker cget $::dscale(ghssphandle) -hide')" "1"
mid=$(tval 'ScaleCurveAt [expr {($::dscale(min)+$::dscale(max))/2.}]')
num "linear curve is 0.5 mid-range [$mid]" "abs($mid - 0.5) < 0.01"
$X -p $D scale ghs
t update
eq "handles shown for GHS" "$(tval 'lmap m {lp sp hp} {$::dscale(hist) marker cget $::dscale(ghs${m}handle) -hide}')" "0 0 0"
eq "SP guide line shown (data value)" "$(tval '$::dscale(hist) marker cget $::dscale(ghssp) -hide')" "0"
eq "LP guide line hidden (auto)" "$(tval '$::dscale(hist) marker cget $::dscale(ghslp) -hide')" "1"
eq "handle stacking: limits, then LP, HP, SP" "$(tval 'set n [$::dscale(hist) marker names]; list [lsearch $n $::dscale(histmax)] [lsearch $n $::dscale(ghslphandle)] [lsearch $n $::dscale(ghshphandle)] [lsearch $n $::dscale(ghssphandle)]')" "3 2 1 0"
lims=$($G $D scale limits)
t 'drag sp 120'
spv=$($G $D scale ghs sp)
num "drag SP to 120 [$spv]" "abs($spv - 120) < 5"
t 'drag lp 105'
lpv=$($G $D scale ghs lp)
num "drag LP (from auto, at the plot bottom) to 105 [$lpv]" "abs($lpv - 105) < 5"
t 'drag hp 250'
hpv=$($G $D scale ghs hp)
num "drag HP (from auto, at the plot top) to 250 [$hpv]" "abs($hpv - 250) < 5"
t 'drag lp 280'
eq "LP stops at SP" "$($G $D scale ghs lp)" "$($G $D scale ghs sp)"
t 'drag hp 50'
eq "HP stops at SP" "$($G $D scale ghs hp)" "$($G $D scale ghs sp)"
t 'drag sp 1e6'
eq "SP stops at HP" "$($G $D scale ghs sp)" "$($G $D scale ghs hp)"
eq "dragging leaves the clip limits alone" "$($G $D scale limits)" "$lims"
$X -p $D scale close
$X -p $D scale minmax

echo "== preferences"
eq "pscale GHS defaults" "$(tval 'lmap k {stretch intensity sp lp hp} {set ::pscale(ghs,$k)}')" "5 0 auto auto auto"

$X -p $D exit
rm -rf $O
echo
echo "$pass passed, $fail failed"
[[ $fail == 0 ]]
