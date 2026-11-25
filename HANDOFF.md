# HANDOFF - where this project stands (read this before any other doc)

Written 2026-11-12 at the end of the T-027 work; section 4 and the capture rows were rewritten
2026-11-18 for T-032, T-033 and T-034, again for T-035 (Load Legend: F16 + F17), again
2026-11-19 for T-012 (the log pane buttons), again 2026-11-24 for T-036 (the DOCS-ONLY pass that
specs the new `Notes` panel and the two `Macro Add` buttons), and again 2026-11-24 for T-039 (the
F18 fix: the GUI's source list, the shared guard, the start-up self-check and the wiring suite). `docs/TASKLOG.md` is the authority on
task state; this
page is the map an agent needs to start without re-reading everything.

## 1. In one paragraph

`PIS Workflow` is a Tcl/Tk GUI that runs inside Altair HyperView, loads one model plus
several result files into a window grid, and applies one result type and one legend to
the active window or to all windows, journalling every HyperView call. Steps 1-4 (Load
All, Load Legend, Load result, Capture) and the log pane buttons ([Clear] [Save] [Load...] [Run log >])
are written and tested offline; Measures and Section cut
are not started (their class pages are still missing). Capture was sent back by the owner
(`T-011: fail 1`, F13), fixed by T-032 (four steps: select -> view -> Draw -> capture) and again by
T-033 after `fail 2` (F14): the view step is its own step with a documented receiver
(`poI3DViewCtrl SetActiveView` on the view control handle) and a documented read-back, the capture
call is the only thing variants apply to, and no generated script releases a page/window handle. The
same GUI run also showed Load All dying on a REFUSED duplicate handle name (F15) - a regression
T-033 caused when it removed those releases - which T-034 fixes by naming every handle per iteration
(`::pis::hw::hname`); T-034 is accepted (2026-11-18, together with T-011). T-035 answered F16 + F17 and
the owner accepted it on 2026-11-19 ("ok pass, accept."), so Load Legend is CLOSED (`T-007: ok`). The
log pane buttons are the live task now: T-012 (`[Clear] [Save] [Load...] [Run log >]`, continue-on-error,
status bar) is agent-done and its owner check is owed (section 4); T-013 (session persistence through the
ini) is the only other unblocked task. T-036 (2026-11-24) is the DOCS-ONLY answer to the owner's
2026-11-18 request: the `Measures` panel gains a `Macro Add` button that reads `Result.log`, and a
sixth panel `Notes` (row 3 column 2) arrives with its own `Macro Add` that reads `Notes.log` - both
are SPEC'd in `docs/SPEC.md` (A16-A20, Q1-Q12 of that pass, the "Macro Add" subsection) and
`docs/refs/SPEC_gui.txt` sections 14-15, with two sample files under `docs/refs/samples/`, and NO
code, test or ini key was touched. T-038 (2026-11-24) delivered the sixth `Notes` panel, its
`Macro Add`, the shared reader `::pis::dlog` (both `Result.log` and `Notes.log`) and the adapter's
note seams with `tests/tcl/test_datalog.tcl` (44 PASS) and `tests/tcl/test_notes.tcl` green - and
the owner's check then answered **FAIL**: fact F18, `invalid command name "::pis::notes::title"`
on every Notes control, because the GUI's source list never named `_tcl_pis_08_notes.tcl` (nor
`_tcl_pis_07_datalog.tcl`) while every suite sourced those files itself. T-039 (2026-11-24) is the
fix and is AGENT-DONE with the owner's check owed (section 4b): the source list now holds both
files, the three controls go through ONE guard in `run_module`, the start logs
`MODULES loaded: ok` right after BUILD, `tests/tcl/test_wiring.tcl` (95 checks) reads that list
and drives the real buttons, and a dummy `Notes.log` ships at the default location. Only the
owner's eye can confirm that a note is PAINTED - every press stays APPLIED-UNCONFIRMED (amber).
T-037 (`Macro Add` on Measures) is STILL BLOCKED on T-009, although the
reader half it needs shipped with T-038. `bash scripts/verify.sh` is the only build/verify entry point and
must end with `verify: OK`.

## 2. Build stamp

`::pis::BUILD` is set by hand in `src/01_scripts/_tcl_pis_11_hw_adapter.tcl`
(`variable BUILD "T13b-20261124-1506"`). T-039 moved it after T-038, because the GUI's source list,
`run_module`'s guard and the self-check changed (`T13a-20261124-1348` is the copy the owner's
`T-038: fail` came from). T-038 had moved it for the note seams
(`note_begin` / `note_send` / `note_now` / `note_eye`). T-036 was a DOCS-ONLY pass and therefore moved
NO stamp: a docs pass must never re-label the code the owner runs.
Bump the code + date whenever the `src/01_scripts`
copy changes (T-029 bumped it for a change in `_tcl_pis_03_load_result.tcl`, T-030 for the
result trace + V6 in the same file and for the log pane wrap in
`_tcl_pis_99_workflow_gui.tcl`, T-031 for the three-state verdict, the per-step trace, V0 and the
amber status line, T-011 for the capture op + `active_window` in the adapter, the new module
`_tcl_pis_06_capture.tcl` and the GUI capture block, T-032 for the four-step capture, the
PROVEN-first variant order, `::pis::hw::set_view`, the new name pattern and the GUI `capture_cfg`
keeping the ini keys, T-033 for the separated view step, `::pis::hw::view_table`/`set_view`
receiver discovery, the `GetActiveView`/`GetViewMatrix` read-back, `begin_capture`, the
`-viewstep` option, `[capture] on_view_unavailable` and the ReleaseHandle removal, T-034 for
`::pis::hw::hname` and the per-iteration handle names in every walk, T-035 for the Load Legend fix
(F16/F17): the per-window seam `::pis::legend::apply_to_window`, the adapter op `legend_visibility`
with `hwc show/hide legends` + `SetDisplayOptions legend`, the read-back gate `GetDisplayOptions
legend`, the deferred `hwc_defer`/`hwc_journal` pair, `begin_legend`/`adapt_legend*`, the shared
class table `tests/mock_hv_type.tcl` and the new section 27, T-012 for the log pane module
`_tcl_pis_20_journal_ui.tcl` (`::pis::jui`), the four wired buttons and the GUI `save_journal` /
`load_journal` / `run_journal` / `clear_log`, and T-038 for the notes: the shared reader
`_tcl_pis_07_datalog.tcl` (`::pis::dlog`), the new module `_tcl_pis_08_notes.tcl`
(`::pis::notes`), the adapter's `note_begin` / `note_send` / `note_now` / `note_eye` /
`select_window` and the GUI sixth panel + `macro_add`, and T-039 for the F18 fix: the two module
files in the GUI's source list, the ONE guard in `run_module` (error -> `ERROR module <Name>:
...` + traceback line + red status), `module_calls` / `check_modules` / `disable_module`, the
`Macro Add` binding through `run_module notes macro`, and `tests/tcl/test_wiring.tcl` - so the
owner's report names the copy and
not just the adapter);
`::pis::hw::build_line` prints it with the variant and layout counts, and the GUI logs the
same stamp at start, so any output the owner pastes names the exact code behind it.

## 3. Task board (see `docs/TASKLOG.md` for each task's full record)

| State | Tasks |
| --- | --- |
| accepted by the owner | T-001 .. T-005, T-007 (Load Legend, with T-035), T-008 (with its fixes T-026, T-027, T-029, T-030, T-031), T-011 (Capture, with T-032, T-033 and T-034), T-034 (the F15 repair itself) |
| reopened (VERIFY-GAP) | T-006 |
| agent-done, owner check owed | T-012 (log pane buttons - section 4a), T-014 .. T-019, T-036 (docs-only: the SPEC pass for the `Notes` panel and the two `Macro Add` buttons), T-039 (the F18 fix of the Notes controls - section 4b) |
| in progress (fix pass) | T-038 (the `Notes` panel + its `Macro Add` + the shared reader `::pis::dlog`): owner check FAIL 2026-11-24, fact F18, repaired by T-039; the reader half is green and unaffected, the panel awaits the eye check of a painted note |
| todo | T-009 (Measures), T-010 (Section cut), T-013 (session persistence through the ini) |
| blocked on a page the owner must paste | T-037 (`Macro Add` on Measures - it calls T-009's op, and T-009 waits for `poIMeasure`; its reader half shipped with T-038) |

- **T-008 is accepted (2026-11-18).** The owner's "ok pass. accepted." closed `fail 1` .. `fail 6`,
  and T-031 was the pass that answered `fail 6` (three-state verdict, one `STEP` line per setter, V0
  first from the owner's own macro, amber status for `APPLIED-UNCONFIRMED`). The module still holds
  no evidence of its own that a window PAINTS a contour (`GetDimensionEnabled` stays false on that
  build), and that limit is recorded in SPEC + TASKLOG, never removed.
- **T-011 (Capture) is ACCEPTED (2026-11-18).** The owner wrote "capture ok. confirm ok. accept." for
  the GUI + saved-log check, and with it T-034 (the F15 repair) is accepted too. `fail 1` (F13) and
  `fail 2` (F14) stay in TASKLOG, unedited, as history: T-032 rewrote the step (variants 1..5
  PROVEN-first, name `{result_file_name}_{view}.png`); T-033 (after `fail 2`) separated the VIEW step
  from the capture variants and found its real receiver in the docs: `poI3DViewCtrl SetActiveView
  active name` (S99) on the handle `<win> GetViewControlHandle <v>` (S103), read back with
  `GetActiveView` (S100). One image = select (layout only) -> view -> `Draw` -> capture call -> file
  check, each its own `hwi` script, ONE journal line per image, ONE `STEP` line per step while
  `[debug] capture_trace` is 1, and `[capture] on_view_unavailable` (stop | capture_current) for a
  build that cannot activate a view.
- **T-007 (Load Legend) is ACCEPTED (2026-11-19).** The owner answered "ok pass, accept." on the
  T-035 check (section 4 of that pass): one `LEGEND ok window k shown|hidden` per window, no
  `could not find requested method: GetPageHandle`, legend visible by eye with `on` ticked and hidden
  with it unticked. F16 (the page was reached from a `poIPost` client handle) and F17 (`on` is the
  Display Control > Legend toggle, not a skip) stay in TASKLOG as history - a new failure is a NEW
  defect line, never an edit of them. T-035 delivered: a class-aware mock (a method is only accepted
  on the handle TYPE that documents it, with the build's own 3-line text), the F16 reproduction test,
  the legend path through the adapter's proven `select_window` helper, op `legend_visibility` with
  V1 = PROVEN `hwc show legends` / `hwc hide legends` and V2 = DOC `poIPost SetDisplayOptions legend
  true|false`, read back with `GetDisplayOptions legend` (S57), per-window `STEP`/`LEGEND` lines, and
  the F17 import-then-show / hide order.
- **T-012 (log pane buttons) is agent-done (2026-11-19, owner check owed - section 4).** New module
  `_tcl_pis_20_journal_ui.tcl` (`::pis::jui`) holds the four rules and no widget: `[Clear]` asks only
  when the journal is dirty or a file was loaded, `[Save]` writes the SAME filter a replay uses (so
  A3 holds by construction, junk lines are counted and never written), `[Load...]` shows a file and
  runs nothing, and `[Run log >]` logs `skipped K`, confirms with `Run K command(s) from <source>?`,
  sends `hwc` lines through `::pis::hw::exec` and `hwi` lines through `::pis::hw::exec_hwi` (never a
  bare `uplevel`), logs one `OK` line per command, stops at the first error unless "continue on error"
  is checked, and reports the failing LINE NUMBER. A replay snapshots and restores the journal, its
  dirty flag and the module/item context, so it never doubles the journal. The GUI keeps only the
  dialogs and the status bar (`save_journal`, `load_journal`, `run_journal`, `clear_log`), and all
  four buttons are in the busy lock. `tests/tcl/test_journal_ui.tcl` = 141 checks; three mutations
  were run to prove the suite bites (stop-on-error disabled, unfiltered save, no journal snapshot).
- **T-034 fixed the Load All regression F15 (2026-11-18, agent-done).** The owner's build refuses a
  handle name that is still alive inside one open stack, verbatim `<name>: object with this name
  already exists.`; T-033 had removed the per-walk `ReleaseHandle` calls (correct, F14 c) while the
  walks still reused ONE fixed name per handle, and the old mock quietly re-defined the command, so
  the suites never saw the refusal. Every walk now names its handles per iteration
  (`::pis::hw::hname`, the owner's own proven form at `batchImportOdb.tcl:81-86`), the capture
  script emits each duplicate line once (after `fill`), and the three mocks now refuse a live
  duplicate with the build's own words - which is what makes a regression fail here instead of
  passing.
- **T-009 and T-010 are blocked** on documentation the owner has to supply: the supplier
  pages for `poIMeasure` and `poISection`. Nothing about those classes may be invented -
  a call gets written only after its page is saved as a source row in `docs/refs/HV_API.md`.
- **T-036 (2026-11-24, docs only) SPEC'd the owner's 2026-11-18 request** and touched no code: a
  `Macro Add` button in the `Measures` header (reads `Result.log`) and a sixth panel `Notes` at row 3
  column 2 with its own `Macro Add` (reads `Notes.log`). The rules live in `docs/SPEC.md` A16-A20 +
  the "Macro Add" subsection + that pass's own Q1-Q12, and in `docs/refs/SPEC_gui.txt` sections 14-15;
  the two files ship as `docs/refs/samples/Result.log` (the owner's template verbatim) and
  `docs/refs/samples/Notes.log` (T-039: the dummy `#Note1` file, also copied to `src/Notes.log` at
  the default location, so `Macro Add` works on the first try). No ini key was written:
  `[macro] result_log` / `notes_log`, `[notes]`, `[debug] notes_trace` are SPEC text until T-037 /
  T-038 land. T-037 is blocked on T-009 (it must call T-009's measure op); T-038 is unblocked because
  every note call is PROVEN in the owner's own scripts (`docs/refs/HV_API_REF.md` S07:312-344).
- T-012 and T-013 were the last two unblocked tasks of the earlier round; T-012 is now agent-done
  (above) and T-013 (session persistence through the ini) is still open. T-038 carried the `Notes`
  panel AND the shared reader `::pis::dlog`; its owner check failed (F18) and T-039 repaired the
  wiring, so the open list is: the owner's checks of T-039/T-038 (4b) and T-012 (4a), then T-013,
  then T-009/T-010/T-037 once the owner sends the `poIMeasure` / `poISection` pages.


## 4. Owner checks owed (GUI + saved log only, max 3 steps each)

### 4a. T-012 - the log pane buttons

Build `T13b-20261124-1506` is the copy to run (T-039 changed only the module wiring and the start
log; the log pane itself is unchanged since `T12a-20261119-0900`). Run **Load All** plus
one legend first, so the journal holds real lines (`# <stamp> | Load Legend | ...` + `hwc`/`hwi`).

1. Click **[Save]**, pick a path under `02_working/`, then open the file: every non-blank line must
   start with `hwc `, `hwi ` or `#`, and the log must say `Save: <n> line(s) written to <path>
   (<m> skipped)`. Then click **[Clear]**: exactly ONE confirmation must appear (the journal is now
   dirty); answering "no" must leave the journal and the pane untouched. That is A3 plus the s.8
   "confirm if journal is unsaved" rule.
2. Click **[Load...]** and pick the journal you just saved (or any `.txt` with a few junk lines): the
   file must be shown in the pane, the log must say `Load: <path> (<n> line(s) shown, nothing run)`,
   and NOTHING may change in HyperView. Then click **[Run log >]**: the dialog must read `Run <K>
   command(s) from <path>?` (K = the number of `hwc`/`hwi` lines), the log must show `Run log:
   skipped <m> line(s) ...`, one `OK line <n>: ...` per executed command, and the windows must end up
   in the loaded state. Answering "no" must execute nothing.
3. Put ONE wrong command (e.g. `hwc no such command`) into that file, `[Load...]` it again and run:
   the log must show `Run log: line <n> failed: <command> | <the build's own text>`, the status bar
   `Error: Run log line <n> failed`, and the commands AFTER it must not run. Tick "continue on error"
   and run again: the rest must run and the failure must still be reported.

Interpretation: A3 (only `hwc`/`hwi`/`#` lines in the saved file), A4 (K commands, K `OK` lines, the
dialog names K), A5 (`skipped <m>` on junk lines), the failing LINE NUMBER and continue-on-error are
the five things this check observes. A `Save journal: no hwc/hwi command to save` ERROR on an empty
journal is correct behaviour, not a defect. The display log is deliberately not saved to `.txt`.

Once the owner answers `T-012: ok` or `T-012: fail 1: <what was seen>`, that line is the only change:
the agent never writes `accepted` itself, and a failure becomes a NEW `T-012` defect line (a new task
number if the shape changes), never an edit of history.

History note: T-031's own GUI+log check was answered "ok pass. accepted." on 2026-11-18, which is why
T-008 is accepted; its spike files (`src/spike/t008_*.tcl`) stay as evidence only and no task reads
them any more. T-011's first check was answered `fail 1` (F13 a-d, fixed by T-032) and the second
`fail 2` (F14 a-f, fixed by T-033); F15 (the duplicate handle name that stopped Load All) came out of
that same GUI run and is fixed by T-034. The third GUI run was answered "capture ok. confirm ok.
accept." on 2026-11-18: T-011 and T-034 are accepted, and the SAME run produced F16 (the
`GetPageHandle` refusal) and F17 (the `on` toggle) for Load Legend, which T-035 answered. The run
after that (2026-11-19) was answered "ok pass, accept." on the T-035 check, so **T-007 and T-035 are
accepted** and the T-012 check in section 4 is the one now owed.

### 4b. T-039 - the three Notes controls (build `T13b-20261124-1506`)

Fact F18 was `invalid command name "::pis::notes::title"` on every Notes press. This check is
about the three controls, not about a perfect note: an amber
`Notes: applied, display not confirmed (look at the windows)` is CORRECT, a green ok is wrong.

1. Start the GUI: the log's FIRST line is the BUILD line, the SECOND is `MODULES loaded: ok`. If a
   module is missing instead, the line reads `ERROR module <Name> not loaded: missing <proc>` and
   that panel's three buttons stay dark - send that line. Press nothing yet.
2. **Load All**, then tick `Note 1` and `Note 3` in the Notes panel: press the `Notes` title button
   (those two notes must appear in the ACTIVE window), then **[Apply all layout]** (they must
   appear in every window), then untick all three and press again: ONE `WARN Notes: no row ticked`
   and no HyperView change. No Tk traceback may appear at any point.
3. Press **[Macro Add]** with the shipped dummy file (it sits at the default location,
   `Notes.log` next to `00_config` / `01_scripts`): the two dummy notes `PIS dummy note 1` and
   `PIS dummy note 2` must be readable. Press **[Save]** and send the log (BUILD line first) plus
   one sentence per window: note visible yes/no.

How to use your own file: the file has NO comments and NO adjust command (the T-038 grammar
cannot express either - SPEC A17), so it is just `#Note<N>` sections and five comma-separated
fields `Name, Text, X, Y, Z`. Replace `Notes.log` (or point `[macro] notes_log` at another file in
the ini) and press `Macro Add` again; `#Note2` would go to window 2, and a bad line stops the whole
press with `Notes.log line <n>: <what>` before any HyperView call.


## 5. What to do next, in order

1. Record the owner's verdict on T-039 (section 4b): accepted = `T-039: ok` AND the T-038 eye
   sentence; a failure is a NEW defect line with the quoted log lines, never an edit of the T-039
   or T-038 entry. What to look at: the BUILD line, `MODULES loaded: ok` as the second line, no Tk
   traceback on any of the three Notes controls, the two ticked notes in the active window and in
   every window, ONE `WARN Notes: no row ticked` on an unticked press, and the two dummy notes of
   `Macro Add` visible. The status must stay amber
   `Notes: applied, display not confirmed (look at the windows)`; a green "ok" would be wrong,
   because nothing on this build can confirm a note.
2. Record the owner's verdict on T-012 too (section 4a): accepted = `T-012: ok`, or a NEW defect
   line with the quoted log lines. T-012 and T-039/T-038 are the tasks with an owner check owed;
   T-007 / T-035 are closed (accepted 2026-11-19), and T-036 is docs-only (its check is three
   files, not a GUI run).
3. T-013 (session persistence through the ini: `[log] continue_on_error`, every field and selection
   restored on start, saved on exit) - and it now also has to carry the new `[notes]` list.
4. Ask the owner for the `poIMeasure` / `poISection` pages, then write T-009 / T-010 with
   the same doc-first protocol the result and capture steps used (HV_API.md rows before code).
   T-037 (`Macro Add` on Measures) waits behind T-009: it must call that op, not a second copy of it.
   Its reader (`::pis::dlog`) is already built and tested, so only the measure op and the header
   slot are missing there.

## 6. UNKNOWN facts this project is currently living with

- **Which class handle carries `SetActiveView`** (T-032) - ANSWERED by T-033: `poI3DViewCtrl`
  (HV_API.md S99, 2024 and 2026 help), reached through `<win> GetViewControlHandle <v>` (S103). The
  owner's `fail 2` had already proved the PAGE guess wrong (`hwIPage` has no such method). The
  module's `::pis::hw::view_table` still carries three UNVERIFIED-GUESS receivers after the
  documented one, each tried ONCE, so if his build differs the log names the receiver that worked.
- **Which capture call his build accepts** (T-032): variant 1 `CaptureImage` (PROVEN, his loader's
  first form) is expected; 2 `CaptureScreen` and 3 `CaptureScreenToSize` grab the whole application,
  so an image of a 2-window layout would show both windows - the log's `CAPTURE ctx` line says which
  call wrote each file and `CAPTURE ok window k variant <n>` pins it.
- is `GetDimensionEnabled` (S36) evidence of what the window PAINTS? It never read true on the
  owner's build while the type and the display option were right (F12), and a nodal result may keep
  line/shell/solid false. SPEC.md (T-031) therefore calls it UNVERIFIED display evidence: it can only
  turn `APPLIED` into `APPLIED-UNCONFIRMED`, never into a failure.
- does `SetDataType` keep or reset the dimension enable state? Both orders are still variants.
- is a `Draw` needed before `GetDimensionEnabled` reports the change? Measured by the `STEP` lines.
- is the contour DISPLAY off in the window even when every dimension reads enabled? Only
  `poIPost SetDisplayOptions contour true` (S56) is documented as a display switch, and its
  read-back `GetDisplayOptions contour` (S57) is part of the trace, the STATE DUMP and `snap`/`diff`;
  V5 is the only variant that sends it.
- is the contour DATA not loaded at all? S53 `SetEnableState true` is the auto load/unload state, not
  a display switch; V0 and V6 send it after `SetDataType`, and `GetEnableState` (S54) now prints what
  it answered in every `STEP ... now:` part.
- what does `::hwp::GetContourLegend` (S02:43-57) return on this build? The `LEGEND` line prints it;
  its meaning is UNVERIFIED, so it never enters the verdict.
- **Are handle NAMES constrained by the build?** (T-034) - one half is ANSWERED by the owner's build:
  a name that is still alive inside one open stack cannot be created a second time (`<name>: object
  with this name already exists.`), and only `ReleaseHandle` on that handle or `CloseStack` frees it.
  The docs say nothing else about names. NOT answered: whether any name is reserved, and whether
  `<page> GetWindowHandle` still answers after a `reset_all` walk removed those windows' models -
   Load All with the `OK` lines is what measures the second one (that owner check was answered
   "ok pass. accepted." on 2026-11-18; T-006 stays `reopened` only for its VERIFY-GAP history).
- **Does this build answer `GetDisplayOptions` / accept `SetDisplayOptions legend`?** (T-035, F16 +
  F17) - the QUESTION THAT MATTERED is ANSWERED by the owner's eye: on 2026-11-19 he accepted the
  T-035 check, so on his build the legend appears with `on` ticked and disappears with it unticked,
  in every window. What is still NOT answered is which call did it: the owner's PROVEN form is
  `hwc show legends` / `hwc hide legends`, which prints nothing, so its effect can only be seen by
  eye; `poIPost SetDisplayOptions legend <true|false>` (S56) is documented but has never been sent to
  this build, and S57's literal is unknown (`true`/`false`, `show`/`hide` and `1`/`0` are all accepted
  by the parser, the log prints what came back). Because no getter is documented for V1,
  `legend_visibility` V1 stays UNVERIFIED-GUESS and logs one `must be checked by eye` INFO per run -
  never an OK on "no error". A future pass may read the saved log of an owner run to learn which
  variant actually carried the change on this build.
- **Can a `Notes` press ever be proven?** (T-036 / T-038) - NO, on today's evidence: this build may
  ignore an `hwc` command in silence, and no per-note getter is quoted anywhere in `docs/refs/HV_API.md`
  or `HV_API_REF.md`. `poIPost GetDisplayOptions notes` (S57, and `notes` is in S56's name list) is the
  only documented query, and it speaks for the WINDOW's notes category, never for one named note. So
  every press is `APPLIED-UNCONFIRMED` (amber, `Notes: applied, display not confirmed (look at the
  windows)`) plus ONE `notes: no documented getter, window k must be checked by eye` per run, and the
  owner's eye is the proof. A `poINote` page, if one exists, would close this (HV_API.md section 9
  item 7). **The `Notes.log` grammar itself is an ASSUMPTION** (SPEC Q8-Q11): the owner has not sent
  the file, `docs/refs/samples/Notes.log` is a dummy (T-039: two DISPLAY notes in `#Note1`, no
  ADJUST row and no comments, because that grammar has neither), and the day he pastes the real file the
  SPEC and the reader change FIRST, never silently.

The first four are measured by the log itself: `TRACE ... BEFORE`, one `TRACE ... sent` line per
variant, one `STEP` line per setter (return or error), `NOCHANGE`/`CHANGED`, `TRACE ... LATE` and
`FALSE-NEGATIVE GUARD`. The `t008_*` spike files and the recorded macro stay available as
diagnostics, but no check depends on them. Until an order is PROVEN the code tries seven variants
(V0 first) and judges each by the read-back only. Never turn any of these questions into an
assumption in product code.

## 7. Rules that must not be broken

- **Doc first.** No HyperView call exists in code before `docs/refs/HV_API.md` names it
  with a source row (`S1`, `S2`, ...), a class (`DOC`, `PROVEN`, `BASED`,
  `UNVERIFIED-GUESS`) and, when nothing prints the behaviour, the exact owner command that
  measures it.
- **Absent method rule** (`::pis::hw::absent_*`): when the build answers `could not find
  requested method: <name>`, that method is recorded for the run, never sent again, logged
  once, and the code path that needs it is skipped instead of retried. The longer text that
  adds `or the method was called with incorrect arguments` counts only when the arguments
  were the documented ones.
- **Receiver type rule** (T-035, F16): a method is sent only to the handle TYPE whose page documents
  it - `tests/mock_hv_type.tcl` is the machine copy of that table. `GetPageHandle` belongs to
  `hwIProject`, so a page is reached `session -> project -> page` and a window is selected with
  `page SetActiveWindow k`; a `poIPost` CLIENT handle is never asked for the page. A mock that
  answers any method on any handle is exactly what hid F16 while every suite was green: keep
  `::mockhv::guard` in every mock.
- **Wiring rule** (T-039, F18): every module must be wired through the GUI's OWN source list (the
  `foreach _pis_file {...}` block of `_tcl_pis_99_workflow_gui.tcl`) and covered by
  `tests/tcl/test_wiring.tcl`, which reads that list, sources it and drives the real buttons. A
  task that adds or renames a proc called ACROSS files must list the callers it checked (the
  `module_calls` table, the dangling-call scan and the report's call/definition table); a suite that
  sources the module files itself proves nothing about the GUI. A new module is loaded only when
  the start-up self-check says `MODULES loaded: ok` for it.
- **One handle name per iteration** (`::pis::hw::hname`): inside one open stack a name that is still
  alive cannot be created twice (F15: `<name>: object with this name already exists.`), and
  `ReleaseHandle` is not allowed on session/project/page/window/view handles (F14 c), so a walk names
  each handle with its loop index (`pisWin_$pisWi`) and builds text with `[hname <base> {<var>}]`.
  Never reuse a fixed handle name across iterations, and never let a mock accept one.
- **ASCII only** in `src/`, `tests/`, `scripts/`; **Tcl 8.5 only** in `src/01_scripts/`
  (no `lmap`, `tailcall`, `coroutine`, `yield`, `string cat`, no `try`/`finally`, no
  tcllib). `verify.sh` fails the build on a violation.
- **Never weaken a check to make it pass** (`AGENTS.md`). A failing test is a fact.
- **Scope**: a task may modify only the files its `Only modify:` line lists.
- **Two signatures**: the agent writes `agent-done` only with real command output; only the
  owner writes `accepted`.
- Everything the owner drops in `src/02_working/` stays out of git.

## 8. Code seams (what to call, not to copy)

| Layer | Entry points |
| --- | --- |
| adapter (`11_hw_adapter.tcl`) | `::pis::hw::exec`, `::pis::hw::exec_hwi <script> -nojournal`, `::pis::hw::journal_run`, `::pis::hw::context`, `::pis::hw::refresh`, `::pis::hw::absent_*`, `::pis::hw::build_line`, `::pis::hw::announce`, `::pis::hw::hname` (the only handle-name spelling: `hname pisWin 3` -> `pisWin_3`, and script text passes `{$pisWi}`), builders for the window grid (`variants`, `make_grid`, `layout_*`) and for observing a page (`observe`, `clients`, `page_info`); the capture seam: `capture_window {k path view unit w h ?-row? ?-layout? ?-trace?}`, `capture_image`, the script builders `capture_frag` / `capture_step_script` / `capture_full_script` / `capture_now`, `set_view {k name}`, `active_view`, `view_getter` / `view_list_getter`; the legend seam: `legend_visibility {k show ?do_select? ?trace?}`, `legend_select {k ?trace?}`, the read-back `legend_now` / `legend_now_text`, the answer parsers `legend_word` / `legend_flag` / `legend_state`, the deferred journal `hwc_line` / `hwc_defer` / `hwc_journal`, `begin_legend` and the per-run cache `adapt_legend` / `adapt_legend_getter` |
| feature modules (`01`, `02`, `03`, `06`) | `::pis::<module>::run {root cfg scope}`, `title`, `need_common`, `need_hw`, `reset_state`; the result module also exposes `variants`, `variant_info`, `variant_name`, `variant_needs`, `build_script`, `plan`, `read_state`, `verdict`, `verdict3`, `apply_to_window`, `targets`, `selected_item`, `window_file`, `match`, `enable_list`, `step_list`, `step_script`, `opts_text`, `snap_values`, `ident_text`, `legend_line`, `trace_on`, `try_all_on`; the legend module exposes `apply_to_window {index path on trace}` (the one seam), `targets`, `selected_item`, `trace_on`, `handle_name`, and the counters `applied` / `shown` / `hidden` / `failed` / `calls`; the capture module exposes `items`, `checked_rows`, `item_text`, `size_spec`, `image_type`, `trace_spec`, `continue_on_error`, `output_dir`, `file_base`, `file_name`, `unique_path`, `result_part`, `windows`, `not_attempted`, `restore_view`, `sanitize` |
| GUI (`99_workflow_gui.tcl`) | `::pis::gui::build`, `run_module`, `result_cfg`, `legend_cfg`, `capture_cfg`, `log_line`, `set_status`, `busy_guard`, `continue_on_error`, and the log pane of T-012: `clear_log`, `save_journal`, `load_journal`, `run_journal` |
| journal pane (`20_journal_ui.tcl`) | `::pis::jui`: `text`, `origin`, `dirty`, `scan`, `confirm` (the yes/no seam the tests replace), `clear`, `save`, `load`, `run`, `coe`, `exec_line`, `reset_state` - the rules live here, the widgets and the file dialogs stay in the GUI; it calls no HyperView command of its own (a replay goes through `::pis::hw::exec` / `exec_hwi`) |
| common (`00_common.tcl`) | `load_config`, `save_config`, `get`, `log`, `to_bool`, `require_file`, `resolve_path` |

A module never builds a HyperView script by hand: it asks the adapter's builders, sends it
through `exec_hwi`, and journals it only when the step really changed the state.

## 9. Tests

- `tests/tcl/test_*.tcl` run under plain `tclsh` against a fake HyperView API: no
  HyperView, no display, no network. Every file must exit 0.
- `tests/tcl/test_result.tcl` drives the result step with switches that make the fake build
  behave like a real one: `resetdims` (SetDataType resets the dimensions), `boolform`
  (only `1`/`0` accepted), `absent` (a method the build does not have), `missingdims` (a
  model without solids), `enabledstate`/`needenable` (a build whose contour data is not
  loaded until `SetEnableState true`), `display`/`ignoreoptions` (what `GetDisplayOptions contour`
  answers and whether the documented display line is a silent no-op), `enableread` (what
  `GetEnableState` answers), `raiseon` (one setter that raises, for the `STEP ... -> ERR` path),
  `legend`/`legenderr` (what `::hwp::GetContourLegend` returns). Section 33 covers T-031:
  literal text, one STEP line per setter, the three verdicts, the same journal text in both trace
  modes, the read-only getters, the legend probe and V0. Counters `calls`, `enables`, `enablesets`,
  `absentcalls`, `setcalls` and the `order` list prove what was sent, in which order.
- `tests/tcl/test_capture.tcl` (T-011, rewritten by T-032 and T-033, 210 checks) mocks the capture
  calls so that each really writes the file, then proves: the name `{result_file_name}_{view}.png`
  (no model), the sanitizing, `noresult`, the `_2`/`_3` collision suffixes (including the
  case-insensitive folder), the `[capture] checked` flags ("0 1 1"), the size spec
  (`image_width`/`image_height` and the older `width`/`height`), `image_type` must be png,
  `[debug] capture_trace`, `[capture] on_view_unavailable` (default `stop`, `capture_current`,
  unknown refused), the output folder, the WARN on an empty selection, the STEP SEQUENCE per image
  (active scope: view -> draw -> call; layout scope: select -> view -> draw -> call), the view name
  with spaces and dots arriving as ONE argument, one journal line per image that holds the view
  change before the call, the variant order (owner's `CaptureImage` first, PROVEN
  `CaptureScreen`/`CaptureScreenToSize` next, DOC `CaptureWindow` last, the percent variant skipped
  when the unit is percent), a call that answers 0 and writes nothing (FAILURE naming the call, the
  answer and the path, nothing journaled), the build's own error code, an empty file, and the T-033
  cases: (a) only the CLIENT handle accepts SetActiveView -> the view step succeeds there, the
  receiver is cached and logged ONCE, window 2 starts with it; (b) no receiver accepts it -> one
  failure, `capture call not attempted`, ZERO capture calls, one absent INFO per type, every tried
  type in the absent list, and a second run that sends nothing; (c) `capture_current` -> one WARN,
  every window captured, no view line in the journal; (d) the method exists but the view name is
  unknown -> discovery stops, the raw text is reported, nothing recorded absent; (e) the name as ONE
  argument with no unresolved token; (f) camera evidence (unchanged -> WARN, changed -> INFO, no
  getter -> one note per run); (g) the exact `view '<name>' not active in window k (read: <v>)` with
  a mismatch; (h) the ReleaseHandle scanner over every op/variant and every step script plus a seeded
  `catch {pisPage ReleaseHandle}` that MUST be flagged and the scripts really sent during the file;
  (i) the accepted capture variant cached for window 2; (k) trace on/off with the same journal text;
  (l) one STEP block per failing step, not one per variant. Then 4 windows x 2 views = 8 names with
  `_2`, window 2 failing (one ERROR line with window/row/view/step/raw, `windows 3..4 not
  attempted`, `captured 2 of 8`, and `captured 6 of 8` with continue_on_error), a journal line that
  replays to the same steps, the adapter's argument checks, the byte-identical ini, and the GUI
  wiring (`capture_cfg` keeps the ini keys, `run_capture`, `run_module`). The mock's switches are
  `view_ok` (which handle kinds accept SetActiveView), `view_other` (kinds whose call answers another
  error), `gav`/`gvm` (the two getters), `cam`, `ok_image`, `ok_screen`, `ok_tosize`, `ok_window`,
  `capture_code`, `write_file`, `cap_bytes`, `fail_win`, `aw_fail`; `::seq` holds the step tags in
  order, `::caps` every capture call's arguments verbatim, `::seen` every {handle kind, name} the
  view step asked and `::attempts` how often.
- **Every mock now has HyperView's handle-name rule** (T-034, F15): `::sim::mkhandle`/`sim_mkh` raise
  the build's own words when a name is created twice while it is still alive, and only `ReleaseHandle`
  on that handle or `CloseStack` frees a name. `tests/tcl/test_hw_adapter.tcl` section 26 is the
  guard: (a) the mock really refuses a live duplicate, (b) a page of FOUR windows goes through
  `make_grid`, every read-back and `reset_session` against it, (c) a static scan proves no script text
  creates one literal handle name twice (a seeded offender MUST be caught, the per-iteration
  `pisWin_$pisWi` form must not be, and a `names >= 10` counter stops the scan from passing by
  looking at nothing). `test_hw_adapter.tcl` 524 checks, `test_block0.tcl` 273, `test_result.tcl` 346,
  `test_hw_exec.tcl` 92, `test_legend.tcl` 100, `test_common.tcl` 46, `test_gui_frame.tcl` 25, `test_journal_ui.tcl` 141 (T-012).
   `bash scripts/verify.sh` on 2026-11-19: 18 `.tcl` files parsed, 32 ASCII, 9 Tcl 8.5, 9 suites ok,
   `verify: OK`. The T-012 suite proves its own bites (three mutations, each reverted): disabling
   stop-on-error made 2 checks fail, writing the UNFILTERED text from `[Save]` made the junk-line
   check fail, and removing the journal snapshot made 2 checks fail (the replay doubled the journal).

- **Every mock is CLASS-AWARE** (T-035, F16): `tests/mock_hv_type.tcl` holds ONE table
  `kind -> {class methods}` built only from rows that name a receiver type (session `hwISession`,
  project `hwIProject`, page `hwIPage`, window `hwIWindow`, client `poIPost`, model `poIModel`, ctrl
  `poIResultCtrl`, manager `poIPostManager`, viewctrl `poI3DViewCtrl`, contour `poIContourCtrl`), and
  `::mockhv::guard <kind> <name> <method>` raises the build's own three-line text
  (`Object named: ... (of type <T>) / could not find requested method: ... / Or the method was called
  with incorrect arguments.`) when a method belongs to another type. A kind nobody types and a method
  no page lists stay UNRESTRICTED - the mock lists those as `receiver unknown` and section 27 of
  `test_hw_adapter.tcl` asserts both escape hatches plus "every kind this file creates is typed".
  `test_legend.tcl` section 1 is the F16 reproduction: the mock refuses `GetPageHandle` on a `poIPost`
  handle, and a layout run then completes EVERY window with `pisP GetPageHandle pisPage` in its trace.
- **The wiring suite** (T-039, F18): `tests/tcl/test_wiring.tcl` (95 checks) is the one suite that
  does NOT source the module files of its own choosing. It reads the `foreach _pis_file {...}` list
  out of `_tcl_pis_99_workflow_gui.tcl` by brace matching, sources those files in that order in a
  fresh `tclsh`, sources the GUI with `::pis_gui_autobuild 0`, and drives the real handlers
  (`run_module notes active|layout|macro` plus both buttons of the other five panels), asserting
  `catch` code 0 and a log line per press. It also scans every listed file for `::pis::<ns>::<name>`
  at command position and requires each to resolve (ONE allowlist entry with its reason:
  `::pis::hw::wait_error` is a `catch` result variable), seeds a missing `::pis::notes::nosuch` to
  prove the scan bites, checks `module_calls` against the GUI's own references, and reproduces both
  the guard sentence and the self-check (`MODULES loaded: ok`, then a renamed-away proc ->
  `module Notes not loaded: missing ...`). Delete a module file from the list and this suite fails;
  that is the point. `bash scripts/verify.sh` on 2026-11-24: 20 `.tcl` files parsed, 37 ASCII, 11 Tcl
  8.5, **12** suites ok (`test_wiring` 95, `test_notes` 80, `test_gui_frame` 41, `test_datalog` 44),
  `verify: OK`.

- Add a section to the matching file, use the local `check` helper, keep it ASCII, and let
  `bash scripts/verify.sh` pick it up.

## 10. Docs map

| File | Role |
| --- | --- |
| `docs/SPEC.md` | the contract (A1..A20 - A16-A20 are the 2026-11-18 additions, and that pass carries its own Q1-Q12 at the end); A10 = the result step, A2-A5 = journal / filter / replay, the `::pis::jui` API + "Journal pane contract (T-012)" = the four log-pane buttons, the "Macro Add" subsection = the two data-file actions |
| `docs/TASKLOG.md` | every task, every decision, every `Ran:` line |
| `docs/refs/HV_API.md` | supplier digest: S-rows (S1..S105), classes, F-facts, section 6 = the capture calls + the view step (S99-S105: `poI3DViewCtrl SetActiveView`/`GetActiveView`/`GetViewList`/`RestoreView`, `hwIWindow GetViewControlHandle`, `GetViewMatrix`), section 7 = the Load Legend seam (F16 handle chain, F17 `on` as the Display Control > Legend toggle, `hwc show/hide legends` + `SetDisplayOptions legend`) AND the Notes subsection (the PROVEN `hwc annotation note` calls of S07, S56/S57's `notes` name, and the per-note getter that does not exist), section 10 = the variant map, section 11 = the result step |
| `docs/refs/HV_API_REF.md` | the PROVEN digest of the owner's own scripts (S02, S03, S06, S07): capture (S06:249/260, S07:544), legend, measures, the handle patterns |
| `docs/refs/HV_OWNER_capture_hits.txt` | the mined capture code the owner actually runs (2026-11-18, T-032): file:line excerpts + the script-vs-module table; the T-033 block at the end records the second search round and the receiver answer |
| `docs/refs/SPEC_load_model.txt`, `SPEC_load_legend.txt`, `SPEC_gui.txt` | the owner's real specs (SPEC_gui s.14-s.15 = the 2026-11-18 amendment: the `Notes` panel, the two `Macro Add` buttons and the shared data-file grammar) |
| `docs/refs/samples/` | the two data files as they must look: `Result.log` = the owner's template verbatim (2 lines), `Notes.log` = the T-039 dummy (`#Note1` + column row + two DISPLAY notes; also at `src/Notes.log`) - neither file may carry prose, because every `#` line is a section and every other line is a data row |
| `docs/BOOTSTRAP.md`, `docs/BRIEF.md` | the generic template procedure (kept for new projects) |
| `docs/archive/` | older copies of files, kept for diffing only |

## 11. First-day checklist for the next agent

1. `bash scripts/verify.sh` -> `verify: OK` (if it is red, that is your first task).
2. Read `AGENTS.md`, `rules/core.md`, `rules/t1.md`, then `docs/SPEC.md` A10 and
   `docs/refs/HV_API.md` section 11.
3. Read the T-008 / T-026 / T-027 / T-029 / T-030 / T-031 lines in `docs/TASKLOG.md` - they hold the
   whole history of the result step, including the failures and why each happened (T-031 also holds
   the macro-vs-module comparison table and the `[1. Endure_SF_A]` answer) - then the T-011 block
   (`fail 1` F13 and `fail 2` F14), the T-032 line (four steps, PROVEN-first variant order, name and
   file proof) and the T-033 line (the view step's real receiver `poI3DViewCtrl SetActiveView`, the
   bounded receiver discovery, `GetActiveView` read-back, `[capture] on_view_unavailable`, the
   ReleaseHandle removal) - and finally the T-034 line (the handle-name rule F15) and the T-035 line
   (F16 + F17: the class-aware mock, the per-window legend seam and `legend_visibility`), then the
   T-012 block (the log pane: the two doors, the filter that both `[Save]` and `[Run log >]` use, the
   journal snapshot, and the suite's three mutations).
4. Take the next task from section 3 and stay inside its `Only modify:` list. Before touching the
   `Notes` / `Macro Add` code, read the T-036 block in `docs/TASKLOG.md`, `docs/SPEC.md` A16-A20 + that
   pass's Q1-Q12 and `docs/refs/SPEC_gui.txt` s.14-s.15: the two sample files under
   `docs/refs/samples/` are INPUT FORMAT, not examples to improvise around.
5. Report with: status, the real `verify.sh` output, changed files, the new `::pis::BUILD`
   stamp, and at most three "How to check" steps for the owner.
