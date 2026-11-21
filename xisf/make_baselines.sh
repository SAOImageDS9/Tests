#!/bin/sh
# Create the probe baseline (<fixture>.xisf.sav) for every XISF fixture from
# its FITS twin, using today's DS9 - which has no XISF reader at all. So the
# expected result of every XISF load is fixed before the reader exists, and
# a reader that passes reproduces exactly what DS9 shows for the FITS
# equivalent. See make_xisf_fixtures.py for what a twin encodes.
#
#   cd Tests/xisf && sh make_baselines.sh
#
# Needs `ds9', `xpaset', `xpaget', `xpaaccess' and `xpans' on PATH (see
# AGENTS.md for the macOS shim), and the twins already generated.
#
# The probe is lifted from ../asdf.sh at run time rather than copied, so the
# two suites cannot drift: an XISF baseline means the same thing as an ASDF
# one. Two lines are then adjusted from the manifest, not from the twin:
#
#  * bitpix. The twin carries what FITS can carry: UInt16 as 16 + BZERO,
#    UInt32/UInt64 as 64. The reader produces fitsy's own -16 for UInt16, so
#    the manifest's bitpix column wins.
#  * refused fixtures get the probe of an empty frame.

cd `dirname $0`

eval "`awk '/^StartDS9 \(\) \{/,/^\}/' ../asdf.sh`"
eval "`awk '/^probe \(\) \{/,/^\}/' ../asdf.sh`"

StartDS9
# keep Error/Warning from opening dialogs nothing can dismiss
printf 'set pds9(confirm) 0\n' | xpaset DS9Test tcl

n=0
for manifest in MANIFEST.tsv real/MANIFEST.tsv wcs1904/MANIFEST.tsv; do
    [ -f $manifest ] || continue
    grep -v '^#' $manifest | while IFS='	' read rel expect bitpix notes; do
	xpaset -p DS9Test frame new
	case $expect in
	    load|load-first)
		twin=`echo $rel | sed 's/\.xisf$/.fits/'`
		if [ ! -f "$twin" ]; then
		    echo "MISSING TWIN $twin"
		    xpaset -p DS9Test frame delete
		    continue
		fi
		xpaset -p DS9Test fits `pwd`/$twin
		probe | sed "s/^bitpix .*/bitpix $bitpix/" > $rel.sav 2>&1
		;;
	    *)
		probe > $rel.sav 2>&1
		;;
	esac
	xpaset -p DS9Test frame delete
	echo "  $rel.sav"
    done
done

xpaset -p DS9Test exit
