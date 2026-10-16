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
#    windows: sizes from lon0/lat0/fov, invalid lat0 fails to load
#  - recentring a window ($frame update fits center [lon lat]) moves the
#    centre, keeps the size, keeps a conic's reference latitude, and is
#    refused for all-sky images; recentred images are compared too
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
ARC proj=arc,lat0=30 1574 1574
ZEA proj=zea,lat0=-90 1004 1004
COE proj=coe 1574 1574
COD proj=cod,lon0=90,lat0=-30 1574 1574
COO proj=coo,lat0=30,fov=200 876 876
COP proj=cop,fov=150 658 658
BON proj=bon,lat0=45 1574 1574
LIST
load "${moc}[proj=tan,lon0=45,lat0=90,fov=40]" > /dev/null
xpaset -p DS9Test save fits ${tmp}/moc_TANpole.fits
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
	${tmp}/moc_TANpole.fits || fail=1
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
