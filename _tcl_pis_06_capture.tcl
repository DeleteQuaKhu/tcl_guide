# src/01_scripts/_tcl_pis_06_capture.tcl
# ::pis::capture - the "Capture" module (task T-011; fixed by T-032, view step fixed by T-033).
# SPEC_gui.txt s.6.5: "List of views (View 1..n). Apply: for each checked view, set the view and
# capture an image. Image name: {result_file_name}_{view}.png so files never overwrite each
# other. Capture only captures; it does not trigger other modules."
# T-032 (owner fail F13, 2026-11-18) changed three things:
#   1. every image is a SEQUENCE of steps, each sent through the adapter: select the window
#      (layout scope) -> activate the VIEW the ticked row names -> Draw -> the capture call ->
#      the file check. One STEP log line per step while [debug] capture_trace is 1, and the
#      journal still holds exactly ONE replayable hwi line per image;
#   2. the capture call order follows the source precedence PROVEN > DOC (owner scripts first,
#      `hwISession CaptureWindow` S91 last) - see the adapter's capture_window table;
#   3. the name is `{result_file_name}_{view}.png`: the model is dropped (owner's order).
# T-033 (owner `T-011: fail 2`, F14) added what the module itself owns:
#   4. the view step has its own receiver list and its own failure (adapter view_table/set_view),
#      so the capture variants never run when the view could not be activated (F14 b);
#   5. `[capture] on_view_unavailable` (stop | capture_current): under `capture_current` ONE WARN
#      switches the rest of the run to the CURRENT view, the owner's way to test the call alone.
# Tcl/Tk 8.5 compatible, no tcllib, no network, no package require, no Tk.
# Sourcing this file defines procs only: it never calls HyperView.
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
#   ::pis::capture::image_type {cfg}          -> the image type (only png, the frozen extension)
#   ::pis::capture::trace_spec {cfg}          -> 1 = one STEP log line per step (default)
#   ::pis::capture::continue_on_error {cfg}   -> [log] continue_on_error as 0/1
#   ::pis::capture::view_policy {cfg}         -> [capture] on_view_unavailable: stop|capture_current
#   ::pis::capture::output_dir {root cfg}     -> absolute folder for the images (created if needed)
#   ::pis::capture::file_base {cfg k view}    -> {result}_{view}, sanitized, no extension
#   ::pis::capture::file_name {cfg k view}    -> that base plus ".png"
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
    foreach p {capture_window set_view active_window context} {
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
# with the documented defaults `pixels 1280 960` (the page's own example numbers, HV_API S91).
# T-032 also accepts the owner's script key names `image_width`/`image_height` (S06/S07 read
# `display image_width` from their config); the older `width`/`height` keys keep working.
# An unknown unit or a non-positive number is refused HERE, before anything is sent.
proc ::pis::capture::size_spec {cfg} {
    ::pis::capture::need_common
    set unit [string tolower [string trim [::pis::common::get $cfg capture unit pixels]]]
    if {$unit eq ""} { set unit pixels }
    if {$unit ne "pixels" && $unit ne "percent"} {
        error "capture: \[capture\] unit must be pixels or percent, got '$unit'"
    }
    set out [list $unit]
    foreach {keys def} {{image_width width} 1280 {image_height height} 960} {
        set v ""
        foreach key $keys {
            set v [string trim [::pis::common::get $cfg capture $key ""]]
            if {$v ne ""} { break }
        }
        if {$v eq ""} { set v $def }
        if {![string is integer -strict $v] || $v < 1} {
            error "capture: \[capture\] [lindex $keys 0] must be a positive integer, got '$v'"
        }
        lappend out $v
    }
    return $out
}

# The image TYPE the capture call is asked for. The file name is frozen to `.png` by SPEC_gui
# s.6.5, so a type that is not png would write a JPEG with a .png name: refused by name, before
# anything is sent. `[capture] image_type` is the owner's own config key (S06/S07).
proc ::pis::capture::image_type {cfg} {
    ::pis::capture::need_common
    set t [string tolower [string trim [::pis::common::get $cfg capture image_type png]]]
    if {$t eq ""} { set t png }
    if {$t ne "png"} {
        error "capture: \[capture\] image_type must be png (the image name ends in .png), got '$t'"
    }
    return $t
}

# The per-step trace (T-032): `[debug] capture_trace`, default 1 until the owner writes accepted.
# It is a LOG switch only - the journal text is identical either way.
proc ::pis::capture::trace_spec {cfg} {
    ::pis::capture::need_common
    set raw [string trim [::pis::common::get $cfg debug capture_trace 1]]
    if {$raw eq ""} { return 1 }
    return [::pis::common::to_bool $raw "debug capture_trace"]
}

# Whether a failed image stops the run (`[log] continue_on_error`, SPEC.md data model).
proc ::pis::capture::continue_on_error {cfg} {
    ::pis::capture::need_common
    set raw [string trim [::pis::common::get $cfg log continue_on_error 0]]
    if {$raw eq ""} { return 0 }
    return [::pis::common::to_bool $raw "log continue_on_error"]
}

# What to do when the build cannot activate the view of a row (T-033 item 6):
#   `[capture] on_view_unavailable = stop`           -> the image fails, nothing written or journaled
#   `[capture] on_view_unavailable = capture_current` -> ONE WARN, then the current view of every
#                                                       window is captured (file names keep the row's
#                                                       view name, so the images may show another view)
# The default is `stop`: an image that silently shows a different view than its name promises is
# worse than a failure the owner can read. An unknown value is refused by name.
proc ::pis::capture::view_policy {cfg} {
    ::pis::capture::need_common
    set raw [string tolower [string trim [::pis::common::get $cfg capture on_view_unavailable stop]]]
    if {$raw eq ""} { set raw stop }
    if {$raw ne "stop" && $raw ne "capture_current"} {
        error "capture: \[capture\] on_view_unavailable must be stop or capture_current, got: '$raw'"
    }
    return $raw
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

# The {result_file_name} part of the name: the result FILE of that window (its basename without
# extension, exactly as the result module knows it - window k is "one result file", SPEC_gui s.4).
# T-032 (owner's order): the MODEL is no longer part of the name, and a window with no result
# line (fewer files than windows) is `noresult`. The uniqueness pass below still guarantees that
# no image is ever overwritten.
proc ::pis::capture::result_part {cfg k} {
    ::pis::capture::need_common
    set files [::pis::common::get $cfg session result_files ""]
    if {[string is integer -strict $k] && $k >= 1 && $k <= [llength $files]} {
        set f [string trim [lindex $files [expr {$k - 1}]]]
        if {$f ne ""} {
            set stem [::pis::capture::file_stem $f]
            if {$stem ne ""} { return $stem }
        }
    }
    return "noresult"
}

# {result_file_name}_{view}, every part sanitized: the pattern T-032 fixes, no extension.
proc ::pis::capture::file_base {cfg k view} {
    ::pis::capture::need_common
    return [join [list \
        [::pis::capture::sanitize [::pis::capture::result_part $cfg $k]] \
        [::pis::capture::sanitize $view]] _]
}

# The same, with the extension the task freezes.
proc ::pis::capture::file_name {cfg k view} {
    return "[::pis::capture::file_base $cfg $k $view].png"
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
        # T-032: ONE clear line and NOTHING sent - a capture sent to a guessed window would
        # photograph the wrong one.
        if {[catch {::pis::hw::active_window} aw]} {
            error "capture: no active window ([string trim $aw])"
        }
        return [list $aw]
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

# Run the module once (T-032). SPEC_gui s.6.5 + s.7: the CHECKED ROWS are the VIEWS (each one
# becomes one image of the row's view), the scope decides the windows - [Apply all layout]
# captures every window of the load, the module button captures the window that is active.
# Everything that can be refused is refused BEFORE the first capture (folder, size, type, a row
# without text, every name), so a refused run sends nothing and journals nothing.
# Per image the adapter sends: select window (layout only) -> view -> Draw -> capture -> file
# check, with ONE STEP log line per step while the trace is on and ONE journal line per image
# either way. A failure names window, row, view, step, the raw answer and the output path; with
# [log] continue_on_error = 1 the next image is attempted, otherwise the run stops and says which
# windows were not attempted. Nothing here writes the ini: "Capture only captures".
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
    lassign [::pis::capture::size_spec $cfg] unit width height
    set type [::pis::capture::image_type $cfg]
    set trace [::pis::capture::trace_spec $cfg]
    set cont [::pis::capture::continue_on_error $cfg]
    set windows [::pis::capture::windows $cfg $scope]
    # ONE plan of {window row view path} built before anything is sent: every name is fixed then,
    # so no capture can be told a name a later capture of the same run will take.
    set plan [list]
    set used [dict create]
    foreach k $windows {
        foreach row $rows {
            set view [::pis::capture::item_text $cfg $row]
            set made [::pis::capture::unique_path $dir [::pis::capture::file_base $cfg $k $view] $used]
            set used [lindex $made 1]
            lappend plan [list $k $row $view [lindex $made 0]]
        }
    }
    set total [llength $plan]
    ::pis::common::log $cfg INFO [format "%s: %d image(s), %s %d x %d, type %s, into %s" \
        $title $total $unit $width $height $type $dir]
    ::pis::common::log $cfg INFO [format "%s: steps per image %s, trace %s (\[debug\] capture_trace)" \
        $title \
        [expr {$scope eq "layout" ? "select/view/draw/capture/file" : "view/draw/capture/file"}] \
        [expr {$trace ? "on" : "off"}]]
    # T-033 item 6: what to do when the build cannot activate a view. `stop` fails the image (the
    # adapter says `view step failed for all receivers, capture call not attempted`); the first
    # such failure under `capture_current` switches the WHOLE run to "capture the current view",
    # with ONE WARN, and the image that hit it is retried without the view step.
    set policy [::pis::capture::view_policy $cfg]
    set viewstep 1
    set warned 0
    # The receiver of the view step is discovered again for this run (one INFO line when it is
    # accepted), so the log of every run names the handle kind that worked.
    if {[llength [info commands ::pis::hw::begin_capture]] > 0} { catch {::pis::hw::begin_capture} }
    set captured 0
    set done 0
    set stopped ""
    foreach step $plan {
        set k [lindex $step 0]
        set row [lindex $step 1]
        set view [lindex $step 2]
        set path [lindex $step 3]
        incr done
        incr calls
        ::pis::capture::status [format "Capture %d/%d running..." $done $total]
        ::pis::hw::context $title $view
        set code [catch {
            ::pis::hw::capture_window $k $path $view $unit $width $height \
                -row $row -layout [expr {$scope eq "layout" ? 1 : 0}] -trace $trace -viewstep $viewstep
        } res]
        # The owner's way to test the capture call alone: the view could not be activated, so from
        # here on every image is taken from whatever view the window shows. ONE WARN, then the same
        # image is retried without the view step (nothing was written, so the retry is safe).
        if {$code && $viewstep && $policy eq "capture_current" && \
                [string first "view step failed" [string trim $res]] >= 0} {
            if {!$warned} {
                set warned 1
                ::pis::common::log $cfg WARN \
                    "capture: view activation unavailable on this build - capturing the CURRENT view of each window, the file names still carry the row's view name (images may show another view)"
            }
            set viewstep 0
            set code [catch {
                ::pis::hw::capture_window $k $path $view $unit $width $height \
                    -row $row -layout [expr {$scope eq "layout" ? 1 : 0}] -trace $trace -viewstep 0
            } res]
        }
        if {$code} {
            # Log hygiene (T-033 item 8): with the trace on, the RAW text already stands in the
            # failing STEP line, so this line points there instead of printing it a second time.
            # With the trace off there is no STEP line, so the raw text belongs here.
            set raw [string trim $res]
            if {$trace} {
                set detail "$raw (see the STEP line above)"
                if {[string length $detail] > 220} {
                    set detail "[string range $raw 0 180].. (see the STEP line above)"
                }
            } else {
                set detail $raw
            }
            set msg "capture window $k row $row view '$view' failed: $detail | output: $path"
            set later [::pis::capture::not_attempted $plan $k]
            if {$later ne ""} { append msg " | $later" }
            ::pis::common::log $cfg ERROR $msg
            ::pis::capture::status "Error: capture window $k failed (see log)"
            if {$cont} { continue }
            # The raised text is SHORT on purpose: the GUI logs it once more, and the whole raw
            # answer must not appear a third time.
            set stopped "capture window $k row $row view '$view' failed (see the log)"
            break
        }
        # The adapter proved the file; the module reads the size it reports (the same two facts,
        # once more, so the OK line can never claim an image the disk does not hold).
        set bytes 0
        if {[dict exists $res bytes]} { set bytes [dict get $res bytes] }
        if {$bytes <= 0} {
            set msg "capture window $k row $row view '$view' wrote no bytes: $path"
            ::pis::common::log $cfg ERROR $msg
            ::pis::capture::status "Error: capture window $k failed (see log)"
            if {$cont} { continue }
            set stopped $msg
            break
        }
        set last_path $path
        incr captured
        ::pis::common::log $cfg OK [format "capture window %d '%s' row %d: %s (%d bytes)" \
            $k $view $row $path $bytes]
    }
    if {$warned} {
        ::pis::common::log $cfg INFO \
            "capture: the images show the CURRENT view of each window, not the row's view (see the WARN above)"
    }
    set last_dir $dir
    if {$captured == $total} {
        ::pis::common::log $cfg OK [format "%s: captured %d of %d image(s) in %s" \
            $title $captured $total $dir]
    } else {
        ::pis::common::log $cfg WARN [format "%s: captured %d of %d image(s) in %s" \
            $title $captured $total $dir]
    }
    if {$stopped ne ""} { error $stopped }
    return $captured
}

# The windows of the plan that a stop left untouched, as ONE clause for the stop line
# ("windows 3..4 not attempted"), or "" when the failure was on the last window.
proc ::pis::capture::not_attempted {plan k} {
    set later [list]
    foreach step $plan {
        if {[lindex $step 0] > $k} { lappend later [lindex $step 0] }
    }
    if {[llength $later] == 0} { return "" }
    set later [lsort -unique -integer $later]
    return [format "windows %d..%d not attempted" [lindex $later 0] [lindex $later end]]
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


