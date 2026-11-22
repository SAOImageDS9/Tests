#!/usr/bin/env python
"""Phase 2 check: every way a TIFF reaches ds9 picks the right reader.

A native load is recognised by its header, which carries the comment
`Read from TIFF at full depth', and by its BITPIX; a photo load has
neither (BITPIX 8, values 0-255). Drives a live ds9 over XPA:

- XPA by file name: auto (default), native, photo; auto on 8-bit gray,
  on colour, and on a file only the photo path reads; native falling back
  to photo; slice; mask (native, and refused for a photo-only file)
- XPA by data (`cat f | xpaset ds9 tiff'), auto and photo
- the SAMP path (ProcessTIFFCmd with a downloaded file and a name)
- the preference pds9(tiff,mode)
- recent files (a native load is recorded as type tiff and reopens
  natively) and backup/restore of a native load
- the command line, by relaunching ds9: -tiff, -tiff native/photo,
  -tiff - (stdin), and -mask -tiff native

    ~/miniforge/envs/ds9asdf/bin/python check_entry.py [xpa bin dir]
"""

import os
import shutil
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
TOP = os.path.abspath(os.path.join(HERE, '..', '..'))
XPA = sys.argv[1] if len(sys.argv) > 1 else os.path.join(TOP, 'bin')
DS9 = os.path.join(TOP, 'bin', 'SAOImageDS9.app', 'Contents', 'MacOS', 'ds9')
TITLE = 'DS9TiffEntry'
TMP = tempfile.mkdtemp(prefix='tiffentry')

U2 = os.path.join(HERE, 'dtype', 'gray_u2_deflate.tif')    # (37,1)=65535
U1 = os.path.join(HERE, 'dtype', 'gray_u1_none.tif')
F4 = os.path.join(HERE, 'dtype', 'gray_f4_lzw.tif')
RGB8 = os.path.join(HERE, 'rgb', 'rgb_u1_contig_strip.tif')
RGB16 = os.path.join(HERE, 'rgb', 'rgb_u2_contig_strip.tif')
PAL = os.path.join(HERE, 'unsupported', 'palette_u1.tif')
FITS = os.path.join(HERE, 'dtype', 'gray_u2_none.fits')

results = []


def env():
    e = dict(os.environ)
    e['PATH'] = XPA + os.pathsep + e['PATH']
    return e


def xpaset(*args, data=None):
    cmd = [os.path.join(XPA, 'xpaset')]
    if data is None:
        cmd.append('-p')
    cmd += [TITLE] + list(args)
    return subprocess.run(cmd, input=data, capture_output=True, env=env())


def xpaget(*args):
    return subprocess.run([os.path.join(XPA, 'xpaget'), TITLE] + list(args),
                          capture_output=True, text=True, env=env()).stdout


def tcl(script):
    """Run a Tcl script in ds9; it may write lines to $_out."""
    out = os.path.join(TMP, 'tcl.out')
    if os.path.exists(out):
        os.remove(out)
    fn = os.path.join(TMP, 'tcl.tcl')
    with open(fn, 'w') as f:
        f.write(f'set _out [open {{{out}}} w]\n{script}\nclose $_out\n')
    xpaset('tcl', data=f'source {{{fn}}}\n'.encode())
    return open(out).read() if os.path.exists(out) else ''


def state():
    hdr = xpaget('fits', 'header')
    native = 'Read from TIFF at full depth' in hdr
    bitpix = None
    for line in hdr.splitlines():
        if line.startswith('BITPIX'):
            bitpix = int(line.split('=')[1].split('/')[0])
    return native, bitpix


def check(name, want_native, want_bitpix=None, value=None):
    native, bitpix = state()
    ok = native == want_native
    detail = f'native={int(native)} BITPIX={bitpix}'
    if want_bitpix is not None and bitpix != want_bitpix:
        ok = False
    if value is not None:
        v = xpaget('data', 'image', '37', '1', '1', '1', 'yes').strip()
        detail += f' (37,1)={v}'
        if v != str(value):
            ok = False
    results.append((ok, name, detail))


def note(ok, name, detail):
    results.append((ok, name, detail))


def start(*args, stdin=None):
    for f in (os.path.expanduser(f'~/{TITLE}.auto'),
              os.path.expanduser(f'~/{TITLE}.auto.dir')):
        shutil.rmtree(f, ignore_errors=True)
        if os.path.exists(f):
            os.remove(f)
    p = subprocess.Popen([DS9, '-title', TITLE] + list(args),
                         stdin=stdin or subprocess.DEVNULL,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                         env=env(), cwd=HERE)
    for _ in range(60):
        r = subprocess.run([os.path.join(XPA, 'xpaaccess'), TITLE],
                           capture_output=True, text=True, env=env())
        if r.stdout.strip() == 'yes':
            break
        time.sleep(0.5)
    time.sleep(1.0)     # let command-line loads finish
    tcl('set pds9(confirm) 0')
    return p


def stop(p):
    xpaset('exit')
    try:
        p.wait(20)
    except subprocess.TimeoutExpired:
        p.kill()


def main():
    # recent loads go to the user's real recent list: keep it and put it
    # back afterwards
    recent = None
    p = start()
    rfn = tcl('puts $_out [RecentFileName]').strip()
    if rfn and os.path.exists(rfn):
        recent = open(rfn, 'rb').read()
    try:
        return run(p)
    finally:
        if rfn:
            if recent is None:
                if os.path.exists(rfn):
                    os.remove(rfn)
            else:
                open(rfn, 'wb').write(recent)


def run(p):

    # XPA by file name
    xpaset('tiff', U2)
    check('xpa auto, uint16', True, -16, 65535)
    xpaset('tiff', 'photo', U2)
    check('xpa photo, uint16', False, 8, 255)
    xpaset('tiff', 'native', U2)
    check('xpa native, uint16', True, -16, 65535)
    xpaset('tiff', F4)
    check('xpa auto, float32', True, -32)
    xpaset('tiff', U1)
    check('xpa auto, uint8 gray -> photo', False, 8)
    xpaset('tiff', 'native', U1)
    check('xpa native, uint8 gray', True, 8)
    xpaset('tiff', 'new', RGB16)
    check('xpa auto, RGB uint16 -> photo (Phase 3)', False, 8)
    xpaset('tiff', 'native', PAL)
    check('xpa native, palette -> falls back to photo', False, 8)
    xpaset('tiff', 'slice', U2)
    check('xpa slice -> photo', False, 8)

    # preference
    tcl('set pds9(tiff,mode) photo')
    xpaset('tiff', U2)
    check('pref photo, uint16', False, 8, 255)
    xpaset('tiff', 'auto', U2)
    check('pref photo, explicit auto overrides', True, -16, 65535)
    tcl('set pds9(tiff,mode) native')
    xpaset('tiff', U1)
    check('pref native, uint8 gray', True, 8)
    tcl('set pds9(tiff,mode) auto')

    # mask
    xpaset('fits', FITS)
    xpaset('tiff', 'mask', 'native', U1)
    n = tcl('puts $_out [$current(frame) get mask count]').strip()
    note(n == '1', 'xpa mask native', f'mask count {n}')
    r = xpaset('tiff', 'mask', RGB8)
    note(b'mask needs the full-depth reader' in r.stdout + r.stderr,
         'xpa mask on a photo-only file is refused',
         (r.stdout + r.stderr).decode().strip()[:80])

    # XPA data on the channel
    data = open(U2, 'rb').read()
    xpaset('tiff', data=data)
    check('xpa data, auto', True, -16, 65535)
    xpaset('tiff', 'photo', data=data)
    check('xpa data, photo', False, 8, 255)
    left = [f for f in os.listdir(tempfile.gettempdir())
            if f.startswith('ds9tiff')] + \
        [f for f in os.listdir('/tmp') if f.startswith('ds9tiff')]
    note(not left, 'temporary files removed', ' '.join(left) or 'none left')

    # SAMP: a downloaded file and the name to show
    samp = os.path.join(TMP, 'download.tif')
    shutil.copy(U2, samp)
    tcl(f'set v {{samp-name.tif}}\nset i 0\nProcessTIFFCmd v i {{}} {{{samp}}}')
    check('samp path, auto', True, -16, 65535)
    name = xpaget('file').strip()
    note(name.endswith('samp-name.tif'), 'samp shows the given name', name)

    # recent files
    xpaset('tiff', U2)
    rec = tcl('RecentRead\nforeach r $irecent(list) {puts $_out $r}')
    first = rec.splitlines()[0] if rec else ''
    note(first.startswith('tiff ') and U2 in first,
         'recent records a native load as tiff', first[:100])
    # something else in between (not U2 again: RecentAdd keeps one entry
    # per file name, so a photo load of U2 would replace the tiff entry)
    xpaset('fits', FITS)
    tcl(f'RecentRead\nforeach r $irecent(list) {{\n'
        f'  if {{[lindex $r 0] == {{tiff}}}} {{RecentOpen $r; break}}\n}}')
    check('recent reopens natively', True, -16, 65535)

    # backup and restore
    xpaset('tiff', U2)
    bck = os.path.join(TMP, 'b.bck')
    xpaset('backup', bck)
    xpaset('frame', 'delete', 'all')
    xpaset('frame', 'new')
    xpaset('restore', bck)
    check('backup/restore of a native load', True, -16, 65535)

    stop(p)

    # command line
    for args, want, bp, val, name in [
        (['-tiff', U2], True, -16, 65535, 'cmdline -tiff (auto)'),
        (['-tiff', 'native', U1], True, 8, None, 'cmdline -tiff native'),
        (['-tiff', 'photo', U2], False, 8, 255, 'cmdline -tiff photo'),
    ]:
        p = start(*args)
        check(name, want, bp, val)
        stop(p)
    with open(U2, 'rb') as f:
        p = start('-tiff', '-', stdin=f)
        check('cmdline -tiff - (stdin)', True, -16, 65535)
        stop(p)
    p = start(FITS, '-mask', '-tiff', 'native', U1)
    n = tcl('puts $_out [$current(frame) get mask count]').strip()
    note(n == '1', 'cmdline -mask -tiff native', f'mask count {n}')
    stop(p)

    fails = 0
    for ok, name, detail in results:
        print(f"{'ok  ' if ok else 'FAIL'} {name}: {detail}")
        fails += not ok
    print(f'{len(results)} checks, {fails} failed')
    return 1 if fails else 0


if __name__ == '__main__':
    sys.exit(main())
