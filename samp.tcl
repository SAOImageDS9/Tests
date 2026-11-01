#  Copyright (C) 1999-2024
#  Smithsonian Astrophysical Observatory, Cambridge, MA, USA
#  For conditions of distribution and use, see copyright notice in "copyright"

source /scratch1/kjg/DS9/build_from_source/SAOImageDS9/SAOImageDS9/ds9/library/xmlrpc.tcl
source /scratch1/kjg/DS9/build_from_source/SAOImageDS9/SAOImageDS9/ds9/library/sampclient.tcl
source /scratch1/kjg/DS9/build_from_source/SAOImageDS9/SAOImageDS9/ds9/library/utilshare.tcl

source /scratch1/kjg/DS9/build_from_source/SAOImageDS9/SAOImageDS9/ds9/parsers/xmlrpclex.tcl
source /scratch1/kjg/DS9/build_from_source/SAOImageDS9/SAOImageDS9/ds9/parsers/xmlrpcparser.tab.tcl
source /scratch1/kjg/DS9/build_from_source/SAOImageDS9/SAOImageDS9/ds9/parsers/xmlrpcparser.tcl

proc SAMPConnect {} {
    global debug
    global xmlrpc

    set xmlrpc(parser) false
    if {![SAMPConnectInit true true $debug]} {
	exit
    }
}

proc SAMPConnectMetadata {} {
    global samp

    set map(samp.name) {string "SAMP-DS9 Test"}
    set map(samp.description.text) {string "Testing private DS9 SAMP"}
    set map(samp.icon.url) {string http://ds9.si.edu/sun.png}
    set map(samp.documentation.url) {string http://ds9.si.edu/doc/ref/index.html}

    set map(home.page) {string http://ds9.si.edu/}
    set map(author.name) {string "William Joye"}
    set map(author.email) {string ds9help@cfa.harvard.edu}
    set map(author.affiliation) {string "Smithsonian Astrophysical Observatory"}
    set map(test.version) "string 1.0"

    set param1 [list param [list value [list string $samp(private)]]]
    set param2 [list param [list value [list struct [xmlrpcList2Member [array get map]]]]]
    set params [list params [list $param1 $param2]]

    if {![SAMPSend samp.hub.declareMetadata $params rr]} {
	puts {SAMP-Test: bad samp.hub.decleareMetadata call}
	catch {unset samp}
	# Error
	return
    }
}

proc SAMPConnectSubscriptions {} {
    global samp

    set map(samp.app.ping) {struct {}}

    set map(samp.hub.event.shutdown) {struct {}}
    set map(samp.hub.event.register) {struct {}}
    set map(samp.hub.event.unregister) {struct {}}
    set map(samp.hub.event.metadata) {struct {}}
    set map(samp.hub.event.subscriptions) {struct {}}
    set map(samp.hub.disconnect) {struct {}}

    set param1 [list param [list value [list string $samp(private)]]]
    set param2 [list param [list value [list struct [xmlrpcList2Member [array get map]]]]]
    set params [list params [list $param1 $param2]]

    if {![SAMPSend samp.hub.declareSubscriptions $params rr]} {
	puts {SAMP-Test: bad samp.hub.declareSubscriptions call}
	catch {unset samp}
	# Error
	return
    }
}

# Support

proc SAMPSendDS9 {proc mtype url cmd id} {
    global samp

    # connected?
    if {![info exists samp]} {
	puts {SAMP-Test: not connected}
	return
    }

    switch $mtype {
	ds9.get {
	    switch $proc {
		samp.hub.notify -
		samp.hub.notifyAll {set proc samp.hub.call}
	    }
	}
	ds9.set {
	    set map2(url) "string $url"
	}
    }

    set samp(msgtag) {}
    incr samp(msgcnt)

    # quotes are really needed
    set map2(cmd) "string \"$cmd\""
    set m2 [xmlrpcList2Member [array get map2]]

    set map(samp.mtype) "string $mtype"
    set map(samp.params) [list struct $m2]
    set m1 [xmlrpcList2Member [array get map]]

    set param1 [list param [list value [list string $samp(private)]]]
    switch $proc {
	samp.hub.notify {
	    set param2 [list param [list value [list string $id]]]
	    set param3 [list param [list value [list struct $m1]]]
	    set params [list params [list $param1 $param2 $param3]]
	}
	samp.hub.notifyAll {
	    set param2 [list param [list value [list struct $m1]]]
	    set params [list params [list $param1 $param2]]
	}
	samp.hub.call {
	    set samp(msgtag) "foo$samp(msgcnt)"

	    set param2 [list param [list value [list string $id]]]
	    set param3 [list param [list value [list string $samp(msgtag)]]]
	    set param4 [list param [list value [list struct $m1]]]
	    set params [list params [list $param1 $param2 $param3 $param4]]
	}
	samp.hub.callAll {
	    set samp(msgtag) "foo$samp(msgcnt)"

	    set param2 [list param [list value [list string $samp(msgtag)]]]
	    set param3 [list param [list value [list struct $m1]]]
	    set params [list params [list $param1 $param2 $param3]]
	}
	samp.hub.callAndWait {
	    set param2 [list param [list value [list string $id]]]
	    set param3 [list param [list value [list struct $m1]]]
	    set param4 [list param [list value [list string $samp(timeout)]]]
	    set params [list params [list $param1 $param2 $param3 $param4]]
	}
    }

    SAMPSend $proc $params rr
}

proc SAMPError {message} {
    puts stderr $message
}

proc SAMPUpdateMenus {} {
}

proc ParserError {msg yycnt yy_current_buffer index_} {
    puts stderr "[string range $yy_current_buffer 0 60]"
    puts stderr [format "%*s" $index_ ^]
    puts stderr "$msg"
    exit
}

# Watchdog
# every wait in the samp client (xmlrpc reply, samp.hub.call response)
# is a vwait, so on timeout release the pending waits and move on

proc WatchdogStart {what} {
    global watchdog

    WatchdogStop
    set watchdog(what) $what
    set watchdog(id) [after [expr $watchdog(timeout)*1000] WatchdogExpired]
}

proc WatchdogStop {} {
    global watchdog

    if {[info exists watchdog(id)]} {
	after cancel $watchdog(id)
	unset watchdog(id)
    }
    # still set means the command finished in time
    if {[info exists watchdog(what)]} {
	unset watchdog(what)
	set watchdog(streak) 0
    }
}

# consecutive timeouts carry over between runs via a file
proc WatchdogLoadStreak {} {
    global watchdog
    global env

    if {[info exists env(SAMP_STREAK_FILE)] && \
	    ![catch {open $env(SAMP_STREAK_FILE)} ch]} {
	set nn [string trim [read $ch]]
	close $ch
	if {[string is integer -strict $nn]} {
	    set watchdog(streak) $nn
	}
    }
}

proc WatchdogSaveStreak {} {
    global watchdog
    global env

    if {[info exists env(SAMP_STREAK_FILE)] && \
	    ![catch {open $env(SAMP_STREAK_FILE) w} ch]} {
	puts $ch $watchdog(streak)
	close $ch
    }
}

proc WatchdogExpired {} {
    global watchdog
    global xmlrpc
    global samp

    if {[info exists watchdog(what)]} {
	puts stderr "\nSAMP-Test: TIMEOUT after $watchdog(timeout)s: $watchdog(what)"
	unset watchdog(what)
	incr watchdog(count)
	incr watchdog(streak)

	# ds9 is likely wedged, stop wasting time
	if {$watchdog(streak) >= $watchdog(max)} {
	    puts stderr "SAMP-Test: giving up after $watchdog(streak) consecutive timeouts"
	    WatchdogSaveStreak
	    exit 125
	}
    }

    # release xmlrpcCall (a value <= 0 means failure)
    foreach vv [array names xmlrpc done,*] {
	if {$xmlrpc($vv) == 0} {
	    set xmlrpc($vv) -1
	}
    }
    # release SAMPSend waiting on a call response
    if {[info exists samp]} {
	set samp(msgtag) {}
    }

    # releasing one wait may lead into another, keep at it until
    # the command returns and WatchdogStop cancels us
    set watchdog(id) [after 100 WatchdogExpired]
}

proc prompt {proc block cmd id} {
    global samp

    if {[string range $cmd 0 0] == "#"} {
	puts $cmd
	return
    }
    set item [lindex $cmd 0]

    if {$block && $cmd != {}} {
	puts -nonewline stderr "$cmd> "
    }

    # blank lines don't count toward (or reset) the timeout streak
    if {$item != {}} {
	WatchdogStart $cmd
    }
    switch -- $item {
	con -
	connect {SAMPConnect}
	dis -
	disconnect {SAMPDisconnect}

	set {
	    set mtype ds9.set
	    set url [lindex $cmd 1]
	    set params [lrange $cmd 2 end]

	    if {[lsearch [SAMPGetAppsSubscriptions $mtype] $id]<0} {
		puts {SAMP-Test: subscription ds9.set not found}
	    } else {
		SAMPSendDS9 $proc $mtype $url $params $id
	    }
	}
	get {
	    set mtype ds9.get
	    set params [lrange $cmd 1 end]

	    if {[lsearch [SAMPGetAppsSubscriptions $mtype] $id]<0} {
		puts {SAMP-Test: subscription ds9.get not found}
	    } else {
		SAMPSendDS9 $proc $mtype {} $params $id
	    }
	}

	sleep {
	    after [expr int([lindex $cmd 1]*1000)]
	}
	echo {
	    set params [lrange $cmd 1 end]
	    puts -nonewline "$params"
	}

	bye -
	exit -
	quit {
	    if {[info exists samp]} {
		SAMPDisconnect
	    }
	    exit
	}
	{} {}
	default {
	    puts -nonewline "Unknown command: $cmd"
	}
    }
    WatchdogStop

    after 50
    puts {}
    if {!$block} {
	puts -nonewline stderr {samp> }
    }

    return
}

namespace eval ::mainloop {}

proc ::mainloop::readable {} {
    variable eof
    global proc
    global block
    global id

    if { [gets stdin text] < 0 } {
 	fileevent stdin readable {}
 	set eof 1
    } else {
 	prompt $proc $block $text $id
    }
    return
}

proc ::mainloop::mainloop {} {
    variable eof
    global proc
    global block
    global id

    set ::tcl_interactive 1
    fconfigure stdin -buffering line -blocking 0
    fileevent stdin readable ::mainloop::readable
    prompt $proc $block {} $id

    vwait [namespace which -variable eof]
    return
}

# Start

global samp
set debug 0
set block 0
set name DS9Test
set id {}
set proc samp.hub.call
# seconds
set watchdog(timeout) 20
set watchdog(count) 0
set watchdog(streak) 0
set watchdog(max) 3
WatchdogLoadStreak

foreach arg $argv {
    switch $arg {
	debug {set debug 1}

	batch -
	block {set block 1}
	interactive -
	noblock {set block 0}

	notify {set proc samp.hub.notify}
	notifyAll {set proc samp.hub.notifyAll}
	call {set proc samp.hub.call}
	callAll {set proc samp.hub.callAll}
	callAndWait {set proc samp.hub.callAndWait}

	default {set name $arg}
   }
}

# nothing to move on to if we can't connect
set connectid [after [expr $watchdog(timeout)*1000] {
    puts stderr "SAMP-Test: TIMEOUT after $watchdog(timeout)s: connect"
    exit 124
}]
SAMPConnect
after cancel $connectid

foreach cc $samp(clients) {
    if {$samp($cc,name) == $name} {
	set id $cc
    }
}

if {$id == {}} {
    puts "SAMP-Test: client $name not found"
    return
}

if {$block} {
    set cmd {}
    while {1} {
	prompt $proc $block $cmd $id
	if {[gets stdin cmd] == -1} {
	    if {[info exists samp]} {
		SAMPDisconnect
	    }
	    WatchdogSaveStreak
	    if {$watchdog(count)} {
		exit 124
	    }
	    exit
	}
    }
} else {
    ::mainloop::mainloop
}

