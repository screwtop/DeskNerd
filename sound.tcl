#!/usr/bin/expectk

# DeskNerd component for displaying audio output level.  I use JACK pretty much all the time, so this is just implemented by running Nicholas J Humfrey's console-based jackmeter program in the background.  Not sure if we can connect it to an output port though, huh?  Oh, well.
# TODO: probably want two meters for stereo monitoring, but maybe one is fine (jackmeter will mix all its inputs down anyway).
# TODO: add menu for ease of exiting.


wm title . {DeskNerd_SoundMeter}
set application_name {DeskNerd Sound Meter}

source {Preferences.tcl}
source {every.tcl}

set refresh_frequency 15	;# Will just be passed to jack_meter, which will then drive this program's output.

# Basic meter dimension preferences:
set indicator_width 8
set indicator_height 20


# Container frame:
pack [frame .sound_gauge  -width $indicator_width  -height $indicator_height  -relief sunken  -borderwidth 1 -background black] -side left
	
# Meter gauge is also simply done as a frame:
place [frame .sound_gauge.meter     -width [expr {$indicator_width-2}] -height 0  -relief flat -borderwidth 0 -background green] -anchor sw -x 0 -y [expr {$indicator_height-2}]


# Update the gauge:
proc sound_gauge_update {decibels raw_rms} {
	global indicator_height .sound_gauge.meter

#	puts $raw_rms

	# Last 6 dB may get grungy, but 20 dB is commonly considered reasonable headroom, and last 3 dB is "precious", so we'll make that red.
	# Mind you, jackmeter uses peak-reading metering.  And 14 dB is probably more likely for popular music.  Replay Gain tends to give you -3 dB K-14, with "nominal peaks" around 9 dB K-14, or -6 dB FS (peak).  So, we'll put the orange/green transition at -6 dB here.
	if     {$decibels >= -1} then {set gauge_colour red} \
	elseif {$decibels >= -3} then {set gauge_colour orange} \
	elseif {$decibels >= -6} then {set gauge_colour yellow} \
	else                          {set gauge_colour green}

	# Map dB peak re. full scale to indicator height.  Perhaps convert to Stevens loudness (better if we had RMS levels to work with).
#	set value [expr {$decibels / 100.0 + 1}]	;# 100 dB range
#	set value [expr {$decibels / 30 + 1}]

;# Now trying RMS and/or Stevens loudness.  Scaling factor of sqrt(2) assumes loudest normal signal would be a full-scale sine wave.  In practice, music RMS levels should be ~14 dB below full-scale.
	# I've observed 0.26 raw numeric RMS with even Replay Gained material.  Hot masters may reach 0.45 raw numeric RMS, so k = 1.6 should be about right.
#	set k 1.6	;# For hot, peak-limited commercial music, RMS reaching 0.5 raw numeric RMS.
	set k 2.5	;# More suitable for Replay Gained or moderately mastered music, RMS reaching no higher than about 0.25.
	set value [expr {$k * pow($raw_rms, 0.67)}]
	
	.sound_gauge.meter configure -height [expr {$value * ($indicator_height-2)}] -background $gauge_colour
}



log_user 0
spawn jack_meter -n -f $refresh_frequency
while true {
	# "-inf" is a possibility, note!  Maybe should define a variable for a floating-point string literal regular expression (TODO).
	expect -re {(-?[0-9]+\.[0-9]+)	(-?[0-9]+\.[0-9]+)	(-?[0-9]+\.[0-9]+)} {
		# 0 -> whole match, 1 -> "Mem:", ...
		# I've modified jack_meter.c to output Stevens RMS levels as the third number, so let's try using that now.
		set sound_level_peak $expect_out(1,string)
		set sound_level_rms $expect_out(2,string)
		set sound_level_rms_stevens $expect_out(3,string)	;# I guess we could calculate this in this program; the RMS -> Stevens calculation is not happening at Fs after all!
	}

#	puts $sound_level_peak
#	set sound_level_peak_normalised [expr {$sound_level_peak / 100.0 + 1.0}]
#	puts $sound_level_peak_normalised

	# Update info menu-panel:
#	update_tooltip_menu $ram_total $ram_used $effective_ram_used $ram_free $effective_ram_free $mem_shared $mem_buffer $mem_cached $swap_total $swap_used $swap_free

	sound_gauge_update $sound_level_peak $sound_level_rms
#	sound_gauge_update $sound_level_peak_normalised
#	sound_gauge_update [expr {$sound_level_peak / 100.0 + 1}]
}


# Endut! Hoch hech!

