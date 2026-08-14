global env current marker parse
source [file join $env(DS9_REGIONCATALOG_TEST_ROOT) regioncatalog common.tcl]

rcRun {
    # Build a small raw-double fixture at runtime so NaN, negative, and very
    # large finite values are deterministic on every platform we test.
    set rawFile [file join $env(DS9_REGIONCATALOG_TEST_TMP) edge.arr]
    set values {
        -1e100 -8 -7 -6 -5
        -4 -3 -2 -1 0
        1 2 NaN 4 5
        6 7 8 9 10
        11 12 13 14 1e100
    }
    set channel [open $rawFile wb]
    fconfigure $channel -translation binary -encoding iso8859-1
    puts -nonewline $channel [binary format d* $values]
    close $channel

    binary scan [binary format d 1.0] H* nativeOrder
    set architecture [expr {[string range $nativeOrder 0 1] eq {3f} ?
        {big} : {little}}]

    set parse(sock) {}
    set parse(fn) {}
    set argv [list "${rawFile}\[dim=5,bitpix=-64,arch=$architecture\]"]
    set i 0
    ProcessArrayCmd argv i {} {}

    set marker(format) ds9
    set marker(system) image
    RegionCmdCommand {image; circle(3,3,10)}
    set frame $current(frame)
    set id [lindex [$frame get marker id all] 0]
    set result [$frame get marker $id analysis stats data image fk5]
    set measured [dict get [lindex [dict get $result components] 0] values]
    rcAssert {[dict get $measured core.pixel_count] == 24} \
        {NaN pixel was not omitted}
    rcAssert {[dict get $measured core.minimum] == -1e100} \
        {large negative value changed}
    rcAssert {[dict get $measured core.maximum] == 1e100} \
        {large positive value changed}
    rcAssert {abs([dict get $measured core.sum]) < 1e99} \
        {mixed-sign sum is not finite and bounded}

    rcCompareLegacy $frame $id

    $frame threads 1
    set serial [$frame get marker analysis stats all data image fk5]
    $frame threads 8
    set parallel [$frame get marker analysis stats all data image fk5]
    rcAssert {$serial eq $parallel} {edge-case threaded result changed}

    # A small positive fixture has a hand-computable intensity-weighted
    # centroid. Pixel centers are (1,1), (2,1), and (3,1).
    set centroidFile [file join $env(DS9_REGIONCATALOG_TEST_TMP) centroid.arr]
    set channel [open $centroidFile wb]
    fconfigure $channel -translation binary -encoding iso8859-1
    puts -nonewline $channel [binary format d* {1 2 3 -1 -2 -3}]
    close $channel
    set argv [list "${centroidFile}\[xdim=3,ydim=2,bitpix=-64,arch=$architecture\]"]
    set i 0
    ProcessArrayCmd argv i {} {}
    $frame marker delete all
    RegionCmdCommand {image; box(2,1,3,1,0)}
    set id [lindex [$frame get marker id all] 0]
    set result [$frame get marker $id analysis stats data image fk5]
    set measured [dict get [lindex [dict get $result components] 0] values]
    rcClose [dict get $measured core.centroid_image_x] [expr {14.0/6.0}] \
        1e-12 {weighted centroid X is wrong}
    rcClose [dict get $measured core.centroid_image_y] 1.0 \
        1e-12 {weighted centroid Y is wrong}
    RegionCmdCommand {image; box(2,2,3,1,0)}
    set negativeId [lindex [$frame get marker id all] end]
    set negative [$frame get marker $negativeId analysis stats data image fk5]
    set negativeValues [dict get [lindex [dict get $negative components] 0] values]
    rcAssert {[dict get $negativeValues core.pixel_count] == 3} \
        {negative-weight region lost pixels}
    rcAssert {![dict exists $negativeValues core.centroid_image_x] &&
        ![dict exists $negativeValues core.centroid_image_y]} \
        {non-positive total weight produced a centroid}
}
