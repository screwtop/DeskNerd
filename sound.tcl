#!/usr/bin/expectk

# DeskNerd component for displaying audio output level.  I use JACK pretty much all the time, so this is just implemented by running Nicholas J Humfrey's console-based jackmeter program in the background.  Not sure if we can connect it to an output port though, huh?  Oh, well.
# TODO: probably want two meters for stereo monitoring, but maybe one is fine (jackmeter will mix all its inputs down anyway).


wm title . {DeskNerd_SoundMeter}
set application_name {DeskNerd Sound Meter}

source {Preferences.tcl}
source {every.tcl}

set refresh_frequency 30	;# Will just be passed to jack_meter, which will then drive this program's output.

# Basic meter dimension preferences:
set indicator_width 8
set indicator_height 20


# Container frame:
pack [frame .sound_gauge  -width $indicator_width  -height $indicator_height  -relief sunken  -borderwidth 1 -background black] -side left
	
# Meter gauge is also simply done as a frame:
place [frame .sound_gauge.meter     -width [expr {$indicator_width-2}] -height 0  -relief flat -borderwidth 0 -background green] -anchor sw -x 0 -y [expr {$indicator_height-2}]


# Update the gauge:
proc sound_gauge_update {value} {
	global indicator_height .sound_gauge.meter

	# Last 6 dB may get grungy, but 20 dB is commonly considered reasonable headroom, and last 3 dB is "precious", so we'll make that red.
	# Mind you, jackmeter uses peak-reading metering.  And 14 dB is probably more likely for popular music.
	if     {$value >= 0.99} then {set gauge_colour red} \
	elseif {$value >= 0.97} then {set gauge_colour orange} \
	elseif {$value >= 0.94} then {set gauge_colour yellow} \
	else                         {set gauge_colour green}

	.sound_gauge.meter configure -height [expr {$value * ($indicator_height-2)}] -background $gauge_colour
}



log_user 0
spawn jack_meter -n -f $refresh_frequency
while true {
	# "-inf" is a possibility, note!
	expect -re {(-?[0-9]+\.[0-9]+)} {
		# 0 -> whole match, 1 -> "Mem:", ...
		set sound_level_peak $expect_out(1,string)
	}

#	puts $sound_level_peak
	set sound_level_peak_normalised [expr {$sound_level_peak / 100.0 + 1.0}]
	puts $sound_level_peak_normalised
	# Update info menu-panel:
#	update_tooltip_menu $ram_total $ram_used $effective_ram_used $ram_free $effective_ram_free $mem_shared $mem_buffer $mem_cached $swap_total $swap_used $swap_free

	
	sound_gauge_update $sound_level_peak_normalised
#	sound_gauge_update [expr {$sound_level_peak / 100.0 + 1}]
}


# Endut! Hoch hech!

