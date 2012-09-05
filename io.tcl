#!/usr/bin/expectk

# Disk I/O performance monitor graph based on percent utilisation (and queue length).
# Uses a continuously-running iostat process connected via expect to gather data.
# For monitoring multiple devices, it would be sensible to have this script implement multiple meters, so that only one Tcl/Tk interpreter needs to be used, and also only one iostat process.

# TODO: rework menus to support multiple devices.
# TODO: add tooltips and/or labels in the meters themselves somehow perhaps.
# TODO: support multiple drives.  Perhaps use TclRAL for storing the statistics within this program (or just pass them around as parameters).
# TODO: refactor this!  Most of the gauge code should be defined oncewheres.
# TODO: figure out how to handle multiple meters with different scales and colour mappings (%util has an upper bound, queue length does not).


wm overrideredirect . 1
wm title . {DeskNerd_IOMeter}

source {Preferences.tcl}
#. configure -background $statusbar_background_colour
# Actually, tear-off menus could be fine and handy for meters like this.
# NOTE: changing the TearOff capability changes the number of items in menus!  Fragile!
option add *TearOff 1
# TODO: fixed-width font might be sensible for the informative tooltip-menus.
#font create font_letter_gothic -family {Letter Gothic 12 Pitch} -size 10
#option add *font font_letter_gothic
# See Preferences.tcl
option add *font font_sans

set refresh_interval_s 1

# List of devices to monitor:
# You can include additional devices like sr0 here, which otherwise don't show up.
# iostat also lets you monitor individual partitions.
# Getting a list from /sys/block might also be effective.
# It would be nice to let iostat display everything, but how do we know what meter gauge's we'll need?
# User preferences/settings file:
catch {source ~/.desknerd/io.tcl}
if {![info exists device_names]} {
	set device_names {sda hda sr0}	;# Probably a fair stab
}
#set device_names {sda sdb sdc sdd sde sdf hda sr0 sr1}
#set device_names {}

# This works, but with no meters the script will fail.
#set device_pattern {([hs][dr][a-z]?[0-9]*)}	;# Default: match any.
#if {[info exists device_names]} {
#	if {$device_names != {}} {
#		# Names specified; use them:
#		set device_pattern "([join $device_names {|}])"
#	}
#}

set device_pattern "([join $device_names {|}])"


set indicator_width 8
set indicator_height 20


# Pop-up menu for convenient exiting:
# TODO: add switching between performance metrics (%util, queue length, I/Os per second, etc.), and perhaps also devices.
menu .popup_menu
	.popup_menu add command -label {Close} -background orange -command {exit}
bind . <3> "tk_popup .popup_menu %X %Y"


# A sort of interactive tool-tip, implemented as a menu.
# TODO: make the labels more maintainable, perhaps storing the strings in a relation.
# TODO: use a fixed-width font and aligned numbers for better readability.
menu .info_menu
	# TODO: include device name and perhaps other info (make, model, capacity, ...) as well.
	.info_menu add command -label {DeskNerd Disk I/O Meter} -command {}
	.info_menu add separator
	.info_menu add command -label "Device: ??" -command {}
	.info_menu add separator
	.info_menu add command -label "% Util.:      ??" -command {} -font font_mono
	.info_menu add command -label "Queue:        ??" -command {} -font font_mono
	.info_menu add command -label "Wait:         ??" -command {} -font font_mono
	.info_menu add command -label "IO/s:         ??" -command {} -font font_mono
	.info_menu add command -label "MB/s:         ??" -command {} -font font_mono
	.info_menu add separator
	.info_menu add command -label "Reads/s:      ??" -command {} -font font_mono
	.info_menu add command -label "Writes/s:     ??" -command {} -font font_mono
	.info_menu add separator
	.info_menu add command -label "Read MB/s:    ??" -command {} -font font_mono
	.info_menu add command -label "Write MB/s:   ??" -command {} -font font_mono
# Could be invoked by mouse-over or left click perhaps.
bind . <1> "tk_popup .info_menu %X %Y"

# Procedure to update the information in the "tooltip" menu.  Ideally this would only be run when necessary, e.g. when actually invoking the menu, but I'm not sure if that's possible.  Actually, having it called from the main expect loop is good in that you can watch the numbers in realtime changing within the menu.  I like.
proc update_tooltip_menu {device util depth wait reads writes read_mb write_mb} {
	set i 2
	.info_menu entryconfigure [incr i] -label "Device: $device"
	incr i
	.info_menu entryconfigure [incr i] -label "Util.:      [format {%4.0f} [expr {$util * 100}]] %"
	.info_menu entryconfigure [incr i] -label "Queue:      [format {%6.1f} $depth]"
	.info_menu entryconfigure [incr i] -label "Wait:       [format {%7.2f} $wait] s"
	.info_menu entryconfigure [incr i] -label "IO/s:       [format {%4.0f} [expr {$reads + $writes}]]"
	.info_menu entryconfigure [incr i] -label "MB/s:       [format {%6.1f} [expr {$read_mb + $write_mb}]]"
	incr i
	.info_menu entryconfigure [incr i] -label "Reads/s:    [format {%4.0f} $reads]"
	.info_menu entryconfigure [incr i] -label "Writes/s:   [format {%4.0f} $writes]"
	incr i
	.info_menu entryconfigure [incr i] -label "Read MB/s:  [format {%6.1f} $read_mb]"
	.info_menu entryconfigure [incr i] -label "Write MB/s: [format {%6.1f} $write_mb]"
}



# Set up UI:
# -relief groove -border 2
frame .gauges -relief sunken -border 1 -padx 1 -pady 1 -background black
grid .gauges

foreach device $device_names {
#	puts $device
	# Bevelled container frame:
	pack [frame .gauges.$device  -width $indicator_width  -height $indicator_height  -relief sunken  -borderwidth 1 -background black] -side left
	# Meter gauge itself is also done as a frame
	place [frame .gauges.${device}.meter     -width [expr {$indicator_width-2}] -height 0  -relief flat -borderwidth 0 -background green] -anchor sw -x 0 -y [expr {$indicator_height-2}]

}


#.io_gauge.meter configure -height 0
# Hmm, with a height of 0, it's still 1 pixel high?!  I guess there's no sense in having an invisible frame...
# Also, yep, height-2 is the maximum height.

proc io_gauge_update {device value} {
	global indicator_height
	# We're assuming value is a 0..1 factor.
	# Colour thresholds?  Overkill to store these in a data structure somewhere?
	# Green|Red?  Green|Orange|Red?  Green|Yellow|Orange|Red?
	# Note: yellow is not terribly visible against the default pale grey background.
	# Perhaps a fixed black background would be appropriate.
	# For % util.:
	# {{0.5 green} {0.75 yellow} {0.90 orange} {1.0 red}}
	if     {$value >= 0.90} then {set gauge_colour red} \
	elseif {$value >= 0.75} then {set gauge_colour orange} \
	elseif {$value >= 0.50} then {set gauge_colour yellow} \
	else                         {set gauge_colour green}

	# For queue length: < 1 is OK, more than 2 is def bad.  Give a bit of leeway (1.01 is close enough to 1 to be left green).
	# {{0.35 green} {0.5 orange} {1.0 red}}
#	if     {$value >= 0.5} then {set gauge_colour red} \
#	elseif {$value >= 0.35} then {set gauge_colour orange} \
#	else                         {set gauge_colour green}

	.gauges.${device}.meter configure -height [expr {$value * ($indicator_height-2)}] -background $gauge_colour
}


# Ping to systray:
source reset_window.tcl
reset_window


#stty -echo	;# No, that's for passwords! :)
log_user 0
#spawn iostat -x -m 1	;# Simple when no variable args, trickier when with:
eval [list spawn iostat -x -m $refresh_interval_s] [lrange $device_names 0 end]
# Line format is "sda               0.00     0.00    0.00    0.00     0.00     0.00     0.00     0.00    0.00   0.00   0.00"
while true {
	expect -re [concat $device_pattern { +([0-9\.]+) +([0-9\.]+) +([0-9\.]+) +([0-9\.]+) +([0-9\.]+) +([0-9\.]+) +([0-9\.]+) +([0-9\.]+) +([0-9\.]+) +([0-9\.]+) +([0-9\.]+)}] {
		# 0 -> whole match, 1 -> "device", ...
		set device $expect_out(1,string)
		set utilisation [expr {$expect_out(12,string) / 100.0}]
		set queue_length [expr {$expect_out(9,string)}]
		set queue_length_meter [expr {1 - pow(1/sqrt(2.0), $queue_length)}]
	#	puts "device = $device	utilisation = $utilisation	queue length = $queue_length	meter = $queue_length_meter"
		set reads_per_second [expr {$expect_out(4,string)}]
		set writes_per_second [expr {$expect_out(5,string)}]
		set read_megabytes_per_second [expr {$expect_out(6,string)}]
		set write_megabytes_per_second [expr {$expect_out(7,string)}]
		set average_wait_time_seconds [expr {$expect_out(10,string) / 1000.0}]

		io_gauge_update $device $utilisation
		update_tooltip_menu $device $utilisation $queue_length $average_wait_time_seconds $reads_per_second $writes_per_second $read_megabytes_per_second $write_megabytes_per_second
		
		# A queue length of 1 is fine for a single drive; 2 or higher may be a problem.  I've seen the queue length exceed 400(!) on sbis4079's single drive.
		# What sort of scaling to use?  Maybe logarithmic?  meter = 1 - (constant ^ queue_length) looks suitable.
	#	io_gauge_update $sda_queue_length_meter
	#	io_gauge_update [expr {1 - 0.70710 ** $sda_queue_length}]	;# Doesn't work - maybe due to no ** in older Tcl usend in the expectk I have?  Seems OK in Tcl 8.5.
	#	io_gauge_update [expr {$sda_queue_length / 150}]	;# Old arbitrary scaling

	}
}

# Wow, that was pretty easy...

