global env current marker
source [file join $env(DS9_REGIONCATALOG_TEST_ROOT) regioncatalog common.tcl]

set ::rcEvents {}
proc rcEvent {payload} {lappend ::rcEvents $payload}
proc rcDrainEvents {} {
    update idletasks
    set result $::rcEvents
    set ::rcEvents {}
    return $result
}
proc rcOneEvent {} {
    set events [rcDrainEvents]
    rcAssert {[llength $events] == 1} \
        "expected one coalesced event, got [llength $events]: $events"
    return [lindex $events 0]
}

rcRun {
    set frame $current(frame)
    set marker(format) ds9
    set marker(system) image
    $frame marker analysis stats callback rcEvent

    RegionCmdCommand {image; circle(3,3,1); box(3,3,2,2,0)}
    set ids [$frame get marker id all]
    set event [rcOneEvent]
    rcAssert {[dict get $event schema_version] == 1} {bad event schema}
    rcAssert {[dict get $event added] eq [lsort -integer $ids]} \
        {bulk additions were not coalesced}
    rcAssert {[dict get $event changed] eq {}} {unexpected changed IDs}

    set first [lindex $ids 0]
    $frame marker $first move 1 0
    set event [rcOneEvent]
    rcAssert {[dict get $event changed] eq $first} {command move not reported}

    $frame marker $first select only
    $frame marker move begin 4 3
    $frame marker move motion 5 3
    update idletasks
    rcAssert {$::rcEvents eq {}} {interactive move reported before completion}
    $frame marker move end
    set event [rcOneEvent]
    rcAssert {[dict get $event changed] eq $first} \
        {interactive completion not reported}

    set editable [lindex $ids 1]
    $frame marker $editable edit begin 1
    update idletasks
    rcAssert {$::rcEvents eq {}} {interactive edit reported before completion}
    $frame marker edit end
    set event [rcOneEvent]
    rcAssert {[dict get $event changed] eq $editable} \
        {interactive edit completion not reported}

    $frame marker $editable rotate begin
    update idletasks
    rcAssert {$::rcEvents eq {}} {interactive rotate reported before completion}
    $frame marker rotate end
    set event [rcOneEvent]
    rcAssert {[dict get $event changed] eq $editable} \
        {interactive rotate completion not reported}

    $frame marker $first select only
    $frame marker copy
    $frame marker paste
    set event [rcOneEvent]
    set pasted [dict get $event added]
    rcAssert {[llength $pasted] == 1} {paste did not report one added region}
    rcAssert {[lsearch -exact [$frame get marker id all] [lindex $pasted 0]] >= 0} \
        {pasted region ID is not present in the frame}

    $frame marker $first delete
    set event [rcOneEvent]
    rcAssert {[dict get $event deleted] eq $first} {delete not reported}
    $frame marker undo
    set event [rcOneEvent]
    rcAssert {[dict get $event added] eq $first} {undo restoration not reported}

    $frame marker catalog create circle 3 3 1
    update idletasks
    rcAssert {$::rcEvents eq {}} {catalog-layer marker entered source events}

    $frame update
    set event [rcOneEvent]
    rcAssert {[dict get $event image_changed] == 1} \
        {image invalidation not reported}

    $frame marker analysis stats callback
    RegionCmdCommand {image; circle(2,2,1)}
    update idletasks
    rcAssert {$::rcEvents eq {}} {event delivered after unsubscribe}
}
