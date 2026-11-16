# src/spike/t008_check.tcl
# T-008 / T-026 check as ONE FILE (owner, 2026-11-11: "I only use files, I do not run commands").
#
# Why this file exists: the owner's check 2 passed (a wrong result name is refused) but check 3
# failed - the log said "applied" while the window's contour never changed. So the module now
# proves the change by READING THE WINDOW BACK (data type, the three contour dimensions of
# docs/refs/HV_API.md S36, the current subcase S40), and this file prints exactly those values
# BEFORE and AFTER the module ran, per window. Nothing here trusts the log.
#
# How to use it in HyperView - nothing to type:
#   0. Copy the WHOLE src/01_scripts folder into the HyperView script path, then File > New.
#   1. Load All as usual (the GUI button), so the windows hold the model and their result files.
#      Without a loaded result there is nothing to display and the VERDICT says so instead of
#      blaming the module.
#   2. Source this file (File > Run Script, or drop it on the Tcl console).
#   3. It writes ONE report file: src/02_working/t008_check.txt - send that back.
#      The file holds the BUILD line, the CHECK lines, one BEFORE line and one AFTER line per
#      window, the STEP line (what the module answered), the VARIANT line, the JOURNAL count and
#      ONE VERDICT line. Read BUILD first: it must name the copy you just copied in.
#
# What it does, in this order (it never edits a file):
#   BUILD   - which copy of the app this session runs
#   CHECK   - the result name used and where it came from, plus the window count and the result
#             file of each window, so the AFTER lines can be read without guessing
#   BEFORE  - per window, what the window answers NOW: type=... enabled=line/shell/solid=...
#             subcase=... component=... (? = that build did not answer that query)
#   STEP    - ::pis::result::run <scope>: the count it answered, or the ERROR text it raised
#   AFTER   - the same read-back as BEFORE, taken after the module ran
#   CELL    - ONLY when MATRIX = 1 (top of this file): one line per diagnostic cell, on window 1
#   MATRIX  - ONLY when MATRIX = 1: the best cell, and the state restored afterwards
#   GETTER  - read-only getters of the contour control, so a diagnosis can see the pool state
#   VARIANT - which apply variant was the one that passed (1 = type-first/true, 2 = enable-first/true,
#             3 = type-first/1, 4 = enable-first/1; see docs/refs/HV_API.md section 11)
#   VERDICT - PASS, or FAIL with one reason per window. It is judged from the AFTER read-back
#             with the module's own verdict rule, never from the log line.
# Tcl 8.5 only: no tcllib, no try/finally, no package require. Every HyperView call goes through
# ::pis::hw - the same procs the GUI uses, so the journal looks the same.

# --- the values to edit by hand -------------------------------------------------------
# The result type to apply. Empty = whatever the GUI's radio list selected, read from
# 00_config/pis_workflow_config.ini ([result] selected + item1..itemN), which is what the GUI
# itself would use. Set it only to check a DIFFERENT type than the GUI last used.
if {![info exists t8_name]} { set t8_name "" }
# Scope of the run: "layout" = every window Load All filled (the GUI's button), "active" = the
# active window only. The BEFORE/AFTER lines always cover every window, so the difference is
# visible either way.
if {![info exists t8_scope]} { set t8_scope "layout" }
# Where the report goes. Empty = src/02_working next to this file (a test points it elsewhere).
if {![info exists t8_report_dir]} { set t8_report_dir "" }
# T-027 DIAGNOSTIC MATRIX: 0 = off, 1 = run the six cells below on WINDOW 1 ONLY, after Load All.
# It changes ONLY the result data type and the dimension enable state of window 1, and RESTORES both
# at the end (the last lines of the block print what was restored). Use it when step 1 of the owner
# check still fails: "MATRIX BEST: cell n" says which order and which boolean literal work.
if {![info exists t8_matrix]} { set t8_matrix 0 }


# ======================================================================================
# Nothing below needs editing.
# ======================================================================================
namespace eval ::t8 {
    variable fd ""
    variable real "puts"
    # T-027: what the diagnostic matrix and the getter probe write into.
    variable got ""
    variable cells {}
    variable ok {}
}

# One line: the console AND the report file. The report write uses 'chan puts' on the channel,
# never the global puts, which may be the capturing proc below (emit -> puts -> emit would loop).
proc ::t8::emit {text} {
    variable real
    variable fd
    if {$real ne "" && [llength [info commands $real]]} {
        $real $text
    } else {
        puts $text
    }
    if {$fd ne ""} {
        catch {chan puts $fd $text}
    }
    return
}

proc ::t8::capture_on {} {
    variable real
    if {$real ne "puts"} { return }
    if {[catch {rename ::puts ::t8::console_puts}]} { return }
    set real ::t8::console_puts
    proc ::puts {args} {
        if {[llength $args] > 1} { return [::t8::console_puts {*}$args] }
        ::t8::emit [lindex $args 0]
    }
    return
}

proc ::t8::capture_off {} {
    variable real
    if {[llength [info commands ::t8::console_puts]]} {
        catch {rename ::puts {}}
        catch {rename ::t8::console_puts ::puts}
    }
    set real puts
    return
}

# The module reports through ::pis::common::log, which without the GUI writes to STDERR. Give it a
# sink, but never replace the GUI's own sink (same trick as src/spike/t006_check.tcl).
proc ::t8::log_sink {} {
    if {[llength [info commands ::pis::gui::log_line]] > 0} { return 0 }
    namespace eval ::pis::gui {}
    proc ::pis::gui::log_line {level msg} {
        ::t8::emit [format "%-5s %s" [string toupper [string trim $level]] $msg]
    }
    return 1
}

proc ::t8::stamp {} {
    return [clock format [clock seconds] -format {%Y-%m-%d %H:%M}]
}

# Read one value out of the app's ini without loading the app (plain text: [section], key = value).
proc ::t8::ini_get {file section key} {
    if {![file isfile $file]} { return "" }
    if {[catch {open $file r} fd]} { return "" }
    set out ""
    set in ""
    while {[gets $fd line] >= 0} {
        set line [string trim $line]
        if {$line eq ""} { continue }
        set c [string index $line 0]
        if {$c eq ";" || $c eq "#"} { continue }
        if {[regexp {^\[(.+)\]$} $line -> sec]} {
            set in [string trim $sec]
            continue
        }
        if {$in ne $section} { continue }
        if {![regexp {^([^=]+)=(.*)$} $line -> k v]} { continue }
        if {[string trim $k] ne $key} { continue }
        set out [string trim $v]
    }
    catch {close $fd}
    return $out
}

proc ::t8::open_report {dir} {
    if {[catch {file mkdir $dir} err]} {
        return [list "" "cannot create the report folder $dir: $err"]
    }
    set file [file join $dir t008_check.txt]
    if {[catch {open $file w} fd]} {
        return [list "" "cannot write $file: $fd"]
    }
    return [list $fd ""]
}


# --- the read-back, the apply and the verdict -----------------------------------------
# One read-back per window of the page, in order: {k st k st ...}, st = "" when the window did not
# answer (no model, no result). Read-only: it never changes the session.
proc ::t8::read_all {api} {
    set out {}
    set k 0
    while {$k < $api} {
        incr k
        set st ""
        catch {set st [::pis::result::read_state $k]}
        lappend out $k $st
    }
    return $out
}

# The BEFORE / AFTER lines: the same five values the module judges on (S29 type, S36 dimensions,
# S40 subcase, S38 component), written with the module's own formatter so the report and the
# module's log line can never say different things.
proc ::t8::print_states {tag cfg states} {
    foreach {k st} $states {
        set file [::pis::result::window_file $cfg $k]
        if {$file eq ""} { set file "-" }
        if {$st eq ""} {
            ::t8::emit [format "%s win %s (%s): no read-back (this window holds no result)" $tag $k $file]
            continue
        }
        ::t8::emit [format "%s win %s (%s) %s" $tag $k $file [::pis::result::values_text $st]]
    }
    return
}

# The apply. The GUI's own entry point (::pis::result::run) is used whenever its Load All gate is
# set in THIS session; otherwise the same seam is called per window - ::pis::result::apply_to_window
# is exactly what run calls for window k, so nothing is shortened or faked. Returns
# {code answer what}.
proc ::t8::apply_run {root cfg name scope windows} {
    if {$scope ne "layout"} {
        set code [catch {::pis::result::run $root $cfg active} res]
        return [list $code $res {::pis::result::run active (the GUI's own path)}]
    }
    set gate 0
    if {[llength [info commands ::pis::step01::loaded]] > 0} {
        catch {set gate [::pis::step01::loaded]}
    }
    if {$gate} {
        set code [catch {::pis::result::run $root $cfg layout} res]
        return [list $code $res {::pis::result::run layout (the GUI's own path)}]
    }
    set n 0
    set bad {}
    foreach k $windows {
        if {[catch {::pis::result::apply_to_window $cfg $k $name} res]} {
            lappend bad [format "window %s: %s" $k [string trim $res]]
            continue
        }
        incr n
    }
    set how {::pis::result::apply_to_window per window (no Load All in this session)}
    if {[llength $bad] > 0} {
        return [list 1 [join $bad { | }] $how]
    }
    return [list 0 [format "%d window(s) changed" $n] $how]
}

# PASS only when every JUDGED window (all of them for the layout scope, the active one otherwise)
# that answered BEFORE still answers AFTER and passes the module's own display rule for the label
# that was applied. A window without a result is NAMED, never skipped.
proc ::t8::verdict {label states judge} {
    set bad {}
    set n 0
    foreach {k st} $states {
        if {[lsearch -exact $judge $k] < 0} { continue }
        if {$st eq ""} {
            lappend bad [format "window %s holds no result (run Load All first)" $k]
            continue
        }
        incr n
        lassign [::pis::result::verdict $st $label] ok why
        if {!$ok} {
            lappend bad [format "window %s: %s" $k $why]
        }
    }
    if {[llength $judge] == 0} {
        return [list FAIL "the active window did not answer GetActiveWindow (S33)"]
    }
    if {$n == 0} {
        return [list FAIL "no window holds a result: run Load All in the GUI (or src/spike/t006_check.tcl) first"]
    }
    if {[llength $bad] > 0} {
        return [list FAIL [join $bad { | }]]
    }
    return [list PASS [format "%d window(s) display '%s' by read-back" $n $label]]
}

# The whole run: read, apply, read again, then judge. Every step is caught so the report always
# ends with a VERDICT line - the file travels, not the console.
proc ::t8::run {root cfg name scope} {
    ::t8::emit [format "T008 check %s" [::t8::stamp]]
    set ob [::pis::hw::observe_dict]
    set api [dict get $ob api]
    if {![string is integer -strict $api] || $api < 1} {
        return [list FAIL [format "the page did not answer a window count (%s)" [dict get $ob line]]]
    }
    ::t8::emit [format "CHECK %d window(s) on the page, scope %s" $api $scope]
    set before [::t8::read_all $api]
    ::t8::print_states BEFORE $cfg $before
    # Which windows the run must change, and therefore the ones this verdict judges: the windows
    # the module itself would target (all of them for the layout scope, the active one otherwise).
    set judge {}
    if {$scope eq "layout"} {
        if {[catch {set judge [::pis::result::targets $cfg layout]}]} {
            set judge {}
            set k 0
            while {$k < $api} {
                incr k
                lappend judge $k
            }
        }
    } else {
        set ast ""
        if {![catch {set ast [::pis::result::read_state -1]}]} {
            set judge [list [dict get $ast win]]
        }
    }
    ::t8::emit [format "ASKED result '%s' on %s (window(s): %s)" $name $scope $judge]
    lassign [::t8::apply_run $root $cfg $name $scope $judge] code res how
    set shown [string trim $res]
    if {$code} {
        ::t8::emit [format "STEP %s failed: %s" $how $shown]
    } else {
        if {[string is integer -strict $shown]} {
            set shown [format "%s window(s) changed" $shown]
        }
        ::t8::emit [format "STEP %s -> %s" $how $shown]
    }
    set after [::t8::read_all $api]
    ::t8::print_states AFTER $cfg $after
    # T-027: the diagnostic matrix (opt-in) and the read-only getter probe, on WINDOW 1 only. Both
    # run AFTER the verdict material above was captured, so they cannot change what this file says
    # about the module; the matrix restores the state it changed and prints what it restored.
    set ::t8_label $name
    set ::t8_dims [list]
    foreach {k st} $before {
        if {$k != 1 || $st eq ""} { continue }
        set i 0
        foreach d {line shell solid} {
            lappend ::t8_dims $d [lindex [dict get $st dims] $i]
            incr i
        }
    }
    if {[string trim $::t8_matrix] ne "" && $::t8_matrix != 0} {
        set btype ""
        foreach {k st} $before {
            if {$k == 1 && $st ne ""} { set btype [dict get $st type] }
        }
        catch {::t8::matrix $btype}
    }
    catch {::t8::getters}
    set v $::pis::result::variant
    set vtext "none (no variant passed)"
    if {$v >= 1} {
        set vtext [format "%s (%s)" $v [::pis::result::variant_name $v]]
    }
    ::t8::emit [format "VARIANT %s" $vtext]
    set lines 0
    set last ""
    foreach line [split [::pis::journal::lines] "\n"] {
        if {[regexp {^hwi[ \t]} $line]} {
            incr lines
            set last $line
        }
    }
    ::t8::emit [format "JOURNAL %d hwi line(s) this session" $lines]
    if {$last ne ""} {
        ::t8::emit [format "JOURNAL last %s" [::pis::hw::clip $last 100]]
    }
    lassign [::t8::verdict $name $after $judge] state why
    if {$code} {
        # The read-back may still show the label (an earlier run left it there), but the module
        # refused to do it: report BOTH, so the reason is never hidden behind a PASS.
        return [list FAIL [format "%s | the module reported: %s" $why [string trim $res]]]
    }
    return [list $state $why]
}

# --- the T-027 diagnostic matrix (window 1 only, restores what it changes) -------------
# One CELL: reset every dimension to false with the documented call, put the data type back to the
# type window 1 had BEFORE, send the cell's own order and literal, Draw on window 1's client, let Tk
# paint when the cell asks for it, then read everything back. Never raises: the build's own error
# text is printed in full on the CELL line.
proc ::t8::matrix_cell {n order state draw before} {
    set lines [list "pisR GetContourCtrlHandle pisCt"]
    foreach d [::pis::result::dims] {
        lappend lines [format "catch {pisCt SetDimensionEnabled %s false}" $d]
    }
    if {$before ne ""} {
        lappend lines [format "catch {pisCt SetDataType %s}" [::pis::hw::quote $before]]
    }
    set en [list]
    foreach d [::pis::result::dims] {
        lappend en [format "catch {pisCt SetDimensionEnabled %s %s}" $d $state]
    }
    set ty [format "catch {pisCt SetDataType %s}" [::pis::hw::quote $::t8_label]]
    if {$order eq "enable_first"} {
        foreach line $en { lappend lines $line }
        lappend lines $ty
    } else {
        lappend lines $ty
        foreach line $en { lappend lines $line }
    }
    lappend lines "catch {pisC Draw}"
    set err "none"
    set e ""
    if {[catch {::pis::hw::exec_hwi [::pis::result::script 1 [join $lines "\n"] 1] -nojournal} e]} {
        set err [string trim $e]
    }
    if {$draw} { catch {::pis::hw::refresh} }
    set st ""
    set why ""
    if {[catch {set st [::pis::result::read_state 1]} why]} {
        ::t8::emit [format "CELL %s order=%s bool=%s draw_before_read=%s -> no read-back: %s | err=%s" \
            $n $order $state $draw [string trim $why] $err]
        return [list 0 $st]
    }
    ::t8::emit [format "CELL %s order=%s bool=%s draw_before_read=%s -> type=%s enabled=%s err=%s" \
        $n $order $state $draw [dict get $st type] [::pis::result::enabled_text $st] $err]
    return [list [::pis::result::verdict $st $::t8_label] $st]
}

# The six cells, in the order T-027 item 5 asks for, then `MATRIX BEST` and the restore.
proc ::t8::matrix {before} {
    ::t8::emit [format "MATRIX on: window 1 only, cells 1-6. This changes ONLY the result data type and the dimension enable state of window 1 and restores both at the end."]
    set ::t8::cells {}
    set ::t8::ok {}
    set plans {
        {1 enable_first true 1}
        {2 type_first true 1}
        {3 enable_first 1 1}
        {4 type_first 1 1}
    }
    foreach p $plans {
        lassign $p n order state draw
        lassign [::t8::matrix_cell $n $order $state $draw $before] v st
        lappend ::t8::cells [dict create n $n order $order state $state draw $draw ok [lindex $v 0] st $st]
        if {[lindex $v 0]} { lappend ::t8::ok $n }
    }
    # Cells 5 and 6: the two best cells above, repeated WITHOUT waiting for Tk to paint. "Best" = the
    # cells that passed, then the cells that at least showed the type; the cell number breaks a tie.
    set order $::t8::ok
    if {[llength $order] < 2} {
        foreach c $::t8::cells {
            set st [dict get $c st]
            if {$st eq ""} { continue }
            if {[dict get $st type] eq $::t8_label} { lappend order [dict get $c n] }
        }
    }
    foreach c $::t8::cells {
        if {[llength $order] >= 2} { break }
        if {[lsearch -exact $order [dict get $c n]] < 0} { lappend order [dict get $c n] }
    }
    set k 5
    foreach pick [lrange $order 0 1] {
        foreach c $::t8::cells {
            if {[dict get $c n] != $pick} { continue }
            lassign [::t8::matrix_cell $k [dict get $c order] [dict get $c state] 0 $before] v st
            lappend ::t8::cells [dict create n $k order [dict get $c order] \
                state [dict get $c state] draw 0 ok [lindex $v 0] st $st]
            incr k
        }
    }
    set best "none"
    foreach c $::t8::cells {
        if {[dict get $c ok]} { set best "cell [dict get $c n]" ; break }
    }
    ::t8::emit [format "MATRIX BEST: %s" $best]
    # Restore: the ORIGINAL type and the ORIGINAL dimension enable state of window 1.
    set lines [list "pisR GetContourCtrlHandle pisCt"]
    if {$before ne ""} {
        lappend lines [format "catch {pisCt SetDataType %s}" [::pis::hw::quote $before]]
    }
    foreach {d v} $::t8_dims {
        if {[string trim $v] eq ""} { continue }
        lappend lines [format "catch {pisCt SetDimensionEnabled %s %s}" $d $v]
    }
    lappend lines "catch {pisC Draw}"
    set e ""
    catch {::pis::hw::exec_hwi [::pis::result::script 1 [join $lines "\n"] 1] -nojournal} e
    catch {::pis::hw::refresh}
    set st ""
    set why ""
    if {[catch {set st [::pis::result::read_state 1]} why]} {
        ::t8::emit [format "MATRIX RESTORED window 1 -> no read-back: %s" [string trim $why]]
        return
    }
    ::t8::emit [format "MATRIX RESTORED window 1 -> type=%s enabled=%s" \
        [dict get $st type] [::pis::result::enabled_text $st]]
    return
}

# Read-only probe: getters that the supplier's class page prints with NO arguments, so nothing here
# can change the session. Setters and getters whose arguments have no printed value space
# (GetEnabled needs a `pool`, GetDataComponent needs a dimension) are skipped on purpose.
proc ::t8::probe_value {lines} {
    set scr "[::pis::result::script 1 [join $lines "\n"] 0]\nset ::t8::got"
    set ::t8::got ""
    set e ""
    if {[catch {::pis::hw::probe $scr} e]} {
        return "error: [string trim $e]"
    }
    return [string trim $::t8::got]
}

proc ::t8::getters {} {
    foreach name {GetLayer GetShellLayer GetShowMidsideNodeResults} {
        set tail [list "pisR GetContourCtrlHandle pisCt"]
        lappend tail [format "if {[catch {pisCt %s} ::t8::got]} { set ::t8::got \"error: \$::t8::got\" }" $name]
        ::t8::emit [format "GETTER %s -> %s" $name [::t8::probe_value $tail]]
    }
    return
}

set t8_dir [file dirname [file normalize [info script]]]
set t8_scripts [file normalize [file join $t8_dir .. 01_scripts]]
# A test may preset t8_root (the app folder); otherwise the folder above src/ is used.
if {![info exists t8_root]} {
    set t8_root [file normalize [file join $t8_dir .. ..]]
}
# A test may preset t8_ini / t8_report_dir; otherwise the app's own files are used.
if {![info exists t8_ini]} {
    set t8_ini [file join $t8_root 00_config pis_workflow_config.ini]
}
if {[string trim $t8_report_dir] ne ""} {
    set t8_out $t8_report_dir
} else {
    set t8_out [file normalize [file join $t8_dir .. 02_working]]
}
lassign [::t8::open_report $t8_out] t8_fd t8_why
if {$t8_fd eq ""} {
    puts "T008 FAIL $t8_why"
    puts "DONE"
} else {
    set ::t8::fd $t8_fd
    ::t8::capture_on
    set t8_verdict [list FAIL "the app did not load"]
    if {[catch {
        foreach t8_f {_tcl_pis_00_common.tcl _tcl_pis_10_hw.tcl \
                _tcl_pis_11_hw_adapter.tcl _tcl_pis_03_load_result.tcl} {
            source [file join $t8_scripts $t8_f]
        }
    } t8_err]} {
        ::t8::emit "STEP source failed: $t8_err"
        set t8_verdict [list FAIL "the app did not load (see STEP line)"]
    } else {
        ::t8::log_sink
        ::t8::emit [::pis::hw::build_line]
        set t8_cfg ""
        catch {set t8_cfg [::pis::common::load_config $t8_root]}
        if {$t8_cfg eq ""} {
            set t8_verdict [list FAIL [format "cannot read the app folder %s" $t8_root]]
            ::t8::emit [format "CHECK %s" [lindex $t8_verdict 1]]
        } else {
            # The result name: the file's own value, else the GUI's radio selection in the ini.
            set t8_use [string trim $t8_name]
            if {$t8_use ne ""} {
                ::t8::emit [format "CHECK result name '%s' from the top of this file" $t8_use]
                dict set t8_cfg result [dict create count 1 selected 1 item1 $t8_use]
            } else {
                set t8_use [::pis::result::selected_item $t8_cfg]
                if {$t8_use ne ""} {
                    ::t8::emit [format "CHECK result name '%s' from %s \[result\]" \
                        $t8_use [file tail $t8_ini]]
                }
            }
            if {$t8_use eq ""} {
                set t8_verdict [list FAIL "no result name: select one in the GUI, or set t8_name at the top of this file"]
                ::t8::emit [format "CHECK %s" [lindex $t8_verdict 1]]
            } elseif {![file isfile $t8_ini]} {
                ::t8::emit [format "CHECK %s not found - the window names stay '-'" [file tail $t8_ini]]
            }
            if {$t8_use ne ""} {
                if {[catch {set t8_verdict [::t8::run $t8_root $t8_cfg $t8_use $t8_scope]} t8_err]} {
                    set t8_verdict [list FAIL "unexpected: $t8_err"]
                }
            }
        }
    }
    lassign $t8_verdict t8_state t8_reason
    ::t8::emit [format "VERDICT: %s %s" $t8_state $t8_reason]
    ::t8::emit [format "REPORT %s" [file join $t8_out t008_check.txt]]
    set ::t8::fd ""
    catch {close $t8_fd}
    ::t8::capture_off
    # A second run in the same session must read the file's values again, never a stale copy.
    catch {unset -nocomplain t8_name t8_scope}
    puts "DONE"
}
