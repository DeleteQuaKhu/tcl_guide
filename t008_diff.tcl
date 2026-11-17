# src/spike/t008_diff.tcl  -  compare two T-029 state snapshots (task T-029).
#
# Runs in plain tclsh OR inside HyperView; it touches no session, only two text files.
#   1. Owner: source src/spike/t008_state.tcl with TAG = broken, switch the contour on by hand,
#      source it again with TAG = working, then source THIS file.
#   2. It prints "DIFF name: broken=<v> working=<v>" for every value that differs and "SAME <n>
#      lines" for the rest, and writes src/02_working/t008_diff.txt.
#   3. Send t008_diff.txt and the two state files.
# BUILD / BUILD-TAG / TIME / STATE FILE lines are ignored: they name the copy and the moment, not
# the state. A key present in only one file is printed with "(missing)" on the other side, because a
# getter that answers in one run and raises in the other IS the difference.
# Tcl 8.5 only: no tcllib, no package require.

# --- the values to edit by hand -------------------------------------------------------
# GLOBALS on purpose (::d8_*): sourcing this file from a proc in another wrapper must still see
# them (T-029).
# Folder holding the two state files and receiving t008_diff.txt. Empty = src/02_working next to
# this file (a test points it elsewhere).
if {![info exists ::d8_dir]} { set ::d8_dir "" }
# Explicit paths, used only when set (a test does not need them).
if {![info exists ::d8_broken]} { set ::d8_broken "" }
if {![info exists ::d8_working]} { set ::d8_working "" }

namespace eval ::d8 {
    variable fd ""
    variable real "puts"
}

proc ::d8::emit {text} {
    variable real
    variable fd
    if {$real ne "" && [llength [info commands $real]]} { $real $text } else { puts $text }
    if {$fd ne ""} { catch {chan puts $fd $text} }
    return
}

# One state file as a dict key -> value. The ignored lines are the ones that only name the copy or
# the moment; a line that is not "key = value" is kept as a note under its own text so it is not
# lost silently.
proc ::d8::read_state {path} {
    set out [dict create]
    if {[catch {open $path r} fh]} {
        return -code error [format "cannot read %s" $path]
    }
    while {[gets $fh line] >= 0} {
        set t [string trim $line]
        if {$t eq ""} { continue }
        if {[regexp {^(BUILD|BUILD-TAG|TIME|STATE FILE)\M} $t]} { continue }
        if {[regexp {^([^=]+?)[ \t]*=[ \t]*(.*)$} $t -> k v]} {
            dict set out [string trim $k] [string trim $v]
            continue
        }
        dict set out $t "-"
    }
    catch {close $fh}
    return $out
}

# Every key of both files, once, in a stable order.
proc ::d8::keys {a b} {
    set out [list]
    foreach k [dict keys $a] { lappend out $k }
    foreach k [dict keys $b] {
        if {[lsearch -exact $out $k] < 0} { lappend out $k }
    }
    return [lsort $out]
}

proc ::d8::main {broken working} {
    set a [::d8::read_state $broken]
    set b [::d8::read_state $working]
    ::d8::emit [format "DIFF FILE broken=%s" $broken]
    ::d8::emit [format "DIFF FILE working=%s" $working]
    set same 0
    set diff 0
    foreach k [::d8::keys $a $b] {
        set have_a [dict exists $a $k]
        set have_b [dict exists $b $k]
        set va [expr {$have_a ? [dict get $a $k] : "(missing)"}]
        set vb [expr {$have_b ? [dict get $b $k] : "(missing)"}]
        if {$have_a && $have_b && $va eq $vb} {
            incr same
            continue
        }
        incr diff
        ::d8::emit [format "DIFF %s: broken=%s working=%s" $k $va $vb]
    }
    ::d8::emit [format "SAME %d lines" $same]
    ::d8::emit [format "DIFF %d name(s) differ" $diff]
    return [expr {$diff > 0 ? 1 : 0}]
}

set d8_here [file dirname [file normalize [info script]]]
if {[string trim $::d8_dir] ne ""} {
    set d8_out [string trim $::d8_dir]
} else {
    set d8_out [file normalize [file join $d8_here .. 02_working]]
}
if {[string trim $::d8_broken] eq ""} {
    set ::d8_broken [file join $d8_out t008_state_broken.txt]
}
if {[string trim $::d8_working] eq ""} {
    set ::d8_working [file join $d8_out t008_state_working.txt]
}
if {[catch {file mkdir $d8_out} d8_err]} {
    puts "T008 DIFF FAIL cannot create $d8_out: $d8_err"
    puts "DONE"
} else {
    set d8_file [file join $d8_out t008_diff.txt]
    if {[catch {open $d8_file w} d8_fh]} {
        puts "T008 DIFF FAIL cannot write $d8_file: $d8_fh"
        puts "DONE"
    } else {
        set ::d8::fd $d8_fh
        if {[catch {::d8::main $::d8_broken $::d8_working} d8_err]} {
            ::d8::emit [format "DIFF FAIL %s" $d8_err]
            ::d8::emit "DIFF HINT run src/spike/t008_state.tcl once with TAG = broken and once with TAG = working first"
        }
        ::d8::emit [format "DIFF FILE %s" $d8_file]
        set ::d8::fd ""
        catch {close $d8_fh}
        puts "DONE"
    }
}
