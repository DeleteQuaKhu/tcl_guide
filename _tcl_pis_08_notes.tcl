# src/01_scripts/_tcl_pis_08_notes.tcl
# ::pis::notes - the "Notes" module (task T-038): the sixth panel, its `Macro Add`, and the notes
# of one window. Tcl/Tk 8.5 compatible, no tcllib, no network, no package require.
# Sourcing this file defines procs only: it never calls HyperView.
#
# EVERY CALL THIS MODULE SENDS IS PROVEN in the owner's own scripts (docs/refs/HV_API_REF.md,
# Annotation/Note, S07:312-344 and common patterns 8/9) - no variant, no guess. The order of one
# note is the owner's order, and the space the supplier's script leaves after `=` in the `font=`,
# `fontsize=` and `borderthickness=` forms is part of the PROVEN text:
#   1) `hwc annotation note delete "<name>"`            inside catch (the old note goes first)
#   2) `hwc annotation note create "<name>"`
#   3) `hwc annotation note "<name>" display text=<text>`
#   4) optional `display font=` (a 4-word fontSpec), `display fontsize=`, `display borderthickness=`
#      (`[notes] font / fontsize / borderthickness`; an EMPTY value is not sent at all - Q11)
#   5) `hwc annotation note "<name>" display positiontype=coordinates`
#   6) `hwc annotation note "<name>" display positionx=<x> positiony=<y> positionz=<z>`
#   7) `hwc annotation note "<name>" display alignmenttext=Center`
#   8) the three optional `catch` extras: `display textcolor=black`, `display borderwidth=0`,
#      `display linetoentity=Continuous`
# Attach-to-node (`... attach entity node "<model> <part> <nodeID>"`, S07:328/338) is NOT sent in
# this version: the file row carries coordinates only (Q10).
#
# THE VERDICT IS `APPLIED-UNCONFIRMED` (docs/SPEC.md A19/Q12): no fetched page documents a per-note
# getter and this build may ignore an `hwc` command in silence, so nothing here can prove that a
# note was drawn. `poIPost GetDisplayOptions notes` (S57) speaks for the WINDOW's notes category and
# is READ and reported, never forced. The status bar sentence is the GUI's job
# ("Notes: applied, display not confirmed (look at the windows)"); this module writes ONE
# `notes: no documented getter, window k must be checked by eye` per run.
#
# T-039 (F18): the three controls of the panel - the title button (ACTIVE window), [Apply all
# layout] (every window of the layout) and [Macro Add] (Notes.log) - are all reached through
# ::pis::gui::run_module, so one shared guard turns any error into `ERROR module <Name>: ...`
# instead of a Tk traceback. Nothing ticked is exactly ONE `WARN Notes: no row ticked` (0 calls,
# 0 journal lines). The T-038 file grammar has NO verb column: every accepted data line IS one
# `hwc annotation note ... display ...` row (name, text, coordinates), so `Macro Add` can DISPLAY
# a note and cannot ADJUST one (reported, not invented). A line that is not a row, a `#Note<N>`
# comment or a blank is refused with `Notes.log line <n>: ...`, and the WHOLE file - every name
# and every window - is validated before the first HyperView call (all-or-nothing).
#
# Public procs:
#   ::pis::notes::run {root cfg scope}          -> windows done ([Apply all layout] / the title)
#   ::pis::notes::macro_add {root cfg}          -> notes created from Notes.log (the file action)
#   ::pis::notes::apply_to_window {k rows opts trace {cont 0} {cfg ""}} -> one window (the ONE seam)
#   ::pis::notes::one_note {k r row opts trace} -> one note, in the PROVEN order
#   ::pis::notes::name_for {k row}              -> pis_note_<k>_<row> (sanitized)
#   ::pis::notes::name_from {row path}          -> the file row's name, sanitized, checked
#   ::pis::notes::sanitize {text}               -> letters, digits and _ only
#   ::pis::notes::trace_on {cfg}                -> [debug] notes_trace (default 1)
#   ::pis::notes::opts {cfg}                    -> [notes] font / fontsize / borderthickness
#   ::pis::notes::targets {cfg scope}           -> windows to act on
#   ::pis::notes::layout_windows {cfg}          -> {id count} of the layout's static table
#   ::pis::notes::chosen {cfg}                  -> the TICKED rows as {row n text <text>} dicts
#   ::pis::notes::reset_state {}                -> counters back to 0 (tests)
# Namespace variables: applied, created, failed, calls, windows, last_file, unconfirmed

namespace eval ::pis::notes {
    if {![info exists applied]} { set applied 0 }
    if {![info exists created]} { set created 0 }
    if {![info exists failed]} { set failed 0 }
    if {![info exists calls]} { set calls 0 }
    if {![info exists windows]} { set windows [list] }
    if {![info exists last_file]} { set last_file "" }
    # 1 once a press has sent a note: the GUI turns this into the amber status (it is never a
    # green "applied" - nothing on this build can confirm a note).
    if {![info exists unconfirmed]} { set unconfirmed 0 }
}

# The module title exactly as the GUI shows it: it goes into the journal comment and the WARN
# required by docs/SPEC.md A8 ("module <name>: no item selected, nothing run").
proc ::pis::notes::title {} {
    return "Notes"
}

proc ::pis::notes::need_common {} {
    foreach p {get log resolve_path to_bool} {
        if {[llength [info commands ::pis::common::$p]] == 0} {
            error "::pis::notes: source _tcl_pis_00_common.tcl first (missing ::pis::common::$p)"
        }
    }
    return
}

# Every HyperView call of this module goes through the adapter (docs/SPEC.md D2). Without it a run
# must stop HERE, naming the missing proc, instead of failing halfway through window 1.
proc ::pis::notes::need_hw {} {
    foreach p {note_begin note_send note_now note_eye select_window active_window refresh} {
        if {[llength [info commands ::pis::hw::$p]] == 0} {
            error "::pis::notes: source _tcl_pis_11_hw_adapter.tcl first (missing ::pis::hw::$p)"
        }
    }
    return
}

# --- names (docs/refs/SPEC_gui.txt s.14.3, Q9) ------------------------------------------------
# A note name may hold letters, digits and _ only: a name a re-run can rebuild byte for byte, so a
# press replaces ITS OWN note and never a note made by hand.
proc ::pis::notes::sanitize {text} {
    set out ""
    foreach ch [split [string trim $text] ""] {
        if {[string is alnum -strict $ch] || $ch eq "_"} {
            append out $ch
        }
    }
    return $out
}

# The generated name of a panel row: window k, list row r (1-based, the ROW, not the run order, so
# ticking row 3 alone still writes pis_note_<k>_3 on the next press).
proc ::pis::notes::name_for {k row} {
    return [::pis::notes::sanitize "pis_note_${k}_${row}"]
}

# The name a `Macro Add` row takes: its own Name field (s.15.3/Q9), sanitized the same way. A name
# with nothing usable left is refused with the file and the line, because the delete-then-create
# step could not replace anything with it.
proc ::pis::notes::name_from {row path} {
    set raw [string trim [dict get $row name]]
    set n [::pis::notes::sanitize $raw]
    if {$n eq ""} {
        error [format "%s line %s: Name '%s' has no letter or digit to build a note name" \
            [file tail [string trim $path]] [dict get $row line] $raw]
    }
    return $n
}

# Is the [debug] notes_trace step trace on? Default 1 until the owner writes `accepted`; an ini
# value of 0 turns it off and the JOURNAL text stays identical either way (docs/SPEC.md).
proc ::pis::notes::trace_on {cfg} {
    set v 1
    catch {set v [::pis::common::get $cfg debug notes_trace 1]}
    set on 1
    if {[catch {set on [::pis::common::to_bool $v "debug notes_trace"]}]} { set on 1 }
    return $on
}

# The note formatting of the ini (Q11): `[notes] font`, `[notes] fontsize`,
# `[notes] borderthickness`. An EMPTY value means that display call is not sent. `font=` needs the
# size, because the PROVEN form is one 4-word `fontSpec`
# (`[list $fontName $fontSize regular regular]`, S07:332) - a half-filled pair is reported once
# instead of sent half-filled.
proc ::pis::notes::opts {cfg} {
    set font ""
    set size ""
    set thick ""
    catch {set font [string trim [::pis::common::get $cfg notes font ""]]}
    catch {set size [string trim [::pis::common::get $cfg notes fontsize ""]]}
    catch {set thick [string trim [::pis::common::get $cfg notes borderthickness ""]]}
    if {($font eq "") != ($size eq "")} {
        ::pis::common::log $cfg INFO \
            "notes: [notes] font and fontsize must both be set, so the font= call is not sent (Q11)"
    }
    return [dict create font $font fontsize $size borderthickness $thick]
}

# The layout's {id count}: the STATIC table of docs/refs/HV_API.md sec.2, never the page, because a
# page a previous session arranged by hand is not evidence of what the ini asked for (T-017).
proc ::pis::notes::layout_windows {cfg} {
    set id [string trim [::pis::common::get $cfg layout id ""]]
    set count ""
    if {[llength [info commands ::pis::hw::layout_windows]] > 0} {
        set count [::pis::hw::layout_windows $id]
    }
    if {$count eq ""} {
        error [format "layout id %s is not in the table" $id]
    }
    return [list $id $count]
}

# Windows a run must act on (same rule as Load Legend, F1/Q1). scope "layout" = every window Load
# All created (1..N in layout order); anything else = the ACTIVE window only, asked with the
# documented `hwIPage GetActiveWindow` (S33, read-only, never journaled).
proc ::pis::notes::targets {cfg scope} {
    if {$scope ne "layout"} {
        return [list [::pis::hw::active_window]]
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

# --- THE SEAM: ONE window (T-038) -----------------------------------------------------------
# The only place of this module that changes a window: select window k (ONE journaled
# `hwi ... SetActiveWindow k`, the PROVEN helper), then the rows in list order, each one note.
# Nothing here walks the page - the window select is the adapter's job (F16).
# `cont` 1 = a note that fails is logged and the next row is sent anyway ([log] continue_on_error);
# the window itself is still counted as done unless the select failed.
# Returns the number of notes this window built.
proc ::pis::notes::apply_to_window {k rows opts trace {cont 0} {cfg ""}} {
    variable applied
    variable created
    variable failed
    variable calls
    if {![string is integer -strict $k] || $k < 1} {
        error "::pis::notes::apply_to_window: window index must be a positive integer, got: $k"
    }
    # The journal comment of every line this window writes: module + window.
    catch {::pis::hw::context [::pis::notes::title] [format "window %d" $k]}
    # 1) window k becomes the active one (ONE journaled hwi line).
    incr calls
    set code [catch {::pis::hw::select_window $k} res]
    if {$code} {
        error [string trim $res]
    }
    # 2) the rows, in list order. The row number in the STEP line is the row's own number (the list
    #    index of a panel row, the ordinal of a file row), never the run order.
    set built 0
    foreach row $rows {
        set r [::pis::notes::row_get $row row 0]
        set code [catch {::pis::notes::one_note $k $r $row $opts $trace} res]
        if {$code} {
            incr failed
            if {!$cont} {
                error [string trim $res]
            }
            # continue-on-error: the row is REPORTED and the next row still goes (s.7).
            if {$cfg ne ""} {
                ::pis::common::log $cfg ERROR \
                    "[::pis::notes::title]: [string trim $res]"
            }
            continue
        }
        incr applied
        incr created
        incr built
    }
    return $built
}

# `GetDisplayOptions notes` of window k, READ and REPORTED, never turned into a verdict (Q12/A19):
# the option speaks for the window's notes category, not for one note. A build without the getter
# answers "" (the adapter proved it absent once, T-027) and then this writes nothing at all.
proc ::pis::notes::report_window {cfg k} {
    set nv ""
    if {[catch {::pis::hw::note_now $k} nv]} {
        ::pis::common::log $cfg INFO [format \
            "notes: window %s GetDisplayOptions notes failed: %s" $k [string trim $nv]]
        return
    }
    set nv [string trim $nv]
    if {$nv eq ""} { return }
    ::pis::common::log $cfg INFO [format \
        "notes: window %s GetDisplayOptions notes = %s" $k $nv]
    return
}

# Run the module once (the panel's own buttons): the TICKED rows, for every window of the layout
# ([Apply all layout]) or for the ACTIVE window (the title button, s.5). Nothing ticked is the WARN of
# s.14.3 and sends no call at all. Every press is APPLIED-UNCONFIRMED (A19): the adapter writes ONE
# eye line per press, the closing line says "display not confirmed", and the GUI turns `unconfirmed`
# into the amber status (`Notes: applied, display not confirmed (look at the windows)`).
proc ::pis::notes::run {root cfg scope} {
    variable applied
    variable created
    variable failed
    variable calls
    variable windows
    variable unconfirmed
    ::pis::notes::need_common
    ::pis::notes::need_hw
    if {$scope ne "layout" && $scope ne "active"} {
        error "::pis::notes::run: unknown scope '$scope' (expected active or layout)"
    }
    set applied 0
    set created 0
    set failed 0
    set calls 0
    set windows [list]
    set unconfirmed 0
    # A new press forgets which methods this build lacks (T-027) and re-arms the adapter's own
    # one-per-press note lines (T-038).
    catch {::pis::hw::absent_reset}
    catch {::pis::hw::note_begin}
    set rows [::pis::notes::chosen $cfg]
    if {[llength $rows] == 0} {
        # T-039: the one WARN the SPEC states for this panel, and nothing else happens - 0
        # HyperView calls, 0 journal lines.
        ::pis::common::log $cfg WARN "[::pis::notes::title]: no row ticked"
        return 0
    }
    set targets [::pis::notes::targets $cfg $scope]
    set total [llength $targets]
    set opts [::pis::notes::opts $cfg]
    set trace [::pis::notes::trace_on $cfg]
    set cont 0
    catch {set cont [::pis::common::to_bool \
        [::pis::common::get $cfg log continue_on_error 0] "log continue_on_error"]}
    set done 0
    foreach k $targets {
        set code [catch {::pis::notes::apply_to_window $k $rows $opts $trace $cont $cfg} res]
        if {$code} {
            if {!$cont} {
                error [string trim $res]
            }
            ::pis::common::log $cfg ERROR "[::pis::notes::title]: [string trim $res]"
            continue
        }
        incr done
        lappend windows $k
    }
    if {$applied > 0} {
        ::pis::notes::report_window $cfg [lindex $windows 0]
        catch {::pis::hw::note_eye [lindex $windows 0]}
        set unconfirmed 1
    }
    set tail ""
    if {$done < $total} {
        set tail [format ", %d of %d window(s) did not finish" [expr {$total - $done}] $total]
    }
    if {$failed > 0} { append tail [format ", %d note(s) failed" $failed] }
    set level OK
    if {$failed > 0} { set level WARN }
    # T-039 (item 5): the closing line starts with `Notes: <n> note(s) in <w> window(s)` and keeps
    # the amber sentence, because no press on this build can be a green pass (A19).
    ::pis::common::log $cfg $level [format \
        "Notes: %d note(s) in %d window(s)%s, display not confirmed (look at the windows)" \
        $applied $done $tail]
    return $applied
}

# The TICKED rows of the panel as `{row <n> text <text>}` dicts - the same shape `row_get` reads, so a
# panel row and a file row go through the same note step (Q9/Q10). The row number is the 1-based list
# position, the number the note name carries. Unticked, empty and unreadable rows are skipped: `run`
# turns an empty answer into the WARN the SPEC states require.
proc ::pis::notes::chosen {cfg} {
    set out [list]
    set flags [list]
    catch {set flags [::pis::common::get $cfg notes checked ""]}
    set i 0
    foreach flag $flags {
        incr i
        set on 0
        catch {set on [::pis::common::to_bool $flag "notes checked"]}
        if {!$on} { continue }
        set text ""
        catch {set text [string trim [::pis::common::get $cfg notes item$i ""]]}
        if {$text eq ""} { continue }
        lappend out [dict create row $i text $text]
    }
    return $out
}

# A row value with a default, so a panel row ({row text}) and a file row ({line name text x y z})
# can both go through the same note step (Q9/Q10).
proc ::pis::notes::row_get {row key default} {
    if {[dict exists $row $key]} { return [dict get $row $key] }
    return $default
}

# ONE note command, counted. The module's `calls` is the number of HyperView calls this press made
# (the window selects are counted by the caller), so the report and the tests can state it exactly.
proc ::pis::notes::send {k r step words trace {soft 0}} {
    variable calls
    incr calls
    return [::pis::hw::note_send $k $r $step $words $trace $soft]
}

# ONE note, in the PROVEN order of docs/refs/HV_API_REF.md S07:312-344 and docs/SPEC.md A19. Every
# command is its own journal line, so a replay of the journal rebuilds the same note (s.14.5).
# `row`  {name text x y z} - `name` "" means the generated pis_note_<k>_<row> (s.14.3/Q9), and a
#        panel row carries no coordinates, so X/Y/Z default to 0 (Q10: coordinates only, and a text
#        row has none - 0 0 0 is the corner, the one place a note cannot hide a window). The TEXT is
#        trimmed, like every field of the file parser, so a row of blanks is the error above.
# `opts` {font fontsize borderthickness} - an EMPTY value means that call is not sent (Q11).
# Returns the number of commands sent for this note.
proc ::pis::notes::one_note {k r row opts trace} {
    set text [string trim [::pis::notes::row_get $row text ""]]
    if {$text eq ""} {
        error [format "::pis::notes::one_note: window %d row %d has no text" $k $r]
    }
    set name [string trim [::pis::notes::row_get $row name ""]]
    if {$name eq ""} { set name [::pis::notes::name_for $k $r] }
    set x [::pis::notes::row_get $row x 0]
    set y [::pis::notes::row_get $row y 0]
    set z [::pis::notes::row_get $row z 0]
    set font [dict get $opts font]
    set size [dict get $opts fontsize]
    set thick [dict get $opts borderthickness]
    set n 0
    # 1) the note of THIS name first, inside the owner's own `catch` (S07:312): it may not exist yet,
    #    and a failing delete must not cost the note that is about to be created.
    ::pis::notes::send $k $r delete [list annotation note delete $name] $trace 1
    incr n
    # 2) create (S07:330) and 3) the text (S07:331).
    ::pis::notes::send $k $r create [list annotation note create $name] $trace
    incr n
    ::pis::notes::send $k $r text [list annotation note $name display text=$text] $trace
    incr n
    # 4) the optional formatting (S07:332-335). The space after `=` is part of the PROVEN line, so the
    #    value is sent as its OWN word: `display font= {<font> <size> regular regular}`.
    if {$font ne "" && $size ne ""} {
        ::pis::notes::send $k $r font \
            [list annotation note $name display font= [list $font $size regular regular]] $trace
        incr n
        ::pis::notes::send $k $r fontsize \
            [list annotation note $name display fontsize= $size] $trace
        incr n
    }
    if {$thick ne ""} {
        ::pis::notes::send $k $r borderthickness \
            [list annotation note $name display borderthickness= $thick] $trace
        incr n
    }
    # 5) where the note sits (S07:336-337): coordinates only in v1, never attach (Q10).
    ::pis::notes::send $k $r positiontype \
        [list annotation note $name display positiontype=coordinates] $trace
    incr n
    ::pis::notes::send $k $r position [list annotation note $name display \
        positionx=$x positiony=$y positionz=$z] $trace
    incr n
    # 6) the alignment the owner's script asks for (S07:339).
    ::pis::notes::send $k $r alignment \
        [list annotation note $name display alignmenttext=Center] $trace
    incr n
    # 7) the three optional visual arguments, each ONE caught call (S07:342-344): a build that does
    #    not know one answers with an error and the note still stands - that IS the owner's `catch`.
    foreach pair {{textcolor textcolor=black} {borderwidth borderwidth=0} \
            {linetoentity linetoentity=Continuous}} {
        ::pis::notes::send $k $r [lindex $pair 0] \
            [list annotation note $name display [lindex $pair 1]] $trace 1
        incr n
    }
    return $n
}

# [Macro Add] on Notes (s.14.5): ONE file pass. The gate of s.14.7 comes first (Load All), then the
# WHOLE file is parsed BEFORE any window is selected or any command is sent (s.15.1), and only then
# does the press act: per `#Note<N>` section, per window the section names, per row in FILE order,
# one note. The names are the file's own Name field, sanitized (Q9), so a re-press replaces exactly
# the notes this file made. The panel's rows and the ini are untouched - a [Macro Add] adds to
# HyperView, it never edits the list (the rule [Macro Add] on Measures follows, Q7).
# Returns the number of notes created.
proc ::pis::notes::macro_add {root cfg} {
    variable applied
    variable created
    variable failed
    variable calls
    variable windows
    variable last_file
    variable unconfirmed
    ::pis::notes::need_common
    ::pis::notes::need_hw
    set applied 0
    set created 0
    set failed 0
    set calls 0
    set windows [list]
    set unconfirmed 0
    # 14.7: both [Macro Add] buttons refuse while Load All has not succeeded - 0 calls, 0 journal.
    set loaded 0
    if {[info exists ::pis::step01::loaded]} { set loaded $::pis::step01::loaded }
    if {!$loaded} {
        error "Model/results not loaded | click Load All first."
    }
    set name Notes.log
    catch {set name [::pis::common::get $cfg macro notes_log Notes.log]}
    set path [::pis::common::resolve_path $root $name]
    set last_file $path
    # Parse FIRST: a missing, unreadable or malformed file raises HERE, so the press has made no call
    # and written no journal line at all (A20).
    set doc [::pis::dlog::parse $path note]
    set layout [::pis::notes::layout_windows $cfg]
    set id [lindex $layout 0]
    set count [lindex $layout 1]
    set opts [::pis::notes::opts $cfg]
    set trace [::pis::notes::trace_on $cfg]
    set cont 0
    catch {set cont [::pis::common::to_bool \
        [::pis::common::get $cfg log continue_on_error 0] "log continue_on_error"]}
    # T-039: validate the WHOLE file before the first call - every section's windows AND every
    # Name - so a bad Name or an orphan section on the LAST line costs no HyperView call at all
    # (all-or-nothing, the rule of s.15.1 applied to the whole press).
    set plan [list]
    foreach section [dict get $doc sections] {
        set rows [list]
        set ord 0
        foreach row [::pis::dlog::rows $section] {
            incr ord
            dict set row row $ord
            dict set row name [::pis::notes::name_from $row $path]
            lappend rows $row
        }
        # A section that names no window is A20's ERROR and stops the press unless continue-on-error.
        lappend plan [dict create section [dict get $section name] \
            targets [::pis::dlog::windows $cfg $path $section $count $id] rows $rows]
    }
    catch {::pis::hw::absent_reset}
    catch {::pis::hw::note_begin}
    set done 0
    foreach step $plan {
        set sec [dict get $step section]
        set rows [dict get $step rows]
        foreach k [dict get $step targets] {
            # A section holding only its column row is legal: ONE INFO, that window is skipped.
            if {[llength $rows] == 0} {
                ::pis::common::log $cfg INFO [format \
                    "Macro Add Notes: section '%s' has no rows, window %s skipped" $sec $k]
                continue
            }
            ::pis::common::log $cfg INFO [format \
                "Macro Add Notes window %s section '%s' rows %d" $k $sec [llength $rows]]
            set code [catch {::pis::notes::apply_to_window $k $rows $opts $trace $cont $cfg} res]
            if {$code} {
                if {!$cont} {
                    error [string trim $res]
                }
                ::pis::common::log $cfg ERROR "[::pis::notes::title]: [string trim $res]"
                continue
            }
            incr done
            lappend windows $k
        }
    }
    if {$applied > 0} {
        ::pis::notes::report_window $cfg [lindex $windows 0]
        catch {::pis::hw::note_eye [lindex $windows 0]}
        set unconfirmed 1
    }
    set tail ""
    if {$failed > 0} { set tail [format ", %d failed" $failed] }
    set level OK
    if {$failed > 0} { set level WARN }
    ::pis::common::log $cfg $level [format \
        "Macro Add Notes: %d note(s) in %d window(s) from %s%s" \
        $applied $done [file tail $path] $tail]
    return $applied
}

# Counters back to zero; used by tests/tcl/test_notes.tcl between cases.
proc ::pis::notes::reset_state {} {
    variable applied
    variable created
    variable failed
    variable calls
    variable windows
    variable last_file
    variable unconfirmed
    set applied 0
    set created 0
    set failed 0
    set calls 0
    set windows [list]
    set last_file ""
    set unconfirmed 0
    catch {::pis::hw::note_begin}
    return
}

