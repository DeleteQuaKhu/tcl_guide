# PIS Workflow - block 0: load ONE model + N result files into a HyperView layout named by its
# integer id (task T-006, T-017). SPEC.md D2: plain HyperView commands only - no user library, no stub mode,
# no bare hwc line in this file. Every command comes from the ::pis::hw adapter (T-002c), so
# a saved journal replays Load All and Reset (New) in a fresh session (SPEC.md A2-A4).
# Tcl/Tk 8.5 compatible, no tcllib, no network, no package require, no Tk.
# Sourcing this file defines procs only: it never touches HyperView.
#
# Procs | params | call sites
#   ::pis::step01::need_common {}         | load_all
#   ::pis::step01::need_adapter {}        | load_all, reset_session
#   ::pis::step01::call {module item cmd} | load_all, reset_session
#   ::pis::step01::window_call {k step label cmd} | load_window
#   ::pis::step01::raw_fail {step k err}  | window_call, load_window (C1: raw reason, 70 chars)
#   ::pis::step01::status_red {msg}       | raw_fail, load_window (one red status line)
#   ::pis::step01::load_window {k model file} | load_all
#   ::pis::step01::validate {root cfg}    | load_all
#   ::pis::step01::load_all {cfg}         | ::pis::gui::run_block0
#   ::pis::step01::reset_session {}       | ::pis::gui::run_block0
#   ::pis::step01::loaded {}              | a module's "click Load All first" gate
# Namespace variables later tasks read (the proc ::pis::step01::loaded returns the same
# value as the variable, so the two can never disagree):
#   last_result (windows created by the last Load All), loaded (0|1)
#
# EACH WINDOW GETS ITS OWN MODEL (fix, 2026-11-10): a window is a client with its own model
# list, so "load the model once, then put a result in every window" leaves windows 2..N with
# nothing to attach to. load_window therefore loads the model into window k AND its result
# into window k, then asks the adapter to read the window back (1 model + 1 result) before
# the next window starts.

namespace eval ::pis::step01 {
    variable last_result 0
    variable loaded 0
}

# ::pis::common is the only config/path/log layer (T-004); fail loudly if missing.
proc ::pis::step01::need_common {} {
    if {[llength [info commands ::pis::common::get]] == 0} {
        error "::pis::step01 needs ::pis::common: source _tcl_pis_00_common.tcl first"
    }
    return
}

# The adapter owns every HyperView command variant (SPEC.md D2/Q1); without it this module
# cannot do anything, and saying so here beats a "no such command" from the middle of a run.
proc ::pis::step01::need_adapter {} {
    if {[llength [info commands ::pis::hw::exec]] == 0} {
        error "::pis::step01 needs ::pis::hw: source _tcl_pis_10_hw.tcl first (missing ::pis::hw::exec)"
    }
    foreach name {reset_session reset_session_soft load_model_in_window \
                      load_model make_grid load_result_in_window verify_window \
                      models_in_window order begin_run} {
        if {[llength [info commands ::pis::hw::$name]] == 0} {
            error "::pis::step01 needs the HyperView adapter: source _tcl_pis_11_hw_adapter.tcl first (missing ::pis::hw::$name)"
        }
    }
    return
}

# One adapter call. The journal context (module + item) is set FIRST, so the wrapper writes
# "<timestamp> | <module> | <item>" in front of the command that really ran. A failure is
# re-raised as one ERROR naming the step and keeping the command's own message (SPEC.md
# error states); the wrapper already journals nothing for a command that failed.
proc ::pis::step01::call {module item cmd} {
    ::pis::hw::context $module $item
    if {[catch {{*}$cmd} res]} {
        error [format "%s: %s failed: %s" $module $item [string trim $res]]
    }
    return $res
}

# Every block-0 rule with its specific message (SPEC.md A6/A7, refs/SPEC_load_model.txt for
# the wording). Returns {model_file result_files layout_id windows} with absolute paths and the
# window count taken from the STATIC layout table (T-017: the id decides the geometry, never a
# page that a previous session arranged by hand).
proc ::pis::step01::validate {root cfg} {
    need_common
    set model [string trim [::pis::common::get $cfg session model_file ""]]
    if {$model eq ""} {
        error "Model file is empty | enter the model path first."
    }
    set model [::pis::common::resolve_path $root $model]
    ::pis::common::require_file "Model file" $model
    set files [list]
    foreach item [::pis::common::get $cfg session result_files ""] {
        set item [string trim $item]
        if {$item eq ""} { continue }
        set item [::pis::common::resolve_path $root $item]
        ::pis::common::require_file "Result file" $item
        lappend files $item
    }
    if {[llength $files] == 0} {
        error "No result files given"
    }
    set id [string trim [::pis::common::get $cfg layout id 19]]
    set windows ""
    if {[llength [info commands ::pis::hw::layout_windows]] > 0} {
        set windows [::pis::hw::layout_windows $id]
    }
    if {$windows eq ""} {
        error [format "layout id %s is not in the table" $id]
    }
    set n [llength $files]
    if {$n > $windows} {
        error [format "%d result file(s) exceed layout %s (%d windows)" $n $id $windows]
    }
    return [dict create model_file $model result_files $files \
        layout_id $id windows $windows]
}

# C1: the status bar AND the log get HyperView's own words for a failing load step - never a
# generic "failed". Shape: "<step> window <k> failed: <raw>", so the line names the step, the
# window and HyperView's REASON and nothing else (the adapter's own variant lines stay in the log
# above it, which is where a variant number belongs).
# T-019 item 4, two lengths on purpose: the LOG keeps the raw error in FULL (up to 300 characters,
# its own line) because that is the text a diagnosis needs; the STATUS BAR keeps 70 characters
# plus " (see log)". A cut that hides the method name ("...could not find requested method: ...")
# is exactly what made the owner's report unreadable.
proc ::pis::step01::raw_fail {step k err} {
    set raw [string map [list "\r" " " "\n" " "] [string trim $err]]
    while {[string first "  " $raw] >= 0} { set raw [string map [list "  " " "] $raw] }
    # The adapter's own message repeats the step, the window and the variant this line already
    # names; drop that prefix so the characters are spent on HyperView's REASON.
    regsub {^[A-Za-z_]+( window [0-9]+)? variant [0-9]+/[0-9]+ failed: } $raw {} raw
    set i [string first " | pick another variant" $raw]
    if {$i >= 0} { set raw [string range $raw 0 [expr {$i - 1}]] }
    if {[string trim $k] eq ""} {
        set head [format "%s failed" $step]
    } else {
        set head [format "%s window %s failed" $step $k]
    }
    set full $raw
    if {[string length $full] > 300} { set full "[string range $full 0 297]..." }
    set short $raw
    if {[string length $short] > 70} { set short "[string range $short 0 69].. (see log)" }
    set msg [format "%s: %s" $head $short]
    status_red "Error: $msg"
    if {[llength [info commands ::pis::common::log]] > 0} {
        catch {::pis::common::log "" ERROR [format "%s: %s" $head $full]}
    }
    return $msg
}

# ONE failing line in red at the bottom of the GUI (the shared sink has no colour argument, so the
# GUI proc is called with its own).
proc ::pis::step01::status_red {msg} {
    if {[llength [info commands ::pis::gui::set_status]] > 0} {
        catch {::pis::gui::set_status $msg red}
    } else {
        catch {::pis::hw::status $msg}
    }
    return
}

# One step of ONE window: the journal context first (so the comment names the window), then the
# adapter call. A failure is re-raised in the shape raw_fail builds, so the same text is in the
# log and in the status bar (SPEC.md error states).
proc ::pis::step01::window_call {k step label cmd} {
    ::pis::hw::context "Load All" [format "window %d: %s" $k $label]
    if {[catch {{*}$cmd} res]} {
        error [raw_fail $step $k $res]
    }
    return $res
}

# Window k, in this order and no other: ONE model, then ITS result, then the read-back.
# C2 (owner report 2, "results do not load"): a result is attached ONLY after the model of window
# k is verified (that window holds exactly 1 model). '<model> SetResult' on a window with no model
# changes nothing and says nothing (conrod/tcl_guide/hv_model_loader.tcl:1362-1400 attaches the
# result to a model handle and reports "no model is loaded in the window" at :1400), so attaching
# blind is the silent failure the owner saw. A window that cannot show its model stops there.
# The result step itself is the owner's working reference (F3): AddModel, model SetResult,
# client WaitForResults - that whole sequence lives in ::pis::hw::load_result_in_window, so this
# module keeps the one order it can check: model, model verified, result, result read back.
proc ::pis::step01::load_window {k model file} {
    window_call $k load_model [file tail $model] [list ::pis::hw::load_model_in_window $k $model]
    set have -1
    if {[catch {set have [::pis::hw::models_in_window $k]} why]} {
        error [raw_fail load_model $k $why]
    }
    if {$have != 1} {
        set msg [format "skip result: window %d has no model" $k]
        status_red "Error: $msg"
        if {[llength [info commands ::pis::common::log]] > 0} {
            catch {::pis::common::log "" ERROR $msg}
        }
        error $msg
    }
    window_call $k load_result [file tail $file] [list ::pis::hw::load_result_in_window $k $file]
    if {[catch {::pis::hw::verify_window $k} why]} {
        set msg [format "window %d read-back failed: %s" $k [string trim $why]]
        status_red "Error: $msg"
        error $msg
    }
    return $k
}

# One window of the run, and the owner's "which windows were not attempted" tail (T-019 item 5).
# The loop still STOPS at the first failing window (SPEC.md error states); what changes is that the
# message now says what that decision left out - on the pass-11 report only window 1 had been
# touched and nothing in the log said so.
proc ::pis::step01::load_window_guarded {k total model file} {
    if {[catch {load_window $k $model $file} why]} {
        set msg [string trim $why]
        if {$k < $total} {
            append msg [format "; windows %d..%d not attempted" [expr {$k + 1}] $total]
        }
        if {[llength [info commands ::pis::common::log]] > 0} {
            catch {::pis::common::log "" ERROR "Load All stopped at window $k: $msg"}
        }
        error $msg
    }
    return $k
}

# Validate first (SPEC.md A6/A7: a rejected input sends nothing and journals nothing), then
# the adapter steps in the order ::pis::hw::order names:
#   order 1 (default): reset -> grid -> for k = 1..N: model k, result k
#   order 2:           reset -> window 1 -> grid -> for k = 2..N: model k, result k
# "Loaded" is only reported when EVERY window passed its own read-back; one failing window
# stops the run with that window's number, its step name and the variants that were tried.
# Returns the number of windows (one per result file). The state is opened and closed inside
# this proc, so a failed run leaves last_result/loaded at 0 and every later module still
# refuses to apply (SPEC.md error states).
proc ::pis::step01::load_all {cfg} {
    variable last_result
    variable loaded
    need_common
    need_adapter
    if {![dict exists $cfg root]} {
        error "::pis::step01::load_all: cfg has no root (load it with ::pis::common::load_config)"
    }
    set info [validate [dict get $cfg root] $cfg]
    set model [dict get $info model_file]
    set files [dict get $info result_files]
    set lid [dict get $info layout_id]
    set windows [dict get $info windows]
    set n [llength $files]
    set base [file tail $model]
    set last_result 0
    set loaded 0
    set order [::pis::hw::order]
    ::pis::common::log $cfg INFO [format "Load All: %s + %d result file(s) into layout id %s (%d window(s), order %d)" \
        $base $n $lid $windows $order]
    ::pis::hw::status [format "Load All: order %d, layout id %s, %d window(s)" $order $lid $n]
    # T-019: the OPTIONAL result wait explains itself once per RUN, not once per window.
    ::pis::hw::begin_run
    # An ALREADY EMPTY session is not a failure: on an empty page the "0 models" check passes
    # without proving the delete verb, so ::pis::hw::reset_session_soft keeps the run alive
    # there and still reports a page that really keeps its models.
    call "Load All" "reset session" [list ::pis::hw::reset_session_soft]
    if {$order == 2} {
        # Window 1 is filled while the page still has the window it starts with, then the
        # grid is built, then the other windows. Order 2 exists for a build that drops the
        # models of a rebuilt page; the per-window read-back decides, not the order.
        load_window_guarded 1 $n $model [lindex $files 0]
        call "Load All" [format "layout id %s" $lid] \
            [list ::pis::hw::make_grid $lid]
        set k 1
        foreach f [lrange $files 1 end] {
            incr k
            load_window_guarded $k $n $model $f
        }
    } else {
        call "Load All" [format "layout id %s" $lid] \
            [list ::pis::hw::make_grid $lid]
        set k 0
        foreach f $files {
            incr k
            load_window_guarded $k $n $model $f
        }
    }
    set last_result $n
    set loaded 1
    ::pis::common::log $cfg OK [format "Load All: %d window(s) loaded" $n]
    return $n
}

# Reset (New): the adapter's own reset step and nothing else. No cfg is involved, so the
# caller (the GUI) owns the log line; the journal keeps this step's comment + hwc line, which
# is what makes a replay clear the session the same way (SPEC.md A2-A4).
proc ::pis::step01::reset_session {} {
    variable last_result
    variable loaded
    need_adapter
    call "Reset (New)" "reset session" [list ::pis::hw::reset_session]
    set last_result 0
    set loaded 0
    return 1
}

# 0|1: has a Load All completed in this session? Same value as the ::pis::step01::loaded
# variable that T-007's legend seam reads, so the two can never disagree.
proc ::pis::step01::loaded {} {
    variable loaded
    return $loaded
}
