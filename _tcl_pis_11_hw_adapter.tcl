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
#   ::pis::hw::reset_session {}                    clear the session (strict)
#   ::pis::hw::reset_session_soft {}               same, but an already-empty session passes
#   ::pis::hw::load_model {path}                   load ONE model into window 1 (k = 1)
#   ::pis::hw::load_model_in_window {index path}   load ONE model into window <index>
#   ::pis::hw::make_grid {cols rows}               build the cols x rows window grid
#   ::pis::hw::load_result_in_window {index path}  result file into window <index>
#   ::pis::hw::verify_window {index}               read-back: window <index> holds 1 model + 1 result
#   ::pis::hw::select_window {index}               make window <index> the active one
#   ::pis::hw::import_legend {path}                import a legend into the active window
# Console helpers, no file edit needed:
#   ::pis::hw::use {op n}       try variant n from now on (e.g. ::pis::hw::use make_grid 2);
#                               "::pis::hw::use order 2" picks the Load All step ORDER
#   ::pis::hw::order {}         which Load All sequence is in use (1 or 2)
#   ::pis::hw::variant {op}     current variant number (1..N)
#   ::pis::hw::variants {op}    that op's list: n, via, cmd, check, want, src, note
#   ::pis::hw::table {}         every op -> its variant list
#   ::pis::hw::help {}          print the table + the use syntax
#   ::pis::hw::diag {}          ONE line under 80 chars: id= api= model= result= per window
#   ::pis::hw::observe {}       ONE line under 80 chars: api= handles= clients= layout=. The only
#                               window count this file trusts; never journaled
#   ::pis::hw::models_in_window {k}  read-only: how many models window k really holds
#   ::pis::hw::clients {}       per-window client letter: H = HyperView, P = chart (Plot), ? =
#                               cannot tell (INFERRED from GetModelList - no GetClientType here)
#   ::pis::hw::page_info {}     ONE read-only line: page index, layout id, window count, the
#                               window numbers that really open (what the page IS right now)
#   ::pis::hw::layout_table {}  measure this page: ONE LAYOUTS line (id -> window count), e.g.
#                               "LAYOUTS 1=2 2=2 3=3 4=3 5=4". A probe: never journaled
#   ::pis::hw::grid_capture {}  read-only: the layout id the page is IN, as ONE GRID line plus
#                               the ::pis::hw::grid_token_set line to paste
#   ::pis::hw::grid_token_set {cols rows id}
#                               remember that layout id for this cols x rows in this session and
#                               print the [layout_tokens] line for the ini (added by hand)
#   ::pis::hw::reset_state {}   variants + order back to 1, no cached layout id (tests)
#   ::pis::hw::run {op values}  run an op (the six operations call this)
#   ::pis::hw::used {op {win}}  variant number that step really used (0 = none worked)
#   ::pis::hw::build_line {}    the ONE BUILD line (stamp, grid variants, line count, layout ids)
#   ::pis::hw::announce {}      print that line to the console and to the GUI log
#
# BUILD STAMP (T-006 iteration, 2026-11-11): ::pis::BUILD is a short code written BY HAND
# when this file changes, e.g. T6i-20261111-1420, so the HyperView machine can be matched to
# a copy of this file without a guess. Sourcing this file prints ONE line,
#   BUILD T6i-20261111-1420 | make_grid variants=1 | adapter lines=<n> | layouts=<n>
# THE LAYOUT IS AN INTEGER ID, NOT A STRING (owner facts F1/F2, 2026-11-11 - MEASURED, not guessed):
# F1: for a 4x1 request every spelling ("4x1", "4 x 1", "4 - 1", "4 times 1") gave layout=4 api=3,
#     and every transpose ("1x4", "1 x 4", ...) gave layout=1 api=2. So '<page> SetLayout' reads
#     ONLY the LEADING INTEGER of its argument and treats it as a layout ID; a "CxR" string is
#     never understood, and '<page> GetLayout' returns that integer. Passes 5-7 sent strings and
#     measured the page, which is why a 4x1 request could leave three windows on screen.
# F2: window-handle and client-handle probes SUCCEED for indices above api (api=2 handles=4
#     clients=3 on the owner's build), so they are not evidence. Only indices 1..api count; this
#     file never asks above api.
# F3: the owner's working reference sequence is: page SetLayout, client AddModel, model SetResult,
#     client WaitForResults - in that order, one window at a time.
# Consequences, all of them new in this pass:
#   1. ::pis::hw::layout_table measures THIS page: 'SetLayout <n>' for n = 1..30 (stop after three
#      consecutive errors), read api after each, cache id -> api for the session, print ONE line
#      "LAYOUTS 1=2 2=2 3=3 4=3 5=4". Nothing journaled: it is a probe, and it moves the page.
#   2. make_grid wants <cols>*<rows> windows and gets its id from (a) the page itself when it
#      already shows that many windows (no SetLayout at all), (b) [layout_tokens] in the ini or
#      ::pis::hw::grid_token_set (integers only), (c) the ids of layout_table whose api is the
#      wanted count - one id: use it; several: the lowest one plus the Override line; none: print
#      the table and the one Fix line, BEFORE anything is loaded.
#   3. Only the final 'SetLayout <id>' is a step: it goes through the wrapper and is journaled
#      once. Success is api == wanted with a window handle and a client handle for every window
#      1..api (never a probe above api), and one GRID line per build: "GRID: id=5 api=4 clients=4".
# The old string machinery (sweep_tokens, "RxC"/"R X C"/"R - C", the plain count, the legacy
# words) is GONE: F1 says this build cannot read any of it, so a candidate list of spellings is a
# list of things that cannot work.
#
# PER-WINDOW LOADING (fix, 2026-11-10): every window is its own client with its OWN model list,
# so a model loaded once into window 1 leaves windows 2..N empty and their result has no model to
# attach to. The reference loader takes the window index as its FIRST argument
# (conrod/tcl_guide/hv_model_loader.tcl:1428, :1483-1498) and the batch importer walks windows
# 1..N the same way (conrod/_tmp_hv/batchImportOdb.tcl:83-87): hence load_model_in_window.
#
# THE LOAD ORDER OF THE WORKING REFERENCE (F3, conrod/_tmp_hv/training.tcl:29-44): AddModel into
# the window, remember the model id AddModel RETURNED (training.tcl:36, and
# hv_model_loader.tcl:1333-1334 keeps it the same way), GetModelHandle with that id (:41 uses an
# explicit id, :55 [client GetActiveModel]), model SetResult (:42), client Draw (:43). This pass
# adds the owner's 'client WaitForResults' between SetResult and the result read-back, because a
# result read back too early is a result that is not there yet. A result is still attached ONLY
# after window k answered exactly 1 model - '<model> SetResult' on a window with no model changes
# nothing and says nothing.
#
# CLIENT TYPE - THE ESCAPED T-006 DEFECT (owner report, 2026-11-10: after Load All every window
# was HyperGraph 2D, not HyperView). This file used to send '<win> SetClientType Plot', copied
# from conrod/_tmp_hv/training.tcl:9,20 - a script whose own header says it makes a window a CURVE
# CHART, i.e. the exact opposite of a window that must show a model and a contour. So:
#   1. NO variant sets a client type any more.
#   2. The grid read-back REFUSES a window that cannot hold a model - a chart window answers a
#      client handle too, which is why the old check (client handle only) passed it.
#   3. 'GetClientType' appears in NO script on this machine (grep conrod/ test/), so a client TYPE
#      cannot be read back by name: OBS names counts, and a client that refuses 'GetModelList' is
#      reported as "client type plot". Nothing guesses a way back to a HyperView window either.
#
# TWO STEP ORDERS (variant lists never change for this; the order does):
#   order 1 (default): reset -> grid -> for k = 1..N: model k, result k
#   order 2:           reset -> model 1, result 1 -> grid -> for k = 2..N: model k, result k
# Order 2 exists because some builds drop the models of an existing window when SetLayout rebuilds
# the page; the read-back after every window decides (SPEC.md ENV: the human's ok/fail is the
# evidence).
#
# RESET, HONESTLY: the delete verb IS sourced for the ACTIVE window (client RemoveAllModels,
# conrod/_tmp_hv/ppt2.tcl:179-190), but no script here proves it on a NON-active window and the
# DeleteModel fallback is a guess (src says UNVERIFIED-GUESS). A reset on an ALREADY EMPTY session
# therefore proves nothing, which is why ::pis::hw::reset_session_soft (Load All) does not stop a
# run just because the page was empty already. Every variant's src names docs/refs/, the reference
# script it came from, or UNVERIFIED-GUESS - help.altair.com could not be reached (2026-11-10).

namespace eval ::pis::hw {
    # Chosen start variant per op, kept across a re-source like the journal buffer.
    if {![info exists adapt_at]} { set adapt_at [dict create] }
    # What each step REALLY used last time: "op" or "op#<window>" -> variant number, 0 = no
    # variant worked. ::pis::hw::diag prints this; nothing else reads it.
    if {![info exists adapt_used]} { set adapt_used [dict create] }
    # Load All step order (1 or 2), also kept across a re-source.
    if {![info exists adapt_order]} { set adapt_order 1 }
    # What the last successful grid really was, for ::pis::hw::diag: the layout ID the page
    # answered ("-"). Written by ::pis::hw::make_grid ONLY after an observation agreed, so a
    # failed grid can never look like a good one in diag.
    if {![info exists adapt_grid]} { set adapt_grid "-" }
    # How many lines THIS copy of the file has (written when it is sourced, below); the BUILD
    # line prints it so "adapter lines=NNN" is measured, never typed by hand.
    if {![info exists build_lines]} { set build_lines 0 }
    # The layout IDs this session knows for a size, keyed "<cols>x<rows>" in GUI order ("4x1" =
    # 4 columns, 1 row). The VALUE is a layout ID (an integer) the page accepted, from
    # ::pis::hw::grid_token_set, the ini, or a grid that already worked. Session only.
    if {![info exists adapt_tokens]} { set adapt_tokens [dict create] }
    # The layout table measured on THIS page (::pis::hw::layout_table): layout ID -> window count
    # the page answered. Empty until something measures it; never guessed from a document.
    if {![info exists adapt_layouts]} { set adapt_layouts [dict create] }
    # The model ID '<client> AddModel' returned per window, so '<model> GetModelHandle' gets the
    # ID of the model THIS app loaded (the reference keeps AddModel's answer the same way). An
    # ARRAY on purpose: the load script writes it from inside the folded one-line script.
    if {![info exists adapt_models]} { array set adapt_models {} }
    # The ini this copy reads [layout_tokens] from ("<script dir>/../00_config/
    # pis_workflow_config.ini"), written when the file is sourced (below). "" = read no ini.
    if {![info exists ini_file]} { set ini_file "" }
}

# The build stamp: short code + yyyymmdd-hhmm, written BY HAND when this file changes (the
# adapter never derives it). The BUILD line and the GUI start line carry the FULL stamp; a DIAG
# line carries the facts only (id/api/model/result), because the stamp plus 8 windows of 1/0
# lists would not fit in the 80 characters a diag line is allowed.
namespace eval ::pis {
    variable BUILD "T6i-20261111-1420"
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

# Models in every window of the active page - the reset check. A window that answers NO model
# list is a CHART window (client type Plot, conrod/_tmp_hv/training.tcl:9,20): it cannot hold a
# model, so it counts as 0 models here and does not fail the delete step - the GRID read-back
# is where such a window is an error, because that is the step that promises HyperView windows.
# GetClientType is used by no script on this machine, so the type is never read by name.
proc ::pis::hw::check_models_on_page {} {
    set s {set @p@NW [@p@Page GetNumberOfWindows]
if {![string is integer -strict $@p@NW]} {set @p@NW [llength $@p@NW]}
set @p@Sum 0
for {set @p@Wi 1} {$@p@Wi <= $@p@NW} {incr @p@Wi} {catch {@p@Page GetWindowHandle @p@Win $@p@Wi}; catch {@p@Win GetClientHandle @p@C}; if {![catch {@p@C GetModelList} @p@Ml]} {incr @p@Sum [llength $@p@Ml]}; catch {@p@C ReleaseHandle}; catch {@p@Win ReleaseHandle}}}
    return "[::pis::hw::stack_open psi]\n[string map [list @p@ psi] $s]\n[::pis::hw::page_close psi]\nset psiSum"
}

# GONE ON PURPOSE (pass 7 / pass 8): grid_token, legacy_token, sweep_tokens, sweep_script,
# grid_sweep and sweep_table had no reader left once the layout became an integer id; a dead proc
# is a lie about what this file can do.

# --- the layout ID this build really uses (integer only - owner fact F1) -----------------
# The key is "<cols>x<rows>" in GUI order ("4x1" = 4 columns, 1 row), because that is what the
# owner types; the VALUE is a layout ID (a positive integer), because F1 measured that this build
# reads only the leading integer of '<page> SetLayout'.
proc ::pis::hw::token_key {cols rows} {
    return [format %dx%d $cols $rows]
}

# --- the layout ID this build really uses (integer only - owner fact F1) -----------------
# The key is "<cols>x<rows>" in GUI order ("4x1" = 4 columns, 1 row), because that is what the
# owner types; the VALUE is a layout ID: a positive INTEGER, because F1 measured that this build
# reads only the leading integer of '<page> SetLayout'. A string value (a "CxR" token, a legacy
# word) is dropped with no error, exactly like an empty one: it cannot work.
# The config layer owns the ini grammar whenever it is loaded; the small copy below is for a
# console where this file was sourced alone (the habit on the HyperView machine), so a cached id
# works there too. Never throws: no ini, an unreadable ini or a bad line just means "no id", and
# make_grid then measures the page with ::pis::hw::layout_table.
proc ::pis::hw::ini_tokens {} {
    variable ini_file
    if {[string trim $ini_file] eq ""} { return [dict create] }
    if {[llength [info commands ::pis::common::read_layout_tokens]] > 0} {
        return [::pis::common::read_layout_tokens $ini_file]
    }
    if {[catch {open $ini_file r} fh]} { return [dict create] }
    set text ""
    if {[catch {set text [read $fh]}]} {
        catch {close $fh}
        return [dict create]
    }
    close $fh
    set out [dict create]
    set cur ""
    foreach line [split $text "\n"] {
        set t [string trim [string trimright $line "\r"]]
        if {$t eq ""} { continue }
        set first [string index $t 0]
        if {$first eq "#" || $first eq ";"} { continue }
        if {[regexp {^\[([^\[\]]+)\]$} $t -> name]} {
            set cur [string tolower [string trim $name]]
            continue
        }
        if {$cur ne "layout_tokens"} { continue }
        set pos [string first "=" $t]
        if {$pos < 1} { continue }
        set k [string tolower [string trim [string range $t 0 [expr {$pos - 1}]]]]
        set v [string trim [string range $t [expr {$pos + 1}] end]]
        if {![regexp {^([0-9]+)x([0-9]+)$} $k -> c r]} { continue }
        if {$v eq "" || $c < 1 || $r < 1} { continue }
        if {![string is integer -strict $v] || $v < 1} { continue }
        dict set out $k $v
    }
    return $out
}

# The layout ID this session knows for cols x rows: this session first, then the ini. "" = none,
# and then ::pis::hw::make_grid measures the page (no guess added). Integers only.
proc ::pis::hw::grid_id {cols rows} {
    variable adapt_tokens
    set key [::pis::hw::token_key $cols $rows]
    if {[dict exists $adapt_tokens $key]} { return [dict get $adapt_tokens $key] }
    set ini [::pis::hw::ini_tokens]
    if {[dict exists $ini $key]} { return [dict get $ini $key] }
    return ""
}

# How many layout IDs this copy knows (session + ini): the BUILD line prints it, so "the ini I
# edited is not the ini this file reads" is visible in one line.
proc ::pis::hw::token_count {} {
    variable adapt_tokens
    set all [dict create]
    dict for {k v} [::pis::hw::ini_tokens] { dict set all $k $v }
    dict for {k v} $adapt_tokens { dict set all $k $v }
    return [dict size $all]
}

# Remember the layout ID for ONE grid size (this session only) and print the [layout_tokens] line
# to paste into the ini BY HAND: writing the ini from here would give the file two writers.
# Integers only - F1 measured that a non-integer argument can only be ignored by this build.
proc ::pis::hw::grid_token_set {cols rows id} {
    variable adapt_tokens
    foreach {label value} [list cols $cols rows $rows] {
        if {![string is integer -strict $value] || $value < 1} {
            error "::pis::hw::grid_token_set: $label must be a positive integer, got: '$value'"
        }
    }
    set lid [string trim $id]
    if {$lid eq ""} { error "::pis::hw::grid_token_set: empty layout id" }
    if {![string is integer -strict $lid] || $lid < 1} {
        error "::pis::hw::grid_token_set: the layout id must be a positive integer, got: '$lid'"
    }
    set key [::pis::hw::token_key $cols $rows]
    dict set adapt_tokens $key $lid
    puts [format "%s = %s" $key $lid]
    return $lid
}

# ONE line under 80 characters for a layout table measured on this page:
#   LAYOUTS 1=2 2=2 3=3 4=3 5=4 6=4
# It is cut with ".." when the table is longer than a line can hold - an id that does not fit is
# missing from the LINE but never from the dict the caller keeps.
proc ::pis::hw::layout_line {table} {
    set line "LAYOUTS"
    dict for {id api} $table {
        set add [format " %s=%s" $id $api]
        if {[string length "$line$add"] >= 78} { append line " .." ; break }
        append line $add
    }
    puts $line
    return $line
}

# Which INTEGER layout id gives how many windows on THIS page (F1: '<page> SetLayout' reads only
# the leading integer and treats it as a layout ID, so an id is the only thing worth sending).
# Measured, never guessed: 'SetLayout <n>' for n = 1..30, read api after each, stop after three
# consecutive SetLayout errors. It MOVES the page, so it is a probe and nothing is journaled; the
# table is cached for the session and returned as {id api id api ...}. Prints ONE line.
proc ::pis::hw::layout_table {} {
    variable adapt_layouts
    ::pis::hw::need_exec
    set s {set @p@Out {}
set @p@Err 0
for {set @p@N 1} {$@p@N <= 30} {incr @p@N} {
    if {[catch {@p@Page SetLayout $@p@N}]} {
        incr @p@Err
        if {$@p@Err >= 3} { break }
        continue
    }
    set @p@Err 0
    set @p@A [@p@Page GetNumberOfWindows]
    if {![string is integer -strict $@p@A]} { set @p@A [llength $@p@A] }
    lappend @p@Out $@p@N $@p@A
}
set @p@Out}
    set got ""
    set script "[::pis::hw::stack_open psi]\n[string map [list @p@ psi] $s]\n[::pis::hw::page_close psi]\nset psiOut"
    if {[catch {set got [::pis::hw::probe $script]} perr]} {
        ::pis::hw::note WARN "layout_table: the page could not be measured: [string trim $perr]"
        return [dict create]
    }
    set table [dict create]
    foreach {id api} $got {
        if {[string is integer -strict $id]} { dict set table $id $api }
    }
    set adapt_layouts $table
    ::pis::hw::layout_line $table
    return $table
}

# The layout ID make_grid must send for cols x rows. Order: (b) a cached/ini id, (c) the ids whose
# measured api is the wanted count - one: that one, several: the LOWEST one plus the Override
# line, none: the table plus the one Fix line and an error BEFORE anything is loaded. (a), "the
# page already is the grid", is make_grid's own first test and never reaches this proc.
# Returns {id how} where how is "cached" or "table".
proc ::pis::hw::choose_layout {cols rows} {
    variable adapt_layouts
    set count [expr {$cols * $rows}]
    set known [::pis::hw::grid_id $cols $rows]
    if {$known ne ""} { return [list $known cached] }
    if {[dict size $adapt_layouts] == 0} {
        set table [::pis::hw::layout_table]
    } else {
        set table $adapt_layouts
    }
    set hits {}
    dict for {id api} $table {
        if {[string is integer -strict $api] && $api == $count} { lappend hits $id }
    }
    if {[llength $hits] == 0} {
        ::pis::hw::layout_line $table
        set msg [format "make_grid: no layout id gives %d window(s) for %dx%d (tried %d id(s))" \
            $count $cols $rows [dict size $table]]
        append msg "\nFix: choose the layout by hand in HyperView, then click Load All again"
        ::pis::hw::note ERROR [format "make_grid: no layout id gives %d window(s); see the LAYOUTS line" $count]
        ::pis::hw::status [format "Error: make_grid %dx%d: no layout id gives %d window(s)" \
            $cols $rows $count]
        error $msg
    }
    set hits [lsort -integer $hits]
    set id [lindex $hits 0]
    if {[llength $hits] > 1} {
        ::pis::hw::note WARN [format "make_grid: layout id %s chosen from %s (shape unverified)" \
            $id [join $hits ,]]
        puts [format "Override: ::pis::hw::grid_token_set %d %d %s" $cols $rows $id]
    }
    return [list $id table]
}

# Read the layout the page is IN ('<page> GetLayout' answers the INTEGER id, F1) and hand the
# owner the line that stores it. Read-only, no SetLayout, no journal: ONE line under 80 characters
# plus the ::pis::hw::grid_token_set line to paste into the ini by hand.
proc ::pis::hw::grid_capture {} {
    ::pis::hw::need_exec
    set ob [::pis::hw::observe_dict]
    set wins [dict get $ob api]
    set lay [dict get $ob layout]
    if {![string is integer -strict $wins]} {
        error "::pis::hw::grid_capture: the page could not be read (is the hwi wrapper available?)"
    }
    set line [format "GRID: id=%s wins=%s" $lay $wins]
    while {[string length $line] >= 80} { set line "[string range $line 0 76].." }
    puts $line
    puts [format "::pis::hw::grid_token_set <cols> <rows> %s" [::pis::hw::quote $lay]]
    return $lay
}

# --- what the page REALLY shows: api, handles, clients (owner fail, 2026-11-11, pass 7) ------
# The owner's build answered GetNumberOfWindows with 4 while HyperView showed THREE windows, so
# the reported count is one fact out of three. This script asks all three and is the ONLY window
# counter in this file: index 1..api is asked for a window handle (NEVER above api - F2 says such
# a probe succeeds and proves nothing), and every window that answers is asked for a client
# handle. api==handles==clients is therefore the only shape a grid this file may accept can have,
# and a phantom window (api > handles) is caught as loudly as a missing one.
proc ::pis::hw::observe_script {} {
    set s {set @p@A [@p@Page GetNumberOfWindows]
if {![string is integer -strict $@p@A]} {set @p@A [llength $@p@A]}
set @p@H 0
set @p@Ct 0
for {set @p@I 1} {$@p@I <= $@p@A} {incr @p@I} {
    if {![catch {@p@Page GetWindowHandle @p@Win $@p@I}]} {
        incr @p@H
        if {![catch {@p@Win GetClientHandle @p@C}]} {incr @p@Ct}
        catch {@p@C ReleaseHandle}
        catch {@p@Win ReleaseHandle}
    }
}
set @p@L -
if {![catch {set @p@L [@p@Page GetLayout]}]} {
    set @p@L [string trim $@p@L]
    if {$@p@L eq ""} {set @p@L -}
}
set @p@Out [list $@p@A $@p@H $@p@Ct $@p@L]}
    return "[::pis::hw::stack_open psi]\n[string map [list @p@ psi] $s]\n[::pis::hw::page_close psi]\nset psiOut"
}

# The same observation WITHOUT printing: {api handles clients layout line}, "-" everywhere when
# the session cannot be asked (no wrapper, no HyperView, a probe that raised), so a caller always
# has a value and never a made-up count.
proc ::pis::hw::observe_dict {} {
    set out [dict create api - handles - clients - layout - \
        line "OBS: api=- handles=- clients=- layout=-"]
    if {[llength [info commands ::pis::hw::probe]] == 0 || \
            [llength [info commands ::pis::hw::exec_hwi]] == 0} {
        return $out
    }
    if {[catch {set got [string trim [::pis::hw::probe [::pis::hw::observe_script]]]}]} { return $out }
    if {[llength $got] != 4} { return $out }
    lassign $got api handles clients lay
    set line [format "OBS: api=%s handles=%s clients=%s layout=%s" $api $handles $clients $lay]
    while {[string length $line] >= 80} { set line "[string range $line 0 76].." }
    return [dict create api $api handles $handles clients $clients layout $lay line $line]
}

# ONE line under 80 characters, printed: the only window count this file reports.
proc ::pis::hw::observe {} {
    set ob [::pis::hw::observe_dict]
    puts [dict get $ob line]
    return $ob
}

# Does one observation describe EXACTLY <count> real HyperView windows? api must equal handles (a
# phantom window is not a window) and clients (a window without a client cannot hold a model).
proc ::pis::hw::observe_ok {ob count} {
    foreach k {api handles clients} {
        if {![string is integer -strict [dict get $ob $k]]} { return 0 }
        if {[dict get $ob $k] != $count} { return 0 }
    }
    return 1
}

# Is the page ALREADY the asked grid? The three numbers above PLUS the client-kind question every
# grid step must pass, so a page of chart windows is never kept just because it counts right.
proc ::pis::hw::grid_ready {count} {
    if {[llength [info commands ::pis::hw::probe]] == 0} { return 0 }
    set got ""
    if {[catch {set got [string trim [::pis::hw::probe [::pis::hw::check_grid $count]]]}]} { return 0 }
    return [expr {$got eq $count}]
}

# The one grid read-back every grid step is judged by, as a probe script, and the ONLY place the
# grid rule lives: for k = 1..api the page must answer a window handle AND a client handle, and
# that client must answer GetModelList (a chart window - client type Plot,
# conrod/_tmp_hv/training.tcl:9,20 - answers a client handle too). There is no separate
# "handles == api" / "clients == api" rule and no probe above api (owner fact F2: such a probe
# succeeds and proves nothing): the two counters only say how many of the api windows answered,
# and they are printed because a page that SAYS 4 while only 3 open can only be described by
# numbers. Answers <count> on success and RAISES otherwise:
#   grid: api=4 handles=3 clients=3 wanted=4 (window 4 did not answer)
proc ::pis::hw::check_grid {count} {
    set s {set @p@A [@p@Page GetNumberOfWindows]
if {![string is integer -strict $@p@A]} {set @p@A [llength $@p@A]}
set @p@H 0
set @p@Ct 0
set @p@Bad 0
for {set @p@I 1} {$@p@I <= $@p@A} {incr @p@I} {
    if {[catch {@p@Page GetWindowHandle @p@Win $@p@I}]} {
        if {!$@p@Bad} { set @p@Bad $@p@I }
        continue
    }
    incr @p@H
    if {[catch {@p@Win GetClientHandle @p@C}]} {
        if {!$@p@Bad} { set @p@Bad $@p@I }
        catch {@p@Win ReleaseHandle}
        continue
    }
    incr @p@Ct
    if {[catch {@p@C GetModelList}]} {
        catch {@p@C ReleaseHandle}
        catch {@p@Win ReleaseHandle}
        error "make_grid: window $@p@I is not a HyperView window (client type plot)"
    }
    catch {@p@C ReleaseHandle}
    catch {@p@Win ReleaseHandle}
}
if {$@p@A != @p@Want || $@p@H != $@p@A || $@p@Ct != $@p@A} {
    if {$@p@Bad} {
        error "grid: api=$@p@A handles=$@p@H clients=$@p@Ct wanted=@p@Want (window $@p@Bad did not answer)"
    }
    error "grid: api=$@p@A handles=$@p@H clients=$@p@Ct wanted=@p@Want"
}
set @p@Got @p@Want}
    set s [string map [list @p@Want $count] $s]
    return "[::pis::hw::stack_open psi]\n[string map [list @p@ psi] $s]\n[::pis::hw::page_close psi]\nset psiGot"
}

# Read-only: how many models window <index> really holds. Load All asks this before attaching a
# result, because a result can only attach to a model that is THERE (owner report 2, "results do
# not load": '<model> SetResult' on a window with no model changes nothing and says nothing,
# conrod/tcl_guide/hv_model_loader.tcl:1362-1400). Raises when the window cannot be opened, so the
# caller reports HyperView's own words.
proc ::pis::hw::models_in_window {index} {
    ::pis::hw::need_exec
    if {![string is integer -strict $index] || $index < 1} {
        error "::pis::hw::models_in_window: window index must be a positive integer, got: '$index'"
    }
    set got [string trim [::pis::hw::probe [::pis::hw::check_models_in_window $index]]]
    if {![string is integer -strict $got]} {
        error "window $index: the model list did not answer a count (got '$got')"
    }
    return $got
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
# One window, read back in ONE probe: "<models>:<resultCtrl>". "1:1" is the only ready
# answer - exactly one model AND a result controller that really exists (GetResultCtrlHandle
# raises on a model without a result, and that error is caught here so the answer stays a
# value). This is the per-window gate Load All uses after loading window k.
proc ::pis::hw::check_window_ready {win} {
    set s {set @p@N [llength [@p@C GetModelList]]
set @p@Ctrl 0
if {$@p@N == 1} {
    set @p@Mid [@p@C GetActiveModel]
    @p@C GetModelHandle @p@M $@p@Mid
    if {![catch {@p@M GetResultCtrlHandle @p@R}]} {
        catch {@p@R ReleaseHandle}
        set @p@Ctrl 1
    }
    catch {@p@M ReleaseHandle}
}
set @p@Ready "$@p@N:$@p@Ctrl"}
    return "[::pis::hw::window_open psi $win]\n[string map [list @p@ psi] $s]\n[::pis::hw::window_close psi]\nset psiReady"
}

# The client letter of every window of the active page, asked with the same question the grid
# check uses: H = a HyperView client (it answered GetModelList), P = a chart client (it did
# not), ? = the window or its client could not be opened at all. Comma list, window 1 first.
# GetClientType is in NO script on this machine, so this is an INFERENCE from behaviour, not a
# type string - ::pis::hw::diag prints it as client=H,H,.. so one chart window among HyperView
# ones is visible in the single line the human copies back.
proc ::pis::hw::check_clients {} {
    set s {set @p@N [@p@Page GetNumberOfWindows]
if {![string is integer -strict $@p@N]} {set @p@N [llength $@p@N]}
set @p@Out {}
for {set @p@I 1} {$@p@I <= $@p@N} {incr @p@I} {
    set @p@T ?
    if {![catch {@p@Page GetWindowHandle @p@Win $@p@I}]} {
        if {![catch {@p@Win GetClientHandle @p@C}]} {
            if {![catch {@p@C GetModelList}]} {set @p@T H} else {set @p@T P}
            catch {@p@C ReleaseHandle}
        }
        catch {@p@Win ReleaseHandle}
    }
    lappend @p@Out $@p@T
}
set @p@Out}
    return "[::pis::hw::stack_open psi]\n[string map [list @p@ psi] $s]\n[::pis::hw::page_close psi]\nset psiOut"
}

# "H,H,P" for the windows of the active page, or "" when the session cannot be asked (no
# wrapper, no HyperView, a probe that raised). Never raises: ::pis::hw::diag must always print
# its one line, even after a failed step.
proc ::pis::hw::clients {} {
    if {[llength [info commands ::pis::hw::exec_hwi]] == 0 || \
            [llength [info commands ::pis::hw::probe]] == 0} {
        return ""
    }
    if {[catch {::pis::hw::probe [::pis::hw::check_clients]} got]} { return "" }
    return [string trim $got]
}

# --- what the active page IS, read-only -----------------------------------------------
# The probe behind ::pis::hw::page_info: the active page's index, how many pages the project
# has, the layout token the page is IN ('<page> GetLayout', batchImportOdb.tcl:105), how many
# windows it reports, and WHICH window numbers really answer a window handle. That last list is
# what tells a 0-based window numbering apart from a 1-based one, and "layout=" is what tells a
# token that was ignored apart from a page that really has that many windows.
# 'GetNumberOfPages' is only in the vocabulary list of the reference loader (hv_model_loader.tcl:
# 74) and is never called there, so it is caught: "?" means this build does not answer it.
proc ::pis::hw::check_page_info {} {
    set s {set @p@PgI [@p@P GetActivePage]
set @p@Pages ?
catch {set @p@Pages [@p@P GetNumberOfPages]}
set @p@Lay ?
if {![catch {set @p@Lay [@p@Page GetLayout]}]} {
    set @p@Lay [string trim $@p@Lay]
    if {$@p@Lay eq ""} {set @p@Lay -}
}
set @p@W [@p@Page GetNumberOfWindows]
if {![string is integer -strict $@p@W]} {set @p@W [llength $@p@W]}
set @p@Open {}
for {set @p@I 1} {$@p@I <= $@p@W} {incr @p@I} {
    if {![catch {@p@Page GetWindowHandle @p@Win $@p@I}]} {
        lappend @p@Open $@p@I
        catch {@p@Win ReleaseHandle}
    }
}
set @p@Op [join $@p@Open ,]
if {$@p@Op eq ""} {set @p@Op -}
set @p@Out "page=$@p@PgI pages=$@p@Pages layout='$@p@Lay' wins=$@p@W open=$@p@Op"}
    return "[::pis::hw::stack_open psi]\n[string map [list @p@ psi] $s]\n[::pis::hw::page_close psi]\nset psiOut"
}

# ONE line the human can paste back when a grid does not appear: what the page is right now.
# Read-only - it changes nothing at all - and it never raises, so it also prints its line after
# a failed Load All. "" when the session cannot be asked (no wrapper / no HyperView).
proc ::pis::hw::page_info {} {
    if {[llength [info commands ::pis::hw::exec_hwi]] == 0 || \
            [llength [info commands ::pis::hw::probe]] == 0} {
        return ""
    }
    if {[catch {::pis::hw::probe [::pis::hw::check_page_info]} got]} { return "" }
    set line [string trim $got]
    if {$line ne ""} { puts "PAGE $line" }
    return $line
}

# --- the variant table ----------------------------------------------------------------
# One grid step's tail, spelled once: after SetLayout, give every window a window handle AND a
# client handle (batchImportOdb.tcl:126-134, "add the pane controls"). %count is filled by
# ::pis::hw::fill. Every call is caught on purpose: the walk must not be the judge, the read-back
# (::pis::hw::check_grid) is.
proc ::pis::hw::grid_walk {} {
    return {
for {set pisWi 1} {$pisWi <= %count} {incr pisWi} {catch {pisPage GetWindowHandle pisWin $pisWi}; catch {pisWin GetClientHandle pisC}; catch {pisC ReleaseHandle}; catch {pisWin ReleaseHandle}}
}
}


# op -> ordered list of variant dicts, fields:
#   n     1..N in trial order (start variant = 1 unless ::pis::hw::use moved it)
#   via   hwi = one handle script through exec_hwi; hwc = one command through exec
#   cmd   the script; %tokens are filled by ::pis::hw::fill
#   check read-only script run afterwards through ::pis::hw::probe ("" = no read-back)
#   want  what check must answer, as text ("" = nothing to compare)
#   src   where the form comes from; note = what a working variant proves
proc ::pis::hw::table {} {
    # Body pieces kept as braced literals: no backslash escaping, one command per line.
    # --- reset bodies ------------------------------------------------------------------
    # reset_remove: the SOURCED verb. conrod/_tmp_hv/ppt2.tcl:179-190 does exactly this on
    # the active window (OpenStack -> project -> page [GetActivePage] -> window
    # [GetActiveWindow] -> client -> client RemoveAllModels -> AddModel -> Draw), so
    # RemoveAllModels is a real client method on this build; walking every window of the
    # active page is this adapter's extension and the read-back is what judges it.
    set reset_remove {
set pisNW [pisPage GetNumberOfWindows]
for {set pisWi 1} {$pisWi <= $pisNW} {incr pisWi} {pisPage GetWindowHandle pisWin $pisWi; pisWin GetClientHandle pisC; pisC RemoveAllModels; catch {pisC ReleaseHandle}; catch {pisWin ReleaseHandle}}
}
    # reset_page / reset_all: the fallback walk. The walk is sourced
    # (conrod/_tmp_hv/batchImportOdb.tcl:79-88); the DeleteModel verb is NOT.
    set reset_page {
set pisNW [pisPage GetNumberOfWindows]
for {set pisWi 1} {$pisWi <= $pisNW} {incr pisWi} {pisPage GetWindowHandle pisWin $pisWi; pisWin GetClientHandle pisC; foreach pisMi [pisC GetModelList] {if {[string is integer -strict $pisMi] && $pisMi > 0} {pisC DeleteModel $pisMi}}; catch {pisC ReleaseHandle}; catch {pisWin ReleaseHandle}}
}
    set reset_all {
set pisNP [pisP GetNumberOfPages]
for {set pisPi 1} {$pisPi <= $pisNP} {incr pisPi} {pisP GetPageHandle pisPage $pisPi; set pisNW [pisPage GetNumberOfWindows]; for {set pisWi 1} {$pisWi <= $pisNW} {incr pisWi} {pisPage GetWindowHandle pisWin $pisWi; pisWin GetClientHandle pisC; foreach pisMi [pisC GetModelList] {if {[string is integer -strict $pisMi] && $pisMi > 0} {pisC DeleteModel $pisMi}}; catch {pisC ReleaseHandle}; catch {pisWin ReleaseHandle}}; catch {pisPage ReleaseHandle}}
}
    # The result step of the working reference (F3, conrod/_tmp_hv/training.tcl:41-43): the model
    # handle is opened with the ID of the model in THIS window - the ID AddModel returned when
    # this session recorded one (::pis::hw::adapt_models), otherwise the client's active model
    # (:55, TCL_StressExport.tcl:22) - then SetResult, then 'client WaitForResults' (owner fact
    # F3: the reference waits before it reads anything back), then the result is read back.
    set result_set {
set pisMid [pisC GetActiveModel]
if {[info exists ::pis::hw::adapt_models(%index)]} {set pisMid $::pis::hw::adapt_models(%index)}
pisC GetModelHandle pisM $pisMid
pisM SetResult %path
pisC WaitForResults
catch {pisM ReleaseHandle}}

    set t [dict create]
    dict set t reset_session [list \
        [dict create n 1 via hwi \
            cmd "[::pis::hw::stack_open pis]\n$reset_remove\n[::pis::hw::page_close pis]" \
            check [::pis::hw::check_models_on_page] want 0 \
            src {conrod/_tmp_hv/ppt2.tcl:179-190 (client RemoveAllModels) + conrod/_tmp_hv/batchImportOdb.tcl:83-87 (windows 1..N walk)} \
            note {every window of the active page holds 0 models - read back, not assumed. The verb is proven on the ACTIVE window only}] \
        [dict create n 2 via hwi \
            cmd "[::pis::hw::stack_open pis]\n$reset_page\n[::pis::hw::page_close pis]" \
            check [::pis::hw::check_models_on_page] want 0 \
            src {conrod/_tmp_hv/batchImportOdb.tcl:83-87 (page/window walk) + UNVERIFIED-GUESS: client DeleteModel <id>} \
            note {one DeleteModel per model id - the WALK is sourced, the DeleteModel verb is UNVERIFIED-GUESS}] \
        [dict create n 3 via hwi \
            cmd "[::pis::hw::stack_open pis]\n$reset_all\n[::pis::hw::page_close pis]" \
            check [::pis::hw::check_models_on_page] want 0 \
            src {UNVERIFIED-GUESS: client DeleteModel <id> on pages 1..N (walk from conrod/_tmp_hv/batchImportOdb.tcl:79-88)} \
            note {variant 2 applied to every page, not just the active one}] \
        [dict create n 4 via hwi \
            cmd "[::pis::hw::stack_open pis]\nset pisR \[pisS New\]\n[::pis::hw::page_close pis]" \
            check [::pis::hw::check_models_on_page] want 0 \
            src {UNVERIFIED-GUESS: <session> New = File > New} \
            note {the File > New equivalent: no model on the active page left}]]
    # -- load_model: ONE model into ONE window. Every variant opens window %win, so k > 1
    # (::pis::hw::load_model_in_window) uses the same list as k = 1. Variant 1 keeps the ID
    # AddModel RETURNS (conrod/_tmp_hv/training.tcl:36 'set modid [cln$t AddModel ...]',
    # conrod/tcl_guide/hv_model_loader.tcl:1333-1334), so the result step can open the handle of
    # the very model this app loaded instead of guessing it.
    dict set t load_model [list \
        [dict create n 1 via hwi \
            cmd "[::pis::hw::window_open pis %win]\nset pisMid \[pisC AddModel %path\]\nset ::pis::hw::adapt_models(%win) \$pisMid\npisC Draw\n[::pis::hw::window_close pis]" \
            check [::pis::hw::check_models_in_window %win] want 1 \
            src {conrod/_tmp_hv/training.tcl:36,40-43 (AddModel returns the id, SetResult, Draw) + conrod/tcl_guide/hv_model_loader.tcl:1333-1334} \
            note {window %win holds exactly one model, and its id is kept for the result step}] \
        [dict create n 2 via hwi \
            cmd "[::pis::hw::stack_open pis]\npisPage GetWindowHandle pisWin %win\npisWin GetClientHandle pisC\npisC AddModel %path\npisWin Draw\n[::pis::hw::window_close pis]" \
            check [::pis::hw::check_models_in_window %win] want 1 \
            src {conrod/tcl_guide/hv_model_loader.tcl (alternate Draw owner) + guess: Draw on the window} \
            note {same model, drawn by the window instead of the client}]]
    # --- grid bodies ------------------------------------------------------------------
    # THE LAYOUT IS AN INTEGER ID (owner fact F1): '<page> SetLayout <id>' is the only form this
    # build understands, and %id is the id make_grid resolved (cached/ini, or measured by
    # ::pis::hw::layout_table). THE WALK is sourced: batchImportOdb.tcl:126-134 applies the layout
    # and then gets a window handle AND a client handle for every window ("add the pane controls").
    # NO VARIANT SETS A CLIENT TYPE: '<win> SetClientType Plot' exists in exactly one script here
    # (conrod/_tmp_hv/training.tcl:9,20) and makes a window a CURVE CHART - the defect the owner
    # reported. Every call in the walk is caught on purpose: the walk must not be the judge, the
    # read-back (check_grid) is, and its message carries the three numbers the page answered.
    set grid_walk [::pis::hw::grid_walk]
    dict set t make_grid [list \
        [dict create n 1 via hwi \
            cmd "[::pis::hw::stack_open pis]\npisPage SetLayout %id\n$grid_walk\n[::pis::hw::page_close pis]" \
            check [::pis::hw::check_grid %count] want %count \
            src {conrod/_tmp_hv/batchImportOdb.tcl:105,126 (GetLayout / SetLayout) + owner fact F1 2026-11-11 (SetLayout reads a layout ID)} \
            note {%count windows, every one a HYPERVIEW client (no SetClientType: training.tcl:9,20 would make a chart); id measured by layout_table}]]
    dict set t load_result_in_window [list \
        [dict create n 1 via hwi \
            cmd "[::pis::hw::window_open pis %index]\n$result_set\n[::pis::hw::window_close pis]" \
            check [::pis::hw::check_result_attached %index] want 1 \
            src {conrod/_tmp_hv/training.tcl:41-43 (GetModelHandle, SetResult, Draw) + owner fact F3 (client WaitForResults)} \
            note {window %index keeps one model and gains a result controller after WaitForResults}]]
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

# A comment-ONLY journal line. A replay must know that the grid was NOT built by this file
# ("set the same layout by hand"), and a fake hwi line would claim the journal can rebuild it.
# ::pis::journal has no comment-only entry (its add takes a command too) and _tcl_pis_10_hw.tcl
# is outside this task's writable files, so the buffer is appended here: the shape stays
# "# <text>", which is exactly what ::pis::journal::filter keeps.
proc ::pis::hw::journal_note {text} {
    set line "# [string trim $text]"
    if {$line eq "#"} { return }
    if {![info exists ::pis::journal::buf]} { return }
    lappend ::pis::journal::buf $line
    if {[info exists ::pis::journal::dirty]} { set ::pis::journal::dirty 1 }
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

# Which Load All sequence the module must follow: 1 (default) or 2. "order" is not a
# HyperView operation - it is the ORDER of the six operations - so it is not in the variant
# table and ::pis::hw::ops never lists it; ::pis::hw::use order <n> picks it.
proc ::pis::hw::order {} {
    variable adapt_order
    return $adapt_order
}

proc ::pis::hw::orders {} {
    return 2
}

proc ::pis::hw::set_order {n} {
    variable adapt_order
    if {![string is integer -strict $n] || $n < 1 || $n > [::pis::hw::orders]} {
        error [format "::pis::hw::use: order has 1..%d values, got: '%s'" \
            [::pis::hw::orders] $n]
    }
    set adapt_order $n
    if {$n == 2} {
        set what "window 1 first, then the grid, then windows 2..N"
    } else {
        set what "the grid first, then every window 1..N"
    }
    ::pis::hw::note INFO [format "adapter order: %d/%d <%s>" $n [::pis::hw::orders] $what]
    ::pis::hw::status [format "HV order: %d/%d" $n [::pis::hw::orders]]
    return $n
}

# Pick the variant to start with, from one short console line: ::pis::hw::use make_grid 2
# Only this changes the order (SPEC ENV: the human's ok/fail is the evidence), and the line
# is logged + shown in the status bar, so the choice is never silent.
# "::pis::hw::use order 2" picks the Load All step order instead (see ::pis::hw::order).
proc ::pis::hw::use {op n} {
    variable adapt_at
    if {$op eq "order"} {
        return [::pis::hw::set_order $n]
    }
    set v [::pis::hw::variant_of $op $n]
    set total [llength [::pis::hw::variants $op]]
    dict set adapt_at $op $n
    ::pis::hw::note INFO [format "adapter %s: variant %d/%d <%s> (%s)" \
        $op $n $total [::pis::hw::one_line [dict get $v cmd]] [dict get $v src]]
    ::pis::hw::status [format "HV %s: variant %d/%d" $op $n $total]
    return $n
}

# " window 2" when the values carry a window number, "" otherwise. The log, the status bar
# and the error of a per-window step all name the window, so a failure of window k can never
# be misread as a failure of window 1.
proc ::pis::hw::window_scope {values} {
    foreach tok {%win %index} {
        if {[dict exists $values $tok]} {
            return [format " window %s" [dict get $values $tok]]
        }
    }
    return ""
}

# The key ::pis::hw::diag reads a step back with: "load_model#2" for window 2, "make_grid"
# for the whole-session steps. Two windows of the same op must never overwrite each other.
proc ::pis::hw::used_key {op values} {
    foreach tok {%win %index} {
        if {[dict exists $values $tok]} { return "$op#[dict get $values $tok]" }
    }
    return $op
}

# Remember the variant a step really used (0 = none worked), for ::pis::hw::diag.
proc ::pis::hw::record {key n} {
    variable adapt_used
    dict set adapt_used $key $n
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
    return [::pis::hw::run_list $op [::pis::hw::variants $op] [::pis::hw::at $op] $values]
}

# The body of ::pis::hw::run with the variant list and the first number given by the caller.
# ::pis::hw::make_grid passes the ONE form (its %id was resolved by choose_layout) while every
# other op keeps its table order. `start` is clamped to the list, so a number kept from a run that
# had more forms can never skip every variant.
proc ::pis::hw::run_list {op list start values} {
    ::pis::hw::need_exec
    set total [llength $list]
    if {![string is integer -strict $start] || $start < 1 || $start > $total} { set start 1 }
    set key [::pis::hw::used_key $op $values]
    set scope [::pis::hw::window_scope $values]
    set tried {}
    set lasterr ""
    set firsterr ""
    set n $start
    while {$n <= $total} {
        set v [lindex $list [expr {$n - 1}]]
        set cmd [::pis::hw::fill [dict get $v cmd] $values]
        set src [dict get $v src]
        set via hwi
        if {[dict exists $v via]} { set via [dict get $v via] }
        ::pis::hw::note INFO [format "%s%s: variant %d/%d <%s> (%s)" \
            $op $scope $n $total [::pis::hw::one_line $cmd] $src]
        ::pis::hw::status [format "HV %s%s: variant %d/%d" $op $scope $n $total]
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
            ::pis::hw::record $key $n
            set tail [expr {$confirmed ? " and confirmed by the read-back" : " (no read-back exists)"}]
            if {$n == $start} {
                ::pis::hw::note OK [format "%s%s: variant %d/%d used%s (%s)" \
                    $op $scope $n $total $tail $src]
            } else {
                ::pis::hw::note OK [format \
                    "%s%s: variant %d/%d used%s (%s); keep it with: ::pis::hw::use %s %d" \
                    $op $scope $n $total $tail $src $op $n]
            }
            return $res
        }
        lappend tried [format "%d/%d failed" $n $total]
        if {$why ne ""} {
            set lasterr $why
        } else {
            set lasterr [string trim $res]
        }
        if {$firsterr eq ""} { set firsterr $lasterr }
        ::pis::hw::note WARN [format "%s%s: variant %d/%d failed (%s); trying the next one" \
            $op $scope $n $total $lasterr]
        incr n
    }
    # No variant worked. The message names the step, the window (when there is one), the
    # variant it stopped at and every variant that was tried, so the human can move the start
    # variant with one console line - and ::pis::hw::diag shows the 0 this step recorded.
    ::pis::hw::record $key 0
    # The status bar says the same in one short line: which step, which window, and that NO
    # variant worked. The full message (with every variant tried and the read-back that
    # refused it) stays in the log line above, so a failing window k is visible in both places.
    ::pis::hw::status [format "Error: %s%s - no variant worked (%d/%d)" $op $scope $total $total]
    set detail $firsterr
    if {$detail eq ""} { set detail $lasterr }
    # A CHART window is not a variant problem: no variant can turn it back into a HyperView
    # window (no script on this machine does that - see the CLIENT TYPE note at the top), so
    # the message names the only thing that works instead of sending the human through the
    # variant table.
    if {[string first "is not a HyperView window" $detail] >= 0} {
        append detail " - File > New gives a session with HyperView windows"
    }
    if {[llength $tried] > 1} {
        append detail [format " (tried %s)" [join $tried {, }]]
    }
    error [format \
        "%s%s variant %d/%d failed: %s | pick another variant with: ::pis::hw::use %s <n>" \
        $op $scope $total $total $detail $op]
}
# --- the six operations (the only names the modules may call) --------------------------
# Each one validates its arguments first (one clear message naming the offending value),
# then hands the values to ::pis::hw::run, which owns the variant list, the read-back and
# the log. Values are quoted by ::pis::hw::fill, so a path with spaces stays one argument.

proc ::pis::hw::reset_session {} {
    return [::pis::hw::run reset_session [dict create]]
}

# Reset for Load All: the same variants, but an ALREADY EMPTY page is not a failure. On an
# empty session the check ("0 models on the page") passes without proving the delete verb -
# that is exactly the hole SPEC.md A6/ENV warns about - so this proc asks the read-back once
# more before it refuses: 0 models left means there was nothing to clear, and stopping a
# whole Load All over that would be wrong. A page that still holds models keeps the real
# error, so a build where the delete really fails is still reported.
proc ::pis::hw::reset_session_soft {} {
    if {![catch {::pis::hw::run reset_session [dict create]} res]} { return $res }
    set why [string trim $res]
    set failed [catch {::pis::hw::probe [::pis::hw::check_models_on_page]} got]
    if {!$failed && [string trim $got] eq "0"} {
        ::pis::hw::note WARN \
            "reset_session: no variant proved the delete, but the page already holds 0 models; Load All continues (the delete verb is UNVERIFIED for a window that is not active)"
        return 0
    }
    error $why
}

# ONE model into window k. k = 1 is ::pis::hw::load_model and nothing else: every window is
# its own client with its own model list (conrod/_tmp_hv/batchImportOdb.tcl:83-87 walks the
# windows this way, conrod/tcl_guide/hv_model_loader.tcl:1428 takes the window index as its
# first argument), so a model loaded once into window 1 never reaches window 2.
proc ::pis::hw::load_model_in_window {index path} {
    if {![string is integer -strict $index] || $index < 1} {
        error "::pis::hw::load_model_in_window: window index must be a positive integer, got: '$index'"
    }
    set p [string trim $path]
    if {$p eq ""} { error "::pis::hw::load_model_in_window: empty model path" }
    if {![file isfile $p]} {
        error "::pis::hw::load_model_in_window: model not found: $p"
    }
    return [::pis::hw::run load_model [dict create %path $p %win $index %index $index]]
}

# k = 1: the one-window case of load_model_in_window, kept because the GUI and the legend
# module call this name. Nothing else about it is special.
proc ::pis::hw::load_model {path} {
    set p [string trim $path]
    if {$p eq ""} { error "::pis::hw::load_model: empty model path" }
    if {![file isfile $p]} { error "::pis::hw::load_model: model not found: $p" }
    return [::pis::hw::load_model_in_window 1 $p]
}

# Read-back only: window k answers "1:1" (one model AND a result controller), or this proc
# says what the window really answered. Never journaled - a check is not a step.
proc ::pis::hw::verify_window {index} {
    ::pis::hw::need_exec
    if {![string is integer -strict $index] || $index < 1} {
        error "::pis::hw::verify_window: window index must be a positive integer, got: '$index'"
    }
    set got [::pis::hw::probe [::pis::hw::check_window_ready $index]]
    if {$got ne "1:1"} {
        error [format \
            "window %d is not ready: read-back answered '%s', expected '1:1' (one model and a result controller)" \
            $index $got]
    }
    return 1
}

# The variant number of every window one op ran in (::pis::hw::made_grid etc.). Used by
# ::pis::hw::diag to print model=/result= window by window: one entry per window the op ran in
# (load_model, load_result_in_window), 0 where no variant worked.
proc ::pis::hw::used_list {op} {
    variable adapt_used
    set pat [format {^%s#([0-9]+)$} $op]
    set wins {}
    foreach k [dict keys $adapt_used] {
        if {[regexp $pat $k -> wi]} { lappend wins $wi }
    }
    if {[llength $wins] == 0} { return {0} }
    set out {}
    foreach wi [lsort -integer $wins] {
        lappend out [dict get $adapt_used "$op#$wi"]
    }
    return $out
}

# The variant number one step really used: ::pis::hw::used reset_session, or
# ::pis::hw::used load_model 3 for window 3 (a step that ran in a window is recorded under
# "<op>#<window>"). 0 means no variant worked - the same 0 ::pis::hw::diag prints, so a
# helper script can report "variant 2/8" without parsing a log line.
proc ::pis::hw::used {op {index ""}} {
    variable adapt_used
    set key $op
    if {[string trim $index] ne ""} { set key "$op#[string trim $index]" }
    if {![dict exists $adapt_used $key]} { return 0 }
    return [dict get $adapt_used $key]
}

# ONE line under 80 characters: the layout id of the last good grid, how many windows the page
# ANSWERS (api, read now - never what this app asked for), 1/0 per window for model and result
# (0 = no variant worked there), and - only when the line still fits - the client letter of each
# window (H = HyperView, P = chart). This is the line the human copies back when only ok/fail is
# possible (ENV), so the shape is fixed:
#   DIAG: id=5 api=4 model=1,1,1,1 result=1,1,1,1 client=H,H,H,H
# The BUILD line carries the stamp; a whole stamp here would leave no room for 8 windows of 1/0
# lists. client= is dropped first (the 1/0 lists are the facts) and omitted entirely when the
# session cannot be asked (no wrapper, no HyperView, a probe that raised) - a made-up letter is
# worse than none.
proc ::pis::hw::diag {} {
    variable adapt_grid
    set ob [::pis::hw::observe_dict]
    set head [format "DIAG: id=%s api=%s" $adapt_grid [dict get $ob api]]
    # 1/0, not the variant number: the DIAG line answers "does window k hold a model/result?".
    set models {}
    foreach n [::pis::hw::used_list load_model] {
        lappend models [expr {$n > 0 ? 1 : 0}]
    }
    set results {}
    foreach n [::pis::hw::used_list load_result_in_window] {
        lappend results [expr {$n > 0 ? 1 : 0}]
    }
    set clients [::pis::hw::clients]
    # Did the session answer at all? (An empty answer means no wrapper / no HyperView / a probe
    # that raised: then no client letter is printed at all rather than a made-up one.)
    set have_clients [expr {[llength $clients] > 0}]
    # Both lists line up window by window: the shorter one is padded with 0 (nothing ran
    # there), so "model=1,1 result=1,0" always means the same two windows. The client list is
    # padded with ? for the same reason (a window nobody asked about yet).
    set width [llength $models]
    if {[llength $results] > $width} { set width [llength $results] }
    if {[llength $clients] > $width} { set width [llength $clients] }
    while {[llength $models] < $width} { lappend models 0 }
    while {[llength $results] < $width} { lappend results 0 }
    while {[llength $clients] < $width} { lappend clients ? }
    # The line must stay under 80 characters. The client letters go first (they are the extra
    # detail), then - only if even the bare line is too long - the OLDEST windows, with ".."
    # saying the list starts somewhere else. So the per-window 1/0 lists stay complete as long as
    # one line can hold them.
    set line ""
    set cut 0
    while {1} {
        set lead [expr {$cut > 0 ? "..," : ""}]
        set bare [format "%s model=%s%s result=%s%s" $head $lead \
            [join [lrange $models $cut end] ,] $lead [join [lrange $results $cut end] ,]]
        set full $bare
        if {$have_clients} {
            append full [format " client=%s%s" $lead [join [lrange $clients $cut end] ,]]
        }
        if {[string length $full] < 80} { set line $full ; break }
        if {[string length $bare] < 80} { set line $bare ; break }
        if {$cut >= $width} { break }
        incr cut
    }
    puts $line
    return $line
}

# Build the cols x rows window grid. The page is the judge (F1/F2):
#   (a) it ALREADY shows cols*rows real windows (every one answering a window handle, a client
#       handle and GetModelList)? Then no SetLayout runs at all - a rebuild would take a grid the
#       owner made by hand away - and the journal gets ONE comment line saying so;
#   (b) ::pis::hw::choose_layout names the id (a cached/ini id, or the id layout_table measured);
#       a failure there happens BEFORE anything is loaded, with the LAYOUTS line and the Fix line;
#   (c) exactly ONE 'SetLayout <id>' is sent through the wrapper and journaled, once. Success is
#       api == cols*rows with a window handle and a client handle for every window 1..api.
# Prints ONE GRID line per call: "GRID: id=<n> api=<a> clients=<c>".
proc ::pis::hw::make_grid {cols rows} {
    variable adapt_grid
    variable adapt_tokens
    foreach {label value} [list cols $cols rows $rows] {
        if {![string is integer -strict $value] || $value < 1} {
            error "::pis::hw::make_grid: $label must be a positive integer, got: '$value'"
        }
    }
    set count [expr {$cols * $rows}]
    ::pis::hw::need_exec
    set ob [::pis::hw::observe]
    if {[::pis::hw::observe_ok $ob $count] && [::pis::hw::grid_ready $count]} {
        ::pis::hw::note INFO [format "make_grid: grid already %d window(s), SetLayout skipped" $count]
        ::pis::hw::status [format "HV make_grid: %d window(s) already present" $count]
        ::pis::hw::journal_note [format \
            "grid %dx%d already present; replay needs the same layout set by hand" $cols $rows]
        ::pis::hw::record make_grid 0
        set adapt_grid [dict get $ob layout]
        puts [format "GRID: id=%s api=%s clients=%s" $adapt_grid \
            [dict get $ob api] [dict get $ob clients]]
        return $count
    }
    lassign [::pis::hw::choose_layout $cols $rows] id how
    set list [::pis::hw::variants make_grid]
    set values [dict create %cols $cols %rows $rows %count $count %id $id]
    if {[catch {::pis::hw::run_list make_grid $list [::pis::hw::at make_grid] $values} err]} {
        # The status bar names the SIZE as well as the step: a failed Load All must say which
        # grid it could not build, not only that a variant failed (run_list's own line is one
        # step shorter than what the human needs to act on).
        ::pis::hw::status [format "Error: make_grid %dx%d: layout id %s did not give %d window(s)" \
            $cols $rows $id $count]
        error [format "%s | asked %d window(s) with layout id %s (%s) | Fix: choose the layout by hand in HyperView, then click Load All again" \
            $err $count $id $how]
    }
    set ob [::pis::hw::observe]
    if {![::pis::hw::observe_ok $ob $count]} {
        error [format \
            "make_grid: the page changed after the step: grid: api=%s handles=%s clients=%s wanted=%d" \
            [dict get $ob api] [dict get $ob handles] [dict get $ob clients] $count]
    }
    dict set adapt_tokens [::pis::hw::token_key $cols $rows] $id
    set adapt_grid [dict get $ob layout]
    if {$adapt_grid eq "-"} { set adapt_grid $id }
    puts [format "GRID: id=%s api=%s clients=%s" $id [dict get $ob api] [dict get $ob clients]]
    ::pis::hw::status [format "HV make_grid: layout id %s, %s window(s)" $id $count]
    return $count
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
    puts [format "  Load All order %d/%d (change it: ::pis::hw::use order <n>)" \
        [::pis::hw::order] [::pis::hw::orders]]
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
    puts "  change one: ::pis::hw::use <op> <n>   e.g. ::pis::hw::use load_model 2"
    puts "  what ran last: ::pis::hw::diag   (ONE line: id= api= model= result= per window)"
    puts "  what the page has NOW: ::pis::hw::observe   (api= handles= clients= layout=, read-only)"
    puts "  what the page is now: ::pis::hw::page_info   (read-only: layout id, wins, open windows)"
    puts "  which layout id this build has: ::pis::hw::layout_table   (probe, not a step)"
    puts "    ONE LAYOUTS line, id=window count, e.g. LAYOUTS 1=2 2=2 3=3 4=3 5=4"
    puts "  pin one by hand: set the layout in HyperView, then ::pis::hw::grid_capture"
    puts "    paste the printed ::pis::hw::grid_token_set <cols> <rows> <id> line, or the ini line"
    return
}

# Every op back to its first variant, the order back to 1, nothing recorded, no cached layout id
# and no measured layout table (tests, and a fresh session).
proc ::pis::hw::reset_state {} {
    variable adapt_at
    variable adapt_used
    variable adapt_order
    variable adapt_grid
    variable adapt_tokens
    variable adapt_layouts
    variable adapt_models
    set adapt_at [dict create]
    set adapt_used [dict create]
    set adapt_order 1
    set adapt_grid "-"
    set adapt_tokens [dict create]
    set adapt_layouts [dict create]
    catch {array unset adapt_models}
    array set adapt_models {}
    return
}

# --- build stamp: ONE line, printed when this file is sourced -------------------------
# The line answers the first question on a HyperView machine ("which copy is this?"):
#   BUILD T6i-20261111-1420 | make_grid variants=1 | adapter lines=NNN | layouts=N
# The line count is measured from the file itself at source time (below), so it cannot go
# stale the way a hand-written number would. "layouts=" is how many layout ids this copy can see
# (session + the [layout_tokens] section of the ini it sits next to), so "the ini I edited is not
# the ini this file reads" shows up before the first Load All.
proc ::pis::hw::build_line {} {
    variable build_lines
    set stamp "no-stamp"
    if {[info exists ::pis::BUILD]} { set stamp $::pis::BUILD }
    set n 0
    catch { set n [llength [::pis::hw::variants make_grid]] }
    set toks 0
    catch { set toks [::pis::hw::token_count] }
    return [format "BUILD %s | make_grid variants=%d | adapter lines=%d | layouts=%d" \
        $stamp $n $build_lines $toks]
}

# Console + GUI log, exactly one line each. The console always gets it (puts); the GUI pane
# gets it through ::pis::gui::log_line when the GUI has already built its log widget - the
# GUI's own start line carries the same stamp, so a GUI started before the adapter was
# sourced still shows which build it runs.
proc ::pis::hw::announce {} {
    set line [::pis::hw::build_line]
    puts $line
    if {[llength [info commands ::pis::gui::log_line]] > 0} {
        catch {::pis::gui::log_line INFO $line}
    }
    return $line
}

# Measure this copy, then print the BUILD line. info script is the file being sourced HERE,
# so the count is of the adapter, not of whatever sourced it.
if {[catch {
    set _pis_bh [open [info script] r]
    set _pis_bt [read $_pis_bh]
    close $_pis_bh
    set ::pis::hw::build_lines [llength [split [string trimright $_pis_bt "\n"] "\n"]]
}]} {
    set ::pis::hw::build_lines 0
}
# The ini this copy reads [layout_tokens] from: the 00_config folder NEXT TO this file, so a
# copy of src/ on the HyperView machine finds its own ini and not another install's.
# info script is the file being sourced HERE, which is the only place that knows it.
if {[catch {
    set ::pis::hw::ini_file [file normalize [file join [file dirname [info script]] .. 00_config pis_workflow_config.ini]]
}]} {
    set ::pis::hw::ini_file ""
}
::pis::hw::announce
