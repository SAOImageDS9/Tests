global env current marker
source [file join $env(DS9_REGIONCATALOG_TEST_ROOT) regioncatalog common.tcl]

rcRun {
    set marker(format) ds9
    set marker(system) image
    RegionCmdCommand {image; circle(3,3,2)}
    RegionCmdCommand {image; annulus(3,3,0.5,1.5,2.5)}
    RegionCmdCommand {image; ellipse(3,3,2,1,30)}
    RegionCmdCommand {image; box(3,3,3,2,30)}
    RegionCmdCommand {image; polygon(1,1,5,1,5,5,1,5)}
    RegionCmdCommand {image; panda(3,3,0,180,2,0,2.5,2)}
    RegionCmdCommand {image; epanda(3,3,0,180,2,0,0,2.5,1.25,2,30)}
    RegionCmdCommand {image; bpanda(3,3,0,180,2,0,0,5,2.5,2,30)}
    for {set ii 0} {$ii < 80} {incr ii} {
        set radius [expr {0.55 + ($ii % 5) * 0.25}]
        RegionCmdCommand "image; circle(3,3,$radius)"
    }

    set frame $current(frame)
    $frame threads 1
    set serial [$frame get marker analysis stats all data image fk5]
    $frame threads 8
    set parallel [$frame get marker analysis stats all data image fk5]
    rcAssert {$serial eq $parallel} \
        {eight-thread result differs from single-thread result}

    set ids [$frame get marker id all]
    set regions [dict get $parallel regions]
    rcAssert {[llength $regions] == [llength $ids]} {parallel job count changed}
    for {set ii 0} {$ii < [llength $regions]} {incr ii} {
        rcAssert {[dict get [lindex $regions $ii] region_id] == [lindex $ids $ii]} \
            {parallel result order changed}
    }

    $frame marker delete all
    RegionCmdCommand {image; circle(3,3,2)}
    $frame threads 64
    set capped [$frame get marker analysis stats all data image fk5]
    rcAssert {[llength [dict get $capped regions]] == 1} \
        {worker-count cap failed}
}
