#!/usr/bin/env tclsh

# Simple clipboard viewer widget for DeskNerd
# CME 2012-09-19


# On X11, we have the complication that there isn't just one clipboard.  X clients are required to handle at least the PRIMARY, SECONDARY, and CLIPBOARD selections.

# It looks like the ICCCM actually anticipates running a client dedicated to managing clipboard data, e.g. to preserve their contents even if the client from which the data originated terminates. xclipboard is such a program. There is provision for a client to assert ownership of the CLIPBOARD selection.
# http://tronche.com/gui/x/icccm/sec-2.html#s-2.6.1

# In Tcl/Tk:
# selection clear | get | handle | own
# clipboard clear | append | get

# TODO: (optionally) keep the PRIMARY and CLIPBOARD selections synchronised.  Or maybe always do it, cos it'll make the UI and updating logic simpler.
# TODO: implement multiple clip units like on the Amiga or in xclipboard?
# TODO: facility for saving clipboard to a file (and loading too?).
# TODO: maybe even record a permanent history of all clipboard events in a database.  Could make for interesting (if highly sensitive) archaeology.
# TODO: truncate the display of the clipboard data (one line only, max n chars).
# TODO: QR code display of clipboard data (using say tzint). Should it appear as an image in the menu, or perhaps just as a pop-up-on-mouse-over image.
# TODO: convert to using a menubutton for docking into the statusbar/systray.
# TODO: handle tzint failure, e.g. "can't read "qr_xbm": no such variable"
# TODO: tweak [shorten] so that it doesn't just return "..." if the clipboard contents starts with a line break.


package require Tk
#wm overrideredirect . 1
wm title . {DeskNerd_Clipboard}

set ::debugging false
source debugging.tcl

# Tolerate absence of tzint:
if {[catch {package require tzint}]} {
	set ::doing_qrcodes 0
	warning "tzint package not found; please install it if you want QR code support."
} else {
	set ::doing_qrcodes 1
}

source Preferences.tcl

set ::refresh_interval_ms 250
set ::keep_synced 1
set ::clipboard_history_length 99





set ::clipboard_history [list]
set ::clipboard_value {}

# Read and return a file's entire contents:
proc slurp {filename} {
	set file_handle [open $filename r]
	set file_data [read $file_handle]
	close $file_handle
	return $file_data
}

# Overwrite a file with specified contents:
proc splat {filename data} {
	set file_handle [open $filename w]
	puts -nonewline $file_handle $data
	close $file_handle
}


# Use this proc to set the canonical clipboard value.
proc set_clipboard_value {value} {
	set ::clipboard_value $value
	# TODO: check [llength $::clipboard_history] against $::clipboard_history_length and prune if necessary.
	lappend ::clipboard_history $value
	# Do we write it back using [clipboard append] and/or [selection ...]?  Or is it just for display?

	# Update GUI components as well:
	.clipboard.menu entryconfigure 1 -label [shorten $value]
	update_qr_image $value

	return [llength $::clipboard_history]
}

toplevel .debugging
label .debugging.primary_label -justify right -anchor e -text {PRIMARY selection:}
label .debugging.primary_contents -relief sunken -justify left -anchor w -textvariable ::primary_selection_contents

label .debugging.clipboard_label -justify right -anchor e -text {CLIPBOARD selection:}
label .debugging.clipboard_contents -relief sunken -justify left -anchor w -textvariable ::clipboard_selection_contents

# Weird: the checkbutton widget doesn't seem to reflect the value of the variable...
# Ah, it does - it just has to be 1 or 0 (unlike other booleans in Tcl, which support the likes of "tRu").
checkbutton .debugging.keep_synced_button -text {Keep synchronised} -variable ::keep_synced

grid .debugging.primary_label   .debugging.primary_contents   -sticky nsew
grid .debugging.clipboard_label .debugging.clipboard_contents -sticky nsew
grid configure  .debugging.keep_synced_button -column 1

if {!$::debugging} {wm withdraw .debugging}

set ::qr_image {}


proc prompt_load_file_to_clipboard {} {
	set filename [tk_getOpenFile -title "Load text file to clipboard"]
	if {![file exists $filename]} {return}
	clipboard clear
	clipboard append [slurp $filename]
	set_clipboard_value [clipboard get]
}

# TODO: save clipboard to file:
proc prompt_save_clipboard_to_file {} {
	set filename [tk_getSaveFile -title "Filename to save as"]
	# Any checking?
	splat $filename $::clipboard_value	;#  [clipboard get] or $::clipboard_value?
}


# Trayable menubutton is the main interface:
# NOTE: we probably want to allow tear-off for this menu.
# TODO: separate submenus for PRIMARY and CLIPBOARD? (and SECONDARY?!)
pack [menubutton .clipboard -font "font_sans 8" -text "Clipboard" -menu .clipboard.menu -direction above]
menu .clipboard.menu -tearoff 1
	.clipboard.menu add command -label "" -command "" -background white	;# entry 1: abbreviated clipboard text
	.clipboard.menu add command -image $::qr_image -background white	;# entry 2: QR code (NOTE: or -bitmap)
	set ::qr_menu_index 2
	.clipboard.menu add separator	;# entry 3: separator
	.clipboard.menu add command -label "Load file into clipboard\u2026" -command prompt_load_file_to_clipboard	;# entry 4
	.clipboard.menu add command -label "Save clipboard to file\u2026" -command prompt_save_clipboard_to_file	;# entry 5
	# TODO: other send mechanisms, such as e-mail, XMPP, SCP, ...?

# TODO: would be nice to be able to copy (or save) the resulting QR image as well, actually...

# Might be nice to indicate when the clipboard has changed:
proc flash_clipboard_button {} {
	set old_colour [.clipboard cget -background]
	after idle {.clipboard configure -background green}
	after 100 [list .clipboard configure -background $old_colour]
	unset old_colour
}

# I even wonder about displaying the shortened clipboard contents in the menubutton, but it'd have to be pretty teensy, and would only make sense for text.



# TODO: pop-up menu for control of the Clipboard program itself.
# ...

# Shorten clipboard contents for display in menu (max one line, max n chars).
# Should this proc also set the global variable used for the abbreviated clipboard string?  Oh, unfortunately, I don't think you can use a variable as the source of text for a menu item.  The menubutton has -textvariable, but not the menu or its items. :(
proc shorten {text} {
	# Need to note whether we're actually discarding stuff.
	set maxlen 80	;# Truncate if more than this many chars
	set abbreviation {}
	if {[string first "\n" $text] >= 0 || [string length $text] > $maxlen} {set abbreviation {…}}
#	set ::clipboard_display_text "[string range [lindex [split $text "\n"] 0] 0 $maxlen]${abbreviation}"
	return "[string range [lindex [split $text "\n"] 0] 0 $maxlen]${abbreviation}"
	# Fugly:
#	.clipboard.menu entryconfigure 3
}


# Use tzint to generate a QR image of the clipboard contents:
proc update_qr_image {data} {
	if {!$::doing_qrcodes} {return}

	# How best to deal with excessively long content?  We can't just return, because there might be a previous image left hanging around that should be zeroed out.  We could truncate it, maybe, and still give some of the data in the QR...dangerous though to modify the data without warning the user somehow.
	# if {[string length $data] > 1800} {???}
	# Perhaps we could create a blank image initially, and rely on it being overwritten if a new one can be generated.

	# TODO: have it work with empty $data.

	# TODO: maybe a heuristic for setting the scale based on the size of the data? And the available screen real estate?
	# Perhaps bail if the amount of data exceeds some reasonable threshold.  1800 characters is certainly pushing it on my portrait display at work, at -scale 4.  Also, even before we hit the limit of the library, the Barcode Scanner app for Android starts to struggle with large images.  There is also a size limit specified for QR data, which we could honour.
	# In the meantime, -scale 4 is probably fine for most uses.
#% winfo screenheight .
#1600
#% winfo screenwidth .
#1200

	# Note: Barcode Scanner app for Android does not work with black border (-box is for L and R black mattes, -bind is for T and B).
	# tzint::Encode bits | eps | svg | xbm varName data ?-option value ...?
	tzint::Encode xbm qr_xbm $data -symbology qrcode -bind false -box false -border 4 -scale 4

	# Note that increasing the scale makes encoding significantly slower! :(  Maybe can scale using the image create command instead?  -zoom?
	# We could have it regenerate the QR code every time the clipboard changes, but that could be quite wasteful. At least run with low CPU priority if doing that.  Alternatively, have it regenerate on demand, when the menu is invoked, although that'll slow down the menu displaying.  Perhaps when you mouse over the main menu button, so it starts before you even click?

	if {[catch {image delete $::qr_image} err]} {warning "update_qr_image: warning: $err"}
	set ::qr_image [image create bitmap]
	if {[catch {set ::qr_image [image create bitmap -data $qr_xbm]} err]} {warning "update_qr_image: error creating bitmap: $err (maybe clipboard contents too large)"}
	# TODO: replace puggers hard-coded menu entry index!
	.clipboard.menu entryconfigure 2 -image $::qr_image

	unset -nocomplain qr_xbm
}

# This now in ~/.tclshrc
proc try {script_to_try script_if_failed} {
	if [catch {uplevel 1 $script_to_try}] {
		uplevel $script_if_failed
	}
}

# Also, should we own one of the selection units (as xclipboard does, I believe)?  I think we probably should.  Would need [selection own] and to define a command usable for [selection handle ...].

proc clipboard_updater {} {
	# Save a copy of the old values so we can detect changes:
	set ::clipboard_old_selection_contents $::clipboard_selection_contents
	set ::primary_old_selection_contents $::primary_selection_contents

	set something_changed false

	# Grab a copy of the current clipboard and primary selections:
	# (We have to copy it in order to display it in the GUI)
	# Also, some applications will occasionally set the clipboard to the empty string (when exiting, for example, which is an annoyance that I've noted in the past).  Ignore such changes.
	try {
		set new_clipboard [selection get -selection CLIPBOARD]
		if {$new_clipboard != ""} {
			set ::clipboard_selection_contents $new_clipboard
			if {$new_clipboard != $::clipboard_old_selection_contents} {set something_changed true}
		} else {
			# Restore the old value:
			set ::clipboard_selection_contents $::clipboard_old_selection_contents
		}
	} {
		#set ::clipboard_selection_contents {}
	}

	# Do likewise with PRIMARY:
	try {
		set new_primary [selection get -selection PRIMARY]
		if {$new_primary != ""} {
			set ::primary_selection_contents $new_primary
			if {$new_primary != $::primary_old_selection_contents} {set something_changed true}
		} else {
			# Restore the old value:
			set ::primary_selection_contents $::primary_old_selection_contents
		}
	} {
		#set ::primary_selection_contents {}
	}

	# TODO: what about the SECONDARY selection?

	# It might be nice to synchronise the two clipboards.  We'd need to tell which was the last one to be changed, and of course they might both have changed (probably due to the same client updating them simltaneously).
	# However, it might be reasonable to assume that any software that uses the CLIPBOARD selection is also going to place the contents in the PRIMARY selection as well (certainly GVim and LibreOffice do this (actually, no, LibreOffice at work doesn't seem to!)).  This makes life much easier:
	if {$::primary_old_selection_contents != $::primary_selection_contents} {
		set something_changed true

		debug " * \"$::primary_selection_contents\""
		# TODO: log somewhere?

		# Also optionally copy to the CLIPBOARD selection:
		if $::keep_synced {
			set ::clipboard_selection_contents $::primary_selection_contents
			clipboard clear
			clipboard append $::primary_selection_contents
			# Update GUI elements as well:
			set_clipboard_value $::primary_selection_contents
		}
	}

	# TODO: try to put this earlier, because generating the QR image takes quite a while.
	if {$something_changed} {flash_clipboard_button}

	after $::refresh_interval_ms {clipboard_updater}
}


clipboard_updater

