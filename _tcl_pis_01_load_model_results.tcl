# PIS Workflow - block 0: load ONE model + N result files into a cols x rows window grid
# (task T-006). SPEC.md D2: plain HyperView commands only - no user library, no stub mode,
# no bare hwc line in this file. Every command comes from the ::pis::hw adapter (T-002c), so
# a saved journal replays Load All and Reset (New) in a fresh session (SPEC.md A2-A4).
# Tcl/Tk 8.5 compatible, no tcllib, no network, no package require, no Tk.
# Sourcing this file defines procs only: it never touches HyperView.
#
# Procs | params | call sites
#   ::pis::step01::need_common {}         | load_all
#   ::pis::step01::need_adapter {}        | load_all, reset_session
#   ::pis::step01::call {module item cmd} | load_all, reset_session
#   ::pis::step01::validate {root cfg}    | load_all
#   ::pis::step01::load_all {cfg}         | ::pis::gui::run_block0
#   ::pis::step01::reset_session {}       | ::pis::gui::run_block0
#   ::pis::step01::loaded {}              | a module's "click Load All first" gate
# Namespace variables later tasks read (the proc ::pis::step01::loaded returns the same
# value as the variable, so the two can never disagree):
#   last_result (windows created by the last Load All), loaded (0|1)

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
    foreach name {reset_session load_model make_grid load_result_in_window} {
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
# the wording). Returns {model_file result_files cols rows} with absolute paths and integers.
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
    set cols [string trim [::pis::common::get $cfg layout cols 4]]
    set rows [string trim [::pis::common::get $cfg layout rows 2]]
    if {![string is integer -strict $cols] || ![string is integer -strict $rows]} {
        error "Layout must be two integers (e.g. 4 x 2), got: $cols x $rows"
    }
    if {$cols <= 0 || $rows <= 0} {
        error "Layout values must be greater than 0, got: $cols x $rows"
    }
    set max [expr {$cols * $rows}]
    set n [llength $files]
    if {$n > $max} {
        error "$n result file(s) exceed layout ${cols}x${rows} (max $max)"
    }
    return [dict create model_file $model result_files $files cols $cols rows $rows]
}

# Validate first (SPEC.md A6/A7: a rejected input sends nothing and journals nothing), then
# the four adapter steps in the one order SPEC.md Q1/D2 names: reset the session, load the
# ONE model, build the cols x rows grid, load result file k into window k.
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
    set cols [dict get $info cols]
    set rows [dict get $info rows]
    set n [llength $files]
    set base [file tail $model]
    set last_result 0
    set loaded 0
    ::pis::common::log $cfg INFO [format "Load All: %s + %d result file(s) into %dx%d" \
        $base $n $cols $rows]
    call "Load All" "reset session" [list ::pis::hw::reset_session]
    call "Load All" "model $base" [list ::pis::hw::load_model $model]
    call "Load All" [format "window grid %dx%d" $cols $rows] \
        [list ::pis::hw::make_grid $cols $rows]
    set k 0
    foreach f $files {
        incr k
        call "Load All" [format "window %d: %s" $k [file tail $f]] \
            [list ::pis::hw::load_result_in_window $k $f]
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
