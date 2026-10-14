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
# (Hammer-Aitoff, Mollweide, ...). ds9 first builds its usual HPX image
# from the table, then resamples it through AST (nearest-neighbour) into
# the requested projection -- FitsHPXReproj in
# tksao/frame/fitshealpix.C.
#
# Prototype selection: the projection comes from the environment
# variables DS9_HPX_PROJ (AIT, MOL, CAR, SFL, GLS, PAR, CEA) and
# DS9_HPX_LON (centre longitude in degrees), read when a HEALPix table
# is loaded. They are set inside the running ds9 through the "tcl" XPA
# access point (Tcl's env array sets the process environment), so one
# ds9 can switch projections between loads. When the filename-bracket
# options (proj=, lon=) replace the env vars, update setproj() below.
#
# Checks:
#  - with DS9_HPX_PROJ unset, loading is unchanged (HPX, 5*nside square)
#  - layout= and quad= are ignored when a projection is requested
#  - every resampled image is saved with "save fits" and compared against
#    reproject.reproject_from_healpix(order='nearest-neighbor') on the
#    same header (hpxproj/compare.py): every pixel where ds9 has a value
#    must be exactly equal. Covers a full-sky RING map, a partial
#    (INDXSCHM=EXPLICIT) NESTED map and a NUNIQ MOC.
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
HPXPY=${HPXPY:-$HOME/miniforge/envs/hpxtest/bin/python}
tmp=`mktemp -d`
fail=0

# setproj PROJ LON  (PROJ empty = unset, i.e. normal HPX)
setproj () {
    if [ -z "$1" ]; then
	echo 'unset -nocomplain env(DS9_HPX_PROJ) env(DS9_HPX_LON)' | xpaset DS9Test tcl
    else
	echo "set env(DS9_HPX_PROJ) $1; set env(DS9_HPX_LON) $2" | xpaset DS9Test tcl
    fi
}

# load FILE -> prints "width height" of the loaded image
load () {
    xpaset -p DS9Test frame delete all
    xpaset -p DS9Test frame new
    xpaset -p DS9Test fits "$1"
    xpaget DS9Test fits size | tr -d '\n'
}

# checksize NAME GOT EXPECTED
checksize () {
    if [ "$2" = "$3" ]; then
	echo " $1 PASSED ($2)"
    else
	echo " $1 FAILED: size '$2', expected '$3'"
	fail=1
    fi
}

StartDS9

# nside=256 -> HPX 1280x1280; AIT/MOL 1418x710; CAR/SFL/PAR 1574x788;
# CEA 1574x504 (resampled sizes are always rounded up to even)
setproj
checksize "default HPX" "`load "${wmap}"`" "1280 1280"

setproj AIT 0
checksize "AIT layout/quad ignored" \
    "`load "${wmap}[system=galactic,layout=north,quad=2]"`" "1418 710"

for pl in "AIT 0 1418 710" "MOL 180 1418 710" "CAR 90 1574 788" \
	  "SFL -60 1574 788" "PAR 0 1574 788" "CEA 270 1574 504"
do
    set -- $pl
    setproj $1 $2
    checksize "wmap $1 lon=$2" "`load "${wmap}[system=galactic]"`" "$3 $4"
    xpaset -p DS9Test save fits ${tmp}/wmap_$1.fits
done

setproj AIT 0
load "${partial}" > /dev/null
xpaset -p DS9Test save fits ${tmp}/partial_AIT.fits

# Regression: MOL at lon=0 for the nside=1024 MOC. With an odd width,
# the centre column sat exactly on the RA=0 polar facet seam of the HPX
# intermediate, nearest-neighbour hit exact .5 ties and rounded into the
# gaps between facets (0 in a MOC's HPX image), so 4 pixels came out 0
# instead of 1. Fixed by always making the output size even.
setproj MOL 0
checksize "moc MOL lon=0" "`load "${moc}"`" "5664 2834"
xpaset -p DS9Test save fits ${tmp}/moc_MOL.fits

setproj
xpaset -p DS9Test frame delete all
xpaset -p DS9Test quit

if [ -x "${HPXPY}" ] && "${HPXPY}" -c 'import numpy, astropy, healpy, reproject' 2>/dev/null; then
    echo " compare with reproject_from_healpix"
    "${HPXPY}" -I hpxproj/compare.py ${wmap} galactic ${tmp}/wmap_*.fits || fail=1
    "${HPXPY}" -I hpxproj/compare.py ${partial} header ${tmp}/partial_AIT.fits || fail=1
    "${HPXPY}" -I hpxproj/compare.py ${moc} header ${tmp}/moc_MOL.fits || fail=1
    echo " projection boundary"
    "${HPXPY}" -I hpxproj/boundary.py ${tmp}/wmap_*.fits ${tmp}/moc_MOL.fits || fail=1
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
