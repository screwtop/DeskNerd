# From http://wiki.tcl.tk/10874

# NOTE: does not work with negative numbers!

# call e.g.
# format_base2_unit 1234 {%7.2f}
# (total width of 7 needed here: "-234.67")

proc format_base2_unit {value format} {
	if {$value < 1024} {
		format "$format" $value
	} else {
		set scale [expr {([string length $value] - 1) / 3}]
		format "$format %s" [expr {$value / pow(1024,$scale)}] [lindex [list {} Ki Mi Gi Ti Pi Ei Zi Yi] $scale]
	}
}


proc format_base10_unit {value format} {
	if {$value < 1000} {
		format "%s" $value
	} else {
		set scale [expr {([string length $value] - 1) / 3}]
		format "$format %s" [expr {$value / pow(1000,$scale)}] [lindex [list {} K M G T P E Z Y] $scale]
	}
}


# TODO: conversion functions for specific multipliers.  Maybe store a table of the data, a la:
# { {K 3} {M 6} {G 9} ... }


