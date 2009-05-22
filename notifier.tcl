#!/usr/local/bin/wish

# A notification component for DeskNerd
# CME 2009-05-21

# Used for reporting important events from system log, arrival of e-mail, new items from RSS, Twitter, etc., and so on.
# Of course, this will eventually just draw its information from the notification database I'm planning to build... :)

# Notifications in a list, spinbox, menu or whatever I eventually decide to use should include a timestamp, but not necessarily the date.  Maybe a sensible date-shortening algorithm like Apple use in Mac OS, e.g. show the name of the day if it's between 1 and 7 days ago.


wm title . {DeskNerd_Notifier}

package require tile	;# tile

source {Preferences.tcl}
option add *TearOff 0
#. configure -background $statusbar_background_colour	;# Set in Preferences.tcl

# Button for dismiss/acknowledge/delete/OK/whatever to call it.
pack [ttk::menubutton .notifier      -text "Notifier (3 unread)" -menu .notifier.menu -relief groove] -side left
#pack [button .unread_button      -text "Unread" -relief groove] -side left
#pack [menubutton .files      -text "Files" -menu .files.menu -relief groove]

# Pop-up menu for accessing settings, exiting.
menu .popup_menu
	.popup_menu add command -label {Close} -background orange -command {exit}
bind . <3> "tk_popup .popup_menu %X %Y"

# Dummy menu items for now...
menu .notifier.menu
	.notifier.menu add command -label "Shell" -command {exec urxvt -e bash -l &}



# Hard-coded list for testing:
set notification_list [list {Mail: Nigel Stanger} {Hotblack: PostgreSQL} {Twitter: Andrew}]

# Spinbox to display the message summary.  Click or double-click to show detail.
# "values" configuration option to allow sourcing from a list.
# Also, we're somehow going to have to uniquely identify all notification messages... :^/
#pack [tk::spinbox .s -from 1.0 -to 100.0 -textvariable spinval] -side left
# spinbox doesn't seem to have -listvariable after all; try -value
pack [tk::spinbox .summary -values $notification_list] -side left

# Alternatively, a pop-up menu with recent notifications might be better - less fiddly to navigate.  It could have further sub-menus for read/seen items, yesterday's items, etc.  The button itself should have some way of showing that there are new notifications.  Maybe colour, bold, a glyph of dingbat disposition, flashing (horror! - maybe only briefly).



# Display full message details and content.  I think it would be appropriate to put this in a dialog.
tk_messageBox -message "Date: Thu 21 May  2009-05-21  18:56:17\nSystem: Hotblack\nSubsystem: PostgreSQL\n\nOuch, my disks are on fire!  Somebody give me some water, quick!"
# or for long messages:
#pack [tk::text .t -width 40 -height 1] -side left
# Should messages be dropped from the list as soon as you've read them?  I think it would be nice to have them remain in the queue a la ticker tape.  Perhaps use colour to indicate whether they've been read or not.  Perhaps you'd need a "jump to unread" or "filter to unread" button as well, or maybe some stuff in a pop-up menu.



