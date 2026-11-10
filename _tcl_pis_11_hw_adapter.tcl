# src/01_scripts/_tcl_pis_11_hw_adapter.tcl
# ::pis::hw adapter - the ONLY file that knows a HyperView command variant (task T-002c).
# SPEC.md D2 (REVISED 2026-11-10): Load All / Reset send every HyperView command through this
# file, as ONE self-contained script per step - an "hwi" handle script via
# ::pis::hw::exec_hwi, or the proven legend command via ::pis::hw::exec ("hwc").
#
# WHY THIS FILE WAS REWRITTEN (owner's report, 2026-11-10): the log said "loaded" while the
# HyperView window stayed empty. This build answers an hwc subcommand it does not know with
# SILENCE - no error, no effect - so "the call returned" proves nothing. Both answers follow
# from that:
#   1. Nothing here guesses an hwc form for a session change any more. Reset, model, grid and
#      result use the hwi handle API that the working scripts on this machine use
#      (conrod/tcl_guide/hv_model_loader.tcl, conrod/_tmp_hv/batchImportOdb.tcl,
#      conrod/_tmp_hv/training.tcl, test/test_out/TCL_StressExport.tcl).
#   2. "No error" is NOT success. Every variant carries a read-only check (check -> want):
#      after the script runs, the check reads the session back through ::pis::hw::probe (never
#      journaled) and a mismatch FAILS the variant, so the next one is tried and the log says
#      "HyperView did not change". A step can only reach OK when the session proves it moved.
#
# Tcl/Tk 8.5 compatible, no tcllib, no network, no package require.
# Sourcing this file defines procs only: it never calls HyperView.
#
# One proc per operation, each running an ordered variant list:
#   ::pis::hw::reset_session {}                    clear the session
#   ::pis::hw::load_model {path}                   load ONE model into window 1
#   ::pis::hw::make_grid {cols rows}               build the cols x rows window grid
#   ::pis::hw::load_result_in_window {index path}  result file into window <index>
#   ::pis::hw::select_window {index}               make window <index> the active one
#   ::pis::hw::import_legend {path}                import a legend into the active window
# Console helpers, no file edit needed:
#   ::pis::hw::use {op n}       try variant n from now on (e.g. ::pis::hw::use make_grid 2)
#   ::pis::hw::variant {op}     current variant number (1..N)
#   ::pis::hw::variants {op}    that op's list: n, via, cmd, check, want, src, note
#   ::pis::hw::table {}         every op -> its variant list
#   ::pis::hw::help {}          print the table + the use syntax
#   ::pis::hw::reset_state {}   variants back to 1 (tests)
#   ::pis::hw::run {op values}  run an op (the six operations call this)
# A variant's source is one of: docs/refs/<file section>, the local reference script it was
# copied from (conrod/..., test/test_out/...), an Altair documentation URL, or the label UNVERIFIED-GUESS (last
# in its list). No help.altair.com page could be reached on 2026-11-10 (404 / search
# challenge), so every form is either read out of a working script on this machine or marked
# as a guess.

namespace eval ::pis::hw {
    # Chosen start variant per op, kept across a re-source like the journal buffer.
    if {![info exists adapt_at]} { set adapt_at [dict create] }
}

# --- script builders: the hwi handle API is spelled once, here ------------------------
# A builder returns a multi-line script whose first line is "hwi OpenStack" and in which
# every line is a complete command, so ::pis::hw::exec_hwi can fold it into one journal line.
# "@p@" is the handle prefix - "pis" for the step, "psi" for its read-only check - and is
# substituted here, never at run time, so a folded line holds plain handle names.
proc ::pis::hw::stack_open {p} {
    set s {hwi OpenStack
hwi GetSessionHandle @p@S
@p@S GetProjectHandle @p@P
set @p@PgI [@p@P GetActivePage]
@p@P GetPageHandle @p@Page $@p@PgI}
    return [string map [list @p@ $p] $s]
}

proc ::pis::hw::page_close {p} {
    set s {catch {@p@Page ReleaseHandle}
catch {@p@P ReleaseHandle}
catch {@p@S ReleaseHandle}
hwi CloseStack}
    return [string map [list @p@ $p] $s]
}
proc ::pis::hw::window_open {p win} {
    set s {@p@Page GetWindowHandle @p@Win @win@
@p@Win GetClientHandle @p@C}
    return "[::pis::hw::stack_open $p]\n[string map [list @p@ $p @win@ $win] $s]"
}

proc ::pis::hw::window_close {p} {
    set s {catch {@p@C ReleaseHandle}
catch {@p@Win ReleaseHandle}}
    return "[string map [list @p@ $p] $s]\n[::pis::hw::page_close $p]"
}

# --- read-back checks: each one ends with the value ::pis::hw::probe must return -------
# Models in one window. llength of GetModelList covers both answers this build gives (a list
# of model ids, or a single count): "0" -> 0, "1 2" -> 2.
proc ::pis::hw::check_models_in_window {win} {
    set s {set @p@N [llength [@p@C GetModelList]]}
    return "[::pis::hw::window_open psi $win]\n[string map [list @p@ psi] $s]\n[::pis::hw::window_close psi]\nset psiN"
}

# Models in every window of the active page - the reset check.
proc ::pis::hw::check_models_on_page {} {
    set s {set @p@NW [@p@Page GetNumberOfWindows]
set @p@Sum 0
for {set @p@Wi 1} {$@p@Wi <= $@p@NW} {incr @p@Wi} {@p@Page GetWindowHandle @p@Win $@p@Wi; @p@Win GetClientHandle @p@C; incr @p@Sum [llength [@p@C GetModelList]]; catch {@p@C ReleaseHandle}; catch {@p@Win ReleaseHandle}}}
    return "[::pis::hw::stack_open psi]\n[string map [list @p@ psi] $s]\n[::pis::hw::page_close psi]\nset psiSum"
}

# Window count of the active page - the grid check. GetNumberOfWindows answers either the
# count ("8") or the list of window numbers ("1 2 3 4 5 6 7 8"), so it is normalised first.
proc ::pis::hw::check_window_count {} {
    set s {set @p@W [@p@Page GetNumberOfWindows]
if {[string is integer -strict $@p@W]} {set @p@N $@p@W} else {set @p@N [llength $@p@W]}}
    return "[::pis::hw::stack_open psi]\n[string map [list @p@ psi] $s]\n[::pis::hw::page_close psi]\nset psiN"
}

# Result attached in one window: a result controller exists for the window's model AND the
# model list is unchanged (one model). This is a PROXY - it cannot name the result file, and
# it is honest about that: a build that keeps a controller on an empty model passes it, so the
# human's "the windows show a contour" is still the final word.
proc ::pis::hw::check_result_attached {win} {
    set s {set @p@Mid [@p@C GetActiveModel]
@p@C GetModelHandle @p@M $@p@Mid
@p@M GetResultCtrlHandle @p@R
catch {@p@R ReleaseHandle}
set @p@N [llength [@p@C GetModelList]]}
    return "[::pis::hw::window_open psi $win]\n[string map [list @p@ psi] $s]\n[::pis::hw::window_close psi]\nset psiN"
}
# --- the variant table ----------------------------------------------------------------
# op -> ordered list of variant dicts, fields:
#   n     1..N in trial order (start variant = 1 unless ::pis::hw::use moved it)
#   via   hwi = one handle script through exec_hwi; hwc = one command through exec
#   cmd   the script; %tokens are filled by ::pis::hw::fill
#   check read-only script run afterwards through ::pis::hw::probe ("" = no read-back)
#   want  what check must answer, as text ("" = nothing to compare)
#   src   where the form comes from; note = what a working variant proves
proc ::pis::hw::table {} {
    # Body pieces kept as braced literals: no backslash escaping, one command per line.
    set reset_page {
set pisNW [pisPage GetNumberOfWindows]
for {set pisWi 1} {$pisWi <= $pisNW} {incr pisWi} {pisPage GetWindowHandle pisWin $pisWi; pisWin GetClientHandle pisC; foreach pisMi [pisC GetModelList] {if {[string is integer -strict $pisMi] && $pisMi > 0} {pisC DeleteModel $pisMi}}; catch {pisC ReleaseHandle}; catch {pisWin ReleaseHandle}}
}
    set reset_all {
set pisNP [pisP GetNumberOfPages]
for {set pisPi 1} {$pisPi <= $pisNP} {incr pisPi} {pisP GetPageHandle pisPage $pisPi; set pisNW [pisPage GetNumberOfWindows]; for {set pisWi 1} {$pisWi <= $pisNW} {incr pisWi} {pisPage GetWindowHandle pisWin $pisWi; pisWin GetClientHandle pisC; foreach pisMi [pisC GetModelList] {if {[string is integer -strict $pisMi] && $pisMi > 0} {pisC DeleteModel $pisMi}}; catch {pisC ReleaseHandle}; catch {pisWin ReleaseHandle}}; catch {pisPage ReleaseHandle}}
}
    set result_set {
set pisMid [pisC GetActiveModel]
pisC GetModelHandle pisM $pisMid
pisM SetResult %path
catch {pisM ReleaseHandle}}
    set result_add {
set pisMid [pisC GetActiveModel]
pisC GetModelHandle pisM $pisMid
pisM SetResult %path
pisM AddResultFile %path
catch {pisM ReleaseHandle}}

    set t [dict create]
    dict set t reset_session [list \
        [dict create n 1 via hwi \
            cmd "[::pis::hw::stack_open pis]\n$reset_page\n[::pis::hw::page_close pis]" \
            check [::pis::hw::check_models_on_page] want 0 \
            src {conrod/_tmp_hv/batchImportOdb.tcl (page/window walk) + guess: DeleteModel verb} \
            note {every window of the active page holds 0 models - read back, not assumed}] \
        [dict create n 2 via hwi \
            cmd "[::pis::hw::stack_open pis]\n$reset_all\n[::pis::hw::page_close pis]" \
            check [::pis::hw::check_models_on_page] want 0 \
            src {conrod/_tmp_hv/batchImportOdb.tcl (pages 1..N walk) + guess: DeleteModel verb} \
            note {variant 1 applied to every page, not just the active one}] \
        [dict create n 3 via hwi \
            cmd "[::pis::hw::stack_open pis]\nset pisR \[pisS New\]\n[::pis::hw::page_close pis]" \
            check [::pis::hw::check_models_on_page] want 0 \
            src {UNVERIFIED-GUESS} \
            note {the File > New equivalent: no model on the active page left}]]
    dict set t load_model [list \
        [dict create n 1 via hwi \
            cmd "[::pis::hw::window_open pis %win]\npisC AddModel %path\npisC Draw\n[::pis::hw::window_close pis]" \
            check [::pis::hw::check_models_in_window %win] want 1 \
            src {conrod/tcl_guide/hv_model_loader.tcl (AddModel + Draw) + conrod/_tmp_hv/batchImportOdb.tcl} \
            note {window %win holds exactly one model}] \
        [dict create n 2 via hwi \
            cmd "[::pis::hw::stack_open pis]\npisPage GetWindowHandle pisWin %win\npisWin GetClientHandle pisC\npisC AddModel %path\npisWin Draw\n[::pis::hw::window_close pis]" \
            check [::pis::hw::check_models_in_window %win] want 1 \
            src {conrod/tcl_guide/hv_model_loader.tcl (alternate Draw owner) + guess: Draw on the window} \
            note {same model, drawn by the window instead of the client}]]
    dict set t make_grid [list \
        [dict create n 1 via hwi \
            cmd "[::pis::hw::stack_open pis]\npisPage SetLayout %colsx%rows\n[::pis::hw::page_close pis]" \
            check [::pis::hw::check_window_count] want %count \
            src {conrod/tcl_guide/hv_model_loader.tcl (SetLayout + GetNumberOfWindows)} \
            note {the page has %count windows: %cols columns by %rows rows}] \
        [dict create n 2 via hwi \
            cmd "[::pis::hw::stack_open pis]\npisPage SetLayout %rowsx%cols\n[::pis::hw::page_close pis]" \
            check [::pis::hw::check_window_count] want %count \
            src {conrod/tcl_guide/hv_model_loader.tcl (SetLayout, transposed spelling)} \
            note {same %count windows, the token written rows x cols}] \
        [dict create n 3 via hwi \
            cmd "[::pis::hw::stack_open pis]\npisPage SetLayout {%cols X %rows}\n[::pis::hw::page_close pis]" \
            check [::pis::hw::check_window_count] want %count \
            src {conrod/tcl_guide/hv_model_loader.tcl (SetLayout, spaced token)} \
            note {the token spelled "%cols X %rows"}] \
        [dict create n 4 via hwi \
            cmd "[::pis::hw::stack_open pis]\npisPage SetLayout %count\n[::pis::hw::page_close pis]" \
            check [::pis::hw::check_window_count] want %count \
            src {conrod/tcl_guide/hv_model_loader.tcl (SetLayout by window count)} \
            note {the layout named by its window count only}]]
    dict set t load_result_in_window [list \
        [dict create n 1 via hwi \
            cmd "[::pis::hw::window_open pis %index]\n$result_set\n[::pis::hw::window_close pis]" \
            check [::pis::hw::check_result_attached %index] want 1 \
            src {conrod/_tmp_hv/training.tcl + test/test_out/TCL_StressExport.tcl (model SetResult)} \
            note {window %index keeps one model and gains a result controller}] \
        [dict create n 2 via hwi \
            cmd "[::pis::hw::window_open pis %index]\n$result_add\n[::pis::hw::window_close pis]" \
            check [::pis::hw::check_result_attached %index] want 1 \
            src {test/test_out/TCL_StressExport.tcl (SetResult + AddResultFile)} \
            note {same, with the result file registered as well}]]
    dict set t select_window [list \
        [dict create n 1 via hwi \
            cmd "[::pis::hw::stack_open pis]\npisPage SetActiveWindow %index\n[::pis::hw::page_close pis]" \
            check {} want {} \
            src {conrod/_tmp_hv/batchImportOdb.tcl (windows 1..N) + guess: SetActiveWindow} \
            note {window %index is the active one; NO read-back exists, watch the highlight}] \
        [dict create n 2 via hwi \
            cmd "[::pis::hw::stack_open pis]\npisPage SetActiveWindow %zindex\n[::pis::hw::page_close pis]" \
            check {} want {} \
            src {UNVERIFIED-GUESS} \
            note {same command, windows numbered from 0}]]
    dict set t import_legend [list \
        [dict create n 1 via hwc cmd {result scalar legend import %path} \
            check {} want {} \
            src {docs/refs/SPEC_load_legend.txt FILE 3 (apply_file) + docs/refs/SPEC_gui.txt sec.6.2} \
            note {the active window shows the legend, the other windows do not}] \
        [dict create n 2 via hwc cmd {legend import %path} \
            check {} want {} src {UNVERIFIED-GUESS} \
            note {short form of the same operation}] \
        [dict create n 3 via hwc cmd {result legend import %path} \
            check {} want {} src {UNVERIFIED-GUESS} \
            note {result verb without scalar}]]
    return $t
}
# Op names, sorted: the only names ::pis::hw::use and ::pis::hw::variants accept.
proc ::pis::hw::ops {} {
    return [lsort [dict keys [::pis::hw::table]]]
}

# One op's variant list; an unknown name errors with the accepted names.
proc ::pis::hw::variants {op} {
    set t [::pis::hw::table]
    if {![dict exists $t $op]} {
        error "::pis::hw::variants: unknown op '$op' (expected one of: [join [::pis::hw::ops] {, }])"
    }
    return [dict get $t $op]
}

# One argument, quoted so a filled script stays valid Tcl: braced when it holds a blank.
proc ::pis::hw::quote {value} {
    if {[llength [info commands ::pis::journal::quote_arg]] > 0} {
        return [::pis::journal::quote_arg $value]
    }
    return [list $value]
}

# Substitute the %tokens of a script (or of a check) with the real values, left to right,
# with no rescanning: a path that happens to contain "%cols" can never be rewritten. The
# value is inserted already quoted, so a path with spaces stays ONE argument. Manual walking
# beats string map here because string map would strip the braces of the quoted text.
# No token is a prefix of another (that is why the 0-based index is %zindex, not %index0).
proc ::pis::hw::fill {template values} {
    set out ""
    set rest $template
    while {1} {
        set best -1
        set key ""
        foreach k [dict keys $values] {
            set i [string first $k $rest]
            if {$i >= 0 && ($best < 0 || $i < $best)} {
                set best $i
                set key $k
            }
        }
        if {$best < 0} {
            append out $rest
            break
        }
        append out [string range $rest 0 [expr {$best - 1}]]
        append out [::pis::hw::quote [dict get $values $key]]
        set rest [string range $rest [expr {$best + [string length $key]}] end]
    }
    return $out
}

# The first line of a script, for a log line that stays readable when the script has six.
proc ::pis::hw::one_line {script} {
    set lines {}
    foreach raw [split $script "\n"] {
        set t [string trim $raw]
        if {$t ne ""} { lappend lines $t }
    }
    set first [lindex $lines 0]
    if {[llength $lines] > 1} { return "$first ..." }
    return $first
}

# Log sink of the adapter. The shared sink owns the timestamp and the colour, so this only
# forwards level + text; it never swallows a message (without the GUI pane it goes to stderr).
proc ::pis::hw::note {level msg} {
    if {[llength [info commands ::pis::common::log]] > 0} {
        # cfg is not used by the shared sink; "" keeps that signature visible here.
        catch {::pis::common::log "" $level $msg}
        return
    }
    puts stderr [format "%-5s %s" $level $msg]
    return
}

# The variant in use must be visible outside the log too (SPEC ENV: no silent fallback).
proc ::pis::hw::status {msg} {
    if {[llength [info commands ::pis::gui::set_status]] > 0} {
        catch {::pis::gui::set_status $msg}
    }
    return
}

# Offline this file is useless without the wrapper: say so instead of a bare Tcl error.
proc ::pis::hw::need_exec {} {
    if {[llength [info commands ::pis::hw::exec]] == 0 || [llength [info commands ::pis::hw::exec_hwi]] == 0} {
        error "::pis::hw: source _tcl_pis_10_hw.tcl first (missing ::pis::hw::exec / exec_hwi)"
    }
    return
}

# The variant dict with number n, or an error naming the valid range.
proc ::pis::hw::variant_of {op n} {
    set list [::pis::hw::variants $op]
    foreach v $list {
        if {[string is integer -strict $n] && [dict get $v n] == $n} { return $v }
    }
    error [format "::pis::hw::use: %s has variants 1..%d, got: '%s'" $op [llength $list] $n]
}

# The variant this op starts with.
proc ::pis::hw::at {op} {
    variable adapt_at
    ::pis::hw::variants $op
    if {![dict exists $adapt_at $op]} { dict set adapt_at $op 1 }
    return [dict get $adapt_at $op]
}

proc ::pis::hw::variant {op} {
    return [::pis::hw::at $op]
}
# Pick the variant to start with, from one short console line: ::pis::hw::use make_grid 2
# Only this changes the order (SPEC ENV: the human's ok/fail is the evidence), and the line
# is logged + shown in the status bar, so the choice is never silent.
proc ::pis::hw::use {op n} {
    variable adapt_at
    set v [::pis::hw::variant_of $op $n]
    set total [llength [::pis::hw::variants $op]]
    dict set adapt_at $op $n
    ::pis::hw::note INFO [format "adapter %s: variant %d/%d <%s> (%s)" \
        $op $n $total [::pis::hw::one_line [dict get $v cmd]] [dict get $v src]]
    ::pis::hw::status [format "HV %s: variant %d/%d" $op $n $total]
    return $n
}

# Run one op: try the variants in order, starting with the chosen one, and stop at the first
# success. Success has TWO parts (SPEC.md D2 REVISION):
#   1. the script ran (exec_hwi / exec raised nothing), and
#   2. the read-back check proved the session changed (::pis::hw::probe vs want).
# A variant that runs and changes nothing is treated exactly like one that raised - this is
# the whole answer to a build that swallows an unknown command - so it is never reported OK
# and the next variant is tried. Nothing is silent, and the chosen start variant is NOT
# changed (only the human changes it, with ::pis::hw::use).
proc ::pis::hw::run {op values} {
    ::pis::hw::need_exec
    set list [::pis::hw::variants $op]
    set total [llength $list]
    set start [::pis::hw::at $op]
    set tried {}
    set lasterr ""
    set n $start
    while {$n <= $total} {
        set v [lindex $list [expr {$n - 1}]]
        set cmd [::pis::hw::fill [dict get $v cmd] $values]
        set src [dict get $v src]
        set via hwi
        if {[dict exists $v via]} { set via [dict get $v via] }
        ::pis::hw::note INFO [format "%s: variant %d/%d <%s> (%s)" \
            $op $n $total [::pis::hw::one_line $cmd] $src]
        ::pis::hw::status [format "HV %s: variant %d/%d" $op $n $total]
        set check ""
        if {[dict exists $v check]} { set check [dict get $v check] }
        # Nothing is journaled before the proof: a command that changed nothing must never
        # land in a journal the human will replay, so a checked step runs with -nojournal and
        # the confirmed line is written afterwards, by ::pis::hw::journal_run.
        set deferred 0
        if {$via eq "hwc"} {
            set code [catch {::pis::hw::exec {*}$cmd} res opts]
        } elseif {[string trim $check] ne ""} {
            set code [catch {::pis::hw::exec_hwi $cmd -nojournal} res opts]
            set deferred 1
        } else {
            set code [catch {::pis::hw::exec_hwi $cmd} res opts]
        }
        set why ""
        set confirmed 0
        if {!$code} {
            if {[string trim $check] ne ""} {
                set want ""
                if {[dict exists $v want]} {
                    set want [string trim [::pis::hw::fill [dict get $v want] $values]]
                }
                set pcode [catch {::pis::hw::probe [::pis::hw::fill $check $values]} got]
                if {$pcode} {
                    set code 1
                    set why "the read-back itself failed: [string trim $got]"
                } elseif {$got ne $want} {
                    set code 1
                    set why [format \
                        "HyperView did not change: read-back answered '%s', expected '%s'" \
                        $got $want]
                }
                set res $got
                set confirmed 1
            }
        }
        if {!$code} {
            if {$deferred} {
                catch {::pis::hw::journal_run $cmd}
            }
            set tail [expr {$confirmed ? " and confirmed by the read-back" : " (no read-back exists)"}]
            if {$n == $start} {
                ::pis::hw::note OK [format "%s: variant %d/%d used%s (%s)" $op $n $total $tail $src]
            } else {
                ::pis::hw::note OK [format \
                    "%s: variant %d/%d used%s (%s); keep it with: ::pis::hw::use %s %d" \
                    $op $n $total $tail $src $op $n]
            }
            return $res
        }
        lappend tried [format "%d/%d failed" $n $total]
        if {$why ne ""} {
            set lasterr $why
        } else {
            set lasterr [string trim $res]
        }
        ::pis::hw::note WARN [format "%s: variant %d/%d failed (%s); trying the next one" \
            $op $n $total $lasterr]
        incr n
    }
    error [format \
        "%s: no variant worked (tried %s). Last error: %s | pick another variant with: ::pis::hw::use %s <n>" \
        $op [join $tried {, }] $lasterr $op]
}
# --- the six operations (the only names the modules may call) --------------------------
# Each one validates its arguments first (one clear message naming the offending value),
# then hands the values to ::pis::hw::run, which owns the variant list, the read-back and
# the log. Values are quoted by ::pis::hw::fill, so a path with spaces stays one argument.

proc ::pis::hw::reset_session {} {
    return [::pis::hw::run reset_session [dict create]]
}

proc ::pis::hw::load_model {path} {
    set p [string trim $path]
    if {$p eq ""} { error "::pis::hw::load_model: empty model path" }
    if {![file isfile $p]} { error "::pis::hw::load_model: model not found: $p" }
    return [::pis::hw::run load_model [dict create %path $p %win 1]]
}

proc ::pis::hw::make_grid {cols rows} {
    foreach {label value} [list cols $cols rows $rows] {
        if {![string is integer -strict $value] || $value < 1} {
            error "::pis::hw::make_grid: $label must be a positive integer, got: '$value'"
        }
    }
    return [::pis::hw::run make_grid \
        [dict create %cols $cols %rows $rows %count [expr {$cols * $rows}]]]
}

proc ::pis::hw::load_result_in_window {index path} {
    if {![string is integer -strict $index] || $index < 1} {
        error "::pis::hw::load_result_in_window: window index must be a positive integer, got: '$index'"
    }
    set p [string trim $path]
    if {$p eq ""} { error "::pis::hw::load_result_in_window: empty result path" }
    if {![file isfile $p]} {
        error "::pis::hw::load_result_in_window: result file not found: $p"
    }
    return [::pis::hw::run load_result_in_window \
        [dict create %path $p %index $index %zindex [expr {$index - 1}]]]
}

proc ::pis::hw::select_window {index} {
    if {![string is integer -strict $index] || $index < 1} {
        error "::pis::hw::select_window: window index must be a positive integer, got: '$index'"
    }
    return [::pis::hw::run select_window \
        [dict create %index $index %zindex [expr {$index - 1}]]]
}

proc ::pis::hw::import_legend {path} {
    set p [string trim $path]
    if {$p eq ""} { error "::pis::hw::import_legend: empty legend path" }
    if {![file isfile $p]} { error "::pis::hw::import_legend: legend file not found: $p" }
    return [::pis::hw::run import_legend [dict create %path $p]]
}

# Print the whole table, the current variant per op and the one-line way to change it.
proc ::pis::hw::help {} {
    puts "PIS HyperView adapter (T-002c): variant 1 is the start, a failing one falls through."
    puts "  A variant only counts as OK when its read-back check proves the session changed."
    foreach op [::pis::hw::ops] {
        set list [::pis::hw::variants $op]
        puts [format "  %-21s at %d/%d" $op [::pis::hw::at $op] [llength $list]]
        foreach v $list {
            set rd "no read-back"
            if {[dict exists $v check] && [string trim [dict get $v check]] ne ""} {
                set rd "read-back = [dict get $v want]"
            }
            puts [format "    %d. %-44s \[%s\] <- %s" \
                [dict get $v n] [::pis::hw::one_line [dict get $v cmd]] $rd [dict get $v src]]
        }
    }
    puts "  change one: ::pis::hw::use <op> <n>   e.g. ::pis::hw::use make_grid 2"
    return
}

# Every op back to its first variant (tests, and a fresh session).
proc ::pis::hw::reset_state {} {
    variable adapt_at
    set adapt_at [dict create]
    return
}
