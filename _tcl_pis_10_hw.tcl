# PIS Workflow - the single HyperView door and the command journal (task T-005).
# ::pis::hw::exec      the hwc door: runs hwc, journals on success
# ::pis::hw::exec_hwi  the hwi door: runs ONE handle script, journals it as one line
# ::pis::hw::probe     read-only query (a check), never journaled
# ::pis::journal       in-memory "hwc ..." / "hwi ..." / "# ..." lines, replayable Tcl
# Tcl/Tk 8.5 compatible, no tcllib, no network, no package require.
# Sourcing this file defines procs only: it never calls HyperView.
#
# Public procs:
#   ::pis::hw::exec {args}             -> hwc {*}$args; journals, rethrows errors
#   ::pis::hw::exec_hwi {script}       -> one hwi script; journals it, rethrows errors
#                                        (-nojournal: run it, write nothing yet)
#   ::pis::hw::journal_run {script}    -> journal one hwi script already proven to work
#   ::pis::hw::probe {script}          -> one hwi script, result returned, NOT journaled
#   ::pis::hw::context {module item}   -> module/item written in the next comment
#   ::pis::journal::add {comment cmd}  -> append "# comment" + cmd
#   ::pis::journal::lines {}           -> journal as text, newline terminated
#   ::pis::journal::filter {text}      -> skipped count; keeps hwc / hwi / # lines
#   ::pis::journal::save {path}        -> write lines() to path, clears dirty
#   ::pis::journal::clear {}           -> drop everything, clears dirty
# Namespace variables later tasks read:
#   ::pis::journal::buf (lines), ::pis::journal::filtered (last filter result),
#   ::pis::journal::file (last saved path), ::pis::journal::dirty (0|1)

namespace eval ::pis::journal {
    # Created once: re-sourcing this file must not wipe an unsaved journal.
    if {![info exists buf]} { set buf {} }
    if {![info exists filtered]} { set filtered {} }
    if {![info exists file]} { set file "" }
    if {![info exists dirty]} { set dirty 0 }
}

namespace eval ::pis::hw {
    if {![info exists cur_module]} { set cur_module "" }
    if {![info exists cur_item]} { set cur_item "" }
}

# One journal argument, quoted so the journaled line stays valid, replayable Tcl.
proc ::pis::journal::quote_arg {arg} {
    if {[regexp {^[^\s\[\]\{\}\"\\\$\;]+$} $arg]} { return $arg }
    return [list $arg]
}

# The single door to HyperView (SPEC.md API). On success the exact command line
# is journaled behind a "# <timestamp> | <module> | <item>" comment; on failure
# nothing is journaled and the original error (code, info, errorcode) is rethrown.
proc ::pis::hw::exec {args} {
    variable cur_module
    variable cur_item
    if {[llength $args] == 0} {
        error "::pis::hw::exec: no HyperView command given"
    }
    if {[llength [info commands hwc]] == 0} {
        error "::pis::hw::exec: the hwc command is not available (run inside HyperView)"
    }
    set parts [list hwc]
    foreach a $args {
        lappend parts [::pis::journal::quote_arg $a]
    }
    set line [join $parts " "]
    set code [catch {hwc {*}$args} res opts]
    if {$code} {
        return -options $opts $res
    }
    set stamp [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
    ::pis::journal::add [format "%s | %s | %s" $stamp $cur_module $cur_item] $line
    return $res
}

# The hwi door (SPEC.md D2 REVISION, 2026-11-10). `script` is ONE complete
# handle script whose first word is hwi, e.g.
#   hwi OpenStack
#   hwi GetSessionHandle pisS
#   ...                                    (one COMPLETE command per line)
# Every newline plus its indentation is folded into "; ", so the folded text is
# both what runs and what lands in the journal - exactly one replayable line.
# This build ignores an hwc subcommand it does not know without raising, so the
# only honest way to see the difference between "worked" and "did nothing" is
# ::pis::hw::probe after the call; exec_hwi itself cannot tell.
# mode: "-journal" (default) writes the line after the script returns; "-nojournal"
# runs it and writes nothing, so a caller that must prove the change first (the
# adapter) can decide afterwards, with ::pis::hw::journal_run.
proc ::pis::hw::exec_hwi {script {mode "-journal"}} {
    variable cur_module
    variable cur_item
    if {[string trim $script] eq ""} {
        error "::pis::hw::exec_hwi: no HyperView script given"
    }
    if {$mode ne "-journal" && $mode ne "-nojournal"} {
        error "::pis::hw::exec_hwi: unknown mode '$mode' (expected -journal or -nojournal)"
    }
    if {[llength [info commands hwi]] == 0} {
        error "::pis::hw::exec_hwi: the hwi command is not available (run inside HyperView)"
    }
    set line [::pis::hw::fold_script $script]
    if {$line eq ""} {
        error "::pis::hw::exec_hwi: the script holds no command (only blank and comment lines)"
    }
    if {![regexp {^hwi[ \t]} $line]} {
        error "::pis::hw::exec_hwi: the script must start with 'hwi ' so the journal line stays replayable"
    }
    set code [catch {uplevel 1 $line} res opts]
    if {$code} {
        # Never leave a half-open stack behind for the next call.
        catch {hwi CloseStack}
        return -options $opts $res
    }
    if {$mode eq "-journal"} {
        ::pis::hw::journal_run $line
    }
    return $res
}

# Journal one handle script that is ALREADY proven to work (SPEC.md D2 REVISION: a command
# that changed nothing must never reach a saved journal). Writes the same line exec_hwi
# writes - folded to one replayable line behind the usual timestamp comment - and returns it.
proc ::pis::hw::journal_run {script} {
    variable cur_module
    variable cur_item
    if {[string trim $script] eq ""} {
        error "::pis::hw::journal_run: no HyperView script given"
    }
    set line [::pis::hw::fold_script $script]
    if {$line eq ""} {
        error "::pis::hw::journal_run: the script holds no command (only blank and comment lines)"
    }
    if {![regexp {^hwi[ \t]} $line]} {
        error "::pis::hw::journal_run: the script must start with 'hwi ' so the journal line stays replayable"
    }
    set stamp [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
    ::pis::journal::add [format "%s | %s | %s" $stamp $cur_module $cur_item] $line
    return $line
}

# Fold a multi-line script into one Tcl line: newline + surrounding blanks -> "; ".
# Blank lines and leading/trailing blanks of the whole script disappear; runs of
# blanks INSIDE a line are untouched, so a path with spaces is never damaged.
# A line that starts with "#" is a COMMENT and is dropped BEFORE the fold (T-016): folding
# joins the lines with "; ", so a comment left in place would swallow every command after it
# ("# note; hwi OpenStack" runs NOTHING and raises NOTHING) - exactly the silent no-op this
# repo is fighting. A script that is all comments folds to "" and its caller refuses it.
proc ::pis::hw::fold_script {script} {
    set text [string map {"\r\n" "\n" "\r" "\n"} $script]
    set parts {}
    foreach raw [split $text "\n"] {
        set t [string trim $raw]
        if {$t eq ""} { continue }
        if {[string index $t 0] eq "#"} { continue }
        lappend parts $t
    }
    return [join $parts "; "]
}

# Read-only query: same hwi stack rules as exec_hwi but nothing is journaled, so
# a saved journal never contains a check pretending to be a step. Used by the
# adapter to prove a step changed the session before it reports OK.
proc ::pis::hw::probe {script} {
    if {[string trim $script] eq ""} {
        error "::pis::hw::probe: no HyperView script given"
    }
    if {[llength [info commands hwi]] == 0} {
        error "::pis::hw::probe: the hwi command is not available (run inside HyperView)"
    }
    set line [::pis::hw::fold_script $script]
    if {$line eq ""} {
        error "::pis::hw::probe: the script holds no command (only blank and comment lines)"
    }
    set code [catch {uplevel 1 $line} res opts]
    if {$code} {
        catch {hwi CloseStack}
        return -options $opts $res
    }
    return $res
}

# The module title (as shown in the GUI) and item recorded in the next journal
# comment. Modules set this once per item, before their HyperView calls.
proc ::pis::hw::context {module item} {
    variable cur_module
    variable cur_item
    set cur_module [string trim $module]
    set cur_item [string trim $item]
    return
}

proc ::pis::journal::add {comment cmd} {
    variable buf
    variable dirty
    set c [string trim $cmd]
    if {$c eq ""} { error "::pis::journal::add: empty command" }
    lappend buf "# [string trim $comment]"
    lappend buf $c
    set dirty 1
    return
}

# Journal as text (newline terminated, "" when empty) - ready for a pane or file.
proc ::pis::journal::lines {} {
    variable buf
    if {[llength $buf] == 0} { return "" }
    set text [join $buf "\n"]
    return "$text\n"
}

# Keep only lines whose first word is hwc or hwi, or that start with #. Returns
# the number of dropped (non blank) lines; the kept lines land in variable filtered.
proc ::pis::journal::filter {text} {
    variable filtered
    set kept {}
    set skipped 0
    foreach line [split $text "\n"] {
        set t [string trim [string trimright $line "\r"]]
        if {$t eq ""} { continue }
        if {[regexp {^(hwc|hwi)[ \t]} $t] || [string index $t 0] eq "#"} {
            lappend kept $t
            continue
        }
        incr skipped
    }
    set filtered $kept
    return $skipped
}

proc ::pis::journal::save {path} {
    variable file
    variable dirty
    if {[string trim $path] eq ""} { error "::pis::journal::save: empty path" }
    set dir [file dirname $path]
    if {![file isdirectory $dir]} {
        if {[catch {file mkdir $dir} err]} {
            error "::pis::journal::save: cannot create $dir ($err)"
        }
    }
    if {[catch {open $path w} fh]} {
        error "::pis::journal::save: cannot write $path ($fh)"
    }
    set failed [catch {puts -nonewline $fh [lines]} err]
    if {[catch {close $fh} cerr] && !$failed} {
        set failed 1
        set err $cerr
    }
    if {$failed} {
        catch {file delete -force $path}
        error "::pis::journal::save: cannot write $path ($err)"
    }
    set file $path
    set dirty 0
    return $path
}

proc ::pis::journal::clear {} {
    variable buf
    variable filtered
    variable dirty
    set buf {}
    set filtered {}
    set dirty 0
    return
}
