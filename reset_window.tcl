# A bit of fiddling to get layout right in systray (see also overrideredirect at start):
# (not sure what delay to use; might be system-dependent (or even window-dependent, in which case should we parameterise for delay?))

proc reset_window {} {
	after 100 {
		wm minsize . [winfo width .] [winfo height .]
		wm withdraw .; wm overrideredirect . 0; wm deiconify .
	}
}

