#!/bin/bash
# Every HiPS check (Tests/hips/*.sh), one after another, each starting
# and stopping its own ds9, server and hub; none needs the network.
# Run from the top of the ds9 tree, or from Tests/:
#   Tests/hips.sh [suite ...]     e.g. Tests/hips.sh hipsref hipsid
# Each suite's output goes to $OUT/<suite>.out (default a temporary
# directory, kept); prints one line per suite and exits 1 if any failed.
# hipsstress and hipsexit also need openssl, for a throwaway certificate
# for the local https server; hipsexit uses Guard Malloc when there is one.
# Needs the hpxtest conda env (numpy, astropy, healpy, reproject, PIL);
# set PY to another python if it lives elsewhere.

cd "$(dirname "$0")/.." || exit 1
OUT=${OUT:-$(mktemp -d "${TMPDIR:-/tmp}/hips.XXXXXX")}
SUITES="hipscmd hipsload hipsbackup hipsdialog hipsview hipsmoc hipsprov
        hipsnet hipspng hipscolour hipsdeep hipscube hipsid hipsformat
        hipssamp hipsref hipspad hipsstress hipsexit"
[ $# -gt 0 ] && SUITES="$*"
bad=0
for s in $SUITES; do
    start=$(date +%s)
    bash Tests/hips/$s.sh > $OUT/$s.out 2>&1
    rc=$?
    line=$(grep '^PASSED' $OUT/$s.out | tail -1)
    printf '%-12s %-24s %4ss\n' $s "${line:-no result (exit $rc)}" $(( $(date +%s) - start ))
    [ $rc = 0 ] || bad=1
done
echo "output in $OUT"
exit $bad
