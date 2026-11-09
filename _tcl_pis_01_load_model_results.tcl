# PIS Workflow - block 0 step script: load ONE model + N result files (task T-006).
# ::pis::step01 owns the validation and the ONLY door to the ::MaxStress library.
# Tcl/Tk 8.5 compatible, no tcllib, no network, no package require, no Tk.
# Sourcing this file defines procs only: it never touches HyperView.
#
# Library calls and the journal (SPEC_gui s.8 vs SPEC.md D2):
#   ::MaxStress::ResetSession / ::MaxStress::LoadAll are Tcl procs of the user's
#   library, not "hwc" commands, so they are NOT journaled: the journal keeps
#   `hwc ` and `#` lines only (SPEC.md A2/A3). They go through ONE helper,
#   ::pis::step01::lib_call, and show up in the display log (INFO/OK/ERROR).
#
# Procs | params | call sites
#   ::pis::step01::need_common {}             | validate, ensure_lib
#   ::pis::step01::lib_call {name args}       | run (LoadAll), reset (ResetSession)
#   ::pis::step01::define_stubs {script_dir}  | ensure_lib (allow_stub only)
#   ::pis::step01::ensure_lib {root cfg}      | run, reset
#   ::pis::step01::validate {root cfg}        | run
#   ::pis::step01::run {root cfg}             | ::pis::gui::run_block0
#   ::pis::step01::reset {root cfg}           | ::pis::gui::run_block0
# Namespace variables read by later tasks: last_result (windows from the last
# LoadAll), loaded (0|1), stub_mode (0|1), lib_path (resolved library path).

namespace eval ::pis::step01 {
    variable last_result 0
    variable loaded 0
    variable stub_mode 0
    variable lib_path ""
}
# ::pis::common is the only config/path/log layer (T-004); fail loudly if missing.
proc ::pis::step01::need_common {} {
    if {[llength [info commands ::pis::common::get]] == 0} {
        error "::pis::step01 needs ::pis::common: source _tcl_pis_00_common.tcl first"
    }
    return
}

# The single door to the user library. A missing proc or a failing call names the
# proc and the resolved library path; nothing is swallowed.
proc ::pis::step01::lib_call {name args} {
    variable lib_path
    set cmd "::MaxStress::$name"
    if {[llength [info commands $cmd]] == 0} {
        error "MaxStress library $lib_path does not define $cmd"
    }
    if {[catch {uplevel #0 [list $cmd {*}$args]} res]} {
        error "MaxStress $name failed: $res"
    }
    return $res
}

# Debug stubs, only when the library file is missing AND allow_stub is true.
proc ::pis::step01::define_stubs {script_dir} {
    if {![namespace exists ::MaxStress]} {
        namespace eval ::MaxStress { variable LIB_DIR "" }
    }
    namespace eval ::MaxStress [list variable LIB_DIR $script_dir]
    if {[llength [info commands ::MaxStress::ResetSession]] == 0} {
        proc ::MaxStress::ResetSession {} {
            puts "DEBUG: ResetSession called"
            return 1
        }
    }
    if {[llength [info commands ::MaxStress::LoadAll]] == 0} {
        proc ::MaxStress::LoadAll {modelFile resultFiles cols rows} {
            puts "DEBUG: LoadAll -> model=$modelFile files=$resultFiles cols=$cols rows=$rows"
            return [llength $resultFiles]
        }
    }
    return 1
}

# Locate and load the library named by [maxstress] lib_file (relative to script_dir
# unless absolute). Missing file: hard error unless allow_stub is true, in which case
# STUB MODE is announced in the log. A broken file is always an error.
proc ::pis::step01::ensure_lib {root cfg} {
    variable lib_path
    variable stub_mode
    need_common
    set script_dir [::pis::common::resolve_path $root \
        [::pis::common::get $cfg folders script_dir 01_scripts]]
    set rel [::pis::common::get $cfg maxstress lib_file maxstress_lib.tcl]
    if {[file pathtype $rel] eq "absolute"} {
        set lib_path [file normalize $rel]
    } else {
        set lib_path [file normalize [file join $script_dir $rel]]
    }
    set allow [::pis::common::to_bool \
        [::pis::common::get $cfg maxstress allow_stub 0] "maxstress allow_stub"]
    if {[file isfile $lib_path]} {
        if {[catch {uplevel #0 [list source $lib_path]} err]} {
            error "Cannot source MaxStress library $lib_path: $err"
        }
        set stub_mode 0
    } elseif {$allow} {
        define_stubs $script_dir
        set stub_mode 1
        ::pis::common::log $cfg WARN "STUB MODE: MaxStress library not found: $lib_path"
    } else {
        error "MaxStress library not found: $lib_path"
    }
    foreach name {ResetSession LoadAll} {
        if {[llength [info commands ::MaxStress::$name]] == 0} {
            error "MaxStress library $lib_path does not define ::MaxStress::$name"
        }
    }
    return $lib_path
}

# Every block-0 rule with its specific message (SPEC.md error/empty states).
# Returns {model_file result_files cols rows} with absolute paths and integers.
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

# Validate, load the library, then one LoadAll. Returns the window count and stores
# it in last_result (loaded = 1 when at least one window was created).
proc ::pis::step01::run {root cfg} {
    variable last_result
    variable loaded
    set info [validate $root $cfg]
    ensure_lib $root $cfg
    set model [dict get $info model_file]
    set files [dict get $info result_files]
    set cols [dict get $info cols]
    set rows [dict get $info rows]
    set windows [lib_call LoadAll $model $files $cols $rows]
    if {![string is integer -strict $windows] || $windows < 0} {
        error "::MaxStress::LoadAll returned a non-integer: $windows"
    }
    set last_result $windows
    set loaded [expr {$windows > 0 ? 1 : 0}]
    ::pis::common::log $cfg INFO [format "LoadAll: %s | %d result file(s) | %dx%d | %d window(s)" \
        $model [llength $files] $cols $rows $windows]
    return $windows
}

# Reset (New): one ResetSession call, then a clean state.
proc ::pis::step01::reset {root cfg} {
    variable last_result
    variable loaded
    ensure_lib $root $cfg
    lib_call ResetSession
    set last_result 0
    set loaded 0
    ::pis::common::log $cfg OK "Session reset"
    return 1
}


