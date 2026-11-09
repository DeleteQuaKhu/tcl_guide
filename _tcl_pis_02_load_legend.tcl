# src/01_scripts/_tcl_pis_02_load_legend.tcl
# ::pis::legend — the "Load Legend" module (task T-007, PARTIAL: the seam is not verified
# inside HyperView yet, the T-002 spike / SPEC Q3 is still open).
# Tcl/Tk 8.5 compatible, no tcllib, no network, no package require.
# Sourcing this file defines procs only: it never calls HyperView.
#
# The ONE seam: ::pis::legend::apply_to_window {index path}
#   - the only place that selects a window, the only place that calls hwc
#     (through ::pis::hw::exec, so every import lands in the journal);
#   - marked ASSUMPTION-Q3/U2: "import acts on the ACTIVE window; window k is selected
#     with <page> SetActiveWindow k". Change that one proc when the spike answers arrive.
#
# Public procs:
#   ::pis::legend::run {root cfg scope}      -> imported window count (0 = skipped)
#   ::pis::legend::apply_to_window {index path} -> the seam (-1 = leave the active window)
#   ::pis::legend::targets {cfg scope}       -> list of window indexes to import into
#   ::pis::legend::selected_item {cfg}       -> [legend] item<selected>, "" when none
#   ::pis::legend::reset_state {}            -> counters back to 0 (tests)
# Namespace variables: applied (last run), calls, last_window, last_path, clicks

namespace eval ::pis::legend {
    if {![info exists applied]} { set applied 0 }
    if {![info exists calls]} { set calls 0 }
    if {![info exists last_window]} { set last_window "" }
    if {![info exists last_path]} { set last_path "" }
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

# Every HyperView handle gets a unique name, so a stale handle from an earlier run can
# never be reused by accident (SPEC_load_legend HARD CONSTRAINTS).
proc ::pis::legend::handle_name {tag} {
    variable clicks
    incr clicks
    return "pis_legend_${tag}_[pid]_$clicks"
}

# --- THE SEAM (ASSUMPTION-Q3/U2) --------------------------------------------
# Window selection and the hwc import live HERE and nowhere else.
#
# ASSUMPTION-Q3/U2 (SPEC Q3 open, T-002 spike not answered):
#   * `hwc result scalar legend import` acts on the window that is ACTIVE.
#   * window k of a CxR layout is selected with `<page> SetActiveWindow k`
#     (windows are numbered from 1 in row-major layout order).
#   * `hwi OpenStack` is safe to call when the stack is already open.
# index < 0 means "leave the active window alone" (the [Apply active] button path).
# When the spike answers differ, this proc is the ONLY thing to change: it is the single
# place that selects a window and the single place that calls hwc.
proc ::pis::legend::apply_to_window {index path} {
    variable calls
    variable last_window
    variable last_path
    if {[string trim $path] eq ""} {
        error "::pis::legend::apply_to_window: empty legend path"
    }
    if {![string is integer -strict $index]} {
        error "::pis::legend::apply_to_window: window index must be an integer, got: $index"
    }
    if {[llength [info commands hwi]] == 0} {
        error "::pis::legend::apply_to_window: the hwi command is not available (run inside HyperView)"
    }
    set client [::pis::legend::handle_name client]
    set page [::pis::legend::handle_name page]
    set stack 0
    set code [catch {
        hwi OpenStack
        set stack 1
        hwi GetActiveClientHandle $client
        $client GetPageHandle $page
        if {$index >= 0} {
            $page SetActiveWindow $index
        }
        ::pis::hw::context [::pis::legend::title] [file tail $path]
        ::pis::hw::exec result scalar legend import $path
        $client Draw
        if {[llength [info commands update]] > 0} {
            update idletasks
        }
    } res opts]
    # HARD CONSTRAINT: release every handle and the stack on the error path too. A failing
    # release never hides the original error (it is kept in $opts).
    foreach h [list $page $client] {
        if {[llength [info commands $h]] > 0} {
            catch {$h ReleaseHandle}
        }
    }
    if {$stack} {
        catch {hwi CloseStack}
    }
    if {$code} {
        return -options $opts $res
    }
    incr calls
    set last_window $index
    set last_path $path
    return $res
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

# Windows a run must import into. scope "layout" = every window created by Load All
# (1..N in layout order); anything else = the active window only (-1 = do not select).
# The per-window numbering is the ASSUMPTION-Q3/U2 above: index 1 is the first window.
proc ::pis::legend::targets {cfg scope} {
    if {$scope ne "layout"} {
        return [list -1]
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

# Run the module once. SPEC_gui s.6.2 order: "on" first (unchecked = skip everything), then
# the selected legend file, then one import per targeted window. Any failure raises, so the
# GUI shows one ERROR and the journal keeps only the commands that really ran.
proc ::pis::legend::run {root cfg scope} {
    variable applied
    ::pis::legend::need_common
    if {$scope ne "layout" && $scope ne "active"} {
        error "::pis::legend::run: unknown scope '$scope' (expected active or layout)"
    }
    set on [::pis::common::to_bool [::pis::common::get $cfg legend on 0] "legend on"]
    if {!$on} {
        set applied 0
        ::pis::common::log $cfg INFO "module [::pis::legend::title]: on is unchecked, nothing run"
        return 0
    }
    set item [::pis::legend::selected_item $cfg]
    if {$item eq ""} {
        set applied 0
        ::pis::common::log $cfg WARN "module [::pis::legend::title]: no item selected, nothing run"
        return 0
    }
    set path [::pis::common::resolve_path $root $item]
    if {![file isfile $path]} {
        error "Legend file not found: $path"
    }
    set windows [::pis::legend::targets $cfg $scope]
    set n 0
    foreach index $windows {
        ::pis::legend::apply_to_window $index $path
        incr n
        if {$index >= 0} {
            ::pis::common::log $cfg INFO "[::pis::legend::title]: window $index <- $path"
        } else {
            ::pis::common::log $cfg INFO "[::pis::legend::title]: active window <- $path"
        }
    }
    set applied $n
    ::pis::common::log $cfg OK "[::pis::legend::title]: $n window(s) <- $path"
    return $n
}

# Counters back to zero; used by tests/tcl/test_legend.tcl between cases.
proc ::pis::legend::reset_state {} {
    variable applied
    variable calls
    variable last_window
    variable last_path
    variable clicks
    set applied 0
    set calls 0
    set last_window ""
    set last_path ""
    set clicks 0
    return
}
