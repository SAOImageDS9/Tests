# hipsload <spec> <out>: load a HiPS into the current frame, record the
# result (fits size, error) in <out>
proc hipsload {spec out} {
    global current ds9
    set ds9(msg) {}
    set rc [catch {$current(frame) load hips "\{$spec\}"} err]
    set f [open $out w]
    puts $f "[$current(frame) get fits size] rc=$rc $err $ds9(msg)"
    close $f
}
# refload <file[opts]> <out>: load an ordinary HEALPix FITS file
proc refload {spec out} {
    global current ds9
    set ds9(msg) {}
    set rc [catch {$current(frame) load fits "\{$spec\}" mmapincr} err]
    set f [open $out w]
    puts $f "[$current(frame) get fits size] rc=$rc $err $ds9(msg)"
    close $f
}
proc savefr {out} {
    global current
    catch {file delete $out}
    $current(frame) save fits image file "\{$out\}"
}
