#!/usr/bin/env tclsh
#!/usr/bin/tclsh8.5

package require Expect
package require Tk

# Disk I/O performance monitor graph based on percent utilisation (and queue length).
# Uses a continuously-running iostat process connected via expect to gather data.
# For monitoring multiple devices, it would be sensible to have this script implement multiple meters, so that only one Tcl/Tk interpreter needs to be used, and also only one iostat process.

# TODO: rework menus to support multiple devices.
# TODO: add tooltips and/or labels in the meters themselves somehow perhaps.
# TODO: support multiple drives.  Perhaps use TclRAL for storing the statistics within this program (or just pass them around as parameters).
# TODO: refactor this!  Most of the gauge code should be defined oncewheres.
# TODO: figure out how to handle multiple meters with different scales and colour mappings (%util has an upper bound, queue length does not).


wm overrideredirect . 1
wm title . {DeskNerd_IOMeter}

source {Preferences.tcl}
#. configure -background $statusbar_background_colour
# Actually, tear-off menus could be fine and handy for meters like this.
# NOTE: changing the TearOff capability changes the number of items in menus!  Fragile!
option add *TearOff 1
# TODO: fixed-width font might be sensible for the informative tooltip-menus.
option add *font font_sans



set field_names {reads_completed reads_merged sectors_read milliseconds_reading writes_completed writes_merged sectors_written milliseconds_writing queue_length milliseconds_io weighted_milliseconds_io discards_completed discards_merged sectors_discarded milliseconds_discarding}


# List of devices to monitor:
# You can include additional devices like sr0 here, which otherwise don't show up.
# iostat also lets you monitor individual partitions.
# Getting a list from /sys/block might also be effective.
# It would be nice to let iostat display everything, but how do we know what meter gauge's we'll need?
#set device_names {sda sr0}	;# Likely minimum on modern systems.
set device_names {sda}	;# For testing
#set device_names {}
# User preferences/settings file:
catch {source ~/.desknerd/io.tcl}

source util.tcl

if {![info exists device_names]} {
	set device_names {sda hda sr0}	;# Probably a fair stab
}
#set device_names {sda sdb sdc sdd sde sdf hda sr0 sr1}
#set device_names {}

# This works, but with no meters the script will fail.
#set device_pattern {([hs][dr][a-z]?[0-9]*)}	;# Default: match any.
#if {[info exists device_names]} {
#	if {$device_names != {}} {
#		# Names specified; use them:
#		set device_pattern "([join $device_names {|}])"
#	}
#}

set device_pattern "([join $device_names {|}])"


set indicator_width 8
set indicator_height 20


# Pop-up menu for convenient exiting:
# TODO: add switching between performance metrics (%util, queue length, I/Os per second, etc.), and perhaps also devices.
menu .popup_menu
	.popup_menu add command -label {Close} -background orange -command {exit}
bind . <3> "tk_popup .popup_menu %X %Y"


# A sort of interactive tool-tip, implemented as a menu.
# TODO: make the labels more maintainable, perhaps storing the strings in a relation.
# TODO: use a fixed-width font and aligned numbers for better readability.
menu .info_menu
	# TODO: include device name and perhaps other info (make, model, capacity, ...) as well.
	.info_menu add command -label {DeskNerd Disk I/O Meter} -command {}
	.info_menu add separator
	.info_menu add command -label "Device: ??" -command {}
	.info_menu add separator
	.info_menu add command -label "% Util.: ??" -command {}
	.info_menu add command -label "Queue: ??" -command {}
	.info_menu add command -label "IO/s: ??" -command {}
	.info_menu add command -label "MB/s: ??" -command {}
	.info_menu add separator
	.info_menu add command -label "Reads/s: ??" -command {}
	.info_menu add command -label "Writes/s: ??" -command {}
	.info_menu add separator
	.info_menu add command -label "Read MB/s: ??" -command {}
	.info_menu add command -label "Write MB/s: ??" -command {}
# Could be invoked by mouse-over or left click perhaps.
bind . <1> "tk_popup .info_menu %X %Y"

# Procedure to update the information in the "tooltip" menu.  Ideally this would only be run when necessary, e.g. when actually invoking the menu, but I'm not sure if that's possible.  Actually, having it called from the main expect loop is good in that you can watch the numbers in realtime changing within the menu.  I like.
proc update_tooltip_menu {device util depth reads writes read_mb write_mb} {
	set i 2
	.info_menu entryconfigure [incr i] -label "Device: $device"
	incr i
	.info_menu entryconfigure [incr i] -label "Util.: [expr {round($util * 100)}] %"
	.info_menu entryconfigure [incr i] -label "Queue: $depth"
	.info_menu entryconfigure [incr i] -label "IO/s: [format %0.0f [expr {$reads + $writes}]]"
	.info_menu entryconfigure [incr i] -label "MB/s: [format %0.1f [expr {$read_mb + $write_mb}]]"
	incr i
	.info_menu entryconfigure [incr i] -label "Reads/s: [format %0.0f $reads]"
	.info_menu entryconfigure [incr i] -label "Writes/s: [format %0.0f $writes]"
	incr i
	.info_menu entryconfigure [incr i] -label "Read MB/s: [format %0.1f $read_mb]"
	.info_menu entryconfigure [incr i] -label "Write MB/s: [format %0.1f $write_mb]"
}



# Set up UI:
# -relief groove -border 2
frame .gauges -relief sunken -border 1 -padx 1 -pady 1 -background black
grid .gauges

foreach device $device_names {
#	puts $device
	# Bevelled container frame:
	pack [frame .gauges.$device  -width $indicator_width  -height $indicator_height  -relief sunken  -borderwidth 1 -background black] -side left
	# Meter gauge itself is also done as a frame
	place [frame .gauges.${device}.meter     -width [expr {$indicator_width-2}] -height 0  -relief flat -borderwidth 0 -background #00FF00] -anchor sw -x 0 -y [expr {$indicator_height-2}]

}


#.io_gauge.meter configure -height 0
# Hmm, with a height of 0, it's still 1 pixel high?!  I guess there's no sense in having an invisible frame...
# Also, yep, height-2 is the maximum height.

proc io_gauge_update {device value} {
	global indicator_height
	# We're assuming value is a 0..1 factor.
	# Colour thresholds?  Overkill to store these in a data structure somewhere?
	# Green|Red?  Green|Orange|Red?  Green|Yellow|Orange|Red?
	# Note: yellow is not terribly visible against the default pale grey background.
	# Perhaps a fixed black background would be appropriate.
	# For % util.:
	# {{0.5 green} {0.75 yellow} {0.90 orange} {1.0 red}}
	if     {$value >= 0.90} then {set gauge_colour red} \
	elseif {$value >= 0.75} then {set gauge_colour orange} \
	elseif {$value >= 0.50} then {set gauge_colour yellow} \
	else                         {set gauge_colour #00FF00}

	# For queue length: < 1 is OK, more than 2 is def bad.  Give a bit of leeway (1.01 is close enough to 1 to be left green).
	# {{0.35 green} {0.5 orange} {1.0 red}}
#	if     {$value >= 0.5} then {set gauge_colour red} \
#	elseif {$value >= 0.35} then {set gauge_colour orange} \
#	else                         {set gauge_colour green}

	.gauges.${device}.meter configure -height [expr {$value * ($indicator_height-2)}] -background $gauge_colour
}


# Ping to systray:
source reset_window.tcl
reset_window


proc init {} {
	global device_names last_ms field_names last delta
	set last_ms 0
	foreach device $device_names {
		foreach field_name $field_names {
			set last($device,$field_name) 0
		}
	#	set delta($device,ms) 0
	}
}



# TODO: final refactoring to properly support passing the device name as arg:
# Or maybe the ms and last_ms can be done in the main loop?
proc read_stats {device} {
	global field_names last $device
#	set ms [clock millis]
	set stats [slurp /sys/block/$device/stat]
	
#	puts $stats

	# TODO: maybe treat timestamp as a field so that it'll get added to the delta array automatically.
	# TODO: store separate ms and last_ms for each device?!
#	set ms_delta [expr {$ms - $last_ms}]
#	set delta($device,ms) $ms_delta
#	puts "time delta = $ms_delta ms"

	lassign $stats {*}$field_names
#	lassign $stats reads_completed reads_merged sectors_read milliseconds_reading writes_completed writes_merged sectors_written milliseconds_writing milliseconds_io weighted_milliseconds_io discards_completed discards_merged sectors_discarded milliseconds_discarding


#	foreach f $field_names {
#		puts "$f = [set $f]"
#	}
	
	# Compute deltas
	foreach field_name $field_names {
		set delta($device,$field_name) [expr {[set $field_name] - $last($device,$field_name)}]
		set last($device,$field_name) [set $field_name]
	}
	
#	parray delta
	
	# Compute % read time, % write time, and total % utilisation:
	# Well, maybe as decimals, not percentages. Convert to % for display, perhaps.
	set read_utilisation [expr {$delta($device,milliseconds_reading) / double($::ms_delta)}]
	set write_utilisation [expr {$delta($device,milliseconds_writing) / double($::ms_delta)}]
	set total_utilisation [expr {$read_utilisation + $write_utilisation}]
#	puts "Utilisation: read: [format %0.2f $read_utilisation]%, write: [format %0.2f $write_utilisation]%, total: [format %0.2f $total_utilisation]%"
	
	# Compute I/O operations per second:
	set reads_per_second [expr {$delta($device,reads_completed) / ($::ms_delta / 1000.0)}]
	set writes_per_second [expr {$delta($device,writes_completed) / ($::ms_delta / 1000.0)}]
	set total_iops [expr {$reads_per_second + $writes_per_second}]
#	puts "IOPS: read: [format %0.0f $reads_per_second] IO/s, write: [format %0.0f $writes_per_second] IO/s, total: [format %0.0f $total_iops] IO/s"
	
	# Compute throughput (MiB/s):
	set read_throughput [expr {$delta($device,sectors_read) * 512 / 1048576.0 / ($::ms_delta / 1000.0)}]
	set write_throughput [expr {$delta($device,sectors_written) * 512 / 1048576.0 / ($::ms_delta / 1000.0)}]
	set total_throughput [expr {$read_throughput + $write_throughput}]
#	puts "Throughput: read: [format %0.2f $read_throughput] MiB/s, write: [format %0.2f $write_throughput] MiB/s, total: [format %0.2f $total_throughput] MiB/s"
	
	# No delta for this one:
	# Moreover, no data neither?!
#	puts "Queue length: $queue_length"
	
	# Return the data as a dict?
	foreach field {read_utilisation write_utilisation total_utilisation reads_per_second writes_per_second total_iops read_throughput write_throughput total_throughput queue_length} {
		dict set data $field [set $field]
	}
	return $data
}


init

every 1000 {
	set ::ms [clock millis]
	# TODO: maybe treat timestamp as a device array field so that it'll get added to the delta array automatically. Store separate ms and last_ms for each device?!
	set ::ms_delta [expr {$::ms - $::last_ms}]
	set ::last_ms $::ms
	
#	puts "time delta = $::ms_delta ms"
	
	set device sda	;#  TODO: do it for all $device_names
#	set delta($device,ms) $ms_delta
	set data [read_stats $device]
	io_gauge_update $device [dict get $data total_utilisation]
	update_tooltip_menu $device [dict get $data total_utilisation] [dict get $data queue_length] [dict get $data reads_per_second] [dict get $data writes_per_second] [dict get $data read_throughput] [dict get $data write_throughput]
	# $read_megabytes_per_second $write_megabytes_per_second
}

# Hopefully that'll prove more stable than the old iostat variant.

