#!/bin/bash
# HiPS Phase 1 checks: local FITS-tile HiPS loaded with "load hips" give
# the same images as the HEALPix map they hold, loaded as an ordinary
# HEALPix table, for each projection; unusable HiPS fail with a message.
#
# Run from the top of the ds9 tree:
#   Tests/hips/hipsload.sh [python]
# python defaults to the hpxtest conda env (numpy, astropy, healpy).
# Test HiPS are in hips/ (see hips/samples.md). Starts and stops its own
# ds9 (title HiPSTest).

T=HiPSTest
. Tests/hips/lib.sh
FERMI=$TOP/hips/data1/ancillary/missions/Fermi_Band4/HiPS
DSS=$TOP/hips/DSS2_red
ABELL=$TOP/hips/Abell1763_irac1

# --- references (independent of ds9's reader) ---
for k in 0 1 2 3; do "$PY" -I $H/mkref.py $FERMI $k $W/fermi_o$k.fits >/dev/null; done
for k in 0 1 2; do "$PY" -I $H/mkref.py $ABELL $k $W/abell_o$k.fits >/dev/null; done
"$PY" -I $H/mksynth.py $W >/dev/null
SYNTH="u8 i16 i32 i64 f32 f64"
for t in $SYNTH; do
  for k in 0 1; do "$PY" -I $H/mkref.py $W/synth_$t $k $W/synth_${t}_o$k.fits >/dev/null; done
done
"$PY" -I $H/mkref.py $W/synth_reduced 1 $W/synth_reduced_o1.fits allsky >/dev/null

# --- ds9 ---
start
echo "source $H/hipsload.tcl" | $X/xpaset $T tcl

# compare <name> <hips spec> <reference spec>
compare() {
  echo "hipsload {$2} $W/a.txt; savefr $W/a.fits" | $X/xpaset $T tcl >/dev/null 2>&1
  echo "refload {$3} $W/b.txt; savefr $W/b.fits" | $X/xpaset $T tcl >/dev/null 2>&1
  r=$("$PY" -I - "$W/a.fits" "$W/b.fits" <<'EOF'
import sys, numpy as np, warnings
from astropy.io import fits
warnings.simplefilter("ignore")
try:
    a, ha = fits.getdata(sys.argv[1], header=True)
    b, hb = fits.getdata(sys.argv[2], header=True)
except Exception as e:
    print("unreadable", e); sys.exit()
keys = [k for k in hb if k[:5] in ("CTYPE", "CRPIX", "CRVAL", "CDELT", "PC1_1", "PC1_2", "PC2_1", "PC2_2", "PV2_1", "PV2_2", "LONPO", "LATPO")]
hdiff = [k for k in keys if ha.get(k) != hb.get(k)]
same = a.shape == b.shape and np.array_equal(a, b, equal_nan=True)
print(("same" if same and not hdiff else "DIFF") + f" {a.shape[::-1]} finite {np.isfinite(a).sum()}" + (f" wcs differs: {hdiff}" if hdiff else ""))
EOF
)
  case "$r" in same*) ok "$1: $r";; *) bad "$1: $r ($(cat $W/a.txt) | $(cat $W/b.txt))";; esac
}

# expect_error <name> <hips spec> <message fragment>
expect_error() {
  echo "hipsload {$2} $W/a.txt" | $X/xpaset $T tcl >/dev/null 2>&1
  if grep -q "rc=1.*$3" $W/a.txt; then ok "$1: $(sed 's/.*rc=1 //' $W/a.txt | head -c 90)"
  else bad "$1: expected '$3', got $(cat $W/a.txt)"; fi
}

PROJS="proj=HPX proj=MOL proj=AIT proj=CAR proj=TAN,lon0=30,lat0=10,fov=40"

echo "Fermi (galactic, 64-px tiles, Allsky at order 3, unpadded tiles)"
for k in 0 1 2 3; do
  for p in $PROJS; do compare "norder=$k $p" "${FERMI}[norder=$k,$p]" "$W/fermi_o$k.fits[$p]"; done
done
compare "automatic order (3)" "${FERMI}" "$W/fermi_o3.fits"
compare "automatic order, MOL" "${FERMI}[proj=MOL]" "$W/fermi_o3.fits[proj=MOL]"

echo "Synthetic (equatorial, 16-px tiles, every BITPIX, BLANK/BSCALE/BZERO, missing tiles, padded+unpadded)"
for t in $SYNTH; do
  compare "$t norder=0" "$W/synth_${t}[norder=0]" "$W/synth_${t}_o0.fits"
  compare "$t automatic (order 1, tiles; Allsky is reduced)" "$W/synth_${t}" "$W/synth_${t}_o1.fits"
  compare "$t norder=1 MOL" "$W/synth_${t}[norder=1,proj=MOL]" "$W/synth_${t}_o1.fits[proj=MOL]"
done
compare "reduced Allsky only (norder=1)" "$W/synth_reduced[norder=1]" "$W/synth_reduced_o1.fits"
compare "reduced Allsky only, AIT" "$W/synth_reduced[norder=1,proj=AIT]" "$W/synth_reduced_o1.fits[proj=AIT]"

echo "Abell1763 irac1 (galactic, partial, float + NaN, padded tiles)"
for k in 0 1 2; do
  compare "norder=$k HPX" "${ABELL}[norder=$k]" "$W/abell_o$k.fits"
  compare "norder=$k TAN at target" "${ABELL}[norder=$k,proj=TAN,lon0=92.7153,lat0=73.2733,fov=4]" "$W/abell_o$k.fits[proj=TAN,lon0=92.7153,lat0=73.2733,fov=4]"
done
compare "automatic (order 2)" "${ABELL}" "$W/abell_o2.fits"

echo "Unusable HiPS give a message"
# PNG/JPEG tiles load since Phase 3 (Tests/hips/hipspng.sh); a HiPS
# with no FITS, PNG or JPEG tiles is refused
mkdir -p $W/webp
sed 's/^hips_tile_format.*/hips_tile_format = webp/' $FERMI/properties > $W/webp/properties
expect_error "no readable tile format" "$W/webp" "no FITS, PNG or JPEG tiles"
expect_error "order deeper than hips_order" "${FERMI}[norder=4]" "deeper than hips_order"
expect_error "order with no data here" "${DSS}[norder=2]" "no fits tiles or Allsky at order 2"
# IRSA's DSS2 red Norder3/Allsky.fits is truncated (4932972 of 6417216
# bytes), and the local copy has no order 0-2 tiles
expect_error "truncated Allsky named" "${DSS}" "Allsky.fits is unreadable"
expect_error "map too large" "${DSS}[norder=9]" "larger than the limit"
expect_error "not a HiPS" "$TOP/hips" "can't read"
# options: order= is only the HEALPix ordering, and an option the
# grammar doesn't know (which it would take for a bin filter) is refused
expect_error "order=0 (not the HiPS order)" "${FERMI}[order=0]" "unknown option in \[order=0\] (the HiPS order is norder=)"
expect_error "order=nested" "${FERMI}[order=nested]" "order= is a HEALPix table's pixel ordering"
expect_error "a mistyped option" "${FERMI}[norder=1,prj=mol]" "unknown option in \[prj=mol\]"
# a deep norder= with no tiles is refused at once: looking for any of
# its 12*4^25 tiles first never finished
cp -R $TOP/Tests/fits/hips $W/deep
sed -i.bak 's/^hips_order .*/hips_order = 29/' $W/deep/properties
t0=$(date +%s)
expect_error "norder=25: map too large" "$W/deep[norder=25]" "order 25 is a map of nside 536870912, larger than the limit"
dt=$(( $(date +%s) - t0 ))
if [ $dt -le 5 ]; then ok "  at once (${dt}s)"; else bad "  took ${dt}s"; fi
# File > Open HiPS... lists a local order too deep to load without
# counting its tiles
mkdir -p $W/deep/Norder12/Dir0
cp $W/deep/Norder1/Dir0/Npix0.fits $W/deep/Norder12/Dir0/Npix0.fits
echo "set f [open $W/o.txt w]; puts \$f [HiPSOpenOrderLabel [lindex [HiPSOpenOrders $W/deep 16] 0]]; close \$f" | $X/xpaset $T tcl
check "dialog: a deep local order" "$(tr -d '\r' < $W/o.txt)" "Order 12: NSIDE 65536, tiles, 196608 MB (too large)"

$X/xpaset -p $T exit
finish
