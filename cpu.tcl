#!/usr/local/bin/wish8.5

# Modified not to use dstat and just read from /proc instead (potentially faster (i.e. can read more frequently)).


# TODO: refactor this!  Most of the gauge code should be defined oncewheres.
# TODO: sort out the gauge/meter terminology.

# Basic linear gauge indicator - modified for CPU utilisation monitoring with dstat
# I think user + system aggregated is probably representative - the meter should be compact.  NOTE: don't just take the idle time and subtract from 100 % - that would treat I/O wait time as busy, which it isn't really IMO.

wm title . {DeskNerd_CPUMeter}

source {Preferences.tcl}
source {every.tcl}

# You should pass in the number of CPUs when you call this.
# TODO: figure out the number of CPUs automatically.
# TODO: what about hyperthreading/logical CPUs?
set cpu_count 4
#set cpu_count [lindex $argv 0]
set refresh_interval_ms [expr {round(4 / 60.0 * 1000)}]	;# On a system with 1000 Hz timer, this should be good down to 1 ms.  50 is probably a reasonable tradeoff.  Or a multiple of the likely display hardware refresh period.

set ::env(TERM) dumb	;# to avoid ANSI codes from dstat

# Basic meter dimension preferences:
set indicator_width 8
set indicator_height 20

# Pop-up menu for convenient exiting:
menu .popup_menu
	.popup_menu add command -label "CPU Meters" -command {}
	.popup_menu add command -label {Close} -background orange -command {exit}
bind . <3> "tk_popup .popup_menu %X %Y"


proc create_meter {meter_id} {
	global indicator_width indicator_height
	# Container frame
	pack [frame .${meter_id}_gauge  -width $indicator_width  -height $indicator_height  -relief sunken  -borderwidth 1 -background black] -side left
	
	# Meter gauge is also done as a frame
	place [frame .${meter_id}_gauge.meter     -width [expr {$indicator_width-2}] -height 0  -relief flat -borderwidth 0 -background green] -anchor sw -x 0 -y [expr {$indicator_height-2}]
}


# Then again, by duplicating this, we can customise the colouring function...
proc gauge_update {meter_id value} {
	global indicator_height .${meter_id}_gauge.meter
	# We're assuming value is a 0..1 factor.
	# Colour thresholds?  Overkill to store these in a data structure somewhere?
	# Green|Red?  Green|Orange|Red?  Green|Yellow|Orange|Red?
	# Note: yellow is no terribly visible against the default pale grey background.
	# Perhaps a fixed black background would be appropriate.
	if     {$value >= 0.90} then {set gauge_colour red} \
	elseif {$value >= 0.75} then {set gauge_colour orange} \
	elseif {$value >= 0.50} then {set gauge_colour yellow} \
	else                         {set gauge_colour green}

	.${meter_id}_gauge.meter configure -height [expr {$value * ($indicator_height-2)}] -background $gauge_colour
}


# OK, let's go...

create_meter cpu0
create_meter cpu1
create_meter cpu2
create_meter cpu3

# As an alternative to dstat (and since it only retrieves its data from there anyway), perhaps we can just use /proc/stat.  That way, we can query as often as we like (more frequently than 1 Hz, for example).  We could also determined the number of CPUs from that file.  I think the data there is in some kind of continuous counter, in percent/second units.

# Since the /proc/stat data are ongoing counters, we'll need to store the previous readings so we can compute the difference.  I think an array would be sensible.  Have to initialise it first (I think), darnit.

set prev_busy_counter(cpu0) 0
set prev_busy_counter(cpu1) 0
set prev_busy_counter(cpu2) 0
set prev_busy_counter(cpu3) 0
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
		if [string match "cpu?" $statistic] {
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


# Endut! Hoch hech!

