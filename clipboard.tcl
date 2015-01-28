#!/usr/bin/env tclsh

# Simple clipboard viewer widget for DeskNerd
# CME 2012-09-19


# On X11, we have the complication that there isn't just one clipboard.  X clients are required to handle at least the PRIMARY, SECONDARY, and CLIPBOARD selections (although I believe the SECONDARY selection is seldom used).

# It looks like the ICCCM actually anticipates running a client dedicated to managing clipboard data, e.g. to preserve their contents even if the client from which the data originated terminates. xclipboard is such a program. There is provision for a client to assert ownership of the CLIPBOARD selection.
# http://tronche.com/gui/x/icccm/sec-2.html#s-2.6.1

# The original design of this program used periodic checking for changes in the CLIPBOARD and PRIMARY selections, but now it tries to own both of those (and re-take ownership if lost).  This allows for a simpler, more reliable implementation, and allows content to be preserved even after the original client terminates, but couuld cause bad interactions with other programs that try to do the same, and unfortunately, taking ownership of the PRIMARY selection causes the original selected text to become unselected.  This makes things like triple-clicking (which extends the selection incrementally, re-owning each time) and basic editing in clients that use the PRIMARY selection not work properly.

# TODO: figure out how to deal with certain clients that use the PRIMARY selection when editing text (e.g. gvim's Find dialog, all Tk text/entry widgets!). It's annoying if you're selecting text to edit it and the selection vanishes from underneath you! We might just have to not own PRIMARY. :(
# DONE: preserve existing CLIPBOARD (and/or PRIMARY) value (by copying before owning the respective selection).
# TODO: fix race condition with the button flashing?
# TODO: (optionally) keep the PRIMARY and CLIPBOARD selections synchronised.  Or maybe always do it, cos it'll make the UI and updating logic simpler.  Or, perhaps just offer separate options to own PRIMARY, CLIPBOARD, and perhaps SECONDARY.
# TODO: implement multiple clip units like on the Amiga or in xclipboard?
# DONE: facility for saving clipboard to a file (and loading too?).
# TODO: maybe even record a permanent history of all clipboard events in a database.  Could make for interesting (if highly sensitive) archaeology.
# DONE (pending refinements): truncate the display of the clipboard data (one line only, max n chars).
# TODO: tweak [shorten] so that it doesn't just return "..." if the clipboard contents starts with a line break.
# DONE (apart from tooltip): QR code display of clipboard data (using say tzint). Should it appear as an image in the menu, or perhaps just as a pop-up-on-mouse-over image.
# DONE: convert to using a menubutton for docking into the statusbar/systray.
# TODO: handle tzint failure, e.g. "can't read "qr_xbm": no such variable"

# WTF: I'm seeing periodic requests for the clipboard contents that I don't believe are originating from this program's behaviour...
# ...turns out it's Adobe Reader (version 9 on Linux). Every 1.7 seconds it reads from CLIPBOARD. Weird.

# One nuisance is that taking ownership of the selection causes the highlighting in the original client window to vanish. More importantly, the delays here should be big enough not to disturb things like triple-clicking to highlight an entire line in a terminal window. Each incremental increase in the selection range causes a new ownership of the selection, but if we take ownership before the n-clicking has finished, the selection will be lost from the other window before it can be properly made.

# I don't think we can tell anything much about the client we lost the selection to.



package require Tk
#wm overrideredirect . 1
wm title . {DeskNerd_Clipboard}

set ::debugging false
source debugging.tcl

# TODO: honour this
set ::do_beep false

# Tolerate absence of tzint:
if {[catch {package require tzint}]} {
	set ::doing_qrcodes 0
	warning "tzint package not found; please install it if you want QR code support."
} else {
	set ::doing_qrcodes 1
}

source Preferences.tcl

set ::refresh_interval_ms 250	;# No longer used with selection ownership approach.
set ::selection_copy_delay 700	;# Length of time after another client takes ownership before we take it back and copy the value. This should be long enough that e.g. triple-clicking in a terminal window still works.
set ::keep_synced 1
set ::clipboard_history_length 99	;# TODO: honour this (in set_clipboard_value below)


set ::clipboard_history [list]
set ::clipboard_value {}



# IIUC, this regains control over the CLIPBOARD selection, copying what the other application had put there when it took ownership.  This seems much nicer than my original timed checking.
# To have this work with the PRIMARY selection as well...?
# NOTE: this isn't actually being used, it was just used as a basis for reown_selection below.
proc readclip {} {
	after 50 {
		puts [set cnt [clipboard get]]
		clipboard clear
		clipboard append $cnt
		selection own -command readclip -selection CLIPBOARD .	;# TODO: add -type, -format
		selection handle . [list string range $cnt]
	}
};# http://stackoverflow.com/questions/18211181/tcl-tk-observing-clipboard

#selection own -command readclip -selection CLIPBOARD .


proc beep {frequency duration} {
	if {[info exists ::do_beep] && $::do_beep} {
		if {[catch [list exec beep -f $frequency -l $duration] err]} {
			puts stderr $err
		}
	}
}

# This callback returns the current value of our own internal clipboard variable, for when we own the selection.
# TODO: is it a problem that the size_limit argument is in bytes, but we're calculating the range using characters?
proc selection_handler {offset size_limit} {
	# Debugging:
	debug "selection_handler: offset=$offset, size_limit=$size_limit, from <<$::clipboard_value>>"
#	set result [string range $::clipboard_value $offset [expr {$offset + $size_limit - 1}]]
#	debug "selection_handler: result = <<$result>>"
#	return $result
	# Really it's a one-liner (and could be in-lined in the [selection own], but it makes debugging easier, and procs are bytecoded.
	flash_clipboard_button green white
	beep 384 8
	return [string range $::clipboard_value $offset [expr {$offset + $size_limit - 1}]]
}

# The own_selection procedure simply returns whether we own the specified selection. (no need for a global variable for this, since we can check it so easily directly, using [selection own].)
# How to name this so that it implies a boolean/question? "is_selection_owned"? "query_..."?
proc own_selection {SELECTION} {return [expr {[selection own -selection $SELECTION] == {.}}]}
# Um, does checking ownership with [selection own] also cause the selection handler to run?! I'm seeing it run more often than expected. No, that was due to Adobe Reader being weird.

# The reown_selection procedure (re-)gains ownership of the specified selection, copying what was there into our own internal clipboard variable, so that it can provided via both CLIPBOARD and PRIMARY.
# What about clients that "simultaneously" set both CLIPBOARD and PRIMARY? gvim is one example. Firefox seems to do reasonably sensible things too.  I think the upshot is that we re-own both in rapid succession, slightly redundantly, so not really a problem.
proc reown_selection {SELECTION} {
	debug "SELECTION = $SELECTION"
	# TODO: check for and honour preference for owning a particular selection (it might ultimately not make sense to own the PRIMARY selection, unfortunately).
	# NOTE: we don't have any way of knowing if the selection has been owned by another client since this was last run. Most of the time, we simply end up copying it back to ourself!  Actually, that probably is silly: we have the "lost selection" callback, which could set a flag...oh, and there's [selection own] which allows you to check.
	if {[own_selection $SELECTION]} {return}
	# Notify user that we've grabbed a selection (regardless of whether it's changing:
	flash_clipboard_button orange white
	beep 512 8
	# Only go through the whole set_clipboard_value process if it's actually changed. This avoids excessive work in regenerating the QR code, and also redundant work (and perhaps user notifications such as beep/flash? it's a bit weird having it beep twice) for clients that set both CLIPBOARD and PRIMARY.
	set new_clipboard_value {}
	catch {set new_clipboard_value [selection get -selection $SELECTION]}
	if {$new_clipboard_value != $::clipboard_value} {
		catch {set_clipboard_value [selection get -selection $SELECTION]}
	}
	selection own -command [list schedule_reown_selection $SELECTION] -selection $SELECTION .
	selection handle -selection $SELECTION . selection_handler
}

# This is just a wrapper around reown_selection with a delay, so that things like triple-clicking (hopefully) aren't disturbed.
proc schedule_reown_selection {SELECTION} {
	beep 256 8
	debug "Lost selection $SELECTION! Will re-take ownership..."
	after $::selection_copy_delay [list reown_selection $SELECTION]
}



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

# Ah, the DeskNerd clipboard utility is a great opportunity to implement a URL-de-Googl-ifier (take a URL from a Google search result and remove the visit-via-Google nuisance)! (though better yet would be a browser add-on, although it's often when sharing a URL by e-mail that they are most overtly annoying).

proc urlDecode {str} {
	set specialMap {"[" "%5B" "]" "%5D"}
	set seqRE {%([0-9a-fA-F]{2})}
	set replacement {[format "%c" [scan "\1" "%2x"]]}
	set modStr [regsub -all $seqRE [string map $specialMap $str] $replacement]
	return [encoding convertfrom utf-8 [subst -nobackslash -novariable $modStr]]
}; # http://rosettacode.org/wiki/URL_decoding#Tcl

proc degooglify {url} {
	array set parameter [split [split [lindex [split $url ?] 1] &] {= }]
	# Need to gracefully bail if $url is not actually a Google search result link.
	if {[array names parameter url] == "url"} {
		set result [urlDecode $parameter(url)]
	} else {
		set result $url
	}
	array unset parameter
	return $result
#	if {[catch {return [urlDecode $parameter(url)]}]} {
#		return $url
#	}
	# TODO: um, array unset parameter?
}

# Likewise for redirects via Facebook:
proc defacebookify {url} {
	urlDecode [urlDecode [lindex [split $url /] end]]
}



# The set_clipboard_value proc is for setting the canonical (internal) clipboard value, to be shared by both CLIPBOARD and PRIMARY selections when other clients ask for those.
proc set_clipboard_value {value} {
	set ::clipboard_value $value
	debug "New clipboard value = $::clipboard_value"
	# TODO: check [llength $::clipboard_history] against $::clipboard_history_length and prune if necessary.
	lappend ::clipboard_history $value
	# Do we write it back using [clipboard append] and/or [selection ...]?  Or is it just for display?
	# No, we should own the PRIMARY (and CLIPBOARD?) selections.

	# Update GUI components as well:
	.clipboard.menu entryconfigure 1 -label [shorten $value]
	update_qr_image $value

	return [llength $::clipboard_history]
}


# TODO: make this debugging stuff work again (or get rid of it):

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



# Facilities for saving clipboard to and loading from external files:

proc prompt_load_file_to_clipboard {} {
	set filename [tk_getOpenFile -title "Load text file to clipboard"]
	if {![file exists $filename]} {return}
	clipboard clear
	clipboard append [slurp $filename]
	set_clipboard_value [clipboard get]
}

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
	.clipboard.menu add command -label "De-Facebook-ify URL" -command {set_clipboard_value [defacebookify [clipboard get]]}	;# entry 4
	.clipboard.menu add command -label "De-Google-ify URL" -command {set_clipboard_value [degooglify [clipboard get]]}	;# entry 5
	.clipboard.menu add separator	;# entry 4: separator
	.clipboard.menu add command -label "Load file into clipboard\u2026" -command prompt_load_file_to_clipboard	;# entry 7
	.clipboard.menu add command -label "Save clipboard to file\u2026" -command prompt_save_clipboard_to_file	;# entry 8
	# TODO: other send mechanisms, such as e-mail, XMPP, SCP, ...?

# TODO: would be nice to be able to copy (or save) the resulting QR image as well, actually...




# Might be nice to indicate when the clipboard has changed:
proc flash_clipboard_button {args} {
	set bg ""
	set fg ""
	catch {set bg [lindex $args 0]}
	catch {set fg [lindex $args 1]}
	# option get .clipboard background Background ? Nope - hardcoded defaults.
	# Toggle foreground and background by default:
	if {$bg == ""} {set bg [.clipboard cget -foreground]}
	if {$fg == ""} {set fg [.clipboard cget -background]}
	.clipboard configure -background $bg -foreground $fg
	after 150 {
		.clipboard configure \
			-background [lindex [.clipboard configure -background] 3] \
			-foreground [lindex [.clipboard configure -foreground] 3]
	}
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

	# Perhaps we could create a blank image initially, and rely on it being overwritten if a new one can be generated.

	# TODO: have it work with empty $data.

	# TODO: maybe a heuristic for setting the scale based on the size of the data? And the available screen real estate?
	# Perhaps bail if the amount of data exceeds some reasonable threshold.  1800 characters is certainly pushing it on my portrait display at work, at -scale 4.  Also, even before we hit the limit of the library, the Barcode Scanner app for Android starts to struggle with large images.  There is also a size limit specified for QR data, which we could honour.

	# In the meantime, -scale 4 is probably fine for most uses.
#% winfo screenheight .
#1600
#% winfo screenwidth .
#1200
	# Potential performance optimisation: We currently have it regenerate the QR code every time the clipboard changes, but that could be quite wasteful. At least run with low CPU priority if doing that.  Alternatively, have it regenerate on demand, when the menu is invoked, although that'll slow down the menu displaying.  Perhaps when you mouse over the main menu button, so it starts before you even click?


	# Start by removing the existing image (regardless of whether the new text is too big for a new image)
	catch {image delete $::qr_image}
	set ::qr_image [image create bitmap]
	# Or is it more efficient to re-use a Tk image and just update it to be empty?

	# Only bother creating the new QR image if it's not unreasonably big.
	if {[string length $data] <= 1800} {
		# Note: Barcode Scanner app for Android does not work with black border (-box is for L and R black mattes, -bind is for T and B).
		# tzint::Encode bits | eps | svg | xbm varName data ?-option value ...?
		tzint::Encode xbm qr_xbm $data -symbology qrcode -bind false -box false -border 4 -scale 4

		# Note that increasing the scale makes encoding significantly slower! :(  Maybe can scale using the image create command instead?  -zoom?
	}

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


# The clipboard_updater routine tries to synchronise the CLIPBOARD and PRIMARY selections (cos that's always been an annoyance, IMO).  Actually, I don't think this should be necessary: it's better if we claim ownership of both those selections, and re-gain them if we lose them (preserving the contents of what the other client just put there). Of course, running multiple such programs will result in squabbles and bad behaviour.

# Also, should we own one (or both) of the selection units (as xclipboard does, I believe)?  I think we probably should.  Would need [selection own] and to define a command usable for [selection handle ...].  Note that if we do own a selection, we should not bother getting that selection for the current clipboard_updater run!

# Note that we can't prevent ownership of a selection from being taken away from us (but we can periodically/frequently take it back! - ideally we'd detect if we lost it, copy what the other program added into our main clipboard variable, and take ownership again so that the effect is the same).

proc clipboard_updater {} {
	# Save a copy of the old values so we can detect changes:
	set ::clipboard_old_selection_contents $::clipboard_selection_contents
	set ::primary_old_selection_contents $::primary_selection_contents

	set something_changed false

	# Grab a copy of the current clipboard and primary selections:
	# (We have to copy it in order to display it in the GUI - no -textvariable possible here)
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

	# TODO: what about the SECONDARY selection? IIUC, it's basically never used.

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


#clipboard_updater


# When starting up, check for existing data in CLIPBOARD and PRIMARY, and make sure those are preserved.
# If both have a value, choose one? Concatenate? Choose the longer one?  Just choose CLIPBOARD?
# TODO: catch, perhaps?
catch {set_clipboard_value [selection get -selection CLIPBOARD]}
catch {set_clipboard_value [selection get -selection PRIMARY]}

reown_selection PRIMARY
reown_selection CLIPBOARD


