#!/usr/bin/env wish
#!/usr/bin/wish8.5
# or perhaps /usr/bin/env wish

# Basic memory usage indicator for DeskNerd.  We could show cache, swap, wired, etc. but what we really care about is how much physical RAM is used out of the available physical RAM.
# Now (2015-07-13) works by reading from /proc/meminfo (`free`'s output varies depending on the version n stuff).
# From Linux 3.2, MemAvailable is probably quite a useful metric.
# {slurp /proc/meminfo} only takes about 10 microseconds, so no biggie there.
# Originally worked by spawning Linux's "free" command in repeat-report mode (-s <nsecs>) and parsing its output.

# I was having problems with the original expect-based version consuming huge amounts of memory over time.  Don't know if it was pipe buffers never being cleared or what, but this is another try using plain Tcl pipe I/O. 2012-08-23.

# TODO: add a (separate, shareable) proc for converting bytes to MiB, GiB, etc., perhaps automatically according to the magnitude.  Or embed a Frink interpreter via TclBlend?! ;^)


set application_name {DeskNerd Memory Meter}
#set application_name {DeskNerd_Memory_Meter}
wm title . $application_name

source {Preferences.tcl}
catch {source ~/.desknerd/memory.tcl}	;# TODO: move to ~/.config/DeskNerd

source {every.tcl}
source {number_formatting.tcl}

set refresh_interval_s 2	;# Memory utilisation doesn't normally change very rapidly; 1..10 s may be quite OK.

# NOTE: changing the TearOff capability changes the number of items in menus!  Fragile!
option add *TearOff 1
# TODO: fixed-width font might be sensible for the informative tooltip-menus.
#option add *font font_mono
#option add *font {{Letter Gothic 12 Pitch} 10}
#set ::env(TERM) dumb	;# to avoid ANSI codes from dstat

# Basic meter dimension preferences:
set indicator_width 8
set indicator_height 20

set use_proc_meminfo 1
set ::debugging 0
set update_interval_milliseconds 1000


# Read a file's contents:
proc slurp {filename} {
	set file_handle [open $filename r]
	set file_data [read $file_handle]
	close $file_handle
	return $file_data
}


# Read current memory stats from /proc/meminfo:
proc read_meminfo {} {
	array unset ::memory_stat

	set meminfo [slurp /proc/meminfo]

	# Convert into array for ease of reference:
	foreach statistic [split $meminfo "\n"] {
		if $::debugging {puts stderr "<<$statistic>>"}
		regexp {^(.*): +([0-9]+) ?(.*)$} $statistic entire_match statistic_name statistic_value statistic_unit
		set ::memory_stat($statistic_name) $statistic_value
		# TODO: keep $statistic_unit as well?  They're all kiB at the moment, but in future...?
	}
}


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

#proc update_tooltip_menu {ram_total ram_used effective_ram_used ram_free effective_ram_free shared buffer cache swap_total swap_used swap_free} {
# }
proc update_tooltip_menu {} {
	set i 0	;# Counter for keeping track of menu item indexes.
	incr i	;# For the tear-off tab (if enabled)!
	incr i	;# Increment to skip over separator items in the menu.
	# Seems a bit ridiculous updating the physical RAM every time, but swap could conceivably vary.
	# Trying out auto-prefix:
#	.info_menu entryconfigure [incr i] -label "Total Physical RAM: [format_base2_unit $ram_total {%7.2f}]B"
#	.info_menu entryconfigure [incr i] -label "Total Swap:         [format_base2_unit $swap_total {%7.2f}]B"

	.info_menu entryconfigure [incr i] -label "Total Physical RAM:          [format {%5d} [expr {round($::ram_total / 1024.0)}]] MiB"
	.info_menu entryconfigure [incr i] -label "Total Swap:                  [format {%5d} [expr {round($::swap_total / 1024.0)}]] MiB"
	incr i
	.info_menu entryconfigure [incr i] -label "Effective Physical RAM Used: [format {%5d} [expr {round($::effective_ram_used / 1024.0)}]] MiB ([format {%2d} [expr round($::effective_ram_used / double($::ram_total) * 100)]]%)"
	.info_menu entryconfigure [incr i] -label "Effective Physical RAM Free: [format {%5d} [expr {round(($::ram_total - $::effective_ram_used) / 1024.0)}]] MiB ([format {%2d} [expr round($::effective_ram_free / double($::ram_total) * 100)]]%)"	
	incr i
	.info_menu entryconfigure [incr i] -label "Shared:                      [format {%5d} [expr {round($::mem_shared / 1024.0)}]] MiB"
	.info_menu entryconfigure [incr i] -label "Buffers:                     [format {%5d} [expr {round($::mem_buffer / 1024.0)}]] MiB"
	.info_menu entryconfigure [incr i] -label "System Cache:                [format {%5d} [expr {round($::mem_cache / 1024.0)}]] MiB"
	incr i
	# It's possible the system has no swap, in which case we need to avoid dividing by zero ("domain error: argument not in valid range").
	if {$::swap_used == 0 || $::swap_free == 0} {
		set swap_used_pct_string ""
		set swap_free_pct_string ""
	} else {
		set swap_used_pct_string " ([format {%2d} [expr round($::swap_used / double($::swap_total) * 100)]]%)"
		set swap_free_pct_string " ([format {%2d} [expr round($::swap_free / double($::swap_total) * 100)]]%)"
	}
	# Or [catch ...]?
	.info_menu entryconfigure [incr i] -label "Swap Used:                   [format {%5d} [expr {round($::swap_used / 1024.0)}]] MiB$swap_used_pct_string"
	.info_menu entryconfigure [incr i] -label "Swap Free:                   [format {%5d} [expr {round($::swap_free / 1024.0)}]] MiB$swap_free_pct_string"
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


if {$use_proc_meminfo} {
	every $update_interval_milliseconds {

		read_meminfo

		# Boringly copy stuff from the resulting array into global variables, so I don't have to rewrite update_tooltip_menu!  TODO: probably nicer to rewrite the update_ procs and the old `free`-based code to use the array variables.  However, some of these require a little calculation, so are still required.
		set ::ram_total  $::memory_stat(MemTotal)
		set ::swap_total $::memory_stat(SwapTotal)
		set ::swap_free  $::memory_stat(SwapFree)
		set ::swap_used  [expr {$::memory_stat(SwapTotal) - $::memory_stat(SwapFree)}]
		set ::mem_shared     $::memory_stat(Shmem)
		set ::mem_buffer     $::memory_stat(Buffers)
		set ::mem_cache      $::memory_stat(Cached)
		# TODO: Slab?
		set ::effective_ram_free $::memory_stat(MemAvailable) ;# If MemAvailable statistic exists!  Otherwise calculate.
		set ::effective_ram_used [expr {$::memory_stat(MemTotal) - $::memory_stat(MemAvailable)}]



		# Update info menu-panel:
		if {[info exists ::ram_total] && [info exists ::swap_total]} {
			update_tooltip_menu
	#	update_tooltip_menu $::ram_total $::ram_used $::effective_ram_used $::ram_free $::effective_ram_free $::mem_shared $::mem_buffer $::mem_cached $::swap_total $::swap_used $::swap_free
	
		# For display, the effective physical RAM utilisation is the important thing (filesystem cache will make room for processes if necessary).
		# NOTE: from Linux 3.2, there's also a MemAvailable in /proc/meminfo, which is probably the best thing to use.
			memory_gauge_update [expr {double($::effective_ram_used) / double($::ram_total)}]
		}
	}
} else {


#log_user 0
#set timeout [expr {$refresh_interval_s + 1}]	;# or perhaps * 2.
# NOTE: may want to consider using "free -b" to use bytes as lowest-common-denominator measure.
#spawn free -s $refresh_interval_s
set input_stream [open [list |free -s $refresh_interval_s] r]
fconfigure $input_stream -buffering line
# Output looks like:
#<<
#             total       used       free     shared    buffers     cached
#Mem:       3933736    3713660     220076          0      47432    1593324
#-/+ buffers/cache:    2072904    1860832
#Swap:      2048276      74432    1973844
#>>

# However, the output may vary with the version.  For "free from procps-ng 3.3.10", it's:
#<<
#              total        used        free      shared  buff/cache   available
#Mem:        8087480     1041668     1595552       91572     5450260     6670524
#Swap:       8388604           0     8388604
#>>
# TBH, maybe just reading from /proc/meminfo would be just as easy, and possibly less likely to need altering over time.

# Hmm, ideally an atomic read from the input stream from `free` would guarantee one "Mem" and one "Swap" line.

fileevent $input_stream readable [list read_input $input_stream]

proc read_input {input_stream} {
	set line [gets $input_stream]
	# TODO: input stream error/EOF handling!

	if [regexp {Mem: +([0-9]+) +([0-9]+) +([0-9]+) +([0-9]+) +([0-9]+) +([0-9]+)} $line entire_match ::ram_total ::ram_used ::ram_free ::mem_shared ::mem_buffer ::mem_cache] {
		# Since the system will use spare physical memory for filesystem cache, the fs cache doesn't really count towards memory used.
		# I think I/O buffer memory works similarly (certainly "free" accounts for cache + buffers together).
		# Shared memory would be fixed, though, I'd think.
		set ::effective_ram_used [expr $::ram_used - $::mem_cache - $::mem_buffer]
		set ::effective_ram_free [expr $::ram_total - $::effective_ram_used]
	}
	
	# Oh, right, we have to do another read...um... or do we? read_input will be called every time there's a new line.
	regexp {Swap: +([0-9]+) +([0-9]+) +([0-9]+)} $line entire_match ::swap_total ::swap_used ::swap_free

#	puts "$ram_used"	;# Just testing...

	# Update info menu-panel:
	if {[info exists ::ram_total] && [info exists ::swap_total]} {
		update_tooltip_menu
#	update_tooltip_menu $::ram_total $::ram_used $::effective_ram_used $::ram_free $::effective_ram_free $::mem_shared $::mem_buffer $::mem_cached $::swap_total $::swap_used $::swap_free

	# For display, the effective physical RAM utilisation is the important thing (filesystem cache will make room for processes if necessary).
		memory_gauge_update [expr {double($::effective_ram_used) / double($::ram_total)}]
	}
	# TODO: handle eof properly.
#	expect eof {break}	;# i.e. not like this, which just causes an expect timeout, since it waits for EOF at every iteration of this while loop.
}
}

# Endut! Hoch hech!
