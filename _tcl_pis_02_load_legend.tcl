# src/01_scripts/_tcl_pis_02_load_legend.tcl
# ::pis::legend - the "Load Legend" module (task T-007; T-035 after the owner's `fail`, F16 + F17).
# Tcl/Tk 8.5 compatible, no tcllib, no network, no package require.
# Sourcing this file defines procs only: it never calls HyperView.
#
# WHAT THE OWNER MEASURED (2026-11-18):
#   F16 - Apply all always ended with `Object named: pis_legend_client_... (of type poIPost) could
#         not find requested method: GetPageHandle ...`. The module used to reach the page through a
#         CLIENT handle; in the proven chain the PROJECT handle is the one that answers
#         `GetPageHandle` (docs/refs/HV_API.md sec.1, S14). That call is GONE: every window is
#         selected through ::pis::hw::select_window (project handle -> page -> SetActiveWindow k),
#         the same helper Load result and Capture use.
#   F17 - `on` is the Display Control > Legend toggle: ticked + [Apply all layout] SHOWS the legend
#         in every window, unticked HIDES it in every window. Unticked is an action, not a skip.
#
# The order per window k (docs/SPEC.md "Load Legend"):
#   1) select window k            - ::pis::hw::select_window (ONE journaled hwi line, S5)
#   2) `on` ticked + a file       - ::pis::hw::import_legend (the PROVEN hwc form, T-021 rules)
#   3) show or hide               - ::pis::hw::legend_visibility (V1 PROVEN hwc show/hide legends,
#                                   V2 DOC poIPost SetDisplayOptions legend, read back with
#                                   GetDisplayOptions legend S57)
# A failing window stops the run unless [log] continue_on_error is set.
#
# Public procs:
#   ::pis::legend::run {root cfg scope}                 -> number of windows shown/hidden
#   ::pis::legend::apply_to_window {index path on trace} -> one window (the ONE seam)
#   ::pis::legend::targets {cfg scope}                  -> window indexes to act on
#   ::pis::legend::selected_item {cfg}                  -> [legend] item<selected>, "" when none
#   ::pis::legend::trace_on {cfg}                       -> 1 when [debug] legend_trace (default 1)
#   ::pis::legend::handle_name {tag}                    -> unique name of the ONE handle this
#                                                          module may create (import fallback)
#   ::pis::legend::reset_state {}                       -> counters back to 0 (tests)
# Namespace variables: applied, shown, hidden, failed, calls, last_window, last_path,
#                      last_variant, clicks

namespace eval ::pis::legend {
    if {![info exists applied]} { set applied 0 }
    if {![info exists shown]} { set shown 0 }
    if {![info exists hidden]} { set hidden 0 }
    if {![info exists failed]} { set failed 0 }
    if {![info exists calls]} { set calls 0 }
    if {![info exists last_window]} { set last_window "" }
    if {![info exists last_path]} { set last_path "" }
    if {![info exists last_variant]} { set last_variant 0 }
    if {![info exists clicks]} { set clicks 0 }
}

# The module title exactly as the GUI shows it: it goes into the journal comment and the
# WARN required by SPEC.md A8 ("module <name>: no item selected, nothing run").
proc ::pis::legend::title {} {
    return "Load Legend"
}

# Offline this file is useless without ::pis::common; say so instead of a confusing error.
proc ::pis::legend::need_common {} {
    foreach p {load_config get resolve_path log to_bool} {
        if {[llength [info commands ::pis::common::$p]] == 0} {
            error "::pis::legend: source _tcl_pis_00_common.tcl first (missing ::pis::common::$p)"
        }
    }
    return
}

# Every HyperView call of this module goes through the adapter (SPEC.md D2). Without it a run must
# stop HERE, naming the missing file, instead of failing halfway through window 1.
proc ::pis::legend::need_hw {} {
    foreach p {select_window import_legend legend_visibility active_window begin_legend} {
        if {[llength [info commands ::pis::hw::$p]] == 0} {
            error "::pis::legend: source _tcl_pis_11_hw_adapter.tcl first (missing ::pis::hw::$p)"
        }
    }
    return
}

# Unique name of the ONE handle this module may create (the legend handle of the
# ::hwp::GetContourLegend import fallback, SPEC_load_legend FILE 3). A stale handle from an earlier
# run can never be reused by accident (SPEC_load_legend HARD CONSTRAINTS).
proc ::pis::legend::handle_name {tag} {
    variable clicks
    incr clicks
    return "pis_legend_${tag}_[pid]_$clicks"
}


# --- THE SEAM: ONE window (T-035) ----------------------------------------------------------
# The only place of this module that changes a window, in the order docs/SPEC.md fixes:
#   select window k -> (on + a file) import -> show | hide.
# Nothing here walks the page: that walk is ::pis::hw::select_window, which uses the PROJECT handle
# for `GetPageHandle` (F16: a poIPost handle refuses that method).
# `on` follows F17: 1 = show (import first), 0 = hide. `trace` is the adapter's step trace.
# Returns the adapter's answer dict ({variant mode line unverified}).
proc ::pis::legend::apply_to_window {index path on trace} {
    variable calls
    variable last_window
    variable last_path
    variable last_variant
    variable shown
    variable hidden
    if {![string is integer -strict $index] || $index < 1} {
        error "::pis::legend::apply_to_window: window index must be a positive integer, got: $index"
    }
    set mode show
    if {![::pis::common::to_bool $on "legend on"]} { set mode hide }
    set p ""
    if {$mode eq "show"} {
        # An EMPTY path is legal under F17: showing needs no file (nothing is imported).
        set p [string trim $path]
        # Refused BEFORE any HyperView call: a missing file must leave the journal untouched.
        if {$p ne "" && ![file isfile $p]} {
            error "Legend file not found: $p"
        }
    }
    # The journal comment of every line this window writes (module + the file's own name).
    if {$p eq ""} {
        ::pis::hw::context [::pis::legend::title] $mode
    } else {
        ::pis::hw::context [::pis::legend::title] [file tail $p]
    }
    # 1) window k becomes the active one - ONE journaled `hwi ... SetActiveWindow k` line.
    ::pis::hw::legend_select $index $trace
    # 2) ticked WITH a file: import it into THAT window (PROVEN hwc form, T-021 texts unchanged).
    if {$mode eq "show" && $p ne ""} {
        ::pis::hw::import_legend $p
    }
    # 3) show it, or hide it (the adapter's job; it does not select the window a second time).
    set res [::pis::hw::legend_visibility $index $mode 0 $trace]
    incr calls
    set last_window $index
    set last_path $p
    set last_variant [dict get $res variant]
    if {$mode eq "show"} {
        incr shown
    } else {
        incr hidden
    }
    return $res
}

# Is the [debug] legend_trace step trace on? Default 1 until the owner writes `accepted`; an ini
# value of 0 turns it off and the JOURNAL text stays identical either way (docs/SPEC.md).
proc ::pis::legend::trace_on {cfg} {
    set v 1
    catch {set v [::pis::common::get $cfg debug legend_trace 1]}
    if {[catch {set on [::pis::common::to_bool $v "debug legend_trace"]}]} { set on 1 }
    return $on
}

# The radio selection of [legend]: index 1..count in the ini, "" when nothing is selected.
proc ::pis::legend::selected_item {cfg} {
    ::pis::legend::need_common
    set sel [string trim [::pis::common::get $cfg legend selected -1]]
    if {![string is integer -strict $sel] || $sel < 1} {
        return ""
    }
    set key "item$sel"
    if {![dict exists [dict get $cfg legend] $key]} {
        return ""
    }
    return [string trim [dict get [dict get $cfg legend] $key]]
}

# Windows a run must act on (T-035). scope "layout" = every window created by Load All (1..N in
# layout order, F1/Q1); anything else = the ACTIVE window only - asked with the documented
# `hwIPage GetActiveWindow` (S33, read-only, never journaled), so the module button touches one
# window and the log names which one (docs/refs/SPEC_gui.txt s.5, quoted in docs/SPEC.md).
proc ::pis::legend::targets {cfg scope} {
    if {$scope ne "layout"} {
        return [list [::pis::hw::active_window]]
    }
    set loaded 0
    if {[info exists ::pis::step01::loaded]} {
        set loaded $::pis::step01::loaded
    }
    if {!$loaded} {
        error "Model/results not loaded | click Load All first."
    }
    set n 0
    if {[info exists ::pis::step01::last_result]} {
        set n $::pis::step01::last_result
    }
    if {![string is integer -strict $n] || $n < 1} {
        error "Load All reported no window to apply to (windows: '$n')"
    }
    set out [list]
    set i 1
    while {$i <= $n} {
        lappend out $i
        incr i
    }
    return $out
}

# Run the module once. F17 order: read `on` first (it is the DISPLAY toggle now, not a skip), then
# the selected legend file - a missing one is refused before any HyperView call - then one window at
# a time: select -> import (ticked only) -> show | hide. A failing window stops the run unless
# [log] continue_on_error is set (docs/refs/SPEC_gui.txt s.7). The final line always says how many
# of how many windows were done.
proc ::pis::legend::run {root cfg scope} {
    variable applied
    variable shown
    variable hidden
    variable failed
    ::pis::legend::need_common
    ::pis::legend::need_hw
    if {$scope ne "layout" && $scope ne "active"} {
        error "::pis::legend::run: unknown scope '$scope' (expected active or layout)"
    }
    set applied 0
    set shown 0
    set hidden 0
    set failed 0
    # A new run forgets which methods this build lacks (T-027) and re-arms the adapter's own
    # one-per-run legend notes (T-035).
    catch {::pis::hw::absent_reset}
    catch {::pis::hw::begin_legend}
    set on [::pis::common::to_bool [::pis::common::get $cfg legend on 0] "legend on"]
    set path ""
    if {$on} {
        set item [::pis::legend::selected_item $cfg]
        if {$item eq ""} {
            # F17: the checkbox is an ACTION - showing a legend needs no file. ONE INFO says why
            # nothing was imported, so an empty row is still not a silent no-op.
            ::pis::common::log $cfg INFO \
                "module [::pis::legend::title]: no legend file selected, showing the legend only"
        } else {
            set path [::pis::common::resolve_path $root $item]
            if {![file isfile $path]} {
                error "Legend file not found: $path"
            }
        }
    }
    set windows [::pis::legend::targets $cfg $scope]
    set total [llength $windows]
    set trace [::pis::legend::trace_on $cfg]
    set cont 0
    catch {set cont [::pis::common::to_bool \
        [::pis::common::get $cfg log continue_on_error 0] "log continue_on_error"]}
    set n 0
    foreach index $windows {
        set code [catch {::pis::legend::apply_to_window $index $path $on $trace} res]
        if {$code} {
            if {!$cont} {
                error [string trim $res]
            }
            ::pis::common::log $cfg ERROR "[::pis::legend::title]: [string trim $res]"
            incr failed
            continue
        }
        incr n
    }
    set applied $n
    set word shown
    if {!$on} { set word hidden }
    set tail ""
    if {$failed > 0} { set tail [format ", %d failed" $failed] }
    set lvl OK
    if {$failed > 0} { set lvl WARN }
    ::pis::common::log $cfg $lvl [format "%s: %d of %d window(s) %s%s" \
        [::pis::legend::title] $n $total $word $tail]
    return $n
}

# Counters back to zero; used by tests/tcl/test_legend.tcl between cases.
proc ::pis::legend::reset_state {} {
    variable applied
    variable shown
    variable hidden
    variable failed
    variable calls
    variable last_window
    variable last_path
    variable last_variant
    variable clicks
    set applied 0
    set shown 0
    set hidden 0
    set failed 0
    set calls 0
    set last_window ""
    set last_path ""
    set last_variant 0
    set clicks 0
    return
}
