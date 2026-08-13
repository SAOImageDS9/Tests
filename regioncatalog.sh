#!/bin/sh

set -eu

test_root=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
ds9_program=${DS9_BIN:-ds9}
test_tmp=$(mktemp -d "${TMPDIR:-/tmp}/ds9-regioncatalog.XXXXXX")
xpa_pid=
cleanup()
{
    if [ -n "$xpa_pid" ]; then
        kill "$xpa_pid" 2>/dev/null || true
    fi
    rm -rf "$test_tmp"
}
trap cleanup EXIT HUP INT TERM

export DS9_REGIONCATALOG_TEST_ROOT="$test_root"
export DS9_REGIONCATALOG_TEST_TMP="$test_tmp"

run_test()
{
    test_name=$1
    image_name=$2
    shift 2
    result_file="$test_tmp/$test_name.out"
    export DS9_REGIONCATALOG_TEST_RESULT="$result_file"
    echo "Testing region catalog: $test_name"
    "$ds9_program" -title "DS9RegionCatalog-$test_name" \
        "$test_root/$image_name" "$@" \
        -source "$test_root/regioncatalog/$test_name.tcl"
    if [ ! -f "$result_file" ] || [ "$(sed -n '1p' "$result_file")" != PASS ]; then
        echo "FAILED: $test_name"
        if [ -f "$result_file" ]; then
            cat "$result_file"
        else
            echo "DS9 did not write $result_file"
        fi
        exit 1
    fi
}

run_test statistics data/5x5.fits
run_test edge data/5x5.fits
run_test threading data/5x5.fits
run_test events data/5x5.fits
run_test catalog data/5x5.fits
run_test wcs data/img.fits
run_test interface data/5x5.fits -region "$test_root/regioncatalog/one.reg" \
    -catalog make

echo "Testing region catalog: mosaic"
mosaic_result="$test_tmp/mosaic.out"
export DS9_REGIONCATALOG_TEST_RESULT="$mosaic_result"
"$ds9_program" -title DS9RegionCatalog-mosaic -mosaicimage wcs \
    "$test_root/mosaic/mosaicimage.fits" \
    -region "$test_root/regions/ds9.mosaic.image.reg" \
    -source "$test_root/regioncatalog/mosaic.tcl"
if [ ! -f "$mosaic_result" ] || [ "$(sed -n '1p' "$mosaic_result")" != PASS ]; then
    echo "FAILED: mosaic"
    if [ -f "$mosaic_result" ]; then cat "$mosaic_result"; fi
    exit 1
fi

if ! command -v xpans >/dev/null 2>&1 || \
   ! command -v xpaaccess >/dev/null 2>&1 || \
   ! command -v xpaset >/dev/null 2>&1; then
    echo "FAILED: XPA tools, including xpans, must be on PATH"
    exit 1
fi

echo "Testing region catalog: XPA"
xpa_name="DS9RegionCatalogXPA$$"
xpa_result="$test_tmp/xpa.out"
xpa_ready_file="$test_tmp/xpa.ready"
export DS9_REGIONCATALOG_TEST_RESULT="$xpa_result"
"$ds9_program" -title "$xpa_name" -xpa yes "$test_root/data/5x5.fits" \
    -region "$test_root/regioncatalog/one.reg" \
    -source "$test_root/regioncatalog/xpa.tcl" &
xpa_pid=$!
xpa_ready=no
xpa_try=0
while [ "$xpa_try" -lt 20 ]; do
    if [ -f "$xpa_ready_file" ] && [ "$(xpaaccess "$xpa_name")" = yes ]; then
        xpa_ready=yes
        break
    fi
    xpa_try=$((xpa_try + 1))
    sleep 1
done
if [ "$xpa_ready" != yes ]; then
    echo "FAILED: XPA endpoint did not register"
    exit 1
fi
xpaset -p "$xpa_name" catalog make
wait "$xpa_pid"
xpa_pid=
if [ ! -f "$xpa_result" ] || [ "$(sed -n '1p' "$xpa_result")" != PASS ]; then
    echo "FAILED: XPA catalog make"
    if [ -f "$xpa_result" ]; then cat "$xpa_result"; fi
    exit 1
fi

echo "PASSED: region catalog"
