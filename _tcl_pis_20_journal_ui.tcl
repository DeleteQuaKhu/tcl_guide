# src/01_scripts/_tcl_pis_20_journal_ui.tcl
# ::pis::jui - the logic behind the four log-pane buttons of task T-012:
# [Clear] [Save] [Load...] [Run log >] (docs/refs/SPEC_gui.txt section 8).
#
# WHY THIS FILE EXISTS: the pane has two streams. The display log is ::pis::gui::log_line; the
# command journal is ::pis::journal (T-005). This namespace is the LOGIC of the four buttons,
# written so that it runs in plain tclsh: it builds no widget, and it opens a dialog only when
# Tk is really loaded (otherwise the answer is "yes", which is what the offline tests need).
#
# THE RULES, one per proc, each taken from the SPEC:
#   * [Clear] asks for a confirmation ONLY when the journal is dirty (SPEC_gui s.8).
#   * [Save] writes a .tcl whose every non-blank line starts with "hwc ", "hwi " or "#" (A3):
#     the SAME filter the replay uses decides what is written, so a junk line is counted and
#     never written.
#   * [Load...] shows an external file and NEVER runs it (SPEC_gui s.8).
#   * [Run log >] confirms FIRST with the command count and the source (A4), executes ONLY
#     "hwc " / "hwi " lines through the two documented doors - ::pis::hw::exec and
#     ::pis::hw::exec_hwi, never a bare uplevel (SPEC.md replay contract, T-016) - logs
#     "skipped K" for the rest (A5), logs ONE OK line per executed command (A4), stops on the
#     first error unless continue-on-error is set, and reports the failing LINE NUMBER of the
#     text it ran.
# No HyperView call of its own: every line it runs already went through the adapter, so this
# file adds no row to docs/refs/HV_API.md - it only re-uses the two doors of T-005 / T-016.
#
# A REPLAY NEVER DOUBLES THE JOURNAL. The two doors journal what they run, and a replay runs
# lines that are already in the journal, so ::pis::jui::run keeps a snapshot of the journal, the
# dirty flag and the module/item context, and puts them back afterwards: one line per command
# stays one line, and the replay itself is visible in the display log.
#
# Public procs (arity, call site):
#   text {}              the text [Run log >] would run / [Save] would write
#   origin {}            "<file>" or "the journal" - for dialogs and log lines
#   dirty {}             1 when the journal is unsaved or a file was loaded
#   scan {text}          -> dict: cmds {{line command} ...} skipped N comments N lines N
#   confirm {title msg}  yes/no seam (Tk dialog when present, else yes) - tests override it
#   clear {}             1 cleared / 0 cancelled
#   save {path}          -> dict: path, skipped, commands
#   load {path}          -> the file's text (shown, never run)
#   run {}               -> dict: executed, skipped, failed (line number or 0), error, cancelled
#   coe {}               1 when continue-on-error is checked
#   exec_line {line}     ONE journal line through its door (hwc -> exec, hwi -> exec_hwi)
#   reset_state {}       forget the loaded file (tests start from here)
# Namespace variables: loaded ("" = the live journal), file, continue_on_error.
# Tcl/Tk 8.5 compatible, no tcllib, no network, no package require, no bare hwc / hwi line.

namespace eval ::pis::jui {
    # Created once: re-sourcing this file must not forget the file the user loaded.
    if {![info exists loaded]} { set loaded "" }
    if {![info exists file]} { set file "" }
    if {![info exists continue_on_error]} { set continue_on_error 0 }
}

# One message on the single display-log sink. ::pis::common::log forwards to the GUI pane when
# the pane exists and writes to stderr otherwise, which is exactly what the offline tests read.
proc ::pis::jui::msg {level text} {
    if {[llength [info commands ::pis::common::log]] > 0} {
        ::pis::common::log "" $level $text
        return $text
    }
    puts stderr [format "%-5s %s" $level $text]
    return $text
}

# The text the two buttons work on: the file [Load...] brought in, else the live journal.
proc ::pis::jui::text {} {
    variable loaded
    if {$loaded ne ""} {
        return $loaded
    }
    return [::pis::journal::lines]
}

# Where that text comes from, for the confirmation dialog and the log lines.
proc ::pis::jui::origin {} {
    variable loaded
    variable file
    if {$loaded ne "" && $file ne ""} {
        return $file
    }
    return "the journal"
}

# SPEC_gui s.8: [Clear] and [Save] care about an UNSAVED journal. A loaded file counts as
# unsaved too, because clearing it throws the loaded text away as well.
proc ::pis::jui::dirty {} {
    variable loaded
    if {$loaded ne ""} {
        return 1
    }
    return [expr {$::pis::journal::dirty ? 1 : 0}]
}

# Forget the loaded file; the live journal is NOT touched (that is ::pis::journal::clear).
proc ::pis::jui::reset_state {} {
    variable loaded
    variable file
    set loaded ""
    set file ""
    return
}

# Split a journal text into what may run and what may not.
#   cmds     {{<line number> <command>} ...} - only "hwc " / "hwi " lines, in text order
#   comments "#" lines, kept for [Save], never executed
#   skipped  non-blank lines that are neither (A5 counts exactly these)
#   lines    number of lines in the text (the line numbers above are 1-based over ALL of them,
#            so the number a report prints is the number the user sees in the file)
# The keep/drop rule is the one ::pis::journal::filter uses (T-005); the test asserts the two
# agree, because a run and a save must never disagree about a line.
proc ::pis::jui::scan {txt} {
    set cmds {}
    set skipped 0
    set comments 0
    set n 0
    foreach raw [split $txt "\n"] {
        incr n
        set t [string trim [string trimright $raw "\r"]]
        if {$t eq ""} {
            continue
        }
        if {[string index $t 0] eq "#"} {
            incr comments
            continue
        }
        if {[regexp {^(hwc|hwi)[ \t]} $t]} {
            lappend cmds [list $n $t]
            continue
        }
        incr skipped
    }
    return [dict create cmds $cmds skipped $skipped comments $comments lines $n]
}

# The yes/no seam. A real dialog only when Tk is loaded; headless (the offline suites) the
# answer is "yes" so every path stays reachable. The tests replace this proc to answer "no".
proc ::pis::jui::confirm {title message} {
    if {[llength [info commands tk_messageBox]] > 0} {
        set answer [tk_messageBox -type yesno -default no -icon question \
            -title $title -message $message]
        return [expr {$answer eq "yes" ? 1 : 0}]
    }
    return 1
}

# continue-on-error: the GUI checkbox owns the value; without a GUI the namespace variable does.
proc ::pis::jui::coe {} {
    if {[info exists ::pis::gui::continue_on_error]} {
        return [expr {$::pis::gui::continue_on_error ? 1 : 0}]
    }
    variable continue_on_error
    return [expr {$continue_on_error ? 1 : 0}]
}

# [Clear] (SPEC_gui s.8): the display log AND the journal, and the confirmation is asked ONLY
# when there is something to lose (a dirty journal or a loaded file). Returns 1 when it cleared
# and 0 when the user said no, so the GUI empties the pane only after a yes.
proc ::pis::jui::clear {} {
    if {![::pis::jui::dirty]} {
        ::pis::journal::clear
        ::pis::jui::reset_state
        return 1
    }
    if {![::pis::jui::confirm "Clear log" \
            "Clear the display log and the journal?\n\nThe journal holds unsaved commands."]} {
        ::pis::jui::msg INFO "Clear: cancelled by the user"
        return 0
    }
    ::pis::journal::clear
    ::pis::jui::reset_state
    return 1
}

# Write a list of lines to a file, the way ::pis::journal::save does (create the folder, never
# leave a half-written file behind). The lines arrive already filtered, so A3 cannot break here.
proc ::pis::jui::write_lines {path lines} {
    set dir [file dirname $path]
    if {![file isdirectory $dir]} {
        if {[catch {file mkdir $dir} err]} {
            error "Save journal: cannot create $dir ($err)"
        }
    }
    if {[catch {open $path w} fh]} {
        error "Save journal: cannot write $path ($fh)"
    }
    set text [join $lines "\n"]
    set failed [catch {puts -nonewline $fh "$text\n"} err]
    if {[catch {close $fh} cerr] && !$failed} {
        set failed 1
        set err $cerr
    }
    if {$failed} {
        catch {file delete -force $path}
        error "Save journal: cannot write $path ($err)"
    }
    return $path
}

# [Save] (A3): the filter decides what is written, so every non-blank line of the file starts
# with "hwc ", "hwi " or "#". A junk line is counted and reported, never written. The live
# journal keeps its own memory: saving a LOADED file never marks the journal as saved.
proc ::pis::jui::save {path} {
    variable file
    variable loaded
    set path [string trim $path]
    if {$path eq ""} {
        error "Save journal: empty path"
    }
    set txt [::pis::jui::text]
    set skipped [::pis::journal::filter $txt]
    set kept $::pis::journal::filtered
    set cmds 0
    foreach line $kept {
        if {[regexp {^(hwc|hwi)[ \t]} $line]} {
            incr cmds
        }
    }
    if {$cmds == 0} {
        error "Save journal: no hwc/hwi command to save"
    }
    ::pis::jui::write_lines $path $kept
    if {$loaded eq ""} {
        set ::pis::journal::dirty 0
    }
    set file $path
    ::pis::jui::msg INFO [format "Save: %d line(s) written to %s (%d skipped)" \
        [llength $kept] $path $skipped]
    return [dict create path $path skipped $skipped commands $cmds]
}

# [Load...] (SPEC_gui s.8): read an external journal and SHOW it - it is never executed here.
# The loaded text becomes what [Run log >] and [Save] work on, and `dirty` reads 1 until it is
# cleared, so [Clear] asks before throwing it away.
proc ::pis::jui::load {path} {
    variable loaded
    variable file
    set path [string trim $path]
    if {$path eq ""} {
        error "Load log: empty path"
    }
    if {![file isfile $path]} {
        error "Load log: file not found: $path"
    }
    if {[catch {open $path r} fh]} {
        error "Load log: cannot read $path ($fh)"
    }
    if {[catch {read $fh} txt]} {
        catch {close $fh}
        error "Load log: cannot read $path ($txt)"
    }
    close $fh
    set loaded $txt
    set file $path
    return $txt
}

# ONE journal line through its door (SPEC.md replay contract, T-016): the first word decides.
# A "hwc" line is re-parsed as a Tcl list and handed to ::pis::hw::exec, so the quoted argument
# of the journal becomes ONE argument again and the door re-quotes the same line; an "hwi" line
# is ONE folded handle script and goes to ::pis::hw::exec_hwi, which closes the stack even when
# it fails. Nothing here calls hwc / hwi / uplevel directly.
proc ::pis::jui::exec_line {line} {
    set word [lindex $line 0]
    if {$word eq "hwc"} {
        set args [lrange $line 1 end]
        return [::pis::hw::exec {*}$args]
    }
    if {$word eq "hwi"} {
        return [::pis::hw::exec_hwi $line]
    }
    error "Run log: not a hwc/hwi line: $line"
}

# Execute the scanned commands in text order -> executed / failed (line number) / error.
# ONE OK log line per executed command (A4); the first failure stops the run unless
# continue-on-error is checked, and its line number is what the caller reports.
proc ::pis::jui::run_lines {cmds coe} {
    set executed 0
    set failed 0
    set errmsg ""
    foreach pair $cmds {
        lassign $pair lineno cmd
        set code [catch {::pis::jui::exec_line $cmd} err]
        if {$code} {
            set failed $lineno
            set errmsg $err
            ::pis::jui::msg ERROR [format "Run log: line %d failed: %s | %s" $lineno $cmd $err]
            if {!$coe} {
                break
            }
            continue
        }
        incr executed
        ::pis::jui::msg OK [format "line %d: %s" $lineno $cmd]
    }
    return [dict create executed $executed failed $failed error $errmsg]
}

# [Run log >] (A4 / A5 / SPEC_gui s.8). Order: count -> "skipped K" -> confirmation -> run.
# The confirmation names the command count and the source, so a cancel executes NOTHING; the
# journal snapshot keeps a replay from doubling the journal (see the header).
proc ::pis::jui::run {} {
    set txt [::pis::jui::text]
    set info [::pis::jui::scan $txt]
    set cmds [dict get $info cmds]
    set skipped [dict get $info skipped]
    if {$skipped > 0} {
        ::pis::jui::msg INFO \
            [format "Run log: skipped %d line(s) that are neither hwc, hwi nor #" $skipped]
    }
    if {[llength $cmds] == 0} {
        ::pis::jui::msg WARN "Run log: no hwc/hwi command to run, nothing executed"
        return [dict create executed 0 skipped $skipped failed 0 error "" cancelled 0]
    }
    set k [llength $cmds]
    set message [format "Run %d command(s) from %s?" $k [::pis::jui::origin]]
    if {$skipped > 0} {
        append message [format "\n\n%d line(s) will be skipped." $skipped]
    }
    if {![::pis::jui::confirm "Run log" $message]} {
        ::pis::jui::msg INFO "Run log: cancelled by the user, nothing executed"
        return [dict create executed 0 skipped $skipped failed 0 error "" cancelled 1]
    }
    # Snapshot: a replay runs lines that are already journaled, so the doors must not add them a
    # second time. The context is restored too, so the next module's comment is not "Run log".
    set saved_buf $::pis::journal::buf
    set saved_dirty $::pis::journal::dirty
    set saved_mod $::pis::hw::cur_module
    set saved_item $::pis::hw::cur_item
    ::pis::hw::context "Run log" [::pis::jui::origin]
    set code [catch {::pis::jui::run_lines $cmds [::pis::jui::coe]} res]
    set ::pis::journal::buf $saved_buf
    set ::pis::journal::dirty $saved_dirty
    set ::pis::hw::cur_module $saved_mod
    set ::pis::hw::cur_item $saved_item
    if {$code} {
        error $res
    }
    set executed [dict get $res executed]
    set failed [dict get $res failed]
    if {$failed} {
        set more ""
        if {[::pis::jui::coe]} {
            set more " (continue on error is checked)"
        }
        ::pis::jui::msg WARN [format "Run log: stopped at line %d after %d command(s)%s" \
            $failed $executed $more]
    } else {
        ::pis::jui::msg INFO [format "Run log: %d command(s) executed, %d line(s) skipped" \
            $executed $skipped]
    }
    return [dict merge $res [dict create skipped $skipped cancelled 0]]
}
