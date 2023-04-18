#  Copyright (C) 1999-2011
#  Smithsonian Astrophysical Observatory, Cambridge, MA, USA
#  For conditions of distribution and use, see copyright notice in "copyright"

source xmlrpc.tcl

proc SAMPConnect {} {
    global samp
    global sampmap

    # connected?
    if {$samp(status)} {
	puts {SAMP: already connected}
	return
    }

    # reset samp array
    set samp(apps,get) {}
    set samp(apps,set) {}
    set samp(apps,evn) {}

    # delete any old tmp files
    SAMPDelTmpFiles

    # can we find a hub?
    if {![SAMPParseHub]} {
 	if {$samp(debug)} {
	    puts "SAMP-Test: unable to locate HUB"
	}
	return
    }

    # register
    set params [list "string $samp(secret)"]
    if {![SAMPSend {samp.hub.register} $params rr]} {
	puts {SAMP: internal error}
	return
    }
    set rr [lindex $rr 1]
    foreach ff $rr {
	foreach {key val} $ff {
	    switch -- $key {
		samp.hub-id {set samp(hub) $val}
		samp.self-id {set samp(self) $val}
		samp.private-key {set samp(private) $val}
	    }
	}
    }

    # declare metadata
    catch {unset sampmap}
    set sampmap(samp.name) {string "SAMP-DS9 Test"}
    set sampmap(samp.description.text) {string "Testing private DS9 SAMP"}
    set sampmap(samp.icon.url) {string "http://hea-www.harvard.edu/RD/ds9/samp.gif"}

    set sampmap(author.name) {string "William Joye"}
    set sampmap(author.email) {string "saord@cfa.harvard.edu"}
    set sampmap(author.affiliation) {string "Smithsonian Astrophysical Observatory"}
    set param1 [list "string $samp(private)"]
    set param2 [list "struct sampmap"]
    set params "$param1 $param2"
    if {![SAMPSend {samp.hub.declareMetadata} $params rr]} {
	puts {SAMP: internal error}
	return
    }

    # who are we
    set samp(port) [lindex [fconfigure [xmlrpc::serve 0] -sockname] 2]
    set samp(home) "[info hostname]:$samp(port)"

    # callback
    set param1 [list "string $samp(private)"]
    set param2 [list "string http://$samp(home)"]
    set params "$param1 $param2"
    if {![SAMPSend {samp.hub.setXmlrpcCallback} $params rr]} {
	puts {SAMP: internal error}
	return
    }

    # declare subscriptions
    catch {unset sampmap}
    set sampmap(samp.app.ping) {struct mapPing}

    set sampmap(samp.hub.event.shutdown) {struct mapShutdown}
    set sampmap(samp.hub.event.register) {struct mapRegister}
    set sampmap(samp.hub.event.unregister) {struct mapUnregister}
    set sampmap(samp.hub.disconnect) {struct mapDisconnect}

#    set sampmap(ds9.get) {struct mapDS9Get}
#    set sampmap(ds9.set) {struct mapDS9Set}

    set param1 [list "string $samp(private)"]
    set param2 [list "struct sampmap"]
    set params "$param1 $param2" 
    if {![SAMPSend {samp.hub.declareSubscriptions} $params rr]} {
	puts {SAMP: internal error}
	return
    }

    # wait
    after $samp(timeout,update)
    SAMPUpdate
    set samp(status) 1
}

proc SAMPDisconnect {} {
    global samp

    # connected?
    if {!$samp(status)} {
	return
    }

    # disconnect
    set params [list "string $samp(private)"]
    set rr {}
    SAMPSend {samp.hub.unregister} $params rr
    SAMPShutdown
}

# Support

proc SAMPShutdown {} {
    global samp

    # delete any files
    SAMPDelTmpFiles

    # reset 
    set samp(status) 0

    # close the server socket if still up
    catch {close $xmlrpc::acceptfd}

    # update the menus
    set samp(apps,get) {}
    set samp(apps,set) {}
    set samp(apps,env) {}
}

proc SAMPUpdate {} {
    # this routine is run after a delay since it needs to 
    # call the hub for metadata

    global samp
    
    if {$samp(debug)} {
	puts "SAMP-Test: SAMPUpdate"
    }

    # get
    set param1 [list "string $samp(private)"]
    set param2 [list "string ds9.get"]
    set params "$param1 $param2" 
    if {![SAMPSend {samp.hub.getSubscribedClients} $params rr]} {
	return
    }
    
    set samp(apps,get) {}
    foreach arg [lindex $rr 1] {
	foreach {key val} $arg {
	    if {$key != {}} {
		lappend samp(apps,get) [list $key [SAMPGetAppName $key]]
	    }
	}
    }

    # set
    set param1 [list "string $samp(private)"]
    set param2 [list "string ds9.set"]
    set params "$param1 $param2" 
    if {![SAMPSend {samp.hub.getSubscribedClients} $params rr]} {
	return
    }
    
    set samp(apps,set) {}
    foreach arg [lindex $rr 1] {
	foreach {key val} $arg {
	    if {$key != {}} {
		lappend samp(apps,set) [list $key [SAMPGetAppName $key]]
	    }
	}
    }

    # env
    set param1 [list "string $samp(private)"]
    set param2 [list "string client.env.get"]
    set params "$param1 $param2" 
    if {![SAMPSend {samp.hub.getSubscribedClients} $params rr]} {
	return
    }
    
    set samp(apps,env) {}
    foreach arg [lindex $rr 1] {
	foreach {key val} $arg {
	    if {$key != {}} {
		lappend samp(apps,env) [list $key [SAMPGetAppName $key]]
	    }
	}
    }

    if {$samp(debug)} {
	puts "SAMP-Test: SAMPUpdate ds9.get apps: $samp(apps,get)"
	puts "SAMP-Test: SAMPUpdate ds9.set apps: $samp(apps,set)"
	puts "SAMP-Test: SAMPUpdate client.env.get apps: $samp(apps,env)"
    }
}

proc SAMPSend {method params resultVar} {
    upvar $resultVar result

    global samp

    if {$samp(debug)} {
	puts "SAMP-Test: SAMPSend $method $params"
    }

    if {[catch {set result [xmlrpc::call $samp(url) $samp(method) $method $params]}]} {
	if {$samp(debug)} {
	    puts "SAMP-Test: SAMPSend Error: $result"
	}
	return 0
    }

    if {$samp(debug)} {
	puts "SAMP-Test: SAMPSend Result: $result"
    }
    
    set status {}
    set value {}
    set error {}
    foreach arg [lindex $result 1] {
	foreach {key val} $arg {
	    switch -- $key {
		samp.result {set value [lindex [lindex $val 0] 1]}
		samp.status {set status $val}
		samp.error  {set error [lindex [lindex $val 0] 1]}
	    }
	}
    }
    if {$status != {}} {
	puts -nonewline "$status $value $error"
    }

    return 1
}

proc SAMPReply {msgid status {result {}} {error {}}} {
    global samp
    global sampmap
    global sampmap2

    if {$samp(debug)} {
	puts "SAMP-Test: SAMPReply $msgid"
    }

    catch {unset sampmap}
    catch {unset sampmap2}
    catch {unset sampmap3}
    switch -- $status {
	OK {
	    set sampmap(samp.status) {string "samp.ok"}
	    set sampmap(samp.result) {struct sampmap2}
	    set sampmap2(value) "string \"[XMLQuote $result]\""
	}
	WARNING {
	    set sampmap(samp.status) {string "samp.error"}
	    set sampmap(samp.result)  {struct sampmap2}
	    set sampmap(samp.error)  {struct sampmap3}
	    set sampmap2(value) "string \"[XMLQuote $result]\""
	    set sampmap2(samp.errortxt) "string \"[XMLQuote $error]\""
	}
	ERROR {
	    set sampmap(samp.status) {string "samp.error"}
	    set sampmap(samp.error)  {struct sampmap3}
	    set sampmap3(samp.errortext) "string \"[XMLQuote $error]\""
	}
    }
    set param1 [list "string $samp(private)"]
    set param2 [list "string $msgid"]
    set param3 [list "struct sampmap"]
    set params "$param1 $param2 $param3"
    if {![SAMPSend {samp.hub.reply} $params rr]} {
	return
    }
}

# receiveNotification(string sender-id, map message)
proc samp.client.receiveNotification {args} {
    global samp
    if {$samp(debug)} {
	puts "SAMP-Test: samp.client.receiveNotification $args"
    }
    set secret [lindex $args 0]
    set id [lindex $args 1]
    set map [lindex $args 2]

    set mtype [lindex $map 0]
    set params [lindex $map 1]

    set method [lindex $mtype 1]
    set args [lindex $params 1]

    switch -- $method {
	samp.hub.event.shutdown {SAMPRcvdEventShutdown args}
	samp.hub.event.register {SAMPRcvdEventRegister args}
	samp.hub.event.unregister {SAMPRcvdEventUnregister args}
	samp.hub.disconnect {SAMPRcvdDisconnect args}
	default {
	    if {$samp(debug)} {
		puts "SAMP-Test: samp.client.receiveNotification bad method $method"
	    }
	}
    }
    return {string OK}
}

# receiveCall(string sender-id, string msg-id, map message)
proc samp.client.receiveCall {args} {
    global samp
    if {$samp(debug)} {
	puts "SAMP-Test: samp.client.receiveCall $args"
    }

    set secret [lindex $args 0]
    set id [lindex $args 1]
    set msgid [lindex $args 2]
    set map [lindex $args 3]

    set mtype [lindex $map 0]
    set params [lindex $map 1]

    set method [lindex $mtype 1]
    set args [lindex $params 1]

    switch -- $method {
	samp.app.ping {SAMPReply $msgid OK {}}
	default {
	    SAMPReply $msgid ERROR "Unknown subscription: $method"
	    if {$samp(debug)} {
		puts "SAMP-Test: samp.client.receiveCall bad method $method"
	    }
	}
    }
    return {string OK}
}

# receiveResponse(string responder-id, string msg-tag, map response)
proc samp.client.receiveResponse {args} {
    global samp
    if {$samp(debug)} {
	puts "SAMP-Test: samp.client.receiveResponse $args"
    }

    set msgtag [lindex $args 0]
    set value [lindex $args 1]
    set map [lindex $args 2]

    return {string OK}
}

# Support

proc SAMPParseHub {} {
    global samp
    global env

    global tcl_platform
    switch $tcl_platform(platform) {
	unix {
	    set fn [file join [GetEnvHome] {.samp}]
	}
	windows {
	    set fn [file join "$env(HOMEDRIVE)$env(HOMEPATH)" {.samp}]
	}
    }

    if {![file exist $fn]} {
	# no hub to be found
	return 0
    }

    set samp(secret) {}
    set samp(url) {}
    set samp(metod) {}
    set fp [open $fn r]
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
	if {[regexp -nocase {samp.hub.xmlrpc.url=(.*)/(.*)} $line foo ss xx]} {
	    set samp(url) $ss
	    set samp(method) $xx
	}
    }
    catch {close $fp}

    if {$samp(secret) == {} || $samp(url) == {}} {
	return 0
    }

    if {$samp(debug)} {
	puts "SAMP-Test: SAMPParseHub $samp(secret) $samp(url) $samp(method)"
    }
    return 1
}

proc SAMPGetAppName {id} {
    global samp

    if {$samp(debug)} {
	puts "SAMP-Test: SAMPGetAppName $id"
    }

    set param1 [list "string $samp(private)"]
    set param2 [list "string $id"]
    set params "$param1 $param2" 
    if {![SAMPSend {samp.hub.getMetadata} $params rr]} {
	return
    }

    set name {}
    foreach arg [lindex $rr 1] {
	foreach {key val} $arg {
	    switch -- $key {
		samp.name {set name [XMLUnQuote $val]}
	    }
	}
    }

    return $name
}

# CallBacks
# Hub

proc SAMPRcvdEventShutdown {varname} {
    upvar $varname args

    global samp
    if {$samp(debug)} {
	puts "SAMP-Test: SAMPRcvdEventShutdown $args"
    }

    SAMPShutdown
}

proc SAMPRcvdEventRegister {varname} {
    upvar $varname args

    global samp

    if {$samp(debug)} {
	puts "SAMP-Test: SAMPRcvdEventRegister $args"
    }

    foreach arg $args {
	foreach {key val} $arg {
	    switch -- $key {
		id {
		    # check to see if its just us
		    if {$samp(self) == $val} {
			return
		    }
		}
	    }
	}
    }

    # wait
    if {$samp(block)} {
	after $samp(timeout,update)
	SAMPUpdate
    } else {
	after $samp(timeout,update) SAMPUpdate
    }
}

proc SAMPRcvdEventUnregister {varname} {
    upvar $varname args

    global samp

    if {$samp(debug)} {
	puts "SAMP-Test: SAMPRcvdEventUnregister $args"
    }

    foreach arg $args {
	foreach {key val} $arg {
	    switch -- $key {
		id {
		    # check to see if its just us
		    if {$samp(self) == $val} {
			return
		    }
		}
	    }
	}
    }

    # wait
    if {$samp(block)} {
	after $samp(timeout,update)
	SAMPUpdate
    } else {
	after $samp(timeout,update) SAMPUpdate
    }
}

proc SAMPRcvdDisconnect {varname} {
    upvar $varname args

    global samp
    if {$samp(debug)} {
	puts "SAMP-Test: SAMPRcvdDisconnect $args"
    }

    set msg {}

    foreach arg $args {
	foreach {key val} $arg {
	    switch -- $key {
		reason {set msg [XMLUnQuote $val]}
	    }
	}
    }

    SAMPShutdown
}

# HTTPClient

proc SAMPSendDS9Set {id url cmd} {
    global samp
    global sampmap
    global sampmap2

    if {$samp(debug)} {
	puts "SAMP-Test: SAMPSendDS9Set $id $cmd"
    }

    # connected?
    if {!$samp(status)} {
	puts {SAMP: not connected}
	return
    }

    # cmd
    catch {unset sampmap}
    set sampmap(samp.mtype) {string "ds9.set"}
    set sampmap(samp.params) {struct sampmap2}

    catch {unset sampmap2}

    set sampmap2(url) "string \"[XMLQuote $url]\""
    set sampmap2(cmd) "string \"[XMLQuote $cmd]\""

    set param1 [list "string $samp(private)"]
    set param2 [list "string $id"]
    set param3 [list "struct sampmap"]
    set param4 [list "string $samp(timeout,wait)"]
    set params "$param1 $param2 $param3 $param4" 

    SAMPSend {samp.hub.callAndWait} $params rr
}

proc SAMPSendDS9Get {id cmd} {
    global samp
    global sampmap
    global sampmap2

    if {$samp(debug)} {
	puts "SAMP-Test: SAMPSendDS9Get"
    }

    # connected?
    if {!$samp(status)} {
	puts {SAMP: not connected}
	return
    }

    # cmd
    catch {unset sampmap}
    set sampmap(samp.mtype) {string "ds9.get"}
    set sampmap(samp.params) {struct sampmap2}

    catch {unset sampmap2}

    set sampmap2(cmd) "string \"[XMLQuote $cmd]\""

    set param1 [list "string $samp(private)"]
    set param2 [list "string $id"]
    set param3 [list "struct sampmap"]
    set param4 [list "string $samp(timeout,wait)"]
    set params "$param1 $param2 $param3 $param4" 

    SAMPSend {samp.hub.callAndWait} $params rr
}

proc SAMPSendClientEnvGet {id name} {
    global samp
    global sampmap
    global sampmap2

    if {$samp(debug)} {
	puts "SAMP-Test: SAMPSendClientEnvGet $id $name"
    }

    # connected?
    if {!$samp(status)} {
	puts {SAMP: not connected}
	return
    }

    # name
    catch {unset sampmap}
    set sampmap(samp.mtype) {string "client.env.get"}
    set sampmap(samp.params) {struct sampmap2}

    catch {unset sampmap2}

    set sampmap2(name) "string \"[XMLQuote $name]\""

    set param1 [list "string $samp(private)"]
    set param2 [list "string $id"]
    set param3 [list "struct sampmap"]
    set param4 [list "string $samp(timeout,wait)"]
    set params "$param1 $param2 $param3 $param4" 

    SAMPSend {samp.hub.callAndWait} $params rr
}

proc SAMPDelTmpFiles {} {
    global app

    # delete any previous files
    foreach fn [glob -directory $app(tmpdir) -nocomplain {samp*}] {
	catch {file delete -force "$fn"}
    }
}

proc InitTempDir {} { 
    global app
    global env

    # check environment vars first
    #   windows is very picky as to file name format 
    if [info exists env(TEMP)] {
	set app(tmpdir) [file normalize [file nativename $env(TEMP)]]
    } elseif [info exists env(TMP)] {
	set app(tmpdir) [file normalize [file nativename $env(TMP)]]
    }

    #   nothing so far, go with defaults
    if {![info exists app(tmpdir)]} {
	global tcl_platform
	switch $tcl_platform(platform) {
	    unix {set app(tmpdir) "/tmp"}
	    windows {set app(tmpdir) "C:/WINDOWS/Temp"}
	}
    }

    #   see if it is valid, else current directory
    if {![file isdirectory $app(tmpdir)]} {
	set app(tmpdir) {.}
    }
}

proc GetEnvHome {} {
    global env

    # return current directory by default
    set home {}

    global tcl_platform
    switch $tcl_platform(platform) {
	unix {
	    if [info exists env(HOME)] {
		set home $env(HOME)
	    }
	}
	windows {
	    if {[info exists env(HOME)]} {
		set hh [file normalize [file nativename $env(HOME)]]
		if [file isdirectory $hh] {
		    set home $hh
		}
	    }
	    # this is just a backup, the above should always work
	    if {$home == {} &&
		[info exists env(HOMEDRIVE)] &&
		[info exists env(HOMEPATH)]} {
		set home "$env(HOMEDRIVE)$env(HOMEPATH)"
	    }
	}
    }

    # if there is a problem, just return current directory
    if {![file isdirectory $home]} {
	set home {.}
    }

    return $home
}

proc prompt {cmd} {
    global samp

    if {[string range $cmd 0 0] == "#"} {
	puts $cmd
	return
    }
    set item [lindex $cmd 0]
    if {$samp(block) && $cmd != {}} {
	puts -nonewline stderr "$cmd> "
    }

    switch -- $item {
	con -
	connect {SAMPConnect}
	dis -
	disconnect {SAMPDisconnect}

	set {
	    set id [lindex [lindex $samp(apps,set) 0] 0]
	    set url [lindex $cmd 1]
	    set params [lrange $cmd 2 end]
	    SAMPSendDS9Set $id $url $params
	}
	get {
	    set id [lindex [lindex $samp(apps,get) 0] 0]
	    set params [lrange $cmd 1 end]
	    SAMPSendDS9Get $id $params
	}
	env {
	    set id [lindex [lindex $samp(apps,env) 0] 0]
	    set params [lrange $cmd 1 end]
	    SAMPSendClientEnvGet $id $params
	}

	sleep {
	    after [expr int([lindex $cmd 1]*1000)]
	}
	echo {
#	    set params [lrange $cmd 1 end]
#	    puts -nonewline "$params"
	}

	bye -
	exit -
	quit {
	    SAMPDisconnect
	    exit
	}
	{} {}
	default {
	    puts -nonewline "Unknown command: $cmd"
	}
    }

    puts {}
    if {!$samp(block)} {
	puts -nonewline stderr {samp> }
    }

    return
}

namespace eval ::mainloop {}

proc ::mainloop::readable {} {
    variable eof
    
    if { [gets stdin text] < 0 } {
 	fileevent stdin readable {}
 	set eof 1
    } else {
 	prompt $text
    }
    return
}
 
proc ::mainloop::mainloop {} {
    variable eof
 
    set ::tcl_interactive 1
    fconfigure stdin -buffering line -blocking 0
    fileevent stdin readable ::mainloop::readable
    prompt {}
 
    vwait [namespace which -variable eof]
    return
}

proc XMLQuote {val} {
    return [string map {& &amp; < &lt; > &gt; \' &apos; \" &quot;} $val]
}

proc XMLUnQuote {val} {
    return [string map {&amp; & &lt; < &gt; > &apos; \' &quot; \"} $val]
}

# Start

set samp(status) 0
set samp(debug) 0
# only used for register/unregister (in micro secs)
set samp(timeout,update) 250
# used for call and wait (in secs)
set samp(timeout,wait) 30
set samp(block) 0

InitTempDir
SAMPConnect

foreach arg $argv {
    switch $arg {
	debug {set samp(debug) 1}
	batch -
	block {set samp(block) 1}
	interactive -
	noblock {set samp(block) 0}
    }
}

if {$samp(block)} {
    set cmd {}
    while {1} {
	prompt $cmd
	if {[gets stdin cmd] == -1} {
	    SAMPDisconnect
	    exit
	}
    }
} else {
    ::mainloop::mainloop
}
