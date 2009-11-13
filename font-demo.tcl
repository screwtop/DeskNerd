set pangram "Amazingly few discotheques provide jukeboxes."
#set pangram {"Who am taking the ebonics quiz?", the prof jovially axed.}
#set pangram {Watch "Jeopardy!", Alex Trebek's fun TV quiz game.}
#set pangram "Jackdaws love my big sphinx of quartz."
pack [text .t -wrap none] -fill both -expand 1
set count 0
set tabwidth 0
foreach family [lsort -dictionary [font families]] {
    .t tag configure f[incr count] -font [list $family 10]
    .t insert end ${family}:\t {} "$pangram\n" f$count
    set w [font measure [.t cget -font] ${family}:]
    if {$w+5 > $tabwidth} {
        set tabwidth [expr {$w+5}]
        .t configure -tabs $tabwidth
    }
}
