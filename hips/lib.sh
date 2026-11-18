# What every HiPS suite shares. A suite names its ds9 (T) and sources
# this, from the top of the ds9 tree:
#
#   T=HiPSFoo
#   . Tests/hips/lib.sh
#
# It sets TOP, X (bin), H (Tests/hips), PY and W (a new work directory),
# and defines the tally (ok, bad, check, finish), ds9 and server helpers,
# and a trap: however the suite ends (finish, a failed command, ^C), its
# ds9, server and hub are stopped and W, ~/.$T and ds9's auto-backup
# files are removed. With KEEPFAIL set, W is kept when a check failed.
#
# The sample HiPS a suite reads stay named in the suite ($TOP/hips/...):
# Tests/hips.sh reads them there to skip a suite whose data is missing.

# T names ds9's files too (never empty here: ~/.$T is a home directory)
if [ -z "$T" ]; then
    echo "lib.sh: set T before sourcing it" >&2
    exit 2
fi
TOP=$PWD
X=$TOP/bin
H=$TOP/Tests/hips
PY=${PY:-$HOME/miniforge/envs/hpxtest/bin/python}
W=$(mktemp -d "${TMPDIR:-/tmp}/$(echo $T | tr A-Z a-z).XXXXXX")
pass=0; fail=0
DS9PID=; SRV=; HUB=
# a crashed or killed earlier run leaves these (AGENTS.md)
rm -rf ~/.$T ~/$T.auto ~/$T.auto.dir

ok()  { pass=$((pass+1)); echo "  ok   $*"; }
bad() { fail=$((fail+1)); echo "  FAIL $*"; }
# check <name> <got> <want>
check() { if [ "$2" = "$3" ]; then ok "$1: $2"; else bad "$1: got '$2', want '$3'"; fi; }
# the line Tests/hips.sh reads, and the exit status (the trap cleans up)
finish() { echo "PASSED $pass, FAILED $fail"; [ $fail = 0 ]; exit; }

nap() { perl -e 'select(undef,undef,undef,0.3)'; }

# tcl <script>: run Tcl in ds9 (uplevel #0, over XPA) and print its result
tcl() { rm -f $W/q; echo 'set f [open '$W'/q w]; puts $f ['"$1"']; close $f' | $X/xpaset $T tcl; cat $W/q 2>/dev/null; }
size() { tcl '$current(frame) get fits size'; }
nframes() { $X/xpaget $T frame all | wc -w | tr -d ' '; }
frames() { nframes; }
kw() { $X/xpaget $T fits header keyword $1; }
hdr() { $X/xpaget $T fits header; }
# shot <name>: the current frame as $W/<name>.fits, to compare
shot() { rm -f $W/$1.fits; $X/xpaset -p $T save fits $W/$1.fits; }
# Error boxes collected in ::errs instead of shown (start does this when
# ERRS is set); lasterr is the latest
errors() { echo 'set ::errs {}; proc Error {m} {lappend ::errs $m}' | $X/xpaset $T tcl; }
lasterr() { tcl 'lindex $::errs end'; }
# the server's requests since the last mark: reqs [pattern]
mark() { : > $W/log; }
reqs() { grep -c "${1:-.}" $W/log; }
# opened <window>: wait for a modal dialog's grab
opened() { for i in $(seq 1 40); do [ "$(tcl 'grab current')" = "$1" ] && break; nap; done; }

# start [ds9 args]: ds9 titled $T, once it answers XPA. DS9ENV is put in
# its environment, its output goes to DS9OUT (default nowhere), and it
# gets DS9WAIT naps to register (default 40).
start() {
    rm -rf ~/$T.auto ~/$T.auto.dir
    env $DS9ENV PATH="$X:$PATH" $X/ds9 -title $T "$@" >${DS9OUT:-/dev/null} 2>&1 &
    DS9PID=$!
    for i in $(seq 1 ${DS9WAIT:-40}); do [ "$($X/xpaaccess -n $T)" -ge 1 ] && break; nap; done
    [ -n "$ERRS" ] && errors
}
stop() {
    $X/xpaset -p $T exit
    for i in $(seq 1 20); do [ "$($X/xpaaccess -n $T)" = 0 ] && break; nap; done
}

# serve: hipsserve.py over $W/www, logging to $W/log, https when
# HIPSSERVE_CERT and HIPSSERVE_KEY are set; U is its base URL
serve() {
    env ${HIPSSERVE_CERT:+HIPSSERVE_CERT=$HIPSSERVE_CERT HIPSSERVE_KEY=$HIPSSERVE_KEY} \
	"$PY" -I $H/hipsserve.py $W/www $W/port $W/log &
    SRV=$!
    for i in $(seq 1 30); do [ -s $W/port ] && break; nap; done
    U=http${HIPSSERVE_CERT:+s}://127.0.0.1:$(cat $W/port)
}

hipscleanup() {
    local rc=$?
    trap - EXIT
    # ds9 still up (a failed or interrupted suite): ask it to exit, in
    # the background in case a modal dialog holds it, then make sure
    if [ -n "$T" ] && [ "$($X/xpaaccess -n $T 2>/dev/null)" -ge 1 ] 2>/dev/null; then
	$X/xpaset -p $T exit >/dev/null 2>&1 &
	for i in $(seq 1 20); do [ "$($X/xpaaccess -n $T 2>/dev/null)" = 0 ] && break; nap; done
    fi
    [ -n "$DS9PID" ] && kill -0 $DS9PID 2>/dev/null && kill $DS9PID 2>/dev/null
    for p in $SRV $HUB; do kill $p 2>/dev/null; wait $p 2>/dev/null; done
    if [ -n "$KEEPFAIL" ] && [ "$fail" != 0 ]; then
	echo "work dir kept: $W"
    else
	rm -rf "$W"
    fi
    [ -n "$T" ] && rm -rf ~/.$T ~/$T.auto ~/$T.auto.dir
    exit $rc
}
trap hipscleanup EXIT
trap 'exit 130' INT TERM
