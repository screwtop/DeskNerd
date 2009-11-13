# Tcl include file for drawing indicator gauges in the systray for DeskNerd.
# UNFINISHED

source {Preferences.tcl}
#. configure -background $statusbar_background_colour

set indicator_width 8
set indicator_height 20



# Container frame
pack [frame .io_gauge  -width $indicator_width  -height $indicator_height  -relief sunken  -borderwidth 1 -background black]

# Meter gauge is also done as a frame
place [frame .io_gauge.meter     -width [expr {$indicator_width-2}] -height 0  -relief flat -borderwidth 0 -background green] -anchor sw -x 0 -y [expr {$indicator_height-2}]


#.io_gauge.meter configure -height 0
# Hmm, with a height of 0, it's still 1 pixel high?!  I guess there's no sense in having an invisible frame...
# Also, yep, height-2 is the maximum height.

proc io_gauge_update {gauge_meter value indicator_height} {
#	global indicator_height
	# We're assuming value is a 0..1 factor.
	# Colour thresholds?  Overkill to store these in a data structure somewhere?
	# Green|Red?  Green|Orange|Red?  Green|Yellow|Orange|Red?
	# Note: yellow is no terribly visible against the default pale grey background.
	# Perhaps a fixed black background would be appropriate.
	if     {$value >= 0.90} then {set gauge_colour red} \
	elseif {$value >= 0.75} then {set gauge_colour orange} \
	elseif {$value >= 0.50} then {set gauge_colour yellow} \
	else                         {set gauge_colour green}

	gauge_meter configure -height [expr {$value * }] -background $gauge_colour
#	gauge_meter configure -height [expr {$value * ($indicator_height-2)}] -background $gauge_colour
}


