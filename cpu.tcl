#!/usr/bin/wish

# Modified not to use dstat and just read from /proc instead (potentially faster (i.e. can read more frequently)).


# TODO: refactor this!  Most of the gauge code should be defined oncewheres.
# TODO: sort out the gauge/meter terminology.
# TODO: figure out how to determine the number of CPUs on the system.  An initial read from /proc/stat might do: just count the number of lines matching /^cpu[0-9]+ /.  But note that [string match] uses patterns!  And think of systems with more than 9 CPUs.
# TODO: investigate leaving the /proc/stat file open while looping and just rewinding each time we read.  It would probably complicate the logic of the program to ensure it was closed when exiting, though.

# Basic linear gauge indicator - modified for CPU utilisation monitoring with dstat
# I think user + system aggregated is probably representative - the meter should be compact.  NOTE: don't just take the idle time and subtract from 100 % - that would treat I/O wait time as busy, which it isn't really IMO.

wm overrideredirect . 1
wm title . {DeskNerd_CPUMeter}

# Basic meter dimension preferences:
set indicator_width 8
set indicator_height 20

set refresh_interval_ms [expr {round(4 / 60.0 * 1000)}]	;# On a system with 1000 Hz timer, this should be good down to 1 ms.  50 is probably a reasonable tradeoff.  Or a multiple of the likely display hardware refresh period.


source {Preferences.tcl}
catch {source ~/.desknerd/cpu.tcl}


source {every.tcl}


set ::env(TERM) dumb	;# to avoid ANSI codes from dstat



# Pop-up menu for convenient exiting:
menu .popup_menu
	.popup_menu add command -label "CPU Meters" -command {}
	.popup_menu add command -label {Close} -background orange -command {exit}
bind . <3> "tk_popup .popup_menu %X %Y"


proc create_meter {meter_id} {
	global indicator_width indicator_height
	# Container frame
	pack [frame .gauges.${meter_id}_gauge  -width $indicator_width  -height $indicator_height  -relief sunken  -borderwidth 1 -background black] -side left
	
	# Meter gauge is also done as a frame
	place [frame .gauges.${meter_id}_gauge.meter     -width [expr {$indicator_width-2}] -height 0  -relief flat -borderwidth 0 -background green] -anchor sw -x 0 -y [expr {$indicator_height-2}]
}


# Then again, by duplicating this, we can customise the colouring function...
proc gauge_update {meter_id value} {
	global indicator_height .gauges.${meter_id}_gauge.meter
	# We're assuming value is a 0..1 factor.
	# Colour thresholds?  Overkill to store these in a data structure somewhere?
	# Green|Red?  Green|Orange|Red?  Green|Yellow|Orange|Red?
	# Note: yellow is no terribly visible against the default pale grey background.
	# Perhaps a fixed black background would be appropriate.
	if     {$value >= 0.90} then {set gauge_colour red} \
	elseif {$value >= 0.75} then {set gauge_colour orange} \
	elseif {$value >= 0.50} then {set gauge_colour yellow} \
	else                         {set gauge_colour green}

	.gauges.${meter_id}_gauge.meter configure -height [expr {$value * ($indicator_height-2)}] -background $gauge_colour
}


# Routine to determine how many logical CPUs are accounted for in the system.
proc get_num_cpus {} {
	set num_cpus 0
	set stat_handle [open "/proc/stat" r]
	set stat_data [read $stat_handle]
	close $stat_handle
	set stat_data [split $stat_data "\n"]
	foreach line $stat_data {
		set statistic [lindex $line 0]
		if [regexp {^cpu[0-9]+$} $statistic] {
			incr num_cpus
		}
	}
	return $num_cpus
}


# OK, let's go...

set ::num_cpus [get_num_cpus]
puts "DeskNerd CPU Meter: CPU count : ${::num_cpus}."

# Container frame for all CPU meters:
frame .gauges -relief sunken -border 1 -padx 1 -pady 1 -background black
grid .gauges

# Set up the CPU meters:
for {set n 0} {$n < $::num_cpus} {incr n} {
	create_meter cpu${n}
}


# As an alternative to dstat (and since it only retrieves its data from there anyway), perhaps we can just use /proc/stat.  That way, we can query as often as we like (more frequently than 1 Hz, for example).  We could also determined the number of CPUs from that file.  I think the data there is in some kind of continuous counter, in percent/second units.

# Since the /proc/stat data are ongoing counters, we'll need to store the previous readings so we can compute the difference.  I think an array would be sensible.  Have to initialise it first (I think), darnit.
for {set n 0} {$n < $::num_cpus} {incr n} {
	set prev_busy_counter(cpu${n}) 0
}

set prev_timestamp 0

# /proc/stat uses the following line format for CPU counters:

# cpuN user nice system idle iowait irq softirq

# The units are apparently USER_HZ ("jiffies"), typically 0.1 s (historically? I think a modern system would use 1000 Hz timers, therefore USER_HZ = 0.001).  Maybe this code won't work with a different USER_HZ value...

# To calculate the idle time for the current interval:
# 1 - (1000000 ms/s / timestamp_delta_in_ms * (curr_idle_counter - prev_idle_counter) / 100 %)

every $refresh_interval_ms {
	global prev_busy_counter refresh_interval_ms prev_timestamp

	# Let's do our own time handling, in case that's contributing to the loss of precision in the calculation:
	set curr_timestamp [clock clicks]
	set timestamp_delta [expr {$curr_timestamp - $prev_timestamp}]
#	puts "timestamp_delta = $timestamp_delta"
	set prev_timestamp $curr_timestamp

	set stat_handle [open "/proc/stat" r]
	set cpu_data [read $stat_handle]
	close $stat_handle
	
	#  Process data file
	set cpu_data [split $cpu_data "\n"]
	foreach line $cpu_data {
	#	puts "line:<<$line>>"
		set statistic [lindex $line 0]
		if [regexp {^cpu[0-9]+$} $statistic] {
			set user_counter [lindex $line 1]
			set nice_counter [lindex $line 2]
			set syst_counter [lindex $line 3]
			set idle_counter [lindex $line 4]	;# Grab the idle field from the line.
	#		set iowt_counter [lindex $line 5]	;# Not sure of the exact significance of iowait; might be good to see if the total iowait time is more than 1 CPU's worth.

			set busy_counter [expr {$user_counter + $nice_counter + $syst_counter}]
		#	puts "$statistic $user_counter $nice_counter $syst_counter $idle_counter -> $busy_counter (prev = $prev_busy_counter($statistic))"
			set busy_delta_decimal [expr {($busy_counter - $prev_busy_counter($statistic)) * 10000.0 / $timestamp_delta}]
		#	puts "busy_delta_decimal = $busy_delta_decimal"
			set prev_busy_counter($statistic) $busy_counter	;# Store the current absolute counter for next time.
			# The counter is, I think, a percentage, but it assumes that 100 % represents one second.  Should we measure the time interval, or assume that it's close enough to the delay we specify in the "every"?

			gauge_update $statistic [expr {$busy_delta_decimal}]	;# ... $refresh_interval_ms
		}
	}
#	puts ""
}


source reset_window.tcl
reset_window


# Endut! Hoch hech!

