#!/bin/bash
# Parallel https tile fetches against a local TLS server (hipsserve.py
# with a throwaway self-signed certificate) while the view keeps
# changing: loads, zooms, pans, slow tiles (/slow/) and hips cancel.
# Passes if ds9 survives every round and exits cleanly.
#
# Run from the top of the ds9 tree:
#   Tests/hips/hipsstress.sh [rounds]      (default 3)
# GM=1 runs ds9 under Guard Malloc (macOS), which catches heap misuse
# sooner but is slow. Needs the hpxtest conda env (PY) and openssl.

ROUNDS=${1:-3}
PY=${PY:-$HOME/miniforge/envs/hpxtest/bin/python}
TOP=$PWD; X=$TOP/bin; H=$TOP/Tests/hips; T=HiPSStress$$
FERMI=$TOP/hips/data1/ancillary/missions/Fermi_Band4/HiPS
ABELL=$TOP/hips/Abell1763_irac1
W=$(mktemp -d "${TMPDIR:-/tmp}/hipsstress.XXXXXX")
pass=0; fail=0
ok()  { pass=$((pass+1)); echo "  ok   $*"; }
bad() { fail=$((fail+1)); echo "  FAIL $*"; }
nap() { perl -e 'select(undef,undef,undef,0.3)'; }

openssl req -x509 -newkey rsa:2048 -nodes -days 2 -subj /CN=127.0.0.1 \
  -addext "subjectAltName=IP:127.0.0.1" -keyout $W/key.pem -out $W/cert.pem 2>/dev/null
mkdir $W/www
for i in $(seq 1 $ROUNDS); do ln -s $FERMI $W/www/f$i; ln -s $ABELL $W/www/a$i; done
HIPSSERVE_CERT=$W/cert.pem HIPSSERVE_KEY=$W/key.pem "$PY" -I $H/hipsserve.py $W/www $W/port $W/log &
SRV=$!
for i in $(seq 1 30); do [ -s $W/port ] && break; nap; done
U=https://127.0.0.1:$(cat $W/port)

rm -rf ~/$T.auto ~/$T.auto.dir ~/.$T
if [ -n "$GM" ]; then MENV="DYLD_INSERT_LIBRARIES=/usr/lib/libgmalloc.dylib"
else MENV="MallocScribble=1 MallocPreScribble=1 MallocGuardEdges=1"; fi
env SSL_CERT_FILE=$W/cert.pem $MENV PATH="$X:$PATH" $X/ds9 -title $T >$W/ds9.out 2>&1 &
PID=$!
for i in $(seq 1 200); do [ "$($X/xpaaccess -n $T)" -ge 1 ] && break; nap; done
alive() { kill -0 $PID 2>/dev/null; }

for i in $(seq 1 $ROUNDS); do
  $X/xpaset -p $T hips "$U/f$i[norder=1,proj=tan,lon0=$((i*37%360)),lat0=10,fov=20]" || bad "load f$i"
  for z in 2 4 8 16; do $X/xpaset -p $T zoom to $z; done
  $X/xpaset -p $T pan to $((i*37%360+3)) 12 galactic
  $X/xpaset -p $T hips "$U/a$i[norder=1,proj=tan]" || bad "load a$i"
  for z in 4 8 16; do $X/xpaset -p $T zoom to $z; done
  $X/xpaset -p $T hips "$U/slow/f$i[norder=2,proj=tan,lon0=$((i*53%360)),lat0=-20,fov=15]"
  $X/xpaset -p $T zoom to 8; $X/xpaset -p $T pan to $((i*53%360+2)) -18 galactic
  [ $((i%3)) = 0 ] && $X/xpaset -p $T hips cancel
  $X/xpaset -p $T zoom to 16
  if alive; then ok "round $i: $(grep -c . $W/log) requests so far"
  else bad "round $i: ds9 died"; break; fi
done

if alive; then
  $X/xpaset -p $T exit
  for i in $(seq 1 100); do alive || break; nap; done
  if alive; then bad "still running 30 s after exit"; kill $PID
  else wait $PID; rc=$?; [ $rc = 0 ] && ok "clean exit" || bad "exit status $rc"; fi
fi
kill $SRV
echo "requests by status:"; cut -d' ' -f1 $W/log | sort | uniq -c
rm -rf ~/$T.auto ~/$T.auto.dir ~/.$T "$W"
echo "PASSED $pass, FAILED $fail"
[ $fail = 0 ]
