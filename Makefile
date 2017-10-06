.PHONY: all
all: getloadavg.so
	@echo 'Run "make install" to install.'

.PHONY: install
install:
	cp  -v  -f  reset_window.tcl clipboard.tcl cpu.tcl files.tcl io.tcl launcher.tcl memory.tcl time.tcl  /usr/local/DeskNerd
	cp  -v  -n  Preferences.tcl  /usr/local/DeskNerd

.PHONY: clean
clean:
	rm -f *.o *.so

getloadavg.so: getloadavg_wrap.o
	gcc -shared getloadavg_wrap.o -o getloadavg.so

getloadavg_wrap.o: getloadavg_wrap.c
	gcc -fpic -c getloadavg_wrap.c -I /usr/include/tcl

getloadavg_wrap.c: getloadavg.i
	swig -tcl8 getloadavg.i
