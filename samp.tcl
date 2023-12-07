#  Copyright (C) 1999-2023
#  Smithsonian Astrophysical Observatory, Cambridge, MA, USA
#  For conditions of distribution and use, see copyright notice in "copyright"

source /Users/joye/SAOImageDS9/ds9/library/sampshare.tcl
source /Users/joye/SAOImageDS9/ds9/library/utilshare.tcl
source /Users/joye/SAOImageDS9/ds9/library/xmlrpc.tcl
source /Users/joye/SAOImageDS9/ds9/parsers/xmlrpclex.tcl
source /Users/joye/SAOImageDS9/ds9/parsers/xmlrpcparser.tab.tcl
source /Users/joye/SAOImageDS9/ds9/parsers/xmlrpcparser.tcl

proc SAMPConnect {} {
    global debug

    SAMPConnectInit true true $debug
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

proc SAMPSendDS9 {proc mtype url cmd} {
    global samp
    
    # connected?
    if {![info exists samp]} {
	puts {SAMP-Test: not connected}
	return
    }

    # first found
    set id [lindex [SAMPGetAppsSubscriptions $mtype] 0]
    if {$id == {}} {
	puts {SAMP-Test: not subscriptions found}
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
	    set samp(msgtag) "foo"

	    set param2 [list param [list value [list string $id]]]
	    set param3 [list param [list value [list string $samp(msgtag)]]]
	    set param4 [list param [list value [list struct $m1]]]
	    set params [list params [list $param1 $param2 $param3 $param4]]
	}
	samp.hub.callAll {
	    set samp(msgtag) "foo"

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

proc prompt {proc block cmd} {
    if {[string range $cmd 0 0] == "#"} {
	puts $cmd
	return
    }
    set item [lindex $cmd 0]

    if {$block && $cmd != {}} {
	puts -nonewline stderr "$cmd> "
    }

    switch -- $item {
	con -
	connect {SAMPConnect}
	dis -
	disconnect {SAMPDisconnect}

	set {
	    set url [lindex $cmd 1]
	    set params [lrange $cmd 2 end]
	    SAMPSendDS9 $proc ds9.set $url $params
	}
	get {
	    set params [lrange $cmd 1 end]
	    SAMPSendDS9 $proc ds9.get {} $params
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
    
    if { [gets stdin text] < 0 } {
 	fileevent stdin readable {}
 	set eof 1
    } else {
 	prompt $proc $block $text
    }
    return
}
 
proc ::mainloop::mainloop {} {
    variable eof
    global proc
    global block
 
    set ::tcl_interactive 1
    fconfigure stdin -buffering line -blocking 0
    fileevent stdin readable ::mainloop::readable
    prompt $proc $block {}
 
    vwait [namespace which -variable eof]
    return
}

# Start

global samp
set debug 0
set block 0
set proc samp.hub.call

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
   }
}

SAMPConnect

if {$block} {
    set cmd {}
    while {1} {
	prompt $proc $block $cmd
	if {[gets stdin cmd] == -1} {
	    if {[info exists samp]} {
		SAMPDisconnect
	    }
	    exit
	}
    }
} else {
    ::mainloop::mainloop
}

