# src/01_scripts/_tcl_pis_03_load_result.tcl
# ::pis::result - the "Load result" module (task T-008, fixed by T-026): make the targeted
# window(s) really DISPLAY the typed result type (the contour data type).
# Tcl/Tk 8.5 compatible, no tcllib, no network, no package require.
# Sourcing this file defines procs only: it never calls HyperView.
#
# WHAT "APPLIED" MEANS (T-026, after the owner's `T-008: fail 2` on 2026-11-12: the log said the
# result was applied while the window's contour did not change). Every form below is named in
# docs/refs/HV_API.md section 11 FIRST, before it is used here:
#   set  : poIContourCtrl SetDimensionEnabled (S35) -> poIContourCtrl SetDataType (S28)
#          -> poIResultCtrl SetCurrentSubcase (S39, ONLY when the window has none)
#          -> <client> Draw on the CLIENT OF THAT WINDOW (PROVEN pattern 2 of HV_API_REF.md)
#   read : poIResultCtrl GetSubcaseList (S32) / GetDataTypeList (S30) / GetCurrentSubcase (S40) /
#          GetNumberOfSubcases (S27), poIContourCtrl GetDataType (S29) / GetDimensionEnabled (S36) /
#          GetDataComponent (S38)
# "no error" proves NOTHING here: S28 says SetDataType ALWAYS answers success (the contour just
# stays gray), and S35/S39 are silent no-ops on a build that ignores them. The step is judged by
# the READ-BACKS only, and a window that accepted every command without changing is an ERROR.
#
# Two steps stay UNVERIFIED-GUESS and are NOT invented:
#   - the data COMPONENT: S37 prints no value space, so GetDataComponent is READ and printed, and
#     SetDataComponent is never sent;
#   - poIContourCtrl SetEnabled (S41): its `pool` argument has no printed value, so it is the LAST
#     variant (variant 2) and is only tried after the documented form failed its read-back.
#
# The ONE seam: ::pis::result::apply_to_window {cfg index name}
#   - the only place that touches a window or a contour control, and the only place that sends a
#     state-changing command (through ::pis::hw::exec_hwi with -nojournal, so only a PASSING
#     variant reaches the journal through ::pis::hw::journal_run);
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
#   ::pis::result::script {index tail {select}}     -> one hwi script: chain + tail + close
#   ::pis::result::probe_script {index}             -> read-only chain answering the state probe
#   ::pis::result::read_state {index}               -> dict of the read-backs, raises if none
#   ::pis::result::verdict {st label}               -> {1 ""} when the window shows it, else {0 why}
#   ::pis::result::build_script {index plan variant} -> one hwi script: enable -> type -> subcase -> Draw
#   ::pis::result::plan {st label}                  -> what one window's script needs (label/enable/sub)
#   ::pis::result::variants {}                      -> the variant numbers, documented form first
#   ::pis::result::reset_state {}                   -> counters back to 0 (tests)
# Namespace variables: applied, calls, last_window, last_type, readback, state, variant, answer

namespace eval ::pis::result {
    if {![info exists applied]} { set applied 0 }
    if {![info exists calls]} { set calls 0 }
    if {![info exists last_window]} { set last_window "" }
    if {![info exists last_type]} { set last_type "" }
    if {![info exists readback]} { set readback "" }
    if {![info exists state]} { set state "" }
    if {![info exists variant]} { set variant 0 }
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
# hwi spelling still lives in exactly one file. `refresh` is the adapter's ONE `update idletasks`
# after a run (T-026).
proc ::pis::result::need_hw {} {
    foreach p {exec_hwi probe journal_run context stack_open window_close quote refresh} {
        if {[llength [info commands ::pis::hw::$p]] == 0} {
            error "::pis::result: source _tcl_pis_10_hw.tcl and _tcl_pis_11_hw_adapter.tcl first (missing ::pis::hw::$p)"
        }
    }
    return
}

# The three dimension labels of poIContourCtrl (S35/S36: "line", "shell", "solid"). They are the
# dimensions a contour can be enabled for, and GetDimensionEnabled is the only documented query
# that says whether the window will paint anything.
proc ::pis::result::dims {} {
    return {line shell solid}
}

# S36 answers "true if enabled, or false if disabled"; a build may spell it 1/0 or yes/on.
proc ::pis::result::is_true {value} {
    set v [string tolower [string trim $value]]
    return [expr {$v eq "1" || $v eq "true" || $v eq "yes" || $v eq "on"}]
}

# One window, up to its result controller, in the supplier's own order (docs/refs/HV_API.md
# section 11; the supplier's S28 example plus S5/S33). The body is sent through exec_hwi/probe,
# where every line is ONE complete command and the newlines are folded, so no line may start with
# a comment and no line may hold only the head of a braced block.
# '@idx@' is the requested window index; a negative value asks the page for the active one.
# <select> 1 first makes that window the ACTIVE one (hwIPage SetActiveWindow, S5): S9 warns that
# result commands do not run while the active window is not a HyperView window, so the window the
# handles belong to must also be the selected one. A read-only probe passes 0 and changes nothing.
# pisRIdx is the index the chain really used: the log, the error text and the file lookup all use
# that value, never the value the caller guessed.
proc ::pis::result::script {index tail {select 0}} {
    ::pis::result::need_hw
    if {![string is integer -strict $index]} {
        error "::pis::result::script: window index must be an integer, got: $index"
    }
    set sel ""
    if {$select} {
        set sel "pisPage SetActiveWindow \$pisRIdx\n"
    }
    set head {set pisRIdx @idx@
if {@idx@ < 0} { set pisRIdx [pisPage GetActiveWindow] }
if {![string is integer -strict $pisRIdx] || $pisRIdx < 1} { error "no window index (GetActiveWindow answered '$pisRIdx')" }
@select@pisPage GetWindowHandle pisWin $pisRIdx
pisWin GetClientHandle pisC
set pisRMid [pisC GetActiveModel]
if {![string is integer -strict $pisRMid] || $pisRMid <= 0} { error "window $pisRIdx has no model id (GetActiveModel answered '$pisRMid')" }
pisC GetModelHandle pisM $pisRMid
pisM GetResultCtrlHandle pisR}
    set body [string map [list @idx@ $index @select@ $sel] $head]
    return "[::pis::hw::stack_open pis]\n$body\n$tail\n[::pis::hw::window_close pis]"
}

# The read-only half: the window index, the data type the contour shows now (S29), the state of
# the three dimensions (S36), the current subcase (S40), how many subcases the file has (S27), the
# data component (S38) and the data type labels the file really holds (S30). The answer lands in
# variable answer because the script has to CLOSE the stack after it (the last command of a folded
# script is the close, whose own result is empty), exactly like the adapter's read-backs do.
# EVERY optional read is inside its own catch: a build that lacks GetDimensionEnabled (an older
# release) or GetDataComponent must still answer the rest, and an empty value means "this build
# did not answer", never "disabled".
proc ::pis::result::probe_script {index} {
    set tail {set pisRSubs ""
catch {set pisRSubs [pisR GetSubcaseList]}
set pisRSub 1
catch {set pisRSub [lindex $pisRSubs 0]}
if {![string is integer -strict $pisRSub] || $pisRSub < 1} { set pisRSub 1 }
set pisRLabels ""
catch {set pisRLabels [pisR GetDataTypeList $pisRSub]}
pisR GetContourCtrlHandle pisCt
set pisRDt ""
catch {set pisRDt [pisCt GetDataType]}
set pisRDims ""
foreach pisRD {line shell solid} { set pisRV ""; catch {set pisRV [pisCt GetDimensionEnabled $pisRD]}; lappend pisRDims $pisRV }
set pisRCur ""
catch {set pisRCur [pisR GetCurrentSubcase]}
set pisRN ""
catch {set pisRN [pisR GetNumberOfSubcases]}
set pisRComp ""
catch {set pisRComp [pisCt GetDataComponent shell]}
set ::pis::result::answer [list $pisRIdx $pisRDt $pisRDims $pisRCur $pisRN $pisRComp $pisRSubs $pisRLabels]}
    return [::pis::result::script $index $tail 0]
}

# Run the probe and answer it as a dict: win type dims subcase nsub component subs labels.
# Raises (with the build's own message) when the chain itself cannot be walked - no model, no
# result attached, no contour control - because then there is nothing to judge.
proc ::pis::result::read_state {index} {
    variable answer
    variable readback
    set answer ""
    set why ""
    if {[catch {::pis::hw::probe [::pis::result::probe_script $index]} why]} {
        error [string trim $why]
    }
    set got [string trim $answer]
    if {[llength $got] < 8} {
        error "the result read-back answered nothing ('$got')"
    }
    lassign $got win dtype dims cur n comp subs labels
    set readback $dtype
    return [dict create win $win type $dtype dims $dims subcase $cur nsub $n \
        component $comp subs $subs labels $labels]
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
    if {![string is integer -strict $index] || $index < 1} { return "" }
    set paths ""
    if {[catch {set paths [::pis::common::get $cfg session result_files ""]}]} { return "" }
    set lines [list]
    foreach line [split $paths "\n"] {
        set line [string trim $line]
        if {$line eq ""} { continue }
        lappend lines $line
    }
    if {$index > [llength $lines]} { return "" }
    return [lindex $lines [expr {$index - 1}]]
}

# The [result] item the radio list has selected, "" when nothing is selected. The ini stores a
# 1-based `selected`, so item1 is selected = 1 (SPEC.md A8: no item = one WARN, nothing run).
proc ::pis::result::selected_item {cfg} {
    ::pis::result::need_common
    if {![dict exists $cfg result]} { return "" }
    set sel 0
    catch {set sel [::pis::common::get $cfg result selected 0]}
    if {![string is integer -strict $sel] || $sel < 1} { return "" }
    set key "item$sel"
    if {![dict exists [dict get $cfg result] $key]} { return "" }
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

# The dimension labels the window does NOT already report as enabled (S36). A dimension that reads
# "" could not be asked (an older build), and is treated as not proven enabled, so the documented
# enable step (S35) runs for it; enabling a dimension that is already on is a no-op.
proc ::pis::result::enable_list {st} {
    set out [list]
    set dims [dict get $st dims]
    set i 0
    foreach d [::pis::result::dims] {
        set v [lindex $dims $i]
        incr i
        if {![::pis::result::is_true $v]} {
            lappend out $d
        }
    }
    return $out
}

# The subcase the script must set, or "": "" whenever the window ALREADY has one - an existing
# subcase is never changed. When it has none, the first id of GetSubcaseList (S32) is used, or 1
# when that list is unreadable and GetNumberOfSubcases (S27) says there is at least one.
proc ::pis::result::subcase_step {st} {
    set cur [dict get $st subcase]
    if {[string is integer -strict $cur] && $cur >= 1} {
        return ""
    }
    foreach id [dict get $st subs] {
        if {[string is integer -strict $id] && $id >= 1} {
            return $id
        }
    }
    set n [dict get $st nsub]
    if {[string is integer -strict $n] && $n > 0} {
        return 1
    }
    return ""
}

# "line=true,shell=true,solid=?" - the read state of the three dimensions, ? = this build did not
# answer GetDimensionEnabled for that label.
proc ::pis::result::enabled_text {st} {
    set out [list]
    set dims [dict get $st dims]
    set i 0
    foreach d [::pis::result::dims] {
        set v [string trim [lindex $dims $i]]
        incr i
        if {$v eq ""} { set v "?" }
        lappend out "$d=$v"
    }
    return [join $out ","]
}

# What a read-back answered, in the order the log line needs it.
proc ::pis::result::values_text {st} {
    set comp [string trim [dict get $st component]]
    if {$comp eq ""} { set comp "?" }
    return [format "type=%s enabled=%s subcase=%s component=%s" \
        [dict get $st type] [::pis::result::enabled_text $st] [dict get $st subcase] $comp]
}

# The ONE line a passing window leaves in the log (SPEC.md A10, T-026):
#   result window 1: type=Stress enabled=line=true,shell=true,solid=true subcase=1 component=?
proc ::pis::result::line_text {win st} {
    return [format "result window %s: %s" $win [::pis::result::values_text $st]]
}

# The ONE sentence a window that took every command and changed nothing leaves behind: the window,
# the requested name and EVERY value read, in full - never a summary and never a cut.
proc ::pis::result::fail_text {win name st why} {
    set comp [string trim [dict get $st component]]
    if {$comp eq ""} { set comp "?" }
    return [format "result window %s: '%s' not displayed (type='%s' enabled='%s' subcase='%s' component='%s') | %s" \
        $win $name [dict get $st type] [::pis::result::enabled_text $st] \
        [dict get $st subcase] $comp $why]
}

# Is the window DISPLAYING the requested label? Answers {1 ""} or {0 <why>}, and only the
# documented read-backs of docs/refs/HV_API.md section 11 decide:
#   - GetDataType (S29) must answer the label the file spells;
#   - at least one dimension must read enabled (S36) WHEN this build answers S36 at all - a build
#     that does not answer it is a NOTE in the log, not a pass and not a failure;
#   - a current subcase (S40) must exist when GetNumberOfSubcases (S27) says the file has one.
proc ::pis::result::verdict {st label} {
    set why [list]
    set got [string trim [dict get $st type]]
    if {$got ne $label} {
        lappend why "GetDataType (S29) answered '$got', not '$label'"
    }
    set known 0
    set on 0
    set dims [dict get $st dims]
    set i 0
    foreach d [::pis::result::dims] {
        set v [lindex $dims $i]
        incr i
        if {[string trim $v] ne ""} { set known 1 }
        if {[::pis::result::is_true $v]} { set on 1 }
    }
    if {$known && !$on} {
        lappend why "no contour dimension is enabled (GetDimensionEnabled, S36)"
    }
    set n [dict get $st nsub]
    if {[string is integer -strict $n] && $n > 0} {
        set cur [dict get $st subcase]
        if {![string is integer -strict $cur] || $cur < 1} {
            lappend why "GetCurrentSubcase (S40) answered '$cur' while the file holds $n subcase(s)"
        }
    }
    if {[llength $why] == 0} {
        return [list 1 ""]
    }
    return [list 0 [join $why "; "]]
}

# The variant list, documented form FIRST: 1 = exactly the sequence of docs/refs/HV_API.md section
# 11 (S5, S35, S28, S39, Draw); 2 = the same plus poIContourCtrl SetEnabled (S41, UNVERIFIED-GUESS:
# its `pool` argument has no printed value). A variant that fails the read-back falls through to
# the next one; the LAST variant's failure text is the one raised.
proc ::pis::result::variants {} {
    return [list 1 2]
}

# The apply script of one window: the chain of <index> + the state-changing lines of <variant>,
# in the documented order. Built with the adapter's builders, so the handle chain and the journal
# spelling stay in one file; the script is sent with -nojournal and journaled only after the
# read-back proved it (SPEC.md A2-A4: a command that changed nothing must never reach a journal).
proc ::pis::result::build_script {index plan variant} {
    set lines [list "pisR GetContourCtrlHandle pisCt"]
    foreach d [dict get $plan enable] {
        lappend lines "pisCt SetDimensionEnabled $d 1"
    }
    if {$variant >= 2} {
        lappend lines "pisCt SetEnabled 1 1"
    }
    lappend lines "pisCt SetDataType [::pis::hw::quote [dict get $plan label]]"
    set sub [dict get $plan sub]
    if {$sub ne ""} {
        lappend lines "pisR SetCurrentSubcase $sub"
    }
    lappend lines "pisC Draw"
    return [::pis::result::script $index [join $lines "\n"] 1]
}

# Everything one window's apply script needs, in one dict:
#   label  - the file's spelling of the requested type (sent, and compared in the read-back)
#   enable - the dimensions to enable first (S35), only the ones not proven enabled
#   sub    - the subcase to set (S39), "" when the window already has one
proc ::pis::result::plan {st label} {
    return [dict create label $label \
        enable [::pis::result::enable_list $st] \
        sub [::pis::result::subcase_step $st]]
}

# THE SEAM. Bring ONE window to "shows <name>" and prove it with the read-backs, or raise with every
# value read. Order (docs/refs/HV_API.md section 11, T-026):
#   1. read the window first, so the decision is never taken on a guess;
#   2. find <name> in the data type labels the file itself reported (S30) - an unknown name stops
#      here, before any SetActiveWindow/SetDataType/SetCurrentSubcase and before any journal line,
#      because nothing was changed and nothing may be claimed;
#   3. apply the lowest variant (documented sequence), read back, and only when the read-back says
#      the window is NOT showing it, try the next variant;
#   4. on a pass: journal exactly the script that passed (one replayable line), count the window and
#      answer {window type}; on no pass at all: raise the LAST variant's text, listing every value
#      read, so the log never says "applied" about a window that did not change.
proc ::pis::result::apply_to_window {cfg index name} {
    variable calls
    variable last_window
    variable last_type
    variable readback
    variable state
    variable variant
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
    set st ""
    set why ""
    if {[catch {set st [::pis::result::read_state $index]} why]} {
        error [format "%s: no result read-back yet (%s) | click Load All first" $slot [string trim $why]]
    }
    set win [dict get $st win]
    if {![string is integer -strict $win] || $win < 1} {
        set win [expr {$index < 0 ? 0 : $index}]
    }
    set shown [::pis::result::window_file $cfg $win]
    if {$shown eq ""} {
        set shown "the loaded result"
    }
    set labels [dict get $st labels]
    if {[llength $labels] == 0} {
        error [format "window %s: %s holds no data type (GetDataTypeList, S30) | did Load All attach it?" \
            $win $shown]
    }
    set label [::pis::result::match $labels $want]
    if {$label eq ""} {
        error [format "result '%s' not found in %s" $want $shown]
    }
    set plan [::pis::result::plan $st $label]
    set all [::pis::result::variants]
    set last [lindex $all end]
    set lastwhy ""
    set res ""
    foreach v $all {
        set scr [::pis::result::build_script $index $plan $v]
        set code [catch {::pis::hw::exec_hwi $scr -nojournal} res]
        set got ""
        if {$code} {
            # A variant that raised cannot have changed anything: judge it on a fresh read-back when
            # the chain still answers, otherwise report the build's own message unchanged.
            if {![catch {set got [::pis::result::read_state $index]}]} {
                set lastwhy [::pis::result::fail_text $win $want $got \
                    "the apply script failed: [string trim $res]"]
            } else {
                set lastwhy [format "result window %s: '%s' not displayed | the apply script failed: %s" \
                    $win $want [string trim $res]]
            }
            if {$v ne $last} {
                ::pis::common::log $cfg INFO [format "result window %s: variant %s failed | trying the next form" $win $v]
            }
            continue
        }
        set rerr ""
        if {[catch {set got [::pis::result::read_state $index]} rerr]} {
            set lastwhy [format "result window %s: '%s' not displayed | the read-back after the change failed: %s" \
                $win $want [string trim $rerr]]
            if {$v ne $last} {
                ::pis::common::log $cfg INFO [format "result window %s: variant %s failed | trying the next form" $win $v]
            }
            continue
        }
        lassign [::pis::result::verdict $got $label] ok why
        if {$ok} {
            ::pis::hw::context [::pis::result::title] $label
            ::pis::hw::journal_run $scr
            incr calls
            set last_window $win
            set last_type $label
            set readback [dict get $got type]
            set state $got
            set variant $v
            return [list $win $label]
        }
        set lastwhy [::pis::result::fail_text $win $want $got $why]
        if {$v ne $last} {
            ::pis::common::log $cfg INFO [format "result window %s: variant %s failed (%s) | trying the next form" \
                $win $v [::pis::result::values_text $got]]
        }
    }
    error $lastwhy
}

# The module entry point (SPEC.md A10). scope "layout" = every window Load All created, anything
# else = the active window only. One apply per window, one read-back line per window that passed,
# and ONE ::pis::hw::refresh after the loop so the page repaints once the state is provably right.
# A failing window stops the run unless [log] continue_on_error says otherwise; the exit status is
# the number of windows that changed, so 0 can never be mistaken for "all done".
proc ::pis::result::run {root cfg scope} {
    variable applied
    ::pis::result::need_common
    ::pis::result::need_hw
    if {$scope ne "layout" && $scope ne "active"} {
        error "::pis::result::run: unknown scope '$scope' (expected active or layout)"
    }
    set applied 0
    set name [::pis::result::selected_item $cfg]
    if {$name eq ""} {
        ::pis::common::log $cfg WARN "module [::pis::result::title]: no item selected, nothing run"
        return 0
    }
    set cont 0
    catch {set cont [::pis::common::to_bool [::pis::common::get $cfg log continue_on_error 0] "log continue_on_error"]}
    set n 0
    foreach index [::pis::result::targets $cfg $scope] {
        set code [catch {::pis::result::apply_to_window $cfg $index $name} res]
        if {$code} {
            if {!$cont} {
                error [string trim $res]
            }
            ::pis::common::log $cfg ERROR "[::pis::result::title]: [string trim $res]"
            continue
        }
        lassign $res win type
        ::pis::common::log $cfg INFO [::pis::result::line_text $win $::pis::result::state]
        incr n
    }
    if {$n == 0} {
        ::pis::common::log $cfg OK [format "%s: nothing changed" [::pis::result::title]]
        return 0
    }
    set applied $n
    ::pis::hw::refresh
    ::pis::common::log $cfg OK [format "%s: %s window(s) now show '%s'" \
        [::pis::result::title] $n $name]
    return $n
}

# Counters and the last read state back to 0/"" (the suites call this between cases; it never
# touches HyperView).
proc ::pis::result::reset_state {} {
    variable applied 0
    variable calls 0
    variable last_window ""
    variable last_type ""
    variable readback ""
    variable state ""
    variable variant 0
    variable answer ""
    return
}
