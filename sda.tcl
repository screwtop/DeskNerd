#!/usr/bin/expectk

# Prototype disk I/O performance monitor graph based on percent utilisation (and queue length), basically hard-coded for "/dev/sda" for now.
# Uses a continuously-running iostat process connected via expect to gather data.
# For monitoring multiple devices, it would be sensible to have this script implement multiple meters, so that only one Tcl/Tk interpreter needs to be used, and also only one iostat process.

# TODO: support multiple drives.  Perhaps use TclRAL for storing the statistics within this program (or just pass them around as parameters).
# TODO: refactor this!  Most of the gauge code should be defined oncewheres.

# Basic linear gauge indicator
# A frame, with a smaller frame inside it to act as the gauge?

wm title . {DeskNerd_IOMeter}

source {Preferences.tcl}
#. configure -background $statusbar_background_colour
# Actually, tear-off menus could be fine and handy for meters like this.
# NOTE: changing the TearOff capability changes the number of items in menus!  Fragile!
option add *TearOff 1
# TODO: fixed-width font might be sensible for the informative tooltip-menus.
option add *font font_sans



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
	.info_menu add command -label "% Util.: ??" -command {}
	.info_menu add command -label "Queue: ??" -command {}
	.info_menu add command -label "IO/s: ??" -command {}
	.info_menu add command -label "MB/s: ??" -command {}
	.info_menu add separator
	.info_menu add command -label "Reads/s: ??" -command {}
	.info_menu add command -label "Writes/s: ??" -command {}
	.info_menu add separator
	.info_menu add command -label "Read MB/s: ??" -command {}
	.info_menu add command -label "Write MB/s: ??" -command {}
# Could be invoked by mouse-over or left click perhaps.
bind . <1> "tk_popup .info_menu %X %Y"

# Procedure to update the information in the "tooltip" menu.  Ideally this would only be run when necessary, e.g. when actually invoking the menu, but I'm not sure if that's possible.  Actually, having it called from the main expect loop is good in that you can watch the numbers in realtime changing within the menu.  I like.
proc update_tooltip_menu {util depth reads writes read_mb write_mb} {
	set i 2
	.info_menu entryconfigure [incr i] -label "Util.: [expr {round($util * 100)}] %"
	.info_menu entryconfigure [incr i] -label "Queue: $depth"
	.info_menu entryconfigure [incr i] -label "IO/s: [expr {$reads + $writes}]"
	.info_menu entryconfigure [incr i] -label "MB/s: [expr {$read_mb + $write_mb}]"
	incr i
	.info_menu entryconfigure [incr i] -label "Reads/s: $reads"
	.info_menu entryconfigure [incr i] -label "Writes/s: $writes"
	incr i
	.info_menu entryconfigure [incr i] -label "Read MB/s: $read_mb"
	.info_menu entryconfigure [incr i] -label "Write MB/s: $write_mb"
}



# Container frame
pack [frame .io_gauge  -width $indicator_width  -height $indicator_height  -relief sunken  -borderwidth 1 -background black]

# Meter gauge is also done as a frame
place [frame .io_gauge.meter     -width [expr {$indicator_width-2}] -height 0  -relief flat -borderwidth 0 -background green] -anchor sw -x 0 -y [expr {$indicator_height-2}]


#.io_gauge.meter configure -height 0
# Hmm, with a height of 0, it's still 1 pixel high?!  I guess there's no sense in having an invisible frame...
# Also, yep, height-2 is the maximum height.

proc io_gauge_update {value} {
	global indicator_height .io_gauge.meter
	# We're assuming value is a 0..1 factor.
	# Colour thresholds?  Overkill to store these in a data structure somewhere?
	# Green|Red?  Green|Orange|Red?  Green|Yellow|Orange|Red?
	# Note: yellow is no terribly visible against the default pale grey background.
	# Perhaps a fixed black background would be appropriate.
	# For % util.:
	if     {$value >= 0.90} then {set gauge_colour red} \
	elseif {$value >= 0.75} then {set gauge_colour orange} \
	elseif {$value >= 0.50} then {set gauge_colour yellow} \
	else                         {set gauge_colour green}

	# For queue length: < 1 is OK, more than 2 is def bad.  Give a bit of leeway (1.01 is close enough to 1 to be left green).
	if     {$value >= 0.5} then {set gauge_colour red} \
	elseif {$value >= 0.35} then {set gauge_colour orange} \
	else                         {set gauge_colour green}

	.io_gauge.meter configure -height [expr {$value * ($indicator_height-2)}] -background $gauge_colour
}


#stty -echo	;# No, that's for passwords! :)
log_user 0
spawn iostat -x -m 1
# Line format is "sda               0.00     0.00    0.00    0.00     0.00     0.00     0.00     0.00    0.00   0.00   0.00"
while true {
	expect -re {(sda) +([0-9\.]+) +([0-9\.]+) +([0-9\.]+) +([0-9\.]+) +([0-9\.]+) +([0-9\.]+) +([0-9\.]+) +([0-9\.]+) +([0-9\.]+) +([0-9\.]+) +([0-9\.]+)} {
		# 0 -> whole match, 1 -> "sda", ...
		set sda_utilisation [expr {$expect_out(12,string) / 100.0}]
		set sda_queue_length [expr {$expect_out(9,string)}]
		set sda_queue_length_meter [expr {1 - pow(1/sqrt(2.0), $sda_queue_length)}]
	#	puts "queue length = $sda_queue_length; meter = $sda_queue_length_meter"
		set sda_reads_per_second [expr {$expect_out(4,string)}]
		set sda_writes_per_second [expr {$expect_out(5,string)}]
		set sda_read_megabytes_per_second [expr {$expect_out(6,string)}]
		set sda_write_megabytes_per_second [expr {$expect_out(7,string)}]

		io_gauge_update $sda_utilisation
		# A queue length of 1 is fine for a single drive; 2 or higher may be a problem.  I've seen the queue length exceed 400(!) on sbis4079's single drive.
		# What sort of scaling to use?  Maybe logarithmic?  meter = 1 - (constant ^ queue_length) looks suitable.
	#	io_gauge_update $sda_queue_length_meter
	#	io_gauge_update [expr {1 - 0.70710 ** $sda_queue_length}]	;# Doesn't work - maybe due to no ** in older Tcl usend in the expectk I have?  Seems OK in Tcl 8.5.
	#	io_gauge_update [expr {$sda_queue_length / 150}]	;# Old arbitrary scaling

		update_tooltip_menu $sda_utilisation $sda_queue_length $sda_reads_per_second $sda_writes_per_second $sda_read_megabytes_per_second $sda_write_megabytes_per_second
	}
}

# Wow, that was pretty easy...

