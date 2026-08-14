global env current marker
source [file join $env(DS9_REGIONCATALOG_TEST_ROOT) regioncatalog common.tcl]

rcRun {
    set marker(format) ds9
    set marker(system) image
    RegionCmdCommand {image; circle(3,3,2)}
    RegionCmdCommand {image; ellipse(3,3,2,1,30)}
    RegionCmdCommand {image; box(3,3,3,2,30)}
    RegionCmdCommand {image; polygon(1,1,5,1,5,5,1,5)}
    RegionCmdCommand {image; annulus(3,3,0.5,1.5,2.5)}
    RegionCmdCommand {image; ellipse(3,3,0.5,0.25,1.5,0.75,2.5,1.25,30)}
    RegionCmdCommand {image; box(3,3,1,0.5,3,1.5,5,2.5,30)}
    RegionCmdCommand {image; panda(3,3,0,180,2,0,2.5,2)}
    RegionCmdCommand {image; epanda(3,3,0,180,2,0,0,2.5,1.25,2,30)}
    RegionCmdCommand {image; bpanda(3,3,0,180,2,0,0,5,2.5,2,30)}
    RegionCmdCommand {image; circle(1,1,2)}
    RegionCmdCommand {image; circle(30,30,2)}
    RegionCmdCommand {image; point(2,2)}
    RegionCmdCommand {image; circle(3,3,1) # fixed=1}

    set frame $current(frame)
    set ids [$frame get marker id all]
    rcAssert {[llength $ids] == 14} {unexpected marker count}

    set schema [$frame get marker analysis stats fields]
    rcAssert {[dict get $schema schema_version] == 1} {bad schema version}
    rcAssert {[llength [dict get $schema fields]] == 17} \
        {unexpected registered-field count}

    foreach id [lrange $ids 0 11] {rcCompareLegacy $frame $id}

    set empty [$frame get marker [lindex $ids 11] analysis stats data image fk5]
    set emptyValues [dict get [lindex [dict get $empty components] 0] values]
    rcAssert {[dict get $emptyValues core.pixel_count] == 0} \
        {empty region has pixels}
    rcAssert {![dict exists $emptyValues core.mean]} \
        {empty-region mean is not missing}

    set circle [$frame get marker [lindex $ids 0] analysis stats data image fk5]
    set values [dict get [lindex [dict get $circle components] 0] values]
    rcAssert {[dict get $values core.pixel_count] == 13} {known pixel count changed}
    rcAssert {[dict get $values core.sum] == 65.0} {known sum changed}
    rcAssert {[dict get $values core.mean] == 5.0} {known mean changed}
    foreach key {core.centroid_image_x core.centroid_image_y} {
        rcAssert {[dict exists $values $key]} "$key missing from known region"
    }

    set batch [$frame get marker analysis stats all data image fk5]
    set regions [dict get $batch regions]
    rcAssert {[llength $regions] == 12} \
        {batch did not filter point and fixed marker}
    for {set ii 0} {$ii < [llength $regions]} {incr ii} {
        rcAssert {[dict get [lindex $regions $ii] region_id] == [lindex $ids $ii]} \
            {batch marker order changed}
    }
    rcAssert {[catch {$frame get marker [lindex $ids 12] analysis stats data image fk5}]} \
        {point unexpectedly supports statistics}
}
