# src/01_scripts/_tcl_pis_03_load_result.tcl
# ::pis::result - the "Load result" module (task T-008): display the typed result type
# (contour data type) in the targeted window(s).
# Tcl/Tk 8.5 compatible, no tcllib, no network, no package require.
# Sourcing this file defines procs only: it never calls HyperView.
#
# The HyperView form is NAMED AND DOCUMENTED FIRST, in docs/refs/HV_API.md section 11
# (T-008's 2026-11-11 amendment), before a single line of this file was written:
#   poIResultCtrl GetContourCtrlHandle (S31) -> poIContourCtrl SetDataType (S28)
#   read-back: poIResultCtrl GetDataTypeList (S30) BEFORE, poIContourCtrl GetDataType (S29) AFTER
#   window index of the "active" scope: hwIPage GetActiveWindow (S33)
# The supplier's own Error field on S28 says SetDataType ALWAYS answers success, even for a name
# that is not in the file (the contour just stays gray), so "no error" is not success here either:
# the step is judged by the two read-backs above.
#
# The ONE seam: ::pis::result::apply_to_window {cfg index name}
#   - the only place that touches a window or a contour control, and the only place that
#     sends SetDataType (through ::pis::hw::exec_hwi, so the proven line lands in the journal);
#   - index >= 1 = that window of the layout; index < 0 = "leave the active window alone"
#     (the per-module button path, SPEC_gui s.5), its index read with GetActiveWindow (S33).
#
# Public procs:
#   ::pis::result::run {root cfg scope}             -> windows changed (0 = nothing run)
#   ::pis::result::apply_to_window {cfg index name} -> {window type} for ONE window
#   ::pis::result::targets {cfg scope}              -> window indexes to apply to
#   ::pis::result::selected_item {cfg}              -> [result] item<selected>, "" when none
#   ::pis::result::window_file {cfg index}          -> result file Load All put in window <index>
#   ::pis::result::match {labels name}              -> the file's own spelling of <name>, "" if absent
#   ::pis::result::script {index tail}              -> one hwi script: chain + tail + close
#   ::pis::result::probe_script {index}             -> read-only chain answering {win {labels}}
#   ::pis::result::reset_state {}                   -> counters back to 0 (tests)
# Namespace variables: applied (last run), calls, last_window, last_type, readback

namespace eval ::pis::result {
    if {![info exists applied]} { set applied 0 }
    if {![info exists calls]} { set calls 0 }
    if {![info exists last_window]} { set last_window "" }
    if {![info exists last_type]} { set last_type "" }
    if {![info exists readback]} { set readback "" }
    if {![info exists answer]} { set answer "" }
}

# The module title exactly as the GUI shows it: it goes into the journal comment and the
# WARN required by SPEC.md A8 ("module <name>: no item selected, nothing run").
proc ::pis::result::title {} {
    return "Load result"
}

# Offline this file is useless without ::pis::common; say so instead of a confusing error.
proc ::pis::result::need_common {} {
    foreach p {load_config get resolve_path log to_bool} {
        if {[llength [info commands ::pis::common::$p]] == 0} {
            error "::pis::result: source _tcl_pis_00_common.tcl first (missing ::pis::common::$p)"
        }
    }
    return
}

# The handle chain and the journal door are the adapter's (T-002c): this module COMPOSES a
# script with the adapter's builders and sends it through the adapter's door procs, so the
# hwi spelling still lives in exactly one file.
proc ::pis::result::need_hw {} {
    foreach p {exec_hwi probe journal_run context stack_open window_close quote} {
        if {[llength [info commands ::pis::hw::$p]] == 0} {
            error "::pis::result: source _tcl_pis_10_hw.tcl and _tcl_pis_11_hw_adapter.tcl first (missing ::pis::hw::$p)"
        }
    }
    return
}

# One window, up to its result controller, in the supplier's own order (docs/refs/HV_API.md
# section 11, the S28 example + S33). The body is sent through exec_hwi/probe, where every line
# is ONE complete command and the newlines are folded, so no line may start with a comment.
# '@idx@' is the requested window index; a negative value asks the page for the active one.
# pisRIdx is the index the chain really used: the log, the error text and the file lookup all
# use that value, never the value the caller guessed.
proc ::pis::result::script {index tail} {
    ::pis::result::need_hw
    if {![string is integer -strict $index]} {
        error "::pis::result::script: window index must be an integer, got: $index"
    }
    set head {set pisRIdx @idx@
if {@idx@ < 0} { set pisRIdx [pisPage GetActiveWindow] }
if {![string is integer -strict $pisRIdx] || $pisRIdx < 1} { error "no window index (GetActiveWindow answered '$pisRIdx')" }
pisPage GetWindowHandle pisWin $pisRIdx
pisWin GetClientHandle pisC
set pisRMid [pisC GetActiveModel]
if {![string is integer -strict $pisRMid] || $pisRMid <= 0} { error "window $pisRIdx has no model id (GetActiveModel answered '$pisRMid')" }
pisC GetModelHandle pisM $pisRMid
pisM GetResultCtrlHandle pisR}
    set body [string map [list @idx@ $index] $head]
    return "[::pis::hw::stack_open pis]\n$body\n$tail\n[::pis::hw::window_close pis]"
}

# The read-only half: which window, and which data type labels its result file really holds
# (S30). The answer lands in variable answer ({window_index {labels}}) because the script has to
# CLOSE the stack after it (the last command of a folded script is the close, whose own result is
# empty), exactly like the adapter's own read-backs do. An empty label list means "no subcase in
# the file", i.e. the result file is not attached to that window.
proc ::pis::result::probe_script {index} {
    set tail {set pisRSub 1
catch {set pisRSub [lindex [pisR GetSubcaseList] 0]}
if {![string is integer -strict $pisRSub] || $pisRSub < 1} { set pisRSub 1 }
set ::pis::result::answer [list $pisRIdx [pisR GetDataTypeList $pisRSub]]}
    return [::pis::result::script $index $tail]
}

# The file's own spelling of the typed name, or "" when the file does not hold it. An exact
# match wins; a case-insensitive one is accepted and the FILE's spelling is what gets sent, so
# the read-back (S29) can be compared with the label the file reported (S30).
proc ::pis::result::match {labels name} {
    set want [string trim $name]
    if {$want eq ""} { return "" }
    foreach label $labels {
        if {$label eq $want} { return $label }
    }
    foreach label $labels {
        if {[string equal -nocase $label $want]} { return $label }
    }
    return ""
}

# The result file Load All attached to window <index>: the ini keeps one path per line and
# step01 loads line k into window k (1:1, in order), so the index IS the line number. "" when
# the ini does not know that window (the active window of a hand-made layout, for example).
proc ::pis::result::window_file {cfg index} {
    ::pis::result::need_common
    if {![dict exists $cfg session]} { return "" }
    if {[catch {set paths [::pis::common::get $cfg session result_files ""]}]} { return "" }
    if {![string is integer -strict $index] || $index < 1 || $index > [llength $paths]} { return "" }
    set item [string trim [lindex $paths [expr {$index - 1}]]]
    if {$item eq ""} { return "" }
    if {[catch {set root [dict get $cfg root]}]} { set root "" }
    if {[catch {return [::pis::common::resolve_path $root $item]}]} { return $item }
    return $item
}

# The radio selection of [result]: index 1..count in the ini, "" when nothing is selected.
proc ::pis::result::selected_item {cfg} {
    ::pis::result::need_common
    set sel [string trim [::pis::common::get $cfg result selected -1]]
    if {![string is integer -strict $sel] || $sel < 1} {
        return ""
    }
    if {![dict exists $cfg result]} {
        return ""
    }
    set key "item$sel"
    if {![dict exists [dict get $cfg result] $key]} {
        return ""
    }
    return [string trim [dict get [dict get $cfg result] $key]]
}

# Windows a run must change. scope "layout" = every window Load All created (1..N in layout
# order); anything else = the active window only (-1 = do not reselect it, S33 reveals its
# index inside the script).
proc ::pis::result::targets {cfg scope} {
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

# THE SEAM: one window, one result type. Nothing is journaled before the read-back proved the
# contour really changed (SPEC.md A2-A4: a command that changed nothing must never reach a
# saved journal), and a type the file does not hold never reaches HyperView at all.
# Answers {window type}; raises the SPEC_gui s.6.1 message when the name is not in the file.
proc ::pis::result::apply_to_window {cfg index name} {
    variable answer
    variable calls
    variable last_window
    variable last_type
    variable readback
    ::pis::result::need_common
    ::pis::result::need_hw
    set want [string trim $name]
    if {$want eq ""} {
        error "::pis::result::apply_to_window: empty result name"
    }
    if {![string is integer -strict $index]} {
        error "::pis::result::apply_to_window: window index must be an integer, got: $index"
    }
    set slot [expr {$index < 0 ? "the active window" : "window $index"}]
    # 1. read-back FIRST (S30). A build that swallows an unknown data type would only paint the
    #    contour gray (S28), so the membership question is asked BEFORE anything is sent.
    set answer ""
    if {[catch {::pis::hw::probe [::pis::result::probe_script $index]} why]} {
        error [format "%s: no result read-back yet (%s) | click Load All first" \
            $slot [string trim $why]]
    }
    set probe [string trim $answer]
    if {[llength $probe] < 2} {
        error [format "%s: the result read-back answered nothing ('%s')" $slot $probe]
    }
    lassign $probe win labels
    if {![string is integer -strict $win] || $win < 1} {
        set win [expr {$index < 0 ? 0 : $index}]
    }
    set rfile [::pis::result::window_file $cfg $win]
    if {$rfile eq ""} {
        set shown "the loaded result file"
    } else {
        set shown $rfile
    }
    if {[llength $labels] == 0} {
        error [format "window %s: the result file holds no data type (%s) | did Load All attach it?" \
            $win $shown]
    }
    set type [::pis::result::match $labels $want]
    if {$type eq ""} {
        error [format "result '%s' not found in %s" $want $shown]
    }
    # 2. the step itself (S28), then 3. the read-back (S29) that decides whether it worked.
    set set_script [::pis::result::script $index \
        "pisR GetContourCtrlHandle pisCt\npisCt SetDataType [::pis::hw::quote $type]"]
    set code [catch {::pis::hw::exec_hwi $set_script -nojournal} res opts]
    if {$code} {
        return -options $opts $res
    }
    set readback ""
    set rb_err ""
    catch {
        # The square brackets are escaped: this text is DATA for HyperView, not a command to
        # run here (a bare [pisCt GetDataType] would run in THIS proc and fail: no such handle).
        ::pis::hw::probe [::pis::result::script $index \
            "pisR GetContourCtrlHandle pisCt\nset ::pis::result::readback \[pisCt GetDataType\]"]
    } rb_err
    set got [string trim $readback]
    if {$got ne $type} {
        set why ""
        if {[string trim $rb_err] ne ""} {
            set why "; read-back error: [string trim $rb_err]"
        }
        error [format "window %s: the read-back refused '%s' (GetDataType answered '%s'%s) | the contour did not change" \
            $win $type $got $why]
    }
    ::pis::hw::context [::pis::result::title] $type
    ::pis::hw::journal_run $set_script
    incr calls
    set last_window $win
    set last_type $type
    return [list $win $type]
}

# Run the module once. SPEC_gui s.6.1 + s.7: the selected type is applied to the targeted
# window(s); an unknown name is ONE ERROR and stops the run, unless `log continue_on_error` is
# set in the cfg (SPEC_gui s.9 stores that switch; the panel button is T-012).
# Returns the number of windows changed (0 = nothing run, already logged).
proc ::pis::result::run {root cfg scope} {
    variable applied
    ::pis::result::need_common
    if {$scope ne "layout" && $scope ne "active"} {
        error "::pis::result::run: unknown scope '$scope' (expected active or layout)"
    }
    set name [::pis::result::selected_item $cfg]
    if {$name eq ""} {
        set applied 0
        ::pis::common::log $cfg WARN "module [::pis::result::title]: no item selected, nothing run"
        return 0
    }
    set cont 0
    if {[catch {
        set cont [::pis::common::to_bool \
            [::pis::common::get $cfg log continue_on_error 0] "log continue_on_error"]
    }]} {
        set cont 0
    }
    set windows [::pis::result::targets $cfg $scope]
    set n 0
    foreach index $windows {
        set code [catch {::pis::result::apply_to_window $cfg $index $name} res]
        if {$code} {
            if {!$cont} {
                error [string trim $res]
            }
            ::pis::common::log $cfg ERROR "[::pis::result::title]: [string trim $res]"
            continue
        }
        lassign $res win type
        set rfile [::pis::result::window_file $cfg $win]
        if {$rfile eq ""} {
            ::pis::common::log $cfg INFO "[::pis::result::title]: window $win <- $type"
        } else {
            ::pis::common::log $cfg INFO "[::pis::result::title]: window $win <- $type ($rfile)"
        }
        incr n
    }
    set applied $n
    ::pis::common::log $cfg OK "[::pis::result::title]: $n window(s) <- $name"
    return $n
}

# Counters back to zero; used by tests/tcl/test_result.tcl between cases.
proc ::pis::result::reset_state {} {
    variable applied
    variable calls
    variable last_window
    variable last_type
    variable readback
    set applied 0
    set calls 0
    set last_window ""
    set last_type ""
    set readback ""
    return
}
