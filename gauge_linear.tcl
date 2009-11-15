# Tcl include file for drawing indicator gauges in the systray for DeskNerd.
# I could imagine an object-oriented approach being reasonable here: a meter has state and methods for updating the state, which would then be reflected in its display.
# Perhaps things like setting the maximum internal value as well, so that scaling can be done within the meter, and you just send it raw data from then on.  And perhaps minimum values too (e.g for a temperature gauge).  And of course cutoff points for the colour coding (perhaps pass as a table).
# Perhaps I should investigate how to create a proper Tk widget.
# UNFINISHED

source {Preferences.tcl}
#. configure -background $statusbar_background_colour

set indicator_width 8
set indicator_height 20




# Trying to factor out the code for generating and updating a meter gauge, so I can easily add multiple ones to a form.
# Should indicator width and height be parameters too?
# If we're essentially creating a Tk widget, shouldn't we somehow return a handle to the calling environment?  Or perhaps pass the parent container to this as a parameter.
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
	# Note: yellow is not terribly visible against the default pale grey background.
	# Perhaps a fixed black background would be appropriate.
	if     {$value >= 0.90} then {set gauge_colour red} \
	elseif {$value >= 0.75} then {set gauge_colour orange} \
	elseif {$value >= 0.50} then {set gauge_colour yellow} \
	else                         {set gauge_colour green}

	.${meter_id}_gauge.meter configure -height [expr {$value * ($indicator_height-2)}] -background $gauge_colour
}






