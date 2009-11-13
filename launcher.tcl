#!/usr/bin/wish

# TODO: an InstaLauncher to implement single-application launcher buttons a la Windows Quick Launch.  It would take command-line arguments identifying the label, icon (I guess) and command to execute when clicked.  Not sure about how to deal with arranging the buttons - drag n drop prolly out of the question!  NOTE: for icons, see the "options" manual, -bitmap and -compound in particular.

#package require tile	;# tile

wm title . {DeskNerd_Launcher}

source {Preferences.tcl}
#option add *TearOff 0
#tile::setTheme clam	;# tile
#ttk::?? clam
. configure -background $statusbar_background_colour

#pack [ttk::menubutton .launch -text "Launch" -menu .launch.menu]	;# tile
pack [menubutton .launch      -text "Launch" -menu .launch.menu -relief groove]
#pack [menubutton .files      -text "Files" -menu .launch.menu -relief groove -background $statusbar_background_colour -foreground $statusbar_foreground_colour]


# Basic menu structure:

menu .popup_menu
	.popup_menu add command -label {Close} -background orange -command {exit}
bind . <3> "tk_popup .popup_menu %X %Y"

# Dummy menu items for now...
menu .launch.menu
	.launch.menu add command -label "Shell" -command {exec urxvt -e bash -l &}
	.launch.menu add command -label "GVim" -command {exec gvim &}
	.launch.menu add separator
	.launch.menu add cascade -menu [menu .launch.menu.audio] -label {Audio}
		# Audacity, Ardour, jack, Pure Data

	.launch.menu add cascade -menu [menu .launch.menu.graphics] -label {Graphics}
		.launch.menu.graphics add command -label "GIMP" -command {exec gimp &}
		.launch.menu.graphics add command -label "Inkscape" -command {exec inkscape &}
	.launch.menu add cascade -menu [menu .launch.menu.network] -label {Network}

	.launch.menu add cascade -menu [menu .launch.menu.publishing] -label {Publishing}
		.launch.menu.publishing add command -label "Adobe Reader" -command {exec acroread &}

	.launch.menu add cascade -menu [menu .launch.menu.settings] -label {Settings}
		.launch.menu.settings add command -label "Gnome Control Centre" -command {exec gnome-control-center &}
		.launch.menu.settings add command -label "Firewall (system-config-firewall)" -command {exec system-config-firewall &}
		.launch.menu.settings add command -label "Firewall (firestarter)" -command {exec firestarter &}
		.launch.menu.settings add command -label "Printer" -command {exec system-config-printer &}

	.launch.menu add cascade -menu [menu .launch.menu.utilities] -label {Utilities}
		.launch.menu.settings add command -label "File Roller" -command {exec file-roller &}
	.launch.menu add cascade -menu [menu .launch.menu.video] -label {Video}


	.launch.menu add separator
	.launch.menu add command -label "Browse /" -command {exec thunar / &}
	.launch.menu add command -label "Browse ~" -command "exec thunar $env(HOME) &"

# Just thinking: under Ion, ad-hoc launching of applications using point-and-click is probably a rare event: we have a lot of stuff launch at start of session, and other stuff is mostly shells and editors, which can easily be launched from the Ion "Run" menu, or from a new ad-hoc shell (the latter beingnot so good in terms of resource use, but nice to be able to see the application's standard output).  For applications with a well-defined target workspace/frame, can/should we jump to those automatically?  Prolly appropriate.  In fact, duh, just set the jump winprop!  :)

