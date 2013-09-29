.PHONY: all
all:
	echo 'This is all Tcl scripts; nothing to build.  "make install" to install.'

.PHONY: install
install:
	cp  -v  -f  reset_window.tcl clipboard.tcl cpu.tcl files.tcl io.tcl launcher.tcl memory.tcl time.tcl  /usr/local/DeskNerd
	cp  -v  -n  Preferences.tcl  /usr/local/DeskNerd
