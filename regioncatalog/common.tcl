rename Error RegionCatalogTestOriginalError
proc Error {message} {error $message}

proc rcAssert {condition message} {
    if {![uplevel 1 [list expr $condition]]} {
        error $message
    }
}

proc rcClose {actual expected tolerance message} {
    if {abs(double($actual)-double($expected)) >
        $tolerance * max(1.0,abs(double($expected)))} {
        error "$message: expected $expected, got $actual"
    }
}

proc rcFinish {status {details {}}} {
    global env
    set channel [open $env(DS9_REGIONCATALOG_TEST_RESULT) w]
    puts $channel $status
    if {$details ne {}} {puts $channel $details}
    close $channel
    QuitDS9
}

proc rcRun {script} {
    if {[catch {uplevel 1 $script} message options]} {
        set details $message
        if {[dict exists $options -errorinfo]} {
            append details "\n" [dict get $options -errorinfo]
        }
        rcFinish FAIL $details
    } else {
        rcFinish PASS
    }
}

proc rcLegacyRows {report} {
    set rows {}
    foreach line [split $report \n] {
        if {[regexp {^[0-9]+\t} $line]} {
            set columns [split $line \t]
            dict set rows [lindex $columns 0] $columns
        }
    }
    return $rows
}

proc rcCompareLegacy {frame id} {
    set result [$frame get marker $id analysis stats data image fk5]
    set legacy [rcLegacyRows [$frame get marker $id analysis stats image fk5]]
    set mapping {
        core.sum 1 core.pixel_count 2 core.mean 3 core.median 4
        core.minimum 5 core.maximum 6 core.variance 7
        core.standard_deviation 8 core.rms 9
    }
    foreach component [dict get $result components] {
        set number [dict get $component component]
        set values [dict get $component values]
        set count [dict get $values core.pixel_count]
        if {$count == 0} {
            rcAssert {![dict exists $legacy $number]} \
                "legacy report retained empty component $number"
            continue
        }
        rcAssert {[dict exists $legacy $number]} \
            "legacy report omitted component $number"
        set row [dict get $legacy $number]
        foreach {key column} $mapping {
            rcAssert {[dict exists $values $key]} \
                "structured result omitted $key"
            rcClose [dict get $values $key] [lindex $row $column] 2e-5 \
                "$key differs from legacy Statistics"
        }
        foreach {key column} {
            core.centroid_image_x 10 core.centroid_image_y 11
        } {
            if {[dict exists $values $key]} {
                rcClose [dict get $values $key] [lindex $row $column] 2e-8 \
                    "$key differs from legacy Statistics"
            }
        }
    }
}
