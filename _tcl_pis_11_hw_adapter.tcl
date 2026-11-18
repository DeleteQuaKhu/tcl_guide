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
#   ::pis::hw::make_grid {id}                      build the layout named by the integer <id>
#   ::pis::hw::load_result_in_window {index path}  result file into window <index>
#   ::pis::hw::verify_window {index}               read-back: window <index> holds 1 model + 1 result
#   ::pis::hw::select_window {index}               make window <index> the active one
#   ::pis::hw::import_legend {path}                import a legend into the active window
#   ::pis::hw::set_view {index name}               activate a named VIEW in window <index> (T-032)
#   ::pis::hw::active_window {}                    read-back: the window that is active NOW
#   ::pis::hw::capture_window {index path view unit w h ?-row r? ?-layout 0|1? ?-trace 0|1?}
#                                                  one PNG of window <index>, in view <view> (T-032)
#   ::pis::hw::refresh {}                          let Tk paint after a run (ONE `update idletasks`)
#
# T-019 (2026-11-11) - the result step no longer DEPENDS on WaitForResults. The supplier documents
# it as valid only in the HyperView - MultiCore profile (docs/refs/HV_API.md sec.5, S16/S17); the
# owner's build has no such method at all, and the unguarded call stopped Load All on window 1
# while windows 2..N were never attempted. It is now:
#   * a guarded OPTIMISATION: poIPostManager GetAsyncMode (S18) is asked once per session, and
#     only a `1` allows a wait; anything else is skipped with ONE `INFO result wait skipped: <why>`
#     per run;
#   * a variant list of its own, op `result_wait`: client form, manager form, and LAST the skip -
#     a form that failed in this session is not offered again;
#   * never the proof: the proof is a BOUNDED read-back (poIModel GetResultCtrlHandle S25 +
#     poIResultCtrl GetNumberOfSubcases S27, ::pis::hw::retry_tries attempts, `after` + `update`,
#     no coroutine). A wait that fails while the read-back succeeds is a WARN.
# T-019 pass 12 (2026-11-12) - GetError is a NOTE, never a judge. The owner's report: window 1
# loaded, window 2 stopped Load All with `session error after SetResult: (poIPost::GetResultList)`
# although the result WAS attached; a 4-window grid never reached windows 3 and 4. The session
# condition is now read (a) BEFORE SetResult to flush a leftover from the window before, and (b)
# after SetResult as ::pis::hw::sess_note: logged as ONE `WARN ... the read-back succeeded` per
# distinct text and per run, and quoted inside the failure message only when the READ-BACK failed.
# Reason: a method that really fails is RAISED by the handle object (F6), so the condition is
# additional information - the same rule the failed wait already followed.
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
#   ::pis::hw::layout_table {}  owner DIAGNOSTIC (never called by Load All): refuses a session that
#                               is not empty, else SetLayout for every id of the static table, ONE
#                               LAYOUTS line (id=window count measured on THIS page), then the
#                               original layout again. Never journaled: it is a probe, and it moves
#                               the page
#   ::pis::hw::grid_capture {}  read-only: the layout id the page is IN, as ONE GRID line plus
#                               the [layout] id line for the ini
#   ::pis::hw::layout_rows {}   THE static layout table: {id windows {shape} id windows {shape} ...}
#   ::pis::hw::layout_windows {id}   window count of that id, "" when the id is not in the table
#   ::pis::hw::layout_shape {id}     the shape text exactly as docs/refs/HV_API.md sec. 2 names it
#   ::pis::hw::layout_label {id}     "<id>: <w> windows - <shape>" (the GUI combobox text)
#   ::pis::hw::layout_choices {}     every label, sorted by window count then id (combobox values)
#   ::pis::hw::layout_count {}       how many ids the table has (20)
#   ::pis::hw::reset_state {}   variants + order back to 1, nothing recorded, no last grid (tests)
#   ::pis::hw::run {op values}  run an op (the six operations call this)
#   ::pis::hw::used {op {win}}  variant number that step really used (0 = none worked)
#   ::pis::hw::build_line {}    the ONE BUILD line (stamp, grid variants, line count, layout ids)
#   ::pis::hw::announce {}      print that line to the console and to the GUI log
#
# BUILD STAMP (T-006 iteration, 2026-11-11): ::pis::BUILD is a short code written BY HAND
# when this file changes, e.g. T6i-20261111-1420, so the HyperView machine can be matched to
# a copy of this file without a guess. Sourcing this file prints ONE line,
#   BUILD T8a-20261112-1449 | make_grid variants=1 | adapter lines=<n> | layouts=20
# "layouts=" is the size of the STATIC table, so a copy without it is visible at once.
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
# F8: the "lowest layout id with that many windows" rule showed a shape nobody asked for (4x1 ->
#     2x2, 1x4 -> 2x2, 4x2 -> 2x4 on the owner's build), because several ids share one window
#     count. T-017 removes the rule: the GUI sends the ID, and the static table below is the only
#     place a shape is written down.
# T-017 CONSEQUENCES (2026-11-12):
#   1. ::pis::hw::layout_rows is THE table (20 ids, docs/refs/HV_API.md sec. 2). Nothing measures
#      a page to learn it, nothing caches it, nothing infers an id from a window count.
#   2. make_grid {id} reads GetLayout first: the same id means the effect is skipped but ONE
#      'hwi ... SetLayout <id>' line is still journaled (T-016, replayable). Otherwise it sends
#      SetLayout <id> and reads BOTH GetLayout == id and GetNumberOfWindows == the table's count
#      back, plus the per-window walk (a window without a client, or a chart window, fails it).
#   3. ::pis::hw::layout_table is an owner DIAGNOSTIC only: it refuses a session that is not empty
#      (its sweep would destroy the page) and no Load All path calls it.
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
    # The layout table is STATIC (T-017): it lives in ::pis::hw::layout_rows, is transcribed from
    # docs/refs/HV_API.md sec. 2 and is never measured, cached or inferred. Nothing about a layout
    # is kept in a namespace variable any more (the token cache of T-006..T-014 is gone).
    # The model ID '<client> AddModel' returned per window, so '<model> GetModelHandle' gets the
    # ID of the model THIS app loaded (the reference keeps AddModel's answer the same way). An
    # ARRAY on purpose: the load script writes it from inside the folded one-line script.
    if {![info exists adapt_models]} { array set adapt_models {} }
    # T-019: the GetAsyncMode answer for THIS session ("-" = not asked yet, 0 or 1). WaitForResults
    # is documented as valid only in the HyperView - MultiCore profile (docs/refs/HV_API.md sec.5,
    # S16/S17), and GetAsyncMode is the documented question (S18). Asked ONCE per session.
    if {![info exists adapt_async]} { set adapt_async "-" }
    # The wait variants that failed in THIS session (a list of variant numbers): the fallback that
    # keeps "a wait with no fallback" from ever happening - the next window uses the next form, and
    # the last form is "no wait at all".
    if {![info exists adapt_wait_bad]} { set adapt_wait_bad {} }
    # The error the optional wait raised in the last result step ("" = none). Written from INSIDE
    # the folded script, read right after it ran: a failing wait is a WARN, never an ERROR.
    if {![info exists wait_error]} { set wait_error "" }
    # Has this RUN already written its one "result wait ..." line? ::pis::hw::begin_run clears it,
    # so Load All explains the wait once per run instead of once per window.
    if {![info exists adapt_wait_notes]} { set adapt_wait_notes 0 }
    # T-027: the methods THIS build answered "could not find requested method" for, "class method"
    # -> 1. Recorded once per run and never retried (::pis::hw::absent_*); a method list of the
    # supplier help is not a promise that the owner's build has it (F9 (a) of docs/refs/HV_API.md).
    if {![info exists adapt_absent]} { set adapt_absent [dict create] }
    # The BOUNDED read-back retry of the result step (T-019): fixed small count, no infinite loop.
    # Tcl 8.5 only - "after" + "catch {update}" between the attempts, no coroutine. A test (or an
    # impatient owner) may set these to 1 / 0 on the console; they are always re-validated.
    if {![info exists retry_tries]} { set retry_tries 4 }
    if {![info exists retry_delay]} { set retry_delay 250 }
    # T-033: the VIEW receiver this session accepted (one name of ::pis::hw::view_table, "" = none
    # yet). Cached on purpose: the owner's log names the handle kind once, and windows 2..N start
    # with it instead of walking the whole list again (F14 b: a failing step was retried 5 times).
    if {![info exists adapt_view]} { set adapt_view "" }
    # T-033 item 7: the CAPTURE variant this run accepted (0 = none yet). Windows 2..N start with
    # it instead of re-trying a call this build already refused.
    if {![info exists adapt_capture]} { set adapt_capture 0 }
    # Has this RUN already said "no getter for the active view or the camera"? One line per run.
    if {![info exists view_note]} { set view_note 0 }
}

# The build stamp: short code + yyyymmdd-hhmm, written BY HAND when this file changes (the
# adapter never derives it). The BUILD line and the GUI start line carry the FULL stamp; a DIAG
# line carries the facts only (id/api/model/result), because the stamp plus 8 windows of 1/0
# lists would not fit in the 80 characters a diag line is allowed.
# T-029 (2026-11-16): the stamp names the whole src/01_scripts COPY the owner runs, not only this
# file - T-029 changed _tcl_pis_03_load_result.tcl (V5 display option, STATE DUMP), and a report
# whose stamp is still T8b cannot be told apart from the T-027 run. So it is bumped for that too.
# T-030 (2026-11-17): bumped again - _tcl_pis_03_load_result.tcl gained the TRACE/NOCHANGE/LATE
# evidence, the snap/diff API and variant V6, and _tcl_pis_99_workflow_gui.tcl now wraps the log
# pane (-wrap char). Same rule: the stamp names the whole src/01_scripts copy.
# T-032 (2026-11-18): bumped for the Capture fix after the owner's `T-011: fail 1` - the adapter's
# capture op is now a four-step image (select/view/draw/call) with a per-step trace, the variant
# order is PROVEN-first, and _tcl_pis_06_capture.tcl names files `{result}_{view}.png`.
# T-033 (2026-11-18): bumped for `T-011: fail 2` - the view step is its OWN step with its own
# receiver list (the documented poI3DViewCtrl first, ::pis::hw::set_view), the capture call is the
# only thing the variants apply to, every ReleaseHandle on session/project/page/window/client is
# gone from the generated scripts, and `[capture] on_view_unavailable` can capture the current view.
namespace eval ::pis {
    variable BUILD "T35a-20261118-2200"
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
    # T-033 / F14 c: NO ReleaseHandle here. PROVEN rule (docs/refs/HV_API_REF.md Misc, T-020 item
    # 2): ReleaseHandle is never called on session, project, page, window, view, post, model or
    # result handles - only on measure / iterator / query / node set / legend handles. The owner's
    # `fail 2` (F14 c) found `catch {pisPage ReleaseHandle}` in every capture script; `CloseStack`
    # is what the owner's own scripts use (S02/S03/S06/S07 all end with it), so that is the only
    # closing command left.
    set s {hwi CloseStack}
    return [string map [list @p@ $p] $s]
}
proc ::pis::hw::window_open {p win} {
    set s {@p@Page GetWindowHandle @p@Win @win@
@p@Win GetClientHandle @p@C}
    return "[::pis::hw::stack_open $p]\n[string map [list @p@ $p @win@ $win] $s]"
}

proc ::pis::hw::window_close {p} {
    # Nothing to release (see page_close): the handles die with the stack.
    return [::pis::hw::page_close $p]
}

# --- handle names: ONE scheme, because the build refuses a live duplicate (F15, T-034) -------
# Owner fact F15 (2026-11-18, build T33a-20261118-1930): inside ONE open stack (`hwi OpenStack`
# .. `hwi CloseStack`) creating a handle whose name is still alive raises, verbatim,
# "<name>: object with this name already exists." - and Load All died on it, because the
# window/page walks of T-033 reused ONE fixed name (`pisWin`, `pisPage`) for every iteration.
# A name is freed by `ReleaseHandle` on that handle or by `CloseStack`; nothing else.
# The PROVEN way round it, read off the owner's own scripts (see TASKLOG T-034 item 2):
#   conrod/_tmp_hv/batchImportOdb.tcl:81-86 - the walk names every handle with the loop index
#     (`page_$i`, `window_$::Import::numberOfWindows`, `client_$::Import::numberOfWindows`),
#   conrod/_tmp_hv/training.tcl:179-184 - `pg${i}$t` per page AND a per-iteration ReleaseHandle,
#   conrod/tcl_guide/hv_model_loader.tcl:2073-2132 - session/project/page once outside the loop,
#     `mlWin`/`mlClient` per window freed at the end of EVERY iteration,
#   conrod/_tmp_hv/hvTest.tcl:124-175 - handles created once and reused by the loop.
# This project uses the FIRST of those (a per-iteration NAME), because it never depends on a
# release being accepted by the build and keeps the journal line replayable as it was sent.
# This proc is the only place that spelling lives: `hname pisWin` is the plain name for a handle
# created once per stack, `hname pisWin 3` is `pisWin_3`. A builder that writes script TEXT
# passes the variable REFERENCE, e.g. `[hname pisWin {$pisWi}]` -> "pisWin_$pisWi", which the
# sent script then fills with the iteration number.
proc ::pis::hw::hname {base {k ""}} {
    if {[string trim $k] eq ""} { return $base }
    return "${base}_$k"
}

# The LAST step of a run that changed what a window DISPLAYS (T-026). Every window was already
# drawn by its own script (`<client> Draw` on the client OF THAT WINDOW, PROVEN pattern 2 of
# docs/refs/HV_API.md section 11, the same form the legend module uses), so this proc only lets Tk
# paint the redraws it was handed: ONE `update idletasks`, never a substitute for a Draw and never a
# HyperView call. When Tk is absent (a batch run) the call is skipped instead of raising, because
# a missing paint must never turn a proven step into a failure.
proc ::pis::hw::refresh {} {
    if {[llength [info commands update]] > 0} {
        catch {update idletasks}
    }
    return
}

# The ONE step that rebuilds a grid that is already on the page (T-016): '<page> SetLayout <id>'
# with the id GetLayout just answered. It is NOT executed - the page already IS that layout - it
# is only written to the journal, so a replay in a fresh session builds the same grid instead of
# finding a comment that tells the human to do it by hand (S2, A4). Sending a layout id twice is
# harmless (`docs/refs/HV_API.md` section 2, S1: the id names the layout, it is not a delta),
# which is what makes this step idempotent.
proc ::pis::hw::set_layout_step {id} {
    set s {@p@Page SetLayout @id@}
    return "[::pis::hw::stack_open pis]\n[string map [list @p@ pis @id@ $id] $s]\n[::pis::hw::page_close pis]"
}

# --- the ABSENT-METHOD rule (T-027; ONE place, every module reuses it) -----------------
# The owner's build answered on 2026-11-12, verbatim:
#   Object named: pisCt (of type poIContourCtrl) could not find requested method: SetEnabled
#   Or the method was called with incorrect arguments.
# docs/refs/HV_API.md S41 lists SetEnabled for the 2024 supplier help, so the help is not wrong -
# THIS build does not have that method. Retrying it on every window would only repeat the same
# error, so the method is recorded ONCE and every later caller skips it (windows 2..N included).
#
# The rule in full (SPEC.md A10):
#   * "could not find requested method: <name>" ALONE is proof of absence;
#   * the longer text ("... Or the method was called with incorrect arguments") is NOT proof by
#     itself: it can also mean the ARGUMENTS were wrong. It is proof only when the call used the
#     arguments the supplier documents for that method, which the caller states with
#     `documented 1`. A guessed argument is never turned into a fact.
# A method that is recorded here is never sent again in this run: a variant that needs it is
# skipped WITHOUT being counted as a failed attempt.

# Split the build's own text: answers {class name ambiguous} or "" when the text is not that
# error at all. The class is "" when the text does not name it.
proc ::pis::hw::absent_parse {text} {
    set t [string map [list "\r" " " "\n" " "] [string trim $text]]
    set name ""
    if {![regexp {could not find requested method:[ \t]*([A-Za-z_][A-Za-z0-9_]*)} $t -> name]} {
        return ""
    }
    set class ""
    if {![regexp {\(of type[ \t]+([A-Za-z_][A-Za-z0-9_]*)\)} $t -> class]} {
        set class ""
    }
    set ambiguous 0
    if {[regexp -nocase {or the method was called with incorrect arguments} $t]} {
        set ambiguous 1
    }
    return [list $class $name $ambiguous]
}

# "class name", or just the name when the class is unknown: the key the record is kept under and
# the text a log line prints.
proc ::pis::hw::absent_key {class name} {
    set c [string trim $class]
    set n [string trim $name]
    if {$c eq ""} { return $n }
    return "$c $n"
}

# Does this build lack <class> <name>? A caller that does not know the class matches by name.
proc ::pis::hw::absent_has {class name} {
    variable adapt_absent
    if {[string trim $name] eq ""} { return 0 }
    if {[dict exists $adapt_absent [::pis::hw::absent_key $class $name]]} { return 1 }
    if {[string trim $class] eq ""} {
        foreach k [dict keys $adapt_absent] {
            if {[lindex $k end] eq [string trim $name]} { return 1 }
        }
    }
    return 0
}

# Which method a build text PROVES absent, as {class name}, or "" when it proves nothing.
# `documented` says whether the call used the arguments the supplier prints for that method.
proc ::pis::hw::absent_of {text documented} {
    set parsed [::pis::hw::absent_parse $text]
    if {[llength $parsed] < 3} { return "" }
    lassign $parsed class name ambiguous
    if {$ambiguous && !$documented} { return "" }
    return [list $class $name]
}

# Record a method the build does not have. Answers "class name" the FIRST time this run stores it
# (so the caller writes its ONE INFO line), "" when it was already known or the text proves
# nothing. Never raises.
proc ::pis::hw::absent_note {text {documented 1}} {
    variable adapt_absent
    set pair [::pis::hw::absent_of $text $documented]
    if {[llength $pair] < 2} { return "" }
    lassign $pair class name
    set key [::pis::hw::absent_key $class $name]
    if {[dict exists $adapt_absent $key]} { return "" }
    dict set adapt_absent $key 1
    return $key
}

# Record a method the code KNOWS is absent (diagnostics, tests, a supplied fact).
proc ::pis::hw::absent_add {class name} {
    variable adapt_absent
    set key [::pis::hw::absent_key $class $name]
    if {$key eq ""} { return "" }
    if {[dict exists $adapt_absent $key]} { return "" }
    dict set adapt_absent $key 1
    return $key
}

# Every method recorded in this run ("class name", in the order they were found).
proc ::pis::hw::absent_list {} {
    variable adapt_absent
    return [dict keys $adapt_absent]
}

# A new RUN forgets them: the INFO line is then written once per run, not once per session.
proc ::pis::hw::absent_reset {} {
    variable adapt_absent
    set adapt_absent [dict create]
    return
}

# --- the OPTIONAL result wait (T-019) -------------------------------------------------
# Why this exists: the owner's build has no WaitForResults at all, and the supplier documents it
# as "valid only in HyperView - MultiCore profile" (docs/refs/HV_API.md sec.5, S16/S17). Pass 8
# used it because the owner's reference script did (owner fact F3), without checking that
# precondition, so every Load All stopped on the first window. It is now an OPTIMISATION with a
# guard and a skip variant: the read-back decides, never the wait.

# One line for the log: newlines flattened, cut to <n> characters with "..". n <= 0 means no cut.
proc ::pis::hw::clip {text n} {
    set t [string map [list "\r" " " "\n" " "] [string trim $text]]
    while {[string first "  " $t] >= 0} { set t [string map [list "  " " "] $t] }
    if {$n > 0 && [string length $t] > $n} { set t "[string range $t 0 [expr {$n - 2}]].." }
    return $t
}

# Read-only: is this session in the HyperView - MultiCore profile? S18 documents the question
# ('<manager> GetAsyncMode' -> true/false, "Errors: None") and S20 the handle it needs
# ('<session> GetClientManagerHandle mgr animation', the name from the supplier's own example).
# Answers 1, 0, or "-" (the question could not be asked: no wrapper, an older build, a probe that
# raised). Never raises - a missing guard must not break a load.
proc ::pis::hw::async_script {} {
    set s {set @p@A -
if {![catch {@p@S GetClientManagerHandle @p@Mgr animation}]} {
    if {![catch {set @p@A [@p@Mgr GetAsyncMode]}]} {
        if {[string is boolean -strict $@p@A]} {set @p@A [expr {$@p@A ? 1 : 0}]} else {set @p@A -}
    }
}
set @p@A}
    return "[::pis::hw::stack_open psi]\n[string map [list @p@ psi] $s]\n[::pis::hw::page_close psi]\nset psiA"
}

# The cached answer. "" wrapper or a failed probe keeps "-" (unknown) for this session: asking
# again on every window would only repeat the same silence.
proc ::pis::hw::async_mode {} {
    variable adapt_async
    if {$adapt_async ne "-"} { return $adapt_async }
    if {[llength [info commands ::pis::hw::probe]] == 0} { return "-" }
    set got ""
    if {[catch {set got [string trim [::pis::hw::probe [::pis::hw::async_script]]]}]} { return "-" }
    if {[string is boolean -strict $got]} {
        set adapt_async [expr {$got ? 1 : 0}]
    }
    return $adapt_async
}

# Which wait this run uses, as a dict {n cmd src why}. The variant list of op `result_wait` IS the
# fallback chain and its LAST entry is "no wait at all", so a plan always exists:
#   1. the human pinned a variant with ::pis::hw::use result_wait <n> -> start there;
#   2. GetAsyncMode is not 1 (or cannot be read)      -> the skip variant, reason named;
#   3. otherwise the first documented form that has not already failed in this session.
# The ONE log line per run is written here (INFO "result wait ..." or INFO "result wait skipped:
# <reason>"), so a skipped wait is visible without reading code and is never repeated per window.
proc ::pis::hw::wait_decide {} {
    variable adapt_wait_bad
    variable adapt_wait_notes
    set list [::pis::hw::variants result_wait]
    set total [llength $list]
    set skip [lindex $list [expr {$total - 1}]]
    set start [::pis::hw::at result_wait]
    if {![string is integer -strict $start] || $start < 1 || $start > $total} { set start 1 }
    set plan [dict create n [dict get $skip n] cmd "" src [dict get $skip src] why ""]
    set why ""
    if {$start >= $total} {
        set why "pinned by ::pis::hw::use result_wait $start"
    } else {
        set a [::pis::hw::async_mode]
        if {$a eq "-"} {
            set why "GetAsyncMode could not be read (poIPostManager S18), MultiCore state unknown"
        } elseif {$a != 1} {
            set why "GetAsyncMode answered $a, this session is not HyperView - MultiCore"
        } else {
            set why "no documented wait form is left"
            for {set n $start} {$n < $total} {incr n} {
                set v [lindex $list [expr {$n - 1}]]
                if {[string trim [dict get $v cmd]] eq ""} { continue }
                if {[lsearch -exact $adapt_wait_bad [dict get $v n]] >= 0} {
                    set why [format "variant %d failed earlier in this session" [dict get $v n]]
                    continue
                }
                set plan [dict create n [dict get $v n] cmd [dict get $v cmd] \
                    src [dict get $v src] why ""]
                set why ""
                break
            }
        }
    }
    if {[string trim [dict get $plan cmd]] eq ""} {
        dict set plan why $why
        if {!$adapt_wait_notes} {
            set adapt_wait_notes 1
            ::pis::hw::note INFO [format "result wait skipped: %s" $why]
        }
    } elseif {!$adapt_wait_notes} {
        set adapt_wait_notes 1
        ::pis::hw::note INFO [format "result wait: variant %d/%d <%s> (%s)" \
            [dict get $plan n] $total [::pis::hw::one_line [dict get $plan cmd]] \
            [dict get $plan src]]
    }
    return $plan
}

# Called once by each Load All: the "result wait ..." line belongs to the RUN, not to the session.
proc ::pis::hw::begin_run {} {
    variable adapt_wait_notes
    variable adapt_notes_seen
    variable sess_note
    variable wait_error
    set adapt_wait_notes 0
    set adapt_notes_seen [dict create]
    set sess_note ""
    set wait_error ""
    return
}

# Called once by each Capture run (T-033): the VIEW receiver is re-discovered and the one-per-run
# view notes are re-armed, so a second run logs the accepted receiver again instead of silently
# reusing a name from a build state nobody saw.
proc ::pis::hw::begin_capture {} {
    variable adapt_view
    variable adapt_capture
    variable view_note
    set adapt_view ""
    set adapt_capture 0
    set view_note 0
    return
}

# Called once by each Load Legend run (T-035): the variant that worked last time is forgotten (the
# PROVEN form is tried first again) and the one-per-run `... must be checked by eye` note is armed.
# The build's own answer about `GetDisplayOptions legend` is NOT forgotten: it is a property of the
# session, like the absent-method list (T-027).
proc ::pis::hw::begin_legend {} {
    variable adapt_legend
    variable adapt_legend_eye
    set adapt_legend 0
    set adapt_legend_eye 0
    return
}

# The session's post-SetResult condition of the window that just ran (T-019 pass 12). A NOTE, not
# a verdict: F7 says this build writes "(poIPost::GetResultList)" there while the result really is
# attached, so only ::pis::hw::check_result_attached may fail a step. Written by result_cmd,
# READ (and logged at most once per distinct text) by load_result_in_window.
# The notes already logged in this session, so 8 windows cannot print the same line 8 times.
namespace eval ::pis::hw {
    variable sess_note ""
    variable adapt_notes_seen [dict create]
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
for {set @p@Wi 1} {$@p@Wi <= $@p@NW} {incr @p@Wi} {catch {@p@Page GetWindowHandle @W@ $@p@Wi}; catch {@W@ GetClientHandle @C@}; if {![catch {@C@ GetModelList} @p@Ml]} {incr @p@Sum [llength $@p@Ml]}}}
    # F15 (T-034): the walk's handles carry the iteration number (::pis::hw::hname).
    set s [string map [list @W@ [::pis::hw::hname @p@Win {$@p@Wi}] \
                            @C@ [::pis::hw::hname @p@C {$@p@Wi}]] $s]
    return "[::pis::hw::stack_open psi]\n[string map [list @p@ psi] $s]\n[::pis::hw::page_close psi]\nset psiSum"
}

# GONE ON PURPOSE (pass 7 / pass 8): grid_token, legacy_token, sweep_tokens, sweep_script,
# grid_sweep and sweep_table had no reader left once the layout became an integer id; a dead proc
# is a lie about what this file can do.

# --- THE layout table (T-017): ONE static place, docs/refs/HV_API.md sec. 2 -------------
# id | windows | shape. The shape text is the doc's own wording, copied verbatim; where the doc
# gives no shape for an id ("four windows (shape not stated)") the label says exactly that and no
# name is invented. This is the ONLY place a layout id or its window count is written down:
# nothing measures a page to learn it, nothing caches it, nothing infers an id from a window
# count (owner fact F8: several ids share one count, so a count cannot name a shape).
proc ::pis::hw::layout_rows {} {
    return {
        0 1 {one window}
        1 2 {two windows (left and right)}
        2 2 {two windows (top and bottom)}
        3 3 {three windows (one left and two right)}
        4 3 {three windows (two left and one right)}
        5 3 {three windows (two top and one bottom)}
        6 3 {three windows (one top and two bottom)}
        7 3 {three windows (left, middle, and right)}
        8 3 {three windows (top, middle, and bottom)}
        9 4 {four windows (shape not stated)}
        10 6 {three rows of two}
        11 6 {two rows of three}
        12 9 {nine windows}
        13 12 {four rows of three}
        14 12 {three rows of four}
        15 16 {sixteen windows}
        16 4 {four rows of one}
        17 8 {four rows of two}
        18 4 {one row of four}
        19 8 {two rows of four}
    }
}

# Window count of ONE id, or "" when the id is not in the table. Only the exact integer text is an
# id: "18x1", "4 x 1" or "a" answer "" - a size is not an id (F1/F8).
proc ::pis::hw::layout_windows {id} {
    set lid [string trim $id]
    if {![string is integer -strict $lid]} { return "" }
    foreach {rid wins shape} [::pis::hw::layout_rows] {
        if {$rid == $lid} { return $wins }
    }
    return ""
}

# The doc's shape text for ONE id, "" when the id is not in the table.
proc ::pis::hw::layout_shape {id} {
    set lid [string trim $id]
    if {![string is integer -strict $lid]} { return "" }
    foreach {rid wins shape} [::pis::hw::layout_rows] {
        if {$rid == $lid} { return $shape }
    }
    return ""
}

# The GUI combobox text: "<id>: <w> windows - <shape>" ("" for an id outside the table, so a
# caller can tell "unknown" from "one window").
proc ::pis::hw::layout_label {id} {
    set wins [::pis::hw::layout_windows $id]
    if {$wins eq ""} { return "" }
    return [format "%s: %s windows - %s" \
        [string trim $id] $wins [::pis::hw::layout_shape $id]]
}

# Order of the combobox: window count first, then id - so every 4-window entry sits together and
# the owner compares shapes instead of hunting for an id.
proc ::pis::hw::layout_cmp {a b} {
    set wa [lindex $a 0]
    set ia [lindex $a 1]
    set wb [lindex $b 0]
    set ib [lindex $b 1]
    if {$wa != $wb} { return [expr {$wa < $wb ? -1 : 1}] }
    if {$ia != $ib} { return [expr {$ia < $ib ? -1 : 1}] }
    return 0
}

# Every label of the table, sorted by window count then id (the combobox values).
proc ::pis::hw::layout_choices {} {
    set pairs {}
    foreach {rid wins shape} [::pis::hw::layout_rows] {
        lappend pairs [list $wins $rid]
    }
    set labels {}
    foreach pair [lsort -command ::pis::hw::layout_cmp $pairs] {
        lappend labels [::pis::hw::layout_label [lindex $pair 1]]
    }
    return $labels
}

# How many ids the table has (20): the BUILD line prints it, so a copy without the table is
# visible in one line.
proc ::pis::hw::layout_count {} {
    return [expr {[llength [::pis::hw::layout_rows]] / 3}]
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

# OWNER DIAGNOSTIC (T-017): what does THIS build really answer for every id of the table?
# '<page> SetLayout <id>' for all 20 ids, read '<page> GetNumberOfWindows' after each, put the
# original layout back and print ONE LAYOUTS line (id=count measured, in table order). It MOVES the
# page, so it is a probe (never journaled) and it REFUSES a session that is not empty - a sweep
# there would take the models the owner just loaded with it. NO Load All path calls it.
# Returns {id count id count ...} for the ids the page accepted.
proc ::pis::hw::layout_table {} {
    ::pis::hw::need_exec
    set models ""
    if {[catch {set models [string trim [::pis::hw::probe [::pis::hw::check_models_on_page]]]} merr]} {
        set models -1
        ::pis::hw::note WARN "layout_table: the page could not be read: [string trim $merr]"
    }
    if {$models ne "0"} {
        if {$models eq "-1"} {
            set why "the page did not answer how many models it holds"
        } else {
            set why [format "%s model(s) on the page" $models]
        }
        ::pis::hw::status [format "Error: layout_table refused: the session is not empty (%s)" $why]
        ::pis::hw::note ERROR [format "layout_table: refused - the session is not empty (%s); File > New, then run it again" $why]
        error [format "layout_table refused: session not empty (%s)" $why]
    }
    set ids {}
    foreach {rid wins shape} [::pis::hw::layout_rows] { lappend ids $rid }
    set s {set @p@Prev -
if {![catch {set @p@Prev [@p@Page GetLayout]}]} {set @p@Prev [string trim $@p@Prev]}
set @p@Out {}
foreach @p@N {@ids@} {
    catch {@p@Page SetLayout $@p@N}
    set @p@A -1
    if {![catch {set @p@A [@p@Page GetNumberOfWindows]}]} {
        if {![string is integer -strict $@p@A]} { set @p@A [llength $@p@A] }
    }
    lappend @p@Out $@p@N $@p@A
}
if {[string is integer -strict $@p@Prev]} {catch {@p@Page SetLayout $@p@Prev}}
set @p@Out}
    set s [string map [list @ids@ $ids] $s]
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
    ::pis::hw::layout_line $table
    return $table
}

# Read the layout the page is IN ('<page> GetLayout' answers the INTEGER id, F1) and hand the
# owner the ini line that stores it. Read-only, no SetLayout, no journal: ONE line under 80
# characters plus the one ini line to paste by hand.
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
    set label [::pis::hw::layout_label $lay]
    if {$label eq ""} {
        puts [format "# id %s is not in the table: \[layout\] id = 19 stays" $lay]
    } else {
        puts [format "# paste into 00_config/pis_workflow_config.ini: \[layout\] id = %s   (%s)" \
            $lay $label]
    }
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
    if {![catch {@p@Page GetWindowHandle @W@ $@p@I}]} {
        incr @p@H
        if {![catch {@W@ GetClientHandle @C@}]} {incr @p@Ct}
    }
}
set @p@L -
if {![catch {set @p@L [@p@Page GetLayout]}]} {
    set @p@L [string trim $@p@L]
    if {$@p@L eq ""} {set @p@L -}
}
set @p@Out [list $@p@A $@p@H $@p@Ct $@p@L]}
    # F15 (T-034): per-iteration handle names - one fixed name per iteration raised
    # "pisWin: object with this name already exists." on the owner's build.
    set s [string map [list @W@ [::pis::hw::hname @p@Win {$@p@I}] \
                            @C@ [::pis::hw::hname @p@C {$@p@I}]] $s]
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
    if {[catch {@p@Page GetWindowHandle @W@ $@p@I}]} {
        if {!$@p@Bad} { set @p@Bad $@p@I }
        continue
    }
    incr @p@H
    if {[catch {@W@ GetClientHandle @C@}]} {
        if {!$@p@Bad} { set @p@Bad $@p@I }
        continue
    }
    incr @p@Ct
    if {[catch {@C@ GetModelList}]} {
        error "make_grid: window $@p@I is not a HyperView window (client type plot)"
    }
}
if {$@p@A != @p@Want || $@p@H != $@p@A || $@p@Ct != $@p@A} {
    if {$@p@Bad} {
        error "grid: api=$@p@A handles=$@p@H clients=$@p@Ct wanted=@p@Want (window $@p@Bad did not answer)"
    }
    error "grid: api=$@p@A handles=$@p@H clients=$@p@Ct wanted=@p@Want"
}
set @p@Got @p@Want}
    # F15 (T-034): EVERY window of the read-back has its OWN handle name.
    set s [string map [list @W@ [::pis::hw::hname @p@Win {$@p@I}] \
                            @C@ [::pis::hw::hname @p@C {$@p@I}]] $s]
    set s [string map [list @p@Want $count] $s]
    return "[::pis::hw::stack_open psi]\n[string map [list @p@ psi] $s]\n[::pis::hw::page_close psi]\nset psiGot"
}

# The read-back every make_grid step is judged by (T-017) and the ONLY place the layout rule
# lives: '<page> GetLayout' must equal the asked id AND '<page> GetNumberOfWindows' must equal the
# table's window count for that id, then the same per-window walk check_grid uses (a window that
# answers no client handle, or a chart window, fails it). Answers "<layout id>:<window count>"
# on success and RAISES otherwise, naming the id, the expected count and what was read:
#   layout: GetLayout=9 windows=4 wanted id=18 with 4 window(s)
proc ::pis::hw::check_layout {id count} {
    set s {set @p@L -
if {![catch {set @p@L [@p@Page GetLayout]}]} {set @p@L [string trim $@p@L]}
set @p@A [@p@Page GetNumberOfWindows]
if {![string is integer -strict $@p@A]} {set @p@A [llength $@p@A]}
set @p@H 0
set @p@Ct 0
set @p@Bad 0
for {set @p@I 1} {$@p@I <= $@p@A} {incr @p@I} {
    if {[catch {@p@Page GetWindowHandle @W@ $@p@I}]} {
        if {!$@p@Bad} { set @p@Bad $@p@I }
        continue
    }
    incr @p@H
    if {[catch {@W@ GetClientHandle @C@}]} {
        if {!$@p@Bad} { set @p@Bad $@p@I }
        continue
    }
    incr @p@Ct
    if {[catch {@C@ GetModelList}]} {
        error "make_grid: window $@p@I is not a HyperView window (client type plot)"
    }
}
if {$@p@L ne "@p@Id" || $@p@A != @p@Want} {
    error "layout: GetLayout=$@p@L windows=$@p@A wanted id=@p@Id with @p@Want window(s)"
}
if {$@p@H != $@p@A || $@p@Ct != $@p@A} {
    if {$@p@Bad} {
        error "grid: api=$@p@A handles=$@p@H clients=$@p@Ct wanted=@p@Want (window $@p@Bad did not answer)"
    }
    error "grid: api=$@p@A handles=$@p@H clients=$@p@Ct wanted=@p@Want"
}
set @p@Got "$@p@L:$@p@A"}
    # F15 (T-034): per-iteration handle names (see ::pis::hw::hname).
    set s [string map [list @W@ [::pis::hw::hname @p@Win {$@p@I}] \
                            @C@ [::pis::hw::hname @p@C {$@p@I}]] $s]
    set s [string map [list @p@Id $id @p@Want $count @p@ psi] $s]
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

# The result read-back of one window (T-019): the window must hold exactly ONE model, and that
# model's result controller must answer a result FILE. Both documented calls are asked:
#   poIModel GetResultCtrlHandle      (S25: raises with no result, 0 on success)
#   poIResultCtrl GetNumberOfSubcases (S27: an integer; 0 = no subcase in the file)
# A BOUNDED retry (::pis::hw::retry_tries, default 4, and ::pis::hw::retry_delay ms) is allowed
# because a load may still be in flight; there is no infinite loop and no dependency on
# WaitForResults. Answers "1" on success and RAISES with the window, the attempt count and
# HyperView's own last words otherwise - a timeout is a FAIL, never a hang and never a silent OK.
proc ::pis::hw::check_result_attached {win} {
    set s {set @p@Ok 0
set @p@Why "the retry never ran"
set @p@K 4
catch {set @p@K $::pis::hw::retry_tries}
if {![string is integer -strict $@p@K] || $@p@K < 1} {set @p@K 1}
set @p@D 250
catch {set @p@D $::pis::hw::retry_delay}
if {![string is integer -strict $@p@D] || $@p@D < 0} {set @p@D 0}
set @p@N [llength [@p@C GetModelList]]
if {$@p@N != 1} {
    error "window @win@ holds $@p@N model(s), expected exactly 1"
}
set @p@Mid [@p@C GetActiveModel]
if {[info exists ::pis::hw::adapt_models(@win@)]} {set @p@Mid $::pis::hw::adapt_models(@win@)}
if {![string is integer -strict $@p@Mid] || $@p@Mid <= 0} {
    error "window @win@ has no model id (GetActiveModel answered '$@p@Mid')"
}
@p@C GetModelHandle @p@M $@p@Mid
for {set @p@T 1} {$@p@T <= $@p@K} {incr @p@T} {
    set @p@Why ""
    # F15 (T-034): the result handle carries the attempt number (::pis::hw::hname). A second
    # attempt under the same name is what the owner's build refuses: "psiR: object with this
    # name already exists." - the retry would then never see a result.
    if {![catch {@p@M GetResultCtrlHandle @R@} @p@Why]} {
        set @p@Sub 0
        if {[catch {set @p@Sub [@R@ GetNumberOfSubcases]} @p@Why]} {set @p@Sub 0}
        if {[string is integer -strict $@p@Sub] && $@p@Sub > 0} {
            set @p@Ok 1
            break
        }
        set @p@Why "GetNumberOfSubcases answered '$@p@Sub'"
    }
    if {$@p@T < $@p@K} {
        catch {after $@p@D}
        catch {update}
    }
}
if {!$@p@Ok} {
    error "window @win@: no result after $@p@K read-back attempt(s): [string trim $@p@Why]"
}
set @p@Ok}
    set s [string map [list @R@ [::pis::hw::hname @p@R {$@p@T}]] $s]
    set s [string map [list @p@ psi @win@ $win] $s]
    return "[::pis::hw::window_open psi $win]\n$s\n[::pis::hw::window_close psi]\nset psiOk"
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
        set @p@Ctrl 1
    }
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
    if {![catch {@p@Page GetWindowHandle @W@ $@p@I}]} {
        if {![catch {@W@ GetClientHandle @C@}]} {
            if {![catch {@C@ GetModelList}]} {set @p@T H} else {set @p@T P}
        }
    }
    lappend @p@Out $@p@T
}
set @p@Out}
    # F15 (T-034): per-iteration handle names (see ::pis::hw::hname).
    set s [string map [list @W@ [::pis::hw::hname @p@Win {$@p@I}] \
                            @C@ [::pis::hw::hname @p@C {$@p@I}]] $s]
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
    if {![catch {@p@Page GetWindowHandle @W@ $@p@I}]} {
        lappend @p@Open $@p@I
    }
}
set @p@Op [join $@p@Open ,]
if {$@p@Op eq ""} {set @p@Op -}
set @p@Out "page=$@p@PgI pages=$@p@Pages layout='$@p@Lay' wins=$@p@W open=$@p@Op"}
    # F15 (T-034): per-iteration handle names (see ::pis::hw::hname).
    set s [string map [list @W@ [::pis::hw::hname @p@Win {$@p@I}]] $s]
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
    set s {
for {set pisWi 1} {$pisWi <= %count} {incr pisWi} {catch {pisPage GetWindowHandle @W@ $pisWi}; catch {@W@ GetClientHandle @C@}}
}
    # F15 (T-034): handle names carry the loop index (batchImportOdb.tcl:81-86).
    return [string map [list @W@ [::pis::hw::hname pisWin {$pisWi}] \
                           @C@ [::pis::hw::hname pisC {$pisWi}]] $s]
}


# The per-window result step, as a script template (T-019). @idx@ = the window token (%index or a
# number), @path@ = the result-file token (%path), @wait@ = the wait fragment chosen by
# ::pis::hw::wait_decide ("" = skip this time). Order, and the reason for each line:
#   model id  - the id AddModel RETURNED (::pis::hw::adapt_models) or the client's active model;
#               a 0/empty answer is a NAMED failure (poIPost AddModel, S21: "model ID, or Null_ID
#               (0) if AddModel failed"), so no result is ever attached to nothing;
#   flush     - GetError read BEFORE SetResult: the read CLEARS the condition (S19), so whatever
#               shows up after SetResult belongs to THIS call and not to the window before it;
#   SetResult - poIModel SetResult (S9) on THAT model's handle; its warning code cannot fail the
#               step, the read-back decides;
#   note      - GetError read right after SetResult is kept as a NOTE in ::pis::hw::sess_note,
#               never as a failure (pass 12, owner-measured F7): the owner's build answers
#               "(poIPost::GetResultList)" on window 2 while the result IS attached, and the
#               supplier's own rule is that a method failure is RAISED, not reported through the
#               session condition (F6). Only the read-back can fail a step (T-019);
#   wait      - the optional, guarded fragment (may be empty). Its own error is caught INTO
#               ::pis::hw::wait_error: a failed wait is a WARN, never a failed step;
#   clear     - GetError once more, so a note from this window cannot sit in front of the next.
proc ::pis::hw::result_cmd {idx path wait} {
    set s {set pisMid [pisC GetActiveModel]
if {[info exists ::pis::hw::adapt_models(@idx@)]} {set pisMid $::pis::hw::adapt_models(@idx@)}
if {![string is integer -strict $pisMid] || $pisMid <= 0} {
    error "window @idx@: AddModel returned no model id (got '$pisMid'), so no result can attach - check that the model really loads in this window"
}
pisC GetModelHandle pisM $pisMid
set ::pis::hw::sess_note ""
catch {pisS GetError}
pisM SetResult @path@
set pisSE ""
catch {set pisSE [pisS GetError]}
if {[string trim $pisSE] ne "" && [string trim $pisSE] ne "0"} {
    set ::pis::hw::sess_note [string trim $pisSE]
}
set ::pis::hw::wait_error ""
catch {
@wait@
} ::pis::hw::wait_error
catch {pisS GetError}}
    set body [string map [list @idx@ $idx @path@ $path @wait@ $wait] $s]
    return "[::pis::hw::window_open pis $idx]\n$body\n[::pis::hw::window_close pis]"
}

# --- ONE capture is a SEQUENCE of steps (T-032; the view split out in T-033) -------------
# The owner's report split one image into steps and asked to see each of them in the log:
# select the window, activate the VIEW the ticked row names, let the window redraw, and only
# then grab the image. T-033 (owner `T-011: fail 2`, F14) separates them for good:
#   * the CAPTURE CALL is the only thing a variant list applies to;
#   * the VIEW step has its OWN receiver list (::pis::hw::view_table) and is executed ONCE per
#     image, before the draw, so a failing view can never be retried five times (F14 b);
#   * a failing view stops the image ONCE, with `capture call not attempted` in the message.
# Every step is ONE complete `hwi` script sent on its own (so its own STEP line and its own raw
# answer exist); the journal keeps ONE replayable line per image, built from the SAME step texts.
#
# Sources (docs/refs/HV_OWNER_capture_hits.txt holds the mined scripts; HV_API.md sec.6 the docs):
#   select : conrod/tcl_guide/hv_model_loader.tcl:2101-2102 (`mlPage SetActiveWindow $w`,
#            best effort in the owner's own loader) + conrod/_tmp_hv/ppt2.tcl:185
#   view   : poI3DViewCtrl SetActiveView (HV_API.md S99, 2024 AND 2026 help: syntax
#            `poI3DViewCtrl_handle SetActiveView active name`, example `view_handle SetActiveView
#            true "View 1"` on the handle `<window> GetViewControlHandle` hands out). The owner's
#            literal `SetActiveView true "View 1"` is kept verbatim; his `fail 2` proved the PAGE
#            is not the receiver (hwIPage has no such method).
#   draw   : docs/refs/HV_API_REF.md section 4 patterns 5/6 (S06:241-252 / 255-262: `Draw` and
#            then `CaptureScreenToSize`) + conrod/tcl_guide/hv_model_loader.tcl:2120-2121
proc ::pis::hw::capture_frag {step} {
    switch -- $step {
        select { return {pisPage SetActiveWindow %index} }
        view   { return {pisPage GetWindowHandle pisWin %index
pisWin GetViewControlHandle pisV
pisV SetActiveView true %view} }
        draw   { return {pisC Draw} }
    }
    error "::pis::hw::capture_frag: unknown capture step '$step' (expected select, view or draw)"
}

# ONE step as ONE complete script (its own stack, closed again). `callcmd` is the ALREADY filled
# capture fragment of the variant; it is spliced in as script text, never as a quoted value.
proc ::pis::hw::capture_step_script {step values {callcmd ""}} {
    if {$step eq "call"} {
        # The capture call's OWN answer is the script's last word, so the caller can fail a
        # variant by the documented integer code (0 = success) and show it in the STEP line.
        return "[::pis::hw::fill [::pis::hw::window_open pis %index] $values]\nset pisCapRet \[$callcmd\]\n[::pis::hw::window_close pis]\nset pisCapRet"
    }
    if {$step eq "draw"} {
        return "[::pis::hw::fill [::pis::hw::window_open pis %index] $values]\n[::pis::hw::capture_frag draw]\n[::pis::hw::window_close pis]"
    }
    if {$step eq "view"} {
        # The view step of the FIRST receiver (the documented one). ::pis::hw::set_view sends the
        # receiver that is really used; this text is only what a plain `view` step looks like.
        return [::pis::hw::fill "[::pis::hw::stack_open pis]\n[::pis::hw::capture_frag view]\n[::pis::hw::page_close pis]" $values]
    }
    return [::pis::hw::fill "[::pis::hw::stack_open pis]\n[::pis::hw::capture_frag $step]\n[::pis::hw::page_close pis]" $values]
}

# The WHOLE image as ONE replayable script: the steps in order inside a single stack, exactly
# what the journal keeps. `layout` 0 leaves the page's active window alone (the [Capture] button
# already captures the active window); 1 makes window %index active first ([Apply all layout]).
# `viewfrag` is the view step of the receiver that was ACCEPTED ("" = the view step was skipped
# by `[capture] on_view_unavailable = capture_current`), so the replay asks the same handle kind.
proc ::pis::hw::capture_full_script {layout values callcmd {viewfrag ""}} {
    set head {hwi OpenStack
hwi GetSessionHandle pisS
pisS GetProjectHandle pisP
set pisPgI [pisP GetActivePage]
pisP GetPageHandle pisPage $pisPgI}
    set mid [list]
    if {$layout} { lappend mid [::pis::hw::capture_frag select] }
    if {[string trim $viewfrag] ne ""} { lappend mid $viewfrag }
    lappend mid {pisPage GetWindowHandle pisWin %index
pisWin GetClientHandle pisC
pisC Draw}
    lappend mid "@@CAPCALL@@"
    set tail {hwi CloseStack
set pisCapRet}
    # The call fragment is spliced in AFTER the fill: it already holds real values, and a path
    # that happens to contain "%width" must never be rewritten by a second pass.
    set filled [::pis::hw::fill [join [list $head [join $mid "\n"] $tail] "\n"] $values]
    # F15 (T-034): ONE stack, ONE creation per name. The view fragment and the draw fragment both
    # open `pisWin` (and `pisC` for the client receiver), which the owner's build refuses:
    # "pisWin: object with this name already exists." An IDENTICAL line is therefore emitted ONCE,
    # at the position it was first written - the replay keeps working and no handle is created
    # twice. The comparison is made AFTER the fill, because a caller may hand in an already
    # filled view fragment (::pis::hw::capture_image does) and `pisWin 1` must equal `pisWin %index`.
    set lines [list]
    set seen [dict create]
    foreach line [split $filled "\n"] {
        set l [string trim $line]
        if {$l eq "" || [dict exists $seen $l]} { continue }
        dict set seen $l 1
        lappend lines $l
    }
    set script [join $lines "\n"]
    return [string map [list "@@CAPCALL@@" "set pisCapRet \[$callcmd\]"] $script]
}

# --- the VIEW step and its receivers (T-033, HV_API.md S99-S104) -------------------------
# The receiver list, in the order T-033 item 3 fixes. The DOCUMENTED receiver comes first: the
# 3D view control handle of window k, because `poI3DViewCtrl SetActiveView active name` is
# documented (2024 and 2026) with exactly the owner's literal, and the supplier's own example
# gets that handle with `<window> GetViewControlHandle view_handle`. The other three are
# UNVERIFIED-GUESS receivers: the owner's literal tried on a documented handle kind, only until
# the first one answers without an error, each one's `type` being the build's own name.
# Fields: n, rec (short name), type (handle type the build names), open (the getter lines),
# handle (the variable the call is sent to), src.
proc ::pis::hw::view_table {} {
    return [list \
        [dict create n 1 rec viewctrl type poI3DViewCtrl handle pisV \
            open {pisPage GetWindowHandle pisWin %index
pisWin GetViewControlHandle pisV} \
            src {docs S99 poI3DViewCtrl SetActiveView (2024+2026 help; the supplier's own example is `view_handle SetActiveView true "View 1"`) + S103 hwIWindow GetViewControlHandle}] \
        [dict create n 2 rec window type hwIWindow handle pisWin \
            open {pisPage GetWindowHandle pisWin %index} \
            src {UNVERIFIED-GUESS (receiver; literal from owner)}] \
        [dict create n 3 rec client type poIPost handle pisC \
            open {pisPage GetWindowHandle pisWin %index
pisWin GetClientHandle pisC} \
            src {UNVERIFIED-GUESS (receiver; literal from owner)}] \
        [dict create n 4 rec session type hwISession handle pisS \
            open {} \
            src {UNVERIFIED-GUESS (receiver; literal from owner)}]]
}

# The view step as ONE script for ONE receiver: its own stack, the getter lines of that receiver,
# then the owner's literal with the name as ONE argument (spaces and dots intact, no `[` in it).
proc ::pis::hw::view_step_script {rec values} {
    set open [dict get $rec open]
    set h [dict get $rec handle]
    set body "$h SetActiveView true %view"
    if {[string trim $open] ne ""} { set body "$open\n$body" }
    return [::pis::hw::fill "[::pis::hw::stack_open pis]\n$body\n[::pis::hw::page_close pis]" $values]
}

# The view step text as it goes into the journal line of an image.
proc ::pis::hw::view_frag {rec} {
    set open [dict get $rec open]
    set body "[dict get $rec handle] SetActiveView true %view"
    if {[string trim $open] ne ""} { return "$open\n$body" }
    return $body
}

# The read-back of the ACTIVE VIEW - DOCUMENTED since T-033 (S100: `<viewctrl> GetActiveView`
# answers the name of the view marked active, "Current View" when none is, and "Whatever is
# currently displayed in the window will always be the same as the active view"). It replaces the
# empty getter of T-032, which existed only because no page had been fetched yet.
proc ::pis::hw::view_getter {} {
    return {psiPage GetWindowHandle psiWin %index
psiWin GetViewControlHandle psiV
set psiRB [psiV GetActiveView]}
}

# The documented VIEW LIST of one window (S101: `<viewctrl> GetViewList <list var>` answers every
# memorized view of the active window; it RAISES when the list is empty). Used to refuse a name the
# window does not offer BEFORE anything is sent to the session.
proc ::pis::hw::view_list_getter {} {
    return {psiPage GetWindowHandle psiWin %index
psiWin GetViewControlHandle psiV
set psiRB {}
psiV GetViewList psiRB}
}

# The camera of one window (S104: `GetViewMatrix`), the EVIDENCE getter used only when the build
# has no GetActiveView: a SetActiveView that changes the camera did something, one that does not
# may have been a no-op - and the image is the only judge either way.
proc ::pis::hw::camera_getter {} {
    return {psiPage GetWindowHandle psiWin %index
psiWin GetViewControlHandle psiV
set psiRB [psiV GetViewMatrix]}
}

# The answer of one getter template for window `index`; "" when the template is empty or cannot be
# asked (a build without the method, no wrapper, no HyperView) - a read-back never raises.
# Every template ends by storing its answer in `psiRB` (the other read-back scripts keep `psiGot`
# for themselves), so this proc returns exactly that variable after the stack is closed.
proc ::pis::hw::read_back {template index} {
    set t [string trim $template]
    if {$t eq ""} { return "" }
    if {[llength [info commands ::pis::hw::probe]] == 0} { return "" }
    set script [::pis::hw::fill \
        "[::pis::hw::stack_open psi]\n$t\n[::pis::hw::page_close psi]\nset psiRB" \
        [dict create %index $index]]
    set got ""
    if {[catch {::pis::hw::probe $script} got]} { return "" }
    return [string trim $got]
}

proc ::pis::hw::active_view {index} {
    return [::pis::hw::read_back [::pis::hw::view_getter] $index]
}

proc ::pis::hw::camera_view {index} {
    return [::pis::hw::read_back [::pis::hw::camera_getter] $index]
}

# The `now:` half of a STEP log line: a read-only question about the session, never journaled.
# `select` asks the page for its active window (S33), `view` asks the view control for the name of
# the active view (S100) - a wrong view is visible in the STEP line itself; draw/call have no state.
proc ::pis::hw::capture_now {step index} {
    if {$step eq "select"} {
        set body {set psiAW [psiPage GetActiveWindow]}
        set script "[::pis::hw::stack_open psi]\n$body\n[::pis::hw::page_close psi]\nset psiAW"
        set got ""
        if {[catch {::pis::hw::probe $script} got]} {
            return [format "active window ? (%s)" [::pis::hw::clip [string trim $got] 120]]
        }
        return [format "active window %s" [string trim $got]]
    }
    if {$step eq "view"} {
        if {[::pis::hw::absent_has "" GetActiveView]} { return "active view ? (GetActiveView absent)" }
        set got [::pis::hw::active_view $index]
        if {$got eq ""} { return "active view ? (the view control did not answer)" }
        return [format "active view '%s'" $got]
    }
    return "-"
}

# op -> ordered list of variant dicts, fields:
#   n     1..N in trial order (start variant = 1 unless ::pis::hw::use moved it)
#   via   hwi = one handle script through exec_hwi; hwc = one command through exec
#   cmd   the script; %tokens are filled by ::pis::hw::fill
#   check read-only script run afterwards through ::pis::hw::probe ("" = no read-back)
#   local 1 = that check asks no HyperView question (a file check); every other check is an
#         `hwi` read-back, which is the default and the only form the adapter test accepts.
#         T-032: the capture op needs no `local` variant any more - its proof is the file it
#         wrote, asked in ::pis::hw::capture_image after the steps (see the capture table).
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
for {set pisWi 1} {$pisWi <= $pisNW} {incr pisWi} {pisPage GetWindowHandle @W@ $pisWi; @W@ GetClientHandle @C@; @C@ RemoveAllModels}
}
    # reset_page / reset_all: the fallback walk. The walk is sourced
    # (conrod/_tmp_hv/batchImportOdb.tcl:79-88); the DeleteModel verb is NOT.
    set reset_page {
set pisNW [pisPage GetNumberOfWindows]
for {set pisWi 1} {$pisWi <= $pisNW} {incr pisWi} {pisPage GetWindowHandle @W@ $pisWi; @W@ GetClientHandle @C@; foreach pisMi [@C@ GetModelList] {if {[string is integer -strict $pisMi] && $pisMi > 0} {@C@ DeleteModel $pisMi}}}
}
    set reset_all {
set pisNP [pisP GetNumberOfPages]
for {set pisPi 1} {$pisPi <= $pisNP} {incr pisPi} {pisP GetPageHandle @P@ $pisPi; set pisNW [@P@ GetNumberOfWindows]; for {set pisWi 1} {$pisWi <= $pisNW} {incr pisWi} {@P@ GetWindowHandle @W@ $pisWi; @W@ GetClientHandle @C@; foreach pisMi [@C@ GetModelList] {if {[string is integer -strict $pisMi] && $pisMi > 0} {@C@ DeleteModel $pisMi}}}}
}
    # F15 (T-034): ONE handle name per iteration, the proven walk's way
    # (batchImportOdb.tcl:81-86 names every handle with the loop index). Reusing `pisWin` for
    # window 2 is what the owner's build refused: "pisWin: object with this name already exists."
    foreach body {reset_remove reset_page} {
        set $body [string map [list @W@ [::pis::hw::hname pisWin {$pisWi}] \
                                    @C@ [::pis::hw::hname pisC {$pisWi}]] [set $body]]
    }
    set reset_all [string map [list @P@ [::pis::hw::hname pisPage {$pisPi}] \
                                    @W@ [::pis::hw::hname pisWin {$pisWi}] \
                                    @C@ [::pis::hw::hname pisC {$pisWi}]] $reset_all]
    # The result step (T-019) is built by ::pis::hw::result_cmd, which ::pis::hw::load_result_in_window
    # re-builds per window so the OPTIONAL wait chosen by ::pis::hw::wait_decide is in it. The table
    # entry below therefore carries NO wait: the documented read-back alone has to pass.

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
            cmd "[::pis::hw::window_open pis %win]\nset pisMid \[pisC AddModel %path\]\nif {!\[string is integer -strict \$pisMid\] || \$pisMid <= 0} {error \"window %win: AddModel returned '\$pisMid' for %path - the model did not load (poIPost AddModel answers 0 on failure, HV_API.md sec.5 S21)\"}\nset ::pis::hw::adapt_models(%win) \$pisMid\npisC Draw\n[::pis::hw::window_close pis]" \
            check [::pis::hw::check_models_in_window %win] want 1 \
            src {docs/refs/HV_API.md sec.5 S21 (poIPost AddModel: "the model ID, or Null_ID (0) if AddModel failed") + conrod/_tmp_hv/training.tcl:36-43 (the returned id is kept)} \
            note {window %win holds exactly one model, its id is kept for the result step, and a 0 from AddModel is a named failure}] \
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
            check [::pis::hw::check_layout %id %count] want %want \
            src {conrod/_tmp_hv/batchImportOdb.tcl:105,126 (GetLayout / SetLayout) + owner fact F1 2026-11-11 (SetLayout reads a layout ID) + S1/S2/S3 (docs/refs/HV_API.md sec. 2)} \
            note {GetLayout == %id and %count HYPERVIEW windows proven by the read-back (no SetClientType: training.tcl:9,20 would make a chart)}]]
    dict set t load_result_in_window [list \
        [dict create n 1 via hwi \
            cmd [::pis::hw::result_cmd %index %path ""] \
            check [::pis::hw::check_result_attached %index] want 1 \
            src {docs/refs/HV_API.md sec.4 (poIModel SetResult S9, GetResultCtrlHandle S25, poIResultCtrl GetNumberOfSubcases S27) + sec.5 (poIPost AddModel S21, GetError S19)} \
            note {window %index holds exactly one model AND its own result file, proved by a BOUNDED read-back - never by WaitForResults}]]
    # --- the OPTIONAL result wait (T-019) -------------------------------------------------
    # Its own variant list, because it IS the fallback chain: two documented forms, then "no wait
    # at all". ::pis::hw::wait_decide picks from it (only when poIPostManager GetAsyncMode answers 1)
    # and the LAST entry must always be the skip - a wait with no fallback is not allowed.
    dict set t result_wait [list \
        [dict create n 1 via hwi frag 1 cmd {pisC WaitForResults scalar} \
            src {docs/refs/HV_API.md sec.5 S16 (poIPost WaitForResults, 2024) - type "scalar" is one of the documented values} \
            note {the client waits for the scalar results before the read-back runs}] \
        [dict create n 2 via hwi frag 1 cmd {pisS GetClientManagerHandle pisMgr animation
pisMgr WaitForResults scalar} \
            src {docs/refs/HV_API.md sec.5 S17 (poIPostManager WaitForResults) + S20 (GetClientManagerHandle, name "animation" from the supplier example)} \
            note {same wait through the session manager instead of the window client}] \
        [dict create n 3 via hwi frag 1 cmd {} \
            src {docs/refs/HV_API.md sec.4 S25/S27 (the read-back decides) + sec.5 S18 (GetAsyncMode guard)} \
            note {no wait at all - the bounded read-back is the only proof, and it is the LAST entry on purpose}]]
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
    # --- the legend VISIBILITY of ONE window (T-035: F17 show/hide, F16 receiver) --------------
    # PROVEN > DOC > UNVERIFIED-GUESS:
    #   V1 `hwc show legends` / `hwc hide legends` - the owner's OWN scripts
    #      (docs/refs/HV_API_REF.md Legend: S02:18 `catch {hwc show legends}`, S06:243 show /
    #      S06:257 hide, S07:461 hide / S07:559 show) and PROVEN pattern 11 (import ->
    #      GetActiveClientHandle -> `hwc show legends` -> Draw -> update idletasks).
    #   V2 `poIPost SetDisplayOptions legend true|false` - DOC: docs/refs/HV_API.md sec.12 S56, whose
    #      documented `name` list holds "legend"; the read-back is S57 `GetDisplayOptions legend`.
    # `%mode` is show|hide and `%flag` is true|false. No `check` field: the getter judges BOTH
    # variants the same way, and a build without it must not fail a step (::pis::hw::legend_now).
    dict set t legend_visibility [list \
        [dict create n 1 via hwc cmd {%mode legends} \
            check {} want {} \
            src {docs/refs/HV_API_REF.md Legend S02:18, S06:243/257, S07:461/559 (PROVEN) + PROVEN pattern 11} \
            note {the ACTIVE window shows/hides its legend; the journal gets the one hwc line}] \
        [dict create n 2 via hwi frag 1 cmd {pisC SetDisplayOptions legend %flag} \
            check {} want {} \
            src {docs/refs/HV_API.md sec.12 S56 (poIPost SetDisplayOptions; the name list contains legend)} \
            note {the documented per-window display switch; read back with GetDisplayOptions legend (S57)}]]
    # --- ONE capture of one window (T-032: the owner's proven call first) ------------------
    # The owner's fail (T-011 F13, 2026-11-18): the DOC call `hwISession CaptureWindow` (S91) was
    # tried FIRST although his own scripts and the PROVEN digest hold working capture calls. The
    # precedence is binding - PROVEN > DOC > UNVERIFIED-GUESS - so the order is now:
    #   1. `<client> CaptureImage <file> PNG 1` - the first form the OWNER's loader tries, and the
    #      only one that renders ONE window off-screen (docs/refs/HV_API.md S97: "Renders the
    #      current HyperView window to an off-screen image file", format PNG, quality 1-4);
    #   2. `<sess> CaptureScreen png <file>` - the spelling of the shipped conrod/_tmp_hv/hvTest.tcl
    #      (line 140) and of the owner's loader (mode `screen`);
    #   3. `<sess> CaptureScreenToSize <type> <file> <w> <h>` - PROVEN HV_API_REF.md S06:249/260,
    #      S07:544, documented by S96 (types BMP/JPEG/TIFF/PNG/Clipboard, 0 or an error code);
    #   4+5. DOC S91 `CaptureWindow`, kept only as the last fallbacks.
    # `CaptureActiveWindow` stays rejected (S92 documents BMP and JPEG only, so it cannot write
    # the `.png` the file name freezes).
    # No variant carries a `check`: the proof of an image is the FILE it wrote (exists and has
    # bytes), and ::pis::hw::capture_image asks exactly that after the steps. A capture that
    # answered 0 but wrote nothing is a FAILURE with both facts in the message.
    dict set t capture_window [list \
        [dict create n 1 via hwi frag 1 call CaptureImage \
            cmd {pisC CaptureImage %path PNG 1} \
            src {conrod/tcl_guide/hv_model_loader.tcl:1936-1938 (mode clientImage, tried first) + docs/refs/HV_API.md S97 (poIPost CaptureImage, 2024: off-screen PNG of the current window, returns 0 or an error code)} \
            note {the window's graphic area is rendered off-screen into the image file}] \
        [dict create n 2 via hwi frag 1 call CaptureScreen \
            cmd {pisS CaptureScreen png %path} \
            src {conrod/_tmp_hv/hvTest.tcl:140 (`sessObj CaptureScreen png test_$i.png`) + conrod/tcl_guide/hv_model_loader.tcl:1944-1945} \
            note {the shipped screen capture spelling wrote the file}] \
        [dict create n 3 via hwi frag 1 call CaptureScreenToSize needpx 1 \
            cmd {pisS CaptureScreenToSize %type %path %width %height} \
            src {docs/refs/HV_API_REF.md S06:249/260 + S07:544 (PROVEN) + docs/refs/HV_API.md S96 (hwISession CaptureScreenToSize, 2024: PNG, width height, 0 or an error code)} \
            note {the sized screen capture of the owner's own scripts wrote the file}] \
        [dict create n 4 via hwi frag 1 call CaptureWindow \
            cmd {pisS CaptureWindow %index PNG %path %unit %width %height} \
            src {docs/refs/HV_API.md sec.6 S91 (hwISession CaptureWindow, 2024): type PNG, win_id explicit, "Success (0) or an error code"} \
            note {the documented window capture wrote the image file}] \
        [dict create n 5 via hwi frag 1 call CaptureWindow \
            cmd {pisS CaptureWindow %index PNG %path percent 150 150} \
            src {docs/refs/HV_API.md sec.6 S91: dimension_type "percent" with the page's own example values 150 150} \
            note {same documented call, sized in percent instead of pixels}]]
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

# A comment-ONLY journal line, used ONLY as a last resort (T-016: make_grid journals a real
# 'SetLayout <id>' step when the page answers a layout id; this is the fallback for the case where
# GetLayout answers nothing usable, because a fake hwi line would claim the journal can rebuild a
# grid it cannot). ::pis::journal has no comment-only entry (its add takes a command too) and
# _tcl_pis_10_hw.tcl is outside this task's writable files, so the buffer is appended here: the
# shape stays "# <text>", which is exactly what ::pis::journal::filter keeps.
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
# ::pis::hw::make_grid passes the ONE form (its %id comes from the caller, T-017) while every
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
        if {$n < $total} {
            ::pis::hw::note WARN [format "%s%s: variant %d/%d failed (%s); trying the next one" \
                $op $scope $n $total $lasterr]
        } else {
            # The LAST variant: there is no next one, and saying "trying the next one" here would
            # send the human looking for a variant that does not exist (owner report, pass 11).
            ::pis::hw::note WARN [format "%s%s: variant %d/%d failed (%s); that was the last variant" \
                $op $scope $n $total $lasterr]
        }
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

# Build the layout named by ONE integer id (T-017). The table is the judge, the page is the proof:
#   (a) '<page> GetLayout' already answers that id AND the page really shows its window count
#       (every window answering a window handle, a client handle and GetModelList)? Then no
#       SetLayout runs - a rebuild would take the grid the owner made by hand away - and the
#       journal gets ONE 'SetLayout <id>' step with that id, so a replay rebuilds the same layout
#       (T-016; the step is journaled, not executed, because the page already IS that layout);
#   (b) otherwise exactly ONE 'SetLayout <id>' is sent through the wrapper and journaled once, and
#       the read-back (::pis::hw::check_layout) proves BOTH GetLayout == id and
#       GetNumberOfWindows == the table's count, plus a client handle for every window 1..api.
# An id outside the table is refused here, with one message and 0 HyperView calls.
# Prints ONE GRID line per call: "GRID: id=<n> api=<a> clients=<c>".
proc ::pis::hw::make_grid {id} {
    variable adapt_grid
    set lid [string trim $id]
    if {![string is integer -strict $lid]} {
        error "::pis::hw::make_grid: the layout id must be an integer, got: '$id'"
    }
    set count [::pis::hw::layout_windows $lid]
    if {$count eq ""} {
        error [format "::pis::hw::make_grid: layout id %s is not in the table (docs/refs/HV_API.md sec. 2 has %d ids)" \
            $lid [::pis::hw::layout_count]]
    }
    ::pis::hw::need_exec
    set ob [::pis::hw::observe]
    set now [dict get $ob layout]
    if {[string is integer -strict $now] && $now == $lid && \
            [::pis::hw::observe_ok $ob $count] && [::pis::hw::grid_ready $count]} {
        ::pis::hw::note INFO [format "make_grid: the page is already layout id %s (%d window(s)), SetLayout skipped" \
            $lid $count]
        ::pis::hw::status [format "HV make_grid: layout id %s already present" $lid]
        # T-016: the grid is NOT rebuilt (that would take the grid the owner made by hand away),
        # but the journal still needs ONE replayable step, otherwise a replay in a fresh session
        # finds no layout at all and every later window load fails (S2, A4). '<page> SetLayout <id>'
        # with the id GetLayout answered is idempotent, so it is journaled and not executed.
        ::pis::hw::journal_run [::pis::hw::set_layout_step $lid]
        ::pis::hw::record make_grid 0
        set adapt_grid $lid
        puts [format "GRID: id=%s api=%s clients=%s" $adapt_grid \
            [dict get $ob api] [dict get $ob clients]]
        return $count
    }
    set list [::pis::hw::variants make_grid]
    set values [dict create %id $lid %count $count %want [format "%s:%s" $lid $count]]
    if {[catch {::pis::hw::run_list make_grid $list [::pis::hw::at make_grid] $values} err]} {
        # The status bar names the id as well as the step: a failed Load All must say which layout
        # it could not build, not only that a variant failed (run_list's own line is one step
        # shorter than what the human needs to act on).
        ::pis::hw::status [format "Error: make_grid: layout id %s did not give %d window(s)" \
            $lid $count]
        error [format "%s | asked layout id %s (%s, %d window(s)) | Fix: pick another entry in the Layout list, then click Load All again" \
            $err $lid [::pis::hw::layout_shape $lid] $count]
    }
    set ob [::pis::hw::observe]
    if {![::pis::hw::observe_ok $ob $count] || [dict get $ob layout] != $lid} {
        error [format \
            "make_grid: the page changed after the step: layout id %s, api=%s handles=%s clients=%s, wanted id %s with %d window(s)" \
            [dict get $ob layout] [dict get $ob api] [dict get $ob handles] \
            [dict get $ob clients] $lid $count]
    }
    set adapt_grid $lid
    puts [format "GRID: id=%s api=%s clients=%s" $lid [dict get $ob api] [dict get $ob clients]]
    ::pis::hw::status [format "HV make_grid: layout id %s, %s window(s)" $lid $count]
    return $count
}

proc ::pis::hw::load_result_in_window {index path} {
    variable adapt_wait_bad
    variable adapt_notes_seen
    if {![string is integer -strict $index] || $index < 1} {
        error "::pis::hw::load_result_in_window: window index must be a positive integer, got: '$index'"
    }
    set p [string trim $path]
    if {$p eq ""} { error "::pis::hw::load_result_in_window: empty result path" }
    if {![file isfile $p]} {
        error "::pis::hw::load_result_in_window: result file not found: $p"
    }
    # T-019: the OPTIONAL wait is decided BEFORE the script is built. Only the poIPostManager
    # GetAsyncMode guard can put a wait into the step, and the skip variant is always available,
    # so no build can lose a window over it. The table's variant list stays the audit trail;
    # only its cmd is re-built, with the chosen fragment.
    set plan [::pis::hw::wait_decide]
    set wcmd [dict get $plan cmd]
    set list [::pis::hw::variants load_result_in_window]
    set built {}
    foreach v $list {
        lappend built [dict replace $v cmd [::pis::hw::result_cmd %index %path $wcmd]]
    }
    set ::pis::hw::wait_error ""
    set ::pis::hw::sess_note ""
    set res ""
    if {[catch {
        set res [::pis::hw::run_list load_result_in_window $built \
            [::pis::hw::at load_result_in_window] \
            [dict create %path $p %index $index %zindex [expr {$index - 1}]]]
    } rerr]} {
        # The step failed on its READ-BACK (the only judge). A session condition from GetError is
        # then the best explanation this build offers, so it is quoted - never the other way round.
        set nerr ""
        catch {set nerr $::pis::hw::sess_note}
        if {[string trim $nerr] ne ""} {
            error "$rerr (session note after SetResult: [::pis::hw::clip $nerr 200])"
        }
        error $rerr
    }
    # PASSED the read-back, so a non-empty GetError is a NOTE, not a failure (F7: this build
    # answers "(poIPost::GetResultList)" on window 2 with the result attached). ONE WARN per
    # distinct text per RUN, so a full grid cannot fill the log with the same line.
    set nerr ""
    catch {set nerr $::pis::hw::sess_note}
    set nerr [string trim $nerr]
    if {$nerr ne ""} {
        if {![dict exists $adapt_notes_seen $nerr]} {
            dict set adapt_notes_seen $nerr 1
            ::pis::hw::note WARN [format \
                "load_result_in_window window %d: session note after SetResult: %s - the read-back succeeded" \
                $index [::pis::hw::clip $nerr 200]]
        }
    }
    # A wait that failed while the read-back SUCCEEDED is a WARN, not an ERROR (T-019), and that
    # form is not tried again in this session - the next window uses the next form and the chain
    # ends at "no wait at all".
    set werr ""
    catch {set werr $::pis::hw::wait_error}
    if {[string trim $werr] ne ""} {
        ::pis::hw::note WARN [format \
            "load_result_in_window window %d: result wait failed: %s - the read-back decided" \
            $index [::pis::hw::clip $werr 300]]
        if {$wcmd ne ""} { lappend adapt_wait_bad [dict get $plan n] }
    }
    return $res
}

proc ::pis::hw::select_window {index} {
    if {![string is integer -strict $index] || $index < 1} {
        error "::pis::hw::select_window: window index must be a positive integer, got: '$index'"
    }
    return [::pis::hw::run select_window \
        [dict create %index $index %zindex [expr {$index - 1}]]]
}

# The index of the window that is ACTIVE right now (T-011). Read-only and never journaled (it is a
# question, not a step): poIPage GetActiveWindow is the documented read the result module already
# uses inside its own script (S33). It answers one clear error instead of a number when the page
# cannot name a window, because a capture sent to a guessed window would photograph the wrong one.
proc ::pis::hw::active_window {} {
    ::pis::hw::need_exec
    # Braced, then interpolated: a literal `[psiPage ...]` inside a double-quoted script would run
    # HERE (before the handle exists) instead of in the script being built.
    set body {set psiAW [psiPage GetActiveWindow]}
    set script "[::pis::hw::stack_open psi]\n$body\n[::pis::hw::page_close psi]\nset psiAW"
    set got ""
    if {[catch {::pis::hw::probe $script} got]} {
        error "::pis::hw::active_window: the page did not answer (GetActiveWindow): [string trim $got]"
    }
    set got [string trim $got]
    if {![string is integer -strict $got] || $got < 1} {
        error "::pis::hw::active_window: no window is active (poIPage GetActiveWindow answered '$got')"
    }
    return $got
}

proc ::pis::hw::import_legend {path} {
    set p [string trim $path]
    if {$p eq ""} { error "::pis::hw::import_legend: empty legend path" }
    if {![file isfile $p]} { error "::pis::hw::import_legend: legend file not found: $p" }
    return [::pis::hw::run import_legend [dict create %path $p]]
}

# --- the legend VISIBILITY of one window (T-035, F16 + F17) --------------------------------
# The owner's two facts:
#   F16 - the legend module reached the page through a CLIENT handle and the build refused it
#         (`Object named: pis_legend_client_... (of type poIPost) could not find requested method:
#         GetPageHandle ...`). Nothing here walks the page from a client: the window is selected by
#         the PROVEN `::pis::hw::select_window` (project handle -> page -> SetActiveWindow k) and the
#         client is only ever the receiver of `Draw` / `SetDisplayOptions` / `GetDisplayOptions`.
#   F17 - `on` is the Display Control > Legend toggle: show it in every window, or hide it in every
#         window. One window per call, one hwi/hwc sequence, one journal line for the state change.
#
# Deferred journal (the ONE hwc call that is not sent by ::pis::hw::exec):
#   a variant must not reach a saved journal when the read-back refuses it, and ::pis::hw::exec has
#   no -nojournal mode. `hwc_defer` runs the command with no journal line and `hwc_journal` writes
#   the SAME text `exec` writes (same quoting, same timestamp comment) only after the read-back
#   agreed. This is the only caller of both procs.
namespace eval ::pis::hw {
    # "-" = GetDisplayOptions legend not asked yet, 1 = it answers, 0 = this build lacks it.
    if {![info exists adapt_legend_getter]} { set adapt_legend_getter "-" }
    # Has THIS run already written its one "checked by eye" line?
    if {![info exists adapt_legend_eye]} { set adapt_legend_eye 0 }
    # Variant that worked last time, so windows 2..N start with it (like adapt_capture).
    if {![info exists adapt_legend]} { set adapt_legend 0 }
}

# "show" / "hide" from the caller's word, with one clear message naming the offending value.
proc ::pis::hw::legend_word {show} {
    set w [string tolower [string trim $show]]
    if {$w eq "show" || $w eq "hide"} { return $w }
    error "::pis::hw::legend_visibility: mode must be show or hide, got: '$show'"
}

# The documented boolean of S56 (`state`: "true for on, or false for off.").
proc ::pis::hw::legend_flag {mode} {
    if {$mode eq "show"} { return true }
    return false
}

# What a GetDisplayOptions legend answer means: show / hide / "" (not an answer).
# S57 says "Returns true if the given display option is on; false if it is not.", and a build may
# spell a boolean as 1/0 or yes/on, so both documented words and the usual spellings are read.
proc ::pis::hw::legend_state {raw} {
    set t [string tolower [string trim $raw]]
    foreach v {1 true on yes} { if {$t eq $v} { return show } }
    foreach v {0 false off no} { if {$t eq $v} { return hide } }
    return ""
}

# Read-only: what the window answers for `GetDisplayOptions legend` (S57). "" = no documented
# getter on this build (the absent-method text is the proof, T-027 rule) or no answer at all.
# Any OTHER error is the build's own words and is raised in full - never swallowed.
proc ::pis::hw::legend_now {index} {
    variable adapt_legend_getter
    if {$adapt_legend_getter eq "0"} { return "" }
    set body {set psiLV [psiC GetDisplayOptions legend]}
    set script "[::pis::hw::window_open psi $index]\n$body\n[::pis::hw::window_close psi]\nset psiLV"
    set got ""
    if {[catch {::pis::hw::probe $script} got]} {
        set raw [string trim $got]
        set parsed [::pis::hw::absent_parse $raw]
        if {[llength $parsed] >= 3} {
            lassign $parsed class mname ambiguous
            if {$mname eq "GetDisplayOptions"} {
                set adapt_legend_getter 0
                return ""
            }
        }
        error $raw
    }
    set adapt_legend_getter 1
    return [string trim $got]
}

# The literal `select_window` sends for window k: the START variant of that op, filled and folded,
# so a STEP line prints exactly the script the proven helper sends.
proc ::pis::hw::legend_select_text {index} {
    set v [::pis::hw::variant_of select_window [::pis::hw::at select_window]]
    set cmd [::pis::hw::fill [dict get $v cmd] \
        [dict create %index $index %zindex [expr {$index - 1}]]]
    return [::pis::hw::fold_script $cmd]
}

# The journal text of one hwc command, built exactly as ::pis::hw::exec builds it.
proc ::pis::hw::hwc_line {words} {
    set parts [list hwc]
    foreach a $words {
        lappend parts [::pis::journal::quote_arg $a]
    }
    return [join $parts " "]
}

# ONE hwc command with NO journal line (see the deferred-journal note above). Raises like the
# build: the caller's `catch` keeps the build's own text.
proc ::pis::hw::hwc_defer {words} {
    if {[llength $words] == 0} {
        error "::pis::hw::hwc_defer: no HyperView command given"
    }
    if {[llength [info commands hwc]] == 0} {
        error "::pis::hw::hwc_defer: the hwc command is not available (run inside HyperView)"
    }
    return [hwc {*}$words]
}

# Journal one hwc command that is ALREADY proven (same comment + line as ::pis::hw::exec).
proc ::pis::hw::hwc_journal {words} {
    set line [::pis::hw::hwc_line $words]
    set mod ""
    set item ""
    if {[info exists ::pis::hw::cur_module]} { set mod $::pis::hw::cur_module }
    if {[info exists ::pis::hw::cur_item]} { set item $::pis::hw::cur_item }
    set stamp [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
    ::pis::journal::add [format "%s | %s | %s" $stamp $mod $item] $line
    return $line
}

# The `now:` half of a STEP line: the read-only state of window k's legend.
proc ::pis::hw::legend_now_text {index} {
    set got ""
    if {[catch {::pis::hw::legend_now $index} got]} {
        return [format "legend ? (%s)" [::pis::hw::clip [string trim $got] 120]]
    }
    set st [::pis::hw::legend_state $got]
    if {$st eq ""} { return "legend ? (no answer from GetDisplayOptions legend)" }
    return "legend visible $st"
}

# Step 1 of the legend path on its own: window k becomes the ACTIVE one through the PROVEN
# ::pis::hw::select_window helper (project handle -> page -> SetActiveWindow k, ONE journaled
# `hwi ...` line) and the STEP line is written. The module calls this once per window and then
# imports, so `legend_visibility` is invoked with do_select 0 and the window is selected exactly
# one time per window.
proc ::pis::hw::legend_select {index {trace 1}} {
    set code [catch {::pis::hw::select_window $index} res]
    set raw [string trim $res]
    set lit [::pis::hw::legend_select_text $index]
    if {$code} {
        if {$trace} {
            ::pis::hw::note ERROR [format "STEP legend window %d select: sent %s -> ERR %s" \
                $index $lit $raw]
        }
        error $raw
    }
    if {$trace} {
        ::pis::hw::note INFO [format "STEP legend window %d select: sent %s -> ret=(empty) | now: %s" \
            $index $lit [::pis::hw::legend_now_text $index]]
    }
    return
}

# Show or hide the legend of ONE window (T-035). Steps, in this order:
#   1) select window k through the proven helper (ONE journaled hwi line) unless the caller already
#      did it (`do_select` 0 - the module selects once, imports, then calls this);
#   2) the variant list of op `legend_visibility`, each variant judged by the documented getter
#      `GetDisplayOptions legend` (S57); the journal line is written only for the variant that
#      passed, and a build without the getter is delivered as UNVERIFIED-GUESS with ONE INFO line;
#   3) `Draw` on the client OF window k (PROVEN pattern 2) and ONE `::pis::hw::refresh`.
# `trace` 1 logs one STEP line per step plus the `LEGEND ok window k shown|hidden variant n` line.
# Returns {variant mode line unverified}; raises the build's own text when a step raises.
proc ::pis::hw::legend_visibility {index show {do_select 1} {trace 1}} {
    variable adapt_legend
    variable adapt_legend_eye
    ::pis::hw::need_exec
    if {![string is integer -strict $index] || $index < 1} {
        error "::pis::hw::legend_visibility: window index must be a positive integer, got: '$index'"
    }
    set mode [::pis::hw::legend_word $show]
    set values [dict create %index $index %mode $mode %flag [::pis::hw::legend_flag $mode]]
    set list [::pis::hw::variants legend_visibility]
    set total [llength $list]
    set start [::pis::hw::at legend_visibility]
    if {$adapt_legend > 0 && $adapt_legend <= $total} { set start $adapt_legend }
    if {![string is integer -strict $start] || $start < 1 || $start > $total} { set start 1 }
    # --- step 1: window k becomes the ACTIVE one (ONE journaled hwi line) ---------------------
    if {$do_select} {
        ::pis::hw::legend_select $index $trace
    }
    # --- step 2: the visibility call, variant by variant --------------------------------------
    set firsterr ""
    set lasterr ""
    set tried [list]
    set won 0
    set winvariant 0
    set unverified 0
    set line ""
    set n $start
    while {$n <= $total} {
        set v [lindex $list [expr {$n - 1}]]
        set via hwi
        if {[dict exists $v via]} { set via [dict get $v via] }
        set cmd [::pis::hw::fill [dict get $v cmd] $values]
        if {$via eq "hwc"} {
            set script $cmd
        } else {
            set script "[::pis::hw::window_open pis $index]\n$cmd\n[::pis::hw::window_close pis]"
        }
        set literal [::pis::hw::fold_script $script]
        if {$via eq "hwc"} { set literal [::pis::hw::hwc_line $cmd] }
        ::pis::hw::note INFO [format "legend_visibility window %d: variant %d/%d <%s> (%s)" \
            $index $n $total $literal [dict get $v src]]
        set code 0
        if {$via eq "hwc"} {
            set code [catch {::pis::hw::hwc_defer $cmd} res]
        } else {
            set code [catch {::pis::hw::exec_hwi $script -nojournal} res]
        }
        set raw [string trim $res]
        set why ""
        if {!$code} {
            set got ""
            set gcode [catch {::pis::hw::legend_now $index} got]
            if {$gcode} {
                set code 1
                set why "the read-back itself failed: [string trim $got]"
            } elseif {$got eq ""} {
                # no documented getter on this build: the variant is delivered, marked unverified
                set unverified 1
            } else {
                set gotstate [::pis::hw::legend_state $got]
                if {$gotstate ne $mode} {
                    set code 1
                    set why [format \
                        "HyperView did not change: GetDisplayOptions legend answered '%s', expected '%s'" \
                        $got $mode]
                }
            }
        }
        if {$code && $why eq ""} { set why [string trim $raw] }
        if {$why eq ""} { set why "the call raised no error" }
        if {$trace} {
            if {$code} {
                ::pis::hw::note WARN [format \
                    "STEP legend window %d visibility (variant %d/%d): sent %s -> ERR %s | now: %s" \
                    $index $n $total $literal $why [::pis::hw::legend_now_text $index]]
            } else {
                set shown "(empty)"
                if {$raw ne ""} { set shown $raw }
                ::pis::hw::note INFO [format \
                    "STEP legend window %d visibility: sent %s -> ret=%s | now: %s" \
                    $index $literal $shown [::pis::hw::legend_now_text $index]]
            }
        }
    # @@LEGEND_TAIL@@
        if {!$code} {
            if {$via eq "hwc"} {
                catch {set line [::pis::hw::hwc_journal $cmd]}
            } else {
                catch {set line [::pis::hw::journal_run $script]}
            }
            set adapt_legend $n
            ::pis::hw::record [::pis::hw::used_key legend_visibility $values] $n
            set word shown
            if {$mode eq "hide"} { set word hidden }
            ::pis::hw::note OK [format "LEGEND ok window %d %s variant %d/%d" \
                $index $word $n $total]
            set won 1
            set winvariant $n
            break
        }
        lappend tried [format "%d/%d failed" $n $total]
        set lasterr $why
        if {$firsterr eq ""} { set firsterr $why }
        if {$n < $total} {
            ::pis::hw::note WARN [format \
                "legend_visibility window %d: variant %d/%d failed (%s); trying the next one" \
                $index $n $total $why]
        } else {
            ::pis::hw::note WARN [format \
                "legend_visibility window %d: variant %d/%d failed (%s); that was the last variant" \
                $index $n $total $why]
        }
        incr n
    }
    if {!$won} {
        ::pis::hw::record [::pis::hw::used_key legend_visibility $values] 0
        ::pis::hw::status [format "Error: legend window %d - no variant worked (%d/%d)" \
            $index $total $total]
        set detail $firsterr
        if {$detail eq ""} { set detail $lasterr }
        if {[llength $tried] > 1} {
            append detail [format " (tried %s)" [join $tried {, }]]
        }
        error [format \
            "legend_visibility window %d variant %d/%d failed: %s | pick another variant with: ::pis::hw::use legend_visibility <n>" \
            $index $total $total $detail]
    }
    if {$unverified && !$adapt_legend_eye} {
        set adapt_legend_eye 1
        ::pis::hw::note INFO [format \
            "legend visibility: no documented getter, window %d must be checked by eye" $index]
    }
    # --- step 3: repaint window k (PROVEN pattern 2), then let Tk paint ----------------------
    # NOT journaled: the journal's own `hwc show legends` / `hwc hide legends` is the state change,
    # and a replay repaints by itself. Same rule as the select step of a capture.
    set dscript "[::pis::hw::window_open pis $index]\npisC Draw\n[::pis::hw::window_close pis]"
    set dcode [catch {::pis::hw::exec_hwi $dscript -nojournal} dres]
    set draw [string trim $dres]
    if {$dcode} {
        if {$trace} {
            ::pis::hw::note ERROR [format "STEP legend window %d draw: sent %s -> ERR %s" \
                $index [::pis::hw::fold_script $dscript] $draw]
        }
        error $draw
    }
    if {$trace} {
        set shown "(empty)"
        if {$draw ne ""} { set shown $draw }
        ::pis::hw::note INFO [format "STEP legend window %d draw: sent %s -> ret=%s | now: %s" \
            $index [::pis::hw::fold_script $dscript] $shown [::pis::hw::legend_now_text $index]]
    }
    ::pis::hw::refresh
    return [dict create variant $winvariant mode $mode line $line unverified $unverified]
}

# The view of ONE window (T-032; receiver discovery in T-033). The ONE place
# `SetActiveView true "<name>"` is spelled, and the ONE place the receiver is decided.
#
# T-033 item 3 (bounded discovery): the owner's literal is tried on the handle kinds of
# ::pis::hw::view_table, the DOCUMENTED 3D view control first. The first receiver that raises
# nothing is CACHED for the session and logged ONCE (`VIEW window k: receiver <type> accepted`);
# a receiver whose error proves the method absent (`could not find requested method`) goes into the
# session absent list with ONE `method absent on this build: <type> SetActiveView` line and is
# never tried again, for any window or row. ANY other error (a view name not found, for example)
# means the method EXISTS: discovery stops and the raw text is reported.
#
# Item 4 (read-back): `GetActiveView` (S100) is read after the call. A different name fails the
# image with `view '<name>' not active in window k (read: <v>)` BEFORE any capture call runs. When
# that getter is absent, the CAMERA (S104 GetViewMatrix) is read before and after as EVIDENCE
# (WARN unchanged / INFO changed); with neither getter one line per run says so.
#
# Nothing is journaled here (the image is journaled as ONE line); the proc returns
# {script rec} - the script it sent and the receiver dict - so ::pis::hw::capture_image can put
# the SAME view text into the journal line. It does NOT redraw: `draw` is its own step.
proc ::pis::hw::set_view {index name} {
    variable adapt_view
    variable view_note
    ::pis::hw::need_exec
    if {![string is integer -strict $index] || $index < 1} {
        error "::pis::hw::set_view: window index must be a positive integer, got: '$index'"
    }
    set n [string trim $name]
    if {$n eq ""} { error "::pis::hw::set_view: empty view name" }
    set values [dict create %index $index %view $n]
    # The receivers still worth trying: the cached one FIRST (windows 2..N), then the table in
    # order, minus every type this build already proved has no SetActiveView.
    set table [::pis::hw::view_table]
    set list [list]
    if {$adapt_view ne ""} {
        foreach rec $table {
            if {[dict get $rec rec] eq $adapt_view} { lappend list [dict get $rec rec] }
        }
    }
    foreach rec $table {
        set rn [dict get $rec rec]
        if {$rn eq $adapt_view} { continue }
        if {[::pis::hw::absent_has [dict get $rec type] SetActiveView]} { continue }
        lappend list $rn
    }
    if {[llength $list] == 0} {
        error "view step failed for all receivers, capture call not attempted: every receiver of SetActiveView is recorded absent on this build"
    }
    # The read-back is taken BEFORE the view step too (item 4: read before and after). When the
    # active-view getter does not answer, the CAMERA is read instead - as evidence, not a verdict.
    set got0 [::pis::hw::active_view $index]
    set cam0 ""
    set camwanted 0
    if {$got0 eq ""} {
        set cam0 [::pis::hw::camera_view $index]
        set camwanted [expr {$cam0 ne "" ? 1 : 0}]
    }
    set tried [list]
    foreach rn $list {
        set rec ""
        foreach cand $table {
            if {[dict get $cand rec] eq $rn} { set rec $cand }
        }
        if {$rec eq ""} { continue }
        set script [::pis::hw::view_step_script $rec $values]
        set code [catch {::pis::hw::exec_hwi $script -nojournal} res]
        if {!$code} {
            # The receiver answered. Cache it, and say it ONCE per run (not once per image).
            set first [expr {$adapt_view ne [dict get $rec rec]}]
            set adapt_view [dict get $rec rec]
            if {$first} {
                ::pis::hw::note INFO [format \
                    "VIEW window %d: receiver %s accepted SetActiveView true '%s'" \
                    $index [dict get $rec type] $n]
            }
            set got [::pis::hw::active_view $index]
            if {$got ne "" && $got ne $n} {
                error "view '$n' not active in window $index (read: $got)"
            }
            if {$got eq ""} {
                if {$camwanted} {
                    set cam1 [::pis::hw::camera_view $index]
                    if {$cam1 eq ""} {
                        if {!$view_note} {
                            set view_note 1
                            ::pis::hw::note INFO "view: no read-back for the active view on this build (neither GetActiveView nor GetViewMatrix answered) - the image is the only proof of the view"
                        }
                    } elseif {$cam0 eq $cam1} {
                        ::pis::hw::note WARN [format \
                            "view window %d: camera unchanged after SetActiveView '%s' (already that view, or the call had no effect) - look at the image" \
                            $index $n]
                    } else {
                        ::pis::hw::note INFO [format "view window %d: camera changed" $index]
                    }
                } elseif {!$view_note} {
                    set view_note 1
                    ::pis::hw::note INFO "view: no read-back for the active view on this build (neither GetActiveView nor GetViewMatrix answered) - the image is the only proof of the view"
                }
            }
            return [list $script $rec]
        }
        set raw [string trim $res]
        lappend tried [format "%s (%s)" [dict get $rec type] [::pis::hw::clip $raw 90]]
        # Proof of absence: the build's own text names the method. The arguments are the owner's
        # documented literal, so the method name alone decides here (T-033 item 2).
        set parsed [::pis::hw::absent_parse $raw]
        if {[llength $parsed] >= 3} {
            lassign $parsed class mname ambiguous
            if {$mname eq "SetActiveView"} {
                if {$class eq ""} { set class [dict get $rec type] }
                set key [::pis::hw::absent_add $class SetActiveView]
                if {$key ne ""} {
                    ::pis::hw::note INFO [format "method absent on this build: %s SetActiveView" $class]
                }
                if {$adapt_view eq [dict get $rec rec]} { set adapt_view "" }
                continue
            }
        }
        # Any other error text means the method EXISTS on that handle: stop the discovery and
        # report the build's own words in full - never record it absent.
        error [format "view step failed, capture call not attempted: receiver %s said: %s" \
            [dict get $rec type] $raw]
    }
    error [format "view step failed for all receivers, capture call not attempted (tried %s)" \
        [join $tried {, }]]
}

# ONE image, step by step (T-032; the view step separated in T-033).
# `values` holds %index %path %view %unit %width %height %type; `layout` 1 makes window %index
# active first, 0 leaves the page's active window alone; `trace` 1 logs one STEP line per step
# (the steps are ALWAYS sent as their own hwi scripts, so a failing step has its own raw answer
# and one image can never repeat another step's trace block); `viewstep` 0 skips the view step
# (`[capture] on_view_unavailable = capture_current`).
# The variants of the table apply to the CAPTURE CALL only: select / view / draw run ONCE, before
# the first variant is tried (F14 b: a failing view was retried five times).
# The proof is the FILE: exists and size > 0. A call that answered 0 and wrote nothing fails,
# with both facts in the message. `row` is a log label only (0 = not a module row).
proc ::pis::hw::capture_image {values layout trace row {viewstep 1}} {
    variable adapt_capture
    ::pis::hw::need_exec
    set index [dict get $values %index]
    set path [dict get $values %path]
    set view [dict get $values %view]
    set list [::pis::hw::variants capture_window]
    set total [llength $list]
    set start [::pis::hw::at capture_window]
    if {$adapt_capture > 0 && $adapt_capture <= $total} { set start $adapt_capture }
    if {![string is integer -strict $start] || $start < 1 || $start > $total} { set start 1 }
    set steps [list]
    if {$layout} { lappend steps select }
    if {$viewstep} { lappend steps view }
    lappend steps draw
    # The journal text of the view step that was really sent ("" = no view line in the journal).
    set viewfrag ""
    # --- the steps BEFORE the capture call: once each, no variant applies ---------------------
    foreach step $steps {
        if {$step eq "view"} {
            set res [list]
            set code [catch {::pis::hw::set_view $index $view} res]
            if {$code} {
                set errtext [string trim $res]
                if {$trace} {
                    ::pis::hw::note ERROR [format "STEP capture window %d row %d view: %s" \
                        $index $row $errtext]
                }
                error $errtext
            }
            set script [lindex $res 0]
            set rec [lindex $res 1]
            set viewfrag [::pis::hw::fill [::pis::hw::view_frag $rec] $values]
            if {$trace} {
                set now [::pis::hw::capture_now view $index]
                ::pis::hw::note INFO [format \
                    "STEP capture window %d row %d view: sent %s -> ret=(accepted by %s) | now: %s" \
                    $index $row [::pis::hw::fold_script $script] [dict get $rec type] $now]
            }
            continue
        }
        set script [::pis::hw::capture_step_script $step $values]
        set code [catch {::pis::hw::exec_hwi $script -nojournal} res]
        set raw [string trim $res]
        if {$code} {
            if {$trace} {
                ::pis::hw::note ERROR [format "STEP capture window %d row %d %s: sent %s -> ERR %s" \
                    $index $row $step [::pis::hw::fold_script $script] $raw]
            }
            error [format "%s step failed, capture call not attempted: %s" $step $raw]
        }
        if {$trace} {
            set now [::pis::hw::capture_now $step $index]
            if {$raw eq ""} { set raw "(empty)" }
            ::pis::hw::note INFO [format "STEP capture window %d row %d %s: sent %s -> ret=%s | now: %s" \
                $index $row $step [::pis::hw::fold_script $script] $raw $now]
        }
    }
    ::pis::hw::refresh
    # --- the capture call: the ONLY thing a variant applies to ------------------------------
    set firsterr ""
    set lasterr ""
    set n $start
    while {$n <= $total} {
        set v [lindex $list [expr {$n - 1}]]
        set call [dict get $v call]
        if {[dict exists $v needpx] && [dict get $v needpx] && [dict get $values %unit] ne "pixels"} {
            ::pis::hw::note INFO [format \
                "capture_window window %d: variant %d/%d skipped (%s takes a pixel size, unit is '%s')" \
                $index $n $total $call [dict get $values %unit]]
            incr n
            continue
        }
        set callcmd [::pis::hw::fill [dict get $v cmd] $values]
        set full [::pis::hw::capture_full_script $layout $values $callcmd $viewfrag]
        set script [::pis::hw::capture_step_script call $values $callcmd]
        set res ""
        set code 0
        if {$trace} {
            ::pis::hw::note INFO [format "CAPTURE ctx window %d row %d view '%s' call %s" \
                $index $row $view $call]
        }
        set code [catch {::pis::hw::exec_hwi $script -nojournal} res]
        # The log shows the LITERAL script that was sent (folded, no display transform of
        # brackets or braces): a truncated "hwi OpenStack ..." would hide the very call the
        # owner has to recognise (F13 asked for per-step evidence, not a summary).
        if {$trace} {
            set literal [::pis::hw::fold_script $script]
            if {$code} {
                ::pis::hw::note ERROR [format "STEP capture window %d row %d call: sent %s -> ERR %s" \
                    $index $row $literal [string trim $res]]
            } else {
                set raw [string trim $res]
                if {$raw eq ""} { set raw "(empty)" }
                ::pis::hw::note INFO [format \
                    "STEP capture window %d row %d call: sent %s -> ret=%s | now: -" \
                    $index $row $literal $raw]
            }
        }
        # The documented answer is an INTEGER: 0 = success, anything else = an error code that
        # fails the variant by its own number. An empty answer is left to the file check.
        set say ""
        if {$code} {
            set say "call: [string trim $res]"
        } elseif {[string is integer -strict [string trim $res]] && [string trim $res] != 0} {
            set say "call $call answered error code [string trim $res]"
        } elseif {![file exists $path]} {
            set say "call $call answered '[string trim $res]' but wrote no file: $path"
        } elseif {[file size $path] <= 0} {
            set say "call $call wrote an empty file: $path"
        }
        if {$say eq ""} {
            set bytes [file size $path]
            set line ""
            catch {set line [::pis::hw::journal_run $full]}
            set adapt_capture $n
            ::pis::hw::record [::pis::hw::used_key capture_window $values] $n
            set tail "variant $n/$total used and confirmed by the file ($bytes bytes, src: [dict get $v src])"
            if {$n == $start} {
                ::pis::hw::note OK [format "capture_window window %d: %s" $index $tail]
            } else {
                ::pis::hw::note OK [format \
                    "capture_window window %d: %s; keep it with: ::pis::hw::use capture_window %d" \
                    $index $tail $n]
            }
            ::pis::hw::note OK [format "CAPTURE ok window %d variant %d/%d %s" $index $n $total $call]
            return [dict create path $path bytes $bytes variant $n call $call \
                view $view script $line]
        }
        lappend tried [format "%d/%d failed" $n $total]
        set lasterr $say
        if {$firsterr eq ""} { set firsterr $say }
        if {$n < $total} {
            ::pis::hw::note WARN [format "capture_window window %d: variant %d/%d failed (%s); trying the next one" \
                $index $n $total $say]
        } else {
            ::pis::hw::note WARN [format "capture_window window %d: variant %d/%d failed (%s); that was the last variant" \
                $index $n $total $say]
        }
        incr n
    }
    ::pis::hw::record [::pis::hw::used_key capture_window $values] 0
    set detail $firsterr
    if {$detail eq ""} { set detail $lasterr }
    if {[llength $tried] > 1} {
        append detail [format " (tried %s)" [join $tried {, }]]
    }
    error [format \
        "capture_window window %d view '%s' variant %d/%d failed: %s | pick another variant with: ::pis::hw::use capture_window <n>" \
        $index $view $total $total $detail]
}

# One image of ONE window (T-032), through the steps above:
#   select window (layout scope only) -> set the VIEW the row names -> Draw -> the capture call.
# The variant order is the PROVEN one (owner script, owner script, HV_API_REF digest) and only
# then the DOC call S91 - see the table.
# `view` is the ticked row's view name. The output path is the CALLER's (the module builds
# {result}_{view}.png and makes it unique); it must not exist yet, because the proof is "the file
# exists and has bytes" - an image from an earlier run would make that proof meaningless.
proc ::pis::hw::capture_window {index path view unit width height args} {
    if {![string is integer -strict $index] || $index < 1} {
        error "::pis::hw::capture_window: window index must be a positive integer, got: '$index'"
    }
    set p [string trim $path]
    if {$p eq ""} { error "::pis::hw::capture_window: empty output path" }
    if {[file exists $p]} {
        error "::pis::hw::capture_window: output file already exists: $p"
    }
    set vw [string trim $view]
    if {$vw eq ""} { error "::pis::hw::capture_window: empty view name" }
    set u [string tolower [string trim $unit]]
    if {$u ne "pixels" && $u ne "percent"} {
        error "::pis::hw::capture_window: dimension unit must be pixels or percent, got: '$unit'"
    }
    foreach {label val} [list width $width height $height] {
        if {![string is integer -strict $val] || $val < 1} {
            error "::pis::hw::capture_window: $label must be a positive integer, got: '$val'"
        }
    }
    if {[llength $args] % 2 != 0} {
        error "::pis::hw::capture_window: options come in pairs (-row <r> -layout <0|1> -trace <0|1> -viewstep <0|1>)"
    }
    set layout 0
    set trace 1
    set row 0
    set viewstep 1
    foreach {opt val} $args {
        switch -- $opt {
            -row {
                if {![string is integer -strict $val] || $val < 0} {
                    error "::pis::hw::capture_window: -row must be a non-negative integer, got: '$val'"
                }
                set row $val
            }
            -layout {
                set layout [expr {($val eq "1" || $val eq "true") ? 1 : 0}]
            }
            -trace {
                set trace [expr {($val eq "1" || $val eq "true") ? 1 : 0}]
            }
            -viewstep {
                # T-033: 0 = do not touch the view at all (`[capture] on_view_unavailable =
                # capture_current`). The row's view name still names the file and the log.
                set viewstep [expr {($val eq "1" || $val eq "true") ? 1 : 0}]
            }
            default {
                error "::pis::hw::capture_window: unknown option '$opt' (expected -row, -layout, -trace, -viewstep)"
            }
        }
    }
    # The image type is the file extension (S06/S07 take it from the config): a `.png` file is
    # asked for as `png`, and a name with no extension defaults to `png`.
    set type [string tolower [string trim [file extension $p] .]]
    if {$type eq ""} { set type png }
    set values [dict create %index $index %path $p %view $vw %unit $u \
        %width $width %height $height %type $type]
    return [::pis::hw::capture_image $values $layout $trace $row $viewstep]
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
                if {[dict exists $v local] && [dict get $v local]} {
                    set rd "file check = [dict get $v want]"
                }
            }
            puts [format "    %d. %-44s \[%s\] <- %s" \
                [dict get $v n] [::pis::hw::one_line [dict get $v cmd]] $rd [dict get $v src]]
        }
    }
    puts "  change one: ::pis::hw::use <op> <n>   e.g. ::pis::hw::use load_model 2"
    puts "  what ran last: ::pis::hw::diag   (ONE line: id= api= model= result= per window)"
    puts "  what the page has NOW: ::pis::hw::observe   (api= handles= clients= layout=, read-only)"
    puts "  what the page is now: ::pis::hw::page_info   (read-only: layout id, wins, open windows)"
    puts "  which layout id this build has: ::pis::hw::layout_table   (DIAGNOSTIC: refuses a session"
    puts "    that is not empty, else ONE LAYOUTS line, id=window count measured on this page)"
    puts "  the table itself: ::pis::hw::layout_choices   (<id>: <w> windows - <shape>, no page read)"
    puts "  which layout the page is IN: ::pis::hw::grid_capture   (read-only, plus the ini line)"
    return
}

# Every op back to its first variant, the order back to 1 and nothing recorded (tests, and a fresh
# session). The layout table is static, so there is nothing layout-related to reset.
proc ::pis::hw::reset_state {} {
    variable adapt_at
    variable adapt_used
    variable adapt_order
    variable adapt_grid
    variable adapt_models
    variable adapt_async
    variable adapt_wait_bad
    variable adapt_wait_notes
    variable adapt_notes_seen
    variable sess_note
    variable wait_error
    variable adapt_absent
    set adapt_at [dict create]
    set adapt_used [dict create]
    set adapt_order 1
    set adapt_grid "-"
    set adapt_async "-"
    set adapt_wait_bad {}
    set adapt_wait_notes 0
    set adapt_notes_seen [dict create]
    set sess_note ""
    set wait_error ""
    set adapt_absent [dict create]
    catch {array unset adapt_models}
    array set adapt_models {}
    return
}

# --- build stamp: ONE line, printed when this file is sourced -------------------------
# The line answers the first question on a HyperView machine ("which copy is this?"):
#   BUILD T32a-20261118-1530 | make_grid variants=1 | adapter lines=NNN | layouts=20
# The line count is measured from the file itself at source time (below), so it cannot go
# stale the way a hand-written number would. "layouts=" is the size of the STATIC table, so a
# copy without it shows up before the first Load All.
proc ::pis::hw::build_line {} {
    variable build_lines
    set stamp "no-stamp"
    if {[info exists ::pis::BUILD]} { set stamp $::pis::BUILD }
    set n 0
    catch { set n [llength [::pis::hw::variants make_grid]] }
    set ids 0
    catch { set ids [::pis::hw::layout_count] }
    return [format "BUILD %s | make_grid variants=%d | adapter lines=%d | layouts=%d" \
        $stamp $n $build_lines $ids]
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
