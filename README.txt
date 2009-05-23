DeskNerd:
A collection of scripts and components designed for used with the Ion window manager on Linux.

Ion's tabbed, pane-oriented way of managing windows and workspaces is wonderful, but the default 
statusbar is a little spartan.  DeskNerd provides some handy programs to pop in the systray(s) in 
the statusbar, a mechanism for boosting the CPU and IO priority of the window that has focus, and 
whatever other things I can think of and implement.

Sorry, but it's Linux-only at present: it depends on things like the /proc filesystem layout and file format, the calling 
syntax for ps(1), the ionice utility, and possibly also the number of jiffies per second (USER_HZ, the kernel software timer 
frequency).

Started CME 2009-05-ish.


References:

Tuomo Valkonen's excellent window manager for the X Window System:
http://modeemi.fi/~tuomov/ion/

The Tcl/Tk home page:
http://www.tcl.tk/

The excellent Tcler's wiki (Tcliki?!):
http://wiki.tcl.tk/
