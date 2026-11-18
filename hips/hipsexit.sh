#!/bin/bash
# Exit ds9 while https tile requests are still in flight. tcltls's exit
# handler frees OpenSSL's BIO methods, so worker threads still reading
# used to crash ds9 on the way out (fixed by HiPSWorkersStop, 96176d71c).
# Each run must end with exit status 0 within 30 s.
#
# Run from the top of the ds9 tree:
#   Tests/hips/hipsexit.sh [runs]          (default 3)
# Runs ds9 under Guard Malloc where there is one (macOS), which made the
# old crash show up 4 times in 5. OLD=1 turns the fix off, to see it
# fail. Needs the hpxtest conda env (PY) and openssl.

RUNS=${1:-3}
PY=${PY:-$HOME/miniforge/envs/hpxtest/bin/python}
TOP=$PWD; X=$TOP/bin; H=$TOP/Tests/hips
FERMI=$TOP/hips/data1/ancillary/missions/Fermi_Band4/HiPS
W=$(mktemp -d "${TMPDIR:-/tmp}/hipsexit.XXXXXX")
pass=0; fail=0
ok()  { pass=$((pass+1)); echo "  ok   $*"; }
bad() { fail=$((fail+1)); echo "  FAIL $*"; }
nap() { perl -e 'select(undef,undef,undef,0.3)'; }

openssl req -x509 -newkey rsa:2048 -nodes -days 2 -subj /CN=127.0.0.1 \
  -addext "subjectAltName=IP:127.0.0.1" -keyout $W/key.pem -out $W/cert.pem 2>/dev/null
mkdir $W/www; ln -s $FERMI $W/www/f
HIPSSERVE_CERT=$W/cert.pem HIPSSERVE_KEY=$W/key.pem "$PY" -I $H/hipsserve.py $W/www $W/port $W/log &
SRV=$!
for i in $(seq 1 30); do [ -s $W/port ] && break; nap; done
U=https://127.0.0.1:$(cat $W/port)
GM=/usr/lib/libgmalloc.dylib
[ -f $GM ] && MENV="DYLD_INSERT_LIBRARIES=$GM" || MENV=

for run in $(seq 1 $RUNS); do
  T=HiPSExit$$_$run; rm -rf ~/$T.auto ~/$T.auto.dir ~/.$T
  env SSL_CERT_FILE=$W/cert.pem $MENV PATH="$X:$PATH" $X/ds9 -title $T >$W/ds9.$run.out 2>&1 &
  PID=$!
  for i in $(seq 1 200); do [ "$($X/xpaaccess -n $T)" -ge 1 ] && break; nap; done
  # deep tiles come in the background, 0.2 s each (/slow/); exit while they do
  $X/xpaset -p $T hips "$U/slow/f[norder=1,proj=tan,lon0=$((run*40)),lat0=20,fov=20]"
  : > $W/log
  $X/xpaset -p $T zoom to 8
  nap; nap
  inflight=$(wc -l < $W/log | tr -d ' ')
  [ -n "$OLD" ] && echo "proc HiPSWorkersStop {} {}" | $X/xpaset $T tcl
  t0=$(date +%s); $X/xpaset -p $T exit
  for i in $(seq 1 100); do kill -0 $PID 2>/dev/null || break; nap; done
  dt=$(( $(date +%s) - t0 ))
  if kill -0 $PID 2>/dev/null; then bad "run $run: still running ${dt} s after exit"; kill -9 $PID
  else
    wait $PID; rc=$?
    if [ $rc = 0 ]; then ok "run $run: exit 0 after $dt s ($inflight tiles fetched before exit)"
    else bad "run $run: exit status $rc after $dt s"; fi
  fi
  rm -rf ~/$T.auto ~/$T.auto.dir ~/.$T
done
kill $SRV
rm -rf "$W"
echo "PASSED $pass, FAILED $fail"
[ $fail = 0 ]
