#!/usr/bin/tclsh8.5

# Simple clipboard viewer widget for DeskNerd
# CME 2012-09-19

# TODO: (optionally) keep the PRIMARY and CLIPBOARD selections synchronised.
# TODO: implement multiple clip units like on the Amiga or in xclipboard?
# TODO: facility for saving clipboard to a file (and loading too?).
# TODO: maybe even record a permanent history of all clipboard events in a database.  Could make for interesting (if highly sensitive) archaeology.


package require Tk

#wm overrideredirect . 1
wm title . {DeskNerd_Clipboard}

set ::refresh_interval_ms 250
set ::keep_synced 1


label .primary_label -justify right -anchor e -text {PRIMARY selection:}
label .primary_contents -relief sunken -justify left -anchor w -textvariable ::primary_selection_contents

label .clipboard_label -justify right -anchor e -text {CLIPBOARD selection:}
label .clipboard_contents -relief sunken -justify left -anchor w -textvariable ::clipboard_selection_contents

# Weird: the checkbutton widget doesn't seem to reflect the value of the variable...
# Ah, it does - it just has to be 1 or 0 (unlike other booleans in Tcl, which support the likes of "tRu").
checkbutton .keep_synced_button -text {Keep synchronised} -variable ::keep_synced

grid .primary_label   .primary_contents   -sticky nsew
grid .clipboard_label .clipboard_contents -sticky nsew
grid configure  .keep_synced_button -column 1


# This now in ~/.tclshrc
proc try {script_to_try script_if_failed} {
	if [catch {uplevel 1 $script_to_try}] {
		uplevel $script_if_failed
	}
}

# Also, should we own one of the selection units (as xclipboard does, I believe)?

proc clipboard_updater {} {
	# Save a copy of the old values so we can detect changes:
	set ::clipboard_old_selection_contents $::clipboard_selection_contents
	set ::primary_old_selection_contents $::primary_selection_contents

	# Grab a copy of the current clipboard and primary selections:
	# (We have to copy it in order to display it in the GUI)
	# Also, some applications will occasionally set the clipboard to the empty string (when exiting, for example, which is an annoyance that I've noted in the past).  Ignore such changes.
	try {
		set new_clipboard [selection get -selection CLIPBOARD]
		if {$new_clipboard != ""} {
			set ::clipboard_selection_contents $new_clipboard
		} else {
			# Restore the old value:
			set ::clipboard_selection_contents $::clipboard_old_selection_contents
		}
	} {
		#set ::clipboard_selection_contents {}
	}

	# Do likewise with PRIMRAY:
	try {
		set new_primary [selection get -selection PRIMARY]
		if {$new_primary != ""} {
			set ::primary_selection_contents $new_primary
		} else {
			# Restore the old value:
			set ::primary_selection_contents $::primary_old_selection_contents
		}
	} {
		#set ::primary_selection_contents {}
	}

	# It might be nice to synchronise the two clipboards.  We'd need to tell which was the last one to be changed.
	# However, it might be reasonable to assume that any software that uses the CLIPBOARD selection is also going to place the contents in the PRIMARY selection as well (certainly GVim and LibreOffice do this).  This makes life much easier:
	if {$::primary_old_selection_contents != $::primary_selection_contents} {
		puts " * \"$::primary_selection_contents\""
		# TODO: log somewhere?
		# Also optionally copy to the CLIPBOARD selection:
		if $::keep_synced {
			set ::clipboard_selection_contents $::primary_selection_contents
			clipboard clear
			clipboard append $::primary_selection_contents
		}
	}
	after $::refresh_interval_ms {clipboard_updater}
}

clipboard_updater

