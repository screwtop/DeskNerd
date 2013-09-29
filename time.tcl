#!/usr/bin/wish

# DeskNerd component for date and time, and perhaps also stuff like a calendar and appointments, weather, tides, moon phases, etc.  Settings could include setting the date and time, checking NTP status and configuration, etc.

# TODO: maybe rename this "...Environment" or "...World" or something suitable, since it deals with more than just date/time.

# TODO: consider precision: if we're only checking every second, we may be up to half a second out, right?

# TODO: use -textvariable to handle the time, rather than using a manual refresh?

# TODO: have separate "Copy Date to Clipboard", "Copy Time to Clipboard", "Copy Date-Timestamp to Clipboard"?


wm title . {DeskNerd_Time}
wm overrideredirect . 1
#puts [info tclversion]

source {Preferences.tcl}
option add *TearOff 0

# Set default date formats (can be overridden in user settings):
set ::display_date_format {%c}	;# Current locale's date format.  Would be good to re-use that by default, in general, but you may want something customised if it's sitting on your desktop all the time.
set ::clipboard_date_format {%Y-%m-%d}
set ::clipboard_time_format {%H:%M:%S}
set ::clipboard_timestamp_format {%Y-%m-%d %H:%M:%S %z}

# Apply user preferences:
catch {source ~/.desknerd/time.tcl}


# Initialise date string
set date_string {}

# "every" abstraction/procedure for periodic doing of stuff. (Nice idiom from http://wiki.tcl.tk)
proc every {ms body} {
	eval $body
	after $ms [info level 0]
}

# TODO: window background colour?
. configure -background $statusbar_background_colour
# This is where the date and time get displayed:
# For the date-time display, use a menubutton or just a label?  Perhaps no "-relief groove" for this component - it's essentially read-only, not a button.

grid [menubutton .time -textvariable date_string -menu {.time.today_mockup} -background $statusbar_background_colour -foreground $statusbar_foreground_colour]
#pack [menubutton .time -textvariable date_string -background $statusbar_background_colour -foreground $statusbar_foreground_colour -font font_mono -pady 0.2m -border 0 -relief sunken]


menu .popup_menu
	# Implement a "Copy date to clipboard".  TODO: With ISO option?
	.popup_menu add command -label {Copy Date}  -command {clipboard clear; clipboard append [clock format [clock seconds] -format $::clipboard_date_format]}

.popup_menu add command -label {Copy Time}  -command {clipboard clear; clipboard append [clock format [clock seconds] -format $::clipboard_time_format]}
	
	.popup_menu add command -label {Copy Date-Time}  -command {clipboard clear; clipboard append [clock format [clock seconds] -format $::clipboard_timestamp_format]}

	.popup_menu add separator
	.popup_menu add command -label {Close} -command {exit}
bind . <3> "tk_popup .popup_menu %X %Y"


# Phony main menu, which would eventually use some kind of database or network calendar connectivity to retrieve the day's appointments dynamically.
# Features: should highlight imminent events.  Other colour-coding could also be useful.
# Features: could dim past events.
# Features: should maybe have the option to show timeslots with no goings-on, just for spacing/ease of judging timeframes by eye.
# Features: clicking on an item should bring up a window or dialog for viewing/editing details.
# Features: display ending time as well?  Probably more relevant when entering/editing appointments, CTTOI.  If using timeslots, have items span timeslots depending on ending time?
# Monospaced font (font_mono) necessary in general; however, the classic bitmapped Helvetica seems to use a fixed width for all digits, so that would be usable too!  I wouldn't expect Tk to allow us to do fancy columnar alignment within menu items.
# How to support scrolling through the days, e.g. to see what's coming up tomorrow?  Perhaps have another section always visible with tomorrow's important events on it?
menu .time.today_mockup
	# Would be nice to display the current date at the top (would have to be updated externally with an [every], since no -textvariable for menu items).
	.time.today_mockup add command -label $date_string
	.time.today_mockup add separator
	.time.today_mockup add command -label {09:00  Meeting with boss} -font font_sans -foreground darkgrey
	.time.today_mockup add command -label {10:15  Morning tea} -font font_sans -foreground darkgrey
	.time.today_mockup add command -label {12:30  Lunch} -font font_sans -foreground darkgrey
	.time.today_mockup add command -label {14:00  TPS Report due} -font font_sans -background darkred -foreground white
	.time.today_mockup add command -label {17:30  Goin' home!} -font font_sans


# How often to refresh?  If displaying seconds, maybe every 100 ms is good enough?  If only showing the minute, every second is perhaps appropriate.
every 100 {
	global date_string
	# TODO: consider storing the date in its canonical format as well, in order to support a "Copy to clipboard in ISO-8601 format", for example, as well as other common (western?) date formats.
	# Getting the system time is nice and easy, as it turns out:
	set date_string [clock format [clock seconds] -format $::display_date_format]

	# Not needed now: using -textvariable instead.
#	.time configure -text $date_string	
#	pack [menubutton .files      -text $date_string -menu .tmenu]
}

source reset_window.tcl
reset_window

