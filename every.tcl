# "every" abstraction/procedure for periodic doing of stuff. (Nice idiom from http://wiki.tcl.tk)
proc every {ms body} {
	eval $body
	after $ms [info level 0]
}
