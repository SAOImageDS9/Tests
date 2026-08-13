global env current marker
source [file join $env(DS9_REGIONCATALOG_TEST_ROOT) regioncatalog common.tcl]

rcRun {
    set frame $current(frame)
    set ids [$frame get marker id all]
    rcAssert {[llength $ids] > 20} {mosaic region fixture did not load}

    set supported 0
    foreach id $ids {
        if {![catch {$frame get marker $id analysis stats data image fk5}]} {
            incr supported
            rcCompareLegacy $frame $id
        }
    }
    rcAssert {$supported > 10} {too few supported mosaic regions}

    $frame threads 1
    set serial [$frame get marker analysis stats all data image fk5]
    $frame threads 8
    set parallel [$frame get marker analysis stats all data image fk5]
    rcAssert {$serial eq $parallel} {mosaic threaded result changed}
    rcAssert {[llength [dict get $parallel regions]] == $supported} \
        {mosaic batch omitted supported regions}

    set varname [RegionCatalogCreate $frame]
    rcAssert {$varname ne {}} {mosaic catalog was not created}
    upvar #0 $varname var
    upvar #0 $var(catdb) db
    rcAssert {$db(Nrows) >= $supported} {mosaic catalog rows are missing}
    RegionCatalogDestroy $varname
}
