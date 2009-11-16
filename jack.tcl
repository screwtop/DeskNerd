#!/usr/bin/expectk

# A basic JACK Audio Connection Kit control systray utility for DeskNerd.
# Will provide a popup menu (or menus) for managing port connections, viewing JACK process status info, etc.  See Documentation/Development/JACK.txt for design details.
# Actually, it might be easier to make calls to jacklib directly.  Not something I've set up for Tcl before, but AFAICT it should be fairly straightforward.  See the separate TclJACK project.

# TODO: having Tcl's pattern matching and list handling will enable some nice features, I think:
# [ ] Connecting all ports for a client to another client (mapping 1:1).
# [ ] Disconnecting all MPlayer instances (mplayer includes the PID in its JACK client name, but we can do a pattern match).
# [ ] Disconnecting all output ports for a client.
# ...
# [ ] Perhaps most significantly, we can choose a playback port that we want to monitor (e.g. system:playback_1 and 2 for the main soundcard outputs), query to find all JACK output ports that connect to it, and connect those to this program, so it will display the effective output signal of the entire system!  I'd wondered how I was going to do that.


# (We're going to be using expect features, to run expectk, not wish.)


wm title . {DeskNerd_JACK}
set application_name {DeskNerd JACK Audio Manager}



# The main popup menu:
pack [menubutton .jack  -text "JACK"  -menu .jack.menu  -relief groove]

# Program management menu on right-click:
menu .popup_menu
	# TODO: $application_name
	.popup_menu add command -label {Close}           -command {exit}
bind . <3> "tk_popup .popup_menu %X %Y"

menu .jack.menu
	# Program label menu item first:
	.jack.menu add command -label $application_name -background grey
	.jack.menu add separator
	# Then any info/status non-interactive items:

	.jack.menu add separator
	.jack.menu add command -label "List Ports to Console" -command {puts [get_jack_port_list]}



# Various procedures to gather JACK state data through the jack_* commands.

# Get a list of JACK ports.  All ports, or have separate procs for playback and capture ports?  Might be nice to only call jack_lsp once and gather as much information as possible, for efficiency (assuming starting new process is more expensive than piping and processing a little more text).
proc get_jack_port_list {} {
	# Run the jack_lsp command to get port information...
	# Might as well use expect for this, I think.
	log_user 0
#	spawn jack_lsp
	spawn jack_lsp -A -L -l -p -c
	while true {
		# On naming of JACK ports:
		# I assume colons are not allowed in JACK client or port names (only as the separator between these).
		# Spaces are allowed (mplayer uses them by default).  Are leading or trailing spaces permitted?  I'll assume not.
		# Are tabs permitted in client/port names?
		# Are leading digits permitted in client/port names?

		# Expect will of course slurp in as much text as possible, so we need to explicitly match line-break characters here.
		expect {
			# Whooph, regular expressions!
			# Hmm, the very first port listed will not be preceded by a newline, but every other one will.  Pain.
			-re {[\r\n]*([^\t \r\n][^:]+):([^\r\n]+)} {
			#	puts "<<$expect_out(0,string)>>"	;# For debugging the pattern matching.
				set jack_subsystem_name $expect_out(1,string)
				set jack_port_name $expect_out(2,string)
				puts "Found port '$jack_subsystem_name' '$jack_port_name'"
				# The port may have additional data, so do another expect here:
				# Boh, it might be easier to do all the pattern matching at the same level.  Maybe line-based processing would be easier after all...
			}
					-re {[\r\n]+   ([^\r\n:]+):([^\r\n]+)} {puts " -> alias: '$expect_out(1,string)' '$expect_out(2,string)'"}
					-re {	port latency = ([0-9]+) frames} {puts " -> port latency: $expect_out(1,string)"}
					-re {	total latency = ([0-9]+) frames} {puts " -> total latency: $expect_out(1,string)"}
					# Is it possible for a port to have no properties?  If so, would jack_lsp emit a "properties:" line at all?
					-re {	properties: ([^\r\n]+)} {puts " -> total latency: $expect_out(1,string)"}



				#	-re {[\r\n]+	([^\r\n:]+):([^\r\n]+)} {
				#		puts " -> other property: $expect_out(0,string)"
						# And if we found a "properties" list, gather the individual property values:
				#	}
			eof {break}
		}

	}
	# Return a list?
}


# Maybe an easier one would be for connecting two JACK ports.
# Would ports be identified simply by name, or by a <client_name, port_name> tuple?
# Since we can only connect ports of clients of the same JACK server, we don't need to worry about qualifying the names further with the server name (I think).
# TODO: figure out quoting issues.  JACK port names may contain spaces, colons, square brackets, ...  What kind of quotation marks to use in the [open] command?
# Literal port names containing "[]$" etc will obviously need to be escaped or written in curly braces for Tcl.
# TODO: error handling?
# <<ERROR b not a valid port>>
# <<child process exited abnormally>>
# Also, watch for naming conflicts here if in a Tcl environment that will try to call system command as well ("jack_connect" == "jack_connect"!).
proc jack_connect {source_port sink_port} {
	set input [open "|jack_connect \"$source_port\" \"$sink_port\"" r]
	set content [split [read $input] \n]
	close $input
	puts $content
	# TODO: return something useful?
}


# And similarly for disconnecting:
proc jack_disconnect {source_port sink_port} {
	set input [open "|jack_disconnect \"$source_port\" \"$sink_port\"" r]
	set content [split [read $input] \n]
	close $input
	puts $content
	# TODO: return something useful?
}
# Could imagine doing jack_disconnect with pattern matching to avoid having to look up and list the sink port name(s) for example.

