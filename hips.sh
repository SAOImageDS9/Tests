#!/bin/bash
# Every HiPS check (Tests/hips/*.sh), one after another, each starting
# and stopping its own ds9, server and hub; none needs the network.
# Run from the top of the ds9 tree, or from Tests/:
#   Tests/hips.sh [suite ...]     e.g. Tests/hips.sh hipsref hipsid
# Each suite's output goes to $OUT/<suite>.out (default a temporary
# directory, kept); prints one line per suite and exits 1 if any failed.
# hipsstress and hipsexit also need openssl, for a throwaway certificate
# for the local https server; hipsexit uses Guard Malloc when there is one.
# Needs the hpxtest conda env (numpy, astropy, healpy, reproject, PIL;
# set PY to another python if it lives elsewhere) and, for most suites,
# the sample HiPS under hips/ (hips/samples.md); a suite whose needs
# aren't there is reported SKIPPED and doesn't fail the run.

cd "$(dirname "$0")/.." || exit 1
OUT=${OUT:-$(mktemp -d "${TMPDIR:-/tmp}/hips.XXXXXX")}
SUITES="hipscmd hipsload hipsbackup hipsdialog hipsview hipsmoc hipsprov
        hipsnet hipspng hipscolour hipsdeep hipscube hipsid hipsformat
        hipssamp hipsref hipspad hipsstress hipsexit"
[ $# -gt 0 ] && SUITES="$*"
PY=${PY:-$HOME/miniforge/envs/hpxtest/bin/python}
export PY
# what a suite needs that isn't in the tree: the python packages (all
# but two), openssl (two), and the sample HiPS under hips/ (most; a copy
# of the HiPS listed in hips/samples.md, not in git). A suite missing
# any is skipped, not failed, so all.sh runs elsewhere.
if "$PY" -I -c 'import numpy, astropy, healpy, reproject, PIL' 2>/dev/null; then
    havepy=1
else
    havepy=0
fi
bad=0
for s in $SUITES; do
    f=Tests/hips/$s.sh
    why=""
    if [ $havepy = 0 ] && grep -q '"\$PY"' $f; then
        why="no python with numpy, astropy, healpy, reproject, PIL (set PY)"
    elif grep -q openssl $f && ! command -v openssl >/dev/null; then
        why="no openssl"
    else
        for d in $(grep -o '\$TOP/hips/[A-Za-z0-9_]*' $f | sort -u); do
            [ -d "${d/\$TOP/$PWD}" ] || why="${why:-no} ${d#\$TOP/}"
        done
    fi
    if [ -n "$why" ]; then
        printf '%-12s SKIPPED: %s\n' $s "$why"
        continue
    fi
    start=$(date +%s)
    bash Tests/hips/$s.sh > $OUT/$s.out 2>&1
    rc=$?
    line=$(grep '^PASSED' $OUT/$s.out | tail -1)
    printf '%-12s %-24s %4ss\n' $s "${line:-no result (exit $rc)}" $(( $(date +%s) - start ))
    [ $rc = 0 ] || bad=1
done
echo "output in $OUT"
exit $bad
