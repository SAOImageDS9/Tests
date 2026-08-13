global env current ds9 iregioncatalog
source [file join $env(DS9_REGIONCATALOG_TEST_ROOT) regioncatalog common.tcl]

rcRun {
    set frame $current(frame)

    # The process was launched with -catalog make.
    rcAssert {[info exists iregioncatalog(frame,$frame)]} \
        {command-line catalog make did not create a catalog}
    set varname $iregioncatalog(frame,$frame)
    upvar #0 $varname var
    upvar #0 $var(catdb) db
    rcAssert {$var(regioncatalog) && $db(Nrows) == 1} \
        {command-line catalog is invalid}

    set argv {make}
    set i 0
    ProcessCatalogCmd argv i
    rcAssert {$iregioncatalog(frame,$frame) eq $varname} \
        {repeated parser command created another catalog}
    RegionCatalogDestroy $varname

    # SAMP ds9.set delegates to CommSet in safe mode.
    CommSet {} {catalog make} 1
    rcAssert {[info exists iregioncatalog(frame,$frame)]} \
        {SAMP dispatcher did not create a catalog}
    RegionCatalogDestroy $iregioncatalog(frame,$frame)

    set menu $ds9(mb).analysis
    UpdateAnalysisMenu
    set index [$menu index [msgcat::mc {Make Catalog}]]
    rcAssert {$index ne {none}} {Analysis menu item is missing}
    rcAssert {[$menu entrycget $index -state] eq {normal}} \
        {Analysis menu item is disabled for an image}
    $menu invoke $index
    rcAssert {[info exists iregioncatalog(frame,$frame)]} \
        {Analysis menu did not create a catalog}

    # A second frame owns an independent catalog. Deleting the original frame
    # must close only its tool and leave the second association alive.
    set firstCatalog $iregioncatalog(frame,$frame)
    CreateFrame
    set secondFrame $current(frame)
    LoadFitsFile [file join $env(DS9_REGIONCATALOG_TEST_ROOT) data 5x5.fits] {} {}
    RegionCmdCommand {image; box(2,2,1,1,0)}
    set secondCatalog [RegionCatalogCreate $secondFrame]
    rcAssert {$secondCatalog ne $firstCatalog} {two frames shared one catalog}
    GotoFrame $frame
    DeleteFrame $frame
    rcAssert {![info exists iregioncatalog(frame,$frame)]} \
        {deleted frame retained a catalog association}
    rcAssert {[info exists iregioncatalog(frame,$secondFrame)]} \
        {deleting one frame detached another catalog}
    rcAssert {[winfo exists .$secondCatalog]} \
        {deleting one frame closed another catalog window}
    RegionCatalogDestroy $secondCatalog
}
