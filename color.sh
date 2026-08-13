#!/bin/sh

# Exercise named and hexadecimal colors through DS9's XPA interface.
# Run from any directory.  Set DS9_BIN or TITLE to override the defaults.

set -u

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$script_dir" || exit 1

title=${TITLE:-DS9ColorTest}
ds9_bin=${DS9_BIN:-ds9}
started=0
failures=0
tests=0
tag_file=

cleanup()
{
    if [ -n "$tag_file" ]; then
        rm -f "$tag_file"
    fi
    if [ "$started" -eq 1 ] && [ "$(xpaaccess "$title" 2>/dev/null)" = yes ]; then
        xpaset -p "$title" quit >/dev/null 2>&1 || true
    fi
}
trap cleanup EXIT HUP INT TERM

fail()
{
    failures=$((failures + 1))
    printf '\nFAILED: %s\n' "$1" >&2
    if [ -n "${2-}" ]; then
        printf '  %s\n' "$2" >&2
    fi
}

abort_if_ds9_gone()
{
    if [ "$(xpaaccess "$title" 2>/dev/null)" != yes ]; then
        printf '\nDS9 exited during the color test; aborting after %d checks.\n' \
            "$tests" >&2
        exit 1
    fi
}

xpa_set()
{
    xpa_set_label=$1
    shift
    tests=$((tests + 1))
    if xpa_set_output=$(xpaset -p "$title" "$@" 2>&1); then
        printf '.'
    else
        fail "$xpa_set_label" "$xpa_set_output"
        abort_if_ds9_gone
    fi
}

xpa_send()
{
    xpa_send_label=$1
    xpa_send_data=$2
    shift 2
    tests=$((tests + 1))
    if xpa_send_output=$(printf '%s\n' "$xpa_send_data" | xpaset "$title" "$@" 2>&1); then
        printf '.'
    else
        fail "$xpa_send_label" "$xpa_send_output"
        abort_if_ds9_gone
    fi
}

xpa_get()
{
    xpa_get_label=$1
    shift
    tests=$((tests + 1))
    if xpa_get_output=$(xpaget "$title" "$@" 2>&1); then
        if [ -n "$xpa_get_output" ]; then
            printf '.'
        else
            fail "$xpa_get_label" "empty XPA response"
        fi
    else
        fail "$xpa_get_label" "$xpa_get_output"
        abort_if_ds9_gone
    fi
}

printf '\n*** color.sh ***\n'

# A source-tree build places DS9 and the XPA clients in the sibling bin
# directory.  Installed commands in PATH and explicit overrides still win.
if ! command -v xpaaccess >/dev/null 2>&1 && [ -x ../bin/xpaaccess ]; then
    PATH="$(cd ../bin && pwd):$PATH"
    export PATH
fi
if [ "$ds9_bin" = ds9 ] && ! command -v ds9 >/dev/null 2>&1 &&
   [ -x ../bin/ds9 ]; then
    ds9_bin=../bin/ds9
fi

if ! command -v xpaaccess >/dev/null 2>&1 ||
   ! command -v xpaset >/dev/null 2>&1 ||
   ! command -v xpaget >/dev/null 2>&1; then
    printf 'xpaaccess, xpaset, and xpaget must be in PATH\n' >&2
    exit 1
fi

if [ "$(xpaaccess "$title")" = no ]; then
    printf 'Starting %s...' "$title"
    "$ds9_bin" -title "$title" -tcl >/dev/null 2>&1 &
    started=1

    count=0
    while [ "$count" -lt 20 ]; do
        if [ "$(xpaaccess "$title")" = yes ]; then
            break
        fi
        sleep 1
        count=$((count + 1))
    done
fi

if [ "$(xpaaccess "$title")" != yes ]; then
    printf '\nUnable to contact %s\n' "$title" >&2
    exit 1
fi

# Tk accepts named colors and #RGB/#RRGGBB specifications.  Keep each hex
# value quoted here so it cannot be mistaken for a shell comment.
colors=${COLORS:-'red green blue white black cyan magenta yellow pink orange purple grey #808080 #123456 #2c8'}

printf '\nSetup'
xpa_set 'load test image' fits data/img.fits
xpa_set 'show coordinate grid' grid yes
xpa_set 'use WCS coordinate grid' grid system wcs
xpa_set 'show contours' contour yes
xpa_set 'open mask dialog' mask open
xpa_set 'create catalog window' catalog new

# Give the region group and illustration commands selected objects to update.
xpa_set 'remove old regions' region delete all
xpa_send 'create test region' 'image; circle(100,100,20)' region
xpa_set 'select test region' region select all
xpa_set 'create test region group' region group color-test new
xpa_set 'remove old illustrations' illustrate delete all
xpa_send 'create test illustration' 'circle 150 150 20' illustrate
xpa_set 'select test illustration' illustrate select all

tag_file=$(mktemp "${TMPDIR:-/tmp}/ds9-color-tags.XXXXXX") || exit 1

printf '\nGeneral color options'
for color in $colors; do
    printf '\n  %-8s ' "$color"

    xpa_set "background: $color" background "$color"
    xpa_get "get background after $color" background
    xpa_set "NaN: $color" nan "$color"
    xpa_get "get NaN after $color" nan

    xpa_set "preference background: $color" prefs bg color "$color"
    xpa_get "get preference background after $color" prefs bg color
    xpa_set "preference NaN: $color" prefs nan color "$color"
    xpa_get "get preference NaN after $color" prefs nan color

    xpa_set "magnifier: $color" magnifier color "$color"
    xpa_get "get magnifier after $color" magnifier color

    xpa_set "colorbar foreground: $color" colorbar foreground "$color"
    xpa_get "get colorbar foreground after $color" colorbar foreground
    xpa_set "colorbar background: $color" colorbar background "$color"
    xpa_get "get colorbar background after $color" colorbar background
    printf '10 30 %s\n' "$color" >"$tag_file"
    xpa_set "colorbar tag: $color" cmap tag load "$tag_file"
    xpa_set "remove colorbar tag after $color" cmap tag delete

    xpa_set "contour: $color" contour color "$color"
    xpa_get "get contour after $color" contour color

    xpa_set "grid lines: $color" grid grid color "$color"
    xpa_get "get grid lines after $color" grid grid color
    xpa_set "grid axes: $color" grid axes color "$color"
    xpa_get "get grid axes after $color" grid axes color
    xpa_set "grid tickmarks: $color" grid tickmarks color "$color"
    xpa_get "get grid tickmarks after $color" grid tickmarks color
    xpa_set "grid border: $color" grid border color "$color"
    xpa_get "get grid border after $color" grid border color
    xpa_set "grid numerics: $color" grid numerics color "$color"
    xpa_get "get grid numerics after $color" grid numlab color
    xpa_set "grid title: $color" grid title color "$color"
    xpa_get "get grid title after $color" grid title color
    xpa_set "grid labels: $color" grid labels color "$color"
    xpa_get "get grid labels after $color" grid textlab color

    xpa_set "region default/selection: $color" region color "$color"
    xpa_get "get region color after $color" region color
    xpa_set "region group: $color" region group color-test color "$color"
    xpa_send "inline region property: $color" \
        "image; circle(200,200,10) # color=$color" region

    xpa_set "illustration default/selection: $color" illustrate color "$color"
    xpa_get "get illustration color after $color" illustrate color
    xpa_send "inline illustration property: $color" \
        "circle 250 250 10 # color = $color" illustrate

    xpa_set "mask: $color" mask color "$color"
    xpa_get "get mask after $color" mask color

    xpa_set "catalog symbol: $color" catalog symbol color "$color"
done

printf '\n3D color options'
xpa_set 'create 3D frame' 3d
xpa_set 'load 3D test cube' fits data/3d.fits
for color in $colors; do
    printf '\n  %-8s ' "$color"
    xpa_set "3D border: $color" 3d border color "$color"
    xpa_get "get 3D border after $color" 3d border color
    xpa_set "3D compass: $color" 3d compass color "$color"
    xpa_get "get 3D compass after $color" 3d compass color
    xpa_set "3D highlight: $color" 3d highlite color "$color"
    xpa_get "get 3D highlight after $color" 3d highlite color
done
xpa_set 'delete 3D frame' frame delete
xpa_set 'close 3D dialog' 3d close
xpa_set 'close cube dialog' cube close

printf '\nPlot line and canvas color options'
xpa_set 'create line plot' plot line plot/xyexey.dat xyexey
xpa_set 'disable line plot theme' plot theme no
for color in $colors; do
    printf '\n  %-8s ' "$color"
    xpa_set "plot foreground: $color" plot foreground "$color"
    xpa_get "get plot foreground after $color" plot foreground
    xpa_set "plot background: $color" plot background "$color"
    xpa_set "plot grid: $color" plot grid color "$color"
    xpa_set "plot line: $color" plot color "$color"
    xpa_get "get plot line after $color" plot line color
    xpa_set "plot line fill: $color" plot fill color "$color"
    xpa_get "get plot line fill after $color" plot line fill color
    xpa_set "plot line symbol: $color" plot line shape color "$color"
    xpa_get "get plot line symbol after $color" plot line shape color
    xpa_set "plot error bars: $color" plot error color "$color"
    xpa_get "get plot error bars after $color" plot error color
done
xpa_set 'close line plot' plot close

printf '\nPlot bar color options'
xpa_set 'create bar plot' plot bar plot/xy.dat xy
xpa_set 'disable bar plot theme' plot theme no
for color in $colors; do
    printf '\n  %-8s ' "$color"
    xpa_set "plot bar border: $color" plot bar border color "$color"
    xpa_get "get plot bar border after $color" plot bar border color
    xpa_set "plot bar fill: $color" plot bar color "$color"
    xpa_get "get plot bar fill after $color" plot bar color
done
xpa_set 'close bar plot' plot close

printf '\nPlot scatter color option'
xpa_set 'create scatter plot' plot scatter plot/xy.dat xy
xpa_set 'disable scatter plot theme' plot theme no
for color in $colors; do
    printf '\n  %-8s ' "$color"
    xpa_set "plot scatter symbol: $color" plot scatter color "$color"
    xpa_get "get plot scatter symbol after $color" plot scatter color
done
xpa_set 'close scatter plot' plot close

printf '\nMulticolor layer option'
xpa_set 'create multicolor frame' multicolor
xpa_set 'load multicolor test image' fits data/i.fits
for color in $colors; do
    printf '\n  %-8s ' "$color"
    xpa_set "multicolor layer: $color" layer color "$color"
    xpa_get "get multicolor layer after $color" layer color
done
xpa_set 'delete multicolor frame' frame delete

printf '\n\n%d XPA color checks; %d failure(s)\n' "$tests" "$failures"
if [ "$failures" -eq 0 ]; then
    printf 'PASSED\n'
    exit 0
else
    printf 'FAILED\n' >&2
    exit 1
fi
