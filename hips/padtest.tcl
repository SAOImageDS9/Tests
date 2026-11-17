proc padtest {fn method out log} {
    global current
    set lf [open $log a]
    $current(frame) clear
    set rr [catch {
	switch -- $method {
	    mmap - mmapincr {$current(frame) load fits "\{$fn\}" $method}
	    alloc - allocgz {$current(frame) load fits "\{$fn\}" $method "\{$fn\}"}
	    channel {
		set ch [open $fn r]
		fconfigure $ch -translation binary -encoding iso8859-1
		$current(frame) load fits "\{$fn\}" channel $ch
		close $ch
	    }
	    var {
		set ch [open $fn r]; fconfigure $ch -translation binary
		global padvar; set padvar [read $ch]; close $ch
		$current(frame) load fits "\{$fn\}" var padvar
	    }
	}
    } err]
    set has [$current(frame) has fits]
    if {$has} {
	set sz [$current(frame) get fits size]
	catch {file delete $out}
	$current(frame) save fits image file "\{$out\}"
	# scaled pixel values (BSCALE/BZERO/BLANK applied) at (x,y)=(8,6),(1,1)
	global padarr
	catch {unset padarr}
	$current(frame) get data image fk5 8 6 1 1 padarr
	set v1 [array get padarr]
	catch {unset padarr}
	$current(frame) get data image fk5 1 1 1 1 padarr
	set v2 [array get padarr]
    } else {set sz {}; set v1 {}; set v2 {}}
    puts $lf [list [file tail $fn] $method rc=$rr has=$has size=$sz v86=$v1 v11=$v2 err=$err]
    close $lf
}
