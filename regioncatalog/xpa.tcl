global env current iregioncatalog

set ::rcXPATries 0
set ready [open [file join $env(DS9_REGIONCATALOG_TEST_TMP) xpa.ready] w]
puts $ready READY
close $ready

proc rcXPAFinish {status details} {
    global env
    set channel [open $env(DS9_REGIONCATALOG_TEST_RESULT) w]
    puts $channel $status
    if {$details ne {}} {puts $channel $details}
    close $channel
    QuitDS9
}

proc rcXPAPoll {} {
    global current iregioncatalog
    if {[info exists iregioncatalog(frame,$current(frame))]} {
        set varname $iregioncatalog(frame,$current(frame))
        upvar #0 $varname var
        upvar #0 $var(catdb) db
        if {$var(regioncatalog) && $db(Nrows) == 1} {
            rcXPAFinish PASS {}
        } else {
            rcXPAFinish FAIL {XPA created an invalid catalog}
        }
        return
    }
    if {[incr ::rcXPATries] >= 300} {
        rcXPAFinish FAIL {timed out waiting for XPA catalog make}
        return
    }
    after 100 rcXPAPoll
}

after 100 rcXPAPoll
