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
#   ::pis::hw::verify_grid {cols rows}             read-back: the page has cols*rows windows, and
#                                                  EVERY one answers a client handle AND is a
#                                                  HyperView client (it answers GetModelList)
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
#   ::pis::hw::diag {}          ONE line under 80 chars: layout, grid, window count, per window
#                               the variant used and the client letter (H|P|?)
#   ::pis::hw::clients {}       per-window client letter: H = HyperView, P = chart (Plot), ? =
#                               cannot tell (INFERRED from GetModelList - no GetClientType here)
#   ::pis::hw::page_info {}     ONE read-only line: page index, layout token, window count, the
#                               window numbers that really open (what the page IS right now)
#   ::pis::hw::grid_sweep {cols rows}
#                               ask THIS page which layout token really gives cols x rows
#                               windows: ONE SWEEP line (ok=... tried=... or none/max=/last=),
#                               nothing journaled, no variant moved - a probe, not a step
#   ::pis::hw::grid_capture {}  read-only: the layout token the page is IN, as ONE GRID line
#                               plus the ::pis::hw::grid_token_set line to paste (the owner
#                               sets the layout by hand, HyperView names its own token)
#   ::pis::hw::grid_token_set {cols rows token}
#                               remember that token for this cols x rows in this session and
#                               print the [layout_tokens] line for the ini (added by hand)
#   ::pis::hw::reset_state {}   variants + order back to 1, no captured token (tests)
#   ::pis::hw::run {op values}  run an op (the six operations call this)
#   ::pis::hw::used {op {win}}  variant number that step really used (0 = none worked)
#   ::pis::hw::build_line {}    the ONE BUILD line (stamp, grid variants, line count, tokens)
#   ::pis::hw::announce {}      print that line to the console and to the GUI log
#
# BUILD STAMP (T-006 iteration, 2026-11-11): ::pis::BUILD is a short code written BY HAND
# when this file changes, e.g. T6g-20261111-1051, so the HyperView machine can be matched to
# a copy of this file without a guess. Sourcing this file prints ONE line,
#   BUILD T6g-20261111-1051 | make_grid variants=1 | adapter lines=<n> | tokens=<n>
# and every ::pis::hw::diag line starts with the same stamp (the time part only fits there).
#
# THE LAYOUT TOKEN IS MEASURED, NOT GUESSED (owner report, 2026-11-11, pass 6): on the owner's
# machine Load All with layout 2x2 and 4x1 left the page as it was, while 2x1 and 1x2 worked - so
# the token is a property of THIS BUILD, and every spelling read out of a document is a guess.
# Five passes guessed; this one asks the page:
#   1. ::pis::hw::grid_sweep applies each candidate with SetLayout and reads BOTH facts back
#      ('<page> GetNumberOfWindows' + a client handle in every window, and '<page> GetLayout',
#      conrod/_tmp_hv/batchImportOdb.tcl:105,126). The first candidate that gives the asked count
#      wins, and the sweep prints ONE line: "SWEEP 2x2: ok=2x2 tried=1", or
#      "SWEEP 2x2: none tried=5 max=2 last=2H" when nothing does (max = the most windows any
#      candidate produced, last = the layout the page answered last);
#   2. the winner is kept for this session, so the NEXT build of that size does not sweep again,
#      and make_grid prints ONE "Keep:" line naming it. An OWNER-CAPTURED token
#      (::pis::hw::grid_capture -> ::pis::hw::grid_token_set, session or [layout_tokens] ini) is
#      used before the sweep is run at all: it was read out of THIS build;
#   3. a page that ALREADY is the asked grid is never rebuilt: no SetLayout at all, ONE
#      comment-only journal line saying a replay needs the same layout set by hand (a fake hwi
#      line would claim the journal can rebuild a grid this file never built);
#   4. only a token that WON reaches the journal, so a replay cannot carry a token this build
#      ignores; a grid that fails sends nothing and prints the Fix line.
# Nothing here reads a token out of a doc, and nothing writes the ini: one ini, one writer.
#
# PER-WINDOW LOADING (fix, 2026-11-10): every window is its own client with its OWN model
# list, so loading the model once into window 1 leaves windows 2..N empty and the result of
# those windows has no model to attach to. The reference loader this file follows takes the
# window index as its FIRST argument (conrod/tcl_guide/hv_model_loader.tcl:1428
# "LoadInputs {winIdx modelPath resultPath ...}", :1483-1486 GetWindowHandle $winIdx ->
# GetClientHandle, :1497-1498 AddModel, :1526 Draw, :1527-1528 GetModelList) and the batch
# importer walks windows 1..N the same way (conrod/_tmp_hv/batchImportOdb.tcl:83-87), which
# is why ::pis::hw::load_model_in_window exists and load_model is only its k = 1 case.
#
# CLIENT TYPE - THE ESCAPED T-006 DEFECT (owner report, 2026-11-10: "sau Load All, cÃ¡c window lÃ 
# HyperGraph 2D, khÃ´ng pháº£i HyperView"). This file used to set a client type on every new
# window: '<win> SetClientType Plot', copied from conrod/_tmp_hv/training.tcl:9,20. Read that
# script's own header (:1 and :13): "å°†ç¬¬ä¸‰é¡µçš„ç¬¬ä¸‰ä¸ªçª—å£å®¢æˆ·ç«¯è®¾ç½®æˆæ›²çº¿å›¾" = "set the client of
# the 3rd window of page 3 to a CURVE CHART". It is a chart exercise, so Plot is the
# HyperGraph 2D client - the exact opposite of a window that must show a model and a contour.
# Consequences, all applied here:
#   1. NO variant sets a client type any more (the two that did are gone from make_grid).
#   2. The grid read-back REFUSES a window that cannot hold a model - a chart window answers a
#      client handle too, which is why the old check (client handle only) passed it.
#   3. Nothing guesses a way back to a HyperView window: GetClientType appears in NO script on
#      this machine and no script sets a window back, so reset only offers what is sourced
#      (<session> New, marked UNVERIFIED-GUESS) and a grid that meets a chart window says so.
# The working reference loader agrees: SetLayout, GetClientHandle, AddModel - no client type
# call anywhere (conrod/tcl_guide/hv_model_loader.tcl:1179-1180, :1329-1337, :1485-1498).
#
# TWO STEP ORDERS (variant lists never change for this; the order does):
#   order 1 (default): reset -> grid -> for k = 1..N: model k, result k
#   order 2:           reset -> model 1, result 1 -> grid -> for k = 2..N: model k, result k
# Order 2 exists because some builds drop the models of an existing window when SetLayout
# rebuilds the page; the read-back after every window decides, the human's ok/fail is the
# evidence (SPEC.md ENV).
#
# RESET, HONESTLY: the delete verb IS sourced for the ACTIVE window - client RemoveAllModels,
# read out of a working script on this machine (conrod/_tmp_hv/ppt2.tcl:179-190, line 187).
# No script here proves it on a NON-active window, and the DeleteModel fallback is a guess
# ("UNVERIFIED-GUESS" in its src). A reset that runs on an ALREADY EMPTY session therefore
# passes its check without proving anything: that is why ::pis::hw::reset_session_soft
# (used by Load All) does not stop a run just because the page was empty already.
# A variant's source is one of: docs/refs/<file section>, the local reference script it was
# copied from (conrod/..., test/test_out/...), an Altair documentation URL, or the label UNVERIFIED-GUESS (last
# in its list). No help.altair.com page could be reached on 2026-11-10 (404 / search
# challenge), so every form is either read out of a working script on this machine or marked
# as a guess.

namespace eval ::pis::hw {
    # Chosen start variant per op, kept across a re-source like the journal buffer.
    if {![info exists adapt_at]} { set adapt_at [dict create] }
    # What each step REALLY used last time: "op" or "op#<window>" -> variant number, 0 = no
    # variant worked. ::pis::hw::diag prints this; nothing else reads it.
    if {![info exists adapt_used]} { set adapt_used [dict create] }
    # Load All step order (1 or 2), also kept across a re-source.
    if {![info exists adapt_order]} { set adapt_order 1 }
    # What the last successful grid really was, for ::pis::hw::diag: the layout as the
    # "<rows>x<cols>" token the page accepted ("-") and the window count read back from
    # HyperView (0 = no grid yet). Both are written by ::pis::hw::make_grid ONLY after its
    # read-back passed, so a failed grid can never look like a good one in diag.
    if {![info exists adapt_grid]} { set adapt_grid "-" }
    if {![info exists adapt_wins]} { set adapt_wins 0 }
    # How many lines THIS copy of the file has (written when it is sourced, below); the BUILD
    # line prints it so "adapter lines=NNN" is measured, never typed by hand.
    if {![info exists build_lines]} { set build_lines 0 }
    # The layout tokens the OWNER captured from this build (::pis::hw::grid_token_set), keyed
    # "<cols>x<rows>" in GUI order ("4x1" = 4 columns, 1 row). The VALUE is HyperView's own
    # spelling, whatever it is. Session only, and never inferred from a doc.
    if {![info exists adapt_tokens]} { set adapt_tokens [dict create] }
    # The ini this copy reads [layout_tokens] from ("<script dir>/../00_config/
    # pis_workflow_config.ini"), written when the file is sourced (below). "" = read no ini.
    if {![info exists ini_file]} { set ini_file "" }
}

# The build stamp: short code + yyyymmdd-hhmm, written BY HAND when this file changes (the
# adapter never derives it). The BUILD line and the GUI start line carry the FULL stamp;
# ::pis::hw::diag carries only the code part (T6g), because the full stamp plus 8 windows of
# model=/result=/client= lists would not fit in the 80 characters a diag line is allowed.
namespace eval ::pis {
    variable BUILD "T6g-20261111-1051"
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

# The layout token this app asks for: "<rows>x<cols>" (cols 4 rows 2 -> "2x4"). That is the
# spelling and the meaning the reference loader uses: conrod/tcl_guide/hv_model_loader.tcl:
# 498-501 (PreferredLayoutToken answers "${r}x${c}") with 457-460 ("'1x2' means 1 row,
# 2 columns = side by side"). The GUI's field is cols x rows, so the token is NOT the field
# text: cols 4 rows 1 is "1x4", never "4x1".
proc ::pis::hw::grid_token {cols rows} {
    return [format %dx%d $rows $cols]
}

# The legacy word for this grid, when the reference loader's list has one for this count and
# arrangement (conrod/tcl_guide/hv_model_loader.tcl:518: single 1x1 2H 2V 3H 3V 4H 4V);
# "" otherwise, and the variant that needs it then fails with exactly that message.
proc ::pis::hw::legacy_token {cols rows} {
    set n [expr {$cols * $rows}]
    if {$n == 1} { return "single" }
    if {$n < 2 || $n > 4} { return "" }
    if {$rows == 1} { return "${n}H" }
    if {$cols == 1} { return "${n}V" }
    return ""
}

# --- the layout token this build really uses (owner-captured, never guessed) ------------
# The key is "<cols>x<rows>" in GUI order ("4x1" = 4 columns, 1 row), because that is what the
# owner types; the TOKEN keeps HyperView's own spelling, whatever it is.
proc ::pis::hw::token_key {cols rows} {
    return [format %dx%d $cols $rows]
}

# The [layout_tokens] section of the ini this copy sits next to, read-only: key -> token.
# The config layer owns the ini grammar whenever it is loaded; the small copy below is for a
# console where this file was sourced alone (the habit on the HyperView machine), so the
# captured token works there too. Never throws: no ini, an unreadable ini or a bad line just
# means "no token", and make_grid then uses its documented forms.
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
        dict set out $k $v
    }
    return $out
}

# The token the OWNER captured for cols x rows: this session first, then the ini. "" = none,
# and then ::pis::hw::make_grid uses the documented forms exactly as before - no guess added.
proc ::pis::hw::owner_token {cols rows} {
    variable adapt_tokens
    set key [::pis::hw::token_key $cols $rows]
    if {[dict exists $adapt_tokens $key]} { return [dict get $adapt_tokens $key] }
    set ini [::pis::hw::ini_tokens]
    if {[dict exists $ini $key]} { return [dict get $ini $key] }
    return ""
}

# How many captured tokens this copy knows (session + ini): the BUILD line prints it, so "the
# ini I edited is not the ini this file reads" is visible in one line.
proc ::pis::hw::token_count {} {
    variable adapt_tokens
    set all [dict create]
    dict for {k v} [::pis::hw::ini_tokens] { dict set all $k $v }
    dict for {k v} $adapt_tokens { dict set all $k $v }
    return [dict size $all]
}

# Remember the token the owner captured for ONE grid size (this session only) and print the
# [layout_tokens] line to paste into the ini BY HAND: writing the ini from here would give the
# file two writers and hide a typo in a token inside a step.
proc ::pis::hw::grid_token_set {cols rows token} {
    variable adapt_tokens
    foreach {label value} [list cols $cols rows $rows] {
        if {![string is integer -strict $value] || $value < 1} {
            error "::pis::hw::grid_token_set: $label must be a positive integer, got: '$value'"
        }
    }
    set tok [string trim $token]
    if {$tok eq ""} { error "::pis::hw::grid_token_set: empty layout token" }
    if {[regexp {[\r\n]} $tok]} {
        error "::pis::hw::grid_token_set: the layout token must be one line, got: '$tok'"
    }
    set key [::pis::hw::token_key $cols $rows]
    dict set adapt_tokens $key $tok
    puts [format "%s = %s" $key $tok]
    return $tok
}

# Read the layout the page is IN ('<page> GetLayout', batchImportOdb.tcl:105) and hand the
# owner the exact line that stores it. Read-only: no SetLayout, no journal, ONE line under 80
# characters plus the ::pis::hw::grid_token_set line. "was=<cols>x<rows>" only when the token
# spells its own shape ("1x4" = 4 columns, 1 row); a word like "2H" does not, so it prints -.
proc ::pis::hw::grid_capture {} {
    ::pis::hw::need_exec
    set st [::pis::hw::page_state]
    if {[llength $st] == 0} {
        error "::pis::hw::grid_capture: the page could not be read (is the hwi wrapper available?)"
    }
    lassign $st wins lay
    set cols ""
    set rows ""
    set was -
    if {[regexp {^([0-9]+)[ \t]*[xX][ \t]*([0-9]+)$} $lay -> r c] && $r > 0 && $c > 0} {
        set rows $r
        set cols $c
        set was [::pis::hw::token_key $cols $rows]
    }
    set line [format "GRID: wins=%s token=%s was=%s" $wins $lay $was]
    if {[string length $line] >= 80} { set line [format "GRID: wins=%s token=%s" $wins $lay] }
    while {[string length $line] >= 80} { set line "[string range $line 0 76].." }
    puts $line
    if {$cols ne ""} {
        puts [format "::pis::hw::grid_token_set %d %d %s" $cols $rows [::pis::hw::quote $lay]]
    } else {
        puts [format "::pis::hw::grid_token_set <cols> <rows> %s" [::pis::hw::quote $lay]]
    }
    return $lay
}

# The page as {wins layout}, read through the SAME read-only script ::pis::hw::page_info prints
# (probe runs it and answers the folded "page=..." line, so nothing is printed twice); ""
# when the session cannot be asked (no wrapper, no HyperView, a probe that raised). Never
# journaled and never raises, so a failure message can carry what HyperView really answered.
proc ::pis::hw::page_state {} {
    if {[llength [info commands ::pis::hw::probe]] == 0 || \
            [llength [info commands ::pis::hw::check_page_info]] == 0} {
        return ""
    }
    set got ""
    if {[catch {set got [string trim [::pis::hw::probe [::pis::hw::check_page_info]]]}]} { return "" }
    if {![regexp {layout='([^']*)' wins=([0-9]+)} $got -> lay wins]} { return "" }
    return [list $wins $lay]
}

# Is the page ALREADY the asked grid? The same read-back a grid step must pass (count AND a
# HyperView client in every window), so "already there" is never just a number: a page of chart
# windows is not a grid this file may keep.
proc ::pis::hw::grid_ready {count} {
    if {[llength [info commands ::pis::hw::probe]] == 0} { return 0 }
    set got ""
    if {[catch {set got [string trim [::pis::hw::probe [::pis::hw::check_grid $count]]]}]} { return 0 }
    return [expr {$got eq $count}]
}

# "wins=<m> layout=<token>" as the page answers it, for a failure message; "-" when the session
# cannot be asked (a made-up count would be worse than none).
proc ::pis::hw::grid_answer {} {
    set st [::pis::hw::page_state]
    if {[llength $st] == 0} { return "-" }
    return [format "wins=%s layout=%s" [lindex $st 0] [lindex $st 1]]
}

# WHY A COUNT MISMATCH ALSO NAMES THE LAYOUT TOKEN (owner's report, 2026-11-11): on the
# owner's machine EVERY variant of a 2x2 AND of a 4x4 request ended in the same answer,
# "wins=2", so the count alone could not tell "the token was ignored" from "the page really
# has 2 windows". '<page> GetLayout' answers the token the page is IN - conrod/_tmp_hv/
# batchImportOdb.tcl:105 reads the page's layout exactly that way, and conrod/tcl_guide/
# hv_model_loader.tcl:1123 reads it plus :1136 caches it - so the mismatch now carries it:
#   wins=2 layout=2H
# ("layout=-" = the page answered an empty string, "layout=?" = GetLayout itself raised.)
# That single field is the difference between a spelling problem and a page that does not change
# at all, and ::pis::hw::grid_sweep prints the same two facts for every candidate token.
#
# The grid read-back, three questions per window k, in this order:
#   (a) does the page really have <count> windows,
#   (b) does window k answer a window handle AND a client handle, and
#   (c) is that client a HYPERVIEW client - can it hold a model at all?
# (c) is the gate for the T-006 escaped defect. The old check stopped at (b), and a chart window
# (client type Plot, conrod/_tmp_hv/training.tcl:9,20) answers a client handle too - so a whole
# grid of HyperGraph 2D windows passed and the model then "loaded" nowhere. GetClientType is used
# by no script on this machine, so the type is NOT read back by name: 'client GetModelList' is
# what every HyperView window here answers (conrod/_tmp_hv/batchImportOdb.tcl:111,
# conrod/tcl_guide/hv_model_loader.tcl:1497-1498 with :1527-1528) and a chart client raises
# instead. The error names the window and the type it acts like:
#   make_grid: window 3 is not a HyperView window (client type plot)
# GetNumberOfWindows answers either the count ("8") or the list of window numbers
# ("1 2 3 4 5 6 7 8"), so it is normalised first - conrod/tcl_guide/hv_model_loader.tcl:
# 540-544 does the same. A window that cannot be opened RAISES with its own number, so the
# failure names k instead of only a wrong total.
proc ::pis::hw::check_grid {count} {
    set s {set @p@W [@p@Page GetNumberOfWindows]
if {![string is integer -strict $@p@W]} {set @p@W [llength $@p@W]}
set @p@Lay ?
if {![catch {set @p@Lay [@p@Page GetLayout]}]} {
    set @p@Lay [string trim $@p@Lay]
    if {$@p@Lay eq ""} {set @p@Lay -}
}
if {$@p@W != @p@Want} {
    set @p@Got "wins=$@p@W layout=$@p@Lay"
} else {
    set @p@Got $@p@W
    for {set @p@I 1} {$@p@I <= $@p@W} {incr @p@I} {
        if {[catch {@p@Page GetWindowHandle @p@Win $@p@I}]} {
            error "window $@p@I: no window handle (the page has $@p@W window(s))"
        }
        if {[catch {@p@Win GetClientHandle @p@C}]} {
            error "make_grid: window $@p@I is not a HyperView window (client type ?: it answers no client handle)"
        }
        if {[catch {@p@C GetModelList}]} {
            error "make_grid: window $@p@I is not a HyperView window (client type plot)"
        }
        catch {@p@C ReleaseHandle}
        catch {@p@Win ReleaseHandle}
    }
}}
    set s [string map [list @p@Want $count] $s]
    return "[::pis::hw::stack_open psi]\n[string map [list @p@ psi] $s]\n[::pis::hw::page_close psi]\nset psiGot"
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
    set result_set {
set pisMid [pisC GetActiveModel]
pisC GetModelHandle pisM $pisMid
pisM SetResult %path
catch {pisM ReleaseHandle}}
    set result_add {
set pisMid [pisC GetActiveModel]
pisC GetModelHandle pisM $pisMid
pisM SetResult %path
pisM AddResultFile %path
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
    # (::pis::hw::load_model_in_window) uses the same list as k = 1.
    dict set t load_model [list \
        [dict create n 1 via hwi \
            cmd "[::pis::hw::window_open pis %win]\npisC AddModel %path\npisC Draw\n[::pis::hw::window_close pis]" \
            check [::pis::hw::check_models_in_window %win] want 1 \
            src {conrod/tcl_guide/hv_model_loader.tcl (AddModel + Draw) + conrod/_tmp_hv/batchImportOdb.tcl} \
            note {window %win holds exactly one model}] \
        [dict create n 2 via hwi \
            cmd "[::pis::hw::stack_open pis]\npisPage GetWindowHandle pisWin %win\npisWin GetClientHandle pisC\npisC AddModel %path\npisWin Draw\n[::pis::hw::window_close pis]" \
            check [::pis::hw::check_models_in_window %win] want 1 \
            src {conrod/tcl_guide/hv_model_loader.tcl (alternate Draw owner) + guess: Draw on the window} \
            note {same model, drawn by the window instead of the client}]]
    # --- grid bodies ------------------------------------------------------------------
    # THE LAYOUT TOKEN is MEASURED on this page, not read out of a document (pass 6,
    # 2026-11-11): see ::pis::hw::sweep_tokens for the candidates - one of them is the reference
    # loader's own "${r}x${c}" (conrod/tcl_guide/hv_model_loader.tcl:498-501, with "1x2" = 1 row,
    # 2 columns at :457-460, which is why both orders are tried and why a 2-window grid hid the
    # mistake), and only the page can say which one it accepts.
    # THE WALK is sourced: batchImportOdb.tcl:126-134 applies the token with
    # '<page> SetLayout <token>' and then gets a window handle AND a client handle for every
    # window ("add the pane controls").
    # NO VARIANT SETS A CLIENT TYPE. '<win> SetClientType Plot' exists in exactly one script on
    # this machine, conrod/_tmp_hv/training.tcl:9,20, and that script's own header calls it
    # "set the 3rd window of page 3 to a CURVE CHART" - it is how a window becomes a HyperGraph
    # 2D chart, i.e. the defect the owner reported after Load All. The working reference loader
    # does what the walk below does and nothing else (hv_model_loader.tcl:1179-1180 SetLayout,
    # :1329-1337 GetClientHandle + AddModel + Draw, :1485-1498 the per-window load).
    # There is also NO variant carrying a HyperView client type: no script on this machine
    # passes any value to SetClientType, so a HyperView value would be a guess - and a guess is
    # exactly what produced this defect.
    # Every call in the walk is caught on purpose: the walk must not be the judge. The
    # read-back (check_grid) is, and its message carries the count it expected and the window
    # it could not open or that turned out to be a chart - one place to read instead of a Tcl
    # error from the middle of a loop.
    set grid_walk [::pis::hw::grid_walk]
    # ONE make_grid form, with a token that is MEASURED on this page (pass 6, 2026-11-11). Five
    # passes tried to read the token out of a document and the owner's build ignored every one of
    # them without an error, so the documented spellings are no longer separate variants here:
    # ::pis::hw::grid_sweep applies them one by one and keeps the FIRST that gives the asked count
    # with a client handle in every window (conrod/tcl_guide/hv_model_loader.tcl:1149-1204 applies
    # a candidate and re-reads the page; conrod/_tmp_hv/batchImportOdb.tcl:105,126 is GetLayout /
    # SetLayout). So the table holds ONE form, and its %owner is a token that was either captured
    # from this build or just proved on it - never a guess.
    dict set t make_grid [list \
        [dict create n 1 via hwi \
            cmd "[::pis::hw::stack_open pis]\npisPage SetLayout %owner\n$grid_walk\n[::pis::hw::page_close pis]" \
            check [::pis::hw::check_grid %count] want %count \
            src {conrod/tcl_guide/hv_model_loader.tcl:1149-1204 (candidate -> SetLayout -> re-read) + conrod/_tmp_hv/batchImportOdb.tcl:105,126 (GetLayout / SetLayout)} \
            note {%count windows, every one a HYPERVIEW client (no SetClientType: training.tcl:9,20 would make a chart); token measured by grid_sweep}]]
    dict set t load_result_in_window [list \
        [dict create n 1 via hwi \
            cmd "[::pis::hw::window_open pis %index]\n$result_set\n[::pis::hw::window_close pis]" \
            check [::pis::hw::check_result_attached %index] want 1 \
            src {conrod/_tmp_hv/training.tcl + test/test_out/TCL_StressExport.tcl (model SetResult)} \
            note {window %index keeps one model and gains a result controller}] \
        [dict create n 2 via hwi \
            cmd "[::pis::hw::window_open pis %index]\n$result_add\n[::pis::hw::window_close pis]" \
            check [::pis::hw::check_result_attached %index] want 1 \
            src {test/test_out/TCL_StressExport.tcl (SetResult + AddResultFile)} \
            note {same, with the result file registered as well}]]
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

# The body of ::pis::hw::run with the variant list and the first number given by the caller:
# The body of ::pis::hw::run with the variant list and the first number given by the caller:
# ::pis::hw::make_grid passes the ONE measured-token form (its %owner is already swept or
# captured) while every other op keeps its table order. `start` is clamped to the list, so a
# number kept from a run that had more forms can never skip every variant.
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

# Read-back only: does the page really show cols x rows windows, and is EVERY one of them a
# usable HYPERVIEW window (a window handle, a client handle, and a client that answers
# GetModelList - i.e. one that can hold a model)? Returns the window count HyperView reported.
# Never journaled. ::pis::hw::run already gates a grid on the same check; this proc is the
# answer the app shows (diag "wins=") and it names the first window that cannot be opened or
# that turned out to be a chart, so a grid that built 4 windows of which 2 are HyperGraph 2D is
# reported as "window 3 is not a HyperView window (client type plot)", not as a total.
proc ::pis::hw::verify_grid {cols rows} {
    ::pis::hw::need_exec
    foreach {label value} [list cols $cols rows $rows] {
        if {![string is integer -strict $value] || $value < 1} {
            error "::pis::hw::verify_grid: $label must be a positive integer, got: '$value'"
        }
    }
    set count [expr {$cols * $rows}]
    set got [string trim [::pis::hw::probe [::pis::hw::check_grid $count]]]
    if {$got ne $count} {
        # $got already carries HyperView's own evidence ("wins=2 layout=2H"), so it is
        # quoted as it is instead of being squeezed into a window count.
        error [format "the page answered '%s', expected %d window(s) (%dx%d)" [string trim $got] \
            $count $cols $rows]
    }
    return $got
}

# --- the LAYOUT SWEEP: the page is the judge (owner fail, 2026-11-11, pass 6) --------------
# Five passes guessed the layout token out of a document and the owner's build ignored every one
# of them without an error (2x1 and 1x2 build, 2x2 and 4x1 do not). The token belongs to THAT
# build, so it is MEASURED here: apply a candidate with SetLayout, read BOTH facts back
# ('<page> GetNumberOfWindows' and '<page> GetLayout', conrod/_tmp_hv/batchImportOdb.tcl:105),
# and accept the first candidate that gives the asked count AND a client handle in EVERY window.
# That is the reference loader's own candidate loop (conrod/tcl_guide/hv_model_loader.tcl:
# 1149-1204 applies a candidate and re-reads the count, :1210-1237 does it one token at a time).
# The list is the UNION of everything this folder knows, so no table entry can be missing: every
# documented spelling rows-first and cols-first ("RxC", "R X C", "R x C", "R - C"), the plain
# window count, and the legacy word this grid can have (single 2H 2V 3H 3V 4H 4V -
# ::pis::hw::legacy_token answers "" for a count/arrangement the reference list cannot express).
proc ::pis::hw::sweep_tokens {cols rows} {
    set out {}
    foreach pair [list [list $rows $cols] [list $cols $rows]] {
        lassign $pair r c
        foreach form [list %dx%d {%d X %d} {%d x %d} {%d - %d}] {
            lappend out [format $form $r $c]
        }
    }
    lappend out [expr {$cols * $rows}]
    set word [::pis::hw::legacy_token $cols $rows]
    if {$word ne ""} { lappend out $word }
    set uniq {}
    foreach t $out {
        if {[lsearch -exact $uniq $t] < 0} { lappend uniq $t }
    }
    return $uniq
}

# The measurement itself, folded into ONE line and run through ::pis::hw::probe: a probe writes
# no journal line, so fifteen tries never become fifteen lines a human would replay, and the only
# SetLayout that reaches the journal is the winner's (::pis::hw::run_list writes it after its
# read-back agreed). Every line of the script is a complete command, because that is what
# ::pis::hw::fold_script needs.
proc ::pis::hw::sweep_script {count tokens} {
    set s {set @p@Want @want@
set @p@Toks @toks@
set @p@Ok -
set @p@N 0
set @p@Max 0
set @p@Last -
set @p@Near -
set @p@Why -
foreach @p@Tok $@p@Toks {
    incr @p@N
    catch {@p@Page SetLayout $@p@Tok}
    set @p@W [@p@Page GetNumberOfWindows]
    if {![string is integer -strict $@p@W]} {set @p@W [llength $@p@W]}
    if {$@p@W > $@p@Max} {set @p@Max $@p@W}
    if {![catch {set @p@L [@p@Page GetLayout]}]} {set @p@Last [string trim $@p@L]}
    if {$@p@Last eq ""} {set @p@Last -}
    set @p@All 1
    set @p@Why -
    if {$@p@W != $@p@Want} {
        set @p@All 0
    } else {
        for {set @p@I 1} {$@p@I <= $@p@W} {incr @p@I} {
            if {[catch {@p@Page GetWindowHandle @p@Win $@p@I} @p@E]} {set @p@All 0; set @p@Why "window $@p@I: $@p@E"; break}
            if {[catch {@p@Win GetClientHandle @p@C} @p@E]} {set @p@All 0; set @p@Why "window $@p@I: $@p@E"; break}
            catch {@p@C ReleaseHandle}
            catch {@p@Win ReleaseHandle}
        }
        if {!$@p@All && $@p@Near eq "-"} {set @p@Near $@p@Tok}
    }
    if {$@p@All} {set @p@Ok $@p@Tok; break}
}
set @p@Out [list $@p@Ok $@p@N $@p@Max $@p@Last $@p@Near $@p@Why]
set @p@Out}
    set quoted ""
    foreach t $tokens { append quoted " [::pis::hw::quote $t]" }
    # One LIST VALUE, not one word per token: "set psiToks [list 1x4 {1 X 4} ...]" - a bare
    # "set psiToks 1x4 {1 X 4} ..." would hand set eleven arguments and fail on the page.
    set quoted "\[list [string trim $quoted]\]"
    set s [string map [list @want@ $count @toks@ $quoted] $s]
    set s [string map [list @p@ psi] $s]
    return "[::pis::hw::stack_open psi]\n$s\n[::pis::hw::page_close psi]\nset psiOut"
}

# Which token THIS page accepts for cols x rows, printed as exactly ONE line under 80 characters
# for the owner to copy back:
#   SWEEP 4x1: ok=1x4 tried=1
#   SWEEP 2x2: none tried=5 max=4 last=2x2 got=2x2 (win..
# "tried" counts the candidates, "max" is the biggest window count any candidate produced,
# "last" is the token the page answered last and "got"/"(...)" name the first candidate that DID
# give the asked count but whose windows could not all be opened - that is what turns the T-006
# defect (a layout that builds HyperGraph 2D windows) from "no token works" into a real reason.
# Returns {ok tried max last near why}; ok is "" when no candidate gave the asked count with a
# client handle in EVERY window. A probe: nothing is journaled, nothing is recorded, no variant
# moves, and the winning token is the only one make_grid sends as a step.
proc ::pis::hw::grid_sweep {cols rows} {
    ::pis::hw::need_exec
    foreach {label value} [list cols $cols rows $rows] {
        if {![string is integer -strict $value] || $value < 1} {
            error "::pis::hw::grid_sweep: $label must be a positive integer, got: '$value'"
        }
    }
    set count [expr {$cols * $rows}]
    set tokens [::pis::hw::sweep_tokens $cols $rows]
    set tag [format %dx%d $cols $rows]
    set got ""
    set perr ""
    # The probe itself can fail (no wrapper, a page that will not open). The one SWEEP line says
    # THAT, instead of reporting "nothing was tried" as if the page had refused every token.
    if {[catch {set got [string trim [::pis::hw::probe [::pis::hw::sweep_script $count $tokens]]]} perr]} {
        set detail [lindex [split [string trim $perr] "\n"] 0]
        set line [format "SWEEP %s: probe failed: %s" $tag $detail]
        while {[string length $line] >= 80} {
            set line [string range $line 0 76]..
        }
        puts $line
        return [dict create ok "" tried 0 max 0 last - near - why - err $detail]
    }
    set ok ""
    set tried 0
    set mx 0
    set last -
    set near -
    set why -
    if {[llength $got] == 6} {
        lassign $got ok tried mx last near why
        if {$ok eq "-"} { set ok "" }
    }
    set why [lindex [split [string trim $why] "\n"] 0]
    if {$ok ne ""} {
        set line [format "SWEEP %s: ok=%s tried=%s" $tag $ok $tried]
    } elseif {$near ne "-" && $why ne "-"} {
        set line [format "SWEEP %s: none tried=%s max=%s last=%s got=%s (%s)" \
            $tag $tried $mx $last $near $why]
    } else {
        set line [format "SWEEP %s: none tried=%s max=%s last=%s" $tag $tried $mx $last]
    }
    while {[string length $line] >= 80} {
        set line [string range $line 0 76]..
    }
    puts $line
    return [dict create ok $ok tried $tried max $mx last $last near $near why $why]
}
# load_result_in_window) used for windows 1..N, 0 where no variant worked.
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

# ONE line under 80 characters: the layout, the variant the grid used, how many windows
# HyperView really shows, and the variant each window used for its model and its result
# (0 = no variant worked), plus the client letter of each window (H = HyperView, P = chart,
# ? = cannot tell). This is the line the human copies back when only ok/fail is possible (ENV),
# so the shape is fixed:
#   DIAG T6e: layout=2x2 grid=1 wins=4 model=1,1,0,0 result=1,1,0,0 client=H,H,H,H
# The short build code comes first (::pis::hw::build_code; the BUILD line has the full stamp),
# so the human's copy-back names the copy of this file that produced the line.
# "layout" is the "<rows>x<cols>" token of the last GOOD grid ("-" while none has succeeded);
# "wins" is the window count read back from the page, never the count this app asked for.
# client= is omitted when the session cannot be asked (no wrapper, no HyperView, a probe that
# raised) - a made-up letter would be worse than no letter.
proc ::pis::hw::diag {} {
    variable adapt_used
    variable adapt_grid
    variable adapt_wins
    set grid 0
    if {[dict exists $adapt_used make_grid]} { set grid [dict get $adapt_used make_grid] }
    set head [format "DIAG %s: layout=%s grid=%d wins=%d" [::pis::hw::build_code] $adapt_grid $grid $adapt_wins]
    set models [::pis::hw::used_list load_model]
    set results [::pis::hw::used_list load_result_in_window]
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
    # The line must stay under 80 characters. A layout with more windows than fits drops the
    # OLDEST windows first (they are the ones already proven) and ".." says the list starts
    # somewhere else. The client letters are dropped only if even one window would not fit with
    # them, so the line never exceeds its 80 characters on a big layout.
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
        if {$cut >= $width} { set line $bare ; break }
        incr cut
    }
    puts $line
    return $line
}

proc ::pis::hw::make_grid {cols rows} {
    variable adapt_grid
    variable adapt_wins
    variable adapt_tokens
    foreach {label value} [list cols $cols rows $rows] {
        if {![string is integer -strict $value] || $value < 1} {
            error "::pis::hw::make_grid: $label must be a positive integer, got: '$value'"
        }
    }
    set count [expr {$cols * $rows}]
    # A grid that fails must never look like a good one in diag: the window count is cleared
    # before anything runs and written again only after a read-back agreed.
    set adapt_wins 0
    ::pis::hw::need_exec
    # (a) THE PAGE ALREADY IS THE GRID - no SetLayout at all (owner's report, 2026-11-11: the
    # layout was chosen by hand and a SetLayout with a token this build ignores can only DESTROY
    # it). The gate is the same read-back a grid step must pass: the count AND a HyperView client
    # in every window. The journal gets ONE comment line, never an hwi line: a replay cannot
    # rebuild a grid this file never built, and it has to know that.
    if {[::pis::hw::grid_ready $count]} {
        set st [::pis::hw::page_state]
        set lay -
        if {[llength $st] > 0} { set lay [lindex $st 1] }
        ::pis::hw::note INFO [format "make_grid: grid already %d window(s), SetLayout skipped" $count]
        ::pis::hw::status [format "HV make_grid: %d window(s) already present" $count]
        ::pis::hw::journal_note [format \
            "grid %dx%d already present; replay needs the same layout set by hand" $cols $rows]
        ::pis::hw::record make_grid 0
        set adapt_grid $lay
        set adapt_wins $count
        return $count
    }
    # (b) THE TOKEN IS MEASURED, NOT GUESSED (pass 6). The owner's capture wins when there is one:
    # it was read out of this build, so it costs one try. Without a capture, ::pis::hw::grid_sweep
    # asks THIS page which candidate gives the asked count, and only that candidate is sent as the
    # step - a token that cannot win is never journaled as if it had.
    set tok [::pis::hw::owner_token $cols $rows]
    set how capture
    set proven 1
    if {$tok eq ""} {
        set swept [::pis::hw::grid_sweep $cols $rows]
        set tok [dict get $swept ok]
        set how sweep
        if {$tok eq ""} {
            # A candidate that DID give the asked count but whose windows would not give up a
            # client handle is still sent as the step: the read-back then names the real cause
            # (windows that are not HyperView ones), which no other token can fix. A step that
            # fails journals nothing, so this can never land in a replay.
            set cand [dict get $swept near]
            if {$cand ne "-" && [dict get $swept why] ne "-"} {
                set tok $cand
                set how "sweep candidate"
                set proven 0
            } else {
                # Nothing this file knows builds the grid here, so nothing is sent for the windows
                # either (they cannot exist). The SWEEP line above is the measurement; this is the
                # one thing left to do.
                error [format "make_grid: no layout token gives %d window(s) for %dx%d (tried %s, best %s) | Fix: chọn %dx%d bằng tay trong HyperView, gõ ::pis::hw::grid_capture, rồi chạy lại Load All" \
                    $count $cols $rows [dict get $swept tried] [dict get $swept max] $cols $rows]
            }
        }
        # Keep the winner for this session: the NEXT %dx%d build and diag use it without sweeping.
        if {$proven} { dict set adapt_tokens [::pis::hw::token_key $cols $rows] $tok }
    }
    # ONE line the owner can keep: which token won and how it was found ("capture" = the owner's
    # own GetLayout line, "sweep" = measured on this page just now). Only a proven token is kept:
    # a candidate that is about to fail must not be offered as if it were the answer.
    if {$proven} {
        puts [format "Keep: %dx%d -> %s (%s)" $cols $rows $tok $how]
        ::pis::hw::status [format "HV make_grid: %dx%d token %s (%s)" $cols $rows $tok $how]
    }
    set list [::pis::hw::variants make_grid]
    set total [llength $list]
    set values [dict create %cols $cols %rows $rows %count $count \
        %grid [::pis::hw::grid_token $cols $rows] \
        %legacy [::pis::hw::legacy_token $cols $rows] %owner $tok]
    # (c) A grid that still fails names what was asked, what the page answered (wins=, layout=),
    # the last form tried and the ONE thing left to do: pick the layout by hand, capture its
    # token, store it.
    if {[catch {::pis::hw::run_list make_grid $list [::pis::hw::at make_grid] $values} err]} {
        error [format "%s | asked %d window(s), page answered %s | last form: variant %d/%d | Fix: chọn layout %dx%d bằng tay trong HyperView, gõ ::pis::hw::grid_capture rồi dán dòng ::pis::hw::grid_token_set được in ra" \
            $err $count [::pis::hw::grid_answer] $total $total $cols $rows]
    }
    # The run proved the grid through check_grid already; this second read-back (never
    # journaled - a check is not a step) is what the app REPORTS and what diag prints, so the
    # number in "wins=" and the token in "layout=" are HyperView's own answers.
    set wins [::pis::hw::verify_grid $cols $rows]
    set st [::pis::hw::page_state]
    set lay ""
    if {[llength $st] > 0} { set lay [lindex $st 1] }
    if {$lay eq "" || $lay eq "-"} { set lay $tok }
    set adapt_grid $lay
    set adapt_wins $wins
    return $wins
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
    puts "  what ran last: ::pis::hw::diag   (one line: layout, grid, wins and every window)"
    puts "  what the page is now: ::pis::hw::page_info   (read-only: layout token, wins, open windows)"
    puts "  which token this build accepts: ::pis::hw::grid_sweep <cols> <rows>   (probe, not a step)"
    puts "    ONE SWEEP line: ok=<token> tried=<n> when one wins, none/max=/last= when none does"
    puts "  the token this build really uses: set the layout by hand, then ::pis::hw::grid_capture"
    puts "    paste the printed ::pis::hw::grid_token_set line (it also prints the \[layout_tokens\] ini line)"
    return
}

# Every op back to its first variant, the order back to 1, nothing recorded and no captured
# layout token (tests, and a fresh session).
proc ::pis::hw::reset_state {} {
    variable adapt_at
    variable adapt_used
    variable adapt_order
    variable adapt_grid
    variable adapt_wins
    variable adapt_tokens
    set adapt_at [dict create]
    set adapt_used [dict create]
    set adapt_order 1
    set adapt_grid "-"
    set adapt_wins 0
    set adapt_tokens [dict create]
    return
}

# --- build stamp: ONE line, printed when this file is sourced -------------------------
# The line answers the first question on a HyperView machine ("which copy is this?"):
#   BUILD T6g-20261111-1051 | make_grid variants=1 | adapter lines=NNN | tokens=N
# The line count is measured from the file itself at source time (below), so it cannot go
# stale the way a hand-written number would. "tokens=" is how many owner-captured layout
# tokens this copy can see (session + the [layout_tokens] section of the ini it sits next to),
# so "the ini I edited is not the ini this file reads" shows up before the first Load All.
proc ::pis::hw::build_line {} {
    variable build_lines
    set stamp "no-stamp"
    if {[info exists ::pis::BUILD]} { set stamp $::pis::BUILD }
    set n 0
    catch { set n [llength [::pis::hw::variants make_grid]] }
    set toks 0
    catch { set toks [::pis::hw::token_count] }
    return [format "BUILD %s | make_grid variants=%d | adapter lines=%d | tokens=%d" \
        $stamp $n $build_lines $toks]
}

# The code part of the stamp (T6e in T6e-20261111-0918): what a DIAG line starts with. The
# time part only fits in the BUILD line - see the note at ::pis::BUILD.
proc ::pis::hw::build_code {} {
    set stamp "no-stamp"
    if {[info exists ::pis::BUILD]} { set stamp $::pis::BUILD }
    set i [string first "-" $stamp]
    if {$i > 0} { return [string range $stamp 0 [expr {$i - 1}]] }
    return $stamp
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
