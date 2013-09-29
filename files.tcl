#!/usr/bin/wish

# Just implement the Files menu...
# TODO: make this modular somehow - maybe just implement the menu, and then attach that however in a parent application.
# Then again, maybe it's a bit silly having each menu require a separate wish instance.  We could have one script running on one wish instance with multiple windows.  What about refresh timing, though?

# TODO: pop-up menus for files and directories:
#  - Copy Path/Filename
#  - New Shell Here
#  - Encrypt
#  - Checksum
#  - Properties/Get Info
#  - Copy Path/Filename
#  - Copy, Cut, Paste?
#  - Rename
#  - Delete (if it can be done safely)
# Also, drag and drop?


wm title . {DeskNerd_Files}
wm overrideredirect . 1

source {Preferences.tcl}
option add *TearOff 0
. configure -background $statusbar_background_colour
set file_manager thunar	;# TODO: should go into global or per-app prefs?
catch {source ~/.desknerd/files.tcl}

pack [menubutton .files      -text "Files" -menu .files.menu -relief groove]
#pack [menubutton .files      -text "Files" -menu .files.menu -relief groove -background $statusbar_background_colour -foreground $statusbar_foreground_colour]


# Basic menu structure:

menu .popup_menu
	.popup_menu add command -label {Close}           -command {exit}
bind . <3> "tk_popup .popup_menu %X %Y"

# Hmmmmm, most important things at the top, or at the bottom?  It should really change depending on whether the statusbur is at the top or the bottom of the screen!
menu .files.menu
	# TODO: Also would be sensible to have sub-menus for things like user-defined favourites/shortcuts/bookmarks, recently-used items, etc.  Maybe they should even go in their own top-level menu, actually.  Perhaps these should be stored in a configuration/preferences database somewhere...
	# Actually, maybe only put "~", "/", and the user's favourites in the top-level menu, and include a submenu for 
	.files.menu add command -label "/commerce/infosci/Users/cedwards" -command "exec $file_manager /commerce/infosci/Users/cedwards &"
	.files.menu add command -label "/mnt/info-nts-12/dbcourses/Info212/www" -command "exec $file_manager /mnt/info-nts-12/dbcourses/Info212/www &"
	.files.menu add separator
	.files.menu add cascade -menu [menu .files.menu.recent] -label {Recently Used}
	.files.menu add cascade -menu [menu .files.menu.mounts] -label {Mount Points}
	.files.menu add cascade -menu [menu .files.menu.labels] -label {Available Volumes}
	.files.menu add separator
	# Special filesystem points to include at the top:
	.files.menu add command -label "Filesystem root (/)" -command "exec $file_manager / &"
	.files.menu add command -label "Home folder (~)" -command "exec $file_manager $env(HOME) &"

# For the file browser menu, we probably want a pseudo-root for each mount point.  I'm not sure if Tcl's "file" API/command allows us to determine mount points, since everything is a local/normal mount, so "/" is the only "volume" it detects.  If we go Linux-only, we can maybe parse /proc/mounts to find these out (filtering out system mount points like /dev/shm, perhaps).
# The list might need to be refreshable; ideally, would auto-refresh.
# TODO: would be kinda nice to be able to copy and/or drag-n-drop the path from the menu into other applications, e.g. in a file requester/dialog or a shell session.






# TODO: put this (and maybe the above) in a proc, to make refreshing the mount list easier.

# Grab other filesystems according to mount points:

# Open and read mountlist from /proc:
set mounts_file [open /proc/mounts]
set mounts [read $mounts_file]
close $mounts_file

## Split into records on newlines
set mount_records [split $mounts "\n"]

## Iterate over the records
# TODO: reverse order, so user mounts come first?!
foreach rec $mount_records {

	if {$rec == ""} {break}

   ## Split into fields on space
   set fields [split $rec " "]

   ## Assign fields to variables and print some out...
#   lassign $fields device path type options x y	
	set device  [lindex $fields 0]
	set path    [lindex $fields 1]
	set type    [lindex $fields 2]
	set options [lindex $fields 3]

	puts "$path <- $device ($type)"

	# Ignore certain mount points:
	if {$path == "/"} {puts "$path"}

	# Use $path for unique identifier, as $device isn't necessarily unique (e.g. "tmpfs"):
	# Oh, in fact neither is $device ("/" has "rootfs" and "/dev/root", for example.)
	# Also, if a device or path contains a ".", it will cause the Tk path to be invalid.
#	menu .files.menu.$path-[string map {. -} $device]
	puts "path = $path"
	.files.menu.mounts add command -label $path -command "exec $file_manager $path &"
}


# Place available volume labels into the labels menu:
foreach label [lsort [glob -directory /dev/disk/by-label -tails *]] {
	# TODO: might need to mount it too! - add capability.  If auto-mounted, it'll likely be in /media/$label.
	# It's also quite possible it'll be mounted already in another location.  Examining the by-label symlinks could be one way to identify the real mount point.
	.files.menu.labels add command -label $label -command "exec $file_manager $/media/$label &"
}

menu .files.menu.test


source reset_window.tcl
reset_window

