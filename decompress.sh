#!/bin/bash
# Compressed non-FITS files: regions, Prism (FITS tables and VOT/TSV/RDB
# imports), catalogs, plot data, contour files and contour levels. Each
# compressed load is compared with loading the same file uncompressed.
# gzip is decoded inside ds9 and must work everywhere; bzip2, .Z, xz and
# zstd are decoded by the matching program, so a format is skipped when
# its compressor is not installed here.
# Driven over XPA; needs ds9 and the xpa tools on PATH. Run from Tests/.
# usage: decompress.sh
# Exits non-zero if any check fails. Work files go to a temp dir.

echo "Decompress Tests"

T=$PWD
# ds9 resolves these paths itself; a native Windows build needs the
# C:/... form (see auxcontour.sh)
if command -v cygpath > /dev/null 2>&1; then
    T=$(cygpath -m "$T")
fi
X="xpaset"
G="xpaget"
D=DS9Test
O=$(mktemp -d "${TMPDIR:-/tmp}/decompress.XXXXXX")
if command -v cygpath > /dev/null 2>&1; then
    O=$(cygpath -m "$O")
fi

launch() {
    $X -p $D exit 2>/dev/null
    for i in $(seq 1 300); do xpaaccess $D 2>/dev/null | grep -q yes || break; sleep 0.1; done
    (nohup ds9 -title $D "$@" > $O/ds9.log 2>&1 &)
    for i in $(seq 1 600); do xpaaccess $D 2>/dev/null | grep -q yes && break; sleep 0.1; done
}
quit() {
    $X -p $D exit 2>/dev/null
    for i in $(seq 1 300); do xpaaccess $D 2>/dev/null | grep -q yes || break; sleep 0.1; done
}

pass=0; fail=0
ok()  { echo "PASSED $1"; pass=$((pass+1)); }
bad() { echo "FAILED $1"; echo "       got: $2"; fail=$((fail+1)); }
eq()  { [[ "$2" == "$3" ]] && ok "$1" || bad "$1" "[$2] expected [$3]"; }
ne()  { [[ "$2" != "$3" ]] && ok "$1" || bad "$1" "both [$2]"; }
has() { [[ "$2" == *"$3"* ]] && ok "$1" || bad "$1" "[$2] lacks [$3]"; }
# any tcl -> its result, or ERR:message
tc() {
  printf 'set ch [open %s/f.txt w]\nif {[catch {%s} rr]} {puts -nonewline $ch "ERR:$rr"} else {puts -nonewline $ch $rr}\nclose $ch\n' "$O" "$1" | $X $D tcl 2>/dev/null
  cat $O/f.txt
}
snap() { $X -p $D saveimage png $O/$1.png; shasum -a 256 $O/$1.png | cut -c1-16; }

# compressed copies of $1 in $O, one per compressor found
F=$O/fx
mkdir -p $F
ZIPS=""
for z in gzip:gz bzip2:bz2 compress:Z xz:xz zstd:zst; do
    command -v ${z%:*} > /dev/null 2>&1 && ZIPS="$ZIPS ${z#*:}"
done
squeeze() {
    for s in $ZIPS; do
	case $s in
	    gz)  gzip -c $F/$1 > $F/$1.gz ;;
	    bz2) bzip2 -c $F/$1 > $F/$1.bz2 ;;
	    Z)   compress -c $F/$1 > $F/$1.Z ;;
	    xz)  xz -c $F/$1 > $F/$1.xz ;;
	    zst) zstd -qc $F/$1 > $F/$1.zst ;;
	esac
    done
}
has_zip() { [[ " $ZIPS " == *" $1 "* ]]; }
# temp dirs ds9 made since this run started
newtmp() { find "$TMPD" -maxdepth 1 -type d -name 'ds9[0-9]*' -newer $O/start 2>/dev/null | wc -l | tr -d ' '; }

echo
echo "*** decompress.sh ***"
echo "compressors:$ZIPS"
if ! has_zip gz; then
    echo "FAILED no gzip to make test files"
    exit 1
fi

cp $T/regions/ds9.fk5.reg $F/r.reg
cp $T/fits/table.fits $F/table.fits
cp $T/plot/xy.dat $F/xy.dat
cp $T/aux/ds9.ctr $T/aux/ds9.con $T/aux/ds9.lev $F
for f in r.reg table.fits xy.dat ds9.ctr ds9.con ds9.lev; do squeeze $f; done
# gzip data under a plain name: the format comes from the bytes
gzip -c $F/r.reg > $F/gzipped.reg
gzip -c $F/r.reg | head -c 200 > $F/trunc.reg.gz
mkdir -p "$F/sp ace"
gzip -c $F/r.reg > "$F/sp ace/r 1.reg.gz"

touch $O/start
sleep 1
launch
TMPD=$(tc 'set ds9(tmpdir)')

echo "== regions"
$X -p $D fits $T/fits/img.fits
$X -p $D regions format ds9
reg() { $X -p $D regions deleteall; $X -p $D regions file "$1"; $G $D regions -format ds9 -system wcs -sky fk5; }
plain=$(reg $F/r.reg)
ne "plain region loads" "$plain" ""
for s in $ZIPS; do
    eq "region .$s" "$(reg $F/r.reg.$s)" "$plain"
done
eq "gzip region named .reg" "$(reg $F/gzipped.reg)" "$plain"
$X -p $D regions deleteall
tc "MarkerLoadFrames {$F/sp ace/r 1.reg.gz} \$current(frame) ds9 wcs fk5" > /dev/null
eq "region .gz, spaces in path" "$($G $D regions -format ds9 -system wcs -sky fk5)" "$plain"
eq "file dialog keeps the .gz name" "$(tc 'file join $markerfbox(dir) $markerfbox(file)')" "$F/sp ace/r 1.reg.gz"
$X -p $D regions deleteall
has "truncated .gz region errors" "$($X -p $D regions file $F/trunc.reg.gz 2>&1)" "Unable to load compressed region file"
tc 'set errorInfo {}' > /dev/null
eq "truncated .gz loads nothing" "$($G $D regions -format ds9 | grep -c circle)" "0"
$X -p $D regions deleteall

echo "== prism, FITS table"
pstate() { tc 'set v [lindex $iprism(prisms) end]; list [set ${v}(extnames)] [set ${v}(rows)]'; }
$X -p $D prism $F/table.fits
plain=$(pstate)
$X -p $D prism close
ne "plain table loads" "$plain" ""
for s in $ZIPS; do
    $X -p $D prism $F/table.fits.$s
    eq "prism table .$s" "$(pstate)" "$plain"
    $X -p $D prism close
done
eq "no temp dirs after prism close" "$(newtmp)" "0"
if has_zip bz2; then
    $X -p $D prism $F/table.fits.bz2
    eq "prism .bz2 temp dir while open" "$(newtmp)" "1"
    eq "temp file has the plain name" "$(tc 'set v [lindex $iprism(prisms) end]; file tail [set ${v}(fn)]')" "table.fits"
    $X -p $D prism clear
    eq "prism clear removes temp dir" "$(newtmp)" "0"
    $X -p $D prism close
fi

echo "== prism and catalog imports"
$X -p $D prism $F/table.fits
for k in vot tsv rdb; do
    $X -p $D prism export $k $F/t.$k
    squeeze t.$k
done
$X -p $D prism close
prows() { tc 'set v [lindex $iprism(prisms) end]; global [set ${v}(tbldb)]; list [starbase_nrows [set ${v}(tbldb)]] [starbase_ncols [set ${v}(tbldb)]]'; }
crows() { tc 'set v [lindex $icat(cats) end]; global [set ${v}(catdb)]; list [starbase_nrows [set ${v}(catdb)]] [starbase_ncols [set ${v}(catdb)]]'; }
for k in vot tsv rdb; do
    $X -p $D prism import $k $F/t.$k
    plain=$(prows)
    $X -p $D prism close
    ne "plain prism import $k" "$plain" "0 0"
    for s in $ZIPS; do
	$X -p $D prism import $k $F/t.$k.$s
	eq "prism import $k.$s" "$(prows)" "$plain"
	$X -p $D prism close
    done
done
# the table has no sky columns, so the catalog tool complains about
# making regions; only the rows matter here
for k in tsv rdb; do
    $X -p $D catalog import $k $F/t.$k 2>/dev/null
    plain=$(crows)
    $X -p $D catalog close
    $X -p $D catalog import $k $F/t.$k.gz 2>/dev/null
    eq "catalog import $k.gz" "$(crows)" "$plain"
    $X -p $D catalog close
done

echo "== plot data"
$X -p $D plot line $F/xy.dat xy
plain=$($G $D plot list)
$X -p $D plot close
ne "plain plot loads" "$plain" ""
for s in $ZIPS; do
    $X -p $D plot line $F/xy.dat.$s xy
    eq "plot .$s" "$($G $D plot list)" "$plain"
    $X -p $D plot close
done
# backup restore path
$X -p $D plot line $F/xy.dat xy
eq "PlotLoadDataFile .gz" "$(tc "PlotLoadDataFile ap {$F/xy.dat.gz} xy")" ""
$X -p $D plot close

echo "== contours"
# contour save writes only generated contours, so compare renders
$X -p $D contour clear
blank=$(snap blank)
$X -p $D contour load $F/ds9.ctr
plain=$(snap ctr)
ne "plain contour draws" "$plain" "$blank"
for s in $ZIPS; do
    $X -p $D contour clear
    $X -p $D contour load $F/ds9.ctr.$s
    eq "contour .ctr.$s" "$(snap ctr.$s)" "$plain"
    eq "contour set name drops .$s" "$(tc 'lindex [lindex [$current(frame) get contour aux] end] 1')" "ds9.ctr"
done
$X -p $D contour clear
$X -p $D contour load $F/ds9.con wcs fk5 red 2 no
plain=$(snap con)
ne "plain .con draws" "$plain" "$blank"
for s in $ZIPS; do
    $X -p $D contour clear
    $X -p $D contour load $F/ds9.con.$s wcs fk5 red 2 no
    eq "contour .con.$s" "$(snap con.$s)" "$plain"
done
$X -p $D contour clear
$X -p $D contour loadlevels $F/ds9.lev
plain=$($G $D contour levels)
ne "plain levels load" "$plain" ""
for s in $ZIPS; do
    # a failed load would leave the previous levels in place
    $X -p $D contour levels "{1 2 3}"
    $X -p $D contour loadlevels $F/ds9.lev.$s
    eq "contour levels .$s" "$($G $D contour levels)" "$plain"
done
$X -p $D contour clear
eq "no temp dirs left" "$(newtmp)" "0"

# exit with a prism still holding a temp file
if has_zip bz2; then
    $X -p $D prism $F/table.fits.bz2
    quit
    eq "exit removes prism temp dir" "$(newtmp)" "0"
else
    quit
fi

rm -rf $O
echo
echo "decompress.sh: $pass passed, $fail failed"
[ $fail -eq 0 ]
