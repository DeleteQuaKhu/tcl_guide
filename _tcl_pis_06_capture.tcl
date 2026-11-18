# src/01_scripts/_tcl_pis_06_capture.tcl
# ::pis::capture - the "Capture" module (task T-011).
# SPEC_gui.txt s.6.5: "List of views (View 1..n). Apply: for each checked view, set the view and
# capture an image. Image name: {model}_{result}_{item}.png so files never overwrite each other.
# Capture only captures; it does not trigger other modules."
# The HyperView call is the one docs/refs/HV_API.md section 6 names for this task (S91):
# `<sess> CaptureWindow win_id, type, filename, dimension_type, width, height` - the only fetched
# capture call that documents PNG, and the only one that takes the window id instead of relying on
# "whatever is active". It is sent through ::pis::hw::capture_window, so the whole step goes through
# the ONE HyperView door and the journal keeps one replayable `hwi ...` line per capture.
# Tcl/Tk 8.5 compatible, no tcllib, no network, no package require, no Tk.
# Sourcing this file defines procs only: it never calls HyperView.
#
# What "set the view" means here (ASSUMPTION-T011/U1, written down because SPEC_gui s.6.5 names no
# view command): the checked row is the LABEL of one capture (it lands in the file name), and the
# window it captures is decided exactly like every other module - the active window, or every
# window of the layout for [Apply all layout] (SPEC_gui s.7's loop: for window -> for item). A
# layout run therefore sets each window with `SetActiveWindow k` (S5) before capturing it, and the
# log line names the window, the item and the final path, so the mapping is never guessed.
#
# Public procs:
#   ::pis::capture::run {root cfg scope}      -> images written (0 = skipped)
#   ::pis::capture::title {}                  -> "Capture" (journal comment + WARN text)
#   ::pis::capture::need_common {}            -> fail loudly when ::pis::common is not sourced
#   ::pis::capture::need_adapter {}           -> same for ::pis::hw (the capture call lives there)
#   ::pis::capture::items {cfg}               -> the [capture] item texts, in row order
#   ::pis::capture::checked_rows {cfg}        -> 1-based rows the [capture] checked string ticks
#   ::pis::capture::item_text {cfg row}       -> one row's text (raises when it is empty)
#   ::pis::capture::size_spec {cfg}           -> {unit width height} for the capture call
#   ::pis::capture::output_dir {root cfg}     -> absolute folder for the images (created if needed)
#   ::pis::capture::file_base {cfg k item}    -> {model}_{result}_{item}, sanitized, no extension
#   ::pis::capture::file_name {cfg k item}    -> that base plus ".png"
#   ::pis::capture::unique_path {dir base used} -> {path used'} that cannot collide
#   ::pis::capture::windows {cfg scope}       -> window indexes the run captures
#   ::pis::capture::sanitize {text}           -> one file-name-safe part
#   ::pis::capture::reset_state {}            -> counters back to 0 (tests)
# Namespace variables: captured, calls, last_path, last_dir

namespace eval ::pis::capture {
    if {![info exists captured]} { set captured 0 }
    if {![info exists calls]} { set calls 0 }
    if {![info exists last_path]} { set last_path "" }
    if {![info exists last_dir]} { set last_dir "" }
}

# The module title exactly as the GUI shows it: it goes into the journal comment and the WARN that
# SPEC.md A8 requires ("module <name>: no item selected, nothing run").
proc ::pis::capture::title {} {
    return "Capture"
}

# Offline this file is useless without ::pis::common; say so instead of a confusing error.
proc ::pis::capture::need_common {} {
    foreach p {get resolve_path log to_bool} {
        if {[llength [info commands ::pis::common::$p]] == 0} {
            error "::pis::capture: source _tcl_pis_00_common.tcl first (missing ::pis::common::$p)"
        }
    }
    return
}

# The capture call itself lives in the adapter (one op, one variant list). Without it this module
# can do nothing, and saying so here beats a "no such command" from the middle of a run.
proc ::pis::capture::need_adapter {} {
    foreach p {capture_window select_window context} {
        if {[llength [info commands ::pis::hw::$p]] == 0} {
            error "::pis::capture: source _tcl_pis_10_hw.tcl and _tcl_pis_11_hw_adapter.tcl first (missing ::pis::hw::$p)"
        }
    }
    return
}

# The status bar during a run (SPEC_gui s.7: "Capture 2/3 running..."). The adapter owns the one
# helper that reaches the GUI, so this module never touches ::pis::gui directly.
proc ::pis::capture::status {msg} {
    if {[llength [info commands ::pis::hw::status]] > 0} {
        catch {::pis::hw::status $msg}
    }
    return
}

# ONE file-name-safe part: everything outside [A-Za-z0-9._-] becomes "_", a run of "_" collapses,
# and leading/trailing "_" and "." go away (Windows refuses a trailing dot). An empty answer never
# produces an empty part - "x" keeps the name pattern intact.
proc ::pis::capture::sanitize {text} {
    set allowed "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-"
    set out ""
    foreach ch [split [string trim $text] ""] {
        if {[string first $ch $allowed] >= 0} {
            append out $ch
        } else {
            append out "_"
        }
    }
    regsub -all {_+} $out _ out
    set out [string trim $out "._"]
    if {$out eq ""} { return "x" }
    return $out
}

# The name of a file without its folder and without its LAST extension ("C:/d/run 1.h3d" -> "run 1").
proc ::pis::capture::file_stem {path} {
    set p [string trim $path]
    if {$p eq ""} { return "" }
    return [file rootname [file tail $p]]
}

# How many rows the [capture] section claims (count = N). A missing or broken count is 0, so the
# module can never run a row nobody listed.
proc ::pis::capture::item_count {cfg} {
    ::pis::capture::need_common
    set c [string trim [::pis::common::get $cfg capture count 0]]
    if {![string is integer -strict $c] || $c < 0} { return 0 }
    return $c
}

# The item texts of [capture] in row order (item1..itemN).
proc ::pis::capture::items {cfg} {
    set out [list]
    set n [::pis::capture::item_count $cfg]
    set i 1
    while {$i <= $n} {
        lappend out [string trim [::pis::common::get $cfg capture "item$i" ""]]
        incr i
    }
    return $out
}

# The ticked rows, 1-based, in row order. SPEC.md data model: `[capture] checked = "0 1 1"` - one
# flag per row, in row order - so a short string leaves the rows beyond it UNCHECKED (nothing is
# invented) and a value that is neither 0/1 nor a boolean word is refused by name.
proc ::pis::capture::checked_rows {cfg} {
    ::pis::capture::need_common
    set raw [string map {, " " ";" " "} [string trim [::pis::common::get $cfg capture checked ""]]]
    set flags [list]
    foreach tok $raw {
        set f [::pis::common::to_bool $tok "capture checked"]
        lappend flags $f
    }
    set n [::pis::capture::item_count $cfg]
    if {$n < [llength $flags]} { set n [llength $flags] }
    set out [list]
    set i 1
    while {$i <= $n} {
        set f 0
        if {$i <= [llength $flags]} { set f [lindex $flags [expr {$i - 1}]] }
        if {$f} { lappend out $i }
        incr i
    }
    return $out
}

# One row's text. An empty row cannot become a file name part, so it is refused by row number.
proc ::pis::capture::item_text {cfg row} {
    ::pis::capture::need_common
    if {![string is integer -strict $row] || $row < 1} {
        error "::pis::capture::item_text: row must be a positive integer, got: '$row'"
    }
    set t [string trim [::pis::common::get $cfg capture "item$row" ""]]
    if {$t eq ""} {
        error "capture: checked row $row has no text in \[capture\] (item$row) - fill it in or untick the row"
    }
    return $t
}

# The size of the image, {unit width height}, for the capture call: `[capture] unit/width/height`
# with the documented defaults `pixels 1280 960` (the page's own example numbers, HV_API S91). An
# unknown unit or a non-positive number is refused HERE, before anything is sent.
proc ::pis::capture::size_spec {cfg} {
    ::pis::capture::need_common
    set unit [string tolower [string trim [::pis::common::get $cfg capture unit pixels]]]
    if {$unit eq ""} { set unit pixels }
    if {$unit ne "pixels" && $unit ne "percent"} {
        error "capture: \[capture\] unit must be pixels or percent, got '$unit'"
    }
    set out [list $unit]
    foreach {key def} {width 1280 height 960} {
        set v [string trim [::pis::common::get $cfg capture $key $def]]
        if {$v eq ""} { set v $def }
        if {![string is integer -strict $v] || $v < 1} {
            error "capture: \[capture\] $key must be a positive integer, got '$v'"
        }
        lappend out $v
    }
    return $out
}

# The folder the images go into: `[folders] working_dir` (default 02_working, resolved against the
# workflow root) - the place SPEC.md D4 reserves for runtime artifacts. It is created when missing
# and refused when it cannot be used, NAMING the path, before the first capture is attempted, so a
# run never stops half way with half the images written.
proc ::pis::capture::output_dir {root cfg} {
    ::pis::capture::need_common
    set wd [string trim [::pis::common::get $cfg folders working_dir 02_working]]
    if {$wd eq ""} { set wd 02_working }
    set dir [::pis::common::resolve_path $root $wd]
    if {![file isdirectory $dir]} {
        set err ""
        if {[catch {file mkdir $dir} err]} {
            error "capture: cannot create the output folder: $dir ($err)"
        }
        if {![file isdirectory $dir]} {
            error "capture: output folder is not a folder: $dir"
        }
    }
    if {![file writable $dir]} {
        error "capture: output folder is not writable: $dir"
    }
    return $dir
}

# The {result} part of the name: the result FILE of that window (its basename without extension),
# because that is the only value that makes the three parts unique across a layout - a window is
# "one result file" (SPEC_gui s.4) and the whole point of the pattern is, in s.6.5's own words,
# "so files never overwrite each other". A window with no result line (fewer files than windows)
# falls back to the SELECTED result type, then to "noresult"; the uniqueness pass below still
# guarantees that no image is ever overwritten.
proc ::pis::capture::result_part {cfg k} {
    ::pis::capture::need_common
    set files [::pis::common::get $cfg session result_files ""]
    if {[string is integer -strict $k] && $k >= 1 && $k <= [llength $files]} {
        set f [string trim [lindex $files [expr {$k - 1}]]]
        if {$f ne ""} { return [::pis::capture::file_stem $f] }
    }
    set sel [string trim [::pis::common::get $cfg result selected 0]]
    if {[string is integer -strict $sel] && $sel >= 1} {
        set t [string trim [::pis::common::get $cfg result "item$sel" ""]]
        if {$t ne ""} { return $t }
    }
    return "noresult"
}

# {model}_{result}_{item}, every part sanitized: SPEC_gui s.6.5's pattern, no extension.
proc ::pis::capture::file_base {cfg k item} {
    ::pis::capture::need_common
    set m [::pis::capture::file_stem [::pis::common::get $cfg session model_file ""]]
    if {$m eq ""} { set m "nomodel" }
    return [join [list \
        [::pis::capture::sanitize $m] \
        [::pis::capture::sanitize [::pis::capture::result_part $cfg $k]] \
        [::pis::capture::sanitize $item]] _]
}

# The same, with the extension the task freezes.
proc ::pis::capture::file_name {cfg k item} {
    return "[::pis::capture::file_base $cfg $k $item].png"
}

# A path in `dir` built from `base` that neither this run nor the folder already holds: the first
# free name is `base.png`, then `base_2.png`, `base_3.png`, ... `used` is the dict of names taken
# by this run (lower-cased, because Windows compares file names without case), and the folder is
# asked too, so an image from an earlier session is never overwritten. Answers {path used'}.
proc ::pis::capture::unique_path {dir base used} {
    if {[string trim $dir] eq "" || [string trim $base] eq ""} {
        error "::pis::capture::unique_path: empty folder or base name"
    }
    set n 1
    while {$n <= 9999} {
        set name "$base.png"
        if {$n > 1} { set name "${base}_$n.png" }
        set key [string tolower $name]
        set path [file join $dir $name]
        if {![dict exists $used $key] && ![file exists $path]} {
            dict set used $key 1
            return [list $path $used]
        }
        incr n
    }
    error "capture: cannot find a free image name for '$base' in $dir (9999 names taken)"
}

# Windows a run captures: every window Load All created (1..N, layout order) for the layout scope,
# or the one window that is active right now. Both are refused before any capture when Load All
# has not run, so a module never "applies" to a session that holds nothing.
proc ::pis::capture::windows {cfg scope} {
    if {$scope ne "layout"} {
        return [list [::pis::hw::active_window]]
    }
    set loaded 0
    if {[llength [info commands ::pis::step01::loaded]] > 0} {
        catch {set loaded [::pis::step01::loaded]}
    } elseif {[info exists ::pis::step01::loaded]} {
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
        error "Load All reported no window to capture (windows: '$n')"
    }
    set out [list]
    set i 1
    while {$i <= $n} {
        lappend out $i
        incr i
    }
    return $out
}

# Run the module once. SPEC_gui s.6.5 + s.7: the CHECKED ROWS are the items (each one becomes one
# image), the scope decides the windows - [Apply all layout] captures every window of the load,
# the module button captures the window that is active. Everything that can be refused is refused
# BEFORE the first capture (folder, size, a row without text, every name), so a refused run sends
# nothing and journals nothing; a failure DURING the run names the window, the item and the output
# path and stops (whether a stop ends the whole run is the GUI's continue-on-error decision).
# Nothing here writes the ini and nothing calls another module: "Capture only captures".
proc ::pis::capture::run {root cfg scope} {
    variable captured
    variable calls
    variable last_path
    variable last_dir
    ::pis::capture::need_common
    ::pis::capture::need_adapter
    if {$scope ne "layout" && $scope ne "active"} {
        error "::pis::capture::run: unknown scope '$scope' (expected active or layout)"
    }
    set title [::pis::capture::title]
    set rows [::pis::capture::checked_rows $cfg]
    if {[llength $rows] == 0} {
        set captured 0
        ::pis::common::log $cfg WARN "module $title: no item selected, nothing run"
        return 0
    }
    set dir [::pis::capture::output_dir $root $cfg]
    set size [::pis::capture::size_spec $cfg]
    set unit [lindex $size 0]
    set width [lindex $size 1]
    set height [lindex $size 2]
    set windows [::pis::capture::windows $cfg $scope]
    # ONE plan of {window row item path} built before anything is sent: every name is fixed then,
    # so no capture can be told a name a later capture of the same run will take.
    set plan [list]
    set used [dict create]
    foreach k $windows {
        foreach row $rows {
            set item [::pis::capture::item_text $cfg $row]
            set made [::pis::capture::unique_path $dir [::pis::capture::file_base $cfg $k $item] $used]
            set used [lindex $made 1]
            lappend plan [list $k $row $item [lindex $made 0]]
        }
    }
    set total [llength $plan]
    ::pis::common::log $cfg INFO [format "%s: %d image(s), %s %d x %d, into %s" \
        $title $total $unit $width $height $dir]
    set done 0
    foreach step $plan {
        set k [lindex $step 0]
        set row [lindex $step 1]
        set item [lindex $step 2]
        set path [lindex $step 3]
        incr done
        ::pis::capture::status [format "Capture %d/%d running..." $done $total]
        ::pis::hw::context $title $item
        # "set the view" (SPEC_gui s.6.5): the layout scope makes the window active first; the
        # active scope already IS that window, so it sends nothing extra.
        if {$scope eq "layout"} {
            ::pis::hw::select_window $k
        }
        incr calls
        set code [catch {::pis::hw::capture_window $k $path $unit $width $height} res]
        if {$code} {
            set msg "capture window $k '$item' failed: [string trim $res] | output: $path"
            ::pis::common::log $cfg ERROR $msg
            ::pis::capture::status "Error: capture window $k failed (see log)"
            error $msg
        }
        # The adapter's own read-back already proved the file; the module looks once more because
        # the task asks for the check AFTER the call and because the size goes into the log line.
        if {![file exists $path]} {
            error "capture window $k '$item' wrote no file: $path"
        }
        set bytes [file size $path]
        if {$bytes <= 0} {
            error "capture window $k '$item' wrote an empty file: $path"
        }
        set last_path $path
        ::pis::common::log $cfg OK [format "capture window %d '%s' row %d: %s (%d bytes)" \
            $k $item $row $path $bytes]
    }
    set captured $total
    set last_dir $dir
    ::pis::common::log $cfg OK [format "%s: %d image(s) in %s" $title $total $dir]
    return $total
}

# Counters back to zero; used by tests/tcl/test_capture.tcl between cases.
proc ::pis::capture::reset_state {} {
    variable captured
    variable calls
    variable last_path
    variable last_dir
    set captured 0
    set calls 0
    set last_path ""
    set last_dir ""
    return
}


