# src/01_scripts/_tcl_pis_11_hw_adapter.tcl
# ::pis::hw adapter - the ONLY file that knows a HyperView command variant (task T-002c).
# SPEC.md D2: Load All / Reset send every HyperView command through this file. ENV
# (2026-11-10): there is no copy-back channel from the HyperView machine, so a variant stays
# UNVERIFIED until the human replies ok/fail; that reply, not a spike, is the evidence.
# Every attempt goes through ::pis::hw::exec, so a working command lands in the journal and a
# failing one does not. A failing variant falls through to the next one and the log says so.
# Tcl/Tk 8.5 compatible, no tcllib, no network, no package require.
# Sourcing this file defines procs only: it never calls HyperView.
#
# One proc per operation, each running an ordered variant list:
#   ::pis::hw::reset_session {}                    clear the session
#   ::pis::hw::load_model {path}                   load ONE model
#   ::pis::hw::make_grid {cols rows}               build the cols x rows window grid
#   ::pis::hw::load_result_in_window {index path}  result file into window <index>
#   ::pis::hw::select_window {index}               make window <index> the active one
#   ::pis::hw::import_legend {path}                import a legend into the active window
# Console helpers, no file edit needed:
#   ::pis::hw::use {op n}       try variant n from now on (e.g. ::pis::hw::use make_grid 2)
#   ::pis::hw::variant {op}     current variant number (1..N)
#   ::pis::hw::variants {op}    that op's list: n, cmd, src, note
#   ::pis::hw::table {}         every op -> its variant list
#   ::pis::hw::help {}          print the table + the use syntax
#   ::pis::hw::reset_state {}   variants back to 1 (tests)
# A variant's source is exactly one of: an Altair documentation URL, docs/refs/<file
# section>, or the label UNVERIFIED-GUESS. No help.altair.com page could be reached on
# 2026-11-10 (404 / search challenge), so nothing here is sourced from memory: every
# command without a line in docs/refs/ carries UNVERIFIED-GUESS and sits last in its list.

namespace eval ::pis::hw {
    # Chosen start variant per op, kept across a re-source like the journal buffer.
    if {![info exists adapt_at]} { set adapt_at [dict create] }
}

# The variant table: op -> ordered list of {n <number> cmd <hwc args> src <source>
# note <what a working variant shows>}. Tokens in cmd are whole elements: %path, %cols,
# %rows, %index, and %index0 (= index - 1, for a 0-based HyperView). Rules: a sourced
# variant comes before a guess; n is 1..N in trial order.
proc ::pis::hw::table {} {
    set t [dict create]
    dict set t reset_session [list \
        [dict create n 1 cmd {session new} src {UNVERIFIED-GUESS} \
            note {one empty session, the File > New equivalent}] \
        [dict create n 2 cmd {page new} src {UNVERIFIED-GUESS} \
            note {one new empty page; the old model may survive}] \
        [dict create n 3 cmd {session reset} src {UNVERIFIED-GUESS} \
            note {older builds; clears in place}]]
    dict set t load_model [list \
        [dict create n 1 cmd {model load %path} src {UNVERIFIED-GUESS} \
            note {exactly one model, in one window}] \
        [dict create n 2 cmd {model open %path} src {UNVERIFIED-GUESS} \
            note {same, other verb}] \
        [dict create n 3 cmd {window loadmodel %path} src {UNVERIFIED-GUESS} \
            note {the window verb instead of the model one}]]
    dict set t make_grid [list \
        [dict create n 1 cmd {page layout %cols %rows} src {UNVERIFIED-GUESS} \
            note {the window count becomes cols x rows}] \
        [dict create n 2 cmd {page setlayout %cols %rows} src {UNVERIFIED-GUESS} \
            note {same, other verb; check the count again}] \
        [dict create n 3 cmd {window layout %cols %rows} src {UNVERIFIED-GUESS} \
            note {the layout is set from a window instead of the page}]]
    dict set t load_result_in_window [list \
        [dict create n 1 cmd {result load %path} src {UNVERIFIED-GUESS} \
            note {after select_window only the active window gains it}] \
        [dict create n 2 cmd {result add %path} src {UNVERIFIED-GUESS} \
            note {same, other verb}] \
        [dict create n 3 cmd {result load %path %index} src {UNVERIFIED-GUESS} \
            note {the command takes the window number itself}]]
    dict set t select_window [list \
        [dict create n 1 cmd {page setactivewindow %index} src {UNVERIFIED-GUESS} \
            note {window <index> is active, windows numbered from 1}] \
        [dict create n 2 cmd {page setactivewindow %index0} src {UNVERIFIED-GUESS} \
            note {same command, windows numbered from 0}] \
        [dict create n 3 cmd {window activate %index} src {UNVERIFIED-GUESS} \
            note {activate by the window verb, 1-based}]]
    dict set t import_legend [list \
        [dict create n 1 cmd {result scalar legend import %path} \
            src {docs/refs/SPEC_load_legend.txt FILE 3 (apply_file) + docs/refs/SPEC_gui.txt sec.6.2} \
            note {the active window shows the legend, the other windows do not}] \
        [dict create n 2 cmd {legend import %path} src {UNVERIFIED-GUESS} \
            note {short form of the same operation}] \
        [dict create n 3 cmd {result legend import %path} src {UNVERIFIED-GUESS} \
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

# Substitute the tokens of one variant command with the real values (whole elements only,
# so a path containing % or spaces can never be mangled).
proc ::pis::hw::fill {template values} {
    set out {}
    foreach e $template {
        if {[dict exists $values $e]} {
            lappend out [dict get $values $e]
        } else {
            lappend out $e
        }
    }
    return $out
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
    if {[llength [info commands ::pis::hw::exec]] == 0} {
        error "::pis::hw: source _tcl_pis_10_hw.tcl first (missing ::pis::hw::exec)"
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
        $op $n $total [dict get $v cmd] [dict get $v src]]
    ::pis::hw::status [format "HV %s: variant %d/%d" $op $n $total]
    return $n
}

# Run one op: try the variants in order, starting with the chosen one, and stop at the first
# success. A failing variant is logged by name and falls through to the next one; nothing is
# silent and the chosen start variant is NOT changed (only the human changes it). exec
# journals the command that worked and journals nothing for the ones that failed.
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
        ::pis::hw::note INFO [format "%s: variant %d/%d <%s> (%s)" $op $n $total $cmd $src]
        ::pis::hw::status [format "HV %s: variant %d/%d" $op $n $total]
        set code [catch {::pis::hw::exec {*}$cmd} res opts]
        if {!$code} {
            if {$n == $start} {
                ::pis::hw::note OK [format "%s: variant %d/%d used (%s)" $op $n $total $src]
            } else {
                ::pis::hw::note OK [format \
                    "%s: variant %d/%d used (%s); keep it with: ::pis::hw::use %s %d" \
                    $op $n $total $src $op $n]
            }
            return $res
        }
        lappend tried [format "%d/%d failed" $n $total]
        set lasterr [string trim $res]
        ::pis::hw::note WARN [format "%s: variant %d/%d failed (%s); trying the next one" \
            $op $n $total $lasterr]
        incr n
    }
    error [format \
        "%s: no variant worked (tried %s). Last error: %s | pick another variant with: ::pis::hw::use %s <n>" \
        $op [join $tried {, }] $lasterr $op]
}

# --- the six operations (the only names the modules may call) ------------------
# Each one validates its arguments first (one clear message naming the offending value),
# then hands the values to ::pis::hw::run, which owns the variant list and the log.

proc ::pis::hw::reset_session {} {
    return [::pis::hw::run reset_session [dict create]]
}

proc ::pis::hw::load_model {path} {
    set p [string trim $path]
    if {$p eq ""} { error "::pis::hw::load_model: empty model path" }
    if {![file isfile $p]} { error "::pis::hw::load_model: model not found: $p" }
    return [::pis::hw::run load_model [dict create %path $p]]
}

proc ::pis::hw::make_grid {cols rows} {
    foreach {label value} [list cols $cols rows $rows] {
        if {![string is integer -strict $value] || $value < 1} {
            error "::pis::hw::make_grid: $label must be a positive integer, got: '$value'"
        }
    }
    return [::pis::hw::run make_grid [dict create %cols $cols %rows $rows]]
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
        [dict create %path $p %index $index %index0 [expr {$index - 1}]]]
}

proc ::pis::hw::select_window {index} {
    if {![string is integer -strict $index] || $index < 0} {
        error "::pis::hw::select_window: window index must be an integer >= 0, got: '$index'"
    }
    set zero 0
    if {$index > 0} { set zero [expr {$index - 1}] }
    return [::pis::hw::run select_window [dict create %index $index %index0 $zero]]
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
    foreach op [::pis::hw::ops] {
        set list [::pis::hw::variants $op]
        puts [format "  %-21s at %d/%d" $op [::pis::hw::at $op] [llength $list]]
        foreach v $list {
            puts [format "    %d. %-38s <- %s" \
                [dict get $v n] [dict get $v cmd] [dict get $v src]]
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

