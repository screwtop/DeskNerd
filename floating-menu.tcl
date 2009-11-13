# Demo/prototype for an application launcher, initially adapted from draggable floating button demo I found on the Tcl wiki somewhere.
# CME 2009-05-14

# Can we give the menu button its own context/pop-up menu???  Yes, we can. :)

# What menus do we want?  An application launcher, an application/document switcher, a window manager workspace switcher (pager), a filesystem/volume browser, ...?
# Perhaps additional menus for kinda desk accessory items: dictionary/thesaurus, calendar, calculator, Google search, Wikipedia search, etc.
# 
# Filesystem browser should have certain top-level items: "/", "~", and an entry for each mount point on the system.  How easily can we identify these in Tcl?
# Filesystem browser should also provide a pop-up menu for files, folders, links, whatever, e.g. copy, paste, rename, properties/info, view (with ...), etc.
# TODO: an orientation switcher (horizontal/vertical menu arrangement).

wm title . {Launcher}

# Drag thing: a frame with a "move arrows" icon in it, or just a button?
#pack []
pack [button .move -text "<move>"] -side left

# First test button
#pack [button .b -text "Exit" -command exit]

pack [menubutton .launcher   -text "Launcher" -menu .launcher.menu] -side left
pack [menubutton .switcher   -text "Switcher" -menu .switcher.menu] -side left
pack [menubutton .workspaces -text "Workspaces" -menu .workspaces.menu] -side left
pack [menubutton .files      -text "Files" -menu .files.menu] -side left

wm overrideredirect . 1


proc rotate_menus {} {
	# not sure...
}




# TODO: make the whole window draggable, or just use the drag handle button/frame/grip?  Slightly weird things happen when you drag while a menu is open (especially if the mouse moves through the menu that's left floating).
bind . <1> {
	set iX0 [expr %X-[winfo rootx .move]]
	set iY0 [expr %Y-[winfo rooty .move]]
	set bMoved 0
}

bind . <B1-Motion> {
	wm geometry . +[expr %X-$iX0]+[expr %Y-$iY0]
	set bMoved 1
}

bind . <ButtonRelease-1> {
	if { $bMoved } break
}

bind . <3> "tk_popup .popup_menu %X %Y"




# Basic menu structure:

menu .popup_menu
	#.popup_menu add cascade -menu [menu .popup_menu.test]    -label {Test}
	.popup_menu add command -label {Rotate} -command {rotate_menus}
	.popup_menu add command -label {Exit}           -command {exit}

menu .launcher.menu
	# Audio, CAD, Network, Settings, Run..., etc.
	.launcher.menu add command -label {Run...} -command {run}
	.launcher.menu add separator
	.launcher.menu add command -label {Exit} -command {exit}
menu .switcher.menu
menu .workspaces.menu
menu .files.menu
#	.files.menu add command -label {Nothing} -command {}


# For the file browser menu, we probably want a pseudo-root for each mount point.  I'm not sure if Tcl's "file" API/command allows us to determine mount points, since everything is a local/normal mount, so "/" is the only "volume" it detects.  If we go Linux-only, we can maybe parse /proc/mounts to find these out (filtering out system mount points like /dev/shm, perhaps).
# The list might need to be refreshable; ideally, would auto-refresh.
# TODO: would be kinda nice to be able to copy and/or drag-n-drop the path from the menu into other applications, e.g. in a file requester/dialog or a shell session.

# Special filesystem points to include at the top:
.files.menu add command -label "/" -command {exec thunar / &}
.files.menu add command -label "~" -command "exec thunar $env(HOME) &"


# TODO: Also would be sensible to have sub-menus for things like user-defined favourites/shortcuts/bookmarks, recently-used items, etc.  Maybe they should even go in their own top-level menu, actually.  Perhaps these should be stored in a configuration/preferences database somewhere...
.files.menu add command -label "/commerce/infosci/Users/cedwards" -command {exec thunar /commerce/infosci/Users/cedwards &}
.files.menu add command -label "/mnt/info-nts-12/dbcourses/Info212/www" -command {exec thunar /mnt/info-nts-12/dbcourses/Info212/www &}

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
	.files.menu add command -label $path -command "exec thunar $path &"
}



menu .files.menu.test

