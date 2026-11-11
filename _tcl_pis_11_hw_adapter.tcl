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
#   ::pis::hw::grid_probe {cols rows {newpage 0}}
#                               ask HyperView which layout token really gives cols x rows
#                               windows: one TRY line per form, the page restored, then the
#                               variant to keep - NOT a step, never journaled. newpage 1 also
#                               tries the AddPage form, which leaves a page behind (0 = no
#                               page is added, so the default changes nothing structural)
#   ::pis::hw::reset_state {}   variants + order back to 1 (tests)
#   ::pis::hw::run {op values}  run an op (the six operations call this)
#   ::pis::hw::used {op {win}}  variant number that step really used (0 = none worked)
#   ::pis::hw::build_line {}    the ONE BUILD line (stamp, grid variants, line count)
#   ::pis::hw::announce {}      print that line to the console and to the GUI log
#
# BUILD STAMP (T-006 iteration, 2026-11-10): ::pis::BUILD is a short code written BY HAND
# when this file changes, e.g. T6e-20261111-0918, so the HyperView machine can be matched to
# a copy of this file without a guess. Sourcing this file prints ONE line,
#   BUILD T6e-20261111-0918 | make_grid variants=8 | adapter lines=<n>
# and every ::pis::hw::diag line starts with the same stamp (the time part only fits there).
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
}

# The build stamp: short code + yyyymmdd-hhmm, written BY HAND when this file changes (the
# adapter never derives it). The BUILD line and the GUI start line carry the FULL stamp;
# ::pis::hw::diag carries only the code part (T6e), because the full stamp plus 8 windows of
# model=/result=/client= lists would not fit in the 80 characters a diag line is allowed.
namespace eval ::pis {
    variable BUILD "T6e-20261111-0918"
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

# WHY A COUNT MISMATCH ALSO NAMES THE LAYOUT TOKEN (owner's report, 2026-11-11): on the
# owner's machine EVERY variant of a 2x2 AND of a 4x4 request ended in the same answer,
# "wins=2", so the count alone could not tell "the token was ignored" from "the page really
# has 2 windows". '<page> GetLayout' answers the token the page is IN - conrod/_tmp_hv/
# batchImportOdb.tcl:105 reads the page's layout exactly that way, and conrod/tcl_guide/
# hv_model_loader.tcl:1123 reads it plus :1136 caches it - so the mismatch now carries it:
#   wins=2 layout=2H
# ("layout=-" = the page answered an empty string, "layout=?" = GetLayout itself raised.)
# That single field is the difference between a spelling problem and a page that does not change
# at all, and ::pis::hw::grid_probe prints the same two facts for every candidate token.
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
    # THE LAYOUT TOKEN, read out of the reference scripts: the token is "<rows>x<cols>" -
    # hv_model_loader.tcl:498-501 PreferredLayoutToken = "${r}x${c}" with :457-460 "'1x2' means
    # 1 row, 2 columns = side by side" - and an earlier variant here sent "%colsx%rows" instead,
    # i.e. the grid transposed. For 2 windows both spellings happen to give 2 windows, which is
    # why only the 4-window layouts failed.
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
    set grid_walk {
for {set pisWi 1} {$pisWi <= %count} {incr pisWi} {catch {pisPage GetWindowHandle pisWin $pisWi}; catch {pisWin GetClientHandle pisC}; catch {pisC ReleaseHandle}; catch {pisWin ReleaseHandle}}
}
    # The legacy word is only for the counts the reference list has (1..4); on any other grid
    # it is empty and that variant fails with the message below instead of sending an empty
    # token.
    set grid_legacy {
set pisTok %legacy
if {$pisTok eq ""} {error "no legacy layout word for this grid (only 1..4 windows have one)"}
pisPage SetLayout $pisTok
}
    dict set t make_grid [list \
        [dict create n 1 via hwi \
            cmd "[::pis::hw::stack_open pis]\npisPage SetLayout %grid\n$grid_walk\n[::pis::hw::page_close pis]" \
            check [::pis::hw::check_grid %count] want %count \
            src {conrod/tcl_guide/hv_model_loader.tcl:498-501,512,1179-1180 (token "${r}x${c}", rows first, SetLayout then GetClientHandle) + conrod/_tmp_hv/batchImportOdb.tcl:126-134 (a client handle for every window)} \
            note {%count windows, every one a HYPERVIEW client (no SetClientType: training.tcl:9,20 would make a chart); token = rows x cols}] \
        [dict create n 2 via hwi \
            cmd "[::pis::hw::stack_open pis]\npisPage SetLayout %colsx%rows\n$grid_walk\n[::pis::hw::page_close pis]" \
            check [::pis::hw::check_grid %count] want %count \
            src {conrod/tcl_guide/hv_model_loader.tcl:512 (the transposed spelling of a "RxC" token, :457-460) + conrod/_tmp_hv/batchImportOdb.tcl:126-134} \
            note {the token written %cols x %rows instead of rows x cols}] \
        [dict create n 3 via hwi \
            cmd "[::pis::hw::stack_open pis]\npisPage SetLayout {%rows X %cols}\n$grid_walk\n[::pis::hw::page_close pis]" \
            check [::pis::hw::check_grid %count] want %count \
            src {conrod/tcl_guide/hv_model_loader.tcl:512 (the "%rows X %cols" spelling)} \
            note {the token with spaces around the X}] \
        [dict create n 4 via hwi \
            cmd "[::pis::hw::stack_open pis]\npisPage SetLayout {%cols X %rows}\n$grid_walk\n[::pis::hw::page_close pis]" \
            check [::pis::hw::check_grid %count] want %count \
            src {conrod/tcl_guide/hv_model_loader.tcl:512 (the "%cols X %rows" spelling)} \
            note {the spaced token, transposed}] \
        [dict create n 5 via hwi \
            cmd "[::pis::hw::stack_open pis]\npisPage SetLayout {%rows x %cols}\n$grid_walk\n[::pis::hw::page_close pis]" \
            check [::pis::hw::check_grid %count] want %count \
            src {conrod/tcl_guide/hv_model_loader.tcl:512 (the "%rows x %cols" spelling)} \
            note {the token with a lower-case x and spaces}] \
        [dict create n 6 via hwi \
            cmd "[::pis::hw::stack_open pis]\npisPage SetLayout {%rows - %cols}\n$grid_walk\n[::pis::hw::page_close pis]" \
            check [::pis::hw::check_grid %count] want %count \
            src {conrod/tcl_guide/hv_model_loader.tcl:512 (the "%rows - %cols" spelling)} \
            note {the token with a dash}] \
        [dict create n 7 via hwi \
            cmd "[::pis::hw::stack_open pis]\npisPage SetLayout %count\n$grid_walk\n[::pis::hw::page_close pis]" \
            check [::pis::hw::check_grid %count] want %count \
            src {conrod/tcl_guide/hv_model_loader.tcl:517 (the plain window count)} \
            note {the layout named by its window count only (arrangement is the build's)}] \
        [dict create n 8 via hwi \
            cmd "[::pis::hw::stack_open pis]\n$grid_legacy\n$grid_walk\n[::pis::hw::page_close pis]" \
            check [::pis::hw::check_grid %count] want %count \
            src {conrod/tcl_guide/hv_model_loader.tcl:518 (single 1x1 2H 2V 3H 3V 4H 4V)} \
            note {the legacy word for 1..4 windows, e.g. %legacy}]]
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
    ::pis::hw::need_exec
    set list [::pis::hw::variants $op]
    set total [llength $list]
    set start [::pis::hw::at $op]
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

# --- which layout token the page really accepts (a probe, not a step) -------------------
# Every make_grid variant's token, in variant order, as {<variant number> <token>} pairs. Built
# from the SAME two helpers the table uses (grid_token / legacy_token) plus the four spellings
# conrod/tcl_guide/hv_model_loader.tcl:509-514 generates, so the probe and the table cannot
# drift apart: a test asserts that each token appears in the command of the variant it is
# paired with. An empty token (a grid the legacy word has no name for) is left out.
proc ::pis::hw::grid_probe_tokens {cols rows} {
    return [list \
        [list 1 [::pis::hw::grid_token $cols $rows]] \
        [list 2 [format %dx%d $cols $rows]] \
        [list 3 [format "%d X %d" $rows $cols]] \
        [list 4 [format "%d X %d" $cols $rows]] \
        [list 5 [format "%d x %d" $rows $cols]] \
        [list 6 [format "%d - %d" $rows $cols]] \
        [list 7 [expr {$cols * $rows}]] \
        [list 8 [::pis::hw::legacy_token $cols $rows]]]
}
# THE QUESTION A COUNT MISMATCH CANNOT ANSWER, asked with HyperView as the judge: for the asked
# grid, apply every candidate token and read back BOTH facts after each one ('<page> GetLayout'
# and '<page> GetNumberOfWindows'), then put the page back the way it was. The reference loader
# does exactly this to learn the token of a window count (hv_model_loader.tcl:1149-1204 applies
# candidates and re-reads the count, :1210-1237 does it one token at a time). The one STRUCTURAL
# alternative that is sourced - a new page from '<project> AddPage' with the layout applied to
# THAT page (batchImportOdb.tcl:124-127) - is tried only when the third argument is 1: adding a
# page cannot be undone by this file (no delete verb is sourced), so the default probe leaves the
# page count alone and the answer says what to run next.
# WHAT IT IS NOT: not a step, never journaled, and it neither records nor moves a variant - a
# probe must not be able to make Load All look successful. It changes the session (a probe has
# to), so the page's own token is put back at the end, and the last line names the variant to
# keep. Output, one short line per form, so the whole block can be pasted back:
#   TRY v1 '2x2' -> layout='2H' wins=2 was=2
#   TRY new-page '2x2' -> layout='2H' wins=2 was=1      (only with the third argument 1)
#   BACK '2H' -> layout='2H' wins=2
#   TEST make_grid 2x2: asked for 4 window(s), the page shows 2
#   BEST variant 3 gives 4 window(s); keep it: ::pis::hw::use make_grid 3
# Returns the variant number that gives the asked count, 0 for the new-page form, "" for none.
# A form counts only when the count BOTH equals the asked one AND changed: a page that already
# shows the asked count cannot tell a working token from an ignored one, and it says that instead.
proc ::pis::hw::grid_probe {cols rows {newpage 0}} {
    ::pis::hw::need_exec
    foreach {label value} [list cols $cols rows $rows] {
        if {![string is integer -strict $value] || $value < 1} {
            error "::pis::hw::grid_probe: $label must be a positive integer, got: '$value'"
        }
    }
    if {![string is integer -strict $newpage] || ($newpage != 0 && $newpage != 1)} {
        error "::pis::hw::grid_probe: newpage must be 0 or 1, got: '$newpage'"
    }
    set count [expr {$cols * $rows}]
    set pairs {}
    foreach pair [::pis::hw::grid_probe_tokens $cols $rows] {
        if {[string trim [lindex $pair 1]] eq ""} { continue }
        lappend pairs $pair
    }
    set s {set psiOut {}
set psiLay0 -
if {![catch {set psiLay0 [psiPage GetLayout]}]} {
    set psiLay0 [string trim $psiLay0]
    if {$psiLay0 eq ""} {set psiLay0 -}
}
set psiW [psiPage GetNumberOfWindows]
if {![string is integer -strict $psiW]} {set psiW [llength $psiW]}
set psiOut [list [list -2 start $psiLay0 $psiW $psiW]]
foreach psiP @pairs@ {
    lassign $psiP psiId psiTok
    set psiWas $psiW
    catch {psiPage SetLayout $psiTok}
    set psiLay -
    if {![catch {set psiLay [psiPage GetLayout]}]} {
        set psiLay [string trim $psiLay]
        if {$psiLay eq ""} {set psiLay -}
    }
    set psiW [psiPage GetNumberOfWindows]
    if {![string is integer -strict $psiW]} {set psiW [llength $psiW]}
    lappend psiOut [list $psiId $psiTok $psiLay $psiW $psiWas]
}
set psiNew -
if {@newpage@} {
set psiNIdx -
catch {set psiNIdx [psiP AddPage]}
if {[string is integer -strict $psiNIdx]} {
    if {![catch {psiP GetPageHandle psiNewPage $psiNIdx}]} {
        set psiNW [psiNewPage GetNumberOfWindows]
        if {![string is integer -strict $psiNW]} {set psiNW [llength $psiNW]}
        set psiNW0 $psiNW
        catch {psiNewPage SetLayout @grid@}
        set psiNL -
        if {![catch {set psiNL [psiNewPage GetLayout]}]} {
            set psiNL [string trim $psiNL]
            if {$psiNL eq ""} {set psiNL -}
        }
        set psiNW [psiNewPage GetNumberOfWindows]
        if {![string is integer -strict $psiNW]} {set psiNW [llength $psiNW]}
        set psiNew [list 0 "new-page:@grid@" $psiNL $psiNW $psiNW0]
        catch {psiNewPage ReleaseHandle}
    }
}
}
if {$psiNew ne "-"} {lappend psiOut $psiNew}
if {$psiLay0 ne "-"} {catch {psiPage SetLayout $psiLay0}}
set psiBack -
if {![catch {set psiBack [psiPage GetLayout]}]} {
    set psiBack [string trim $psiBack]
    if {$psiBack eq ""} {set psiBack -}
}
set psiBw [psiPage GetNumberOfWindows]
if {![string is integer -strict $psiBw]} {set psiBw [llength $psiBw]}
lappend psiOut [list -1 "back:$psiLay0" $psiBack $psiBw -]
set psiOut}
    set tok [::pis::hw::quote [::pis::hw::grid_token $cols $rows]]
    set body [string map [list @pairs@ [list $pairs] @grid@ $tok @newpage@ $newpage] $s]
    set script "[::pis::hw::stack_open psi]\n$body\n[::pis::hw::page_close psi]\nset psiOut"
    set got [::pis::hw::probe $script]
    set best ""
    set newform 0
    set back "-"
    set w0 "-"
    set forms 0
    foreach item $got {
        lassign $item id idtok lay wins was
        if {$id eq "-2"} {
            # The page before the probe: a page that ALREADY shows the asked count cannot tell
            # a token that works from a token that was ignored, and the answer says so.
            set w0 $wins
            continue
        }
        # A form only counts as a MATCH when it CHANGED the count to the asked one: a token the
        # build ignored leaves the count where the previous form put it, so it can never win.
        set changed [expr {$wins == $count && $wins != $was}]
        if {$id eq "-1"} {
            # The page's own token was put back - but the page says whether it took it: reporting
            # the token we ASKED for would be the same "no error = it worked" mistake this file
            # exists to avoid, so a failed restore is named as such.
            set asked [string range $idtok 5 end]
            if {$lay eq $asked} {
                puts [format "BACK '%s' -> layout='%s' wins=%s" $idtok $lay $wins]
            } else {
                puts [format "BACK '%s' -> layout='%s' wins=%s (the page did NOT take its own token back)" \
                    $idtok $lay $wins]
            }
            set back [format "layout='%s' wins=%s" $lay $wins]
        } elseif {$id == 0} {
            incr forms
            puts [format "TRY new-page '%s' -> layout='%s' wins=%s was=%s" $idtok $lay $wins $was]
            if {$changed} { set newform 1 }
        } else {
            incr forms
            puts [format "TRY v%s '%s' -> layout='%s' wins=%s was=%s" $id $idtok $lay $wins $was]
            if {$changed && $best eq ""} { set best $id }
        }
    }
    puts [format "TEST make_grid %dx%d: asked for %d window(s), the page shows %s" \
        $cols $rows $count $w0]
    if {$best ne ""} {
        puts [format "BEST variant %s gives %d window(s); keep it: ::pis::hw::use make_grid %s" \
            $best $count $best]
        return $best
    }
    if {$newform} {
        puts [format "BEST the NEW-PAGE form gives %d window(s) and no variant does - report this line" $count]
        return 0
    }
    if {$w0 eq $count} {
        puts [format "BEST the page already shows %d window(s) and no form changed it - nothing to learn" $count]
        return ""
    }
    puts [format "BEST none of the %d form(s) gives %d window(s); the page is back to %s" \
        $forms $count $back]
    if {!$newpage} {
        puts [format "NEXT ::pis::hw::grid_probe %d %d 1   (also try a NEW page: 'AddPage' + the layout)" \
            $cols $rows]
    }
    return ""
}



# One per-window record as a comma list, oldest window first: the variants load_model (or
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
    foreach {label value} [list cols $cols rows $rows] {
        if {![string is integer -strict $value] || $value < 1} {
            error "::pis::hw::make_grid: $label must be a positive integer, got: '$value'"
        }
    }
    set count [expr {$cols * $rows}]
    # A grid that fails must never look like a good one in diag: the window count is cleared
    # before the variants run and written again only after the read-back below passed.
    set adapt_wins 0
    # A failed grid also names the ONE console line that answers "which token does this build
    # accept" - otherwise the human is left with "no variant worked" and nothing to do next.
    if {[catch {::pis::hw::run make_grid [dict create \
            %cols $cols %rows $rows %count $count \
            %grid [::pis::hw::grid_token $cols $rows] \
            %legacy [::pis::hw::legacy_token $cols $rows]]} err]} {
        error [format "%s | which token this build accepts: ::pis::hw::grid_probe %d %d" \
            $err $cols $rows]
    }
    # The run proved the grid through check_grid already; this second read-back (never
    # journaled - a check is not a step) is what the app REPORTS and what diag prints, so the
    # number in "wins=" is HyperView's own answer, not the number this file asked for.
    set wins [::pis::hw::verify_grid $cols $rows]
    set adapt_grid [::pis::hw::grid_token $cols $rows]
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
    puts "  change one: ::pis::hw::use <op> <n>   e.g. ::pis::hw::use make_grid 2"
    puts "  what ran last: ::pis::hw::diag   (one line: layout, grid, wins and every window)"
    puts "  what the page is now: ::pis::hw::page_info   (read-only: layout token, wins, open windows)"
    puts "  which token this build accepts: ::pis::hw::grid_probe <cols> <rows> ?newpage 0|1?   (probe, not a step)"
    puts "    add '1' as the third argument to also try a NEW page; the default leaves the page count alone"
    return
}

# Every op back to its first variant, the order back to 1, nothing recorded (tests, and a
# fresh session).
proc ::pis::hw::reset_state {} {
    variable adapt_at
    variable adapt_used
    variable adapt_order
    variable adapt_grid
    variable adapt_wins
    set adapt_at [dict create]
    set adapt_used [dict create]
    set adapt_order 1
    set adapt_grid "-"
    set adapt_wins 0
    return
}

# --- build stamp: ONE line, printed when this file is sourced -------------------------
# The line answers the first question on a HyperView machine ("which copy is this?"):
#   BUILD T6e-20261111-0918 | make_grid variants=8 | adapter lines=NNN
# The line count is measured from the file itself at source time (below), so it cannot go
# stale the way a hand-written number would.
proc ::pis::hw::build_line {} {
    variable build_lines
    set stamp "no-stamp"
    if {[info exists ::pis::BUILD]} { set stamp $::pis::BUILD }
    set n 0
    catch { set n [llength [::pis::hw::variants make_grid]] }
    return [format "BUILD %s | make_grid variants=%d | adapter lines=%d" $stamp $n $build_lines]
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
::pis::hw::announce
