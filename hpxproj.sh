StartDS9 () {
    if [ `xpaaccess DS9Test` = no ]; then
	timeout 2m ds9 -title DS9Test &

	i=1
	while [ "$i" -le 10 ]
	    do
	    sleep 2
	    if [ `xpaaccess DS9Test` = yes ]; then
		break
	    fi

	    i=`expr $i + 1`
	done
    fi
}

# Test for displaying HEALPix tables in other all-sky projections
# (Hammer-Aitoff, Mollweide, ...) with the filename-bracket options
#   proj=ait|mol|car|sfl|gls|par|cea|hpx   (case-insensitive, default hpx)
#   lon0=<deg>                             (centre longitude, default 0)
# ds9 first builds its usual HPX image from the table, then resamples it
# through AST (nearest-neighbour) into the requested projection --
# FitsHPXReproj in tksao/frame/fitshpxreproj.C.
#
# Checks:
#  - with no proj=, or proj=hpx, loading is unchanged (HPX, 5*nside square)
#  - layout= and quad= are ignored when a projection is requested
#  - lon0= takes integers and reals and sets CRVAL1; proj= is
#    case-insensitive; an unknown proj= fails to load
#  - [ext,hpx] (e.g. [1,proj=ait]) applies the options
#  - zenithal (TAN SIN STG ARC ZEA) and conic (COP COE COD COO BON)
#    windows: sizes from lon0/lat0/fov, invalid lat0 fails to load;
#    windows start display-sized (HEALPix pixels, twice the frame) and
#    follow the zoom (finer pixels down to HEALPix's when zooming in,
#    coarser and wider when zooming out, on-screen scale unchanged); zoom
#    to fit shows the whole fov
#  - recentring a window ($frame update fits center [lon lat]) moves the
#    centre, keeps the size, keeps a conic's reference latitude, and is
#    refused for all-sky images; recentred images are compared too
#  - live recentring after pans: threshold, pan/crosshair kept, pan to
#    targets beyond the window and in another sky system, conics follow
#    in longitude only, locked frames follow, scale limits from the
#    whole map, and a recentred view renders like a fresh load
#  - regions survive recentring (list, ids, selection), and ones the
#    window can't place are parked and restored later; deleting regions
#    deletes their parked copies; regions created out of reach appear
#    once the window gets there
#  - catalog markers (local catalogs/cellout.fits on the MOC) keep their
#    positions, ids, tags and table link through recentres and parking,
#    and regenerating the catalog while parked gives one marker per row
#  - aux contours (from a file) are remapped through the sky: a recentred
#    view renders like a fresh load with the same file, and they come
#    back after a far recentre
#  - AIT/MOL with a grid and seam-crossing regions render byte-identically
#    to the same image reloaded as an ordinary FITS file
#  - every resampled image is saved with "save fits" and compared against
#    reproject.reproject_from_healpix(order='nearest-neighbor') on the
#    same header (hpxproj/compare.py): ds9 must keep the sky system and
#    every pixel where ds9 has a value must be exactly equal. Covers
#    full-sky RING and NESTED maps, COORDSYS G / C / E / absent, a
#    partial (INDXSCHM=EXPLICIT) NESTED map and a NUNIQ MOC. The nside=64
#    fixtures in fits/hpxproj come from hpxproj/make_fixtures.py.
#  - full-sky images are blank exactly outside the projection boundary
#    (hpxproj/boundary.py)
#
# The numeric checks need python with numpy, astropy, healpy and
# reproject. Set HPXPY to that python; the default is the "hpxtest"
# conda env. If it isn't there, they are skipped.

echo
echo "*** hpxproj.sh ***"

wmap=fits/wmap_ring.fits
partial=fits/healpix_partial.fits
moc=fits/ChandraMOC10_nograting.fits
fixtures=fits/hpxproj
HPXPY=${HPXPY:-$HOME/miniforge/envs/hpxtest/bin/python}
tmp=`mktemp -d`
fail=0

# load FILE -> prints "width height" of the loaded image
load () {
    xpaset -p DS9Test frame delete all
    xpaset -p DS9Test frame new
    xpaset -p DS9Test fits "$1" 2> /dev/null
    xpaget DS9Test fits size | tr -d '\n'
}

# check NAME GOT EXPECTED
check () {
    if [ "$2" = "$3" ]; then
	echo " $1 PASSED ($2)"
    else
	echo " $1 FAILED: got '$2', expected '$3'"
	fail=1
    fi
}

# crval1 FITSFILE -> CRVAL1 of the primary header, as written
crval1 () {
    head -c 28800 "$1" | fold -w 80 | grep '^CRVAL1 ' | head -1 | \
	sed 's/^CRVAL1  = *//;s/ *\/.*$//'
}

StartDS9

# Window sizes depend on the frame size (a window starts at twice the
# frame), so fix it.
xpaset -p DS9Test width 800
xpaset -p DS9Test height 600

# nside=256 -> HPX 1280x1280; AIT/MOL 1418x710; CAR/SFL/PAR 1574x788;
# CEA 1574x504 (resampled sizes are always rounded up to even)
check "default HPX" "`load "${wmap}"`" "1280 1280"
check "proj=hpx" "`load "${wmap}[proj=hpx]"`" "1280 1280"
check "layout/quad ignored" \
    "`load "${wmap}[system=galactic,layout=north,quad=2,proj=ait]"`" "1418 710"
check "proj= case-insensitive" "`load "${wmap}[PROJ=Mol]"`" "1418 710"
check "unknown proj= fails" "`load "${wmap}[proj=xyz]"`" "0 0"

load "${wmap}[proj=car,lon0=-60.5]" > /dev/null
xpaset -p DS9Test save fits ${tmp}/lon0.fits
check "lon0=-60.5 sets CRVAL1" "`crval1 ${tmp}/lon0.fits`" "299.5"

for pl in "AIT 0 1418 710" "MOL 180 1418 710" "CAR 90 1574 788" \
	  "SFL -60 1574 788" "PAR 0 1574 788" "CEA 270 1574 504"
do
    set -- $pl
    check "wmap $1 lon0=$2" \
	"`load "${wmap}[system=galactic,proj=$1,lon0=$2]"`" "$3 $4"
    xpaset -p DS9Test save fits ${tmp}/wmap_$1.fits
done

# zenithal and conic: centre lon0/lat0, size fov (angular diameter for
# zenithals, plane width for conics); defaults fov TAN 90, SIN/STG 180,
# ARC/ZEA 360, conics 360, conic lat0 45. The polar TAN case puts HPX
# facet seams on the image diagonals (regression for exact .5 ties).
while read name opts size
do
    check "wmap $name" "`load "${wmap}[system=galactic,$opts]"`" "$size"
    xpaset -p DS9Test save fits ${tmp}/wmap_$name.fits
done <<LIST
TAN proj=tan 504 504
TANpole proj=tan,lon0=45,lat0=90,fov=40 186 186
SIN proj=sin,lat0=60 504 504
STG proj=stg,lon0=120,lat0=-30 1004 1004
ARC proj=arc,lat0=30 1574 1104
ZEA proj=zea,lat0=-90 1004 1004
COE proj=coe 1574 1104
COD proj=cod,lon0=90,lat0=-30 1574 1104
COO proj=coo,lat0=30,fov=200 876 876
COP proj=cop,fov=150 658 658
BON proj=bon,lat0=45 1574 1104
LIST
load "${moc}[proj=tan,lon0=45,lat0=90,fov=40]" > /dev/null
xpaset -p DS9Test save fits ${tmp}/moc_TANpole.fits
# windows are display-sized: they start at HEALPix pixels (0.0573 deg at
# nside 1024) and twice the frame, within the fov (the MOC as a full-sky
# ARC would be ~6300^2 at that resolution; HPX_WINDOW_MAX still caps it)
check "initial window: twice the frame" "`load "${moc}[proj=arc,fov=360]"`" "1600 1104"
xpaset -p DS9Test save fits ${tmp}/moc_ARCcap.fits
check "initial window: HEALPix pixels" \
    "`head -c 28800 ${tmp}/moc_ARCcap.fits | fold -w 80 | grep '^CDELT2 ' | sed 's/^CDELT2 *= *//;s/ .*//' | awk '{printf "%.5f", $1}'`" "0.05726"
check "initial window: no coarsening" \
    "`head -c 28800 ${tmp}/moc_ARCcap.fits | fold -w 80 | grep -c 'coarser than the HEALPix'`" "0"
# windows follow the zoom: pixels as fine as a screen pixel (down to the
# HEALPix pixel), twice the visible area, and the on-screen scale (deg
# per screen pixel = CDELT / zoom) unchanged; zoom to fit shows the
# whole fov
# key FITSFILE KEY -> value
key () {
    head -c 28800 "$1" | fold -w 80 | grep "^$2 " | head -1 | sed "s/^$2 *= *//;s/ *\/.*\$//"
}
# scale -> deg per screen pixel of the current frame
scale () {
    xpaset -p DS9Test save fits ${tmp}/sc.fits
    z=`xpaget DS9Test zoom | awk '{print $1}'`
    awk -v c="\`key ${tmp}/sc.fits CDELT2\`" -v z=$z 'BEGIN {printf "%.6g", c/z}'
}
# same A B -> yes if A and B agree to 1e-6 (relative)
same () { awk -v a=$1 -v b=$2 'BEGIN {d=a-b; if (d<0) d=-d; print (d <= 1e-6*(a<0?-a:a)) ? "yes" : "no: " a " " b}'; }
xpaset -p DS9Test zoom to fit
s0=`scale`
fit0=`key ${tmp}/sc.fits CDELT2`
check "zoom to fit: whole fov, coarse pixels" \
    "`key ${tmp}/sc.fits CDELT2 | awk '{print ($1 > 0.3) ? "yes" : "no: " $1}'`" "yes"
xpaset -p DS9Test zoom 4
s1=`scale`
check "zoom in: on-screen scale kept" "`same $s1 \`awk -v s=$s0 'BEGIN {printf "%.6g", s/4}'\``" "yes"
f0=`key ${tmp}/sc.fits CDELT2`
check "zoom in: finer pixels" \
    "`awk -v a=$f0 -v b=$fit0 'BEGIN {print (a < b/2) ? "yes" : "no: " a " vs " b}'`" "yes"
xpaset -p DS9Test zoom 8
check "zoom in further: HEALPix resolution" \
    "`scale > /dev/null; key ${tmp}/sc.fits CDELT2 | awk '{printf "%.5f", $1}'`" "0.05726"
cp ${tmp}/sc.fits ${tmp}/moc_ARCzoom.fits
xpaset -p DS9Test zoom 0.0625
s2=`scale`
check "zoom out: on-screen scale kept" "`same $s2 \`awk -v s=$s0 'BEGIN {printf "%.6g", s*2}'\``" "yes"
cw=`printf 'set ch [open %s/fr.txt w]\nputs $ch [$ds9(canvas) itemcget $current(frame) -width]\nclose $ch\n' "${tmp}" | xpaset DS9Test tcl; cat ${tmp}/fr.txt`
check "zoom out: window <= 2x the frame" \
    "`awk -v n=\`key ${tmp}/sc.fits NAXIS1\` -v w=$cw 'BEGIN {print (n <= 2*w+4) ? "yes" : "no: " n " " w}'`" "yes"
xpaset -p DS9Test zoom to 1
# Recentring a zenithal/conic window keeps the HPX intermediate and
# rebuilds the window around a new centre. Frame-level command for now,
# reached through the tcl access point:
#   $current(frame) update fits center          (on the current pan)
#   $current(frame) update fits center lon lat  (map's own sky system)
# fr CMD -> "OK" or "ERR: msg"
fr () {
    printf 'set ch [open %s/fr.txt w]\nif {[catch {$current(frame) %s} rr]} {puts $ch "ERR:$rr"} else {puts $ch OK}\nclose $ch\n' \
	"${tmp}" "$1" | xpaset DS9Test tcl
    cat ${tmp}/fr.txt
}
# crval2 FITSFILE -> "CRVAL1 CRVAL2" as written
crval12 () {
    echo "`crval1 $1` `head -c 28800 "$1" | fold -w 80 | grep '^CRVAL2 ' | head -1 | sed 's/^CRVAL2  = *//;s/ *\/.*$//'`"
}

load "${wmap}[system=galactic,proj=tan,fov=60]" > /dev/null
check "recentre lon lat" "`fr 'update fits center 30 20'`" "OK"
xpaset -p DS9Test save fits ${tmp}/wmap_recentre1.fits
check "recentre lon lat CRVAL" "`crval12 ${tmp}/wmap_recentre1.fits`" "30 20"
xpaset -p DS9Test pan to 45 10 wcs galactic
check "recentre on pan" "`fr 'update fits center'`" "OK"
xpaset -p DS9Test save fits ${tmp}/wmap_recentre2.fits
check "recentre on pan CRVAL" "`crval12 ${tmp}/wmap_recentre2.fits`" "45 10"
check "recentre size kept" "`xpaget DS9Test fits size | tr -d '\n'`" "292 292"
load "${wmap}[system=galactic,proj=coe,lat0=30]" > /dev/null
xpaset -p DS9Test pan to 100 30 wcs galactic
check "recentre conic" "`fr 'update fits center'`" "OK"
xpaset -p DS9Test save fits ${tmp}/wmap_recentre3.fits
check "recentre conic keeps lat0" "`crval12 ${tmp}/wmap_recentre3.fits`" "100 30"
load "${wmap}[system=galactic,proj=ait]" > /dev/null
check "recentre AIT refused" "`fr 'update fits center 10 10'`" \
    "ERR: not a HEALPix zenithal/conic window"

# Live recentring (step 2): after a pan (not during a drag) a window is
# rebuilt once the pan point is more than 1/4 of the window from its
# centre; the pan and crosshair keep their sky positions, contours are
# regenerated, a "pan to" a sky position goes straight there even if it
# is outside the window, and scale limits come from the whole map.
# cv -> "CRVAL1 CRVAL2" of the current frame, saved to $tmp/cv.fits
cv () {
    xpaset -p DS9Test save fits ${tmp}/cv.fits
    crval12 ${tmp}/cv.fits
}
# lim -> scale limits, minmax then zscale
lim () {
    xpaset -p DS9Test scale mode minmax
    l1=`xpaget DS9Test scale limits | tr -d '\n'`
    xpaset -p DS9Test scale mode zscale
    l2=`xpaget DS9Test scale limits | tr -d '\n'`
    xpaset -p DS9Test scale mode minmax
    echo "$l1 / $l2"
}
load "${wmap}[system=galactic]" > /dev/null
hpxlim=`lim`
load "${wmap}[system=galactic,proj=tan,fov=60]" > /dev/null
check "window scale = whole map" "`lim`" "$hpxlim"
xpaset -p DS9Test mode crosshair
xpaset -p DS9Test crosshair 20 5 wcs galactic
xpaset -p DS9Test mode none
xpaset -p DS9Test pan to 10 0 wcs galactic
check "short pan: no recentre" "`cv`" "0 0"
xpaset -p DS9Test pan to 40 10 wcs galactic
check "long pan: recentred" "`cv`" "40 10"
check "long pan: pan kept" "`xpaget DS9Test pan wcs galactic degrees | tr -d '\n'`" \
    "40.0000000 10.0000000"
check "long pan: crosshair kept" \
    "`xpaget DS9Test crosshair wcs galactic degrees | tr -d '\n'`" "20.0000000 5.0000000"
check "recentred: scale unchanged" "`lim`" "$hpxlim"
xpaset -p DS9Test pan to 200 -30 wcs galactic
check "pan beyond TAN reach" "`cv`" "200 -30"
xpaset -p DS9Test pan to 300 -60 wcs fk5
check "pan in fk5" "`xpaget DS9Test pan wcs fk5 degrees | tr -d '\n'`" \
    "300.0000000 -60.0000000"
# a conic window showing its whole projection plane has nothing to gain
# from a rebuild; zoomed in, its meridian follows the pan (reference
# latitude kept) and the window slides across the plane to the pan point
load "${wmap}[system=galactic,proj=coe,lat0=30,fov=150]" > /dev/null
xpaset -p DS9Test pan to 150 45 wcs galactic
check "conic pan, whole plane shown: no rebuild" "`cv`" "0 30"
check "conic pan, whole plane shown: pan kept" \
    "`xpaget DS9Test pan wcs galactic degrees | tr -d '\n'`" "150.0000000 45.0000000"
# zoomed in on a window that started coarse (the MOC's 360 deg conic is
# capped): the window no longer shows the whole plane
load "${moc}[proj=coe,lat0=30]" > /dev/null
xpaset -p DS9Test zoom to 4
xpaset -p DS9Test pan to 150 45 wcs fk5
check "conic pan, zoomed in: meridian only" \
    "`cv | awk '{printf "%.4f %.4f", $1, $2}'`" "150.0000 30.0000"
check "conic pan, zoomed in: pan kept" \
    "`xpaget DS9Test pan wcs fk5 degrees | tr -d '\n'`" "150.0000000 45.0000000"
xpaset -p DS9Test zoom to 1

# locked frames: the second window follows
load "${wmap}[system=galactic,proj=tan,fov=60]" > /dev/null
xpaset -p DS9Test frame new
xpaset -p DS9Test fits "${wmap}[system=galactic,proj=sin,fov=90]"
xpaset -p DS9Test lock frame wcs
xpaset -p DS9Test frame first
xpaset -p DS9Test pan to 200 -30 wcs galactic
xpaset -p DS9Test frame next
check "lock frame wcs: other window recentred" "`cv | cut -c1-12`" "200.00000005"
xpaset -p DS9Test lock frame none

# regions (step 3): remapped through the sky on recentre, keeping ids,
# selection and properties; regions the window can't place (more than
# 90 deg from a TAN centre) are parked and come back later
# frv CMD -> the frame command's result
frv () {
    printf 'set ch [open %s/fr.txt w]\nif {[catch {$current(frame) %s} rr]} {puts $ch "ERR:$rr"} else {puts $ch $rr}\nclose $ch\n' \
	"${tmp}" "$1" | xpaset DS9Test tcl
    cat ${tmp}/fr.txt | tr -d '\n'
}
regs () {
    xpaget DS9Test regions -format ds9 -system wcs -sky galactic \
	-skyformat degrees | grep -v '^#\|^global\|^galactic'
}
load "${wmap}[system=galactic,proj=tan,fov=60]" > /dev/null
cat <<REG | xpaset DS9Test regions
galactic
circle(20,5,2) # color=red text={c1} tag={t1}
box(-10,8,4,2,30) # color=cyan
polygon(5,-5,8,-5,8,-2) # color=yellow width=2
ellipse(-15,-12,3,1.5,45) # color=magenta dash=1
point(12,12) # point=diamond color=white
circle(25,-10,1.5) # color=orange text={far}
REG
frv "marker 2 select" > /dev/null
frv "marker 5 select" > /dev/null
regs > ${tmp}/regs0.txt
xpaset -p DS9Test pan to 40 10 wcs galactic
check "regions: recentred" "`cv`" "40 10"
check "regions: same list" "`regs | shasum | cut -c1-16`" \
    "`shasum < ${tmp}/regs0.txt | cut -c1-16`"
check "regions: ids kept" "`frv 'get marker id all'`" "1 2 3 4 5 6 "
check "regions: selection kept" "`frv 'get marker select'`" "2 5 "
xpaset -p DS9Test pan to 200 -30 wcs galactic
check "regions: unplaceable ones parked" "`frv 'get marker id all'`" ""
xpaset -p DS9Test pan to 0 0 wcs galactic
check "regions: parked ones back" "`frv 'get marker id all'`" "1 2 3 4 5 6 "
check "regions: back, same list" "`regs | shasum | cut -c1-16`" \
    "`shasum < ${tmp}/regs0.txt | cut -c1-16`"
check "regions: back, selection kept" "`frv 'get marker select'`" "2 5 "
# deleting regions also deletes their parked copies (no zombies)
xpaset -p DS9Test pan to 200 -30 wcs galactic
xpaset -p DS9Test regions delete all
xpaset -p DS9Test pan to 0 0 wcs galactic
check "regions: delete all while parked" "`frv 'get marker id all'`" ""
cat <<REG | xpaset DS9Test regions
galactic
circle(20,5,2) # tag={t1}
box(-10,8,4,2,30)
ellipse(-15,-12,3,1.5,45) # tag={t1}
REG
keep=`frv 'get marker id all' | awk '{print $2}'`
xpaset -p DS9Test pan to 200 -30 wcs galactic
frv "marker t1 delete" > /dev/null
xpaset -p DS9Test pan to 0 0 wcs galactic
check "regions: delete by tag while parked" "`frv 'get marker id all'`" "$keep "
xpaset -p DS9Test regions delete all
# a region created where the window can't place it is parked, and
# appears once the window gets there
xpaset -p DS9Test pan to 200 -30 wcs galactic
echo 'galactic; circle(10,5,2) # text={late}' | xpaset DS9Test regions
check "regions: created out of reach, parked" "`frv 'get marker id all'`" ""
xpaset -p DS9Test pan to 0 0 wcs galactic
check "regions: created out of reach, appears" \
    "`regs | grep -c 'text={late}'`" "1"
xpaset -p DS9Test regions delete all

# catalogs (catalog layer): a local catalog on a TAN window of the MOC.
# Its markers are remapped like regions, keep their ids and tags, and
# keep the marker -> table row link (callbacks); markers parked at a far
# centre come back with it, and regenerating the catalog while parked
# leaves exactly one marker per row.
# catfr CMD -> result of a Tcl command on the first catalog
catv () {
    printf 'set ch [open %s/fr.txt w]\nglobal icat\nset cc [lindex $icat(cats) 0]\nupvar #0 $cc var\nif {[catch {%s} rr]} {puts $ch "ERR:$rr"} else {puts $ch $rr}\nclose $ch\n' \
	"${tmp}" "$1" | xpaset DS9Test tcl
    cat ${tmp}/fr.txt | tr -d '\n'
}
catlist () {
    printf 'set ch [open %s/fr.txt w]\nputs $ch [$current(frame) marker catalog list ds9 wcs fk5 degrees no]\nclose $ch\n' \
	"${tmp}" | xpaset DS9Test tcl
    grep -v '^#\|^global\|^fk5' ${tmp}/fr.txt
}
catn () { frv 'get marker catalog id all' | wc -w | tr -d ' '; }
# catrow TAG -> table row selected after highliting the marker tagged TAG
catrow () {
    id=`frv "get marker catalog {$1} id"`
    frv "marker catalog unhighlite all" > /dev/null
    catv '$var(tbl) selection clear all' > /dev/null
    frv "marker catalog $id highlite" > /dev/null
    catv 'lindex [$var(tbl) curselection] 0'
}
load "${moc}[proj=tan,lon0=246.75,lat0=-24.54,fov=10]" > /dev/null
xpaset -p DS9Test catalog import fits catfits/cellout.fits
sleep 2
check "catalog: markers" "`catn`" "118"
catlist > ${tmp}/cat0.txt
cid=`frv "get marker catalog {cattool.5} id"`
check "catalog: marker -> table row" "`catrow cattool.5`" "5,1"
xpaset -p DS9Test pan to 260 -20 wcs fk5
check "catalog: recentred, same markers" "`catlist | shasum | cut -c1-16`" \
    "`shasum < ${tmp}/cat0.txt | cut -c1-16`"
check "catalog: recentred, id kept" "`frv "get marker catalog {cattool.5} id"`" "$cid"
check "catalog: recentred, table link" "`catrow cattool.5`" "5,1"
xpaset -p DS9Test pan to 66.75 24.54 wcs fk5
check "catalog: far centre, parked" "`catn`" "0"
xpaset -p DS9Test pan to 246.75 -24.54 wcs fk5
check "catalog: back, same markers" "`catlist | shasum | cut -c1-16`" \
    "`shasum < ${tmp}/cat0.txt | cut -c1-16`"
check "catalog: back, id kept" "`frv "get marker catalog {cattool.5} id"`" "$cid"
check "catalog: back, table link" "`catrow cattool.5`" "5,1"
xpaset -p DS9Test pan to 66.75 24.54 wcs fk5
xpaset -p DS9Test catalog symbol color red
sleep 1
xpaset -p DS9Test pan to 246.75 -24.54 wcs fk5
check "catalog: regenerated while parked, one per row" "`catn`" "118"
check "catalog: regenerated while parked, same markers" \
    "`catlist | sed 's/ color=red//' | shasum | cut -c1-16`" \
    "`shasum < ${tmp}/cat0.txt | cut -c1-16`"
check "catalog: regenerated while parked, table link" "`catrow cattool.5`" "5,1"
xpaset -p DS9Test catalog close

# aux contours (loaded from a file) go through the sky too: recentred
# they render like a fresh load at that centre with the same file, and
# after a far recentre (all of them off the window) they come back
# shot NAME LON LAT -> sha of a render panned to lon lat
shot () {
    xpaset -p DS9Test pan to $2 $3 wcs galactic
    xpaset -p DS9Test zoom to 2
    xpaset -p DS9Test saveimage png ${tmp}/$1.png
    shasum -a 256 < ${tmp}/$1.png | cut -c1-16
}
aw="${wmap}[system=galactic,proj=tan,fov=40"
load "$aw]" > /dev/null
xpaset -p DS9Test scale log
xpaset -p DS9Test contour smooth 4
xpaset -p DS9Test contour nlevels 3
xpaset -p DS9Test contour yes
xpaset -p DS9Test contour save ${tmp}/aux.ctr wcs galactic
xpaset -p DS9Test contour no
xpaset -p DS9Test contour load ${tmp}/aux.ctr
aux0=`shot aux0 0 0`
check "aux contours: recentre" "`fr 'update fits center 10 5'`" "OK"
auxr=`shot auxr 10 5`
load "$aw,lon0=10,lat0=5]" > /dev/null
xpaset -p DS9Test scale log
xpaset -p DS9Test contour load ${tmp}/aux.ctr
check "aux contours: recentred renders like a fresh load" "$auxr" "`shot auxf 10 5`"
load "$aw]" > /dev/null
xpaset -p DS9Test scale log
xpaset -p DS9Test contour load ${tmp}/aux.ctr
xpaset -p DS9Test pan to 200 -30 wcs galactic
check "aux contours: back after a far recentre" "`shot auxb 0 0`" "$aux0"
xpaset -p DS9Test contour clear
xpaset -p DS9Test contour smooth 1
xpaset -p DS9Test contour nlevels 5
xpaset -p DS9Test scale linear
xpaset -p DS9Test zoom to 1

# render parity: recentred (with contours) vs a fresh load at that centre
load "${wmap}[system=galactic,proj=tan,fov=20]" > /dev/null
xpaset -p DS9Test scale log
xpaset -p DS9Test contour yes
xpaset -p DS9Test pan to 40 10 wcs galactic
xpaset -p DS9Test zoom to 2
xpaset -p DS9Test saveimage png ${tmp}/recentred.png
load "${wmap}[system=galactic,proj=tan,fov=20,lon0=40,lat0=10]" > /dev/null
xpaset -p DS9Test contour yes
xpaset -p DS9Test pan to 40 10 wcs galactic
xpaset -p DS9Test zoom to 2
xpaset -p DS9Test saveimage png ${tmp}/fresh.png
check "recentred renders like a fresh load (contours)" \
    "`shasum -a 256 < ${tmp}/recentred.png | cut -c1-16`" \
    "`shasum -a 256 < ${tmp}/fresh.png | cut -c1-16`"
xpaset -p DS9Test contour no
xpaset -p DS9Test scale linear
xpaset -p DS9Test zoom to 1

check "conic lat0=0 fails" "`load "${wmap}[proj=coe,lat0=0]"`" "0 0"
check "lat0=95 fails" "`load "${wmap}[proj=tan,lat0=95]"`" "0 0"

load "${partial}[proj=ait]" > /dev/null
xpaset -p DS9Test save fits ${tmp}/partial_AIT.fits

# Regression: MOL at lon0=0 for the nside=1024 MOC. With an odd width,
# the centre column sat exactly on the RA=0 polar facet seam of the HPX
# intermediate, nearest-neighbour hit exact .5 ties and rounded into the
# gaps between facets (0 in a MOC's HPX image), so 4 pixels came out 0
# instead of 1. Fixed by always making the output size even.
check "moc MOL lon0=0" "`load "${moc}[proj=mol]"`" "5664 2834"
xpaset -p DS9Test save fits ${tmp}/moc_MOL.fits

# Generated nside=64 fixtures (hpxproj/make_fixtures.py): the same map
# labelled G / C / E / no COORDSYS, and a NESTED copy. nside=64 ->
# AIT/MOL 356x180.
for f in ${fixtures}/ring64_gal ${fixtures}/ring64_equ \
	 ${fixtures}/ring64_ecl ${fixtures}/ring64_unk ${fixtures}/nested64_gal
do
    b=`basename $f`
    check "$b AIT lon0=120" "`load "${f}.fits[proj=ait,lon0=120]"`" "356 180"
    xpaset -p DS9Test save fits ${tmp}/fix_${b}_AIT.fits
    check "$b MOL lon0=-90" "`load "${f}.fits[proj=mol,lon0=-90]"`" "356 180"
    xpaset -p DS9Test save fits ${tmp}/fix_${b}_MOL.fits
done

# [ext,hpx] form: the options after the extension used to be ignored
# (grammar rule used the bracketed hpxs instead of hpxsb)
check "[1,proj=ait]" "`load "${fixtures}/ring64_gal.fits[1,proj=ait]"`" "356 180"
check "[1,layout=north]" "`load "${fixtures}/ring64_gal.fits[1,layout=north]"`" "256 256"

# Display parity: a resampled image must render exactly like the same
# image saved with "save fits" and reloaded as an ordinary FITS file,
# with a galactic grid and regions straddling the +/-180 seam.
# render FILE LON0 PNG
render () {
    load "$1" > /dev/null
    xpaset -p DS9Test zoom to fit
    xpaset -p DS9Test scale log
    xpaset -p DS9Test scale minmax
    xpaset -p DS9Test grid yes
    xpaset -p DS9Test grid system wcs
    xpaset -p DS9Test grid sky galactic
    s=$(( ($2 + 180) % 360 ))
    echo "galactic; circle($((s-2)),20,8); box($s,-50,30,15,0); polygon($((s-10)),0,$((s+10)),0,$((s+10)),10,$((s-10)),10)" | \
	xpaset DS9Test regions
    xpaset -p DS9Test saveimage png $3
    xpaset -p DS9Test grid no
}
for pl in "ait 0" "mol 180"
do
    set -- $pl
    load "${wmap}[system=galactic,proj=$1,lon0=$2]" > /dev/null
    xpaset -p DS9Test save fits ${tmp}/parity_$1.fits
    render "${wmap}[system=galactic,proj=$1,lon0=$2]" $2 ${tmp}/parity_$1_hpx.png
    render "${tmp}/parity_$1.fits" $2 ${tmp}/parity_$1_plain.png
    check "$1 renders like plain FITS" \
	"`shasum -a 256 < ${tmp}/parity_$1_hpx.png | cut -c1-16`" \
	"`shasum -a 256 < ${tmp}/parity_$1_plain.png | cut -c1-16`"
done

xpaset -p DS9Test frame delete all
xpaset -p DS9Test quit

if [ -x "${HPXPY}" ] && "${HPXPY}" -c 'import numpy, astropy, healpy, reproject' 2>/dev/null; then
    echo " compare with reproject_from_healpix"
    "${HPXPY}" -I hpxproj/compare.py ${wmap} galactic ${tmp}/wmap_*.fits || fail=1
    "${HPXPY}" -I hpxproj/compare.py ${partial} header ${tmp}/partial_AIT.fits || fail=1
    "${HPXPY}" -I hpxproj/compare.py ${moc} header ${tmp}/moc_MOL.fits \
	${tmp}/moc_TANpole.fits ${tmp}/moc_ARCcap.fits ${tmp}/moc_ARCzoom.fits || fail=1
    for f in ${fixtures}/ring64_gal ${fixtures}/ring64_equ \
	     ${fixtures}/ring64_ecl ${fixtures}/ring64_unk ${fixtures}/nested64_gal
    do
	b=`basename $f`
	"${HPXPY}" -I hpxproj/compare.py ${f}.fits header \
	    ${tmp}/fix_${b}_AIT.fits ${tmp}/fix_${b}_MOL.fits || fail=1
    done
    echo " projection boundary"
    "${HPXPY}" -I hpxproj/boundary.py ${tmp}/wmap_AIT.fits ${tmp}/wmap_MOL.fits ${tmp}/wmap_CAR.fits ${tmp}/wmap_SFL.fits ${tmp}/wmap_PAR.fits ${tmp}/wmap_CEA.fits ${tmp}/moc_MOL.fits \
	${tmp}/fix_*.fits || fail=1
else
    echo " numeric checks SKIPPED: no python with numpy/astropy/healpy/reproject at ${HPXPY}"
fi

rm -rf ${tmp}

if [ $fail = "0" ]; then
    echo "PASSED"
else
    echo "FAILED"
    exit 1
fi
