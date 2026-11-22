#!/usr/bin/env python
"""Phase 0 check of fitsy's libtiff probe, run inside a live ds9.

Sends ds9 (over XPA, through its `tcl' entry point) a script that runs
`fitsy tiff decode <file>` on every MANIFEST.tsv entry and writes the
results to a file, then compares directory 0 of each with the manifest:
the tags, and nsamples/min/max/sum of every decoded sample. That tests
the stubs wiring, each codec as ds9 has it configured (Deflate comes from
tkimg's img::tiff), byte order, strips vs tiles and planar layout.

`refuse' entries are only reported (Phase 0 decides nothing about them):
the line shows whether libtiff decoded them and, if not, its message.

Start ds9 first, with xpans on PATH (AGENTS.md), e.g.
    PATH=$PWD/../../bin:$PATH \\
      ../../bin/SAOImageDS9.app/Contents/MacOS/ds9 -title DS9TiffProbe &
then
    ~/miniforge/envs/ds9asdf/bin/python check_probe.py [title] [xpa bin dir]
"""

import csv
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))

# Flattens probe.out to one tab-separated line per fixture; dict entries
# are joined with \x1f so values with spaces survive.
CONV_TCL = r'''set ch [open {@OUT@}]
proc clean {s} { string map [list \t { } \n { }] $s }
while {[gets $ch line] >= 0} {
  lassign $line fixture status result
  if {$status ne "OK"} {
    puts "$fixture\tERROR\t0\t[clean $result]"
    continue
  }
  set kv {}
  dict for {k v} [lindex $result 0] { lappend kv "$k=[clean $v]" }
  puts "$fixture\tOK\t[llength $result]\t[join $kv \x1f]"
}
'''

TAGS = ['width', 'height', 'spp', 'compression', 'planar', 'photometric',
        'orientation', 'predictor', 'subfiletype']


def main():
    title = sys.argv[1] if len(sys.argv) > 1 else 'DS9TiffProbe'
    xpabin = sys.argv[2] if len(sys.argv) > 2 else \
        os.path.join(HERE, '..', '..', 'bin')
    rows = list(csv.DictReader(open(os.path.join(HERE, 'MANIFEST.tsv')),
                               delimiter='\t'))

    tmp = tempfile.mkdtemp(prefix='tiffprobe')
    out = os.path.join(tmp, 'probe.out')
    script = os.path.join(tmp, 'probe.tcl')
    with open(script, 'w') as f:
        f.write(f'set _ch [open {{{out}}} w]\n')
        for r in rows:
            fn = os.path.join(HERE, r['fixture'])
            f.write(f'if {{[catch {{fitsy tiff decode {{{fn}}}}} _r]}} '
                    f'{{puts $_ch [list {{{r["fixture"]}}} ERROR $_r]}} '
                    f'else {{puts $_ch [list {{{r["fixture"]}}} OK $_r]}}\n')
        f.write('close $_ch\n')
    subprocess.run([os.path.join(xpabin, 'xpaset'), title, 'tcl'],
                   input=f'source {{{script}}}\n', text=True, check=True)

    # parse the Tcl lists with tclsh would be overkill: each line is
    # {fixture} OK {{dict} {dict}...} - let a Tcl interpreter do it
    tclsh = os.path.join(xpabin, 'tclsh9.0')
    conv = os.path.join(tmp, 'conv.tcl')
    with open(conv, 'w') as f:
        f.write(CONV_TCL.replace('@OUT@', out))
    res = subprocess.run([tclsh, conv], capture_output=True, text=True,
                         check=True).stdout

    got = {}
    for line in res.splitlines():
        fixture, status, ndirs, rest = line.split('\t', 3)
        d = {}
        if status == 'OK':
            for kv in rest.split('\x1f'):
                k, _, v = kv.partition('=')
                d[k] = v
        got[fixture] = (status, int(ndirs), d, rest)

    fails = 0
    for r in rows:
        status, ndirs, d, rest = got.get(r['fixture'],
                                         ('MISSING', 0, {}, ''))
        if r['expect'] == 'refuse':
            if status != 'OK':
                note = 'probe error: ' + rest
            elif d.get('decoded') == '1':
                note = 'libtiff decodes it'
            else:
                note = 'decode fails: ' + d.get('error', '')
            print(f"INFO {r['fixture']}: {note}")
            continue

        problems = []
        if status != 'OK':
            problems.append(rest)
        else:
            if ndirs != int(r['ndirs']):
                problems.append(f'ndirs {ndirs}')
            for k in TAGS:
                if int(d.get(k, -99)) != int(r[k]):
                    problems.append(f'{k}={d.get(k)} want {r[k]}')
            bs = int(d['byteswapped'])
            if bs != (1 if r['byteorder'] == 'MM' else 0):
                problems.append(f'byteswapped={bs}')
            if d.get('decoded') != '1':
                problems.append('decode: ' + d.get('error', ''))
            else:
                if int(d['nsamples']) != int(r['nsamples']):
                    problems.append(f"nsamples {d['nsamples']}")
                for k in ('min', 'max', 'sum'):
                    g, e = float(d[k]), float(r[k])
                    tol = 1e-9 * max(1.0, abs(e)) if 'f' in r['dtype'] \
                        or k == 'sum' else 0
                    if abs(g - e) > tol:
                        problems.append(f'{k}={d[k]} want {r[k]}')
        if problems:
            fails += 1
            print(f"FAIL {r['fixture']}: {'; '.join(problems)}")

    nload = sum(r['expect'] == 'load' for r in rows)
    print(f'{nload} load fixtures probed, {fails} failed')
    return 1 if fails else 0


if __name__ == '__main__':
    sys.exit(main())
