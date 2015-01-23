# Various alert routines for different reasons/severity.  Could maybe use different beep patterns.  Don't forget that there's already a Tcl "error" command to avoid.
proc alert {message} {
        puts stderr "\x1b\[31;1m >> ALERT: ${message}\x1b\[0m"; flush stderr
}

proc warning {message} {
        puts stderr "\x1b\[33;1m >> WARNING: ${message}\x1b\[0m"; flush stderr
}

proc debug {message} {
        if {$::debugging} {puts stderr "\x1b\[35;1m >> DEBUG: $message\x1b\[0m"; flush stderr}
}

