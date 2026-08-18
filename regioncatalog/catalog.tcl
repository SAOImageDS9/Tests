global env current marker iregioncatalog
source [file join $env(DS9_REGIONCATALOG_TEST_ROOT) regioncatalog common.tcl]

rename PanToFrame RegionCatalogTestOriginalPanToFrame
set ::rcCatalogPanCalls {}
proc PanToFrame {frame x y system sky} {
    lappend ::rcCatalogPanCalls [list $frame $x $y $system $sky]
}

proc rcCatalogKeyAtRow {varname row} {
    upvar #0 $varname var
    upvar #0 $var(tbldb) view
    return [list $view($row,$view(region_id)) $view($row,$view(component))]
}

rcRun {
    set marker(format) ds9
    set marker(system) image
    RegionCmdCommand {image; circle(3,3,1); annulus(3,3,0.5,1.5,2.5); circle(30,30,1)}

    set frame $current(frame)
    set varname [RegionCatalogCreate $frame]
    rcAssert {$varname ne {}} {catalog was not created}
    upvar #0 $varname var
    upvar #0 $var(catdb) db
    rcAssert {$db(Nrows) == 4} {initial component rows are wrong}
    foreach metadata {DataType Unit Precision Ucd Description} {
        rcAssert {[info exists db($metadata)]} "$metadata metadata missing"
        rcAssert {[llength $db($metadata)] == $db(Ncols)} \
            "$metadata metadata is misaligned"
    }
    rcAssert {$var(show) == 0} {catalog markers defaulted on}

    set var(panto) 1
    CATSelectRows $varname plot {1} 1
    rcAssert {[llength $::rcCatalogPanCalls] == 1} \
        {plot selection did not Pan To without catalog markers}
    rcAssert {[lindex [lindex $::rcCatalogPanCalls 0] 0] eq $frame} \
        {plot selection panned the wrong frame}
    set highlightedId [lindex [rcCatalogKeyAtRow $varname 1] 0]
    rcAssert {[$frame get marker $highlightedId highlite]} \
        {Pan To did not highlite the source region}
    rcAssert {[$frame get marker highlite number] == 1} \
        {Pan To highlited more than the source region}

    set emptyId [lindex [$frame get marker id all] 2]
    set emptyRow $var(regioncatalog,record,$emptyId,1)
    rcAssert {[dict get $emptyRow npix] == 0} {empty row pixel count changed}
    rcAssert {[dict get $emptyRow mean] eq {}} {empty row mean is not blank}

    set same [RegionCatalogCreate $frame]
    rcAssert {$same eq $varname} {second catalog was created for one frame}

    RegionCmdCommand {image; box(2,2,2,2,0)}
    set added [lindex [$frame get marker id all] end]
    update idletasks
    rcAssert {$db(Nrows) == 5} {new region did not add a row}
    $frame marker $added move 1 0
    update idletasks
    set row $var(regioncatalog,record,$added,1)
    rcAssert {[dict get $row X] == 3.0} {move did not refresh coordinates}
    set generation $var(regioncatalog,generation)
    for {set ii 0} {$ii < 20} {incr ii} {
        $frame marker $added move 0.01 0
        update idletasks
    }
    rcAssert {$var(regioncatalog,generation) >= $generation + 20} \
        {repeated live edits were dropped}

    set var(sort) mean
    set var(sort,dir) -decreasing
    RegionCatalogRefreshView $varname
    $var(tbl) selection set 1,1
    set selected [rcCatalogKeyAtRow $varname 1]
    RegionCmdCommand {image; circle(1,1,0.75)}
    update idletasks
    set restored {}
    foreach cell [$var(tbl) curselection] {
        set rr [lindex [split $cell ,] 0]
        if {$rr > 0} {lappend restored [rcCatalogKeyAtRow $varname $rr]}
    }
    rcAssert {[lsearch -exact $restored $selected] >= 0} \
        {selection was not preserved across sorted refresh}
    rcAssert {![$frame get marker [lindex $selected 0] select]} \
        {catalog selection selected its source region}

    set var(filter) {$region_id >= 3}
    RegionCatalogRefreshView $varname
    upvar #0 $var(tbldb) filtered
    for {set rr 1} {$rr <= $filtered(Nrows)} {incr rr} {
        rcAssert {$filtered($rr,$filtered(region_id)) >= 3} \
            {filter retained a rejected row}
    }
    set var(filter) {}
    RegionCatalogRefreshView $varname

    set exportFile [file join $env(DS9_REGIONCATALOG_TEST_TMP) catalog.tsv]
    set ::cvarname $varname
    TBLCmdSave $exportFile TSVWrite
    rcAssert {[file exists $exportFile] && [file size $exportFile] > 0} \
        {TSV export was not written}

    set annulus [lindex [$frame get marker id all] 1]
    $frame marker $annulus annulus radius 0.5 3.0 4 image degrees
    update idletasks
    set componentCount 0
    foreach key $var(regioncatalog,keys) {
        if {[lindex $key 0] == $annulus} {incr componentCount}
    }
    rcAssert {$componentCount == 4} {component rows were not reconciled}

    $frame marker $annulus delete
    update idletasks
    foreach key $var(regioncatalog,keys) {
        rcAssert {[lindex $key 0] != $annulus} {deleted rows remain}
    }

    # Teardown must cancel every pending blink callback before its frame can
    # be deleted.  Raw frame commands left in the timer queue caused a Linux
    # race during test shutdown.
    RegionCatalogPanToRow $varname 1
    set blinkTimers $var(regioncatalog,blink,after)
    rcAssert {[llength $blinkTimers] == 5} \
        {region highlite did not schedule the expected blink callbacks}
    RegionCatalogDestroy $varname
    foreach token $blinkTimers {
        rcAssert {[lsearch -exact [after info] $token] < 0} \
            {catalog destruction left a blink callback pending}
    }
    rcAssert {![$frame get marker $highlightedId highlite]} \
        {catalog destruction left the source region highlited}
    rcAssert {![info exists iregioncatalog(frame,$frame)]} \
        {catalog association survived destruction}
}
