global env current marker wcs
source [file join $env(DS9_REGIONCATALOG_TEST_ROOT) regioncatalog common.tcl]

rename PanToFrame RegionCatalogTestOriginalPanToFrame
set ::rcPanCalls {}
proc PanToFrame {frame x y system sky} {
    lappend ::rcPanCalls [list $frame $x $y $system $sky]
}

rcRun {
    set marker(format) ds9
    set marker(system) image
    set wcs(system) wcs
    set wcs(sky) fk5
    RegionCmdCommand {image; circle(128,128,10)}
    set frame $current(frame)
    set id [lindex [$frame get marker id all] 0]

    set imageResult [$frame get marker $id analysis stats data image fk5]
    rcAssert {[dict get $imageResult area_unit] eq {pixel_squared}} \
        {image area unit changed}
    set physicalResult [$frame get marker $id analysis stats data physical fk5]
    rcAssert {[dict get $physicalResult coordinate_system] eq {physical}} \
        {physical coordinate metadata changed}
    set wcsResult [$frame get marker $id analysis stats data wcs fk5]
    rcAssert {[dict get $wcsResult area_unit] eq {arcsec_squared}} \
        {celestial area unit changed}
    rcAssert {[dict get $imageResult centroid_wcs_system] eq {wcs}} \
        {image query did not fall back to primary WCS for centroid}
    rcAssert {[dict get $imageResult centroid_wcs_unit] eq {deg}} \
        {celestial centroid WCS unit is wrong}
    set imageValues [dict get [lindex [dict get $imageResult components] 0] values]
    set wcsValues [dict get [lindex [dict get $wcsResult components] 0] values]
    foreach key {core.centroid_image_x core.centroid_image_y \
        core.centroid_wcs_x core.centroid_wcs_y} {
        rcAssert {[dict exists $imageValues $key]} "$key missing from image result"
        rcAssert {[dict exists $wcsValues $key]} "$key missing from WCS result"
        rcClose [dict get $imageValues $key] [dict get $wcsValues $key] 1e-12 \
            "$key changed with requested coordinate system"
    }

    set legacy [rcLegacyRows [$frame get marker $id analysis stats wcs fk5]]
    set legacyRow [dict get $legacy 1]
    foreach {key column} {
        core.centroid_image_x 10 core.centroid_image_y 11
        core.centroid_wcs_x 12 core.centroid_wcs_y 13
    } {
        rcClose [dict get $wcsValues $key] [lindex $legacyRow $column] 2e-8 \
            "$key missing from legacy Statistics output"
    }

    set varname [RegionCatalogCreate $frame]
    upvar #0 $varname var
    upvar #0 $var(catdb) db
    rcAssert {[info exists db(RA_J2000)] && [info exists db(DEC_J2000)]} \
        {celestial headings missing}
    rcAssert {[lindex $db(Unit) [expr {$db(RA_J2000)-1}]] eq {deg}} \
        {celestial coordinate unit changed}
    rcAssert {[lindex $db(Ucd) [expr {$db(RA_J2000)-1}]] eq {pos.eq.ra}} \
        {RA UCD missing}
    foreach column {centroid_x centroid_y centroid_wcs_x centroid_wcs_y} {
        rcAssert {[info exists db($column)]} "$column catalog column missing"
    }
    rcAssert {[lindex $db(Unit) [expr {$db(centroid_x)-1}]] eq {pixel}} \
        {image centroid unit changed}
    rcAssert {[lindex $db(Unit) [expr {$db(centroid_wcs_x)-1}]] eq {deg}} \
        {WCS centroid unit changed}
    rcClose $db(1,$db(centroid_wcs_x)) \
        [dict get $wcsValues core.centroid_wcs_x] 1e-12 \
        {catalog WCS centroid does not match structured result}

    set var(panto) 1
    set ::rcPanCalls {}
    RegionCatalogPanToRow $varname 1
    rcAssert {[llength $::rcPanCalls] == 1} {WCS row did not pan once}
    set call [lindex $::rcPanCalls 0]
    rcAssert {[lindex $call 1] == $db(1,$db(RA_J2000))} \
        {WCS pan RA differs from row}
    rcAssert {[lindex $call 2] == $db(1,$db(DEC_J2000))} \
        {WCS pan DEC differs from row}
    rcAssert {[lindex $call 3] eq {wcs} && [lindex $call 4] eq {fk5}} \
        {WCS pan used the wrong system}
    RegionCatalogDestroy $varname
}
