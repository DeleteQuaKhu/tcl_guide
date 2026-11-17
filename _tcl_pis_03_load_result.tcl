# src/01_scripts/_tcl_pis_03_load_result.tcl
# ::pis::result - the "Load result" module (task T-008, reworked by T-026 and T-027): make the
# targeted window(s) really DISPLAY the typed result type (the contour data type).
# Tcl/Tk 8.5 compatible, no tcllib, no network, no package require.
# Sourcing this file defines procs only: it never calls HyperView.
#
# WHAT "APPLIED" MEANS (T-026, after the owner's `T-008: fail 2` on 2026-11-12: the log said the
# result was applied while the window's contour did not change). Every form below is named in
# docs/refs/HV_API.md section 11 FIRST, before it is used here:
#   set  : poIContourCtrl SetDataType (S28) and/or poIContourCtrl SetDimensionEnabled (S35), in the
#          order of the variant (see VARIANT TABLE below)
#          -> poIResultCtrl SetCurrentSubcase (S39, ONLY when the window has none)
#          -> <client> Draw on the CLIENT OF THAT WINDOW (PROVEN pattern 2, docs/refs/HV_API.md
#             section 11: `<post> Draw` > `update idletasks`)
#   read : poIResultCtrl GetSubcaseList (S32) / GetDataTypeList (S30) / GetCurrentSubcase (S40) /
#          GetNumberOfSubcases (S27), poIContourCtrl GetDataType (S29) / GetDimensionEnabled (S36) /
#          GetDataComponent (S38), poIPost GetDisplayOptions contour (S57, T-029)
# "no error" proves NOTHING here: S28 says SetDataType ALWAYS answers success (the contour just
# stays gray), and S35/S39 are silent no-ops on a build that ignores them. The step is judged by
# the READ-BACKS only, and a window that accepted every command without changing is an ERROR.
#
# T-027 (owner's `T-008: fail 3`, 2026-11-12) fixed three defects of T-026:
#   (a) poIContourCtrl SetEnabled (S41) does NOT EXIST on the owner's build ("could not find
#       requested method: SetEnabled"). It is gone from the production variants; a method the
#       build says it does not have is now recorded ONCE and skipped everywhere
#       (::pis::hw::absent_*, SPEC.md A10);
#   (b) the ORDER of "enable the dimensions" and "SetDataType" was never documented - T-026
#       enabled first because the planning prompt said so. The supplier prints no order, so BOTH
#       orders are variants and the read-back decides;
#   (c) the failure text listed only the LAST variant, so the outcome of the documented order was
#       invisible. Every variant now leaves ONE line in the log: what step it reached, the build's
#       own error text in full, and every value read back; the status bar keeps the first 70
#       characters of the FIRST variant's line plus " (see log)".
#
# VARIANT TABLE (production). Each variant is the same read-back and the same verdict; they differ
# only in ORDER and in the boolean literal of SetDimensionEnabled's `state`:
#   1  type-first,   state true   order UNVERIFIED-GUESS (the doc prints none), form DOC
#                                 (S35: "True if enabled, false if not")
#   2  enable-first, state true   order UNVERIFIED-GUESS (the T-026 order), form DOC
#   3  type-first,   state 1      both UNVERIFIED-GUESS (the doc prints true/false)
#   4  enable-first, state 1      both UNVERIFIED-GUESS
#   5  type-first,   state true   + ONE documented display line before Draw (T-029):
#                                 `pisC SetDisplayOptions contour true` (poIPost S56), read back with
#                                 `pisC GetDisplayOptions contour` (S57). Every part of V5 is DOC:
#                                 the name `contour` and the state `true` are printed on S56.
#   6  type-first,   state true   + `pisCt SetEnableState true` (S53) between the type and the
#                                 dimensions, then Draw (T-030). OWNER-MACRO: the owner's own working
#                                 HyperView macro sends exactly this line, in this position after
#                                 `SetDataType` (test/test_out/TCL_StressExport.tcl lines 55-60, so
#                                 the method EXISTS on this build and was recorded in use); the state
#                                 literal `true` is S53's own example. S53 says what it is: the AUTO
#                                 load/unload switch for contour data ("a false state unloads the
#                                 loaded data"), NOT a display toggle - which is why V6 keeps the
#                                 dimensions and the Draw, and why a pass of V6 is reported as "the
#                                 data was never allowed to load", not as "this is the display call".
# T-029 STOP RULE: after 3 failed passes whose fix relied on UNVERIFIED-GUESS variants, no further
# variant may be added before the owner returns evidence (a log, a state diff or a recorded macro).
# T-008 is at that point, so V5 is the LAST variant until `src/02_working/t008_diff.txt` arrives; the
# one exception is a form the supplier prints, which is exactly what V5 is.
#
# T-030 (owner's `T-008: fail 5`: a correct name, still no contour - T-029 not accepted). Two things
# changed, and neither one is a guess:
#   (d) EVIDENCE ARRIVED, and it is a file, not a memory: the owner's own working HyperView macro
#       (test/test_out/TCL_StressExport.tcl, "BY FUKADA", in use on the owner's machine) sets the
#       contour up with `con SetEnableState true` on the contour control, AFTER `SetDataType` and
#       after the other contour properties (lines 55-60). Because that macro runs on this build, the
#       METHOD and its position are recorded in use, not inferred. S53 documents the call ("True if
#       contour data can be loaded; otherwise false"; a false state UNLOADS the loaded contour data)
#       and S54 reads it. V6 is that route: type, then SetEnableState true, then the dimensions, then
#       Draw - added AFTER V1..V5 so the log stays comparable with the previous run and so an early
#       pass is still possible. What V6 does NOT claim: S53 is not a display switch (docs/refs/
#       HV_API.md section 12, subsection "Does SetEnableState ... control whether a contour is
#       DISPLAYED?" answers NO), so a V6 pass means the build had to be
#       told to LOAD the contour data first - a different defect from V5's display option.
#   (e) THE LOG NOW CARRIES THE WHOLE STORY, uncut: a TRACE line per window (BEFORE, the exact
#       commands each variant sent, LATE after the last variant), a NOCHANGE line whenever a variant
#       left every value identical, a FALSE-NEGATIVE GUARD line that says which read-backs really
#       answered, and an OWNER CHECK line that says what to look at on screen. `snap`/`snaps_text`/
#       `diff` write the same evidence on demand from the console. The log PANE no longer clips a
#       long line: it wraps it (-wrap char), and the message itself is never cut.

# The plan only enables the dimensions that do NOT already read true (S36), so an enabled
# dimension is never touched; the doc prints no way to ask "does this model contain solids", so the
# verdict requires AT LEAST ONE dimension true and prints the other two (a model without solids
# must not be refused). SetDataComponent is never sent (S37 prints no value space): the component
# is READ (S38) and printed.
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
#   ::pis::result::dump_calls {}                    -> every documented READ-ONLY getter, one call each
#   ::pis::result::dump_script {index}              -> read-only chain filling ::pis::result::dumped
#   ::pis::result::dump_dict {index}                -> {name value} pairs (T-029 STATE DUMP)
#   ::pis::result::dump_window {cfg index}          -> ONE "STATE DUMP window k" log block
#   ::pis::result::read_state {index}               -> dict of the read-backs, raises if none
#   ::pis::result::verdict {st label}               -> {1 ""} when the window shows it, else {0 why}
#   ::pis::result::build_script {index plan variant} -> one hwi script: the variant's own order
#   ::pis::result::plan {st label}                  -> what one window's script needs (label/enable/sub)
#   ::pis::result::variants {}                      -> the variant numbers, documented forms first
#   ::pis::result::variant_info {v}                 -> order/state + the src class of each part
#   ::pis::result::variant_name {v}                 -> "type-first, true" (report text)
#   ::pis::result::variant_needs {v}                -> the {class method} pairs the variant sends
#   ::pis::result::step_of {raw variant}            -> the step the build's own text names
#   ::pis::result::variant_line {win name v n ...}  -> the one line a failed variant leaves
#   ::pis::result::trace_text {tag win text}        -> "TRACE window k <tag> <text>" (T-030)
#   ::pis::result::nochange_text {win v n name st}  -> the line a variant that changed nothing leaves
#   ::pis::result::guard_text {win name st why}     -> the FALSE-NEGATIVE GUARD line (T-030)
#   ::pis::result::owner_line {win name}            -> the OWNER CHECK sentence (T-030)
#   ::pis::result::snap {tag {windows ""}}          -> read-only snapshot of the current state
#   ::pis::result::snaps_text {tag}                 -> the snapshot as log lines
#   ::pis::result::diff {a b}                       -> the differences between two snapshots
#   ::pis::result::head_cut {text {n}}              -> <n> chars + " (see log)" (status bar)
#   ::pis::result::reset_state {}                   -> counters back to 0 (tests)
# Namespace variables: applied, calls, last_window, last_type, readback, state, variant, answer,
#                      failed, owner, snaps

namespace eval ::pis::result {
    if {![info exists applied]} { set applied 0 }
    if {![info exists calls]} { set calls 0 }
    if {![info exists last_window]} { set last_window "" }
    if {![info exists last_type]} { set last_type "" }
    if {![info exists readback]} { set readback "" }
    if {![info exists state]} { set state "" }
    if {![info exists variant]} { set variant 0 }
    if {![info exists answer]} { set answer "" }
    if {![info exists failed]} { set failed 0 }
    # T-029: the STATE DUMP answer (list of {name value} pairs), filled by dump_dict.
    if {![info exists dumped]} { set dumped {} }
    # T-030: the OWNER CHECK sentence of the last failure, and the read-only snapshots taken with
    # ::pis::result::snap {tag -> dict of window -> {values dump}}.
    if {![info exists owner]} { set owner "" }
    if {![info exists snaps]} { set snaps [dict create] }
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
set pisRDisp ""
catch {set pisRDisp [pisC GetDisplayOptions contour]}
set ::pis::result::answer [list $pisRIdx $pisRDt $pisRDims $pisRCur $pisRN $pisRComp $pisRSubs $pisRLabels $pisRDisp]}
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
    lassign $got win dtype dims cur n comp subs labels disp
    set readback $dtype
    return [dict create win $win type $dtype dims $dims subcase $cur nsub $n \
        component $comp subs $subs labels $labels display $disp]
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

# T-030: the same values plus the window's own contour display option (poIPost GetDisplayOptions
# contour, S57), for the TRACE lines only. `line_text`/`fail_text` keep the documented A10 form that
# the report files quote verbatim, so the display option is added here and not there. "?" means the
# build answered nothing for it - never "off".
proc ::pis::result::trace_values {st} {
    set base [::pis::result::values_text $st]
    set disp ""
    if {[dict exists $st display]} { set disp [string trim [dict get $st display]] }
    if {$disp eq ""} { set disp "?" }
    return "$base display=$disp"
}

# The ONE line a passing window leaves in the log (SPEC.md A10, T-026):
#   result window 1: type=Stress enabled=line=true,shell=true,solid=true subcase=1 component=?
proc ::pis::result::line_text {win st} {
    return [format "result window %s: %s" $win [::pis::result::values_text $st]]
}

# The ONE sentence a window that took every command and changed nothing leaves behind: the window,
# the requested name and EVERY value read, in full - never a summary and never a cut. T-027 builds
# its per-variant lines (variant_line) on the same values; this single-window form is kept because
# docs/refs/HV_API.md section 11 and the report files quote it verbatim.
proc ::pis::result::fail_text {win name st why} {
    set comp [string trim [dict get $st component]]
    if {$comp eq ""} { set comp "?" }
    return [format "result window %s: '%s' not displayed (type='%s' enabled='%s' subcase='%s' component='%s') | %s" \
        $win $name [dict get $st type] [::pis::result::enabled_text $st] \
        [dict get $st subcase] $comp $why]
}

# Which step a variant reached, judged from the build's OWN text: the method it could not find, a
# method name it printed, or - when the text names none - the first state-changing command of that
# variant. Derived from the error, never invented.
proc ::pis::result::step_of {raw variant} {
    set t [string trim $raw]
    set name ""
    if {[regexp {could not find requested method:[ \t]*([A-Za-z_][A-Za-z0-9_]*)} $t -> name]} {
        return $name
    }
    foreach m {SetDataType SetEnableState SetDimensionEnabled SetCurrentSubcase Draw} {
        if {[string first $m $t] >= 0} { return $m }
    }
    if {[dict get [::pis::result::variant_info $variant] order] eq "type_first"} {
        return "SetDataType"
    }
    return "SetDimensionEnabled"
}

# The one line a FAILED variant leaves (T-027 item 2). It keeps the documented prefix of SPEC.md
# A10 ("result window k: '<name>' not displayed") and appends the variant's own surname, the step it
# reached and either the build's raw text or every value read back - in full, never cut.
proc ::pis::result::variant_line {win name v n short step detail} {
    return [format "result window %s: '%s' not displayed | variant %s/%s %s: step %s -> %s" \
        $win $name $v $n $short $step $detail]
}

# The read-back values as the tail of a variant line; "" (no dict) means the probe answered nothing.
proc ::pis::result::read_suffix {st} {
    if {$st eq ""} {
        return " | read-back: none (the window did not answer the probe)"
    }
    return " | read-back: [::pis::result::values_text $st]"
}

# T-030: the TRACE line. One per window and step, at INFO, uncut - it is what makes a log
# self-sufficient: the values BEFORE anything was sent, the exact commands each variant sent, and the
# values LATE (after the last variant). Format (the report parser in src/spike/t008_check.tcl sinks
# the same lines verbatim):
#   TRACE window 1 BEFORE type=... enabled=... subcase=... component=... display=...
#   TRACE window 1 variant 1/6 'type-first, true' sent: SetDataType "Stress" -> ... -> Draw
#   TRACE window 1 LATE   type=...            (only when the window did not pass: a pass leaves the
#                                              documented A10 result line instead, so one window still
#                                              has exactly one values line)
proc ::pis::result::trace_text {tag win text} {
    return [format "TRACE window %s %s %s" $win $tag $text]
}

# The line a variant leaves when the window answered every command and NOTHING changed - every value
# it reads after the variant is identical to the values read before it. That is a different defect
# from "the read-back contradicts the request", and the log must say which one happened.
proc ::pis::result::nochange_text {win v n st} {
    return [format "NOCHANGE window %s variant %s/%s: every value is identical to BEFORE (%s) - the build accepted the commands and ignored them" \
        $win $v $n [::pis::result::trace_values $st]]
}

# T-030: the false-negative guard. A window can DISPLAY the result while every getter still answers
# "not shown", or the getters may not exist at all; both cases look like a module failure from the
# log alone. This ONE line says which read-backs really answered, so the owner's "I can see it" is
# evidence and not a contradiction.
proc ::pis::result::guard_text {win name st why} {
    set answered [list]
    set quiet [list]
    if {[string trim [dict get $st type]] ne ""} {
        lappend answered "GetDataType (S29)"
    } else {
        lappend quiet "GetDataType (S29)"
    }
    set known 0
    set vals [list]
    set dims [dict get $st dims]
    set i 0
    foreach d [::pis::result::dims] {
        set v [string trim [lindex $dims $i]]
        incr i
        lappend vals "$d=[expr {$v eq "" ? "?" : $v}]"
        if {$v ne ""} { set known 1 }
    }
    if {$known} {
        lappend answered "GetDimensionEnabled (S36) [join $vals ,]"
    } else {
        lappend quiet "GetDimensionEnabled (S36)"
    }
    if {[dict exists $st display] && [string trim [dict get $st display]] ne ""} {
        lappend answered "GetDisplayOptions contour (S57)=[string trim [dict get $st display]]"
    } else {
        lappend quiet "GetDisplayOptions contour (S57)"
    }
    set q "none"
    if {[llength $quiet] > 0} { set q [join $quiet {, }] }
    set a "none"
    if {[llength $answered] > 0} { set a [join $answered {; }] }
    return [format "FALSE-NEGATIVE GUARD window %s: '%s' - answered: %s | did not answer (empty, never 'off'): %s | verdict: %s" \
        $win $name $a $q [string trim $why]]
}

# T-030: the sentence the owner has to read last. It says what to LOOK AT, because the two possible
# defects (the getters lie / the apply is wrong) need different next steps and only a human eye can
# tell them apart.
proc ::pis::result::owner_line {win name} {
    return [format "OWNER CHECK window %s: look at that window now - is the '%s' contour VISIBLE? visible = the read-backs are wrong, not the apply (send this log + src/02_working/t008_check.txt); not visible = the apply is wrong (send the same two files)" \
        $win $name]
}
# The STATUS BAR version of a report line: the first <n> characters plus " (see log)", the same two
# lengths the model loader uses (T-019). The log keeps the full line.
proc ::pis::result::head_cut {text {n 70}} {
    set t [string map [list "\r" " " "\n" " "] [string trim $text]]
    while {[string first "  " $t] >= 0} { set t [string map [list "  " " "] $t] }
    if {$n > 0 && [string length $t] > $n} {
        set t [string range $t 0 [expr {$n - 1}]]
    }
    return "$t (see log)"
}

# Is the window DISPLAYING the requested label? Answers {1 ""} or {0 <why>}, and only the
# documented read-backs of docs/refs/HV_API.md section 11 decide:
#   - GetDataType (S29) must answer the label the file spells;
#   - at least one dimension must read enabled (S36) WHEN this build answers S36 at all - a build
#     that does not answer it is a NOTE in the log, not a pass and not a failure;
#   - a current subcase (S40) must exist when GetNumberOfSubcases (S27) says the file has one;
#   - the window's CONTOUR DISPLAY OPTION (poIPost GetDisplayOptions contour, S57, T-029) must not
#     answer a value that is not true WHEN THE BUILD ANSWERS IT AT ALL - a window whose display
#     option is off shows nothing whatever GetDataType says, and a build that does not answer S57
#     stays a NOTE (an empty value), never a pass and never a failure.
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
    set disp ""
    if {[dict exists $st display]} { set disp [string trim [dict get $st display]] }
    if {$disp ne "" && ![::pis::result::is_true $disp]} {
        lappend why "the contour display option of this window is off (poIPost GetDisplayOptions contour, S57) answered '$disp'"
    }
    if {[llength $why] == 0} {
        return [list 1 ""]
    }
    return [list 0 [join $why "; "]]
}

# The variant list, in the order the module tries them. The order and the boolean literal of
# S35's `state` are the ONLY two things the supplier does not pin down, so each combination is one
# variant and the READ-BACK - never the order of this list - decides. Documented forms come first.
proc ::pis::result::variants {} {
    return [list 1 2 3 4 5 6]
}

# One variant, in one dict:
#   order      "type_first" | "enable_first"
#   order_src  DOC when the supplier prints the order, otherwise UNVERIFIED-GUESS + the reason
#   state      the literal sent as S35's `state` argument ("true" or "1")
#   state_src  DOC when the supplier's own words print that form, otherwise UNVERIFIED-GUESS
#   display    1 when the variant also sends the documented display line (poIPost SetDisplayOptions
#              contour true, S56), 0 otherwise
#   display_src the src class of that line (DOC only; there is no guessed display line)
#   enable_state 1 when the variant also sends poIContourCtrl SetEnableState true (S53) between the
#              type and the dimensions, 0 otherwise; enable_state_src is its src class
# The order is UNKNOWN in every variant: S35 and S28 are two pages of the same class and neither
# says which one must come first. Because a type change may reset state, "type-first" is preferred
# and is variant 1; the T-026 order follows as variant 2. The literal `true`/`false` is what S35
# prints ("True if enabled, false if not") and the supplier's own examples use (`SetIfMultipleLayer
# true`), so a variant that sends `true` is DOC and the `1`/`0` form is UNVERIFIED-GUESS.
# Variant 5 (T-029) is the only variant whose DISPLAY line is documented: S56 prints both the name
# (`contour` is one of the listed display options) and the state ("true for on, or false for off"),
# and S57 is its documented read-back. It reuses V1's order, so a pass of V5 also tells the owner
# that order V1 works.
# Variant 6 (T-030) sends ONE more documented call, poIContourCtrl SetEnableState (S53/S54), in the
# position the owner's own working macro uses it (right after SetDataType and the other contour
# properties). Its src class is OWNER-MACRO: stronger than UNVERIFIED-GUESS (the method exists on
# this build and the position was recorded in use), weaker than DOC for a DISPLAY claim, because
# S53 is the auto load/unload switch and not a display toggle.
proc ::pis::result::variant_info {v} {
    set doc_state {DOC S35 "True if enabled, false if not"}
    set guess_state {UNVERIFIED-GUESS the doc prints true/false, not 1/0}
    set doc_order {DOC the doc prints no order}
    set guess_order {UNVERIFIED-GUESS the doc prints no order; a type change may reset state}
    set doc_display {DOC S56 "contour" + "true for on, or false for off"}
    set proven_enable {OWNER-MACRO test/test_out/TCL_StressExport.tcl lines 55-60 (SetDataType -> ... -> SetEnableState true, recorded in use on this build) + DOC S53 "True if contour data can be loaded; otherwise false"}
    set info ""
    switch -- $v {
        1 { set info [dict create order type_first order_src $guess_order \
                        state true state_src $doc_state] }
        2 { set info [dict create order enable_first order_src $guess_order \
                        state true state_src $doc_state] }
        3 { set info [dict create order type_first order_src $guess_order \
                        state 1 state_src $guess_state] }
        4 { set info [dict create order enable_first order_src $guess_order \
                        state 1 state_src $guess_state] }
        5 { set info [dict create order type_first order_src $guess_order \
                        state true state_src $doc_state \
                        display 1 display_src $doc_display] }
        6 { set info [dict create order type_first order_src $guess_order \
                        state true state_src $doc_state \
                        enable_state 1 enable_state_src $proven_enable] }
        default {
            error "::pis::result::variant_info: unknown variant '$v' (expected one of: [::pis::result::variants])"
        }
    }
    if {![dict exists $info display]} {
        dict set info display 0
        dict set info display_src {none - this variant sends no display line}
    }
    if {![dict exists $info enable_state]} {
        dict set info enable_state 0
        dict set info enable_state_src {none - this variant sends no enable-state line}
    }
    return $info
}

# "type-first, true" / "enable-first, 1": the short name a report line and the log use.
proc ::pis::result::variant_name {v} {
    set info [::pis::result::variant_info $v]
    set ord [dict get $info order]
    if {$ord eq "type_first"} {
        set ord "type-first"
    } else {
        set ord "enable-first"
    }
    set name "$ord, [dict get $info state]"
    if {[dict get $info display]} {
        set name "$name, contour display on"
    }
    if {[dict get $info enable_state]} {
        set name "$name, enable state on"
    }
    return $name
}

# The {class method} pairs a variant sends. Before a variant runs, every pair is asked against the
# ABSENT-METHOD record (::pis::hw::absent_has): a method the build said it does not have is never
# sent again - not in this window, not in window 2..N - and a variant that needs it is skipped
# instead of being counted as a failed attempt (T-027 / SPEC.md A10).
proc ::pis::result::variant_needs {v} {
    set out [list [list poIContourCtrl SetDataType] [list poIContourCtrl SetDimensionEnabled]]
    if {[dict get [::pis::result::variant_info $v] display]} {
        lappend out [list poIPost SetDisplayOptions]
    }
    if {[dict get [::pis::result::variant_info $v] enable_state]} {
        lappend out [list poIContourCtrl SetEnableState]
    }
    return $out
}

# The apply script of one window: the chain of <index> + the state-changing lines of <variant> in
# THAT variant's order. Built with the adapter's builders, so the handle chain and the journal
# spelling stay in one file; the script is sent with -nojournal and journaled only after the
# read-back proved it (SPEC.md A2-A4: a command that changed nothing must never reach a journal).
# The state-changing lines come from ::pis::result::variant_lines, so the TRACE line of the log says
# exactly what was sent (T-030: never a copy that can drift).
proc ::pis::result::build_script {index plan variant} {
    set lines [list "pisR GetContourCtrlHandle pisCt"]
    foreach line [::pis::result::variant_lines $plan $variant] {
        lappend lines $line
    }
    return [::pis::result::script $index [join $lines "\n"] 1]
}

# The STATE-CHANGING lines of one variant, in the order the variant's own dict says. `pisCt` is the
# contour control of the chain above, `pisR` its result controller and `pisC` the client of the
# window. Documented literals only: `state` is the variant's dict (S35), `contour`/`true` are S56's
# own words, `true` for SetEnableState is S53's own example.
proc ::pis::result::variant_lines {plan variant} {
    set info [::pis::result::variant_info $variant]
    set state [dict get $info state]
    set types [list "pisCt SetDataType [::pis::hw::quote [dict get $plan label]]"]
    set dims [list]
    foreach d [dict get $plan enable] {
        lappend dims "pisCt SetDimensionEnabled $d $state"
    }
    set lines [list]
    if {[dict get $info order] eq "type_first"} {
        foreach line $types { lappend lines $line }
        # T-030 V6: the owner's own script sends the enable state RIGHT AFTER the data type, and the
        # dimensions come after that - the macro's order, kept.
        if {[dict get $info enable_state]} {
            lappend lines "pisCt SetEnableState true"
        }
        foreach line $dims { lappend lines $line }
    } else {
        foreach line $dims { lappend lines $line }
        if {[dict get $info enable_state]} {
            lappend lines "pisCt SetEnableState true"
        }
        foreach line $types { lappend lines $line }
    }
    set sub [dict get $plan sub]
    if {$sub ne ""} {
        lappend lines "pisR SetCurrentSubcase $sub"
    }
    # T-029: the ONE documented display line (poIPost SetDisplayOptions, S56). Only V5 sends it; when
    # the build says it does not have the method, the ABSENT-METHOD rule skips the whole variant.
    if {[dict get $info display]} {
        lappend lines "pisC SetDisplayOptions contour true"
    }
    lappend lines "pisC Draw"
    return $lines
}

# What a variant SENT, as the one-line tail of a TRACE line: the handle prefix is dropped (it is the
# same chain for every variant) and the steps are joined with " -> ", so one line reads
#   SetDataType "Stress" -> SetEnableState true -> SetDimensionEnabled line true -> ... -> Draw
proc ::pis::result::commands_text {plan variant} {
    set out [list]
    foreach line [::pis::result::variant_lines $plan $variant] {
        set parts [split [string trim $line]]
        if {[llength $parts] > 1 && [regexp {^pis[A-Z]} [lindex $parts 0]]} {
            set line [join [lrange $parts 1 end]]
        }
        lappend out $line
    }
    return [join $out " -> "]
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
# variant's own outcome. Order (docs/refs/HV_API.md section 11, T-027):
#   1. read the window first, so the decision is never taken on a guess;
#   2. find <name> in the data type labels the file itself reported (S30) - an unknown name stops
#      here, before any SetActiveWindow/SetDataType/SetCurrentSubcase and before any journal line,
#      because nothing was changed and nothing may be claimed;
#   3. apply the lowest variant, read back, and only when the read-back says the window is NOT
#      showing it, try the next one - unless the build already PROVED it does not have a method that
#      variant needs: then the variant is SKIPPED, not counted as a failed attempt;
#   4. on a pass: the failed variants before it are logged as INFO (a fallthrough stays visible),
#      ONLY the passing script is journaled, and the answer is {window type};
#   5. on no pass at all: every variant leaves ONE ERROR line in the log - its short name, the step
#      it reached, the build's own text in full and every value read back - the raised text (the
#      status bar) keeps the first 70 characters of the FIRST of those lines + " (see log)", and
#      window 1 additionally leaves ONE "STATE DUMP window 1" block (T-029) with every documented
#      read-only getter of its contour control.
# T-030 adds, without changing any of the above: a TRACE ... BEFORE line (the values read before the
# first command), one TRACE line per variant (the commands it SENT), a NOCHANGE line when the values
# after a variant are identical to BEFORE, a TRACE ... LATE line (the values after the last variant),
# a FALSE-NEGATIVE GUARD line and the OWNER CHECK sentence - the same text ::pis::result::owner_line
# hands to the GUI. All of it is INFO/WARN and read-only.
proc ::pis::result::apply_to_window {cfg index name} {
    variable calls
    variable last_window
    variable last_type
    variable readback
    variable state
    variable variant
    variable failed
    variable owner
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
    # T-030: the BEFORE trace - what the window answers before this module touches it.
    set before_text [::pis::result::trace_values $st]
    ::pis::common::log $cfg INFO [::pis::result::trace_text BEFORE $win $before_text]
    set plan [::pis::result::plan $st $label]
    set all [::pis::result::variants]
    set n [llength $all]
    set fails [list]
    set first ""
    set res ""
    set late ""
    foreach v $all {
        # ABSENT-METHOD RULE (2nd half): a variant that needs a method this build does not have is
        # skipped - never sent, never counted as a failed attempt, in this window or any later one.
        set missing ""
        foreach pair [::pis::result::variant_needs $v] {
            lassign $pair class method
            if {[::pis::hw::absent_has $class $method]} {
                set missing $method
                break
            }
        }
        if {$missing ne ""} {
            ::pis::common::log $cfg INFO [format "TRACE window %s variant %s/%s %s: SKIPPED, this build does not have %s" \
                $win $v $n [::pis::result::variant_name $v] $missing]
            continue
        }
        set scr [::pis::result::build_script $index $plan $v]
        # T-030: the TRACE line says exactly which commands this variant sends, before it sends them.
        ::pis::common::log $cfg INFO [format "TRACE window %s variant %s/%s '%s' sent: %s" \
            $win $v $n [::pis::result::variant_name $v] [::pis::result::commands_text $plan $v]]
        set code [catch {::pis::hw::exec_hwi $scr -nojournal} res]
        set raw [string trim $res]
        if {$code} {
            # ABSENT-METHOD RULE (1st half): the build's own text decides. The arguments of every
            # production variant are the documented ones, so `documented 1`; the record is written
            # once per run and the INFO line below is its only announcement.
            set key [::pis::hw::absent_note $raw 1]
            if {$key ne ""} {
                ::pis::common::log $cfg INFO [format "method absent on this build: %s" $key]
            }
        }
        # Always read back, even when the variant raised: the values are what a diagnosis needs.
        set got ""
        set rerr ""
        set rok 1
        if {[catch {set got [::pis::result::read_state $index]} rerr]} {
            set rok 0
            set got ""
        }
        set line ""
        if {$code} {
            set line [::pis::result::variant_line $win $want $v $n \
                [::pis::result::variant_name $v] [::pis::result::step_of $raw $v] \
                [format "the apply script failed: %s%s" $raw [::pis::result::read_suffix $got]]]
        } elseif {!$rok} {
            set line [::pis::result::variant_line $win $want $v $n \
                [::pis::result::variant_name $v] "read-back" \
                [format "the read-back after the change failed: %s" [string trim $rerr]]]
        } else {
            lassign [::pis::result::verdict $got $label] ok why
            if {$ok} {
                foreach done $fails {
                    ::pis::common::log $cfg INFO $done
                }
                ::pis::hw::context [::pis::result::title] $label
                ::pis::hw::journal_run $scr
                incr calls
                set last_window $win
                set last_type $label
                set readback [dict get $got type]
                set state $got
                set variant $v
                # The A10 result line that `run` prints next IS the pass evidence (BEFORE, the sent
                # lines and that line cover the whole story), so no second copy of the same values is
                # written here: one window, one values line.
                return [list $win $label]
            }
            set line [::pis::result::variant_line $win $want $v $n \
                [::pis::result::variant_name $v] "read-back" \
                [format "%s | %s" [::pis::result::values_text $got] $why]]
        }
        # T-030: a variant that raised nothing and changed nothing is a different defect from one whose
        # read-back contradicts the request - say which happened, once per such variant, at WARN.
        if {$rok && !$code && [::pis::result::trace_values $got] eq $before_text} {
            ::pis::common::log $cfg WARN [::pis::result::nochange_text $win $v $n $got]
        }
        if {$rok} { set late $got }
        lappend fails $line
        if {$first eq ""} { set first $line }
    }
    incr failed
    foreach line $fails {
        ::pis::common::log $cfg ERROR $line
    }
    # T-030: the closing lines, the same ones whatever went wrong above - a reader can quote them
    # without reading the whole run. LATE is the values after the LAST variant that answered.
    if {$late ne ""} {
        ::pis::common::log $cfg INFO [::pis::result::trace_text LATE $win [::pis::result::trace_values $late]]
    } else {
        ::pis::common::log $cfg INFO [::pis::result::trace_text LATE $win "no read-back answered after the last variant"]
    }
    set seen $st
    if {$late ne ""} { set seen $late }
    ::pis::common::log $cfg WARN [::pis::result::guard_text $win $want $seen \
        "the read-backs above say 'not displayed'; either one of them answered wrongly or the apply is wrong, and only a human eye can tell which"]
    # T-029 item 2: a window that accepted every command and still shows nothing now leaves the
    # read-only getter dump behind it, so a normal GUI failure always carries evidence. Window 1 only
    # per run (cheap) and never a setter: ::pis::result::dump_window reads.
    if {$win == 1} {
        set dt ""
        if {[catch {::pis::result::dump_window $cfg $win} dt]} {
            # A dump that cannot run must SAY so: a silent failure here is exactly the defect class
            # T-029 is fixing.
            catch {::pis::common::log $cfg WARN [format "STATE DUMP window %s failed: %s" \
                $win [string trim $dt]]}
        }
    }
    # T-030: the OWNER CHECK is the LAST log line of a failed window on purpose - it is the only one
    # that asks the owner for something. The status bar keeps the documented A10 prefix (the first
    # variant line, cut), so the log is where the owner reads the question.
    set owner [::pis::result::owner_line $win $want]
    ::pis::common::log $cfg WARN $owner
    if {$first eq ""} {
        error [format "result window %s: '%s' not displayed | no variant could run, method(s) absent on this build: %s" \
            $win $want [::pis::hw::absent_list]]
    }
    error [::pis::result::head_cut $first]
}

# --- the STATE DUMP (T-029 item 2): evidence on every normal failure ---------------------------
# The documented READ-ONLY getters of poIContourCtrl plus the result controller's subcase reads and
# the window's own display option. One call per entry, each in its own catch; the answer is a list of
# {name value} pairs where a raising getter answers "ERR <the build's own text>", never an empty
# string. Getters only: there is no setter here, so running the dump can never change the session.
# Left out on purpose (the doc prints no value space, or the argument is not a Tcl value):
# GetEnabled (`pool`), GetMultipleLayerList (`hwStringList&`), GetValueList (needs a selection set),
# GetValidResultsSystemsList (needs a data type + a component), GetLegendHandle (creates a handle).
# docs/refs/HV_API.md section 12 has one row per method and the reason of each exclusion.
proc ::pis::result::dump_calls {} {
    set out [list]
    foreach name {GetAverageColor GetAverageMode GetAverageModeList GetColoredByLayer
                  GetCornerDataEnabled GetCurrentPlotStyle GetDataType GetDiscreteColor
                  GetFeatureAngleAverage GetFeatureAngleAverageEnableState GetIgnoredFlippedNormal
                  GetInterpolateColor GetLayer GetMultiplier GetResultSystem GetShellLayer
                  GetShowMidsideNodeResults GetThresholdMaxEnableState GetValueFilterEnableState
                  IsMultipleLayer} {
        lappend out [list pisCt $name]
    }
    foreach d [::pis::result::dims] {
        lappend out [list pisCt GetDimensionEnabled $d]
    }
    foreach d {node line shell solid} {
        lappend out [list pisCt GetDataComponent $d]
    }
    lappend out [list pisR GetNumberOfSubcases Base]
    lappend out [list pisR GetCurrentSubcase]
    lappend out [list pisR GetSubcaseList Base]
    lappend out [list pisC GetDisplayOptions contour]
    return $out
}

# The read-only script of the dump: the same handle chain as the probe, then one caught getter per
# call, then the close. Every line is ONE complete command (the adapter folds them into one journal
# line), and the answer lands in ::pis::result::dumped because the close must stay the last command.
proc ::pis::result::dump_script {index} {
    set lines [list "pisR GetContourCtrlHandle pisCt"]
    foreach call [::pis::result::dump_calls] {
        set name [join [lrange $call 1 end] " "]
        lappend lines [format {set pisDV ""; if {[catch {%s} pisDV]} { set pisDV "ERR $pisDV" }; lappend ::pis::result::dumped [list {%s} $pisDV]} \
            $call $name]
    }
    set tail "set ::pis::result::dumped {}\n[join $lines "\n"]"
    return [::pis::result::script $index $tail 0]
}

# The dump as {name value} pairs. Raises (with the build's own text) only when the chain itself
# cannot be walked: then there is no window to dump and the caller prints that instead.
proc ::pis::result::dump_dict {index} {
    variable dumped
    set dumped {}
    if {[catch {::pis::hw::probe [::pis::result::dump_script $index]} why]} {
        error [string trim $why]
    }
    return $dumped
}

# ONE log block for one window: a header, one "name = value" line per documented getter, the line
# that says the simulation is NOT dumped, and an end line with the counts. Read-only; INFO level so a
# wall of getters is not mistaken for a wall of errors.
proc ::pis::result::dump_window {cfg index} {
    ::pis::result::need_common
    ::pis::result::need_hw
    set pairs [list]
    if {[catch {set pairs [::pis::result::dump_dict $index]} why]} {
        set pairs [list [list probe "ERR [string trim $why]"]]
    }
    ::pis::common::log $cfg INFO [format "STATE DUMP window %s" $index]
    set errors 0
    foreach pair $pairs {
        set value [lindex $pair 1]
        if {[string first "ERR " $value] == 0} { incr errors }
        ::pis::common::log $cfg INFO [format "  %s = %s" [lindex $pair 0] $value]
    }
    ::pis::common::log $cfg INFO "  simulation = NOT DUMPED (no documented no-argument getter; see docs/refs/HV_API.md section 12)"
    ::pis::common::log $cfg INFO [format "STATE DUMP end window %s (%d getter(s), %d error(s))" \
        $index [llength $pairs] $errors]
    return $pairs
}

# --- the SNAPSHOT (T-030 item e): the same evidence as the log, on demand --------------------------
# `::pis::result::snap before` reads the windows and keeps the answer under <tag>, so a later
# `::pis::result::diff before after` says WHAT changed instead of "nothing worked". READ-ONLY by
# construction: read_state is the probe (getters only) and dump_dict is the T-029 getter list - no
# setter, no Draw, no journal line. Console-only on purpose: the log toolbar is frozen by
# docs/refs/SPEC_gui.txt (Clear / Save / Load... / Run log > / continue on error), so a new button
# would be a GUI change nobody asked for; the module's own failure path already prints the same
# evidence automatically.
# <windows> is a list of window indexes; empty means "every window the page reports" (1..api, the
# F2-safe count of ::pis::hw::observe_dict).
proc ::pis::result::snap {tag {windows ""}} {
    variable snaps
    ::pis::result::need_common
    ::pis::result::need_hw
    set t [string trim $tag]
    if {$t eq ""} {
        error "::pis::result::snap: empty tag (use a name such as before or after)"
    }
    set wl $windows
    if {[llength $wl] == 0} {
        set api [dict get [::pis::hw::observe_dict] api]
        if {![string is integer -strict $api] || $api < 1} {
            error "::pis::result::snap: the page did not answer how many windows it has (pass the window numbers)"
        }
        set wl [list]
        for {set i 1} {$i <= $api} {incr i} { lappend wl $i }
    }
    set shot [dict create]
    foreach w $wl {
        if {![string is integer -strict $w] || $w < 1} {
            error "::pis::result::snap: window numbers start at 1, got '$w'"
        }
        set one ""
        if {[catch {set one [::pis::result::read_state $w]} why]} {
            dict set shot $w [dict create values "no read-back: [string trim $why]" dump [list]]
            continue
        }
        set dump [list]
        catch {set dump [::pis::result::dump_dict $w]}
        dict set shot $w [dict create values [::pis::result::trace_values $one] dump $dump]
    }
    dict set snaps $t $shot
    foreach w [lsort -integer [dict keys $shot]] {
        ::pis::common::log "" INFO [format "SNAP %s window %s %s" \
            $t $w [dict get $shot $w values]]
    }
    return $shot
}

# One snapshot as log text, one line per window (the same text `snap` logged).
proc ::pis::result::snaps_text {tag} {
    variable snaps
    set t [string trim $tag]
    if {![dict exists $snaps $t]} {
        error [format "::pis::result::snaps_text: no snapshot named '%s' (have: %s)" \
            $t [join [lsort [dict keys $snaps]] {, }]]
    }
    set shot [dict get $snaps $t]
    set out [list]
    foreach w [lsort -integer [dict keys $shot]] {
        lappend out [format "SNAP %s window %s %s" $t $w [dict get $shot $w values]]
    }
    return [join $out "\n"]
}

# The difference between two snapshots, one block per window: "unchanged" when every value is the
# same, otherwise both sides. The TWO reasons a run can fail look identical in a bare log - the getter
# never changed (nothing was applied) or the getter lies (it changed and still says no) - and this is
# the text that tells them apart.
proc ::pis::result::diff {a b} {
    variable snaps
    foreach t [list [string trim $a] [string trim $b]] {
        if {![dict exists $snaps $t]} {
            error [format "::pis::result::diff: no snapshot named '%s' (have: %s)" \
                $t [join [lsort [dict keys $snaps]] {, }]]
        }
    }
    set ta [string trim $a]
    set tb [string trim $b]
    set sa [dict get $snaps $ta]
    set sb [dict get $snaps $tb]
    set wins [lsort -integer -unique [concat [dict keys $sa] [dict keys $sb]]]
    set out [list]
    foreach w $wins {
        set va "not in $ta"
        set vb "not in $tb"
        if {[dict exists $sa $w]} { set va [dict get $sa $w values] }
        if {[dict exists $sb $w]} { set vb [dict get $sb $w values] }
        if {$va eq $vb} {
            lappend out [format "DIFF window %s unchanged: %s" $w $va]
        } else {
            lappend out [format "DIFF window %s\n  %s: %s\n  %s: %s" $w $ta $va $tb $vb]
        }
    }
    if {[llength $out] == 0} { lappend out "DIFF no window in either snapshot" }
    return [join $out "\n"]
}

# else = the active window only. One apply per window, one read-back line per window that passed,
# and ONE ::pis::hw::refresh after the loop so the page repaints once the state is provably right.
# A failing window stops the run unless [log] continue_on_error says otherwise; the exit status is
# the number of windows that changed, so 0 can never be mistaken for "all done".
proc ::pis::result::run {root cfg scope} {
    variable applied
    variable failed
    ::pis::result::need_common
    ::pis::result::need_hw
    if {$scope ne "layout" && $scope ne "active"} {
        error "::pis::result::run: unknown scope '$scope' (expected active or layout)"
    }
    set applied 0
    set failed 0
    # A new run forgets which methods this build lacks, so the ONE "method absent on this build"
    # INFO line is written once per run and not once per session (T-027).
    catch {::pis::hw::absent_reset}
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
    variable failed 0
    variable calls 0
    variable last_window ""
    variable last_type ""
    variable readback ""
    variable state ""
    variable variant 0
    variable answer ""
    return
}
