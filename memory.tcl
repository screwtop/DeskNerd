#!/usr/bin/expectk

# Basic memory usage indicator for DeskNerd.  We could show cache, swap, wired, etc. but what we really care about is how much physical RAM is used out of the available physical RAM.
# Works by spawning Linux's "free" command in repeat-report mode (-s <nsecs>) and parsing its output.

# TODO: add a (separate, shareable) proc for converting bytes to MiB, GiB, etc., perhaps automatically according to the magnitude.


wm title . {DeskNerd_MemoryMeter}
set application_name {DeskNerd Memory Meter}

source {Preferences.tcl}
# TODO: fixed-width font for menu display
source {every.tcl}
source {number_formatting.tcl}

set refresh_interval_s 1	;# Memory utilisation doesn't normally change very rapidly; 1..10 s may be quite OK.

# NOTE: changing the TearOff capability changes the number of items in menus!  Fragile!
option add *TearOff 1
# TODO: fixed-width font might be sensible for the informative tooltip-menus.
#option add *font font_mono

#set ::env(TERM) dumb	;# to avoid ANSI codes from dstat

# Basic meter dimension preferences:
set indicator_width 8
set indicator_height 20

# Pop-up menu for convenient exiting:
menu .popup_menu
	.popup_menu add command -label $application_name -command {}	;# TODO: add about dialog for this?
	.popup_menu add separator
	.popup_menu add command -label {Close} -background orange -command {exit}
bind . <3> "tk_popup .popup_menu %X %Y"

# Extra info menu, tooltip styles.
# TODO: maybe add total amount of physical RAM and swap.
# TODO: maybe add % reporting for physical RAM (effective) and swap.
# TODO: maybe use automatic-multiplier-prefix number formatting (e.g. MiB, TiB) (though consistency is more important, and MiB is generally still fine ca. 2010).
menu .info_menu
	.info_menu add command -label $application_name -command {}
	.info_menu add separator
	.info_menu add command -label "Total Physical RAM: ??" -command {} -font font_mono
	.info_menu add command -label "Total Swap:         ??" -command {} -font font_mono
	.info_menu add separator
	.info_menu add command -label "Effective Physical RAM Used: ??" -command {} -font font_mono
	.info_menu add command -label "Effective Physical RAM Free: ??" -command {} -font font_mono
	.info_menu add separator
	.info_menu add command -label "Shared Mem:   ??" -command {} -font font_mono
	.info_menu add command -label "Buffer Mem:   ??" -command {} -font font_mono
	.info_menu add command -label "System Cache: ??" -command {} -font font_mono
	.info_menu add separator
	.info_menu add command -label "Swap Used: ??" -command {} -font font_mono
	.info_menu add command -label "Swap Free: ??" -command {} -font font_mono
# Could be invoked by mouse-over or left click perhaps.
bind . <1> "tk_popup .info_menu %X %Y"

proc update_tooltip_menu {ram_total ram_used effective_ram_used ram_free effective_ram_free shared buffer cache swap_total swap_used swap_free} {
	set i 0	;# Counter for keeping track of menu item indexes.
	incr i	;# For the tear-off tab (if enabled)!
	incr i	;# Increment to skip over separator items in the menu.
	# Seems a bit ridiculous updating the physical RAM every time, but swap could conceivably vary.
	# Trying out auto-prefix:
#	.info_menu entryconfigure [incr i] -label "Total Physical RAM: [format_base2_unit $ram_total {%7.2f}]B"
#	.info_menu entryconfigure [incr i] -label "Total Swap:         [format_base2_unit $swap_total {%7.2f}]B"

	.info_menu entryconfigure [incr i] -label "Total Physical RAM:          [format {%5d} [expr {round($ram_total / 1024.0)}]] MiB"
	.info_menu entryconfigure [incr i] -label "Total Swap:                  [format {%5d} [expr {round($swap_total / 1024.0)}]] MiB"
	incr i
	.info_menu entryconfigure [incr i] -label "Effective Physical RAM Used: [format {%5d} [expr {round($effective_ram_used / 1024.0)}]] MiB ([format {%2d} [expr round($effective_ram_used / double($ram_total) * 100)]]%)"
	.info_menu entryconfigure [incr i] -label "Effective Physical RAM Free: [format {%5d} [expr {round(($ram_total - $effective_ram_used) / 1024.0)}]] MiB ([format {%2d} [expr round($effective_ram_free / double($ram_total) * 100)]]%)"	
	incr i
	.info_menu entryconfigure [incr i] -label "Shared:                      [format {%5d} [expr {round($shared / 1024.0)}]] MiB"
	.info_menu entryconfigure [incr i] -label "Buffers:                     [format {%5d} [expr {round($buffer / 1024.0)}]] MiB"
	.info_menu entryconfigure [incr i] -label "System Cache:                [format {%5d} [expr {round($cache / 1024.0)}]] MiB"
	incr i
	.info_menu entryconfigure [incr i] -label "Swap Used:                   [format {%5d} [expr {round($swap_used / 1024.0)}]] MiB ([format {%2d} [expr round($swap_used / double($swap_total) * 100)]]%)"
	.info_menu entryconfigure [incr i] -label "Swap Free:                   [format {%5d} [expr {round($swap_free / 1024.0)}]] MiB ([format {%2d} [expr round($swap_free / double($swap_total) * 100)]]%)"
}


# Set up the gauge:

# Container frame:
pack [frame .memory_gauge  -width $indicator_width  -height $indicator_height  -relief sunken  -borderwidth 1 -background black] -side left
	
# Meter gauge is also simply done as a frame:
place [frame .memory_gauge.meter     -width [expr {$indicator_width-2}] -height 0  -relief flat -borderwidth 0 -background green] -anchor sw -x 0 -y [expr {$indicator_height-2}]


# Update the gauge:
proc memory_gauge_update {value} {
	global indicator_height .memory_gauge.meter

	if     {$value >= 0.90} then {set gauge_colour red} \
	elseif {$value >= 0.80} then {set gauge_colour orange} \
	elseif {$value >= 0.60} then {set gauge_colour yellow} \
	else                         {set gauge_colour green}

	.memory_gauge.meter configure -height [expr {$value * ($indicator_height-2)}] -background $gauge_colour
}



log_user 0
set timeout [expr {$refresh_interval_s + 1}]	;# or perhaps * 2.
# NOTE: may want to consider using "free -b" to use bytes as lowest-common-denominator measure.
spawn free -s $refresh_interval_s
# Output looks like:
#<<
#             total       used       free     shared    buffers     cached
#Mem:       3933736    3713660     220076          0      47432    1593324
#-/+ buffers/cache:    2072904    1860832
#Swap:      2048276      74432    1973844
#>>
while true {
	expect -re {(Mem:) +([0-9]+) +([0-9]+) +([0-9]+) +([0-9]+) +([0-9]+) +([0-9]+)} {
		# 0 -> whole match, 1 -> "Mem:", ...
		set ram_total $expect_out(2,string)
		set ram_used $expect_out(3,string)
		set ram_free $expect_out(4,string)
		set mem_shared $expect_out(5,string)
		set mem_buffer $expect_out(6,string)
		set mem_cached $expect_out(7,string)
	}

	# Since the system will use spare physical memory for filesystem cache, the fs cache doesn't really count towards memory used.
	# I think I/O buffer memory works similarly (certainly "free" accounts for cache + buffers together).
	# Shared memory would be fixed, though, I'd think.
	set effective_ram_used [expr $ram_used - $mem_cached - $mem_buffer]
	set effective_ram_free [expr $ram_total - $effective_ram_used]

	expect -re {(Swap:) +([0-9]+) +([0-9]+) +([0-9]+)} {
		set swap_total $expect_out(2,string)
		set swap_used $expect_out(3,string)
		set swap_free $expect_out(4,string)
	}

#	puts "$ram_used"	;# Just testing...

	# Update info menu-panel:
	update_tooltip_menu $ram_total $ram_used $effective_ram_used $ram_free $effective_ram_free $mem_shared $mem_buffer $mem_cached $swap_total $swap_used $swap_free

	# For display, the effective physical RAM utilisation is the important thing (filesystem cache will make room for processes if necessary).
	memory_gauge_update [expr {double($effective_ram_used) / double($ram_total)}]

	# TODO: handle eof properly.
#	expect eof {break}	;# i.e. not like this, which just causes an expect timeout, since it waits for EOF at every iteration of this while loop.
}


# Endut! Hoch hech!

