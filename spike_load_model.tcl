# src/spike/spike_load_model.tcl — T-002b SPIKE HARNESS. Throwaway probe, NOT product code.
# Question (SPEC D2 + Q1): which Tcl 8.5-only commands clear the session, load ONE model,
# create a cols x rows window grid and load result file k into window k — and does each of
# those exist as a plain `hwc ...` one-liner (the only form `::pis::hw::exec` can journal)?
# Refs: docs/refs/SPEC_load_model.txt (behaviour, validation rules and messages only; the
# user-library contract written in that ref is superseded by SPEC D2).
#
# SESSION WARNING — these steps CHANGE the HyperView session (they may close windows and
# load a model): ::spike2::try_reset, ::spike2::try_load_model, ::spike2::try_grid,
# ::spike2::try_result, ::spike2::full. Run them on a THROWAWAY model only.
# ::spike2::probe is read-only and changes nothing.
#
# Every candidate command runs ALONE inside catch and its raw result or error is printed as
#   <time> SPIKE: <label> | OK|ERROR | <value verbatim>
# so a wrong candidate is recorded as data, never a crash and never a guess. This harness
# fills in NOTHING: the findings live in docs/spikes/load-model-window.md and stay TBD until
# the owner pastes this harness's real output.
#
# Tcl 8.5 only: no try/finally, no tcllib, no package require. Every handle is released on
# every path, including after an error.
namespace eval ::spike2 {
    variable lines {}
    variable worked {}
    variable counter 0
    variable hand [dict create session {} project {} client {} page {} window {}]
    variable model ""
    variable resultFile ""
    variable cols 4
    variable rows 1
    variable k 2
}

# Append one SPIKE line to stdout and to the copy-back buffer.
proc ::spike2::say {msg} {
    set ts [clock format [clock seconds] -format %H:%M:%S]
    set line "$ts SPIKE: $msg"
    puts $line
    lappend ::spike2::lines $line
    return $line
}

# Read-only probe: run one candidate, print its raw result. Never throws, never records.
proc ::spike2::attempt {label script} {
    set code [catch {uplevel 1 $script} res]
    if {$code} {
        ::spike2::say "$label | ERROR | $res"
        return ""
    }
    ::spike2::say "$label | OK | $res"
    return $res
}

# Same as attempt, but reports success as 1/0 so a caller can branch on it.
proc ::spike2::attempt_ok {label script} {
    set code [catch {uplevel 1 $script} res]
    if {$code} {
        ::spike2::say "$label | ERROR | $res"
        return 0
    }
    ::spike2::say "$label | OK | $res"
    return 1
}

# Destructive probe: same as attempt, and an OK command is remembered for the replay block.
proc ::spike2::try {label script} {
    set code [catch {uplevel 1 $script} res]
    if {$code} {
        ::spike2::say "$label | ERROR | $res"
        return ""
    }
    ::spike2::say "$label | OK | $res"
    lappend ::spike2::worked $script
    return $res
}

proc ::spike2::unique {tag} {
    incr ::spike2::counter
    return "pis_spike2_${tag}_[pid]_$::spike2::counter"
}

# HARD CONSTRAINT: release every handle on every path, including after an error.
proc ::spike2::release {tag} {
    set name [dict get $::spike2::hand $tag]
    if {$name eq ""} {
        return
    }
    ::spike2::attempt "ReleaseHandle $tag" [list $name ReleaseHandle]
    dict set ::spike2::hand $tag ""
}

proc ::spike2::close {} {
    foreach tag {window page client project session} {
        ::spike2::release $tag
    }
    ::spike2::attempt "hwi CloseStack" {hwi CloseStack}
}

# Acquire a fresh handle stack. Two candidate ways are probed; whichever works is kept.
# Returns 1 when at least a client handle exists, 0 otherwise (nothing is guessed after that).
proc ::spike2::open {} {
    ::spike2::attempt "hwi OpenStack" {hwi OpenStack}
    set s [::spike2::unique session]
    if {[::spike2::attempt_ok "hwi GetSessionHandle" [list hwi GetSessionHandle $s]]} {
        dict set ::spike2::hand session $s
        set pr [::spike2::unique project]
        if {[::spike2::attempt_ok "session GetProjectHandle" [list $s GetProjectHandle $pr]]} {
            dict set ::spike2::hand project $pr
        }
    }
    set c [::spike2::unique client]
    if {![::spike2::attempt_ok "hwi GetActiveClientHandle" [list hwi GetActiveClientHandle $c]]} {
        return 0
    }
    dict set ::spike2::hand client $c
    set p [::spike2::unique page]
    if {![::spike2::attempt_ok "client GetPageHandle" [list $c GetPageHandle $p]]} {
        return 0
    }
    dict set ::spike2::hand page $p
    set w [::spike2::unique window]
    if {[::spike2::attempt_ok "page GetWindowHandle (active)" [list $p GetWindowHandle $w]]} {
        dict set ::spike2::hand window $w
    }
    return 1
}

# Enumerate the windows of the current page: count first, then one handle per index.
# Read-only (handles are released immediately).
proc ::spike2::list_windows {} {
    set p [dict get $::spike2::hand page]
    if {$p eq ""} {
        ::spike2::say "window list | SKIPPED | no page handle"
        return
    }
    set count [::spike2::attempt "page GetWindowCount" [list $p GetWindowCount]]
    if {![string is integer -strict $count]} {
        ::spike2::say "window list | SKIPPED | GetWindowCount returned '$count'"
        return
    }
    for {set i 1} {$i <= $count} {incr i} {
        set w [::spike2::unique window]
        if {[::spike2::attempt_ok "page GetWindowHandle $i" [list $p GetWindowHandle $w $i]]} {
            ::spike2::attempt "window $i GetModelFileName" [list $w GetModelFileName]
            ::spike2::attempt "window $i GetResultCount" [list $w GetResultCount]
            ::spike2::attempt "ReleaseHandle window $i" [list $w ReleaseHandle]
        }
    }
    ::spike2::say "window list | NOTE | $count window(s) reported by this page"
}

# Read-only discovery: version, command inventory, current page state, window list.
# Changes nothing.
proc ::spike2::probe {} {
    ::spike2::say "=== probe start (read-only, changes nothing) ==="
    ::spike2::attempt "info patchlevel" {info patchlevel}
    ::spike2::attempt "hwi GetVersion" {hwi GetVersion}
    ::spike2::attempt "hwc GetVersion" {hwc GetVersion}
    ::spike2::attempt "info procs hwc" {info procs hwc}
    ::spike2::attempt "info args hwc" {info args hwc}
    ::spike2::attempt "info body hwc (first 2000 chars - lists its real subcommands)" \
        {string range [info body hwc] 0 2000}
    ::spike2::attempt "procs ::hwc::*" {lsort [info procs ::hwc::*]}
    ::spike2::attempt "commands ::hwc*" {lsort [info commands ::hwc*]}
    ::spike2::attempt "procs ::hwi::*" {lsort [info procs ::hwi::*]}
    ::spike2::attempt "procs ::hwp::*" {lsort [info procs ::hwp::*]}
    ::spike2::attempt "procs ::post::*" {lsort [info procs ::post::*]}
    ::spike2::attempt "procs ::tms::*" {lsort [info procs ::tms::*]}
    if {![::spike2::open]} {
        ::spike2::say "=== probe end: no handle stack (run this inside the HyperView Tcl console) ==="
        ::spike2::close
        return
    }
    set c [dict get $::spike2::hand client]
    set p [dict get $::spike2::hand page]
    set w [dict get $::spike2::hand window]
    ::spike2::attempt "client GetPageCount" [list $c GetPageCount]
    ::spike2::attempt "page GetLayoutType" [list $p GetLayoutType]
    ::spike2::attempt "page GetActiveWindow" [list $p GetActiveWindow]
    if {$w ne ""} {
        ::spike2::attempt "window (active) GetModelFileName" [list $w GetModelFileName]
        ::spike2::attempt "window (active) GetResultCount" [list $w GetResultCount]
        ::spike2::attempt "window (active) GetResultFileName 1" [list $w GetResultFileName 1]
    }
    ::spike2::list_windows
    ::spike2::close
    ::spike2::say "=== probe end ==="
}

# A spike must fail loudly: the offending path is in the message, no silent fallback.
proc ::spike2::check_file {what path} {
    if {[string trim $path] eq ""} {
        error "no $what given: pass an absolute path or set ::spike2::$what"
    }
    if {![file isfile $path]} {
        error "$what not found: $path"
    }
    return $path
}

# STEP 1 (CHANGES THE SESSION): candidate commands that clear the session / close windows.
proc ::spike2::try_reset {} {
    ::spike2::say "=== step reset start (CHANGES the session) ==="
    set code [catch {
        if {![::spike2::open]} {
            error "no handle stack (run this in the HyperView Tcl console)"
        }
        set s [dict get $::spike2::hand session]
        set pr [dict get $::spike2::hand project]
        set c [dict get $::spike2::hand client]
        set p [dict get $::spike2::hand page]
        ::spike2::try "hwc session new" {hwc session new}
        ::spike2::try "hwc new session" {hwc new session}
        ::spike2::try "hwc page new" {hwc page new}
        ::spike2::try "session NewSession" [list $s NewSession]
        ::spike2::try "session Reset" [list $s Reset]
        ::spike2::try "client Reset" [list $c Reset]
        ::spike2::try "project Reset" [list $pr Reset]
        ::spike2::try "page Reset" [list $p Reset]
        ::spike2::attempt "page GetWindowCount (after the candidates)" [list $p GetWindowCount]
    } res]
    ::spike2::close
    if {$code} {
        ::spike2::say "step reset | ABORTED | $res"
    }
    ::spike2::say "=== step reset end: note which candidate really cleared the session ==="
}

# STEP 2 (CHANGES THE SESSION): candidate commands that load ONE model file.
proc ::spike2::try_load_model {{file ""}} {
    if {$file eq ""} {
        set file $::spike2::model
    }
    ::spike2::check_file model $file
    ::spike2::say "=== step load-model start (CHANGES the session): $file ==="
    set code [catch {
        if {![::spike2::open]} {
            error "no handle stack (run this in the HyperView Tcl console)"
        }
        set c [dict get $::spike2::hand client]
        set p [dict get $::spike2::hand page]
        set w [dict get $::spike2::hand window]
        ::spike2::try "window LoadModel" [list $w LoadModel $file]
        ::spike2::try "hwc model load" [list hwc model load $file]
        ::spike2::try "hwc model open" [list hwc model open $file]
        ::spike2::try "client LoadModel" [list $c LoadModel $file]
        ::spike2::try "page LoadModel" [list $p LoadModel $file]
        ::spike2::attempt "window GetModelFileName (after the candidates)" [list $w GetModelFileName]
        ::spike2::attempt "client Draw" [list $c Draw]
        ::spike2::attempt "update idletasks" {update idletasks}
    } res]
    ::spike2::close
    if {$code} {
        ::spike2::say "step load-model | ABORTED | $res"
    }
    ::spike2::say "=== step load-model end: note which candidate really loaded the model ==="
}

# STEP 3 (CHANGES THE SESSION): candidate commands that create a cols x rows window grid.
proc ::spike2::try_grid {{cols 0} {rows 0}} {
    if {$cols <= 0} {
        set cols $::spike2::cols
    }
    if {$rows <= 0} {
        set rows $::spike2::rows
    }
    ::spike2::say "=== step grid start (CHANGES the session): $cols x $rows ==="
    set code [catch {
        if {![::spike2::open]} {
            error "no handle stack (run this in the HyperView Tcl console)"
        }
        set p [dict get $::spike2::hand page]
        ::spike2::attempt "page GetWindowCount (before)" [list $p GetWindowCount]
        ::spike2::attempt "page GetLayoutType (before)" [list $p GetLayoutType]
        ::spike2::try "hwc page layout" [list hwc page layout $cols $rows]
        ::spike2::try "hwc window layout" [list hwc window layout $cols $rows]
        ::spike2::try "page SetLayout (two args)" [list $p SetLayout $cols $rows]
        ::spike2::try "page SetWindowLayout (two args)" [list $p SetWindowLayout $cols $rows]
        ::spike2::try "page SetLayoutType (two args)" [list $p SetLayoutType $cols $rows]
        ::spike2::try "page AddWindow" [list $p AddWindow]
        ::spike2::attempt "page GetWindowCount (after)" [list $p GetWindowCount]
        ::spike2::attempt "page GetLayoutType (after)" [list $p GetLayoutType]
        ::spike2::list_windows
    } res]
    ::spike2::close
    if {$code} {
        ::spike2::say "step grid | ABORTED | $res"
    }
    ::spike2::say "=== step grid end: note which candidate really produced $cols x $rows windows ==="
}

# STEP 4 (CHANGES THE SESSION): candidates that load a result file into window k (after
# trying to select window k). Both families are probed — a plain `hwc` one-liner and the
# handle API — because SPEC D2 needs a journalable `hwc` form.
proc ::spike2::try_result {{k 0} {file ""}} {
    if {$k <= 0} {
        set k $::spike2::k
    }
    if {$file eq ""} {
        set file $::spike2::resultFile
    }
    ::spike2::check_file resultFile $file
    ::spike2::say "=== step result start (CHANGES the session): window $k <- $file ==="
    set code [catch {
        if {![::spike2::open]} {
            error "no handle stack (run this in the HyperView Tcl console)"
        }
        set p [dict get $::spike2::hand page]
        set c [dict get $::spike2::hand client]
        ::spike2::attempt "page GetWindowCount" [list $p GetWindowCount]
        set wk [::spike2::unique window]
        if {[::spike2::attempt_ok "page GetWindowHandle $k" [list $p GetWindowHandle $wk $k]]} {
            dict set ::spike2::hand window $wk
            ::spike2::attempt "page SetActiveWindow $k" [list $p SetActiveWindow $k]
            ::spike2::attempt "window $k GetModelFileName" [list $wk GetModelFileName]
            ::spike2::try "window $k LoadResult" [list $wk LoadResult $file]
            ::spike2::try "hwc result load" [list hwc result load $file]
            ::spike2::try "hwc result add" [list hwc result add $file]
            ::spike2::try "window $k LoadResult (path, index)" [list $wk LoadResult $file $k]
            ::spike2::try "window $k AddResult" [list $wk AddResult $file]
            ::spike2::attempt "window $k GetResultCount" [list $wk GetResultCount]
            ::spike2::attempt "window $k GetResultFileName 1" [list $wk GetResultFileName 1]
        }
        ::spike2::attempt "client Draw" [list $c Draw]
        ::spike2::attempt "update idletasks" {update idletasks}
        ::spike2::list_windows
    } res]
    ::spike2::close
    if {$code} {
        ::spike2::say "step result | ABORTED | $res"
    }
    ::spike2::say "=== step result end: note WHICH window shows the result ==="
}

# Convenience: the four steps in the order the product would run them, each independent.
# A step that raises is recorded and the sequence continues, so one bad path still leaves a
# full copy-back block.
proc ::spike2::full {{model ""} {file ""} {cols 0} {rows 0} {k 0}} {
    ::spike2::say "##### full sequence start (CHANGES the session) #####"
    foreach step [list \
        [list ::spike2::probe] \
        [list ::spike2::try_reset] \
        [list ::spike2::try_load_model $model] \
        [list ::spike2::try_grid $cols $rows] \
        [list ::spike2::try_result $k $file]] {
        if {[catch {uplevel #0 $step} res]} {
            ::spike2::say "full | STEP FAILED | $res"
        }
    }
    ::spike2::say "##### full sequence end #####"
    ::spike2::report
}

proc ::spike2::report {} {
    puts "----- BEGIN COPY-BACK BLOCK -----"
    foreach line $::spike2::lines {
        puts $line
    }
    if {[llength $::spike2::worked] == 0} {
        puts "WORKED SEQUENCE: (empty, no candidate succeeded)"
    } else {
        puts "WORKED SEQUENCE (the OK commands, in the order they were tried):"
        foreach cmd $::spike2::worked {
            puts "  $cmd"
        }
    }
    puts "----- END COPY-BACK BLOCK -----"
}

proc ::spike2::save {file} {
    # NOTE: `open`/`close` must be fully qualified here — this namespace defines
    # ::spike2::open and ::spike2::close, which would shadow the Tcl builtins.
    set fh [::open $file w]
    foreach line $::spike2::lines {
        puts $fh $line
    }
    if {[llength $::spike2::worked] > 0} {
        puts $fh "WORKED SEQUENCE:"
        foreach cmd $::spike2::worked {
            puts $fh "  $cmd"
        }
    }
    ::close $fh
    return $file
}

proc ::spike2::help {} {
    puts "SPIKE T-002b usage (HyperView Tcl console):"
    puts "  set ::spike2::model      D:/path/to/model.h3d"
    puts "  set ::spike2::resultFile D:/path/to/result.h3d"
    puts "  set ::spike2::cols 4 ; set ::spike2::rows 1 ; set ::spike2::k 2"
    puts "  ::spike2::probe                        ;# read-only: build, commands, windows"
    puts "  ::spike2::try_reset                    ;# CHANGE session: clear / close"
    puts "  ::spike2::try_load_model               ;# CHANGE session: load the model"
    puts "  ::spike2::try_grid 4 1                 ;# CHANGE session: cols x rows"
    puts "  ::spike2::try_result 2 D:/path/r.h3d   ;# CHANGE session: result into window 2"
    puts "  ::spike2::full                         ;# all of the above, in order, then report"
    puts "  ::spike2::report                       ;# print the copy-back block"
    puts "  ::spike2::save D:/tmp/spike2.txt       ;# same block to a file"
}

::spike2::say "harness loaded (T-002b spike); run ::spike2::help"
