#  Copyright (C) 1999-2023
#  Smithsonian Astrophysical Observatory, Cambridge, MA, USA
#  For conditions of distribution and use, see copyright notice in "copyright"

source xmlrpc.tcl

proc SAMPConnect {} {
    global samp

    # connected?
    if {[info exists samp]} {
	puts [array get samp]
	puts {SAMP-Test: already connected}
	return
    }

    # reset samp array
    catch {unset samp}

    set samp(clients) {}
    set samp(tmp,files) {}
    set samp(msgtag) {}
    # used for call and wait (in secs)
    set samp(timeout,wait) 30
    
    # can we find a hub?
    if {![SAMPParseHub]} {
	global debug
 	if {$debug} {
	    puts {SAMP-Test: unable to locate HUB}
	}
	catch {unset samp}
	return
    }

    # register
    set params [list "string $samp(secret)"]
    set rr {}
    if {![SAMPSend {samp.hub.register} $params rr]} {
	puts {SAMP-Test: internal error}
	catch {unset samp}
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
	puts {SAMP-Test: internal error}
	return
    }

    # who are we
    set samp(sock) [xmlrpc::serve 0]
    set samp(port) [lindex [fconfigure $samp(sock) -sockname] 2]
    set samp(home) "[info hostname]:$samp(port)"

    # callback
    set param1 [list "string $samp(private)"]
    set param2 [list "string http://$samp(home)"]
    set params "$param1 $param2"
    if {![SAMPSend {samp.hub.setXmlrpcCallback} $params rr]} {
	puts {SAMP-Test: internal error}
	return
    }

    # declare subscriptions
    catch {unset sampmap}
    set sampmap(samp.app.ping) {struct mapPing}

    set sampmap(samp.hub.event.shutdown) {struct mapShutdown}
    set sampmap(samp.hub.event.register) {struct mapRegister}
    set sampmap(samp.hub.event.unregister) {struct mapUnregister}
    set sampmap(samp.hub.event.metadata) {struct mapMetadata}
    set sampmap(samp.hub.event.subscriptions) {struct mapSubscriptions}
    set sampmap(samp.hub.disconnect) {struct mapDisconnect}

    set param1 [list "string $samp(private)"]
    set param2 [list "struct sampmap"]
    set params "$param1 $param2" 
    if {![SAMPSend {samp.hub.declareSubscriptions} $params rr]} {
	puts {SAMP-Test: internal error}
	return
    }

    # get current client info
    set params [list "string $samp(private)"]
    set rr {}
    if {![SAMPSend {samp.hub.getRegisteredClients} $params rr]} {
	puts {SAMP-Test: internal error}
	return
    }
    set samp(clients) [lindex $rr 1]

    foreach cc $samp(clients) {
	set param1 [list "string $samp(private)"]
	set param2 [list "string $cc"]
	set params "$param1 $param2" 
	set rr {}
	if {![SAMPSend {samp.hub.getSubscriptions} $params rr]} {
	    puts {SAMP-Test: internal error}
	    return
	}
	
	foreach arg [lindex $rr 1] {
	    foreach {key val} $arg {
		lappend samp($cc,subscriptions) $key
	    }
	}

	set param1 [list "string $samp(private)"]
	set param2 [list "string $cc"]
	set params "$param1 $param2" 
	set rr {}
	if {![SAMPSend {samp.hub.getMetadata} $params rr]} {
	    puts {SAMP-Test: internal error}
	    return
	}

	foreach arg [lindex $rr 1] {
	    foreach {key val} $arg {
		switch -- $key {
		    samp.name {set samp($cc,name) [XMLUnQuote $val]}
		}
	    }
	}
    }

    # samp initalization started
    set samp(init) 1
}

proc SAMPDisconnect {} {
    global samp

    # connected?
    if {![info exists samp]} {
	puts {SAMP-Test: not connected}
	return
    }

    # disconnect
    if {[info exists samp(private)]} {
	set params [list "string $samp(private)"]
	set rr {}
	if {![SAMPSend {samp.hub.unregister} $params rr]} {
	    puts {SAMP-Test: internal error}
	    return
	}
	SAMPShutdown
    }
}

# Support

proc SAMPShutdown {} {
    global samp

    # delete any files
    SAMPDelTmpFiles

    # close the server socket if still up
    catch {close $samp(sock)}

    # unset samp array
    catch {unset samp}
}

proc SAMPSend {method params resultVar {ntabs 5} {distance 4}} {
    upvar $resultVar result
    global samp

    global debug
    if {$debug} {
	puts "SAMP-Test: SAMPSend $method $params"
    }

    if {[catch {set result [xmlrpc::call $samp(url) $samp(method) $method $params $ntabs $distance]}]} {
	puts "SAMP-Test: SAMPSend Error: $result"
	return 0
    }

    if {$debug} {
	puts "SAMP-Test: SAMPSend Result: $result"
    }
    
    switch $method {
	samp.hub.notify -
	samp.hub.notifyAll {
	    puts -nonewline "ok"
	}
	samp.hub.call -
	samp.hub.callAll {
	    set samp(msgtag) [lindex $result 1]

	    # and now we wait
	    vwait samp(msgtag)
	}
	samp.hub.callAndWait {
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
	    puts -nonewline "$status $value $error"
	}
    }

    return 1
}

proc SAMPReply {msgid status {result {}} {error {}}} {
    global samp

    global debug
    if {$debug} {
	puts "SAMP-Test: SAMPReply $msgid $status"
    }

    switch -- $status {
	OK {
	    set sampmap(samp.status) {string "samp.ok"}
	    set sampmap(samp.result) {struct sampmap2}
	    if {$result != {}} {
		set sampmap2(value) "string \"[XMLQuote $result]\""
	    }
	    if {$url != {}} {
		set sampmap2(url) "string \"[XMLQuote $url]\""
	    }
	}
	WARNING {
	    set sampmap(samp.status) {string "samp.error"}
	    set sampmap(samp.result)  {struct sampmap2}
	    set sampmap(samp.error)  {struct sampmap3}
	    if {$result != {}} {
		set sampmap2(value) "string \"[XMLQuote $result]\""
	    }
	    if {$url != {}} {
		set sampmap2(url) "string \"[XMLQuote $url]\""
	    }
	    set sampmap3(samp.errortxt) "string \"[XMLQuote $error]\""
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
    set rr {}
    if {![SAMPSend {samp.hub.reply} $params rr]} {
	puts {SAMP-Test: internal error}
	return
    }
}

proc SAMPValidMtype {mtype} {
    switch $mtype {
	samp.client.receiveNotification -
	samp.client.receiveCall -
	samp.client.receiveResponse -
	samp.hub.event.shutdown -
	samp.hub.event.register -
	samp.hub.event.unregister -
	samp.hub.event.metadata -
	samp.hub.event.subscriptions -
	samp.hub.disconnect -
	samp.app.ping {return 1}
	default {return 0}
    }
}

# receiveNotification(string sender-id, map message)
proc samp.client.receiveNotification {args} {
    global samp

    global debug
    if {$debug} {
	puts "SAMP-Test: samp.client.receiveNotification $args"
    }

    set secret [lindex $args 0]
    set id [lindex $args 1]
    set map [lindex $args 2]

    if {$secret != $samp(private)} {
	puts {SAMP-Test: internal error}
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

    if {[SAMPValidMtype $mtype]} {
	$mtype params
    } else {
	Error "SAMP: [msgcat::mc {internal error}]"
	return {string ERROR}
    }

    return {string OK}
}

# receiveCall(string sender-id, string msg-id, map message)
proc samp.client.receiveCall {args} {
    global samp

    global debug
    if {$debug} {
	puts "SAMP-Test: samp.client.receiveCall $args"
    }

    set secret [lindex $args 0]
    set id [lindex $args 1]
    set msgid [lindex $args 2]
    set map [lindex $args 3]

    if {$secret != $samp(private)} {
	Error "SAMP: [msgcat::mc {internal error}]"
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

    if {[SAMPValidMtype $mtype]} {
	$mtype params
	SAMPReply $msgid OK
    } else {
	Error "SAMP: [msgcat::mc {internal error}]"
	return {string ERROR}
    }

    return {string OK}
}

# receiveResponse(string responder-id, string msg-tag, map response)
proc samp.client.receiveResponse {args} {
    global samp

    global debug
    if {$debug} {
	puts stderr "samp.client.receiveResponse $args"
    }

    set secret [lindex $args 0]
    set id [lindex $args 1]
    set msgtag [lindex $args 2]
    set map [lindex $args 3]

    if {$samp(msgtag) == {}} {
	puts "SAMP-Test: samp.client.receiveResponse bad tag $msgtag"
    }
    set samp(msgtag) {}

    set status {}
    set value {}
    set error {}
    foreach arg $map {
	foreach {key val} $arg {
	    switch -- $key {
		samp.result {set value [lindex [lindex $val 0] 1]}
		samp.status {set status $val}
		samp.error  {set error [lindex [lindex $val 0] 1]}
	    }
	}
    }
    puts -nonewline "$status $value $error"

    return {string OK}
}

# Support

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
    set samp(metod) {}
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

    global debug
    if {$debug} {
	puts "SAMP-Test: SAMPParseHub $samp(secret) $samp(url) $samp(method)"
    }

    return 1
}

proc ParseURL {url varname} {
    upvar $varname r

    set r(scheme) {}
    set r(authority) {}
    set r(path) {}
    set r(query) {}
    set r(fragment) {}
    set exp {^(([^:/?#]+):)?(//([^/?#]*))?([^?#]*)(\?([^#]*))?(#(.*))?}

    if {![regexp -nocase $exp $url x a r(scheme) c r(authority) r(path) f r(query) h r(fragment)]} {
	return 0
    }

    # check for windows disk drives
    global tcl_platform
    switch $tcl_platform(platform) {
	unix {
	    switch -- $r(scheme) {
		zipfs {
		    # special case for zipfs
		    set r(path) "$r(scheme):$r(path)"
		    set r(scheme) {}
		}
		ftp {
		    # strip any username/passwd
		    set id [string first {@} $r(authority)]
		    if { $id != -1} {
			set r(authority) [string range $r(authority) [expr $id+1] end]
		    }
		}
	    }
	}
	windows {
	    switch -- $r(scheme) {
		{} -
		ftp -
		http -
		https -
		file {
		    if {[regexp {/([A-Z]:)(/.*)} $r(path) a b c]} {
			set r(path) "$b$c"
		    }
		}
		default {
		    set r(path) "$r(scheme):$r(path)"
		    set r(scheme) {}
		}
	    }
	}
    }

    return 1
}

proc SAMPGetAppName {id} {
    global samp

    global debug
    if {$debug} {
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

proc SAMPGetAppsSubscriptions {mtype} {
    global samp

    set ll {}
    foreach cc $samp(clients) {
	if {[lsearch $samp($cc,subscriptions) $mtype]>=0} {
	    lappend ll $cc
	}
    }
    return $ll
}

# CallBacks

proc samp.hub.event.shutdown {varname} {
    upvar $varname args

    global debug
    if {$debug} {
	puts stderr "samp.hub.event.shutdown $args"
    }

    SAMPShutdown
}

proc samp.hub.event.register {varname} {
    upvar $varname args
    global samp

    global debug
    if {$debug} {
	puts stderr "samp.hub.event.register $args"
    }

    foreach arg $args {
	foreach {key val} $arg {
	    switch -- $key {
		id {
		    lappend samp(clients) $val
		    set samp($val,subscriptions) {}
		    set samp($val,name) {}
		}
	    }
	}
    }
}

proc samp.hub.event.unregister {varname} {
    upvar $varname args
    global samp

    global debug
    if {$debug} {
	puts stderr "samp.hub.event.unregister $args"
    }

    foreach arg $args {
	foreach {key val} $arg {
	    switch -- $key {
		id {
		    set id [lsearch $samp(clients) $val]
		    set samp(clients) [lreplace $samp(clients) $id $id]
		    unset samp($val,subscriptions)
		    unset samp($val,name)
		}
	    }
	}
    }
}

proc samp.hub.event.metadata {varname} {
    upvar $varname args
    global samp

    global debug
    if {$debug} {
	puts stderr "samp.hub.event.metadata $args"
    }

    set id {}
    set name {}
    foreach arg $args {
	foreach {key val} $arg {
	    switch -- $key {
		id {
		    set id $val
		}
		metadata {
		    foreach aa $val {
			foreach {bb cc} $aa {
			    if {$bb == {samp.name}} {
				set name $cc
			    }
			}
		    }
		}
	    }
	}
    }
    
    # should not happen
    if {$id == {}} {
	return
    }

    # just ignore if ourself
    if {$id == $samp(self)}  {
	return
    }

    set samp($id,name) $name
}

proc samp.hub.event.subscriptions {varname} {
    upvar $varname args
    global samp

    global debug
    if {$debug} {
	puts stderr "samp.hub.event.subscriptions $args"
    }

    set id {}
    set subs {}
    foreach arg $args {
	foreach {key val} $arg {
	    switch -- $key {
		id {
		    set id $val
		}
		subscriptions {
		    foreach aa $val {
			foreach {bb cc} $aa {
			    lappend subs $bb
			}
		    }
		}
	    }
	}
    }
    
    # should not happen
    if {$id == {}} {
	return
    }

    # just ignore if ourself
    if {$id == $samp(self)}  {
	return
    }

    set samp($id,subscriptions) $subs
}

proc samp.hub.disconnect {varname} {
    upvar $varname args

    global debug
    if {$debug} {
	puts stderr "samp.hub.disconnect $args"
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

proc samp.app.ping {varname} {
    upvar $varname args

    global debug
    if {$debug} {
	puts stderr "samp.app.ping $args"
    }
}

proc SAMPSendDS9Set {proc url cmd} {
    global samp

    global debug
    if {$debug} {
	puts "SAMP-Test: SAMPSendDS9Set $cmd"
    }

    # connected?
    if {![info exists samp]} {
	puts {SAMP-Test: not connected}
	return
    }

    # first found
    set id [lindex [SAMPGetAppsSubscriptions {ds9.set}] 0]

    if {$id == {}} {
	puts {SAMP-Test: not subscriptions found}
	return
    }

    # cmd
    set sampmap(samp.mtype) {string "ds9.set"}
    set sampmap(samp.params) {struct sampmap2}
    set sampmap2(url) "string \"[XMLQuote $url]\""
    set sampmap2(cmd) "string \"[XMLQuote $cmd]\""

    set param1 [list "string $samp(private)"]
    switch $proc {
	samp.hub.notify {
	    set param2 [list "string $id"]
	    set param3 [list "struct sampmap"]
	    set params "$param1 $param2 $param3" 
	}
	samp.hub.notifyAll {
	    set param2 [list "struct sampmap"]
	    set params "$param1 $param2" 
	}
	samp.hub.call {
	    set param2 [list "string $id"]
	    set param3 [list "string foo"]
	    set param4 [list "struct sampmap"]
	    set params "$param1 $param2 $param3 $param4" 
	}
	samp.hub.callAll {
	    set param2 [list "string foo"]
	    set param3 [list "struct sampmap"]
	    set params "$param1 $param2 $param3" 
	}
	samp.hub.callAndWait {
	    set param2 [list "string $id"]
	    set param3 [list "struct sampmap"]
	    set param4 [list "string $samp(timeout,wait)"]
	    set params "$param1 $param2 $param3 $param4" 
	}
    }
    
    SAMPSend $proc $params rr
}

proc SAMPSendDS9Get {proc cmd} {
    global samp

    global debug
    if {$debug} {
	puts "SAMP-Test: SAMPSendDS9Get"
    }

    # connected?
    if {![info exists samp]} {
	puts {SAMP-Test: not connected}
	return
    }

    # first found
    set id [lindex [SAMPGetAppsSubscriptions {ds9.get}] 0]

    if {$id == {}} {
	puts {SAMP-Test: not subscriptions found}
	return
    }

    # cmd
    set sampmap(samp.mtype) {string "ds9.get"}
    set sampmap(samp.params) {struct sampmap2}
    set sampmap2(cmd) "string \"[XMLQuote $cmd]\""

    set param1 [list "string $samp(private)"]
    # just in case
    switch $proc {
	samp.hub.notify -
	samp.hub.notifyAll {
	    set proc samp.hub.call
	}
    }

    switch $proc {
	samp.hub.call {
	    set param2 [list "string $id"]
	    set param3 [list "string foo"]
	    set param4 [list "struct sampmap"]
	    set params "$param1 $param2 $param3 $param4" 
	}
	samp.hub.callAll {
	    set param2 [list "string foo"]
	    set param3 [list "struct sampmap"]
	    set params "$param1 $param2 $param3" 
	}
	samp.hub.callAndWait {
	    set param2 [list "string $id"]
	    set param3 [list "struct sampmap"]
	    set param4 [list "string $samp(timeout,wait)"]
	    set params "$param1 $param2 $param3 $param4" 
	}
    }

    SAMPSend $proc $params rr
}

proc SAMPDelTmpFiles {} {
    global samp

    # delete any tmp files
    if {[info exists samp]} {
	if {[info exists samp(tmp,files)]} {
	    foreach fn $samp(tmp,files) {
		catch {file delete -force "$fn"}
	    }
	}
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
    global tcl_platform

    switch $tcl_platform(platform) {
	unix {
	    if {[info exists env(HOME)]} {
		return $env(HOME)
	    }
	}
	windows {
	    if {[info exists env(HOME)]} {
		set hh [file normalize [file nativename $env(HOME)]]
		if {[file isdirectory $hh]} {
		    return $hh
		}
	    }
	    # this is just a backup, the above should always work
	    if {[info exists env(HOMEDRIVE)] &&	[info exists env(HOMEPATH)]} {
		return "$env(HOMEDRIVE)$env(HOMEPATH)"
	    }
	}
    }
    return {}
}

proc prompt {proc block cmd} {
    if {[string range $cmd 0 0] == "#"} {
	puts $cmd
	return
    }
    set item [lindex $cmd 0]

    if {$cmd != {}} {
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
	    SAMPSendDS9Set $proc $url $params
	}
	get {
	    set params [lrange $cmd 1 end]
	    SAMPSendDS9Get $proc $params
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
	    SAMPDisconnect
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

proc XMLQuote {val} {
    return [string map {& &amp; < &lt; > &gt; \' &apos; \" &quot;} $val]
}

proc XMLUnQuote {val} {
    return [string map {&amp; & &lt; < &gt; > &apos; \' &quot; \"} $val]
}

# Start

set debug 0
set block 0
set proc samp.hub.call

InitTempDir
SAMPConnect

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

if {$block} {
    set cmd {}
    while {1} {
	prompt $proc $block $cmd
	if {[gets stdin cmd] == -1} {
	    SAMPDisconnect
	    exit
	}
    }
} else {
    ::mainloop::mainloop
}
