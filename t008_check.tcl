# src/spike/t008_check.tcl
# T-008 check, ONE FILE, reworked by T-029 after the owner's `T-008: fail 4` (a correct result name
# still shows no contour) and after this file's own INPUT DEFECT (it died with `VERDICT: FAIL no
# result name` on a machine where the app already knew the name, so it produced NO evidence).
#
# How to use it in HyperView - nothing to type:
#   0. Copy the WHOLE src/01_scripts folder into the HyperView script path, then File > New.
#   1. Load All as usual (the GUI button), so the windows hold the model and their result files.
#   2. Source this file (File > Run Script, or drop it on the Tcl console).
#   3. It writes ONE report file: src/02_working/t008_check.txt - send that back, ALL of it.
#
# INPUT RULES (T-029 item 0 - a check must never die on an input the app already knows):
#   result name : t8_name at the top -> else the GUI's own [result] selection in the ini (read with
#                 ::pis::common, the reader the GUI uses) -> else the FIRST type window 1 offers.
#                 ONE line says which source won: "CHECK input: result name '<n>' from <source>".
#   model file, result files, layout id : the ini first, a variable at the top only as an override,
#                 one CHECK line per value taken.
#   no model in window 1 -> "CHECK input: no model loaded in window 1: run Load All first", then the
#                 read-only state of every window, then the file stops.
#   nothing anywhere -> "VERDICT: FAIL input: ..." AFTER the types window 1 offers (first 20) and the
#                 read-only state dump, so the report is never empty of evidence.
#   The BUILD line is printed exactly ONCE (the adapter prints its own when it is sourced; that line
#   is kept and this file does not print a second one).
#
# What it does, in this order (it never edits a file):
#   BUILD   - which copy of the app this session runs
#   CHECK   - every input value and where it came from, the window count, each window's result file
#   BEFORE  - per window, what the window answers NOW: type, the three dimensions, subcase, component
#   STEP    - ::pis::result::run <scope>: the count it answered, or the ERROR text it raised
#             (a failing window leaves one "variant v/n ..." line EACH plus ONE "STATE DUMP window 1"
#             block in the report - the module writes them, this file only sinks the log into it)
#   AFTER   - the same read-back as BEFORE, taken after the module ran
#   CELL    - ONLY when MATRIX = 1: one line per diagnostic cell, window 1 only, each with the FULL
#             read-only getter dump on the same line (name=value;...)
#   MATRIX  - ONLY when MATRIX = 1: the best cell and the state restored afterwards
#   VARIANT - which apply variant passed (1 type-first/true, 2 enable-first/true, 3 type-first/1,
#             4 enable-first/1, 5 type-first/true + SetDisplayOptions contour true; HV_API.md s.11-12)
#   VERDICT - PASS, or FAIL with one reason per window, judged from the AFTER read-back with the
#             module's own verdict rule, never from a log line.
# Tcl 8.5 only: no tcllib, no try/finally, no package require. Every HyperView call goes through
# ::pis::hw - the same procs the GUI uses, so the journal looks the same.

# --- the values to edit by hand -------------------------------------------------------
# EVERY setting below is a GLOBAL (::t8_*) on purpose: the owner may source this file from a
# proc in their own wrapper, and a bare `set` there would create a local the rest of the file
# cannot see (T-029: that trap is what made the input-rules test run on defaults).
# The result type to apply. Empty = the GUI's [result] selection, else the first type window 1
# offers. Set it only to check a DIFFERENT type than the GUI last used.
if {![info exists ::t8_name]} { set ::t8_name "" }
# Model file and layout id: empty = take them from the ini ([session] model_file, [layout] id).
# Set them only to check a value the ini does not hold.
if {![info exists ::t8_model]} { set ::t8_model "" }
if {![info exists ::t8_layout]} { set ::t8_layout "" }
# Scope of the run: "layout" = every window Load All filled (the GUI's button), "active" = the
# active window only. The BEFORE/AFTER lines always cover every window, so the difference is
# visible either way.
if {![info exists ::t8_scope]} { set ::t8_scope "layout" }
# Where the report goes. Empty = src/02_working next to this file (a test points it elsewhere).
if {![info exists ::t8_report_dir]} { set ::t8_report_dir "" }
# T-029 DIAGNOSTIC MATRIX: 0 = off, 1 = run the nine cells below on WINDOW 1 ONLY, after Load All.
# It changes ONLY the result data type, the dimension enable state and the contour display option of
# window 1, and RESTORES type + dimensions at the end (the last lines print what was restored).
# Which cells can change state: cells 1-9 all set the type and the dimensions of window 1; cell 9
# also selects window 1 (SetActiveWindow). No other window is touched.
if {![info exists ::t8_matrix]} { set ::t8_matrix 0 }



# ======================================================================================
# Nothing below needs editing.
# ======================================================================================
namespace eval ::t8 {
    variable fd ""
    variable real "puts"
    # T-027: what the diagnostic matrix and the getter probe write into.
    variable got ""
    variable cells {}
    variable ok {}
    # T-029: set as soon as a BUILD line reached the report (the adapter prints its own; the file
    # must not print a second one).
    variable saw_build 0
}

# One line: the console AND the report file. The report write uses 'chan puts' on the channel,
# never the global puts, which may be the capturing proc below (emit -> puts -> emit would loop).
proc ::t8::emit {text} {
    variable real
    variable fd
    if {[string match "BUILD *" [string trim $text]]} { set ::t8::saw_build 1 }
    if {$real ne "" && [llength [info commands $real]]} {
        $real $text
    } else {
        puts $text
    }
    if {$fd ne ""} {
        catch {chan puts $fd $text}
    }
    return
}

# Did a BUILD line already reach the report? The adapter prints one when it is sourced, so the file
# asks this instead of printing a second line (T-029 item 0d).
proc ::t8::report_has_build {} {
    variable saw_build
    if {[info exists saw_build] && $saw_build} { return 1 }
    return 0
}

# The data type labels a window answers (S30), first <n> of them, for the one line that must always
# be in the report when no name could be resolved.
proc ::t8::types_text {st {n 20}} {
    set labels [list]
    if {$st ne ""} { catch {set labels [dict get $st labels]} }
    if {[llength $labels] == 0} { return "(none)" }
    if {[llength $labels] > $n} { set labels [lrange $labels 0 [expr {$n - 1}]] }
    return [join $labels ", "]
}

proc ::t8::capture_on {} {
    variable real
    if {$real ne "puts"} { return }
    if {[catch {rename ::puts ::t8::console_puts}]} { return }
    set real ::t8::console_puts
    proc ::puts {args} {
        if {[llength $args] > 1} { return [::t8::console_puts {*}$args] }
        ::t8::emit [lindex $args 0]
    }
    return
}

proc ::t8::capture_off {} {
    variable real
    if {[llength [info commands ::t8::console_puts]]} {
        catch {rename ::puts {}}
        catch {rename ::t8::console_puts ::puts}
    }
    set real puts
    return
}

# The module reports through ::pis::common::log, which without the GUI writes to STDERR. Give it a
# sink that ALWAYS reaches this report: a sink that is already there (the GUI's log panel, a test)
# is renamed and called first, so the panel keeps filling and the report gets every line as well.
# T-029: without the chaining, a GUI session's report held no STATE DUMP at all - the dump went to
# the panel and the evidence file, the one thing the owner sends back, stayed silent.
proc ::t8::log_sink {} {
    variable sink_done
    if {[info exists sink_done]} { return 0 }
    set sink_done 1
    namespace eval ::pis::gui {}
    if {[llength [info commands ::pis::gui::log_line]] > 0} {
        catch {rename ::t8::log_line_prev {}}
        catch {rename ::pis::gui::log_line ::t8::log_line_prev}
    }
    proc ::pis::gui::log_line {level msg} {
        if {[llength [info commands ::t8::log_line_prev]] > 0} {
            catch {::t8::log_line_prev $level $msg}
        }
        ::t8::emit [format "%-5s %s" [string toupper [string trim $level]] $msg]
    }
    return 1
}

proc ::t8::stamp {} {
    return [clock format [clock seconds] -format {%Y-%m-%d %H:%M}]
}

# Read one value out of the app's ini without loading the app (plain text: [section], key = value).
proc ::t8::ini_get {file section key} {
    if {![file isfile $file]} { return "" }
    if {[catch {open $file r} fd]} { return "" }
    set out ""
    set in ""
    while {[gets $fd line] >= 0} {
        set line [string trim $line]
        if {$line eq ""} { continue }
        set c [string index $line 0]
        if {$c eq ";" || $c eq "#"} { continue }
        if {[regexp {^\[(.+)\]$} $line -> sec]} {
            set in [string trim $sec]
            continue
        }
        if {$in ne $section} { continue }
        if {![regexp {^([^=]+)=(.*)$} $line -> k v]} { continue }
        if {[string trim $k] ne $key} { continue }
        set out [string trim $v]
    }
    catch {close $fd}
    return $out
}

proc ::t8::open_report {dir} {
    if {[catch {file mkdir $dir} err]} {
        return [list "" "cannot create the report folder $dir: $err"]
    }
    set file [file join $dir t008_check.txt]
    if {[catch {open $file w} fd]} {
        return [list "" "cannot write $file: $fd"]
    }
    return [list $fd ""]
}


# --- the read-back, the apply and the verdict -----------------------------------------
# One read-back per window of the page, in order: {k st k st ...}, st = "" when the window did not
# answer (no model, no result). Read-only: it never changes the session.
proc ::t8::read_all {api} {
    set out {}
    set k 0
    while {$k < $api} {
        incr k
        set st ""
        catch {set st [::pis::result::read_state $k]}
        lappend out $k $st
    }
    return $out
}

# The BEFORE / AFTER lines: the same five values the module judges on (S29 type, S36 dimensions,
# S40 subcase, S38 component), written with the module's own formatter so the report and the
# module's log line can never say different things.
proc ::t8::print_states {tag cfg states} {
    foreach {k st} $states {
        set file [::pis::result::window_file $cfg $k]
        if {$file eq ""} { set file "-" }
        if {$st eq ""} {
            ::t8::emit [format "%s win %s (%s): no read-back (this window holds no result)" $tag $k $file]
            continue
        }
        ::t8::emit [format "%s win %s (%s) %s" $tag $k $file [::pis::result::values_text $st]]
    }
    return
}

# The apply. The GUI's own entry point (::pis::result::run) is used whenever its Load All gate is
# set in THIS session; otherwise the same seam is called per window - ::pis::result::apply_to_window
# is exactly what run calls for window k, so nothing is shortened or faked. Returns
# {code answer what}.
proc ::t8::apply_run {root cfg name scope windows} {
    if {$scope ne "layout"} {
        set code [catch {::pis::result::run $root $cfg active} res]
        return [list $code $res {::pis::result::run active (the GUI's own path)}]
    }
    set gate 0
    if {[llength [info commands ::pis::step01::loaded]] > 0} {
        catch {set gate [::pis::step01::loaded]}
    }
    if {$gate} {
        set code [catch {::pis::result::run $root $cfg layout} res]
        return [list $code $res {::pis::result::run layout (the GUI's own path)}]
    }
    set n 0
    set bad {}
    foreach k $windows {
        if {[catch {::pis::result::apply_to_window $cfg $k $name} res]} {
            lappend bad [format "window %s: %s" $k [string trim $res]]
            continue
        }
        incr n
    }
    set how {::pis::result::apply_to_window per window (no Load All in this session)}
    if {[llength $bad] > 0} {
        return [list 1 [join $bad { | }] $how]
    }
    return [list 0 [format "%d window(s) changed" $n] $how]
}

# PASS only when every JUDGED window (all of them for the layout scope, the active one otherwise)
# that answered BEFORE still answers AFTER and passes the module's own display rule for the label
# that was applied. A window without a result is NAMED, never skipped.
proc ::t8::verdict {label states judge} {
    set bad {}
    set n 0
    foreach {k st} $states {
        if {[lsearch -exact $judge $k] < 0} { continue }
        if {$st eq ""} {
            lappend bad [format "window %s holds no result (run Load All first)" $k]
            continue
        }
        incr n
        lassign [::pis::result::verdict $st $label] ok why
        if {!$ok} {
            lappend bad [format "window %s: %s" $k $why]
        }
    }
    if {[llength $judge] == 0} {
        return [list FAIL "the active window did not answer GetActiveWindow (S33)"]
    }
    if {$n == 0} {
        return [list FAIL "no window holds a result: run Load All in the GUI (or src/spike/t006_check.tcl) first"]
    }
    if {[llength $bad] > 0} {
        return [list FAIL [join $bad { | }]]
    }
    return [list PASS [format "%d window(s) display '%s' by read-back" $n $label]]
}

# The whole run: read, apply, read again, then judge. Every step is caught so the report always
# ends with a VERDICT line - the file travels, not the console.
proc ::t8::run {root cfg name scope} {
    ::t8::emit [format "T008 check %s" [::t8::stamp]]
    set ob [::pis::hw::observe_dict]
    set api [dict get $ob api]
    if {![string is integer -strict $api] || $api < 1} {
        return [list FAIL [format "the page did not answer a window count (%s)" [dict get $ob line]]]
    }
    ::t8::emit [format "CHECK %d window(s) on the page, scope %s" $api $scope]
    set before [::t8::read_all $api]
    ::t8::print_states BEFORE $cfg $before
    # Which windows the run must change, and therefore the ones this verdict judges: the windows
    # the module itself would target (all of them for the layout scope, the active one otherwise).
    set judge {}
    if {$scope eq "layout"} {
        if {[catch {set judge [::pis::result::targets $cfg layout]}]} {
            set judge {}
            set k 0
            while {$k < $api} {
                incr k
                lappend judge $k
            }
        }
    } else {
        set ast ""
        if {![catch {set ast [::pis::result::read_state -1]}]} {
            set judge [list [dict get $ast win]]
        }
    }
    ::t8::emit [format "ASKED result '%s' on %s (window(s): %s)" $name $scope $judge]
    lassign [::t8::apply_run $root $cfg $name $scope $judge] code res how
    set shown [string trim $res]
    if {$code} {
        ::t8::emit [format "STEP %s failed: %s" $how $shown]
    } else {
        if {[string is integer -strict $shown]} {
            set shown [format "%s window(s) changed" $shown]
        }
        ::t8::emit [format "STEP %s -> %s" $how $shown]
    }
    set after [::t8::read_all $api]
    ::t8::print_states AFTER $cfg $after
    # T-027: the diagnostic matrix (opt-in) and the read-only getter probe, on WINDOW 1 only. Both
    # run AFTER the verdict material above was captured, so they cannot change what this file says
    # about the module; the matrix restores the state it changed and prints what it restored.
    set ::t8_label $name
    set ::t8_dims [list]
    foreach {k st} $before {
        if {$k != 1 || $st eq ""} { continue }
        set i 0
        foreach d {line shell solid} {
            lappend ::t8_dims $d [lindex [dict get $st dims] $i]
            incr i
        }
    }
    if {[string trim $::t8_matrix] ne "" && $::t8_matrix != 0} {
        set btype ""
        foreach {k st} $before {
            if {$k == 1 && $st ne ""} { set btype [dict get $st type] }
        }
        if {[catch {::t8::matrix $btype} merr]} {
            ::t8::emit [format "MATRIX INCOMPLETE: %s" [string trim $merr]]
        }
    }
    catch {::t8::getters}
    set v $::pis::result::variant
    set vtext "none (no variant passed)"
    if {$v >= 1} {
        set vtext [format "%s (%s)" $v [::pis::result::variant_name $v]]
    }
    ::t8::emit [format "VARIANT %s" $vtext]
    set lines 0
    set last ""
    foreach line [split [::pis::journal::lines] "\n"] {
        if {[regexp {^hwi[ \t]} $line]} {
            incr lines
            set last $line
        }
    }
    ::t8::emit [format "JOURNAL %d hwi line(s) this session" $lines]
    if {$last ne ""} {
        ::t8::emit [format "JOURNAL last %s" [::pis::hw::clip $last 100]]
    }
    lassign [::t8::verdict $name $after $judge] state why
    if {$code} {
        # The read-back may still show the label (an earlier run left it there), but the module
        # refused to do it: report BOTH, so the reason is never hidden behind a PASS.
        return [list FAIL [format "%s | the module reported: %s" $why [string trim $res]]]
    }
    return [list $state $why]
}

# --- the T-029 diagnostic matrix (window 1 only, restores what it changes) -------------
# One CELL: reset every dimension to false with the documented call, put the data type back to the
# type window 1 had BEFORE, send the cell's own order and literal, Draw on window 1's client, let Tk
# paint when the cell asks for it, then read EVERYTHING back - the module's five values AND the full
# read-only getter dump of item 3 on the same line (`name=value;...`). Never raises: the build's own
# error text is printed in full on the CELL line.
# mode ""      : the plain cell (T-027 behaviour)
# mode "wait"  : after the apply script, after 300 + update + a Draw through the same chain (timing)
# mode "twice" : Draw called TWICE before the read
# mode "active": window 1 is made the ACTIVE window first (the chain already selects it) and the
#                data type is then read through the ACTIVE client as well, so a pass/fail difference
#                between the two paths exposes a wrong or stale contour control (handle identity).
proc ::t8::matrix_cell {n order state draw before {mode ""}} {
    set lines [list "pisR GetContourCtrlHandle pisCt"]
    foreach d [::pis::result::dims] {
        lappend lines [format "catch {pisCt SetDimensionEnabled %s false}" $d]
    }
    if {$before ne ""} {
        lappend lines [format "catch {pisCt SetDataType %s}" [::pis::hw::quote $before]]
    }
    set en [list]
    foreach d [::pis::result::dims] {
        lappend en [format "catch {pisCt SetDimensionEnabled %s %s}" $d $state]
    }
    set ty [format "catch {pisCt SetDataType %s}" [::pis::hw::quote $::t8_label]]
    if {$order eq "enable_first"} {
        foreach line $en { lappend lines $line }
        lappend lines $ty
    } else {
        lappend lines $ty
        foreach line $en { lappend lines $line }
    }
    lappend lines "catch {pisC Draw}"
    if {$mode eq "twice"} {
        lappend lines "catch {pisC Draw}"
    }
    # mode active: read the type through BOTH paths, so the two contour controls can be compared.
    set ::t8::type_win ""
    set ::t8::type_active ""
    set ::t8::active_idx ""
    if {$mode eq "active"} {
        lappend lines "catch {set ::t8::type_win \[pisCt GetDataType\]}"
        lappend lines "pisPage SetActiveWindow 1"
        lappend lines "pisPage GetWindowHandle pisWinA \[pisPage GetActiveWindow\]"
        lappend lines "catch {set ::t8::active_idx \[pisPage GetActiveWindow\]}"
        lappend lines "pisWinA GetClientHandle pisCA"
        lappend lines "catch {set ::t8::active_model \[pisCA GetActiveModel\]}"
        lappend lines "if {!\[string is integer -strict \$::t8::active_model\] || \$::t8::active_model <= 0} { error \"the active window has no model id\" }"
        lappend lines "pisCA GetModelHandle pisMA \$::t8::active_model"
        lappend lines "pisMA GetResultCtrlHandle pisRA"
        lappend lines "pisRA GetContourCtrlHandle pisCtA"
        lappend lines "catch {set ::t8::type_active \[pisCtA GetDataType\]}"
    }
    set err "none"
    set e ""
    if {[catch {::pis::hw::exec_hwi [::pis::result::script 1 [join $lines "\n"] 1] -nojournal} e]} {
        set err [string trim $e]
    }
    if {$draw} { catch {::pis::hw::refresh} }
    if {$mode eq "wait"} {
        catch {after 300}
        catch {update}
        catch {::pis::hw::exec_hwi [::pis::result::script 1 "catch {pisC Draw}" 1] -nojournal}
        catch {after 300}
        catch {update}
    }
    set st ""
    set why ""
    set dump [::t8::dump_text 1]
    if {[catch {set st [::pis::result::read_state 1]} why]} {
        ::t8::emit [format "CELL %s order=%s bool=%s draw_before_read=%s mode=%s -> no read-back: %s | err=%s | dump=%s" \
            $n $order $state $draw [::t8::mode_name $mode] [string trim $why] $err $dump]
        return [list 0 $st]
    }
    if {$mode eq "active"} {
        ::t8::emit [format "CELL %s order=%s bool=%s draw_before_read=%s mode=%s -> type=%s enabled=%s err=%s | identity active_window=%s type_win=%s type_active=%s same=%s | dump=%s" \
            $n $order $state $draw [::t8::mode_name $mode] [dict get $st type] \
            [::pis::result::enabled_text $st] $err $::t8::active_idx \
            $::t8::type_win $::t8::type_active \
            [expr {$::t8::type_win eq $::t8::type_active ? 1 : 0}] $dump]
        return [list [::pis::result::verdict $st $::t8_label] $st]
    }
    ::t8::emit [format "CELL %s order=%s bool=%s draw_before_read=%s mode=%s -> type=%s enabled=%s err=%s | dump=%s" \
        $n $order $state $draw [::t8::mode_name $mode] [dict get $st type] \
        [::pis::result::enabled_text $st] $err $dump]
    return [list [::pis::result::verdict $st $::t8_label] $st]
}

# The cell's mode as one short word for the CELL line.
proc ::t8::mode_name {mode} {
    if {$mode eq ""} { return plain }
    return $mode
}

# The full read-only getter dump of window 1 as ONE compact line: name=value;name=value;...
# A getter that raises answers "ERR <text>" inside its own field, so one bad method cannot hide the
# others. Read-only by construction (::pis::result::dump_calls holds getters only).
proc ::t8::dump_text {win} {
    set pairs [list]
    if {[catch {set pairs [::pis::result::dump_dict $win]} why]} {
        return "ERR [string trim $why]"
    }
    set out [list]
    foreach pair $pairs {
        lappend out [format "%s=%s" [lindex $pair 0] [lindex $pair 1]]
    }
    return [join $out ";"]
}
# The nine cells, in the order T-029 item 5 asks for: 1-4 = order x literal, 5-6 = the two best
# cells repeated WITHOUT waiting for Tk to paint, 7 = the best cell with after+update+Draw before the
# read (timing), 8 = the best cell with Draw twice, 9 = the best cell read through the ACTIVE client
# (handle identity). Then `MATRIX BEST` and the restore of the ORIGINAL type and dimension states.
proc ::t8::matrix {before} {
    ::t8::emit "MATRIX on: window 1 only, cells 1-9. This changes ONLY the result data type, the dimension enable state and the contour display option of window 1 and restores type + dimensions at the end."
    set ::t8::cells {}
    set ::t8::ok {}
    set plans {
        {1 enable_first true 1}
        {2 type_first true 1}
        {3 enable_first 1 1}
        {4 type_first 1 1}
    }
    foreach p $plans {
        lassign $p n order state draw
        lassign [::t8::matrix_cell $n $order $state $draw $before] v st
        lappend ::t8::cells [dict create n $n order $order state $state draw $draw ok [lindex $v 0] st $st]
        if {[lindex $v 0]} { lappend ::t8::ok $n }
    }
    # Cells 5 and 6: the two best cells above, repeated WITHOUT waiting for Tk to paint. "Best" = the
    # cells that passed, then the cells that at least showed the type; the cell number breaks a tie.
    set order $::t8::ok
    if {[llength $order] < 2} {
        foreach c $::t8::cells {
            set st [dict get $c st]
            if {$st eq ""} { continue }
            if {[dict get $st type] eq $::t8_label} { lappend order [dict get $c n] }
        }
    }
    foreach c $::t8::cells {
        if {[llength $order] >= 2} { break }
        if {[lsearch -exact $order [dict get $c n]] < 0} { lappend order [dict get $c n] }
    }
    set k 5
    foreach pick [lrange $order 0 1] {
        foreach c $::t8::cells {
            if {[dict get $c n] != $pick} { continue }
            lassign [::t8::matrix_cell $k [dict get $c order] [dict get $c state] 0 $before] v st
            lappend ::t8::cells [dict create n $k order [dict get $c order] \
                state [dict get $c state] draw 0 ok [lindex $v 0] st $st]
            incr k
        }
    }
    # Cells 7-9: the best cell's order and literal, with the three extra readings item 5 asks for.
    set best_cell ""
    foreach c $::t8::cells {
        if {[dict get $c ok]} { set best_cell $c ; break }
    }
    if {$best_cell eq "" && [llength $::t8::cells] > 0} { set best_cell [lindex $::t8::cells 0] }
    set extra {wait twice active}
    set k 7
    foreach mode $extra {
        set order "type_first"
        set state "true"
        if {$best_cell ne ""} {
            set order [dict get $best_cell order]
            set state [dict get $best_cell state]
        }
        lassign [::t8::matrix_cell $k $order $state 1 $before $mode] v st
        lappend ::t8::cells [dict create n $k order $order state $state draw 1 \
            mode $mode ok [lindex $v 0] st $st]
        incr k
    }
    # Item 5c: the SetEnableState cell exists ONLY if the supplier documents it as a display switch.
    # S53 says "Sets the auto load/unload contour data state", so there is no such cell - and this
    # line says so instead of silently dropping it.
    ::t8::emit "CELL 10 skipped: poIContourCtrl SetEnableState is documented as the auto load/unload contour data state (S53), not a display switch, so no cell sends it"
    set best "none"
    foreach c $::t8::cells {
        if {[dict get $c ok]} { set best "cell [dict get $c n]" ; break }
    }
    ::t8::emit [format "MATRIX BEST: %s" $best]
    # Restore: the ORIGINAL type and the ORIGINAL dimension enable state of window 1.
    set lines [list "pisR GetContourCtrlHandle pisCt"]
    if {$before ne ""} {
        lappend lines [format "catch {pisCt SetDataType %s}" [::pis::hw::quote $before]]
    }
    foreach {d v} $::t8_dims {
        if {[string trim $v] eq ""} { continue }
        lappend lines [format "catch {pisCt SetDimensionEnabled %s %s}" $d $v]
    }
    lappend lines "catch {pisC Draw}"
    set e ""
    catch {::pis::hw::exec_hwi [::pis::result::script 1 [join $lines "\n"] 1] -nojournal} e
    catch {::pis::hw::refresh}
    set st ""
    set why ""
    if {[catch {set st [::pis::result::read_state 1]} why]} {
        ::t8::emit [format "MATRIX RESTORED window 1 -> no read-back: %s" [string trim $why]]
        return
    }
    ::t8::emit [format "MATRIX RESTORED window 1 -> type=%s enabled=%s" \
        [dict get $st type] [::pis::result::enabled_text $st]]
    return
}

# The read-only getter dump, printed once as its own line (MATRIX = 0 keeps one line of evidence even
# when no cell runs). Getters only - ::pis::result::dump_calls cannot send a setter.
proc ::t8::getters {} {
    ::t8::emit [format "GETTERS window 1 %s" [::t8::dump_text 1]]
    return
}

# --- the run itself: every input resolved the way item 0 of T-029 asks -------------------------
# Answers {PASS|FAIL <reason>}; it never raises for an input problem, because a report that ends
# with "FAIL input" AND the read-only state is evidence, while a report that dies on a missing name
# is not (that was the owner's `t008_check: input defect`, cause AGENT).
proc ::t8::main {root ini scope} {
    set cfg ""
    catch {set cfg [::pis::common::load_config $root]}
    if {$cfg eq ""} {
        ::t8::emit [format "CHECK input: cannot read the app folder %s" $root]
        return [list FAIL [format "cannot read the app folder %s" $root]]
    }
    if {![file isfile $ini]} {
        ::t8::emit [format "CHECK input: %s not found - every ini value falls back" [file tail $ini]]
    }
    # --- item 0b: the values the app already knows, one CHECK line per value taken -----------
    if {[string trim $::t8_model] ne ""} {
        ::t8::emit [format "CHECK input: model file '%s' from the top of this file" [string trim $::t8_model]]
    } else {
        set model ""
        catch {set model [::pis::common::get $cfg session model_file ""]}
        if {[string trim $model] eq ""} {
            ::t8::emit "CHECK input: model file '-' (the ini names none; Load All decides)"
        } else {
            ::t8::emit [format "CHECK input: model file '%s' from %s \[session\] model_file" \
                $model [file tail $ini]]
        }
    }
    set files ""
    catch {set files [::pis::common::get $cfg session result_files ""]}
    set nfiles 0
    foreach line [split $files "\n"] {
        if {[string trim $line] ne ""} { incr nfiles }
    }
    ::t8::emit [format "CHECK input: %d result file(s) from %s \[session\] result_files" \
        $nfiles [file tail $ini]]
    if {[string trim $::t8_layout] ne ""} {
        ::t8::emit [format "CHECK input: layout id '%s' from the top of this file" [string trim $::t8_layout]]
    } else {
        set layout ""
        catch {set layout [::pis::common::get $cfg layout id ""]}
        if {[string trim $layout] eq ""} {
            ::t8::emit "CHECK input: layout id '-' (the ini names none)"
        } else {
            ::t8::emit [format "CHECK input: layout id '%s' from %s \[layout\] id" \
                $layout [file tail $ini]]
        }
    }
    # --- item 0c: is anything loaded at all? -------------------------------------------------
    set ob [::pis::hw::observe_dict]
    set api [dict get $ob api]
    if {![string is integer -strict $api] || $api < 1} {
        ::t8::emit [format "CHECK input: the page did not answer a window count (%s)" [dict get $ob line]]
        return [list FAIL [format "the page did not answer a window count (%s)" [dict get $ob line]]]
    }
    set first ""
    set ferr ""
    if {[catch {set first [::pis::result::read_state 1]} ferr]} { set first "" }
    if {$first eq ""} {
        ::t8::emit "CHECK input: no model loaded in window 1: run Load All first"
        ::t8::emit [format "CHECK there are %d window(s) on the page" $api]
        ::t8::print_states BEFORE $cfg [::t8::read_all $api]
        catch {::pis::result::dump_window $cfg 1}
        return [list FAIL [format "no model loaded in window 1: run Load All first (%s)" \
            [string trim $ferr]]]
    }
    # --- item 0a: the result name, in the order (1) file (2) ini (3) first type of window 1 ---
    set name ""
    if {[string trim $::t8_name] ne ""} {
        set name [string trim $::t8_name]
        ::t8::emit [format "CHECK input: result name '%s' from the top of this file (t8_name)" $name]
    } else {
        catch {set name [::pis::result::selected_item $cfg]}
        if {$name ne ""} {
            ::t8::emit [format "CHECK input: result name '%s' from %s \[result\] selected" \
                $name [file tail $ini]]
        }
    }
    if {$name eq ""} {
        set name [lindex [dict get $first labels] 0]
        if {$name ne ""} {
            ::t8::emit [format "CHECK input: no name given, using the first type offered by window 1: '%s' (edit t8_name to test another)" $name]
        } else {
            ::t8::emit [format "CHECK input: window 1 offers no data type (first 20): %s" \
                [::t8::types_text $first 20]]
        }
    }
    if {$name eq ""} {
        ::t8::emit [format "CHECK input: %d window(s) on the page, read-only state below" $api]
        ::t8::print_states BEFORE $cfg [::t8::read_all $api]
        catch {::pis::result::dump_window $cfg 1}
        return [list FAIL "input: no result name anywhere - select one in the GUI (\[result\] item), edit t8_name at the top of this file, or load a result file into window 1 with Load All"]
    }
    # The module takes its item from the ini; a name taken from the top of this file, or from the
    # first type window 1 offers, is handed to it as the only item - the T-027 behaviour, kept.
    if {[string trim $::t8_name] ne "" || [::pis::result::selected_item $cfg] eq ""} {
        dict set cfg result [dict create count 1 selected 1 item1 $name]
    }
    return [::t8::run $root $cfg $name $scope]
}

set t8_dir [file dirname [file normalize [info script]]]
set t8_scripts [file normalize [file join $t8_dir .. 01_scripts]]
# A test may preset ::t8_root (the app folder); otherwise the folder above src/ is used.
if {![info exists ::t8_root]} {
    set ::t8_root [file normalize [file join $t8_dir .. ..]]
}
# A test may preset ::t8_ini / ::t8_report_dir; otherwise the app's own files are used.
if {![info exists ::t8_ini]} {
    set ::t8_ini [file join $::t8_root 00_config pis_workflow_config.ini]
}
if {[string trim $::t8_report_dir] ne ""} {
    set t8_out $::t8_report_dir
} else {
    set t8_out [file normalize [file join $t8_dir .. 02_working]]
}
lassign [::t8::open_report $t8_out] t8_fd t8_why
if {$t8_fd eq ""} {
    puts "T008 FAIL $t8_why"
    puts "DONE"
} else {
    set ::t8::fd $t8_fd
    ::t8::capture_on
    set t8_verdict [list FAIL "the app did not load"]
    if {[catch {
        foreach t8_f {_tcl_pis_00_common.tcl _tcl_pis_10_hw.tcl \
                _tcl_pis_11_hw_adapter.tcl _tcl_pis_03_load_result.tcl} {
            source [file join $t8_scripts $t8_f]
        }
    } t8_err]} {
        ::t8::emit "STEP source failed: $t8_err"
        set t8_verdict [list FAIL "the app did not load (see STEP line)"]
    } else {
        ::t8::log_sink
        # T-029 item 0d: the adapter prints its own BUILD line when it is sourced, and that line
        # is already in the report. Print one ONLY when nothing reached the report.
        if {![::t8::report_has_build]} {
            ::t8::emit [::pis::hw::build_line]
        }
        if {[catch {set t8_verdict [::t8::main $::t8_root $::t8_ini $::t8_scope]} t8_err]} {
            ::t8::emit "STEP unexpected: $t8_err"
            set t8_verdict [list FAIL "unexpected: $t8_err"]
        }
    }
    lassign $t8_verdict t8_state t8_reason
    ::t8::emit [format "VERDICT: %s %s" $t8_state $t8_reason]
    ::t8::emit [format "REPORT %s" [file join $t8_out t008_check.txt]]
    set ::t8::fd ""
    catch {close $t8_fd}
    ::t8::capture_off
    # A second run in the same session must read the file's values again, never a stale copy.
    # These four are the hand-edited ones; ::t8_root / ::t8_ini / ::t8_report_dir stay as the
    # caller set them (the owner's app folder is not something a run may forget).
    catch {unset -nocomplain ::t8_name ::t8_model ::t8_layout ::t8_scope}
    puts "DONE"
}
