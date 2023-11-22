#  Copyright (C) 1999-2023
#  Smithsonian Astrophysical Observatory, Cambridge, MA, USA
#  For conditions of distribution and use, see copyright notice in "copyright"

source /Users/joye/SAOImageDS9/ds9/library/sampshare.tcl
source /Users/joye/SAOImageDS9/ds9/library/utilshare.tcl
source /Users/joye/SAOImageDS9/ds9/library/xmlrpc.tcl
source /Users/joye/SAOImageDS9/ds9/parsers/xmlrpclex.tcl
source /Users/joye/SAOImageDS9/ds9/parsers/xmlrpcparser.tab.tcl
source /Users/joye/SAOImageDS9/ds9/parsers/xmlrpcparser.tcl

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
    set param2 [list param [list value [list struct [list2rpcMember [array get map]]]]]
    set params [list $param1 $param2]
    
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

    set map(client.env.get) {struct {}}

    set param1 [list param [list value [list string $samp(private)]]]
    set param2 [list param [list value [list struct [list2rpcMember [array get map]]]]]
    set params [list $param1 $param2]

    if {![SAMPSend samp.hub.declareSubscriptions $params rr]} {
	puts {SAMP-Test: bad samp.hub.declareSubscriptions call}
	catch {unset samp}
	# Error
	return
    }
}

proc SAMPSend {method params resultVar} {
    upvar $resultVar result
    global samp

    global debug
    if {$debug(tcl,samp)} {
	puts stderr "SAMPSend: $samp(url) $samp(method) $method $params"
    }

    if {[catch {set result [xmlrpcCall $samp(url) $samp(method) $method $params]}]} {
	if {$debug(tcl,samp)} {
	    puts stderr "SAMPSend: bad xmlrpcCAll"
	}
	# Error
	return 0
    }

    if {$debug(tcl,samp)} {
	puts stderr "SAMPSend Result: $result"
    }

    switch $method {
	samp.hub.notify -
	samp.hub.notifyAll {}

	samp.hub.call -
	samp.hub.callAll {
	    # and now we wait
	    # must be set before
	    vwait samp(msgtag)
	}

	samp.hub.callAndWait {
	    SAMPrpc2List [list params $result] args
	    
	    set map [lindex $args 0]

	    set status {}
	    set value {}
	    set error {}
	    foreach mm $map {
		foreach {key val} $mm {
		    switch -- $key {
			samp.status {set status $val}
			samp.result {set value [lindex $val 1]}
			samp.error  {set error [lindex $val 1]}
		    }
		}
	    }

	    puts -nonewline "$status $value $error"
	}
    }

    return 1
}

proc samp.client.receiveNotification {rpc} {
    global samp

    SAMPrpc2List $rpc args

    set secret [lindex $args 0]
    set id [lindex $args 1]
    set map [lindex $args 2]

    if {$secret != $samp(private)} {
	puts {SAMP-Test: samp.client.recievedNotification bad secret}
	# Error
	return {string ERROR}
    }

    set mtype {}
    set params {}
    foreach mm $map {
	foreach {key val} $mm {
	    switch -- $key {
		samp.mtype {set mtype $val}
		samp.params {set params $val}
	    }
	}
    }

    after 0 "$mtype {} $params"
    return {string OK}
}

proc samp.client.receiveCall {rpc} {
    global samp

    SAMPrpc2List $rpc args

    set secret [lindex $args 0]
    set id [lindex $args 1]
    set msgid [lindex $args 2]
    set map [lindex $args 3]

    if {$secret != $samp(private)} {
	puts {SAMP-Test: samp.client.recievedCall bad secret}
	# Error
	return {string ERROR}
    }

    set mtype {}
    set params {}
    foreach mm $map {
	foreach {key val} $mm {
	    switch -- $key {
		samp.mtype {set mtype $val}
		samp.params {set params $val}
	    }
	}
    }

    after 0 "$mtype \{$msgid\} $params"
    return {string OK}
}

proc samp.client.receiveResponse {rpc} {
    global samp

    SAMPrpc2List $rpc args

    set secret [lindex $args 0]
    set id [lindex $args 1]
    set msgtag [lindex $args 2]
    set map [lindex $args 3]

    if {$secret != $samp(private)} {
	puts {SAMP-Test: samp.client.recievedResponse bad secret}
	# Error
	return {string ERROR}
    }

    if {$msgtag != $samp(msgtag)} {
	puts {SAMP-Test: samp.client.recievedResponse bad msgtag}
	# Error
	return {string ERROR}
    }
    set samp(msgtag) {}

    set status {}
    set value {}
    set error {}
    foreach mm $map {
	foreach {key val} $mm {
	    switch -- $key {
		samp.status {set status $val}
		samp.result {set value [lindex $val 1]}
		samp.error  {set error [lindex $val 1]}
	    }
	}
    }

    puts -nonewline "$status $value $error"

    return {string OK}
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
    set m2 [list2rpcMember [array get map2]]

    set map(samp.mtype) "string $mtype"
    set map(samp.params) [list struct $m2]
    set m1 [list2rpcMember [array get map]]

    set param1 [list param [list value [list string $samp(private)]]]
    switch $proc {
	samp.hub.notify {
	    set param2 [list param [list value [list string $id]]]
	    set param3 [list param [list value [list struct $m1]]]
	    set params [list $param1 $param2 $param3]
	}
	samp.hub.notifyAll {
	    set param2 [list param [list value [list struct $m1]]]
	    set params [list $param1 $param2]
	}
	samp.hub.call {
	    set samp(msgtag) "foo"

	    set param2 [list param [list value [list string $id]]]
	    set param3 [list param [list value [list string $samp(msgtag)]]]
	    set param4 [list param [list value [list struct $m1]]]
	    set params [list $param1 $param2 $param3 $param4]
	}
	samp.hub.callAll {
	    set samp(msgtag) "foo"

	    set param2 [list param [list value [list string $samp(msgtag)]]]
	    set param3 [list param [list value [list struct $m1]]]
	    set params [list $param1 $param2 $param3]
	}
	samp.hub.callAndWait {
	    set param2 [list param [list value [list string $id]]]
	    set param3 [list param [list value [list struct $m1]]]
	    set param4 [list param [list value [list string $samp(timeout)]]]
	    set params [list $param1 $param2 $param3 $param4]
	}
    }
    
    SAMPSend $proc $params rr
}

proc SAMPParseHub {} {
    global samp
    global env

    set fn {}

    if {[info exists env(SAMP_HUB)]} {
	if {$env(SAMP_HUB) != {}} {
	    set exp {std-lockurl:(.*)}
	    if {[regexp $exp $env(SAMP_HUB) dummy url]} {

		ParseURL $url rr
		switch -- $rr(scheme) {
		    file {set fn $rr(path)}
		    default {}
		}
	    }
	}
    }

    if {$fn == {}} {
	set fn [file join [GetEnvHome] {.samp}]
    }

    # no hub to be found
    if {![file exist $fn]} {
	return 0
    }
    if {[catch {set fp [open $fn r]}]} {
	return 0
    }

    set samp(secret) {}
    set samp(url) {}
    set samp(method) {}
    set samp(fn) $fn

    while {1} {
	if {[gets $fp line] == -1} {
	    break
	}

	# skip any comments
	if {[string range $line 0 0] == "#"} {
	    continue;
	}

	if {[regexp -nocase {samp.secret=(.*)} $line foo ss]} {
	    set samp(secret) $ss
	}
	if {[regexp -nocase {samp.hub.xmlrpc.url=(.*)} $line foo url]} {
	    if {[ParseURL $url r]} {
		set samp(url) $r(scheme)://$r(authority)
		set samp(method) [string range $r(path) 1 end]
	    }
	}
    }
    catch {close $fp}

    if {$samp(secret) == {} || $samp(url) == {}} {
	SAMPDelTmpFiles
	catch {unset samp}
	return 0
    }

    return 1
}

proc Error {message} {
    puts sterr $message
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
	connect {SAMPConnect 1}
	dis -
	disconnect {SAMPDisconnect 1}

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
	    SAMPDisconnect 1
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

set debug(tcl,samp) 0
set block 0
set proc samp.hub.call

SAMPConnect 1

foreach arg $argv {
    switch $arg {
	debug {
	    global debug
	    set debug(tcl,samp) 1
	}

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

if {$block} {
    set cmd {}
    while {1} {
	prompt $proc $block $cmd
	if {[gets stdin cmd] == -1} {
	    SAMPDisconnect 1
	    exit
	}
    }
} else {
    ::mainloop::mainloop
}

