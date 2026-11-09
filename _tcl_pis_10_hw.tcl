# PIS Workflow - the single HyperView door and the command journal (task T-005).
# ::pis::hw::exec    the ONLY path to HyperView: runs hwc, journals on success
# ::pis::journal     in-memory "hwc ..." + "# ..." lines, replayable Tcl
# Tcl/Tk 8.5 compatible, no tcllib, no network, no package require.
# Sourcing this file defines procs only: it never calls HyperView.
#
# Public procs:
#   ::pis::hw::exec {args}             -> hwc {*}$args; journals, rethrows errors
#   ::pis::hw::context {module item}   -> module/item written in the next comment
#   ::pis::journal::add {comment cmd}  -> append "# comment" + cmd
#   ::pis::journal::lines {}           -> journal as text, newline terminated
#   ::pis::journal::filter {text}      -> skipped count; keeps hwc / # lines
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

# Keep only lines whose first word is hwc or that start with #. Returns the
# number of dropped (non blank) lines; the kept lines land in variable filtered.
proc ::pis::journal::filter {text} {
    variable filtered
    set kept {}
    set skipped 0
    foreach line [split $text "\n"] {
        set t [string trim [string trimright $line "\r"]]
        if {$t eq ""} { continue }
        if {[regexp {^hwc[ \t]} $t] || [string index $t 0] eq "#"} {
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
