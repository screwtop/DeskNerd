#!/usr/bin/expectk

# Prototype disk I/O performance monitor graph based on percent utilisation (and queue length), basically hard-coded for "/dev/sda".

# TODO: refactor this!  Most of the gauge code should be defined oncewheres.

# Basic linear gauge indicator
# A frame, with a smaller frame inside it to act as the gauge?

wm title . {DeskNerd_IOMeter}

source {Preferences.tcl}
#. configure -background $statusbar_background_colour

set indicator_width 8
set indicator_height 20

# Pop-up menu for convenient exiting:
menu .popup_menu
	.popup_menu add command -label {Close} -background orange -command {exit}
bind . <3> "tk_popup .popup_menu %X %Y"


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
	if     {$value >= 0.90} then {set gauge_colour red} \
	elseif {$value >= 0.75} then {set gauge_colour orange} \
	elseif {$value >= 0.50} then {set gauge_colour yellow} \
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
		puts "queue length = $sda_queue_length"	;# Not actually queue length: scaled.
	#	io_gauge_update $sda_utilisation
		io_gauge_update [expr {$sda_queue_length / 150}]	;# Arbitrary scaling; I've seen the queue length exceed 400(!) on sbis4079.
	}
}

# Wow, that was pretty easy...

