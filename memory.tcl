#!/usr/bin/expectk

# Basic memory usage indicator for DeskNerd.  We could show cache, swap, wired, etc. but what we really care about is how much physical RAM is used out of the available physical RAM.
# Works by spawning Linux's "free" command in repeat-report mode (-s <nsecs>) and parsing its output.

wm title . {DeskNerd_MemoryMeter}

source {Preferences.tcl}
source {every.tcl}

set refresh_interval_s 5	;# Memory utilisation doesn't normally change very rapidly; 1..10 s may be quite OK.

#set ::env(TERM) dumb	;# to avoid ANSI codes from dstat

# Basic meter dimension preferences:
set indicator_width 8
set indicator_height 20

# Pop-up menu for convenient exiting:
menu .popup_menu
	.popup_menu add command -label "RAM Usage Meter" -command {}
	.popup_menu add command -label {Close} -background orange -command {exit}
bind . <3> "tk_popup .popup_menu %X %Y"


# Container frame
pack [frame .memory_gauge  -width $indicator_width  -height $indicator_height  -relief sunken  -borderwidth 1 -background black] -side left
	
# Meter gauge is also done as a frame
place [frame .memory_gauge.meter     -width [expr {$indicator_width-2}] -height 0  -relief flat -borderwidth 0 -background green] -anchor sw -x 0 -y [expr {$indicator_height-2}]



# Then again, by duplicating this, we can customise the colouring function...
proc memory_gauge_update {value} {
	global indicator_height .memory_gauge.meter
	# We're assuming value is a 0..1 factor.
	# Colour thresholds?  Overkill to store these in a data structure somewhere?
	# Green|Red?  Green|Orange|Red?  Green|Yellow|Orange|Red?
	# Note: yellow is no terribly visible against the default pale grey background.
	# Perhaps a fixed black background would be appropriate.
	if     {$value >= 0.90} then {set gauge_colour red} \
	elseif {$value >= 0.75} then {set gauge_colour orange} \
	elseif {$value >= 0.50} then {set gauge_colour yellow} \
	else                         {set gauge_colour green}

	.memory_gauge.meter configure -height [expr {$value * ($indicator_height-2)}] -background $gauge_colour
}



log_user 0
spawn free -s $refresh_interval_s
# Output looks like:
#             total       used       free     shared    buffers     cached
#Mem:       3933736    3713660     220076          0      47432    1593324
#-/+ buffers/cache:    2072904    1860832
#Swap:      2048276      74432    1973844
while true {
	expect -re {(Mem:) +([0-9]+) +([0-9]+) +([0-9]+) +([0-9]+) +([0-9]+) +([0-9]+)} {
		# 0 -> whole match, 1 -> "Mem:", ...
	#	puts $expect_out(0,string)
		set ram_available $expect_out(2,string)
	#	puts $ram_available
	
	}
	expect -re {(.*buffers/cache:) +([0-9]+) +([0-9]+)} {
	#	puts $expect_out(0,string)
		set ram_used $expect_out(2,string)
	#	puts $ram_used
	}

#	puts "ram_used = $ram_used; ram_available = $ram_available; [expr {double($ram_used) / double($ram_available)}]"

	memory_gauge_update [expr {double($ram_used) / double($ram_available)}]
}


# Endut! Hoch hech!

