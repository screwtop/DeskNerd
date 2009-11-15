#!/usr/bin/expectk

# DeskNerd component for displaying audio output level.  I use JACK pretty much all the time, so this is just implemented by running Nicholas J Humfrey's console-based jackmeter program in the background.  Not sure if we can connect it to an output port though, huh?  Oh, well.
# TODO: probably want two meters for stereo monitoring, but maybe one is fine (jackmeter will mix all its inputs down anyway).
# TODO: add menu for ease of exiting.


wm title . {DeskNerd_SoundMeter}
set application_name {DeskNerd Sound Meter}

source {Preferences.tcl}
source {every.tcl}

# This could actually make a decent standalone meter, with a gauge meter (markings) and a larger size.
#set refresh_frequency 60	;# Possibly suitable for large standalone meters, where you want to be able to see drum hits fairly clearly.  May jiggle due to bass frequencies.
#set refresh_frequency 15	;# Will just be passed to jack_meter, which will then drive this program's output.
set refresh_frequency 10	;# Low CPU use and long enough to take lowest audible frequencies into account.
# I had thought to set the expect timeout according to $refresh_frequency, but actually expect's timeout variable must be an integral number of seconds, and you would seldom have a refresh frequency less than 1 Hz.  However, if you do set it below 1 Hz, the 1-second expect timeout will incorrectly cause timeouts.  TODO: maybe bother improving this behaviour.
# Furthermore, a slow [spawn] due to a heavily loaded system may trigger timeouts!  Manifests itself by the sound gauge not yet existing, AFAICT.  TODO: handle this more gracefully.


# Basic meter dimension preferences:
set indicator_width 8
set indicator_height 20
# For standalone use:
#set indicator_width 10
#set indicator_height 400
# The following doesn't work: window geometry is not defined at this point, plus you'd need to handle recomputing this when resized.
#set window_geometry [split [wm geometry .] {x+}]
#puts $window_geometry
#set indicator_width [lindex $window_geometry 0]
#set indicator_height [expr "[lindex $window_geometry 1] - 4"]

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
	# TODO: now that we have RMS levels as well, perhaps use yellow to indicate RMS-based encroaching-into-headroom, and orange and red for peak measures.

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
set timeout 1	;# See comment near start about expect timeout.
spawn jack_meter -n -f $refresh_frequency
while true {
	# Init variables to avoid occasional errors?  There's probably a better way to deal with that (maybe using expect features).
	set sound_level_peak 0
	set sound_level_rms 0
	set sound_level_rms_stevens 0

	# TODO: figure out how to correctly handle genuine silence (as opposed to no signal).
#	set float_re {-?(inf|[0-9]+\.[0-9]+)}
	set float_re {-?[0-9]*\.[0-9]*}

	# "-inf" is a possibility, note!  Maybe should define a variable for a floating-point string literal regular expression (TODO).
	# Note that there's also an expect timeout that may occur here, for example when no source port is connected.
	expect -re "($float_re)	($float_re)	($float_re)" {
		# 0 -> whole match, 1 -> "Mem:", ...
		# I've modified jack_meter.c to output Stevens RMS levels as the third number, so let's try using that now.
		# Maybe it would be better to have jack_meter return raw (not dB) values, to avoid getting -infs.
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

# If jack_meter dies (and control reaches this point), we should probably just exit.   Or tell the user.  Or (perhaps better) respawn in an exception-handler?
tk_dialog .jack_meter_quit "Notification" "The jack_meter process has unexpectedly quit." {} 0 "What a shame."]
# What a shame | Oh, dear | That's a pity | ... ;^)


# Endut! Hoch hech!

