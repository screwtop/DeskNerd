# Nifty demo from the Tcl wiki
pack [button .b -text "The Button" -command exit]
  wm overrideredirect . 1

  bind .b <1> {
    set iX0 [expr %X-[winfo rootx .b]]
    set iY0 [expr %Y-[winfo rooty .b]]
    set bMoved 0
  }

  bind .b <B1-Motion> {
    wm geometry . +[expr %X-$iX0]+[expr %Y-$iY0]
    set bMoved 1
  }

  bind .b <ButtonRelease-1> {
    if { $bMoved } break
  }
