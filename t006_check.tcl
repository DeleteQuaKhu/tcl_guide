# src/spike/t006_check.tcl
# T-006 check as ONE FILE (owner, 2026-11-11: "I only use files, I do not run commands").
#
# How to use it in HyperView - nothing to type:
#   1. File > New (the way you always start; this file does not reset for you).
#   2. Edit the values below: the model file, the result file(s), cols, rows.
#   3. Source this file (File > Run Script, or drop it on the Tcl console).
#   4. It prints a short transcript and writes ONE report file:
#          src/02_working/t006_check.txt
#      Send that file back. It holds the BUILD line, the LAYOUTS line (layout id -> window
#      count, measured on YOUR page), the GRID line, the DIAG line (model/result per window)
#      and ONE VERDICT line (PASS, or FAIL with the reason). That is all I need.
#
# What it does, in this order (nothing else, and it never edits a file):
#   BUILD   - which copy of the adapter this session runs
#   LAYOUTS - 'SetLayout <n>' for n = 1..30 on this page. It MOVES the page, which is why it
#             runs first and make_grid rebuilds the grid right after
#   GRID    - make_grid cols rows: the layout id, the window count and the client count
#   DIAG    - per window: does it hold a model (1/0) and its own result (1/0)
#   VERDICT - PASS, or FAIL plus the reason. It is read back window by window
#             ("1 model + a result controller"), not copied from the DIAG line, so a grid too
#             wide for that one line is still judged correctly.
# Tcl 8.5 only: no tcllib, no try/finally, no package require. Every HyperView call still goes
# through ::pis::hw - the same calls the GUI makes, so the journal looks the same.

# --- the values to edit by hand -------------------------------------------------------
# (The if-guard lets a test preset a value; the file clears these six names after a run, so
# sourcing it again after an edit always reads the values below and never a stale copy.)
if {![info exists t6_model]} { set t6_model {C:/temp/model.h3d} }
if {![info exists t6_results]} {
    set t6_results {C:/temp/result1.h3d C:/temp/result2.h3d}
}
if {![info exists t6_cols]} { set t6_cols 4 }
if {![info exists t6_rows]} { set t6_rows 2 }
# 1 = measure the layout table first (the LAYOUTS line). 0 = skip it and trust make_grid.
if {![info exists t6_measure]} { set t6_measure 1 }
# 1 = keep going after a window fails, so the DIAG line shows every window as 1/0.
if {![info exists t6_try_all]} { set t6_try_all 1 }
# Where the report goes. Empty = src/02_working next to this file (a test points it elsewhere).
if {![info exists t6_report_dir]} { set t6_report_dir "" }

# ======================================================================================
# Nothing below needs editing.
# ======================================================================================
namespace eval ::t6 {
    variable fd ""
    variable real "puts"
}

# One line: the console AND the report file. Everything else in this file goes through here,
# and the adapter's own puts are captured (::t6::capture_on), so the report IS the transcript
# and nothing has to be copied by hand. The report write uses 'chan puts' on the channel,
# never the global puts: that one may be the capturing proc below, and calling it from here
# would loop (emit -> puts -> emit ...).
proc ::t6::emit {text} {
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

# The real console command is kept under another name and put back by ::t6::capture_off, so
# the console keeps working after this file has run. A call WITH a channel (puts stderr ...)
# is not a console line: it is passed straight through, so nothing is recorded twice.
proc ::t6::capture_on {} {
    variable real
    if {$real ne "puts"} { return }
    if {[catch {rename ::puts ::t6::console_puts}]} { return }
    set real ::t6::console_puts
    proc ::puts {args} {
        if {[llength $args] > 1} { return [::t6::console_puts {*}$args] }
        ::t6::emit [lindex $args 0]
    }
    return
}
proc ::t6::capture_off {} {
    variable real
    if {[llength [info commands ::t6::console_puts]]} {
        catch {rename ::puts {}}
        catch {rename ::t6::console_puts ::puts}
    }
    set real puts
    return
}

# The adapter reports a variant through ::pis::common::log, which without the GUI writes to
# STDERR (a console that only shows stdout would hide the reason). Same trick as
# src/spike/try_load_all.tcl: give it a sink, but never replace the GUI's own sink.
proc ::t6::log_sink {} {
    if {[llength [info commands ::pis::gui::log_line]] > 0} { return 0 }
    namespace eval ::pis::gui {}
    proc ::pis::gui::log_line {level msg} {
        ::t6::emit [format "%-5s %s" [string toupper [string trim $level]] $msg]
    }
    return 1
}

proc ::t6::stamp {} {
    return [clock format [clock seconds] -format {%Y-%m-%d %H:%M}]
}

# The verdict, read from the SESSION, one window at a time - never parsed out of the DIAG line:
# that line is cut to stay under 80 characters, so a grid of 13+ windows would lose the lists at
# the start and a full grid could look empty. Per window the answer is "<models>:<resultCtrl>",
# the same gate Load All uses: "1:1" = one model AND a result controller that really exists.
proc ::t6::verdict {cols rows} {
    set want [expr {$cols * $rows}]
    set ob {}
    if {[catch {::pis::hw::observe_dict} ob]} {
        return [list FAIL "the page did not answer a window count"]
    }
    set api [dict get $ob api]
    if {![string is integer -strict $api]} {
        return [list FAIL "the page did not answer a window count"]
    }
    if {$api != $want} {
        return [list FAIL [format "api=%s but %dx%d wants %d window(s)" $api $cols $rows $want]]
    }
    set empty {}
    for {set k 1} {$k <= $want} {incr k} {
        set got "?"
        if {[catch {::pis::hw::probe [::pis::hw::check_window_ready $k]} found]} {
            set got "?"
        } else {
            set got [string trim $found]
        }
        if {$got eq "1:1"} { continue }
        if {[string match "0:*" $got]} {
            lappend empty "window $k: no model"
        } else {
            lappend empty "window $k: no result"
        }
    }
    if {[llength $empty] > 3} {
        set empty [concat [lrange $empty 0 2] {...}]
    }
    if {[llength $empty] > 0} { return [list FAIL [join $empty {, }]] }
    return [list PASS [format "layout id %s, %d window(s), each with one model and its own result" \
        [dict get $ob layout] $want]]
}

# Find the report folder and open the report. Returns {channel why}; why is only set when the
# file could not be opened, and then the run says so instead of pretending it has a report.
proc ::t6::open_report {dir} {
    if {[catch {file mkdir $dir} err]} {
        return [list "" "cannot create the report folder $dir: $err"]
    }
    set file [file join $dir t006_check.txt]
    if {[catch {open $file w} fd]} {
        return [list "" "cannot write $file: $fd"]
    }
    return [list $fd ""]
}

# The whole run. Every step is caught: one failure must still produce a report with a VERDICT
# line, because the file is what travels, not the console.
proc ::t6::run {model results cols rows measure try_all} {
    ::t6::emit [format "T006 check %s" [::t6::stamp]]
    ::t6::emit [format "ASKED %dx%d = %d window(s), model %s" $cols $rows \
        [expr {$cols * $rows}] $model]
    ::t6::emit [format "ASKED result file(s) = %d" [llength $results]]
    if {$measure} {
        if {[catch {::pis::hw::layout_table} err]} {
            ::t6::emit "STEP layout_table failed: $err"
        }
    }
    if {[catch {::pis::hw::make_grid $cols $rows} err]} {
        ::t6::emit "STEP make_grid ${cols}x${rows} failed: $err"
        return [list FAIL [format "make_grid %dx%d did not build the grid (see STEP line)" \
            $cols $rows]]
    }
    set k 0
    foreach f $results {
        incr k
        if {[catch {::pis::hw::load_model_in_window $k $model} err]} {
            ::t6::emit "STEP window $k model failed: $err"
            if {!$try_all} {
                return [list FAIL "window $k: the model did not load (see STEP line)"]
            }
            continue
        }
        if {[catch {::pis::hw::load_result_in_window $k $f} err]} {
            ::t6::emit "STEP window $k result failed: $err"
            if {!$try_all} {
                return [list FAIL "window $k: the result did not attach (see STEP line)"]
            }
            continue
        }
    }
    # The DIAG line prints itself and lands in the report; the verdict below is a SEPARATE,
    # per-window read-back (the DIAG line is cut to 80 characters, this is not).
    if {[catch {::pis::hw::diag} err]} {
        ::t6::emit "STEP diag failed: $err"
        return [list FAIL "the session did not answer (see STEP line)"]
    }
    return [::t6::verdict $cols $rows]
}

# --- source the app, run, write the report --------------------------------------------
set t6_dir [file dirname [file normalize [info script]]]
set t6_scripts [file normalize [file join $t6_dir .. 01_scripts]]
if {[string trim $t6_report_dir] ne ""} {
    set t6_out $t6_report_dir
} else {
    set t6_out [file normalize [file join $t6_dir .. 02_working]]
}
lassign [::t6::open_report $t6_out] t6_fd t6_why
if {$t6_fd eq ""} {
    puts "T006 FAIL $t6_why"
    puts "DONE"
} else {
    set ::t6::fd $t6_fd
    ::t6::capture_on
    set t6_verdict [list FAIL "the app did not load"]
    if {[catch {
        foreach t6_f {_tcl_pis_00_common.tcl _tcl_pis_10_hw.tcl \
                _tcl_pis_11_hw_adapter.tcl _tcl_pis_01_load_model_results.tcl} {
            source [file join $t6_scripts $t6_f]
        }
    } t6_err]} {
        ::t6::emit "STEP source failed: $t6_err"
        set t6_verdict [list FAIL "the app did not load (see STEP line)"]
    } else {
        ::t6::log_sink
        if {[catch {set t6_verdict [::t6::run $t6_model $t6_results $t6_cols $t6_rows \
                $t6_measure $t6_try_all]} t6_err]} {
            set t6_verdict [list FAIL "unexpected: $t6_err"]
        }
    }
    lassign $t6_verdict t6_state t6_reason
    ::t6::emit [format "VERDICT: %s %s" $t6_state $t6_reason]
    ::t6::emit [format "REPORT %s" [file join $t6_out t006_check.txt]]
    set ::t6::fd ""
    catch {close $t6_fd}
    ::t6::capture_off
    # A second run in the same HyperView session (4x1, then 2x1) must read the file's values
    # again: a stale global would silently ignore the edit. t6_report_dir is kept - it is the
    # one value a caller sets on purpose.
    catch {unset -nocomplain t6_model t6_results t6_cols t6_rows t6_measure t6_try_all}
    puts "DONE"
}
