#!/bin/sh
# The reader's WCS through ds9's own WCS code (AST), before ds9 can load
# XISF itself (TODO_XISF.md Phase 4; Phase 5 adds the load command).
#
# For every loadable wcs/ fixture, writes a FITS file whose header is
# *exactly* the cards FitsXisf builds (utils/xisfdump --fits) and whose
# pixels are the twin's, loads it into ds9 and runs the same probe as
# ../asdf.sh. The result must equal the fixture's .xisf.sav baseline,
# which was recorded from the twin: so AST reads the reader's cards - its
# number formatting, PV/LONPOLE, mirrored SIP - to the same sky positions
# as the twin's own.
#
#   cd Tests/xisf && sh check_ds9_wcs.sh [python]
#
# Needs ds9 and the xpa tools on PATH (AGENTS.md has the macOS shim), and
# a python with numpy and astropy (default: the ds9asdf conda env). Run
# it with sh, not zsh: the probe relies on word splitting.

cd `dirname $0`
py=${1:-$HOME/miniforge/envs/ds9asdf/bin/python}
dump=../../utils/xisfdump/xisfdump

# a plain relative directory: ds9's command line takes a path component
# that starts with `-' for an option
tmp=`mktemp -d ./_wcscheck.XXXXXX` || exit 1
trap 'rm -rf "$tmp"' EXIT

"$py" -I - "$tmp" "$dump" <<'EOF' || exit 1
import pathlib, subprocess, sys
from astropy.io import fits
out, dump = pathlib.Path(sys.argv[1]), sys.argv[2]
for line in open("MANIFEST.tsv"):
    rel, expect = line.split("\t")[:2]
    if not rel.startswith("wcs/") or expect == "refuse":
        continue
    r = subprocess.run([dump, "--fits", rel], capture_output=True, text=True)
    cards = [l[5:].ljust(80)[:80] for l in r.stdout.splitlines()
             if l.startswith("card ")]
    head = "".join(cards).encode("ascii")
    head += b" " * (-len(head) % 2880)
    data = fits.getdata(pathlib.Path(rel).with_suffix(".fits"))
    data = data.astype(data.dtype.newbyteorder(">")).tobytes()
    data += b"\0" * (-len(data) % 2880)
    (out / rel.replace("/", "__").replace(".xisf", ".fits")).write_bytes(head + data)
EOF

eval "`awk '/^StartDS9 \(\) \{/,/^\}/' ../asdf.sh`"
eval "`awk '/^probe \(\) \{/,/^\}/' ../asdf.sh`"
StartDS9 > /dev/null 2>&1
printf 'set pds9(confirm) 0\n' | xpaset DS9Test tcl

pass=0
fail=0
for f in $tmp/*.fits; do
    rel=`basename $f .fits | sed 's|__|/|'`
    xpaset -p DS9Test frame new
    xpaset -p DS9Test fits `pwd`/$f
    probe > $tmp/out.txt 2>&1
    xpaset -p DS9Test frame delete
    if diff -w $rel.xisf.sav $tmp/out.txt > /dev/null; then
	pass=`expr $pass + 1`
    else
	fail=`expr $fail + 1`
	echo "FAIL $rel"
	diff -w $rel.xisf.sav $tmp/out.txt | sed 's/^/    /'
    fi
done
xpaset -p DS9Test exit
echo "$pass passed, $fail failed"
exit $fail
