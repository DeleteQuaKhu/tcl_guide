# src/spike/t008_state.tcl  -  READ-ONLY state snapshot of window 1 (task T-029).
#
# THIS FILE CHANGES NOTHING: every call it makes is a documented GETTER (docs/refs/HV_API.md
# section 12). It never calls a Set*, never Draws and never selects a window.
#
# OWNER HOW-TO (4 steps):
#   1. Load All, then Load result with the correct name so the window FAILS to show the contour.
#      Source this file with TAG = "broken" (top of the file, or: set ::TAG broken).
#   2. Switch the contour on BY HAND in the Contour panel for window 1 until the result shows.
#      Source this file again with TAG = "working".
#   3. Source src/spike/t008_diff.tcl (it runs in plain tclsh too).
#   4. Send src/02_working/t008_diff.txt AND the two state files.
#
# It writes src/02_working/t008_state_<TAG>.txt: the BUILD line once, a BUILD-TAG <TAG> line and the
# TIME of the snapshot (the diff tool ignores those three), the window count, the ini values it used,
# the client, the data type list size, the current subcase and every documented read-only getter of
# window 1, sorted by name so two files diff cleanly.
# Tcl 8.5 only: no tcllib, no package require.

# --- the values to edit by hand -------------------------------------------------------
# These four are GLOBALS on purpose (::TAG, ::s8_*): sourcing this file from a proc in another
# wrapper must still see them (T-029).
# Which file this run writes: "broken" (before the manual switch) or "working" (after it).
if {![info exists ::TAG]} { set ::TAG "broken" }
# Where the state file goes. Empty = src/02_working next to this file (a test points it elsewhere).
if {![info exists ::s8_out]} { set ::s8_out "" }
# The app folder. Empty = the folder two levels above this file.
if {![info exists ::s8_root]} { set ::s8_root "" }
# The ini. Empty = <root>/00_config/pis_workflow_config.ini.
if {![info exists ::s8_ini]} { set ::s8_ini "" }

namespace eval ::s8 {
    variable fd ""
    variable real "puts"
}

# One line: the console AND the state file.
proc ::s8::emit {text} {
    variable real
    variable fd
    if {$real ne "" && [llength [info commands $real]]} { $real $text } else { puts $text }
    if {$fd ne ""} { catch {chan puts $fd $text} }
    return
}

# The getter dump of one window as sorted "name = value" lines. Read-only by construction:
# ::pis::result::dump_calls holds documented getters only.
proc ::s8::dump_lines {win} {
    set pairs [list]
    if {[catch {set pairs [::pis::result::dump_dict $win]} why]} {
        return [list [format "probe = ERR %s" [string trim $why]]]
    }
    set out [list]
    foreach pair $pairs {
        lappend out [format "%s = %s" [lindex $pair 0] [lindex $pair 1]]
    }
    return [lsort $out]
}


# Build the file. Never raises: every step is caught, because a state file that dies is the defect
# this pass is fixing.
proc ::s8::main {root ini} {
    set cfg ""
    catch {set cfg [::pis::common::load_config $root]}
    if {$cfg eq ""} {
        ::s8::emit [format "CHECK input: cannot read the app folder %s" $root]
        return
    }
    # Item 0b: the values the app already knows, one CHECK line each.
    set model ""
    catch {set model [::pis::common::get $cfg session model_file ""]}
    if {[string trim $model] eq ""} {
        ::s8::emit "CHECK input: model file '-' (the ini names none; Load All decides)"
    } else {
        ::s8::emit [format "CHECK input: model file '%s' from %s \[session\] model_file" \
            $model [file tail $ini]]
    }
    set files ""
    catch {set files [::pis::common::get $cfg session result_files ""]}
    set nfiles 0
    set first_file ""
    foreach line [split $files "\n"] {
        if {[string trim $line] eq ""} { continue }
        incr nfiles
        if {$first_file eq ""} { set first_file [string trim $line] }
    }
    ::s8::emit [format "CHECK input: %d result file(s) from %s \[session\] result_files" \
        $nfiles [file tail $ini]]
    set layout ""
    catch {set layout [::pis::common::get $cfg layout id ""]}
    if {[string trim $layout] eq ""} {
        ::s8::emit "CHECK input: layout id '-' (the ini names none)"
    } else {
        ::s8::emit [format "CHECK input: layout id '%s' from %s \[layout\] id" $layout [file tail $ini]]
    }
    set ob [::pis::hw::observe_dict]
    set api [dict get $ob api]
    if {![string is integer -strict $api] || $api < 1} {
        ::s8::emit [format "window_count = ERR %s" [dict get $ob line]]
        return
    }
    ::s8::emit [format "window_count = %d" $api]
    ::s8::emit [format "result_file_1 = %s" [expr {$first_file eq "" ? "-" : $first_file}]]
    # Item 0c: no model in window 1 -> say so and stop, after the read-only state below.
    set st ""
    set err ""
    if {[catch {set st [::pis::result::read_state 1]} err]} { set st "" }
    if {$st eq ""} {
        ::s8::emit "CHECK input: no model loaded in window 1: run Load All first"
        foreach line [::s8::dump_lines 1] { ::s8::emit $line }
        ::s8::emit [format "session = no result read-back (%s)" [string trim $err]]
        return
    }
    ::s8::emit [format "data_type_count = %d" [llength [dict get $st labels]]]
    ::s8::emit [format "data_types = %s" [join [dict get $st labels] ", "]]
    ::s8::emit [format "current_subcase = %s" [dict get $st subcase]]
    ::s8::emit [format "subcase_count = %s" [dict get $st nsub]]
    # The client of window 1 and the name this file's chain uses for it. The client TYPE is S7 on
    # the WINDOW handle (hwIWindow GetClientType), so it is asked there, never on the client.
    ::s8::emit "client_handle = pisC"
    set ctype ""
    catch {::pis::hw::probe [::pis::result::script 1 "catch {set ::s8::ctype \[pisWin GetClientType\]}" 0]}
    if {[info exists ::s8::ctype]} { set ctype $::s8::ctype }
    if {[string trim $ctype] eq ""} { set ctype "?" }
    ::s8::emit [format "client_type = %s" $ctype]
    foreach line [::s8::dump_lines 1] { ::s8::emit $line }
    return
}


set s8_here [file dirname [file normalize [info script]]]
set s8_scripts [file normalize [file join $s8_here .. 01_scripts]]
if {[string trim $::s8_root] eq ""} {
    set ::s8_root [file normalize [file join $s8_here .. ..]]
}
if {[string trim $::s8_ini] eq ""} {
    set ::s8_ini [file join $::s8_root 00_config pis_workflow_config.ini]
}
if {[string trim $::s8_out] ne ""} {
    set s8_dir [string trim $::s8_out]
} else {
    set s8_dir [file normalize [file join $s8_here .. 02_working]]
}
if {[catch {file mkdir $s8_dir} s8_err]} {
    puts "T008 STATE FAIL cannot create $s8_dir: $s8_err"
    puts "DONE"
} else {
    set s8_file [file join $s8_dir [format "t008_state_%s.txt" $::TAG]]
    if {[catch {open $s8_file w} s8_fh]} {
        puts "T008 STATE FAIL cannot write $s8_file: $s8_fh"
        puts "DONE"
    } else {
        set ::s8::fd $s8_fh
        if {[catch {
            foreach s8_f {_tcl_pis_00_common.tcl _tcl_pis_10_hw.tcl \
                    _tcl_pis_11_hw_adapter.tcl _tcl_pis_03_load_result.tcl} {
                source [file join $s8_scripts $s8_f]
            }
        } s8_err]} {
            ::s8::emit "CHECK the app did not load: $s8_err"
        }
        # The BUILD lines and the moment, exactly once. t008_diff.tcl ignores all three.
        if {[llength [info commands ::pis::hw::build_line]] > 0} {
            ::s8::emit "BUILD-TAG $::TAG"
            ::s8::emit [::pis::hw::build_line]
        }
        ::s8::emit [format "TIME %s" [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]]
        if {[catch {::s8::main $::s8_root $::s8_ini} s8_err]} {
            ::s8::emit [format "STATE unexpected: %s" $s8_err]
        }
        ::s8::emit [format "STATE FILE %s" $s8_file]
        set ::s8::fd ""
        catch {close $s8_fh}
        puts "DONE"
    }
}
