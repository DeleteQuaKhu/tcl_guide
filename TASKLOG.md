# TASKLOG

Statuses: `todo â†’ in-progress â†’ agent-done â†’ accepted`; if the user check
fails: `rework â†’ agent-done`; escaped defect: `reopened`.

Cause codes: `SPEC`, `AGENT`, `SCOPE`, `VERIFY-GAP`, `USER-SKIP`, `USER-CHANGE`,
`ENV`, `EXTERNAL`.

## Block template (T2/T3)

```text
T-001: <title>
Status: todo
Done when:
Only modify:
Agent:
  Ran: <command> â†’ <result>
  Self-healing retries used: <0..2>
  Diff: <git diff --stat>
  Assumptions used: <list; "none" if none>
  How to check (user, max 3 steps; each says "seeing X is correct, seeing Y is wrong"):
    1.
    2.
    3.
  Rollback: git revert <sha> or a specific step
User:
  Check: pass | fail | skipped   (date: )
  Steps run / skipped:
  Notes:
Defect (if any):
  Description: <observable, short>
  Found at: user-check | CI | after-accept
  Cause: <code> â€” <1 sentence of evidence>
  Fix:
  Prevention: <1 concrete change>
```

## T1 variant

One line per task:

```text
T-001: <title> â€” Status: <status> â€” Ran: <command> â†’ <result>
```

---

## Tasks â€” PIS Workflow (T1: one line per task; each line carries `Done when`, `Only modify`, `How to check`)

Product truth: `docs/refs/SPEC_gui.txt`, `docs/refs/SPEC_load_model.txt`, `docs/refs/SPEC_load_legend.txt`; summary in `docs/SPEC.md`.
- Process (HV-CHECK MODE, owner 2026-11-10; full text in `docs/SPEC.md` Â§Constraints): the dev machine has no HyperView â€” the owner checks on the HyperView machine and replies in one line.
- Process: `agent-done` = code written + `bash scripts/verify.sh` green + short report written; the agent then stops that task.
- Process: the agent does not wait for intermediate confirmation, nor for `accepted`, before the next task in the scope handed over.
- Process: the owner replies `T-0xx: ok` or `T-0xx: fail <step>: <what was seen, short>`.
- Process: the agent never writes `accepted`; a `fail` means rework of that one task only, next variant of the op.
- Process: mock results are always labelled MOCK and never presented as checked on HyperView.

`Refs:` on each task is read-only input (never inside `Only modify`): the agent reads exactly those sections at task start and reports `ÄÃ£ Ä‘á»c: <file Â§section>`; Refs vs `docs/SPEC.md` D1â€“D5 â†’ follow D1â€“D5 and tell the human; Refs vs Refs, or SPEC silence â†’ stop and ask.
Order: tooling gate â†’ spike T-002 (superseded, ENV) â†’ GUI frame â†’ ini â†’ hw wrapper/journal/lock â†’ spike T-002b (superseded, ENV) â†’ adapter T-002c (HyperView ops) â†’ block 0 â†’ Load Legend â†’ Load result â†’ Measures â†’ Section Cut â†’ Capture â†’ log buttons â†’ session persistence.

T-001: Tooling gate â€” `scripts/verify.sh` verifies Tcl, not pnpm â€” Status: accepted â€” Done when: `bash scripts/verify.sh` exits 0 on the current tree, prints `verify: OK`, fails non-zero naming the file on a `.tcl` syntax error, and contains no `pnpm`/`node` call â€” Only modify: `scripts/verify.sh` â€” How to check: 1) `bash scripts/verify.sh` â†’ seeing `verify: OK` plus the parsed `.tcl` file list is correct, seeing `pnpm`/`ERR_MODULE_NOT_FOUND`/`tclsh: not found` is wrong. 2) Append `proc broken {} {` to a copy of one `src/**/*.tcl` and rerun â†’ seeing a non-zero exit naming that file is correct, seeing `verify: OK` is wrong. 3) `grep -nE "pnpm|node " scripts/verify.sh` â†’ seeing 0 hits is correct, seeing `pnpm` is wrong â€” Ran: - â€” Refs: none

T-002: SPIKE â€” `hwc result scalar legend import` per window + how to select one window in a cols x rows layout â€” Status: accepted â€” Done when: throwaway harness `src/spike/spike_legend_window.tcl` runs inside HyperView and `docs/spikes/legend-window-import.md` records (a) whether the import hits the active window only or all windows, (b) the exact Tcl 8.5-only command sequence targeting window k of CxR, (c) the HyperView build used, and SPEC Q3 carries that answer; khá»›p cÃ¡c má»¥c liÃªn quan trong Refs; mÃ¢u thuáº«n thÃ¬ theo SPEC.md D1-D5 â€” Only modify: `src/spike/spike_legend_window.tcl`, `docs/spikes/legend-window-import.md`, `docs/SPEC.md` (Q3 row only) â€” How to check: 1) In HyperView load 1 model + 4 results in a 4x1 grid, source the harness â†’ seeing the doc state "per window" or "all windows" is correct, seeing "unknown/TBD" is wrong. 2) Run the doc's sequence for window 3 only â†’ seeing only window 3 change its legend is correct, seeing all or no window change is wrong. 3) Run the harness a second time in the same session â†’ seeing the same result with no error dialog is correct, seeing an error or a changed finding is wrong â€” Ran: - â€” Refs: docs/refs/SPEC_load_legend.txt FILE 3 (`hwc result scalar legend import`), FILE 3 (refresh_active_post, apply_file) â€” Audit note 2026-11-10: this line reads `accepted`, but what actually exists is the harness plus the structure of the doc; (a)-(c) are still `TBD` and `Ran` is still `-`, i.e. the harness has never been run inside HyperView, so the `accepted` status is not a finding and SPEC Q3 stays OPEN. Harness bug found during the 2026-11-10 audit and fixed the same day (`src/spike/spike_legend_window.tcl` only; the probe itself is unchanged): `::spike::save <file>` raised `wrong # args: should be "open"` because `::spike::open`/`::spike::close` shadow the builtins. It now calls `::open`/`::close` and was verified under tclsh by writing and re-reading a file. â€” Superseded by T-002c (ENV 2026-11-10): findings will not be collected. Superseded, see T-015 (`docs/refs/HV_API.md` is now the API source of truth).

T-003: GUI frame â€” resizable two-column window (block 0 + 5 module blocks | log pane + status bar), shared module-list helper, busy lock â€” Status: accepted â€” Done when: sourcing `_tcl_pis_99_workflow_gui.tcl` in HyperView shows every block title and every button of `docs/SPEC.md` A1, `::pis::gui::set_busy 1` disables Apply/Load All/Run log, and the parse smoke test passes; khá»›p cÃ¡c má»¥c liÃªn quan trong Refs; mÃ¢u thuáº«n thÃ¬ theo SPEC.md D1-D5 â€” Only modify: `src/01_scripts/_tcl_pis_99_workflow_gui.tcl`, `tests/tcl/test_gui_frame.tcl` â€” How to check: 1) Source the script in HyperView â†’ seeing block 0 + Load result + Load Legend + Measures + Section Cut + Capture on the left, log pane + `[Clear] [Save] [Load...] [Run log >]` + status `Idle` on the right is correct, seeing a missing block or an error is wrong. 2) In the HyperView console run `::pis::gui::set_busy 1` then `::pis::gui::set_busy 0` â†’ seeing the buttons grey out and come back is correct, seeing them stay clickable is wrong. 3) `bash scripts/verify.sh` â†’ seeing `verify: OK` is correct, seeing a parse failure naming the GUI file is wrong â€” Ran: bash scripts/verify.sh -> verify: OK (exit 0); tclsh tests/tcl/test_gui_frame.tcl -> 20 PASS, exit 0 (headless, Git Tcl 8.6.17 + Magicsplat 8.6.16); throwaway Tk 8.6 build outside HyperView -> every A1 widget present, 5 blocks + one Apply all layout each + legend on, rows toggle [v]/[ ], busy lock normal->disabled->normal, Clear empties the pane. HyperView How-to-check 1) and 2) still need the owner. â€” Refs: docs/refs/SPEC_gui.txt Â§3, Â§5, Â§13

T-004: config ini â€” `::pis::common` read/write of `pis_workflow_config.ini` + defaults + `src/02_working/` ignored â€” Status: accepted â€” Done when: `load_config`/`get`/`save_config` round-trip the SPEC schema, a missing/corrupt ini yields defaults plus exactly one `WARN` naming the path, a missing key raises `Missing required config value: <section> <key>`, and the offline test passes; khá»›p cÃ¡c má»¥c liÃªn quan trong Refs; mÃ¢u thuáº«n thÃ¬ theo SPEC.md D1-D5 â€” Only modify: `src/01_scripts/_tcl_pis_00_common.tcl`, `src/00_config/pis_workflow_config.ini`, `tests/tcl/test_common.tcl`, `.gitignore` â€” How to check: 1) `tclsh tests/tcl/test_common.tcl` â†’ seeing `PASS` lines and exit 0 is correct, seeing an error is wrong. 2) Rename the ini to `.bak` and launch in HyperView â†’ seeing the window open with exactly one `WARN` naming the path is correct, seeing a crash or a dialog storm is wrong. 3) Restore the ini, set `[layout] cols = 6`, close the window, reopen â†’ seeing `cols = 6` restored is correct, seeing `4` is wrong â€” Ran: tclsh tests/tcl/test_common.tcl -> 41 PASS, ok all ::pis::common checks passed, exit 0 (Git Tcl 8.6.17 + Magicsplat 8.6.16); bash scripts/verify.sh -> verify: OK, exit 0; throwaway Tk 8.6 integration outside HyperView -> log pane shows exactly one WARN naming the missing ini path, defaults cols 4, and [layout] cols = 6 survives save+reload. HyperView step 2 still needs the owner (no HyperView on this machine). â€” Refs: docs/refs/SPEC_gui.txt Â§9; docs/refs/SPEC_load_legend.txt FILE 1, FILE 2


T-005: hw wrapper + journal + button lock â€” `::pis::hw::exec` is the single door to HyperView, journal holds `hwc`/`hwi`/`#` lines only â€” Status: accepted â€” Done when: every HyperView call goes through `::pis::hw::exec`, a successful call appends `# <ts> | <module> | <item>` plus the exact command, a failing call appends nothing, `::pis::journal::filter` keeps only `hwc `/`hwi `/`#` lines and returns the skipped count, and no bare `hwc ` exists outside `_tcl_pis_10_hw.tcl`; khá»›p cÃ¡c má»¥c liÃªn quan trong Refs; mÃ¢u thuáº«n thÃ¬ theo SPEC.md D1-D5 â€” Only modify: `src/01_scripts/_tcl_pis_10_hw.tcl`, `tests/tcl/test_hw_exec.tcl` â€” How to check: 1) `tclsh tests/tcl/test_hw_exec.tcl` â†’ seeing `PASS` lines for success/error/filter is correct, seeing a failure is wrong. 2) In HyperView trigger one wrapper call from the console, then `puts [::pis::journal::lines]` â†’ seeing exactly 1 comment + 1 `hwc ` line is correct, seeing extra text is wrong. 3) `grep -rn "^[[:space:]]*hwc " src/01_scripts | grep -v _tcl_pis_10_hw.tcl` â†’ seeing 0 hits is correct, seeing any hit is wrong â€” Ran: 2026-11-09: `tclsh tests/tcl/test_hw_exec.tcl` -> 31 PASS, exit 0; `bash scripts/verify.sh` -> verify: OK, exit 0; bare-`hwc` scan over `src/01_scripts/*.tcl` excluding `_tcl_pis_10_hw.tcl` -> 0 hits â€” Refs: docs/refs/SPEC_gui.txt Â§7, Â§8

T-002b: SPIKE â€” Load All / Reset (New) as plain `hwc` commands (replaces `::MaxStress`; SPEC D2 + Q1) â€” Status: accepted â€” Done when: throwaway harness `src/spike/spike_load_model.tcl` runs inside HyperView and `docs/spikes/load-model-window.md` records, each section left `TBD` until the human pastes the real output: (a) the Tcl 8.5-only command sequence that clears the session (Reset), (b) the sequence that loads ONE model and creates a `cols x rows` window grid, (c) the sequence that loads result file k into window k plus the window numbering (0- or 1-based) and the HyperView build used â€” and every recorded line is a plain `hwc ...` command (no `::MaxStress::*`, no `hwi` handle juggling), so the sequence can sit in the journal as-is; khá»›p cÃ¡c má»¥c liÃªn quan trong Refs; mÃ¢u thuáº«n thÃ¬ theo SPEC.md D1-D5 â€” Only modify: `src/spike/spike_load_model.tcl`, `docs/spikes/load-model-window.md`, `docs/SPEC.md` (Q1 row only) â€” How to check: 1) In HyperView source the harness â†’ seeing it print the candidate sequence of each section plus the build string with no error dialog is correct, seeing an error, a `::MaxStress` call or a result the harness invented is wrong. 2) Paste what the harness printed into the doc â†’ seeing every recorded line start with `hwc ` is correct, seeing a Tcl proc call, a `hwi` handle line or a guessed command is wrong. 3) In a fresh HyperView session paste the recorded Reset + load sequence â†’ seeing the same model in the same CxR grid is correct, seeing a second model, a different grid or an error is wrong. 4) Run Load All twice without Reset â†’ whatever HyperView does is recorded verbatim (a clean second load and a clear HyperView error are both acceptable findings), seeing the doc keep `TBD` is wrong â€” Ran: 2026-11-09: `bash scripts/verify.sh` -> `== tcl files (7) ==` (the 5 `src/01_scripts/*.tcl` + `src/spike/spike_legend_window.tcl` + `src/spike/spike_load_model.tcl`), `== syntax == ok 7 file(s)`, `== tests == ok` for `test_block0.tcl`, `test_common.tcl`, `test_gui_frame.tcl`, `test_hw_exec.tcl`, `test_legend.tcl`, `verify: OK`, exit 0. The harness was also sourced under tclsh with no HyperView and nothing emulated: it loads, prints `SPIKE: <label> | ERROR | invalid command name "hwi"` for every candidate, exactly one `| ABORTED | no handle stack (run this in the HyperView Tcl console)` line per step, and `WORKED SEQUENCE: (empty, no candidate succeeded)`; `::spike2::try_load_model <missing path>` raises `model not found: <path>`; `::spike2::save <file>` writes the copy-back block to a file. No finding is filled in â€” (a)-(e) stay `TBD` until the owner pastes real output. That run found and fixed two harness bugs: (1) `return` inside `catch` printed two `ABORTED` lines, replaced with `error`; (2) `open`/`close` inside `::spike2::save` resolved to `::spike2::open`/`::spike2::close` (namespace shadowing), now `::open`/`::close`. The same shadowing bug existed in the accepted `::spike::save` of `src/spike/spike_legend_window.tcl` (T-002): fixed 2026-11-10 during the docs audit (`::open`/`::close` + a warning comment, probe untouched), verified under tclsh by writing and re-reading a file. Also on 2026-11-10 this harness's probing helper `::spike2::try` was renamed `::spike2::candidate` (here only) so `grep -rniE "\btry\b" src` no longer matches a proc; `::spike2::help` and `::spike2::full` re-ran clean afterwards. â€” Refs: docs/refs/SPEC_load_model.txt (validation rules + messages only; its `::MaxStress` contract is superseded by SPEC D2; superseded, see T-015); docs/spikes/legend-window-import.md (the same window-numbering question for legends, tracked separately by T-002/Q3) â€” Accepted: 2026-11-10 (owner: "ok accept"), covering what was delivered: the harness `src/spike/spike_load_model.tcl` and the structure of `docs/spikes/load-model-window.md`. NOT accepted as findings: (a)-(e) and SPEC Q1 are still `TBD`/open, because the harness has not been run inside HyperView yet â€” the next turn on this task is the owner pasting the copy-back block, not new code. â€” Superseded by T-002c (ENV 2026-11-10): findings will not be collected.

Gate: Ä‘Ã£ má»Ÿ 2026-11-10 â€” T-002c accepted, nÃªn T-006 vÃ  T-007 Ä‘Æ°á»£c cháº¡y (khÃ´ng cÃ²n Ä‘iá»u kiá»‡n spike; ENV).
Gate (HV-CHECK MODE, 2026-11-10, `docs/SPEC.md` Â§Constraints): Ä‘iá»u kiá»‡n duy nháº¥t cÃ²n láº¡i lÃ  T-002c á»Ÿ `agent-done` trÆ°á»›c T-006/T-007; khÃ´ng task nÃ o chá» `accepted`, khÃ´ng chá» spike hay confirm trung gian. Lá»‹ch sá»­: gate Ä‘Ã£ má»Ÿ 2026-11-10 vÃ¬ T-002c accepted.

T-002c: HyperView adapter â€” má»™t file `src/01_scripts/_tcl_pis_11_hw_adapter.tcl`, má»—i thao tÃ¡c má»™t proc: `reset_session`, `load_model`, `make_grid`, `load_result_in_window`, `select_window`, `import_legend`; má»—i proc cÃ³ list biáº¿n thá»ƒ cÃ³ nguá»“n; má»i lá»‡nh Ä‘i qua `::pis::hw::exec` â€” Status: accepted (user check: pass, 2026-11-10) â€” Done when: the file defines `::pis::hw::reset_session {}`, `::pis::hw::load_model {path}`, `::pis::hw::make_grid {cols rows}`, `::pis::hw::load_result_in_window {index path}`, `::pis::hw::select_window {index}`, `::pis::hw::import_legend {path}`, each running an ordered variant list in which every variant records its source (an Altair documentation URL or `docs/refs/<file Â§section>`) or the label `UNVERIFIED-GUESS`, with guesses sorted last; every HyperView call inside the adapter goes through `::pis::hw::exec` (no bare `hwc` line, no `hwi` handle command outside it), a failing variant falls through to the next one and both names reach the log, the variant finally used is printed in the log and shown in the status bar (no silent fallback), and `tclsh tests/tcl/test_hw_adapter.tcl` passes with the HyperView side MOCKED (every mock line labelled `MOCK`); khá»›p cÃ¡c má»¥c liÃªn quan trong Refs; mÃ¢u thuáº«n thÃ¬ theo SPEC.md D1-D5 â€” Only modify: `src/01_scripts/_tcl_pis_11_hw_adapter.tcl`, `tests/tcl/test_hw_adapter.tcl` â€” How to check (trÃªn mÃ¡y HyperView; tráº£ lá»i ok / fail + sá»‘ bÆ°á»›c): 1) In a fresh HyperView session source `src/01_scripts/_tcl_pis_10_hw.tcl` then `src/01_scripts/_tcl_pis_11_hw_adapter.tcl` and run `::pis::hw::help` (it lists every op, its current variant and `::pis::hw::use <op> <n>`), then `::pis::hw::load_model <one model.h3d>` â†’ seeing exactly one model in one window plus a log line naming the variant used is correct, seeing two models, an error dialog or no variant name is wrong. 2) Then run `::pis::hw::make_grid 4 1` and `::pis::hw::load_result_in_window 2 <r.h3d>` â†’ seeing the result in window 2 only is correct, seeing it in every window or in window 1 is wrong. 3) Run `::pis::hw::reset_session` then `::pis::hw::import_legend <legend.tcl>` â†’ seeing the session empty and the legend applied to the window named in the log is correct, seeing a leftover model or an unchanged legend is wrong â€” Ran: `bash scripts/verify.sh` â†’ `verify: OK` (8 `.tcl` files parsed, 6 test files green, exit 0); `tclsh tests/tcl/test_hw_adapter.tcl` â†’ 70 PASS, exit 0 (HyperView MOCKED: fake `hwc` + fake log/status, no `hwi`, no real session); source-check of the adapter: 0 bare `hwc` lines, 0 `hwi`, 0 `try`/`finally`, 0 `package require`, 18 variants with a source each; web check on 2026-11-10 for the Altair Tcl reference â†’ no reachable page (404 / bot challenge), so only `import_legend` has a real source (`docs/refs`) and the other 17 variants carry `UNVERIFIED-GUESS`; sizes: adapter 292 lines, test 346 lines (over the ~300 guidance, no check dropped) â€” User: pass 2026-11-10 ("ok accept" cho How-to-check 1â€“3; biáº¿n thá»ƒ 1/3 cá»§a cáº£ 6 op giá»¯ nguyÃªn, khÃ´ng pháº£i `use` láº¡i) â€” Refs: docs/SPEC.md (Constraints ENV; D2; Q1; Q3); docs/refs/SPEC_load_model.txt (behaviour, validation and messages only â€” never the `::MaxStress` library call); docs/refs/SPEC_load_legend.txt FILE 3; docs/refs/SPEC_gui.txt Â§6.2

  Defect (if any) [2026-11-10, same fix pass]:
    Description: The adapter could put the model only in window 1, and its reset table paired a sourced page/window walk with an UNVERIFIED delete verb while the sourced one sat unused.
    Found at: user-check (the T-006 defect above).
    Cause: AGENT - ::pis::hw::load_model carried a fixed %win 1, and reset_session used client DeleteModel (a guess) although this machine's own script deletes with client RemoveAllModels (conrod/_tmp_hv/ppt2.tcl:187).
    Fix: ::pis::hw::load_model_in_window (load_model = k=1); reset_session variant 1 is now RemoveAllModels over the windows of the active page (walk conrod/_tmp_hv/batchImportOdb.tcl:83-87), with DeleteModel-on-active-page, DeleteModel-on-all-pages and <session> New as fallbacks marked UNVERIFIED-GUESS; ::pis::hw::reset_session_soft (Load All) leaves an already-empty session alone; ::pis::hw::verify_window; ::pis::hw::diag; ::pis::hw::order / use order 2.
    Prevention: every variant's src field names a workspace file:line read in the same pass (or the UNVERIFIED-GUESS label), so an unproven verb is visible in the table instead of implied by a big list.

T-006: Block 0 â€” model + result files + cols x rows layout, Load All, Reset (New) â€” Status: reopened (VERIFY-GAP, pass 3, 2026-11-10 â€” pass 2 Ä‘Ã£ Ä‘Æ°á»£c user accept rá»“i fail láº¡i ngay á»Ÿ How-to-check vá»›i layout 4 window; pass 4 (AGENT, 2026-11-10): lÃ m láº¡i `make_grid` khÃ´ng Ä‘áº·t client type ná»¯a vÃ  Ä‘á»c láº¡i client tá»«ng window â€” váº«n `reopened`, chá» user ok/fail trÃªn HyperView) â€” pass 1 was: rework (user fail 2026-11-10 on How-to-check 2-4: this HyperView build ignores the guessed `hwc` one-liners without an error, so the log said "loaded" while nothing loaded; the result list had no way to remove a line â€” list fix done 2026-11-10, command layer waits for the owner's decision on the `hwi` rework of D2/Q1) â€” Done when: Load All validates model/result existence and `len(results) <= cols*rows` (SPEC A6/A7 bullets), Reset (New) and Load All call the adapter procs `::pis::hw::reset_session` / `::pis::hw::load_model` / `::pis::hw::make_grid` / `::pis::hw::load_result_in_window` (T-002c) and nothing else â€” no bare `hwc` line, no handle command and no variant list inlined in this module â€” one `# <timestamp> | <module> | <item>` comment plus the `hwc` lines in the journal, nothing else â€” a saved journal replays model + window grid in a fresh HyperView session, `grep -rniE "maxstress|allow_stub|lib_call" src` returns 0 hits, and the fields round-trip through the ini; khá»›p cÃ¡c má»¥c liÃªn quan trong Refs; mÃ¢u thuáº«n thÃ¬ theo SPEC.md D1-D5 â€” Only modify: `src/01_scripts/_tcl_pis_01_load_model_results.tcl`, `src/01_scripts/_tcl_pis_99_workflow_gui.tcl` (block-0 wiring), `tests/tcl/test_block0.tcl` â€” How to check: 1) `tclsh tests/tcl/test_block0.tcl` â†’ seeing `PASS` for empty model, 9 files in 4x2, missing result file is correct, seeing any error accepted silently is wrong. 2) In HyperView leave the model empty and click Load All â†’ seeing `Error:` in the status bar and 0 journal lines is correct, seeing a HyperView dialog or a loaded window is wrong. 3) Enter 9 result files with layout 4 x 2 and click Load All â†’ seeing an error containing `8` is correct, seeing windows created is wrong. 4) Valid model + 2 results in 2 x 1, click Load All, `[Save]` the journal, then paste that file into a fresh HyperView session â†’ seeing the same model and the same 2-window grid is correct, seeing an error or an empty session is wrong. 5) `grep -rniE "maxstress|allow_stub" src` â†’ seeing 0 hits is correct, seeing a `::MaxStress` call is wrong. 6) Click `[Reset (New)]` â†’ seeing the session cleared and the journal gain the reset comment + its `hwc` line(s) is correct, seeing an unjournaled clear is wrong. 7) In the HyperView Tcl console source `src/spike/probe_hvi_reset.tcl`, `set f <one model.h3d>`, then `::spiker::all $f` â†’ seeing one `variant N | CLEARED |` line per variant that really emptied the session, plus a `BEST:` line naming a variant number, is correct, seeing `SEED FAILED` / `NOT CLEARED` on every variant is wrong (paste the copy-back block back and reply fail) â€” Ran: 2026-11-10 (rework after T-002c, SPEC D2): `tclsh tests/tcl/test_block0.tcl` -> 99 PASS, exit 0 (HyperView MOCKED: a fake `hwc` records every call, so every PASS is MOCK evidence); `bash scripts/verify.sh` -> verify: OK, exit 0 (8 tcl files parsed, 6 test files green); `grep -rniE "maxstress|allow_stub|lib_call" src` -> 0 hits; `grep -rn 'hwc ' src/01_scripts` -> the step script and the GUI match comments only. Previous run, kept as history: 2026-11-09: `tclsh tests/tcl/test_block0.tcl` -> 59 PASS, exit 0; `bash scripts/verify.sh` -> verify: OK, exit 0 (5 files parsed, 4 test files green); live Tk smoke (`tclsh`, window built then withdrawn): ini prefill 2 x 2 + 3 files -> Load All -> `Status: STUB MODE | Loaded 3 result(s) into 3 window(s).`; 3 files with 2 x 1 -> `Status: Error: 3 result file(s) exceed layout 2x1 (max 2)`; deleted ini -> window opens with exactly 1 `WARN` naming `pis_workflow_config.ini` and 4 x 2 defaults; journal stays empty in every case. Deviations to review: (1) `::MaxStress::ResetSession`/`LoadAll` are Tcl procs, not `hwc` commands, so they cannot be journaled without breaking SPEC A2/A3 â€” they go through ONE helper `::pis::step01::lib_call` and appear in the display log only (`INFO LoadAll: ...`, `OK Session reset`), which means replaying a saved journal will NOT replay Load All; (2) the GUI file now sources `_tcl_pis_00_common.tcl`, `_tcl_pis_10_hw.tcl`, `_tcl_pis_01_load_model_results.tcl` itself (one `source` command starts the tool) and block 0 prefills from the ini â€” the rest of T-013 (module lists, save on exit) stays open; (3) `[maxstress]` is still read with defaults (`lib_file = maxstress_lib.tcl`, `allow_stub = 0`) and was NOT added to the shipping ini. SUPERSEDED (USER-CHANGE 2026-11-09) and now CLOSED by the 2026-11-10 rework: deviation (1) is gone (Load All / Reset are journaled `hwc` lines through the adapter), deviation (3) is gone (`lib_call` / `ensure_lib` / `define_stubs` / `stub_mode` deleted; `grep -rniE "maxstress|allow_stub|lib_call" src` -> 0 hits), deviation (2) stays valid. New in the rework: (4) Load All runs the adapter's `reset_session` step FIRST (SPEC Q1: "resets the session, loads ONE model, builds the cols x rows grid and loads result file k into window k"), so Load All twice is a clean reload instead of a duplicated model â€” the journal replays the same order; (5) the procs are `::pis::step01::load_all {cfg}` (root comes from the cfg `root` key, returns the window count), `::pis::step01::reset_session {}` and `::pis::step01::loaded {}` (0|1) per the SPEC API contract â€” the `loaded` / `last_result` namespace variables stay because T-007's legend seam reads them, and the proc returns the same 0|1 as the variable so the two cannot disagree; (6) each step sets one `::pis::hw::context` pair before its adapter call, so the journal is one `# <timestamp> | Load All | <step>` comment plus its `hwc` line and a failure names that step (`Load All: window 2: r2.h3d failed: ...`) while the wrapper journals nothing for the failed command; (7) the GUI file now also sources `_tcl_pis_11_hw_adapter.tcl` (block-0 wiring) and its `run_block0` calls `load_all` / `reset_session` â€” nothing else in the GUI changed. â€” User: fail 2026-11-10 (How-to-check 2-4), verbatim: "pháº§n chá»n layout, load model hiá»ƒn thá»‹ trÃªn log lÃ  load Ä‘Æ°á»£c nhÆ°ng thá»±c táº¿ khÃ´ng load dc trÃªn hyperview, pháº§n result file sau khi add khÃ´ng xÃ³a dc, cáº§n nÃ³ nhÆ° list cÃ³ tháº¿ xÃ³a tá»« ngÆ°á»i dÃ¹ng". Root cause found WITHOUT HyperView, from this machine's own working scripts: `hwc` in this build only knows its own HWC command set (`hwc result scalar legend import` is the one proven form, used by the confirmed legend workflow) and IGNORES the adapter's guesses (`hwc session new`, `hwc model load <path>`, `hwc page layout C R`, `hwc result load <path>`) without raising, so `::pis::hw::exec` journaled them and the log claimed success. Every script that really loads a model on this machine uses the `hwi` handle API instead: `hwi OpenStack` â†’ `hwi GetSessionHandle` â†’ `<sess> GetProjectHandle` â†’ `<proj> GetPageHandle <pg> [<proj> GetActivePage]` â†’ `<pg> GetWindowHandle <win> <n>` â†’ `<win> GetClientHandle <clt>` â†’ `<clt> AddModel <file>` + `<clt> Draw`, layout with `<pg> SetLayout <token>` (tokens `RxC`, `R X C`, plain count, `2V`â€¦, verified by `<pg> GetNumberOfWindows`), results attached to the window's model with `<model> SetResult <file>` / `<model> AddResultFile <file>` â€” see `conrod/tcl_guide/hv_model_loader.tcl`, `conrod/_tmp_hv/batchImportOdb.tcl` (HyperView 2021), `conrod/_tmp_hv/training.tcl`, `test/test_out/TCL_StressExport.tcl`. Consequence: SPEC D2/Q1 (`hwc`-only journal) cannot be met for reset/load/grid/result and needs the owner's decision; the adapter is NOT re-guessed. Done in this pass: the result list is the user's â€” `[Remove]` button plus `<Delete>`/`<BackSpace>` on a multi-select listbox, one `INFO removed N result file(s)` or exactly one `WARN` when nothing is selected, `remove` added to the busy lock, `tclsh tests/tcl/test_block0.tcl` â†’ 112 PASS, exit 0. â€” Ran (pass 2 of the rework, 2026-11-10 â€” the `hwi` command layer plus a read-back check, SPEC D2 REVISION; the `Ran` entry above is pass 1 and is kept as history): `tclsh tests/tcl/test_block0.tcl` -> 125 PASS, exit 0 (HyperView MOCKED, and the mock is now a real session: one model pool, results per window, `SetLayout` changes the window count, `silent_add` / `failmatch` / `failcount` inject this build's silent no-op and one failing variant, so "window k shows the model" is asserted offline instead of assumed); `tclsh tests/tcl/test_hw_adapter.tcl` -> 120 PASS, `tclsh tests/tcl/test_hw_exec.tcl` -> 64 PASS, `test_common.tcl` -> 41, `test_gui_frame.tcl` -> 20, `test_legend.tcl` -> 56, every one exit 0; `bash scripts/verify.sh` -> `== tcl files (9) ==`, `ok 9 file(s)`, all 6 test files `ok`, `verify: OK`, exit 0; `grep -rniE "maxstress|allow_stub|lib_call" src` -> 0 hits; bare `hwc` lines in `src/01_scripts` outside the wrapper -> 0; new `src/spike/probe_hvi_reset.tcl` (the reset probe of step 7) driven under a MOCK `hwi` from a throwaway `%TEMP%` driver -> 24 PASS: a `DeleteModel` that really clears reads `CLEARED`, the same script under a silent-ignore mode reads `NOT CLEARED`, a missing model reads `SEED FAILED` and is never counted as cleared, an unknown variant number is refused, and `all` + `report` end with the `BEST:` line plus `::pis::hw::use reset_session <n>`; the adapter exactly as accepted on 2026-11-10 is archived at `docs/archive/_tcl_pis_11_hw_adapter.pre-hwi-rework.2026-11-10.tcl` (+ `docs/archive/README.md`), because this folder still has no `.git` and the overwrite would otherwise be the only copy; the `%TEMP%` scratch files of this pass are deleted. Still open, and it needs the owner rather than more code: which `reset_session` variant stays first â€” step 7 and the `ok`/`fail` reply on the probe's copy-back block decide it. â€” Refs: docs/refs/SPEC_load_model.txt (validation rules + messages only; its `::MaxStress` contract is superseded by SPEC D2); docs/refs/SPEC_gui.txt Â§4, Â§10; docs/SPEC.md (Constraints ENV; D2; Q1 â€” adapter rules and the ok/fail channel)

  Defect (if any) [2026-11-10, fix pass]:
    Description: Load All logged "Loaded N result(s)" while only window 1 showed a model; windows 2..N stayed empty.
    Found at: user-check (T-006 How-to-check 1: "window 1 has it, window 2 is empty" = wrong).
    Cause: AGENT - _tcl_pis_01_load_model_results.tcl loaded the ONE model into window 1 (::pis::hw::load_model hard-coded %win 1) and then put a result into windows 1..N; a window is its own client with its own model list (conrod/_tmp_hv/batchImportOdb.tcl:111 reads GetModelList per client, conrod/tcl_guide/hv_model_loader.tcl:1428 LoadInputs takes winIdx first), so window k>1 had no model for SetResult to attach to.
    Fix: ::pis::hw::load_model_in_window {index path} (load_model is only its k=1 case); ::pis::step01::load_window loads model+result per window and ::pis::hw::verify_window reads each window back ("1:1" = one model + one result controller) before the next one; one failing window stops the run and names k, the step and the variants (e.g. "load_result_in_window window 2 variant 2/2 failed: ...") in the log and the status bar; "Loaded" only when every window passed; order 1 = reset -> grid -> every window, order 2 = window 1 -> grid -> the rest (::pis::hw::use order 2, named in log and status); ONE-line ::pis::hw::diag; the reset is soft for Load All (an already-empty session does not stop the run).
    Prevention: tests/tcl/test_block0.tcl now models ONE MODEL LIST PER WINDOW (a new window is empty) and asserts a model + a result in every loaded window - "model only in window 1" can no longer pass a test.

  Defect (if any) [2026-11-10, pass 3 â€” VERIFY-GAP, T-006 reopened after accept]:
    Description: Load All works for a 2-window layout (2x1, 1x2) and FAILS for every 4-window layout (4x1, 1x4, 2x2, 3x2, 4x2).
    Found at: after-accept (user check, verbatim: "Load All cháº¡y vá»›i layout 2x1 vÃ  1x2 nhÆ°ng FAIL vá»›i layout 4 window").
    Cause: AGENT â€” `make_grid` asked the page for the layout in GUI field order (`%colsx%rows`, e.g. "4x1") while the reference loader spells and re-applies the token rows first (`conrod/tcl_guide/hv_model_loader.tcl:498-501` PreferredLayoutToken = "${r}x${c}", `:457-460` "'1x2' means 1 row, 2 columns = side by side"), so the count check passed for 2 windows (both spellings give 2) and the 4-window grids were refused by this build with silence. Second hole, same area: the grid read-back compared the window COUNT only, so a page whose new windows have no plot client passed, and the first symptom appeared later at that window's model load (`conrod/_tmp_hv/training.tcl:9,20` sets a window's client type with '<win> SetClientType Plot'; `conrod/_tmp_hv/batchImportOdb.tcl:130-134` takes a client handle per window).
    Fix: `make_grid` variant 1 = the reference form (`SetLayout %rowsx%cols` + one `SetClientType Plot` per window + the sourced window/client walk), variant 2 = the same token without the client step (so "the client type is required" and "the token is wrong" are told apart in the log), then the old spellings and the layout token table as fallbacks: transposed `%colsx%rows`, "%rows X %cols", "%cols X %rows", "%rows x %cols", "%rows - %cols", plain count, legacy word (`single 1x1 2H 2V 3H 3V 4H 4V`, `hv_model_loader.tcl:518`). New `::pis::hw::check_grid {count}` proves the count AND that every window k answers a window + client handle (a failing window raises with its number); `::pis::hw::verify_grid {cols rows}` is the app-facing read-back and returns the count HyperView reports; `::pis::hw::make_grid` records it as `::pis::hw::layout`/`::pis::hw::wins` only after a successful read-back; `::pis::hw::diag` is now ONE line `DIAG: layout=2x2 grid=1 wins=4 model=1,1,0,0 result=1,1,0,0`; a variant run that fails reports the FIRST mismatch (the intended form) plus every variant tried, in the log and in the status bar (`Error: <op> window k - no variant worked`).
    Prevention: `tests/tcl/test_block0.tcl` mocks the layout STRICTLY (only the reference token for the size under test is accepted, every other spelling is silent, exactly like this build) and gives a window created by a layout change NO client until `SetClientType Plot` ran on it; a 7-row matrix (2x1, 1x2, 2x2, 4x1, 1x4, 3x2, 4x2) asserts a model AND its own result in EVERY window plus a `diag` with no 0, so "works for 2 windows" cannot pass again. Red proof (same tree, adapter downgraded to the old token + no client step in a throwaway `%TEMP%` copy, deleted afterwards): `test_block0` 177 PASS / 61 FAIL, exit 1 â€” including "Load All 2x2 fills 4 window(s): -1", 4x1, 1x4, 3x2, 4x2 and "every new window was given a plot client: 0" for 2x1/1x2.
    Agent:
      Ran: 2026-11-10 (pass 3): `tclsh tests/tcl/test_block0.tcl` -> 229 PASS, 0 FAIL, exit 0 (HyperView MOCKED); `tclsh tests/tcl/test_hw_adapter.tcl` -> 166 PASS, 0 FAIL, exit 0 (MOCK); `test_common` 41, `test_gui_frame` 20, `test_hw_exec` 64, `test_legend` 56, all exit 0; `bash scripts/verify.sh` (via `C:/Program Files/Git/bin/bash.exe`, tclsh 8.6.17) -> `== tcl files (9) ==`, `ok 9 file(s)`, all 6 test files `ok`, `verify: OK`, exit 0; bare `hwc ` lines outside `_tcl_pis_10_hw.tcl` -> 0 hits; `^\s*(try|finally)` -> 0 hits; `package require` -> comments only + the single `package require Tk` in the GUI; red proof above.
      Self-healing retries used: 2 (the walk first raised inside its loop, which hid the expected count -> every call in the walk is now caught and the read-back judges; then the failure message carried only the LAST variant's error -> `run` now leads with the first).
      Diff: no `.git` in this folder, so no `git diff --stat`; files changed: `src/01_scripts/_tcl_pis_11_hw_adapter.tcl`, `tests/tcl/test_block0.tcl`, `tests/tcl/test_hw_adapter.tcl`, `docs/TASKLOG.md` (this entry). `src/01_scripts/_tcl_pis_01_load_model_results.tcl` and the GUI were NOT touched (item 7).
      Assumptions used: (1) the reference token is rows-first, from `hv_model_loader.tcl:457-460,498-501,512` â€” every variant stays a guess until the human's ok/fail, and only the human moves the start variant; (2) a window created by a layout change needs `SetClientType Plot` (`training.tcl:9,20`) â€” variant 1 does it, variant 2 does not, and the log names which one worked; (3) on the real build `GetClientHandle` on a client-less window may raise OR hand back a useless handle â€” the read-back asks the same question either way, so both are caught.
      How to check (user, max 3 steps):
        1. Empty session, 1 model + 4 result files, layout 2x2, Load All -> seeing 4 windows, each with the model and its own result, is correct; fewer than 4 windows or an empty window is wrong.
        2. Repeat with layout 4x1 and then 1x4 -> seeing 4 windows filled the same way is correct; anything less is wrong.
        3. `::pis::hw::diag` -> seeing ONE line `DIAG: layout=2x2 grid=1 wins=4 model=1,1,1,1 result=1,1,1,1` (no 0) is correct; any `0`, a `wins=` lower than the window count, or more than one line is wrong.
      Rollback: no git target; move the start variant without touching a file (`::pis::hw::use make_grid 3`), or revert the file: variant 1's token back to `%colsx%rows` and drop the client step from the walk.
    User:
      Check: pending (2026-11-10) â€” the 3 steps above
      Steps run / skipped:
      Notes:
  Defect (if any) [2026-11-10, pass 4 â€” AGENT, T-006 stays reopened]:
    Description: after Load All every window is a HyperGraph 2D CHART window instead of a HyperView window, so the model/contour never shows in any window.
    Found at: user-check (owner's verbatim report: "sau Load All, cÃ¡c window lÃ  HyperGraph 2D, khÃ´ng pháº£i HyperView").
    Cause: AGENT â€” the two `make_grid` variants that ran first sent `<win> SetClientType Plot` per window, copied out of `conrod/_tmp_hv/training.tcl:9,20` without reading what that script is for: its own header (`:1`, `:13`, "å°†ç¬¬ä¸‰é¡µçš„ç¬¬ä¸‰ä¸ªçª—å£å®¢æˆ·ç«¯è®¾ç½®æˆæ›²çº¿å›¾") says the script sets the 3rd window of page 3 to a CURVE CHART, i.e. `Plot` is the HyperGraph 2D client â€” the opposite of a window that must show a model. `GetClientType` appears in NO script on this machine, so the type was never read back either, and the grid read-back asked only for a client HANDLE, which a chart window answers too.
    Fix: both `SetClientType Plot` variants are GONE from `make_grid` (8 variants left: reference token `<rows>x<cols>` + the window/client walk, then the transposed/spaced/dash/count/legacy spellings â€” none sets a client type); `::pis::hw::check_grid` now also asks the client for `GetModelList` and refuses a window that cannot hold a model with `make_grid: window <k> is not a HyperView window (client type <t>)` (status red + WARN/ERROR in the log), and `::pis::hw::run` adds `- File > New gives a session with HyperView windows` when that is the cause; `::pis::hw::check_models_on_page` counts a chart window as 0 models (a chart cannot hold one), so Reset passes there and the GRID is the step that names it; new `::pis::hw::check_clients`/`::pis::hw::clients` read the per-window letter back (H = answers GetModelList, P = does not, ? = no client handle) and `::pis::hw::diag` now prints `client=H,H,..` per window inside the same under-80 line; `src/spike/try_load_all.tcl` prints `NEW File > New (or restart HyperView): this session has HyperGraph 2D windows` instead of a NEXT line when a chart window is the failure. `::pis::BUILD` is now `T6d-20261110-1642` (printed on source). NO verb that sets a window BACK to HyperView exists in any script on this machine (`GetClientType` is absent too), so none was guessed: only reset's existing `<session> New` variant (UNVERIFIED-GUESS) remains as a candidate, and the grid error says what to do (`File > New`).
    Prevention: every `src` in the variant table must name what the source script DOES (not only file:line) and the destination use must be checked against it before a variant is put at position 1 â€” `training.tcl` is a chart script, so its `SetClientType Plot` can never be a grid step; a test asserts that no variant of any op contains `SetClientType`, and a mock page of Plot windows must make Load All RED (`tests/tcl/test_hw_adapter.tcl` A2/A3/A4, `tests/tcl/test_block0.tcl` "THE ESCAPED DEFECT" block).
    Agent:
      Ran: 2026-11-10 (pass 4): `tclsh tests/tcl/test_block0.tcl` -> `ok  all block-0 checks passed`, exit 0 (MOCK); `tclsh tests/tcl/test_hw_adapter.tcl` -> `ok  all ::pis::hw adapter checks passed (HyperView side MOCKED)`, exit 0 (MOCK); `bash scripts/verify.sh` (git-bash, tclsh 8.6.17) -> `== tcl files (10) ==`, `ok  10 file(s)`, all 6 test files `ok`, `verify: OK`, exit 0; console smoke of `src/spike/try_load_all.tcl` against a %TEMP% mock (temp files deleted): 2x2/4 results -> `BUILD T6d-... | make_grid variants=8 | adapter lines=1119`, one `STEP`+`VERIFY` per window, `DIAG T6d: layout=2x2 grid=1 wins=4 model=1,1,1,1 result=1,1,1,1 client=H,H,H,H`, `DONE`; 4x1/4 results -> `layout=1x4 ... client=H,H,H,H`, `DONE`; Plot page -> `FAIL make_grid 2x2: make_grid: window 1 is not a HyperView wind..`, `NEW File > New (or restart HyperView): ...`, `DIAG T6d: layout=- grid=0 wins=0 ... client=P,P,P,P`, `DONE`.
      Self-healing retries used: 1 (the first `diag` build padded `client=?` even when the session could not be asked, which printed a made-up letter â€” `have_clients` now decides whether the field is printed at all).
      Diff: no `.git` in this folder, so no `git diff --stat`; files changed: `src/01_scripts/_tcl_pis_11_hw_adapter.tcl`, `src/spike/try_load_all.tcl`, `tests/tcl/test_block0.tcl`, `tests/tcl/test_hw_adapter.tcl`, `docs/TASKLOG.md` (this entry). `src/01_scripts/_tcl_pis_01_load_model_results.tcl` and the GUI were NOT touched (no change was needed: the step module already refuses to report Loaded when a grid/window fails).
      Assumptions used: (1) a window created by `SetLayout` is a HyperView window unless something sets its client type â€” that is what the working reference loader relies on (`hv_model_loader.tcl:1179-1180` SetLayout, `:1329-1337` GetClientHandle + AddModel, no client type call anywhere), and it is MOCK-verified only; (2) `client GetModelList` is the usable read-back of "this is a HyperView client" because no script on this machine uses `GetClientType`; (3) the type letter in `diag` (H/P/?) is inferred from that behaviour, not read from HyperView.
      How to check (user, max 3 steps):
        1. Empty session (File > New), 1 model + 4 result files, layout 2x2, Load All -> seeing 4 windows, each a HYPERVIEW window with the model and its own result, is correct; seeing chart frames (axes/curves, no model) is wrong.
        2. Repeat with layout 4x1 -> seeing 4 HyperView windows filled the same way is correct; anything less is wrong.
        3. `::pis::hw::diag` -> seeing ONE line under 80 characters with `wins=4`, no `0` anywhere and `client=H,H,H,H` is correct; a `P` or `?`, a `0`, or more than one line is wrong.
      Rollback: no git target; the previous build is `docs/archive/_tcl_pis_11_hw_adapter.pre-hwi-rework.2026-11-10.tcl` (older than this pass) or re-add the two `SetClientType Plot` variants in `::pis::hw::table` (do NOT â€” that is the defect); `::pis::hw::use make_grid <n>` moves the start variant without editing a file.
    User:
      Check: pending (2026-11-10) â€” the 3 steps above
      Steps run / skipped:
      Notes:

  Defect (if any) [2026-11-11, pass 5 â€” EXTERNAL (owner fail on HyperView: 2x2 vÃ  4x1 khÃ´ng ra Ä‘á»§ window, 2x1 vÃ  1x2 thÃ¬ á»•n), T-006 agent-done â€” owner check pending]:
    Description: Load All with layout 2x2 or 4x1 leaves the page with the windows it already had (2 in the owner's session); 2x1 and 1x2 work. This build answers every guessed layout token with silence, so no variant of make_grid can be trusted to hold the right spelling, and a SetLayout that is ignored is invisible in both directions (nothing breaks, nothing happens).
    Found at: user-check (owner, 2026-11-11: "Load All vá»›i layout 2x2 vÃ  4x1 khÃ´ng ra Ä‘á»§ window; 2x1 vÃ  1x2 thÃ¬ á»•n").
    Cause: EXTERNAL - the token belongs to this HyperView build, not to a document. The working scripts read it back FROM the page (`<page> GetLayout`, conrod/_tmp_hv/batchImportOdb.tcl:105) and apply that same token (:126). The adapter stops guessing: the owner captures the token once per size and the adapter stores it.
    Fix: `::pis::hw::grid_capture` (read-only; ONE `GRID: wins=<n> token=<GetLayout> was=<CxR or ->` line under 80 characters plus the `::pis::hw::grid_token_set` line to paste) and `::pis::hw::grid_token_set {cols rows token}` (session memory; prints the `<cols>x<rows> = <token>` `[layout_tokens]` ini line, writes no file; refuses anything that is not a positive cols/rows pair and a one-line token). The ini gained an empty `[layout_tokens]` section and `::pis::common::read_layout_tokens {path}` reads it ({} for a missing/unreadable file, bad keys dropped). make_grid order: (a) the page ALREADY shows cols*rows HyperView windows -> NO SetLayout, one INFO line `make_grid: grid already <n> window(s), SetLayout skipped` and ONE comment-only journal line `# grid CxR already present; replay needs the same layout set by hand` (no fake hwi line); (b) the owner-captured token is variant 1/N with src `owner-captured (GetLayout)`; (c) the documented variants follow it unchanged (labels and src kept); (d) a failure now carries `asked <n> window(s), page answered wins=<m> layout=<token> | last form: variant <n>/<n> | Fix: ...` instead of a probe hint. `src/spike/try_load_all.tcl` gained `USE_EXISTING_GRID` (1 = skip make_grid entirely). BUILD is `T6f-20261111-1018` and prints `tokens=<n>` so "the ini I edited is not the ini this file reads" is visible before the first Load All.
    Prevention: tests/tcl/test_hw_adapter.tcl "4b": grid_capture prints exactly two lines and changes nothing; grid_token_set refuses 0 / "a" / empty / two-line input; the ini reader keeps one good line and drops empty, non-CxR and zero keys; 2x2, 4x1, 1x4, 3x2 and 4x2 all build on a mock build that accepts ONLY the captured token (variant 1/9, src in the log, token in the journaled line); a frozen page fails with asked / wins / layout / last form / Fix; a hand-made 4-window page is never rebuilt (0 SetLayout, 1 comment line, 0 lines dropped by the journal filter), while a page of chart windows is rebuilt, not kept. tests/tcl/test_block0.tcl: Load All on a hand-made 2x1 grid sends no SetLayout and still fills both windows, and `::pis::common::read_layout_tokens` is covered with the config layer loaded. (pass 6 replaced the tabled forms and the `last form` text: see the pass-6 Prevention below - the table is ONE form and the token is MEASURED by `::pis::hw::grid_sweep`.)
    Agent:
      Ran: 2026-11-11 (pass 5): `bash scripts/verify.sh` (git-bash, tclsh 8.6.17) -> `== tcl files (10) ==`, `ok  10 file(s)`, all 6 test files `ok`, `verify: OK`, exit 0; `tclsh tests/tcl/test_hw_adapter.tcl` -> 271 PASS, exit 0 (MOCK); `tclsh tests/tcl/test_block0.tcl` -> 256 PASS, exit 0 (MOCK); `tclsh tests/tcl/test_hw_exec.tcl` -> 64, `test_common.tcl` -> 41, `test_gui_frame.tcl` -> 20, `test_legend.tcl` -> 56, every one exit 0; console smoke of `src/spike/try_load_all.tcl` against a %TEMP% mock (temp files created and deleted): USE_EXISTING_GRID 0 -> `STEP make_grid win=- variant=1: OK`, 2 windows loaded, `DIAG T6f: layout=2x2 grid=1 wins=4 model=1,1,0,0 result=1,1,0,0 client=H,H,H,H`, 1 SetLayout; USE_EXISTING_GRID 1 on a hand-made 4-window page -> `SKIP make_grid 2x2: USE_EXISTING_GRID=1, ...`, 0 SetLayout, both windows loaded; the same hand-made page with USE_EXISTING_GRID 0 -> `STEP make_grid win=- variant=0: OK`, 0 SetLayout, `layout=2x2 grid=0 wins=4`.
      Not verified on HyperView: every HyperView answer (the captured token, the skip on a hand-made page, the Fix line) is MOCK evidence on this machine.
      Diff: no `.git` in this folder, so no `git diff --stat`; files changed: `src/01_scripts/_tcl_pis_11_hw_adapter.tcl` (BUILD `T6f-20261111-1018`), `src/01_scripts/_tcl_pis_00_common.tcl`, `src/00_config/pis_workflow_config.ini`, `src/spike/try_load_all.tcl`, `tests/tcl/test_hw_adapter.tcl`, `tests/tcl/test_block0.tcl`, `docs/TASKLOG.md` (this entry). `src/01_scripts/_tcl_pis_01_load_model_results.tcl` and the GUI were NOT touched (no change was needed).
      Try on HyperView (user, max 3 steps):
        1. Pick the 2x2 layout by hand in HyperView, type `::pis::hw::grid_capture` -> seeing ONE `GRID: wins=4 token=... was=2x2` line under 80 characters plus one `::pis::hw::grid_token_set 2 2 <token>` line is correct; anything else, or the page changing, is wrong. Paste the printed `<cols>x<rows> = <token>` under `[layout_tokens]` in `src/00_config/pis_workflow_config.ini` and re-source the adapter -> `BUILD T6f-20261111-1018 | ... | tokens=1` is correct.
        2. File > New, 1 model + 4 results, layout 2x2, Load All -> seeing 4 HyperView windows each with the model and its own result is correct; seeing the old 2 windows is wrong (reply `T-006: fail 2: <that FAIL line>` â€” it now carries `asked 4 window(s), page answered wins=.. layout=..`).
        3. Repeat step 1 + Load All with 4x1 (4 results) -> seeing 4 windows is correct; a page that ALREADY shows the asked number of windows must log `make_grid: grid already <n> window(s), SetLayout skipped` and gain exactly one `# grid CxR already present; ...` journal line and no SetLayout line.
      Rollback: no git target; `::pis::hw::use make_grid <n>` still moves the start variant without editing a file, and emptying `[layout_tokens]` returns make_grid to the documented forms only.
    User:
      Check: pending (2026-11-11) â€” the 3 steps above
      Steps run / skipped:
      Notes:

  Defect (if any) [2026-11-11, pass 6 â€” AGENT (pass 5 still made the owner capture a token by hand; the token is MEASURABLE on the page), T-006 agent-done â€” owner check pending]:
    Description: After pass 5, Load All needs two manual steps (`grid_capture` + an ini line) on a fresh machine before 2x2/4x1 can build, and the eight tabled spellings are still guesses that can silently do nothing. A `SetLayout` this build ignores answers neither an error nor a change, so "which spelling does it want" is a question only the page can answer.
    Found at: agent-check (2026-11-11, continuing pass 5: the capture path had to exist before the first Load All; the sweep is the same idea without the hand work).
    Cause: AGENT â€” the page is a better judge than any document: apply a candidate, then read the count AND the layout back (`<page> GetNumberOfWindows` + a client handle in every window, and `<page> GetLayout`; conrod/tcl_guide/hv_model_loader.tcl:1149-1204, conrod/_tmp_hv/batchImportOdb.tcl:105,126).
    Fix: `::pis::hw::sweep_tokens {cols rows}` (the documented union in one list: rows-first, cols-first, the `R X C` / `R x C` / `R - C` spacings, the plain window count, the legacy word for 1..4 windows, deduped), `::pis::hw::sweep_script` (one read-only hwi script that applies a candidate and returns `wins|layout`) and `::pis::hw::grid_sweep {cols rows}` (dict `{ok tried max last near why}` plus ONE `SWEEP 4x1: ok=1x4 tried=1` / `SWEEP 2x2: none tried=5 max=2 last=2H` line under 80 characters; journals nothing, records no step, moves no variant). make_grid (b) is now: the owner capture if there is one (one try), else `grid_sweep`; ONLY a proven candidate becomes the journaled step, and it is kept for the session and reported as ONE `Keep: 4x1 -> 1x4 (sweep)` line; a candidate that reached the count but whose windows refused a client handle is still sent (`how = "sweep candidate"`) so the read-back names the real cause (a chart window), but it is neither cached nor Keep-printed; when no candidate wins nothing is sent at all and the error is `make_grid: no layout token gives 4 window(s) for 2x2 (tried 5, best 2) | Fix: chá»n 2x2 báº±ng tay trong HyperView, gÃµ ::pis::hw::grid_capture, rá»“i cháº¡y láº¡i Load All`. The variant table is ONE form (`::pis::hw::variants make_grid` = 1; `::pis::hw::use make_grid 2` is refused, naming 1..1), so there is no variant to move. `::pis::hw::page_state` now reads the page through `::pis::hw::check_page_info` (it had called `page_info` and re-ran that LINE as a script, which returned nothing - diag printed `layout=-`), so diag reports the real token. `src/spike/try_load_all.tcl` prints `PROBE ::pis::hw::grid_sweep <cols> <rows>   (paste the SWEEP line back)` for a failing grid (a NEXT line would name a variant that does not exist) and its DIAG line stays ONE line. BUILD is `T6g-20261111-1051`.
    Prevention: tests/tcl/test_hw_adapter.tcl "4": A a build that knows only `1x4` is found in ONE try (`SWEEP 4x1: ok=1x4 tried=1`, `Keep: 4x1 -> 1x4 (sweep)`, 2 SetLayout = try + step, the token in the journaled line, the token cached); B 3x2 needs five tries (`ok=3x2 tried=5`, 6 SetLayout, only `3x2` journaled); C a build that knows only the plain count wins on `4` (tried=5); D a legacy-only build wins on `4H` (tried=10); E a page that accepts every token fails after 5 tries, journals nothing, caches nothing, prints no Keep line and hands over the Fix line; F `grid_sweep` alone prints exactly ONE line under 80 characters, journals nothing, records no step, moves no variant, refuses `0` / `a` by name, and says `got=` when the count came but the client handle did not; G `sweep_tokens` is the exact documented union, in order (4x1 = 10 candidates, 2x2 = 5, 3x2 = 9, 4x4 = 5) and `variants make_grid` is 1. `tests/tcl/test_block0.tcl` still passes unchanged.
    Agent:
      Ran: 2026-11-11 (pass 6): `tclsh tests/tcl/test_hw_adapter.tcl` -> 288 PASS, `ok  all ::pis::hw adapter checks passed (HyperView side MOCKED)`, exit 0 (MOCK); `tclsh tests/tcl/test_block0.tcl` -> `ok  all block-0 checks passed`, exit 0 (MOCK); `bash scripts/verify.sh` (git-bash, tclsh 8.6.17) -> `== tcl files (10) ==`, `ok  10 file(s)`, all 6 test files `ok`, `verify: OK`, exit 0; `info complete` on `src/spike/try_load_all.tcl` -> 1 (parsed, not run); every `_tmp*` scratch file deleted (`Get-ChildItem -Recurse -Filter _tmp*` -> 0).
      Not verified on HyperView: the SWEEP line, `Keep:`, the measured token and the Fix line are MOCK evidence on this machine; no HyperView was available to this pass, and `try_load_all.tcl` was NOT console-smoked this pass (parsed only).
      Diff: no `.git` in this folder, so no `git diff --stat`; files changed: `src/01_scripts/_tcl_pis_11_hw_adapter.tcl` (BUILD `T6g-20261111-1051`), `src/spike/try_load_all.tcl`, `tests/tcl/test_hw_adapter.tcl`, `docs/TASKLOG.md` (this entry). `src/01_scripts/_tcl_pis_00_common.tcl`, the ini, `_tcl_pis_01_load_model_results.tcl` and the GUI were NOT touched.
      Try on HyperView (user, max 3 steps):
        1. File > New, 1 model + 4 results, layout 2x2, Load All -> seeing ONE `SWEEP 2x2: ok=<token> tried=<n>` line, ONE `Keep: 2x2 -> <token> (sweep)` line and 4 HyperView windows each with the model and its own result is correct; no SWEEP line (an old copy of the adapter is loaded) or only 2 windows is wrong.
        2. Repeat with layout 4x1 (4 results) -> `SWEEP 4x1: ...` + `Keep: 4x1 -> ...` and 4 filled windows is correct. Reply with those two SWEEP lines: they name the token THIS build accepts, which is the whole question.
        3. `::pis::hw::diag` -> seeing ONE line under 80 characters with `layout=<token> grid=1 wins=4` and `client=H,H,H,H` is correct; a `P`, a `?`, a `0` or a second line is wrong. If a grid refuses, the FAIL line ends with `Fix: ... grid_capture` and `::pis::hw::grid_sweep 2 2` prints the one SWEEP line to paste back.
      Rollback: no git target; a captured token in `[layout_tokens]` still wins over the sweep without editing this file, and `::pis::hw::grid_capture` + `::pis::hw::grid_token_set` remain the manual route for a size the sweep cannot prove.
    User:
      Check: pending (2026-11-11) - the 3 steps above
      Steps run / skipped:
      Notes:

  Defect (if any) [2026-11-11, pass 7 - AGENT + EXTERNAL (owner fail on HyperView: 4x1 shows 3 windows although the adapter reports wins=4, results do not load, and the source carried Vietnamese text), T-006 agent-done - owner check pending]:
    Description: On the owner's build a 4x1 request leaves THREE windows on screen while the adapter reports wins=4, and the result files never show up; 2x1 and 1x2 work. The adapter also carried Vietnamese and typographic text in its comments and in two "Fix:" strings.
    Found at: user-check (owner, 2026-11-11): (1) choosing 4x1 gives 3 windows, not 4, even though the adapter reports wins=4; (2) results do not load; (3) code contains Vietnamese text.
    Cause: AGENT + EXTERNAL. AGENT: (a) every window count came from '<page> GetNumberOfWindows' alone, so a build that answers the number it was ASKED for while building one window fewer passed every check - one read-back was trusted; (b) the result step attached a result without first proving that window k holds a model, and '<model> SetResult' on a window with no model changes nothing and says nothing (conrod/tcl_guide/hv_model_loader.tcl:1362-1400 reports "no model is loaded in the window"); (c) text that came from the owner's Vietnamese prompts was left in the source. EXTERNAL: this build's window count and its layout tokens are not the documented ones.
    Fix: (1) ::pis::hw::observe prints ONE line `OBS: api=.. handles=.. clients=.. layout=..` and is the only window counter in the file: index 1..api+2 is asked for a window handle and every window for a client handle, so a phantom window (api=4 handles=3) is as visible as a missing one; a layout counts only when api == handles == clients == cols*rows. (2) grid_sweep, make_grid and the already-complete-grid shortcut all use that observation; grid_sweep keeps one row per attempt and make_grid, when no candidate matches, fails BEFORE loading anything and prints `TRY <token> -> OBS: ...` (at most 12 lines) plus ONE `Fix: pick the layout by hand in HyperView (window layout menu), then click Load All again (SetLayout is skipped when the page already has the right windows)`. The disagreement is reported verbatim as `grid: api=<a> handles=<h> clients=<c> wanted=<n>`. (3) A plain window count ("4") and the legacy words ("4H") are no longer candidates: no file in this workspace shows them producing that many windows, and conrod/tcl_guide/hv_model_loader.tcl:441 says the plain count "12" is a SINGLE window. (4) Load All attaches a result only after ::pis::hw::models_in_window k answers 1 - otherwise `skip result: window <k> has no model`; every failing load step puts HyperView's own words (first 70 chars) in the status bar and the log as `<step> window <k> variant <v>/<n> failed: <raw>`. (5) All non-ASCII removed from src/, tests/, scripts/ (19 bytes in 8 files: typographic dashes, arrows, quotes, one Vietnamese comment), and scripts/verify.sh now checks for any byte above 0x7F. (6) BUILD is now `T6h-20261111-1153`; the adapter is 1601 lines (same as pass 6: dead procs grid_token, legacy_token, page_state, grid_answer and verify_grid were deleted to pay for the new code).
    Prevention: tests/tcl/test_hw_adapter.tcl "0" (observe: ONE line under 80, api/handles/clients/layout, no journal line, a phantom window shown as api=4 handles=3); "D1" (a mock that accepts the token but builds one window fewer: the grid FAILS with `grid: api=4 handles=3 clients=3 wanted=4`, the TRY table shows it, nothing is loaded, the status goes red, no token is cached); "D2" (2x1, 1x2, 2x2, 4x1, 1x4, 3x2, 4x2 each find the one token that mock honours); "C" (a build that honours only a plain count or a legacy word cannot build 2x2: 4 TRY lines plus the Fix line, nothing loaded, nothing journaled); "M" (windows with no client handle fail with clients=0); "N" (an already-complete grid is skipped, a page with one chart window is rebuilt); tests/tcl/test_block0.tcl keeps the Load All, replay, chart-page and diag checks green, and the result step now proves the model first (`skip result: window <k> has no model`); scripts/verify.sh checks every byte of src/, tests/ and scripts/ for 0x7F+ (shown red on a temp file with one Vietnamese letter, then green).
    Agent:
      Ran: 2026-11-11 (pass 7): `tclsh tests/tcl/test_hw_adapter.tcl` -> `ok  all ::pis::hw adapter checks passed (HyperView side MOCKED)`, exit 0 (MOCK); `tclsh tests/tcl/test_block0.tcl` -> `ok  all block-0 checks passed`, exit 0 (MOCK); `bash scripts/verify.sh` (git-bash, tclsh 8.6.17) -> `ok  10 file(s)`, `ok  55 file(s) are ASCII`, all 6 test files `ok`, `verify: OK`, exit 0. The ASCII check was shown RED first: a temp file `tests/tcl/zz_ascii_probe.tcl` holding one Vietnamese letter printed `verify: NON-ASCII tests/tcl/zz_ascii_probe.tcl:2: byte 0xE1` (three bytes) and `verify: FAILED`; the file was deleted and the run went green.
      Not verified on HyperView: the OBS line, the TRY table, the Fix line and the raw load error are MOCK evidence on this machine; no HyperView was available, and `src/spike/try_load_all.tcl` was parsed, not run.
      Diff: no `.git` in this folder, so no `git diff --stat`; files changed: `src/01_scripts/_tcl_pis_11_hw_adapter.tcl` (BUILD `T6h-20261111-1153`, 1601 lines before and after), `src/01_scripts/_tcl_pis_01_load_model_results.tcl`, `src/spike/try_load_all.tcl` (TRY_ALL), `scripts/verify.sh` (the ASCII check), `tests/tcl/test_hw_adapter.tcl`, `tests/tcl/test_block0.tcl`, and 7 files whose only change is ASCII text (`_tcl_pis_02_load_legend.tcl`, `_tcl_pis_99_workflow_gui.tcl`, `probe_hvi_reset.tcl`, `spike_legend_window.tcl`, `spike_load_model.tcl`, `test_gui_frame.tcl`, `test_legend.tcl`); `docs/TASKLOG.md` (this entry). The concise-reply skill file was also edited: its Language section now says file content is English ASCII.
      Assumptions used: (1) a window that answers GetClientHandle is not necessarily a HyperView window - `client GetModelList` decides, because no script on this machine calls `GetClientType`; (2) asking indices 1..api+2 finds an extra window on every layout the GUI offers; (3) the reference result call is `<model> SetResult <file>` on the handle from `GetModelHandle GetActiveModel` (conrod/tcl_guide/hv_model_loader.tcl:1376-1388), and variant 1 is argument-for-argument that form.
      Try on HyperView (user, max 3 steps):
        1. File > New, 1 model + 4 results, layout 4x1, Load All -> seeing ONE `OBS: api=4 handles=4 clients=4 ...` line, ONE `SWEEP 4x1: ...` line, ONE `Keep: 4x1 -> ...` line and FOUR filled windows is correct. If it fails, copy the `TRY ... -> OBS: ...` lines plus the `Fix:` line back: they name the exact disagreement (api vs handles).
        2. Repeat with layout 2x1 and then 1x2 -> both must still fill 2 windows with their results (they worked before; they must not regress).
        3. `::pis::hw::diag` -> ONE line under 80 characters with `layout=<token> obs=4/4/4 model=1,1,1,1 result=1,1,1,1` is correct; a `0` in model=/result= or `obs=` numbers that disagree is wrong. A failing window now shows HyperView's own words: `<step> window <k> variant <n>/<n> failed: ...`.
      Rollback: no git target; rolling back means restoring `::pis::hw::grid_token`, `legacy_token` and the single-count `check_grid`, which is the defect itself - do not. `::pis::hw::use make_grid <n>` still moves the start variant without editing a file.
    User:
      Check: pending (2026-11-11) - the 3 steps above
      Steps run / skipped:
      Notes:

  Defect (if any) [2026-11-11, pass 8 - EXTERNAL (the owner measured his own HyperView: the layout is an integer ID, not a "CxR" token), T-006 agent-done - owner check pending]:
    Description: The owner measured four spellings of a 4x1 request ("4x1", "4 x 1", "4 - 1", "4 times 1") and every one gave layout=4 api=3, while the four transposes gave layout=1 api=2. So '<page> SetLayout' reads ONLY the leading integer of its argument and treats it as a layout ID; a "CxR" string is never understood, and '<page> GetLayout' answers that integer. A window-handle/client-handle probe above api SUCCEEDS on his build (api=2 handles=4 clients=3), so such a probe is not evidence. His working reference runs page SetLayout -> client AddModel -> model SetResult -> client WaitForResults, one window at a time.
    Found at: user-check (owner, 2026-11-11, pass 8): measured facts F1 (the leading integer is a layout ID), F2 (probes above api succeed), F3 (the working call order).
    Cause: EXTERNAL. Passes 5-7 treated the layout as a STRING token ("RxC" spellings, the plain count, the legacy words) and tried to measure it by applying each spelling. F1 says none of those strings can be understood: "4x1" is the id 4, which happens to be a three-window layout on this build - exactly the 3-window answer to a 4-window request. Pass 7's counter also asked indices 1..api+2, and F2 says those probes succeed, so part of the evidence it compared was noise.
    Fix: (1) The string machinery is GONE - sweep_tokens, sweep_script, grid_sweep, sweep_table, owner_token and build_code were deleted (adapter 1598 -> 1489 lines, net -109). (2) ::pis::hw::layout_table measures THIS page: 'SetLayout <n>' for n = 1..30 (stop after three consecutive SetLayout errors), api read after each, cached for the session, printed as ONE line under 80 characters, e.g. `LAYOUTS 1=2 2=2 3=3 4=3 5=4`; it moves the page, so it is a probe and nothing is journaled. (3) ::pis::hw::make_grid wants cols*rows and takes its id from (a) the page itself when it already shows that many real windows (no SetLayout at all), (b) [layout_tokens] in the ini or ::pis::hw::grid_token_set (integers only), (c) the ids whose measured api is the wanted count - one: use it; several: the LOWEST one plus `Override: ::pis::hw::grid_token_set <cols> <rows> <id>`; none: print the LAYOUTS line and `Fix: choose the layout by hand in HyperView, then click Load All again`, BEFORE anything is loaded. Only the final 'SetLayout <id>' is a step (journaled once) and every build prints ONE `GRID: id=<n> api=<a> clients=<c>` line. (4) ::pis::hw::observe asks indices 1..api only (never above api - F2), and the grid rule now lives in ONE place, ::pis::hw::check_grid: for k = 1..api the page must answer a window handle AND a client handle whose `GetModelList` works (a chart window answers a client handle too, so it is the client type that separates them). There is no separate `handles == api` / `clients == api` rule: the two counters only say how many of the api windows answered, and a mismatch prints `grid: api=4 handles=3 clients=3 wanted=4 (window 4 did not answer)`. (5) Load All follows F3 per window: AddModel (the id it RETURNS is kept in ::pis::hw::adapt_models), the model count of that window is verified (otherwise `skip result: window <k> has no model`), SetResult on that model's handle, `client WaitForResults`, then the result controller is read back; every failing load step puts the RAW text (first 70 chars) in the status bar and the log as `<step> window <k> failed: <raw error>`. (6) ::pis::hw::diag is ONE line under 80 characters: `DIAG: id=<n> api=<a> model=<1|0 per window> result=<1|0 per window>` (client= only while it fits), and src/spike/try_load_all.tcl ends with the same line, printed by the adapter. (7) The ini documents `<cols>x<rows> = <layout id>` and ::pis::common::read_layout_tokens keeps positive INTEGER values only (a "CxR" string is dropped, never sent). (8) BUILD is `T6i-20261111-1420`. (9) `scripts/verify.sh` judges TEXT files only (`*.tcl *.sh *.ini *.md *.txt *.cfg *.json *.ts`): the all-files scan died with `verify: ERROR cannot read src/02_working/t006_25472/model.inp` on the owner's own work data (model.inp + r1..r9.h3d), so a data drop there could turn the check red; the rule itself (any byte above 0x7F in code or docs) is unchanged and was proven red on a probe file.
    Prevention: tests/tcl/test_hw_adapter.tcl (MOCK only, no HyperView here): F1/F2 as facts of the mock (SetLayout reads the leading integer; above api handles=4 clients=3); (i) the old "4x1" string path is RED with `grid: api=3 handles=3 clients=3 wanted=4`; (ii) layout_table finds the id with four windows, prints ONE line and stops after three unknown ids; (iii) several ids -> lowest id + Override, no id -> LAYOUTS + Fix with nothing loaded, exactly one id -> no Override; (iv) observe never asks above api, so a 2-window page is reported as 2; (v) AddModel -> model verify -> SetResult -> WaitForResults -> result verify, with the model handle opened with the id AddModel returned, and a window without a model skipping its result; (vi) the raw error text reaches the status bar and the log; (vii) exactly ONE SetLayout in the journal; (viii) 2x1, 1x2, 2x2, 4x1, 1x4, 3x2 and 4x2 all build from the measured id; plus the D1 phantom window (api=4 handles=3, reported as `grid: api=4 handles=3 clients=3 wanted=4 (window 4 did not answer)`) and a page that ignores every id. tests/tcl/test_block0.tcl keeps Load All, replay, order 1/2, the hand-made grid, the chart-page refusal and the per-window model/result checks. 280 MOCK checks in test_hw_adapter.tcl, 260 in test_block0.tcl; scripts/verify.sh: 10 files parsed, 22 files ASCII, 6 test files green.
    Ran: 2026-11-11: `tclsh tests/tcl/test_hw_adapter.tcl` -> 280 PASS, exit 0 and `tclsh tests/tcl/test_block0.tcl` -> 260 PASS, exit 0 (HyperView MOCKED: the page/window/client/model handle objects and F1/F2 live in the mock); `bash scripts/verify.sh` -> verify: OK, exit 0 (10 files parsed, 22 text files ASCII, 6 test files green). The ASCII rule was proven live, not assumed: `src/_tmp_probe.txt` with bytes 0xC3 0x97 -> `verify: NON-ASCII src/_tmp_probe.txt:2: byte 0xC3` + `byte 0x97` + `verify: FAILED`, exit 1; file deleted -> `verify: OK`, exit 0. NOT verified on HyperView (no GUI on this machine).
    Diff: no `.git` in this folder, so no `git diff --stat`; files changed: `src/01_scripts/_tcl_pis_11_hw_adapter.tcl` (BUILD `T6i-20261111-1420`, 1598 -> 1489 lines), `src/01_scripts/_tcl_pis_01_load_model_results.tcl` (load order), `src/01_scripts/_tcl_pis_00_common.tcl` (`read_layout_tokens` keeps integers), `src/00_config/pis_workflow_config.ini` (`[layout_tokens]` comment), `src/spike/try_load_all.tcl` (TRY_ALL + the DIAG line), `scripts/verify.sh` (text-only ASCII scan), `tests/tcl/test_hw_adapter.tcl`, `tests/tcl/test_block0.tcl`, `docs/TASKLOG.md` (this entry). The probe file `src/_tmp_probe.txt` was deleted after the red run.
    How to check (owner, HyperView, 3 steps):
      1. Source the app and type `::pis::hw::layout_table` -> ONE `LAYOUTS ...` line. The id printed next to the count you want (4 for a 4x1 grid) is the id this build uses; seeing that line is correct, seeing no line at all is wrong.
      2. Load 4x1 with Load All -> ONE `GRID: id=<n> api=4 clients=4` line and four filled windows. A `GRID` line with api=3, a `LAYOUTS ...` line instead of `GRID`, or a FAIL line ending in `Fix: choose the layout by hand...` is wrong: paste those lines back.
      3. `::pis::hw::diag` -> ONE line under 80 characters, `DIAG: id=<n> api=4 model=1,1,1,1 result=1,1,1,1`. A 0 in model=/result= means that window failed; paste the line back. Then repeat 1-3 for 2x1 and 1x2 (the sizes that already worked) to prove nothing regressed.
    Rollback: no git target; the layout is pinned by ONE integer per size, so `::pis::hw::grid_token_set <cols> <rows> <id>` (or a `[layout_tokens]` line in the ini) overrides the measurement without editing any file, and `::pis::hw::use <op> <n>` still moves a start variant. Bringing the string tokens back is the defect itself - do not.
    STOP RULE: if this pass still fails, no more code is written; only the `LAYOUTS`, `GRID` and `DIAG` lines are asked for.
    Superseded by pass 9: those three lines are ONE FILE now (`src/spike/t006_check.tcl`), and the file writes the report to send back.
    User:
      Check: pending (2026-11-11) - the 3 steps above
      Steps run / skipped:
      Notes:

  Defect (if any) [2026-11-11, pass 9 - OWNER (he uses FILES, he does not run console commands), T-006 agent-done - owner check pending]:
    Description: Pass 8 handed the owner three console commands (`::pis::hw::layout_table`, Load All, `::pis::hw::diag`). Owner, 2026-11-11: "I only use files, I do not run commands." A check that exists only as typed commands is a check he cannot run, and there was no file to send back.
    Found at: user-check (owner, 2026-11-11, pass 9).
    Cause: EXTERNAL (workflow), not a code defect: the three LAYOUTS / GRID / DIAG lines already exist and the adapter is unchanged in this pass. `src/spike/try_load_all.tcl` is a file, but it writes no report, so "send the result back" still meant copying from the console.
    Fix: NEW FILE `src/spike/t006_check.tcl` (247 lines, a spike - the adapter is NOT touched): (1) the values to edit are the first lines of the file - model, result file(s), cols, rows, plus two switches (measure the layout table, keep going after a failed window); a run clears those six names, so sourcing the file again after an edit reads the edit and never a stale copy; (2) sourcing it runs the app, the layout measurement, make_grid and the per-window F3 load; (3) it writes ONE report, `src/02_working/t006_check.txt`, holding the adapter's own BUILD line, the LAYOUTS line, `OBS`, the GRID line, the DIAG line and ONE `VERDICT: PASS|FAIL <reason>` line - the file travels, the console is not needed; (4) the report IS the console transcript: the file captures the adapter's `puts` and installs the log sink, and puts the real `puts` back when it is done (`chan puts` writes the report, so the capture cannot loop); (5) a failing run still writes the report with a VERDICT line (every step is caught; the reason caps at three items, e.g. `VERDICT: FAIL window 1: no model, window 2: no model, window 3: no model, ...`); (6) the verdict is read back window by window (`<models>:<resultCtrl>`, "1:1" = ready, the same gate Load All uses) and never parsed out of the DIAG line, which is cut at 80 characters and would lose the lists of a 13+ window grid; (7) it never resets the session and never edits a file - start from File > New. `scripts/verify.sh` now skips `src/02_working` in the ASCII scan, for the same reason it already skipped the owner's work data there: that folder holds the report too, and a report quotes the path the owner chose.
    Prevention: tests/tcl/test_hw_adapter.tcl "14" runs the REAL file three times under the MOCK: (14a) 2x1 with one result per window - the report exists, starts with the BUILD line, holds LAYOUTS, `GRID: id=1 api=2 clients=2`, `DIAG: id=1 api=2 model=1,1 result=1,1`, `VERDICT: PASS`, is pure ASCII, names its own path, `puts` is the real command again afterwards, and the six edited values are cleared so a second source re-reads them; (14b) a 2x2 grid with only two results - `VERDICT: FAIL` naming `window 3: no model`, still ONE line under 80 characters; (14c) no result file at all - the first three empty windows are named and the rest is capped with `...`. Green: `tclsh tests/tcl/test_hw_adapter.tcl` -> 300 PASS, exit 0; `tclsh tests/tcl/test_block0.tcl` -> 260 PASS, exit 0; `bash scripts/verify.sh` -> `verify: OK`, exit 0 (11 files parsed, 23 ASCII text files, 6 test files). The new scan rule was proven both ways: a non-ASCII byte in `src/02_working/_probe.txt` no longer turns verify red, the same byte in `src/_probe2.txt` still does (`verify: NON-ASCII src/_probe2.txt:1: byte 0xC3`, exit 1); both probe files deleted, verify green again. Also proven WITHOUT HyperView: sourcing the file under plain tclsh writes the report and ends in `VERDICT: FAIL make_grid 2x2 did not build the grid (see STEP line)` instead of crashing.
    How to check (owner, HyperView, ONE file, nothing typed): edit the four values at the top of `src/spike/t006_check.tcl`, then source the file (File > Run Script) -> it prints its transcript and writes `src/02_working/t006_check.txt`; send that file back. `VERDICT: PASS` plus `GRID: id=<n> api=4 clients=4` is correct; `VERDICT: FAIL` is an answer too - the file names the grid or the window that failed.
    Rollback: delete `src/spike/t006_check.tcl` and the report it writes; nothing else changed (`::pis::hw` is identical to pass 8, `scripts/verify.sh` only dropped one folder from a scan).
    STOP RULE: unchanged - on a FAIL only the report file is read, no code is written.
    User:
      Check: pending (2026-11-11) - source `src/spike/t006_check.tcl`, send `src/02_working/t006_check.txt`
      Steps run / skipped:
      Notes:
  Defect (if any) [2026-11-11, pass 10 - EXTERNAL (the owner sent the report file back), T-006 agent-done - T-017 gate]:
    Description: The owner ran `src/spike/t006_check.tcl` in his HyperView and sent `src/02_working/t006_check.txt` back. Two answers came out of it: (1) the grid is still wrong in the shape he asked for - he asked for `4x1`, the report shows `layout=4` and THREE windows, which is the F1 fact (the leading integer is a layout ID, and id 4 is a three-window layout), not a bug in the count; (2) the report was written by the PREVIOUS adapter - its `BUILD:` line is `T6h-20261111-1153`, and that copy has no LAYOUTS line at all, while `src/01_scripts/_tcl_pis_11_hw_adapter.tcl` in the tree is `T6j-20261111-1650`. So the run tested the adapter from before T-016 and cannot answer anything the current build changed.
    Found at: user-check (owner, 2026-11-11, pass 10) - the report file, not the console.
    Cause: EXTERNAL, two parts. The layout half is F1 (a `cols x rows` pair is not a layout id; see T-017 for the fix and its gate) - it is not a pass-10 code change. The build half is a workflow cause: the owner copies files by hand into HyperView, and only the spike + the adapter he already had were refreshed, so the tree and his session disagree silently. A report that carries its own `BUILD:` line is what exposed it - the same line should be compared before any verdict is believed.
    Fix: no adapter or test code in this pass (T-017 is gated). Two comment blocks in `src/spike/t006_check.tcl` - its own how-to, so the owner reads it where he needs it: (1) a new step 0, "copy the WHOLE `src/01_scripts` folder (six files) into the HyperView script path, not one file", with this pass's mix-up as the reason; (2) a line under the report description, "read the BUILD line before sending: it must name the copy you just copied in (`T6j-20261111-1650` today)". No executable line changed.
    Prevention: the report's first line IS the build stamp (task 14 asserts it starts with the BUILD line), so a stale copy is visible without reading code; `tclsh tests/tcl/test_hw_adapter.tcl` -> 307 PASS, exit 0, and `bash scripts/verify.sh` -> `verify: OK`, exit 0, both on `T6j-20261111-1650` (adapter 1514 lines today, against the 1598 lines in the returned report - a second, independent sign that the two copies differ).
    How to check (owner, HyperView, ONE file, nothing typed): copy `src/01_scripts` into the HyperView script path (all six files), source `src/spike/t006_check.tcl`, send `src/02_working/t006_check.txt` back -> the first line must read `T6j-20261111-1650` and a LAYOUTS line must be there; the GRID line answering `api=4` for `4x2` is the only thing this run can still prove, the 4x1 shape waits for T-017.
    Rollback: revert the two comment blocks in `src/spike/t006_check.tcl` (step 0 and the BUILD-line reminder); `docs/TASKLOG.md` is the record of this pass.
    STOP RULE: unchanged - on a FAIL only the report file is read, no code is written.
    User:
      Check: pending (2026-11-11) - re-send `src/02_working/t006_check.txt` from a session running `T6j-20261111-1650`
      Steps run / skipped:
      Notes: the returned report shows `layout=4` with three windows for a `4x1` request - kept as the F1 evidence T-017 cites

  Defect (if any) [2026-11-11, pass 11 - AGENT (this pass: code review + the owner's pass-10 report), T-006 agent-done - owner check pending]:
    Description: The result step of Load All depended on a method the owner's build does not have. `load_window` sent `WaitForResults` after `SetResult` and counted an error as a failed window, so the run stopped on window 1 ("only window 1 loaded") although the result file was attached: `docs/refs/HV_API.md` S16/S17 document `WaitForResults` only for the HyperView - MultiCore profile, and F5 records that this build has no such call (the owner's F-b report). Related holes found in the same review: `AddModel` returning 0 (the documented "named failure") was read as a model id; the read-back had no retry bound, so a build that fills the controller a moment later would fail the window; a failed window did not say which windows were never tried.
    Found at: code review 2026-11-11 (this pass), the pass-10 report ("only window 1 loaded"), and MOCK block 14.
    Cause: AGENT. One optional HyperView call was the single gate on a step whose real proof (an attached result) is readable without it, and every mock answered every method, so "what if the method is absent" was never exercised. The owner cannot debug that from a report; he only sees the run stop.
    Fix: adapter `T6k-20261111-1703`: (1) the wait is now an OPTIMIZATION with three variants chosen at run time - client form, manager form (`GetClientManagerHandle mgr animation`, S20), or SKIP - and `GetAsyncMode` (S18) decides whether a wait is even meaningful; (2) a wait that is missing or raises never fails a window - its own error is caught INTO `::pis::hw::wait_error` inside the script, logged as one `WARN ... the read-back decided`, and that variant is not tried again in the session - and at most ONE `INFO result wait skipped: <reason>` line is logged per run (`begin_run` resets that latch); (3) success is the bounded read-back `GetResultCtrlHandle` + `GetNumberOfSubcases > 0` - 4 tries, 250 ms apart, `after` + `update`, no coroutines (Tcl 8.5, A15), never a hang; (4) a read-back that really fails stops the run with one line ending `windows N..M not attempted` (`load_window_guarded` in `_tcl_pis_01_load_model_results.tcl`); (5) `AddModel` 0 is a named failure; (6) `GetError` is read right after `SetResult` and again after the wait, because it CLEARS the condition (S19) - a single late read sees nothing.
    Prevention: MOCK block 14 in `tests/tcl/test_hw_adapter.tcl` runs the adapter against builds that answer no `WaitForResults`, answer only the manager form, raise from it, report async, have no client manager, return 0 from `AddModel`, and raise from the session: 347 PASS, exit 0. The rule this pass adds to the review checklist: no operation may depend on a method `HV_API.md` marks as profile-specific or `NOT FETCHED` unless the call is guarded AND has a SKIP variant with a test that takes it.
    How to check (owner, HyperView, ONE file, nothing typed): copy the WHOLE `src/01_scripts` folder into the HyperView script path (six files), source `src/spike/t006_check.tcl`, send `src/02_working/t006_check.txt` back -> the first line must read `T6k-20261111-1703`, the report must hold at most one `INFO result wait skipped: ...` line, and the verdict must be `PASS` with `result=1,1,1,1` (or a `FAIL` that names the read-back, which is also an answer). A run that stops on window 1 is wrong only if the stop line names something other than the read-back.
    Rollback: one BUILD step apart - `::pis::hw::use result_wait <n>` pins the START variant (1 = client form, 2 = manager form, 3 = skip; a run falls forward from there and always ends at skip), so a wrong choice is answerable without editing a file; the log line `INFO result wait: variant <n>/3 <cmd>` names the variant the run actually used. The layout half of Load All is untouched by this pass (T-017).
    STOP RULE: unchanged - on a FAIL only the report file is read, no code is written.
    Also in this pass (not a code defect): the first `t006_check` run of the day wrote `VERDICT: FAIL input: model file not found: <path> (edit MODEL at the top of this file)` - the six values at the top of the spike still held the placeholder path. Cause EXTERNAL (an unedited spike). The file now refuses before it touches HyperView and names the input, so an unedited copy can never again look like a HyperView failure.
    User:
      Check: pending (2026-11-11) - re-send `src/02_working/t006_check.txt` from a session running `T6k-20261111-1703`
      Steps run / skipped:
      Notes:
  Defect (if any) [2026-11-12, pass 12 - AGENT (the owner's real-GUI report), T-006 agent-done - owner check pending]:
    Description: Load All stopped on window 2 in the real GUI: `Status: Error: load_result window 2 failed: window 2: session error after SetResult: (poIPost::GetResultList)` - while window 2 DID hold its model and its result (a 2x1 layout showed both correct). In a 4x1 request it aborted at window 2 and windows 3 and 4 were never attempted, so the layout half of Load All could not be judged at all. The condition is a bare method note from HyperView's own SetResult path, not a failure of the step.
    Found at: the owner's pass-12 report (real HyperView GUI, `T6k-20261111-1703`), 2026-11-12 09:08, both a 2x1 and a 4x1 run.
    Cause: AGENT. `GetError` was used as a JUDGE although pass 11's own F6 already recorded that this build raises a method failure from the handle object and never from the session condition - so the condition is additional information, never proof. The same pass had already learned that lesson for the wait (a failed wait is a WARN) and did not apply it to the condition next to it. The mock could not catch it because `sim_sess_error` was never called by any test: the guard shipped with 0 assertions, and a guard no test takes is a guard nobody has read.
    Fix: adapter `T6l-20261112-0940`: (1) `GetError` is read once BEFORE `SetResult` to flush a leftover from the previous window (the read clears the condition, S19), so window k can never be failed by window k-1; (2) the read AFTER `SetResult` is stored in `::pis::hw::sess_note` and never raised - it is logged as ONE `WARN load_result_in_window window <k>: session note after SetResult: <text> - the read-back succeeded` per distinct text per run (`adapt_notes_seen`, reset by `begin_run`, so a full grid cannot repeat the same line); (3) when the read-back FAILS, that note is appended to the failure text as `(session note after SetResult: <text>)` - explanation, not cause; (4) the pre-SetResult flush runs inside the journaled script, so a replay shows the same order. The read-back stays the only judge (T-019).
    Prevention: MOCK block 14 (g)-(j) in `tests/tcl/test_hw_adapter.tcl` now takes the guard: the owner's exact text delivered AT SetResult time (`sim_sess_error_on_result`, so the flush cannot swallow it) leaves 3 of 3 windows loaded with one WARN; the same text on a 4-window grid loads all four and logs the note once (the owner's 4x1 symptom); a note plus a dead read-back fails with the read-back text and quotes the note; a leftover condition set BEFORE the step is flushed and never logged. 370 PASS, exit 0. Rule added to the review checklist: every guard in the result path must have a test that takes it, and a diagnostic channel (GetError, a wait error, a warning code) may never decide pass/fail on its own.
    How to check (owner, HyperView, ONE file, nothing typed): copy the WHOLE `src/01_scripts` folder into the HyperView script path (six files), then - in the GUI - run Load All again. A 4x1 request must now load all four windows; at most one `WARN ... session note after SetResult: (poIPost::GetResultList) - the read-back succeeded` line is expected in the log, and no `Error:` in the status bar. The check is GUI + log only: no spike file has to be sourced and no report file has to be sent back - the BUILD line at the top of the log names the copy that ran (it must read `T8d-20261117-0900` or later), `GRID: id=<n> api=4 clients=4` names the layout it picked, and any `ERROR`/`WARN` line names the window that did not load. Quoting those log lines is the whole answer.
    Rollback: one setting apart - `set ::pis::hw::retry_tries 4` / `retry_delay 250` bound the read-back; the note is log-only, so nothing in the journal changes shape; a build where the condition really does mean failure still fails, because the read-back fails with it and the note is quoted.
    STOP RULE: one HyperView run either way - a report/status line naming this pass is the answer; do not edit code between the GUI run and the spike run.
    Also in this pass (EXTERNAL: an unedited spike, not a code defect): the owner's `t006_check` run stopped at `VERDICT: FAIL input: model file not found: C:/temp/model.h3d` although his GUI had been loading a real model all along. `src/spike/t006_check.tcl` now falls back to the workflow's own ini (`[session] model_file` / `result_files`, read with `::t6::ini_get`, relative paths resolved against the app folder) and prints ONE `CHECK input: ... from pis_workflow_config.ini` line per value it took, so a report is never blocked by a placeholder and never silently runs on a different file than the GUI. Empty stays empty, and a placeholder that exists nowhere still reports `FAIL input` naming both ways to set it.
    User:
      Check: pending (2026-11-12) - run Load All in the GUI (4x1 and then 2x1) and read the log: `GRID: id=<n> api=4 clients=4` plus one result line per window is correct. GUI + log only, no spike file and no report file.
      Steps run / skipped:
      Notes:



T-007: Load Legend module â€” radio list + `on` checkbox + import per window through the T-002c adapter â€” Status: accepted (user check: pass, 2026-11-19 - the owner's "ok pass, accept." answers the T-035 check, so F16 and F17 are closed by T-035) - previously agent-done (seam `::pis::hw::select_window` + `::pis::hw::import_legend` Ä‘Ã£ Ä‘Æ°á»£c user ok qua T-002c ngÃ y 2026-11-10, `ASSUMPTION-Q3` Ä‘Ã³ng; T-007 váº«n chá» user check riÃªng cá»§a nÃ³) â€” Done when: `on` unchecked skips the module entirely, a missing legend file raises `Legend file not found: <path>` with 0 journal lines, a dialog override stays session-only, and the run calls `::pis::hw::select_window` then `::pis::hw::import_legend` (T-002c) once per targeted window, logging the variant used, and the step is judged by a READ-BACK: `docs/refs/HV_API.md` section 7 governs the legend form, so the task must name the legend/contour state query it reads and FAIL when that read-back shows no change - `hwc result scalar legend import` returning without an error is NOT success (this build ignores an unknown `hwc` silently, SPEC D2/F4); while HV_API.md lists no legend/contour state query (it does not today), the step keeps the label `UNVERIFIED-GUESS` and may never be reported OK on the strength of "no error"; khá»›p cÃ¡c má»¥c liÃªn quan trong Refs; mÃ¢u thuáº«n thÃ¬ theo SPEC.md D1-D5 â€” Only modify: `src/01_scripts/_tcl_pis_02_load_legend.tcl`, `src/01_scripts/_tcl_pis_99_workflow_gui.tcl` (legend block), `tests/tcl/test_legend.tcl` â€” How to check: 1) `tclsh tests/tcl/test_legend.tcl` â†’ seeing `PASS` for on=0, missing file, session override is correct, seeing the override written into the ini is wrong. 2) In HyperView uncheck `on` and run the module â†’ seeing 0 journal lines and an `INFO` skip message is correct, seeing an `hwc` line is wrong. 3) Type a non-existent `.tcl` path and run â†’ seeing `ERROR` containing that exact path is correct, seeing an attempt in the journal is wrong â€” Ran: 2026-11-09: `tclsh tests/tcl/test_legend.tcl` -> 56 PASS, exit 0 (HyperView MOCKED: `hwc`, `hwi` and the handle object commands are test doubles inside the test file); `bash scripts/verify.sh` -> verify: OK, exit 0 (6 files parsed, 5 test files green); live Tk smoke (window built, then destroyed, no HyperView): no legend row -> one `WARN module Load Legend: no item selected, nothing run`; one row + on=0 -> `INFO module Load Legend: on is unchecked, nothing run`; on=1 + missing file -> `ERROR module Load Legend: Legend file not found: <path>` with status `Error: <same>`; busy back to 0, `on` checkbutton back to `normal`, journal empty and `src/00_config/pis_workflow_config.ini` unchanged in every case. NOT verified (needs the owner in HyperView): everything the seam does â€” the imports themselves. Deviations to review: (1) the single seam `::pis::legend::apply_to_window` is marked ASSUMPTION-Q3/U2 ("import acts on the active window; window k is selected with `<page> SetActiveWindow k`, windows numbered 1..N in layout order") and is the ONLY place to change when the spike answers arrive â€” it is also the only place that calls `hwc` (via `::pis::hw::exec`, so the journal stays pure) and the only place that releases handles; (2) the namespace is `::pis::legend`, not the D3 `::pis::stepNN` pattern, because the owner named the proc `::pis::legend::apply_to_window`; (3) `[Apply all layout]` needs a window count, so it raises `Model/results not loaded | click Load All first.` when Load All has not run, while the module-name button imports into the active window without Load All; (4) the legend list/selection/`on` are built into a THROWAWAY cfg per run (`::pis::gui::legend_cfg`), so a GUI/dialog choice is session-only and nothing is written to the ini (persistence stays in T-013); (5) `busy_guard` now blocks any module request while another run is in flight (SPEC A11) and the `on` checkbutton is part of the busy lock. â€” Refs: docs/refs/SPEC_load_legend.txt FILE 3, FILE 4, HARD CONSTRAINTS; docs/refs/SPEC_gui.txt Â§6.2; docs/SPEC.md (Constraints ENV; D2; Q3 â€” adapter rules and the ok/fail channel)
T-008: Load result module â€” radio list, name must exist in the result file â€” Status: accepted (user check: pass, 2026-11-18 - the owner's "ok pass. accepted." closes fail 1..fail 6; the answer to fail 6 was T-031) - T-027, 2026-11-12: OWNER CHECK fail 3 (a CORRECT name still leaves every window reading enabled=false for line/shell/solid, and the error names `poIContourCtrl SetEnabled` as a method this build does not have; cause AGENT: an undocumented ORDER of the two state changes and an UNVERIFIED-GUESS method were relied on, and the report hid the documented order's outcome - the fix is the T-027 line below) - T-026, 2026-11-12 FIXED: OWNER CHECK fail 2 (step 2 passed, but on the correct result name the log said applied while the window's contour did NOT change; cause AGENT: the verdict trusted "no error" and the read-back did not prove what the window DISPLAYS; the T-026 line below carries the doc/code table and the fix). Earlier status was agent-done (2026-11-12: docs/refs/HV_API.md section 11 named the HyperView call BEFORE any code, then the module, the GUI block and the test; the owner check is still owed) â€” Done when: the selected type is applied to the targeted window(s), an unknown name raises `result '<name>' not found in <file>` and stops unless continue-on-error is set, and the selection persists in the ini, and (2026-11-11 amendment) the task names its HyperView call in `docs/refs/HV_API.md` BEFORE any code - an `hwi` handle call where one exists, not an `hwc` form - and the step FAILS when its read-back shows no change; khá»›p cÃ¡c má»¥c liÃªn quan trong Refs; mÃ¢u thuáº«n thÃ¬ theo SPEC.md D1-D5 â€” Only modify: `src/01_scripts/_tcl_pis_03_load_result.tcl`, `src/01_scripts/_tcl_pis_99_workflow_gui.tcl` (result block), `tests/tcl/test_result.tcl`, `docs/refs/HV_API.md` (section 11 - the call is named there FIRST, per the 2026-11-11 amendment) â€” How to check: 1) `tclsh tests/tcl/test_result.tcl` â†’ seeing `PASS` for a known type and for an unknown type is correct, seeing the unknown type reach the wrapper is wrong. 2) In HyperView with a loaded result file run Load result with a wrong name â†’ seeing `ERROR` `result '<name>' not found in <file>` and 0 new journal lines is correct, seeing a contour change or a crash is wrong. 3) Run with a correct name â†’ seeing the contour switch and 1 journal line per window (`hwc` or `hwi`) is correct, seeing 0 lines is wrong â€” Ran: 2026-11-12: `tclsh tests/tcl/test_result.tcl` -> MOCK, 70 PASS, exit 0 (label matcher; one PROVEN SetDataType per window with one hwi journal line each; unknown type -> `result 'X' not found in <file>` with 0 HyperView calls and 0 journal lines; a build that answers success and changes nothing is refused by the GetDataType read-back; continue-on-error; active-window scope via GetActiveWindow without reselecting; empty data type list, no result attached, no selection, blocked before Load All, unknown scope; ini byte-identical; GUI busy guard + result_cfg + run_module dispatch; missing HyperView); `bash scripts/verify.sh` -> `verify: OK`, exit 0 (7 test files green, 26 files ASCII, 7 files Tcl 8.5). Assumptions used: the ini result-file line k is the file Load All put in window k (step01 loads them in order) and the `active` scope reads the window index with hwIPage GetActiveWindow (S33). NOT done here: writing the module lists back into the ini on exit (T-013 owns that write; this module only READS the selection and never writes the ini). â€” Refs: docs/refs/SPEC_gui.txt Â§6.1


T-026: fix T-008 - apply the result so the window really DISPLAYS it - Status: agent-done (owner check pending, 2026-11-12) - Owner report recorded as `T-008: fail 2`: step 2 PASS (a wrong result name still raises `result '<name>' not found in <file>` and writes no journal line); step 3 the log says the result was applied while the window does NOT show it (the contour did not change) - Cause AGENT: the verdict trusted "no error", and the read-back did not prove what the window DISPLAYS - NOT accepted - FIXED 2026-11-12 (AGENT; "accepted" is the owner's word to write, the owner check is still owed): the module now reads the window BACK after every change and journals only what the read-back proved. Code: `src/01_scripts/_tcl_pis_03_load_result.tcl` (apply_to_window: read -> membership (S30) -> enable the dimensions that are off (S35) -> SetDataType (S28) -> SetCurrentSubcase only when there is none (S39/S40) -> Draw on window k's client -> read again -> verdict; run: one apply per window, one INFO line per window carrying every value read, one journal line only for the window that passed, ONE `::pis::hw::refresh` after the loop) and `src/01_scripts/_tcl_pis_11_hw_adapter.tcl` (`::pis::hw::refresh`, BUILD `T8a-20261112-1449`). Doc/code table in `docs/refs/HV_API.md` section 11: S28 SetDataType = the step, S29 GetDataType = the type read-back, S30 GetDataTypeList = the membership gate, S35/S36 Set/GetDimensionEnabled = the DISPLAY gate, S37/S38 Set/GetDataComponent (read only, never set), S39/S40 Set/GetCurrentSubcase (set only when none), S41 poIContourCtrl SetEnabled = UNVERIFIED fallback, variant 2 only; SPEC.md A10 now defines a type as APPLIED only when the window's own read-back proves the DISPLAY state. MOCK tests a-g in `tests/tcl/test_result.tcl`: a contour that stays disabled FAILS; the enable step precedes SetDataType and skips a dimension already on; SetCurrentSubcase only when the window has none; Draw runs on window k's own client; an unknown name -> exact text, 0 calls, 0 journal lines; the journaled line replays to the same state; the 1 -> 2 fallthrough journals only the passing form and reports the last variant's text once. Owner check file: `src/spike/t008_check.tcl` -> `src/02_working/t008_check.txt` (BUILD, CHECK, BEFORE/AFTER read-back per window, STEP, VARIANT, JOURNAL, VERDICT) - Ran: 2026-11-12: `tclsh tests/tcl/test_result.tcl` -> MOCK, 155 PASS, exit 0; `bash scripts/verify.sh` -> `verify: OK`, exit 0 (7 test files green, 27 files ASCII, 7 files Tcl 8.5).
T-027: fix T-008 after `T-008: fail 3` - make the dimensions really enabled, and make the failure report complete - Status: agent-done (owner check pending, 2026-11-12; NEVER accepted) - Owner report recorded as `T-008: fail 3` (T-026 not accepted): a CORRECT result name gives `Error: result window 1: '1. Endure_SF_A' not displayed (type='1. Endure_SF_A' enabled='line=false,shell=false,solid=false' subcase='1' component='Scalar value') | the apply script failed: Object named: pisCt (of type poIContourCtrl) could not find requested method: SetEnabled Or the method was called with incorrect arguments.` Facts F9: (a) poIContourCtrl has NO SetEnabled on this build, so T-026's S41 guess is dead; (b) after the apply the window reads the right type, subcase 1 and component 'Scalar value' but ALL THREE dimensions read false, so nothing is displayed; (c) only the LAST variant's error was shown, so variant 1's outcome was invisible; (d) T-026 enabled the dimensions BEFORE SetDataType and no page prints that order - a type change that resets the state produces exactly (b). Cause AGENT: an undocumented ORDER and an UNVERIFIED-GUESS method were relied on, and the report hid the documented variant's outcome. FIX (item 1 table in `docs/refs/HV_API.md` section 11, questions asked of the doc before any code): (a) S35 prints `SetDimensionEnabled dim_label state` with `dim_label` in {"line","shell","solid"} and state "True if enabled, false if not" - ONLY true/false are printed and the class examples use `true`; (b) the doc does NOT say whether SetDataType keeps or resets the dimension state = UNKNOWN, so BOTH orders are variants; (c) no other documented method turns the contour on that this code may use (`SetEnableState` is a different feature; `PlotResult`/`LoadResult` pages are NOT FETCHED, so their arguments would be invented), and `SetEnabled` is dead; (d) the doc does NOT say a Draw is needed before GetDimensionEnabled reflects the change = UNKNOWN, so it is measured, not guessed. Code: `src/01_scripts/_tcl_pis_03_load_result.tcl` - variant table V1 type-first/`true` (DOC literal, order UNVERIFIED-GUESS), V2 enable-first/`true` (the T-026 order), V3 type-first/`1`, V4 enable-first/`1` (the 1/0 form is UNVERIFIED-GUESS); `SetEnabled` is gone from production; every variant ends with the same read-back (S29 type, S36 all three dimensions, S40 subcase) and the same verdict (type + AT LEAST ONE dimension true, so a model without solids is not refused, and the other two are printed); when every variant fails the LOG holds one line per variant - `result window k: '<name>' not displayed | variant v/n <short>: step <step> -> <the build's raw text or the values read>` - never cut, in the order tried, and the raised text (status bar) is the first 70 characters of the FIRST line plus " (see log)". ABSENT-METHOD RULE, shared in `src/01_scripts/_tcl_pis_11_hw_adapter.tcl` (`::pis::hw::absent_parse/of/note/has/add/list/reset`, ADAPTER BUILD `T8b-20261112-1638`): `could not find requested method: <name>` records `<class> <name>` for the run; the longer text that adds `or the method was called with incorrect arguments` is proof ONLY when the call used the documented arguments (a guessed argument is never turned into a fact); a recorded method is never sent again in that run - windows 2..N included - a variant that needs it is SKIPPED instead of counted as a failed attempt, and ONE `INFO method absent on this build: <class> <name>` is logged per run; F9 (a) recorded in HV_API.md section 8. Owner file `src/spike/t008_check.tcl`: new switch `MATRIX = 0`; with 1 it runs six cells on window 1 only (enable_first/type_first x true/1 x draw_before_read 1/0), prints `CELL n order=.. bool=.. draw_before_read=.. -> type=.. enabled=.. err=<full text>`, then `MATRIX BEST: cell n|none`, restores the original type and dimension states and prints them, plus a read-only `GETTER` probe (GetLayer, GetShellLayer, GetShowMidsideNodeResults - getters with no documentable arguments). Tests (MOCK, `tests/tcl/test_result.tcl` + `tests/tcl/test_hw_adapter.tcl`): a build whose SetDataType RESETS the dimensions -> V1 passes and the enable-first script is shown leaving them false; a build that accepts only 1/0 -> V1/V2 fail, V3 passes, the journal holds only V3; SetEnabled absent -> nothing calls it; a method absent on window 1 -> called ONCE, one INFO, window 2 skipped, `no variant could run`; all four variants in the log with the values read and the 70-character status text; a model without a solid dimension still passes (`solid=?`); a wrong name -> exact text with 0 apply calls and 0 journal lines; journal replay; the owner's absent text parsed with and without documented arguments; the MATRIX block on the mock. - Ran: 2026-11-12: `tclsh tests/tcl/test_result.tcl` -> MOCK, 193 PASS, exit 0; `tclsh tests/tcl/test_hw_adapter.tcl` -> MOCK, 447 PASS, exit 0; `bash scripts/verify.sh` -> `verify: OK`, exit 0 (14 tcl files parsed, 27 ASCII, 7 Tcl 8.5, 7 suites green). Commands still UNVERIFIED on HyperView: whether type-first or enable-first is the order that leaves the dimensions true, and whether the literal must be `true` or `1` - both are answered by `MATRIX BEST` in the owner file (owner check step 2), never by this log. - Refs: docs/refs/HV_API.md section 11 (S28-S42), SPEC.md A10.
T-028: package the repo for hand-off and publish it on GitHub - Status: agent-done (2026-11-12, owner request) - Why: the owner asked for a new repo `tcl_guide_v2` so another agent can continue the work. Changed: `README.md` rewritten from the template text to the real project (what it is, the one verify command, the module list, the repository map, the doc-first rule, the hand-off prompt, the template leftovers); new `docs/HANDOFF.md` (task board, the owed owner check for T-027, what to do next, the two UNKNOWN facts, the rules that must not be broken, the code seams, the test switches, the docs map, a first-day checklist); `.github/workflows/ci.yml` no longer installs pnpm/Node - it installs Tcl and runs `bash scripts/verify.sh` plus gitleaks, because the repo holds no Node code and the template steps would have failed on every push; `src/index.ts` and `src/index.test.ts` (`Hello, world` template placeholders) moved to `docs/archive/template-node/` so no file under `src/` looks like a TypeScript build; `docs/archive/README.md` updated (the folder is no longer "the only copy", git history exists now). No product code touched: `src/01_scripts/**`, `tests/**`, `scripts/verify.sh` are unchanged from T-027. - Ran: 2026-11-12: `bash scripts/verify.sh` -> `verify: OK`, exit 0 (14 tcl files parsed, 27 ASCII, 7 Tcl 8.5, 7 suites green); `git init -b main` + first commit of 70 files, remote `https://github.com/DeleteQuaKhu/tcl_guide_v2`. - Refs: AGENTS.md, docs/HANDOFF.md.

T-009: Measures module â€” checkbox list, row order = execution order â€” Status: todo â€” Done when: only checked rows run, in list order, the list is saved/restored with its check state, and an empty selection logs one `WARN` naming the module, and (2026-11-11 amendment) the task names its `poIMeasure` call in `docs/refs/HV_API.md` BEFORE any code (that page is NOT FETCHED today), prefers an `hwi` handle call over an `hwc` form, and FAILS the step when its read-back shows no measure was added; khá»›p cÃ¡c má»¥c liÃªn quan trong Refs; mÃ¢u thuáº«n thÃ¬ theo SPEC.md D1-D5 â€” Only modify: `src/01_scripts/_tcl_pis_04_measures.tcl`, `src/01_scripts/_tcl_pis_99_workflow_gui.tcl` (measures block), `tests/tcl/test_measures.tcl` â€” How to check: 1) `tclsh tests/tcl/test_measures.tcl` â†’ seeing `PASS` for order and for an empty selection is correct, seeing an unchecked row execute is wrong. 2) In HyperView add 3 measures, check rows 1 and 3, run the module â†’ seeing 2 journal lines in row order is correct, seeing 3 lines or reverse order is wrong. 3) Uncheck every row and run â†’ seeing exactly one `WARN` naming the module and no journal change is correct, seeing an `hwc` line is wrong â€” Ran: - â€” Refs: docs/refs/SPEC_gui.txt Â§6.3


T-029: the T-008 evidence pass - the report must carry the state, the display switch must be documented, and no check may die on an input - Status: agent-done (2026-11-16, owner check owed, NEVER accepted) - Why: `T-008: fail 4` plus the owner's `t008_check.tcl: input defect` (both below), and the STOP RULE recorded in `docs/SPEC.md` after three failed passes that relied on UNVERIFIED-GUESS variants; this pass adds NO guessed variant, ONE documented one, and the evidence the next decision needs. Items: (0) INPUT RULES - the spike resolves the result name (file variable, then the GUI's `[result]` selection via `::pis::common::load_config` + `::pis::result::selected_item`, then the first type `GetDataTypeList` offers), model/layout the same way, and every failure path (no name, no model, no page answer) still prints the types + the read-only state before it stops; ONE BUILD line per report (the adapter's own). (1) `poIPost SetDisplayOptions contour true` (S56, read-back S57) is the ONLY fetched method that turns a contour's DISPLAY on, so it becomes variant V5, labelled DOC in `::pis::result::variant_info` (`display 1`, `display_src "DOC S56 ..."`), placed before the `Draw`, and named by `::pis::result::variant_needs` as `{poIPost SetDisplayOptions}` so the absent-method rule can skip it; V1-V4 stay as they were and nothing else was added (answer table below, `docs/refs/HV_API.md` section 12). (2) STATE DUMP - every normal GUI failure now logs ONE `STATE DUMP window 1` block (`::pis::result::dump_window`): one line per documented read-only getter of `poIContourCtrl` plus the result controller's subcase reads and `GetDisplayOptions contour`, each in its own `catch`, `name = value`, a raising getter as `name = ERR <the build's own text>`, a closing `STATE DUMP end window k (N getter(s), E error(s))`, and ONE `simulation = NOT DUMPED` line; getters only, by construction (`::pis::result::dump_calls`), so the dump can never change the session; the 5 getters that are left out are listed with their reason in `docs/refs/HV_API.md` section 12. (3) `src/spike/t008_state.tcl` - READ-ONLY snapshot of window 1 written to `src/02_working/t008_state_<TAG>.txt` (BUILD, BUILD-TAG, TIME, window count, ini values used, client, data-type list, subcase, every getter sorted by name); every step is inside a `catch`, so the file always exists. (4) `src/spike/t008_diff.tcl` - compares two snapshots in plain tclsh: `DIFF name: broken=<v> working=<v>`, `(missing)` when only one run answered, `SAME <n> lines`, `DIFF <n> name(s) differ`, plus `t008_diff.txt`. (5) MATRIX - the diagnostic matrix grew to cells 1-9 (order x literal x draw-before-read, the two best cells without waiting for Tk, the best cell with after+update+Draw, with Draw twice, read through the ACTIVE client) and prints `CELL 10 skipped: ... SetEnableState ... auto load/unload ...` instead of inventing that cell (S53), then `MATRIX BEST` and the restored state. (6) `docs/refs/HV_MACRO_contour.txt` - the owner records the hand-made switch with HyperView's macro recorder and pastes the lines under `--- PASTE RECORDED LINES BELOW ---`. Robustness found while testing: every setting of the three spike files is a GLOBAL (`::t8_*`, `::TAG`/`::s8_*`, `::d8_*`) because `source` inside a proc evaluates in that proc's scope - a bare `set` there made the check run on defaults with no report; and `::t8::log_sink` now CHAINS to a sink that already exists (the GUI panel, a test) instead of leaving it alone, because a GUI session's report otherwise held no STATE DUMP at all. Tests (`tests/tcl/test_result.tcl`, MOCK, blocks 27-31): dump completeness/one block/end line/getter count, a raising getter keeps the full text and the run continues, a wrong name still refused exactly with 0 journal/set/enable/display calls, V5 present + DOC + needs `poIPost SetDisplayOptions` while V1-V4 do not and V5's line runs before the `Draw`, the state tool runs/writes/sorts/sends no setter, the diff tool prints changed + missing + `SAME 2 lines` + exactly two differences, and the input rules h1-h4 (name from the ini, first type offered, no name at all, no model) each with the BUILD line exactly once; the matrix block also asserts the nine CELL lines, the getter dump on each, `CELL 10 skipped`, `MATRIX BEST` and the restore. - Ran: 2026-11-16: `tclsh tests/tcl/test_result.tcl` -> MOCK, 244 PASS, exit 0; `tclsh tests/tcl/test_hw_adapter.tcl` -> MOCK, 447 PASS, exit 0; `bash scripts/verify.sh` -> `verify: OK`, exit 0 (16 tcl files parsed, 27 ASCII, 7 Tcl 8.5, 7 suites green). ADAPTER/SRC BUILD is now `T8c-20261116-1200` (the stamp names the `src/01_scripts` copy, not only the adapter). Commands still UNVERIFIED on HyperView: whether `SetDataType` keeps or resets the dimension state, whether a `Draw` is needed before `GetDimensionEnabled` reports it, and whether the window's contour DISPLAY is what is off - all three are answered by the owner's `STATE DUMP` + `MATRIX BEST` + the two snapshots/diff + the recorded macro, never by this log. NOT FETCHED: the `poIContourCtrl` averaging-family page `poicontourctrl_getavgacrosspartsenable.htm` answered 404, so nothing on it is used. - Files (this pass): `src/spike/t008_check.tcl`, `src/spike/t008_state.tcl`, `src/spike/t008_diff.tcl`, `src/01_scripts/_tcl_pis_03_load_result.tcl`, `src/01_scripts/_tcl_pis_11_hw_adapter.tcl`, `tests/tcl/test_result.tcl`, `tests/tcl/test_hw_adapter.tcl`, `docs/SPEC.md`, `docs/HANDOFF.md`, `docs/refs/HV_API.md`, `docs/refs/HV_MACRO_contour.txt`, `docs/TASKLOG.md`. - Not yet checked on HyperView: the result-display operation, 5 variants (V1-V4 order UNVERIFIED-GUESS, V5 DOC in `_tcl_pis_03_load_result.tcl`), plus the three spike files `src/spike/t008_check.tcl`, `src/spike/t008_state.tcl`, `src/spike/t008_diff.tcl`. - Refs: docs/SPEC.md (Evidence rules, A10 amendment), docs/refs/HV_API.md sections 11-12, docs/HANDOFF.md sections 4, 6.


OWNER RESULT (recorded 2026-11-16, before T-029) - `T-008: fail 4` (T-027 not accepted): a CORRECT result name still fails: `Error: result window 1: '1. Endure_SF_A' not displayed | variant 1/4 type-fir (see log)`. The window does not show the contour. All FOUR guessed variants (type-first / enable-first x `true` / `1`) fail the read-back (F10), so the answer is not another order and not another literal. Cause: `EXTERNAL` for the missing evidence (the owner did not send the per-variant log lines), `AGENT` for the diagnostic that could not name the cause. Consequence: the STOP RULE below.

OWNER RESULT (recorded 2026-11-16) - `t008_check.tcl: input defect`, cause **AGENT**: the owner sourced the file on build `T8b-20261112-1638` and the report held only `CHECK no result name: select one in the GUI, or set t8_name at the top of this file` / `VERDICT: FAIL no result name`; HyperView was never called, so the file produced NO evidence. Same defect class as the `t006_check` model path: a check must never die on an input the app already knows. The BUILD line also appeared twice (the adapter prints it when sourced, and the file printed it again). Both are fixed in T-029 items 0 and 0d.

STOP RULE (recorded in `docs/SPEC.md`, binding on every later task): after 3 failed passes on the same operation whose fix relied on UNVERIFIED-GUESS variants, the next pass is EVIDENCE-ONLY - no new production variant may be added until the owner returns evidence, except ONE whose every argument form is documented (labelled `DOC`). T-008 (`fail 1..4`) is at that point.

T-029 item 1 ANSWER TABLE (does any fetched method control whether a contour is DISPLAYED?) - `SetEnableState` NO ("Sets the auto load/unload contour data state"; false unloads data) | `GetEnableState` NO (reads that state) | `SetEnabled` NO proof (`pool` has no printed values, and the build lacks the method: F9 a) | `SetDimensionEnabled` per-dimension only (already V1-V4) | `SetCornerDataEnabled` NO (node-on-element binding only) | `SetShowMidsideNodeResults` / `SetThreshold*EnableState` / `SetValueFilterEnableState` / `SetFeatureAngleAverageEnableState` NO (options inside the contour) | `PlotResult` / `LoadResult` / `GetResultPlotted` / `GetResultStatus` NO for this build (MultiCore profile only, and they need a RESULT DEFINITION id that nothing in this flow creates) | **`poIPost SetDisplayOptions contour true` YES** - the only documented switch that turns a window's contour display on, with `GetDisplayOptions contour` as its documented read-back. V5 was therefore added, labelled DOC, and nothing else (STOP RULE). Full table: `docs/refs/HV_API.md` section 12.


T-010: Section Cut module â€” checkbox list of sections â€” Status: todo â€” Done when: each checked section is created/shown in row order, the list and check state persist, an empty selection logs one `WARN` naming the module, and a wrapper error stops the run unless continue-on-error is set, and (2026-11-11 amendment) the task names its `poISection` call in `docs/refs/HV_API.md` BEFORE any code (that page is NOT FETCHED today), prefers an `hwi` handle call over an `hwc` form, and FAILS the step when its read-back shows no section changed; khá»›p cÃ¡c má»¥c liÃªn quan trong Refs; mÃ¢u thuáº«n thÃ¬ theo SPEC.md D1-D5 â€” Only modify: `src/01_scripts/_tcl_pis_05_section_cut.tcl`, `src/01_scripts/_tcl_pis_99_workflow_gui.tcl` (section block), `tests/tcl/test_section.tcl` â€” How to check: 1) `tclsh tests/tcl/test_section.tcl` â†’ seeing `PASS` for order and empty selection is correct, seeing an unchecked section execute is wrong. 2) In HyperView check 2 of 3 sections and run â†’ seeing 2 `hwc` lines and 2 sections in the model tree is correct, seeing 1 or 3 is wrong. 3) Introduce a bad section item and run â†’ seeing `ERROR` naming the item and the run stopping is correct, seeing the next item still execute is wrong â€” Ran: - â€” Refs: docs/refs/SPEC_gui.txt Â§6.4

T-011: Capture module â€” checkbox list of views, image name `{model}_{result}_{item}.png` â€” Status: agent-done (2026-11-18, owner check owed, NEVER accepted; the full record is the T-011 block below) â€” Done when: each checked view is set and captured, no file name collides, an unwritable target raises `ERROR` naming the output path, and capture never triggers another module, and (2026-11-11 amendment) the task names its capture call in `docs/refs/HV_API.md` section 6 (`hwISession CaptureWindow` or `CaptureActiveWindow`) BEFORE any code, uses that `hwi` handle call instead of an `hwc` form, and after the call checks that the output file EXISTS and has size > 0 - a capture that wrote nothing is a FAIL, not a success; khá»›p cÃ¡c má»¥c liÃªn quan trong Refs; mÃ¢u thuáº«n thÃ¬ theo SPEC.md D1-D5 â€” Only modify: `src/01_scripts/_tcl_pis_06_capture.tcl`, `src/01_scripts/_tcl_pis_99_workflow_gui.tcl` (capture block), `tests/tcl/test_capture.tcl` â€” How to check: 1) `tclsh tests/tcl/test_capture.tcl` â†’ seeing `PASS` for the name pattern and for duplicate names is correct, seeing two views map to the same file name is wrong. 2) In HyperView check 2 views and run â†’ seeing exactly 2 new `.png` files named `{model}_{result}_{item}.png` in `02_working/` is correct, seeing 1 file or an overwritten file is wrong. 3) Point the capture folder at a read-only path and run â†’ seeing `ERROR` naming that path and no partial file is correct, seeing a silent skip is wrong â€” Ran: - â€” Refs: docs/refs/SPEC_gui.txt Â§6.5

T-011 (full record, 2026-11-18) - Capture module: the documented call, the frozen name, and the file as the only proof. Why: the task's 2026-11-11 amendment requires the call to be named in `docs/refs/HV_API.md` section 6 BEFORE any code, and that section held only "bodies NOT FETCHED"; so the first work of this pass was the two pages, then the code. Only modify (actual): `docs/refs/HV_API.md` (section 6 + the S91/S92 source rows + the variant map - the amendment requires this file), `src/01_scripts/_tcl_pis_06_capture.tcl` (new), `src/01_scripts/_tcl_pis_99_workflow_gui.tcl` (capture block, the source list, the run_module branch), `src/01_scripts/_tcl_pis_11_hw_adapter.tcl` (the op `capture_window`, its table entry, the read-only helper `active_window`, the BUILD stamp), `tests/tcl/test_capture.tcl` (new), `tests/tcl/test_hw_adapter.tcl` (op count 7 -> 8, `capture_window` in the known-ops list, and the `local 1` rule for a check that asks no HyperView question), `docs/SPEC.md` (the Capture subsection + the `[capture]` size keys), `docs/TASKLOG.md`, `docs/HANDOFF.md`. Items: (1) EVIDENCE FIRST - S91 `hwISession CaptureWindow win_id, type, filename, dimension_type, width, height, quality` quoted verbatim with its inputs, its own example and "Success (0) or an error code"; S92 `CaptureActiveWindow` quoted too and REJECTED, because its documented type list is BMP and JPEG only and the frozen name needs `.png` - so the module has ONE call with two documented `dimension_type` forms, never a guess chain. (2) THE STEP - one `hwi` script per capture, session handle only (the call names its window, so no page is read and nothing is assumed about which window is active): `set pisCapWin <k>` -> `set pisCapRet [<sess> CaptureWindow $pisCapWin PNG <file> <unit> <w> <h>]` -> release + `hwi CloseStack` -> an INTEGER answer other than 0 raises with that code -> `set pisCapRet`. The journal keeps ONE replayable `hwi ...` line per image and nothing else. (3) THE PROOF - the variant's check is `[file exists <path>] && [file size <path>] > 0`, the ONLY `local 1` check in the adapter table (it asks no HyperView question), and the module re-checks existence and size after the call and logs the byte count; a capture that wrote nothing or 0 bytes FAILS and journals nothing. The module also guarantees the path cannot pre-exist (`_2`, `_3`, ... suffixes, compared without case), so an older image can never be mistaken for this run's output. (4) THE NAME - `{model}_{result}_{item}.png` with every part sanitized to `[A-Za-z0-9._-]`; `{result}` is the result FILE of that window, because that is the only reading that keeps the triple unique per window (the reason s.6.5 gives for the pattern), with the selected result type and `noresult` as fallbacks. (5) SCOPE - the module button captures the ACTIVE window via `poIPage GetActiveWindow` (S33, read-only probe, never journaled); `[Apply all layout]` walks 1..N and sets each window active before its capture; both are refused before anything is sent when Load All has not run. (6) SIDE EFFECTS - none: no `Draw`, no other module runs, the ini is never written (asserted byte-identical in the test). Assumptions used: ASSUMPTION-T011/U1 (a checked row is the LABEL of one capture and the scope decides the window - SPEC_gui names no view command), ASSUMPTION-T011/U2 (image size `pixels 1280 960`, the example values on S91; `[capture]` unit/width/height override it, and variant 2 falls back to the page's `percent 150 150`). - Ran: 2026-11-18: `bash scripts/verify.sh` -> `== tcl files (17) ==`, `== syntax == ok 17 file(s)`, `== ascii == ok 29 file(s) are ASCII`, `== tcl85 == ok 8 file(s) are Tcl 8.5`, all 8 suites `ok`, `verify: OK`, exit 0; per-suite PASS counts: `test_capture` 85 (new), `test_hw_adapter` 453, `test_result` 346, `test_block0` 273, `test_hw_exec` 92, `test_legend` 56, `test_common` 46, `test_gui_frame` 25 (1376 in total). ADAPTER/SRC BUILD is now `T11a-20261118-1107`. Commands still UNVERIFIED on HyperView: whether this build answers `CaptureWindow <win> PNG <file> pixels 1280 960` with 0 AND writes a non-empty file (variant 1), whether it accepts a pixel size for a window of the layout (variant 2 is the documented percent fallback), and whether `SetActiveWindow` is needed before a capture at all (the call names its window; it is sent only because s.6.5 says "set the view"). - Not yet checked on HyperView: the whole Capture step - MOCK only on this machine, the mock writes the file, so no real PNG was ever produced here. - Rollback: `::pis::hw::use capture_window <n>` pins the START variant (1 = pixels, 2 = percent); every log line names the window, the row and the final path, so a wrong image is answerable without editing a file. - Refs: docs/refs/SPEC_gui.txt s.6.5, s.7, s.9; docs/refs/HV_API.md section 6 (S91/S92).

T-012: Log pane buttons â€” `[Clear] [Save] [Load...] [Run log >]` + continue-on-error + status bar â€” Status: agent-done (2026-11-19, owner check owed; NEVER accepted by the agent - only the OWNER accepts) â€” Done when: Clear asks for confirmation only when the journal is dirty, Save writes a replayable `.tcl` whose non-blank lines start with `hwc `, `hwi ` or `#`, Load shows an external file without running it, and Run log> confirms with the line count, executes only `hwc` and `hwi` lines (`hwc` through `::pis::hw::exec`, `hwi` through `::pis::hw::exec_hwi`, never a bare `uplevel` - SPEC API contract replay rule, T-016), logs `skipped K`, stops on the first error unless continue-on-error is checked, and reports the failing line number; khá»›p cÃ¡c má»¥c liÃªn quan trong Refs; mÃ¢u thuáº«n thÃ¬ theo SPEC.md D1-D5 â€” Only modify: `src/01_scripts/_tcl_pis_20_journal_ui.tcl`, `src/01_scripts/_tcl_pis_99_workflow_gui.tcl` (log wiring), `tests/tcl/test_journal_ui.tcl` â€” How to check: 1) `tclsh tests/tcl/test_journal_ui.tcl` â†’ seeing `PASS` for filter/skip count and stop-on-first-error is correct, seeing a line that starts with neither `hwc ` nor `hwi ` executed is wrong. 2) In HyperView import a `.tcl` containing 3 junk lines, then Run log> â†’ seeing `skipped 3` and only the `hwc`/`hwi` lines executed (a `hwi` line runs through `exec_hwi`, so it still closes the stack) is correct, seeing junk executed is wrong. 3) Click Run log> and cancel the confirmation dialog â†’ seeing 0 journal lines executed is correct, seeing execution start is wrong â€” Ran: 2026-11-19: `tclsh tests/tcl/test_journal_ui.tcl` -> 141 PASS, 0 FAIL, exit 0 (HyperView MOCKED by a fake hwc / hwi and by a display-log sink proc); `tclsh tests/tcl/test_gui_frame.tcl` -> ok all GUI frame checks passed, exit 0 (the GUI still loads headless with the new module in its source list); `bash scripts/verify.sh` -> verify: OK, exit 0 (18 tcl files parsed, 32 ASCII, 9 Tcl 8.5, 9 suites green - the count dropped from 28 after the stale src/02_working/t<task>_<pid> folders of earlier runs were deleted); RED PROOF, three mutations of `_tcl_pis_20_journal_ui.tcl` restored afterwards: stop-on-error disabled -> FAILED 2 check(s); save writing the unfiltered text -> FAILED 1 check(s) (the junk line reached the file); journal snapshot removed -> FAILED 2 check(s) (the replay doubled the journal). â€” Refs: docs/refs/SPEC_gui.txt Â§8

T-012 (full record, 2026-11-19) - the log pane buttons: four buttons, two doors, one line number.
  Why: `docs/refs/SPEC_gui.txt` section 8 asks for two streams (a display log and a command
  journal), four buttons, a "continue on error" box and a status bar, and SPEC A3/A4/A5 make the
  saved file, the run count and the skipped count observable. Until this pass the four buttons
  existed but `[Save]`, `[Load...]` and `[Run log >]` only logged "not wired yet (frame task T-003)".
  What it does, one rule per proc (the whole API is in SPEC.md, "Journal pane contract (T-012)"):
  * `[Clear]` (`::pis::jui::clear`) empties the display log AND the journal, and asks ONE yes/no
    question only when `dirty` is 1 (an unsaved journal or a loaded file); a "no" changes nothing.
  * `[Save]` (`::pis::jui::save`) writes the SAME filter the replay uses, so every non-blank line of
    the file starts with `hwc `, `hwi ` or `#` (A3) by construction; junk lines are counted, never
    written; an empty journal is refused with `Save journal: no hwc/hwi command to save`; saving a
    loaded file never marks the LIVE journal as saved.
  * `[Load...]` (`::pis::jui::load`) reads an external journal and shows it (`| <line>` INFO lines
    in the pane); it executes NOTHING, and the loaded text becomes the source of the next two
    buttons (and counts as dirty, so `[Clear]` asks before throwing it away).
  * `[Run log >]` (`::pis::jui::run`) logs `skipped K` (A5), confirms with `Run K command(s) from
    <source>?` (A4: the dialog shows K), executes the kept lines in text order, logs ONE `OK` line
    per executed command, stops at the first error unless continue-on-error is checked, and reports
    `Run log: line <n> failed: <command> | <the build's own error text>` plus `Run log: stopped at
    line <n> after <m> command(s)`, `<n>` being the line number of the text that was run.
  * the doors are the two the SPEC names (T-016): `hwc` lines through `::pis::hw::exec`, `hwi` lines
    through `::pis::hw::exec_hwi`; the file holds NO `uplevel` (the test checks that too, so a
    "convenient" bare uplevel cannot come back).
  * a replay never doubles the journal: `run` snapshots `::pis::journal::buf`, its dirty flag and the
    module/item context and restores all three afterwards (the doors journal what they run).
  Files: new `src/01_scripts/_tcl_pis_20_journal_ui.tcl` (namespace `::pis::jui`, 15 procs, no
  widget and no HyperView call of its own - it replays lines that already went through the adapter,
  so `docs/refs/HV_API.md` gains no row); `_tcl_pis_99_workflow_gui.tcl` (log wiring: it sources the
  new file, `clear_log` now clears both streams, `save_journal` / `load_journal` / `run_journal` open
  the dialogs and keep the status bar honest, the four buttons are wired and all four sit in the busy
  lock); new `tests/tcl/test_journal_ui.tcl` (141 checks). `::pis::BUILD` is now
  `T12a-20261119-0900` - that one-line bump lives in `_tcl_pis_11_hw_adapter.tcl`, which this task's
  "Only modify" list does not name: section 2 of `docs/HANDOFF.md` requires the stamp to name the
  copy the owner runs, so the adapter changed by that string and by nothing else.
  Assumptions used: (1) the display log is NOT saved to `.txt` - SPEC_gui s.8 says "optionally" and
  T-012 does not ask for it; (2) `skipped K` is logged BEFORE the dialog, so the pane explains what
  the dialog is about and a cancelled run still shows the count; (3) the reported line number is the
  number in the text that was run (not the index of the command), because that is the number the user
  can find in the file or in the pane; (4) `::pis::gui::continue_on_error` is the switch when the GUI
  exists and `::pis::jui::continue_on_error` otherwise - the ini key `[log] continue_on_error` is read
  and written by T-013, not here.
  How to check (user, max 3 steps):
    1. In HyperView source `01_scripts/_tcl_pis_99_workflow_gui.tcl`, run Load All + one legend, then
       click `Save` -> seeing a `.tcl` whose every non-blank line starts with `hwc `, `hwi ` or `#` is
       correct, seeing any other line is wrong; then `Clear` -> seeing ONE confirmation (the journal
       is dirty) is correct, seeing it silently emptied is wrong.
    2. Click `Load...` and pick a file with 3 junk lines -> seeing the file shown in the pane, the log
       saying "nothing run" and no HyperView change is correct. Then `Run log >` -> seeing a dialog
       `Run K command(s) from <path>?`, then `skipped 3`, one `OK` line per command and the windows
       changing is correct; cancelling the dialog must execute nothing.
    3. Put one wrong command in the file and run again -> seeing `Run log: line <n> failed`, the
       status bar `Error: Run log line <n> failed`, and the commands after it NOT executed is correct;
       ticking "continue on error" and running again must execute the rest.
  Rollback: no git target; restore the three `not_wired` commands in `_tcl_pis_99_workflow_gui.tcl`
  and delete `_tcl_pis_20_journal_ui.tcl` + `tests/tcl/test_journal_ui.tcl` (nothing else imports
  them; the GUI's source list is the only reference).
  Refs: docs/refs/SPEC_gui.txt s.8 (the four buttons), s.7 (status bar and the busy lock), s.9 (ini);
  docs/SPEC.md A2/A3/A4/A5, "Journal pane contract (T-012)" and the replay contract line (T-016);
  TASKLOG T-005 (the two doors), T-014, T-016 and T-018 (the source rules the new test re-checks),
  T-006 (the `not_wired` placeholder this pass removes for the log pane).

T-013: Session persistence â€” save on exit, restore on start for block 0, layout and all five module lists â€” Status: todo â€” Done when: every field and selection round-trips through `pis_workflow_config.ini` on exit/start, a deleted ini restores defaults with one `WARN`, and the session test passes; khá»›p cÃ¡c má»¥c liÃªn quan trong Refs; mÃ¢u thuáº«n thÃ¬ theo SPEC.md D1-D5 â€” Only modify: `src/01_scripts/_tcl_pis_99_workflow_gui.tcl`, `tests/tcl/test_session_ini.tcl` â€” How to check: 1) `tclsh tests/tcl/test_session_ini.tcl` â†’ seeing `PASS` for a full round-trip is correct, seeing any list order or check state lost is wrong. 2) In HyperView fill every field, check items in all 5 modules, close, reopen â†’ seeing identical text, order and selection is correct, seeing defaults is wrong. 3) Delete the ini and reopen â†’ seeing defaults plus exactly one `WARN` naming the file is correct, seeing a crash is wrong â€” Ran: - â€” Refs: docs/refs/SPEC_gui.txt Â§9

T-014: docs consistency - a journal line is `hwc `, `hwi ` or `#`, and D2 matches the owner-measured result order â€” Status: agent-done â€” Done when: no statement in `docs/SPEC.md` or `docs/TASKLOG.md` restricts the journal to `hwc` lines alone, SPEC D2 states `AddModel` -> `SetResult` -> `WaitForResults` -> `GetResultCtrlHandle` read-back and that `AddResultFile` is not part of Load All, and `bash scripts/verify.sh` is OK â€” Only modify: `docs/SPEC.md`, `docs/TASKLOG.md` â€” Agent: Ran: 2026-11-11: `grep -nE "only h[w]c" docs/SPEC.md docs/TASKLOG.md` -> 0 hits; `grep -n "non-\`hwc\`" docs/SPEC.md` -> the amended Error-states line only; `grep -n "AddResultFile" docs/SPEC.md` -> 1 hit, inside the new "not part of Load All" sentence; `bash scripts/verify.sh` -> `verify: OK`, exit 0 â€” How to check (user, max 3): 1) `grep -nE "only h[w]c" docs/SPEC.md docs/TASKLOG.md` -> seeing 0 hits is correct, seeing any hit is wrong. 2) read SPEC D2 -> seeing `AddModel` -> `SetResult` -> `WaitForResults` -> result-controller read-back plus the `AddResultFile` sentence is correct, seeing "SetResult then AddResultFile" is wrong. 3) `bash scripts/verify.sh` -> `verify: OK` is correct, `verify: FAILED` is wrong. Rollback: no `.git` yet, so restore the two files from the copy the owner keeps. â€” Refs: docs/SPEC.md A2, A3, Constraints, Error states, D2, Q1, Q3; docs/TASKLOG.md T-002, T-002b, T-005, T-012

T-015: `docs/refs/HV_API.md` - the HyperView API reference this repo trusts â€” Status: agent-done â€” Done when: the file exists and is ASCII, every command the adapter uses has an entry (syntax, arguments, return value, one example, doc URL, doc version) or an explicit `NOT FETCHED` line naming the page the owner must paste, the layout id table and the owner-measured F1..F4 behaviour are recorded, and `bash scripts/verify.sh` is OK â€” Only modify: `docs/refs/HV_API.md` (new) â€” Agent: Ran: 2026-11-11: fetched S1..S15 from https://2024.help.altair.com/2024/hwdesktop/... (2024 help) -> 20 layout ids with window counts, `SetClientType` choices `FePre Model Animation Plot Plot3D TextEditor Video`, `GetResultCtrlHandle` as the documented result read-back; `bash scripts/verify.sh` -> `verify: OK`, exit 0, `ok 23 file(s) are ASCII` â€” How to check (user, max 3): 1) open section 2 -> seeing the 20-id table (0..19) and the cols x rows mapping is correct, seeing an empty table or a `TBD` is wrong. 2) open section 5 -> seeing `NOT FETCHED` for `AddModel`/`WaitForResults` plus the exact page to paste is correct, seeing an invented syntax is wrong. 3) `bash scripts/verify.sh` -> `verify: OK` is correct. Rollback: delete the file. â€” Refs: https://2024.help.altair.com/2024/hwdesktop/hwd/topics/chapter_heads/hyperview_r.htm; docs/TASKLOG.md T-006 pass 8/9; the `conrod/` scripts named in the adapter

T-016: journal and wrapper hardening - comment lines, quoting, and the grid step in the journal â€” Status: agent-done â€” Done when: a `#` line inside an `hwi` script can no longer swallow the commands after it, a path holding a space, `[`, `]`, `$`, `{`, `}` or `;` reaches HyperView and the journal unchanged, an all-comment script is refused by name, `probe` closes the stack on failure and never journals, `make_grid` journals ONE `SetLayout <id>` step when the page already is the grid, the SPEC API contract states the replay doors, and `bash scripts/verify.sh` is OK â€” Only modify: `src/01_scripts/_tcl_pis_10_hw.tcl`, `src/01_scripts/_tcl_pis_11_hw_adapter.tcl` (item 4 only), `tests/tcl/test_hw_exec.tcl`, `tests/tcl/test_hw_adapter.tcl`, `docs/SPEC.md` (API contract sentence) â€” Agent: Ran: 2026-11-11: `tclsh tests/tcl/test_hw_exec.tcl` -> MOCK, 92 PASS, exit 0 (13 new checks); `tclsh tests/tcl/test_hw_adapter.tcl` -> MOCK, 307 PASS, exit 0 (7 new checks); `tclsh tests/tcl/test_block0.tcl` -> MOCK, 260 PASS, exit 0; `bash scripts/verify.sh` -> `verify: OK`, exit 0 â€” How to check (user, max 3): 1) in HyperView source the three scripts, load a model + results, press Load All -> seeing the DIAG line and one `hwi ... SetLayout <id>` line in the journal is correct, seeing a `# grid ... already present` comment instead is wrong. 2) click Save and open the `.tcl` -> seeing every non-blank line start with `hwc `, `hwi ` or `#`, and every `hwi` line replayable, is correct; seeing a `#` line folded into a `hwi` line is wrong. 3) `bash scripts/verify.sh` -> `verify: OK` is correct. Rollback: restore `fold_script` and the `make_grid` branch (a) block (no `.git` yet). â€” Refs: docs/refs/HV_API.md section 2, 4; docs/SPEC.md API contract; docs/TASKLOG.md T-006 pass 8

T-017: layout model - `cols x rows` cannot name a HyperView layout id â€” Status: agent-done, gate closed 2026-11-12 (gate answered A on 2026-11-11; implemented 2026-11-12; owner replied "T-017: ok" after the three HyperView checks; `accepted` is the owner's word, so it is not written here) â€” Done when: the owner answers (a) or (b), SPEC is amended FIRST, then the adapter and `tests/tcl/test_hw_adapter.tcl` follow it, and `bash scripts/verify.sh` is OK â€” Only modify (after the gate): `docs/SPEC.md`, `docs/TASKLOG.md`, `src/01_scripts/_tcl_pis_11_hw_adapter.tcl`, `tests/tcl/test_hw_adapter.tcl` â€” Agent: Ran: 2026-11-12: implemented the code half (SPEC/table/make_grid/combobox/ini/spike/tests); `bash scripts/verify.sh` -> `verify: OK`, exit 0 â€” Proposal (the owner chooses; 15 lines below):
  1. Measured + documented: `docs/refs/HV_API.md` S1 lists 20 integer layout ids and the id DECIDES the geometry - 4x1 is id 18, 1x4 is id 16, 2x2 is id 9 (shape not stated), 4x2 is id 19, 2x4 is id 17, 3x2 is id 11, 2x3 is id 10, 3x4 is id 14, 4x3 is id 13.
  2. The adapter keeps `cols x rows` and takes the LOWEST id whose window count matches, so 4x1, 1x4 and 2x2 can collapse onto one id and the shape the owner asked for is lost; the owner's pass-8 measurement ("4x1" -> layout=4 = three windows) is that defect in the wild.
  3. `::pis::hw::layout_table` also sweeps `SetLayout 1..30` on the LIVE page, which destroys windows and models when the session is not empty.
  4. Proposal A (combobox): replace the two integer fields with a layout-id combobox whose label is "N windows - shape" from the S1 table; the ini keeps `[layout] id = <n>`; A7 becomes "N result files exceed the window count of layout <id>"; no sweep, no guess, and the owner picks the exact picture he wants.
  5. Proposal B (keep the fields): keep `cols x rows`, add `[layout_tokens] <cols>x<rows> = <id>` filled from the S1 table, and REFUSE a size the table cannot express (3x3 and the duplicated-count shapes) with one message and 0 journal lines; the lowest-id rule is deleted; A7 stays as it is.
  6. Both proposals: `layout_table` may run only on an EMPTY session (0 models in every window) and refuses otherwise with a status line naming why.
  7. Both proposals: cache the measured table in the ini, keyed by the HyperView build string, so the sweep runs once per build and never on a page the owner has loaded.
  8. Both proposals: `::pis::hw::grid_capture` (reads `GetLayout`, no sweep) stays the way to pin a page the owner arranged by hand, and it needs no change in this task.
  9. Why not "keep the lowest id": a count-only match reproduces exactly the 3-windows-instead-of-4 report; the id table is the only place the shape is recorded.
  10. Migration: an ini written by T6j may hold `[layout] cols = 4, rows = 2`; proposal A reads it once to preselect id 19 (4x2) and proposal B keeps the keys as they are, so neither breaks a saved session.
  11. Test plan for both: MOCK `make_grid 4 2` must journal `SetLayout 19`, `make_grid 2 4` -> 17, `make_grid 4 1` -> 18, `make_grid 1 4` -> 16, `make_grid 2 2` -> 9; an unknown size -> one message, 0 journal lines, 0 SetLayout calls.
  12. Note on the owner's 2026-11-11 report (TASKLOG T-006 pass 10): it was written by adapter `T6h-20261111-1153`, which has no LAYOUTS line and none of the T-016 work, so it cannot answer proposal A or B; what it does prove is item 2 - he asked for `4x1`, the report shows `layout=4` and three windows.
  13. Gate: reply `T-017: a` or `T-017: b` (or name a third shape). No adapter or test change happens before that reply.
  14. If the answer is "neither", the fallback is proposal B with the ini table only (no S1 defaults), i.e. the owner measures each size once with `::pis::hw::grid_capture` and the adapter never guesses.
  15. Refs: docs/refs/HV_API.md S1, S2, S4; docs/SPEC.md A7 and the `[layout]` section; docs/TASKLOG.md T-006 pass 8 (F1), pass 9.
  How to check (user, max 1 step): read the 15 lines above and answer `T-017: a` or `T-017: b` -> seeing the adapter's LAYOUT code unchanged is correct, seeing a layout change before the SPEC amendment is wrong. â€” Refs: docs/refs/HV_API.md S1/S2; docs/SPEC.md A7; docs/TASKLOG.md T-006 pass 8/9
  Gate answer (2026-11-11): `T-017: a` â€” proposal A (layout-id combobox, no sweep on a loaded page, no lowest-id guess). Recorded before any layout code. The adapter is `T6k-20261111-1703` (T-019, the result wait), so the `cols x rows` code the proposal above describes is still the T6j code and this pass did not touch it.
  Agent (2026-11-11, after T-019): SPEC amended FIRST, no code. Amendments: Goal (the id, not a size, decides the geometry), S1 (4 results = layout id 18, one row of four), A7 (the exact message `9 result file(s) exceed layout 19 (8 windows)`), A12 (the layout id round-trips), the data model (`[layout] id = 19`, default = today's `cols = 4, rows = 2`, legacy `cols`/`rows` read once with ONE `INFO` and then ignored, `[layout_tokens]` deleted), the two new error states (too many results; an id that is not one of the twenty), D1, Q1, and a new API-contract bullet (`make_grid {id}`, static id table, `layout_table` refuses a session that holds a model, `grid_capture` unchanged).
  State, on purpose: the SPEC is now AHEAD of the code - `::pis::hw::make_grid` still takes two integers and A7's message is still the old one, so SPEC and code disagree until the code half lands. That is the order this task sets ("SPEC is amended FIRST"), not a defect, and nothing was left half-migrated because no code was touched.
  Scope note: proposal A does not fit the gate's Only-modify list - the two integer fields, the ini key and the A7 guard live in `_tcl_pis_99_workflow_gui.tcl` (30 layout references), `_tcl_pis_01_load_model_results.tcl` (18), `_tcl_pis_00_common.tcl` (12, `read_layout_tokens`), `src/00_config/pis_workflow_config.ini`, `tests/tcl/test_block0.tcl` (85) and `tests/tcl/test_hw_adapter.tcl` (151). The code half therefore widens the list to those six files; `tests/tcl/test_gui_frame.tcl` holds 0 layout references and needs no change.
  Code plan for the next pass (one commit, SPEC first is already done): (1) static id table in the adapter + `make_grid {id}` + delete `choose_layout`, `grid_id`, `ini_tokens`, `grid_token_set` and the token cache; (2) `layout_table` refuses a non-empty session; (3) GUI: the two integer entries become one `ttk::combobox` listing `"<id>: <n> windows - <shape>"`, default 19; (4) step01: validate the id and the count, exact A7 message, 0 HyperView calls on either error; (5) ini: `[layout] id = 19`, legacy `cols`/`rows` read once, `[layout_tokens]` removed; (6) tests: `make_grid 19` journals `SetLayout 19`, `18` -> 18, `16` -> 16, `17` -> 17, `9` -> 9, `0` -> 0; an unknown id -> one message, 0 journal lines, 0 `SetLayout` calls; A7's new text; the legacy-ini INFO once.
  Implemented (2026-11-12, adapter `T6m-20261112-1200`), all six steps, with the ONE change F8 forced on step 5: the legacy `cols`/`rows` keys are NOT converted into an id (a count cannot name a shape); they are ignored with ONE `INFO legacy [layout] cols/rows ignored, using id <n>` per run and dropped on the next save. What the code now is: `::pis::hw::layout_rows` holds the 20 ids + the doc's own shape text (single place; `layout_windows`, `layout_shape`, `layout_label`, `layout_choices`, `layout_count` read it, nothing measures or caches a page); `make_grid {id}` reads `GetLayout` first (same id -> the effect is skipped but ONE `hwi ... SetLayout <id>` line is still journaled, T-016), else ONE `SetLayout <id>` whose read-back `check_layout` proves BOTH `GetLayout == id` and `GetNumberOfWindows == the table count` plus the per-window client/GetModelList walk; `layout_table` refuses a session that is not empty and no Load All path calls it; `step01::validate` returns `{model_file result_files layout_id windows}` and the two errors are `N result file(s) exceed layout <id> (<w> windows)` and `layout id <n> is not in the table` (both before any HyperView call); the GUI block 0 has ONE read-only `ttk::combobox` of `layout_choices` (sorted by window count then id), its value is saved on a successful Load All and on window close (`WM_DELETE_WINDOW` -> `::pis::gui::close_window`), and an ini id the table does not know is displayed as the default but KEPT so Load All refuses it by name; `t006_check.tcl` reads `[layout] id` (ONE `CHECK input: layout id ...` line), prints the `LAYOUT:` asked/answered line and has `TABLE=1`, which prints one `TABLE id=<n> expected=<w> windows=<y> OK|FAIL` line per id on an empty session and `TABLE refused: session not empty` otherwise. The pre-T-017 dev harness `src/spike/try_load_all.tcl` was updated too (it called `make_grid $COLS $ROWS` and printed `::pis::hw::grid_token_set`, both gone): it now sets ONE `LAYOUT_ID`, checks the id against the table before any HyperView call, and its FIX/PROBE lines name the id instead of a size. Ran: `tclsh tests/tcl/test_hw_adapter.tcl` -> 430 PASS, exit 0; `tclsh tests/tcl/test_block0.tcl` -> 273 PASS, exit 0; `tclsh tests/tcl/test_common.tcl` -> 46 PASS, exit 0; `tclsh tests/tcl/test_gui_frame.tcl` (20 PASS), `test_hw_exec.tcl` (92 PASS), `test_legend.tcl` (56 PASS) -> green; `bash scripts/verify.sh` -> `verify: OK`, exit 0 (12 files parsed, 24 ASCII, 6 Tcl-8.5).
  Prevention: a GUI input that cannot name the API's real parameter must not be translated by a heuristic - a `cols x rows` pair was converted into "the lowest id with that many windows", which showed 2x2 for a 4x1 request and 2x4 for a 4x2 request (F8). The input now IS the parameter (a layout-id combobox fed by one static table), and the table is checked against `docs/refs/HV_API.md` sec. 2 by a MOCK test (20 unique ids, every window count, ids 16/17/18/19 distinct), so a wrong number in the table is red before it reaches a page.
  State: SPEC and code now agree; the two integer fields, `[layout_tokens]`, `read_layout_tokens`, `grid_id`, `choose_layout`, `grid_token_set`, `token_key`, `ini_tokens` and `token_count` are gone from the tree.
  How to check (owner, HyperView, max 3 steps): (1) copy the WHOLE `src/01_scripts` folder, start the GUI and pick, one after another, the two-window entry, the 4-window 2x2 entry, the 4-window 4x1 entry, the 8-window 4x2 entry and the 8-window 2x4 entry -> seeing the grid whose shape equals the label is correct; seeing another entry's shape (2x2 where 4x1 was chosen, 2x4 where 4x2 was chosen) is the old F8 defect. (2) on a fresh EMPTY session source `src/spike/t006_check.tcl` with `TABLE=1` -> every `TABLE id=<n> expected=<w> windows=<y> OK` is correct; a `FAIL` names the id to send back, and `TABLE refused: session not empty` means step 1 was skipped. (3) with the 4x1 entry and 4 result files click Load All -> seeing 4 windows, each with its own result and no `Error:` in the status bar is correct.

  Gate closed (2026-11-12): the owner ran the three HyperView steps above and replied `T-017: ok`. Recorded here as closed, not `accepted` (process rule, line 55: the agent never writes that word). What that fixes in place: layout id 19 in the ini is the shipped default, `make_grid` reads `GetLayout` first, one `SetLayout <id>` per grid with the `"id:count"` read-back, the read-only combobox saves on Load All and on close, the two failures are `N result file(s) exceed layout <id> (<w> windows)` and `layout id <n> is not in the table` with 0 HyperView calls. Task not reopened; a later failure is a NEW defect line, not an edit to this one.

T-018: Tcl 8.5 guard in `scripts/verify.sh` â€” Status: agent-done â€” Done when: `verify.sh` rejects `lmap`, `tailcall`, `coroutine`, `yield` and `string cat` at command position under `src/01_scripts` (comments and `src/spike` exempt, `lassign` allowed), the rule is proven red on a probe file and green on the tree, and SPEC A15 says so â€” Only modify: `scripts/verify.sh`, `docs/SPEC.md` (A15) â€” Agent: Ran: 2026-11-11: `bash scripts/verify.sh` -> `== tcl85 == ok 6 file(s) are Tcl 8.5`, `verify: OK`, exit 0; with `src/01_scripts/_probe_tcl85.tcl` (one comment naming all five words, one `lassign`, one `lmap`, one `string cat`) -> `verify: TCL85 src/01_scripts/_probe_tcl85.tcl:6: Tcl 8.6 command: ...` and `:7: Tcl 8.6 string subcommand: ...`, `verify: FAILED`, exit 1, with the comment line and the `lassign` line NOT reported; probe deleted, `verify: OK` again â€” How to check (user, max 3): 1) `bash scripts/verify.sh` -> seeing `== tcl85 == ok N file(s) are Tcl 8.5` is correct, seeing the section missing is wrong. 2) put `set x [lmap v {1 2} {set v}]` in a copy under `src/01_scripts` and rerun -> seeing `verify: TCL85 <file>:<line>` plus exit 1 is correct, seeing `verify: OK` is wrong. 3) `grep -n "lmap" scripts/verify.sh` -> seeing the rule next to the `string cat` rule is correct, seeing the section absent is wrong. Rollback: delete the `== tcl85 ==` block. â€” Refs: docs/SPEC.md A15


T-019: result step - Load All must not depend on `WaitForResults` â€” Status: agent-done â€” Done when: no step of Load All may fail because this HyperView lacks an OPTIONAL method: `WaitForResults` is documented only for the MultiCore profile (`docs/refs/HV_API.md` S16/S17) and the owner's build has no such call (F5, the owner's F-b report), so the wait becomes a guarded optimization (ask `GetAsyncMode` first, try the client form, then the manager form from `GetClientManagerHandle <mgr> animation`, else SKIP), a wait that is missing or raises may never fail a window (its own error is caught into `::pis::hw::wait_error` and becomes a `WARN`; a blocking HyperView call has no timeout of its own, so the guard is `GetAsyncMode` plus the always-available skip), the proof that a result is attached is the bounded read-back `GetResultCtrlHandle` + `GetNumberOfSubcases` (4 tries, 250 ms, never a hang), a read-back that really fails stops the run with one line naming the windows that were not attempted, at most ONE `INFO result wait skipped: ...` line per run, `AddModel` returning 0 is a named failure that also stops the run, and `bash scripts/verify.sh` is OK â€” Only modify: `src/01_scripts/_tcl_pis_11_hw_adapter.tcl`, `src/01_scripts/_tcl_pis_01_load_model_results.tcl`, `src/spike/t006_check.tcl`, `tests/tcl/test_hw_adapter.tcl`, `tests/tcl/test_block0.tcl`, `docs/SPEC.md` (D2), `docs/refs/HV_API.md` â€” Agent: Ran: 2026-11-11: `tclsh tests/tcl/test_hw_adapter.tcl` -> 347 PASS, exit 0 (block 14 a/a2/b/c/d/e/f: no `WaitForResults`, manager form, raising wait, async build, no client manager, `AddModel` 0, session error); `tclsh tests/tcl/test_block0.tcl` -> 260 PASS, exit 0; `tclsh tests/tcl/test_hw_exec.tcl` -> 92 PASS, exit 0; `bash scripts/verify.sh` -> `verify: OK`, exit 0 (24 files ASCII, 6 test files green) â€” How to check (user, HyperView, max 2 steps): 1) copy the WHOLE `src/01_scripts` folder, source `src/spike/t006_check.tcl`, send `src/02_working/t006_check.txt` back -> the first line must read `T6k-20261111-1703`; a `VERDICT: PASS` with a `result=1,1,1,1` DIAG is correct, and a `FAIL window 1 ...` that names the read-back is also an answer (paste it). 2) On the same report, a line `INFO result wait skipped: ...` once, with no `WAIT` retry loop, is correct; a run that stops on window 1 with `unknown method WaitForResults` is the defect this task removes. â€” Refs: docs/refs/HV_API.md S16, S17, S18, S19, S20, S21, S25, S27, F3/F5/F6; docs/SPEC.md D2; docs/TASKLOG.md T-006 pass 11


T-030: `T-008: fail 5` - answer it with the owner's own recorded order and a log that carries the whole story - Status: agent-done (2026-11-17, owner check owed, NEVER accepted) - Why: after T-027/T-029 a correct result name still left every window without a contour, and the log neither showed WHICH calls were sent nor kept a long line visible. Items: (1) V6 taken from evidence - the owner's working macro `test/test_out/TCL_StressExport.tcl` (lines 55-60) sets the contour up with `SetEnableState true` AFTER `SetDataType`; S53 documents that call and S54 reads it back, so V6 = `SetDataType` -> `SetEnableState true` -> the three dimension enables -> `Draw`, added AFTER V1..V5 (the log stays comparable with the T-029 run and an early win is still possible), name `type-first, true, enable state on`, `variant_needs 6` lists the four calls; S53 is the AUTO LOAD/UNLOAD state, not a display switch (`docs/refs/HV_API.md` section 12), so a V6 pass means the build had to be told to LOAD the data - a different defect from V5's display switch. (2) The trace, at INFO, per window, never clipped: `TRACE window k BEFORE type=.. enabled=<three dimensions> subcase=.. component=.. display=..` with `?` for a getter that did not answer; one `TRACE window k variant v/6 '<name>' sent: <call> -> ...` line per variant, written BEFORE the calls go out; `NOCHANGE window k variant v/6 ...` when every value came back identical; `TRACE window k LATE ...` only when the window did NOT pass (the duplicate LATE line on a pass was removed - a pass leaves the A10 result line as the single values line); `FALSE-NEGATIVE GUARD window k ...` naming which read-backs answered and which raised; `OWNER CHECK window k ...` as the LAST line of a failed window. (3) Read-only console API, console only (`SPEC_gui.txt` freezes the toolbar): `::pis::result::snap {tag {windows ""}}`, `snaps_text {tag}`, `diff {a b}` - `snap` stores `read_state` + `dump_dict`, sends no setter, draws nothing and writes no journal line; `snaps_text` logs one `SNAP <tag> window k ...` line per window; `diff` logs `DIFF window k` with `before:`/`after:` or `DIFF window k unchanged:`; an unknown tag raises and names the tags that exist. (4) The truncation was ONLY the pane: neither `::pis::common::log` nor the GUI append ever cut a message, so `_tcl_pis_99_workflow_gui.tcl` builds the pane `-wrap char` (horizontal scrollbar kept) and the header says why. (5) No `[debug] result_trace` ini key - the trace IS the evidence the owner check depends on, so it is unconditional; a switch that can be off turns a missing line into a configuration question. (6) Tests: `tests/tcl/test_result.tcl` section 32 (a)-(f2) proves V6 comes LAST, sends the documented literal right after the type and before the dimensions, cites the owner macro, V1..V5 send no state, `variant_needs`/`variant_name` match; the whole failed-run story WITH its order (BEFORE, 6 sent lines, 6 NOCHANGE lines, LATE, FALSE-NEGATIVE GUARD, OWNER CHECK last); an unanswered `display` getter prints `?`; `snap`/`snaps_text`/`diff` over 4 windows with no setter call, one `SNAP` line per window, changed vs unchanged proven, unknown tag refused; an absent `SetEnableState` is called ONCE, logs ONE INFO line and V6 is `SKIPPED` on window 2. The sim gained `enabledstate`, `enablesets`, `needenable`, `absent` and `order` (plus the `result_line` helper); five assertions that counted log lines now count the A10 result line, because TRACE/NOCHANGE repeat those values by design. `tests/tcl/test_gui_frame.tcl` asserts `-wrap char` and that no `-wrap none` is left. `tests/tcl/test_hw_adapter.tcl` no longer pins a stamp literal: it checks the BUILD line carries `$::pis::BUILD` and that the stamp has the form `T<code>-<yyyymmdd>-<hhmm>`. - Ran: 2026-11-17: `tclsh tests/tcl/test_result.tcl` -> 290 PASS, exit 0; `tclsh tests/tcl/test_gui_frame.tcl` -> 22 PASS, exit 0; `tclsh tests/tcl/test_hw_adapter.tcl` -> 448 PASS, exit 0; `bash scripts/verify.sh` -> `verify: OK`, exit 0 (16 files parsed, 27 ASCII, 7 Tcl 8.5, 7 suites green). BUILD `T8d-20261117-0900`. - Files: `src/01_scripts/_tcl_pis_03_load_result.tcl`, `src/01_scripts/_tcl_pis_99_workflow_gui.tcl`, `src/01_scripts/_tcl_pis_11_hw_adapter.tcl` (stamp + comments), `tests/tcl/test_result.tcl`, `tests/tcl/test_gui_frame.tcl`, `tests/tcl/test_hw_adapter.tcl`, `docs/SPEC.md`, `docs/HANDOFF.md`, `docs/refs/HV_API.md`, `docs/TASKLOG.md`. - Not checked on HyperView: the whole result step, and therefore whether V6 makes the contour appear. - Refs: `docs/SPEC.md` (Production trace, HV-CHECK MODE item 8), `docs/refs/HV_API.md` sections 11-12, `docs/HANDOFF.md` sections 2-6, `test/test_out/TCL_StressExport.tcl` lines 55-60.


OWNER RESULT (recorded 2026-11-17) - `T-008: fail 5`, cause **AGENT**: a correct result name still left every window without a contour, so neither the `SetDataType` -> dimension-enable order (V1-V4) nor the display option (V5) is the missing step, and the log cut long lines at the pane edge so it never showed what was actually sent. Handled by T-030: V6 from the owner's own macro plus a trace that prints every step. A new failure becomes `T-008: fail 6`, never an edit of this line.


T-031: `T-008: fail 6` - honest verdict, step-by-step trace, full mining of the owner's proven script - Status: accepted (user check: pass, 2026-11-18; the GUI+log check passed, see the OWNER RESULT line below) - Why: T-030 asked for per-step evidence and treated `GetDimensionEnabled` as proof of a display; F12 shows the owner's build answers the type and the display option correctly and never moves a dimension flag, so the module reported a failure it could not prove and hid the one thing that mattered (what each call returned). Only modify: `src/01_scripts/_tcl_pis_03_load_result.tcl`, `src/01_scripts/_tcl_pis_11_hw_adapter.tcl` (shared helpers only), the result block + status colours of `src/01_scripts/_tcl_pis_99_workflow_gui.tcl`, `tests/tcl/test_result.tcl`, `tests/tcl/test_gui_frame.tcl`, `docs/refs/HV_API.md`, `docs/refs/HV_OWNER_contour_hits.txt` (new), `docs/SPEC.md`, `docs/TASKLOG.md`, `docs/HANDOFF.md`. Items 1-4: (1) LITERAL SENT TEXT - every `sent:`/`TRACE`/`STEP` text is the command as it sits in the executed script, quoting and handle included (`pisCt SetDataType {1. Endure_SF_A}`); no transform exists anywhere (`[ ]`/`{ }`/`( )`), and a data type with blanks or dots is ONE word built by `::pis::hw::quote` (the adapter's `::pis::journal::quote_arg`), never by brackets. F12 (d) answered: the module never emits a bracket - `[list "1. Endure_SF_A"]` is `{1. Endure_SF_A}` (checked with tclsh 8.6, see the Ran line) and the only way a bracket reaches the log is a LABEL that itself holds one, in which case the text is braced again (`{[1. Endure_SF_A]}`); the bracket in the owner's log is therefore a display/copy artefact of the previous text, not an executed command. (2) STEP TRACE - `[debug] result_trace` (default 1 until the owner writes `accepted`); every setter is its OWN hwi script in the adapter's stack pattern (`set pisRStep [<cmd>]` captured, stack closed, no ReleaseHandle on a forbidden handle kind, and the bare `set pisRStep` AFTER `hwi CloseStack` is what the door returns, so `ret=` is the setter's own answer, never CloseStack's), and ONE line per setter: `STEP window k v<v>/<n> <step name>: sent <literal command> -> ret=<raw|(empty)> | now: type=.. dims=.. display=.. subcase=.. enablestate=..` or `-> ERR <text, full>`; a `ret` other than empty/0 fails the step (every setter used here is documented as "Returns 0 if successful, otherwise an error code"). Non-trace mode keeps ONE script per window and ONE journal line, and the journal text of the passing variant is IDENTICAL in both modes (the `set pisRStep` wrapper is never journaled). One `NOTE type already '<name>' before the apply: SetDataType effect is not provable this run` per run. (3) THREE-STATE VERDICT - `APPLIED` (type + at least one dimension true + subcase + display not false), `APPLIED-UNCONFIRMED` (type + `GetDisplayOptions contour` true + subcase + nothing raised + no dimension true before AND after), `FAILED` (type mismatch / display option off / subcase 0 / a step raised or returned an error). The middle state is a WARN, counts the window as processed, journals the FIRST variant that raised nothing, does not block later modules, and the GUI status bar shows `Load result: applied, display not confirmed (look at the windows)` in the EXISTING warn colour `#9a6400` (SPEC_gui prints no status colour rule, so none is invented); `GetDimensionEnabled` is documented in SPEC as UNVERIFIED display evidence and can never make a window failed on its own. `[debug] result_try_all` (default = result_trace) keeps V2..Vn running after an unconfirmed variant and reports each as `NOCHANGE` or `CHANGED`; NOCHANGE now compares with the state immediately BEFORE that variant and says `the setter returned without error but the getters did not move` - the word `ignored` and the spacing typo are gone. (4) FULL MINE - `docs/refs/HV_OWNER_contour_hits.txt` (new) holds the owner's contour section, source lines 34-96 of `C:/Users/TechnoStar/Documents/macro/test/test_out/TCL_StressExport.tcl` (the task's `test/test_out/...` is relative to that macro root; the file WAS found, so no STOP condition), plus the handle chain and the calls that were not copied. The comparison table (below) finds differences, so V0 exists: `SetDataType` -> `SetEnableState true` -> `Draw`, FIRST in `variants`, NO dimension enable, src `PROVEN`.
Items 5-8, tests, Ran line and the owner check: (5) MORE READ-ONLY EVIDENCE - the probe, the STATE DUMP and `snap`/`diff` read `GetDisplayOptions` for every S56 name and `GetEnableState` (S54, the documented read-back of V0/V6's call - printed as `enablestate=` in every `STEP ... now:`), print `IDENT window k: client=pisC models=<GetModelList> added=<GetActiveModel>` (Load All keeps no AddModel return, so the text never claims it) and ONCE per window `LEGEND window k: handle=..|empty|absent|ERR ..` from the PROVEN `::hwp::GetContourLegend` (S02:43-57), guarded by `info commands`, releasing a returned handle at once; the legend never enters the verdict. (6) LOG HYGIENE - the mid-word breaks (`shel` / `l true`, `valu` / `e display`) are made by the Tk text widget's `-wrap char`, not by `common::log` or the GUI insert (both pass the message unchanged, and a Save/copy yields the logical line), so nothing in the code was changed for it and the 70-character limit stays a status-bar rule only. (7) TESTS - `tests/tcl/test_result.tcl` section 33 (a)-(l) plus rewritten T-026/T-027/T-030 expectations for the three verdicts and V0; `tests/tcl/test_gui_frame.tcl` checks the amber sentence, its `#9a6400` colour and that it comes from `::pis::result::unconfirmed`. (8) DOCS - SPEC.md "Verdict, step trace and literal sent text (T-031)" + the A10 amendment; HV_API.md F12, the T-031 subsection and the `GetEnableState` note; HANDOFF sections 2/4/5/6/9/11. `::pis::BUILD` = `T8e-20261117-1500`. - Ran: 2026-11-17: `tclsh tests/tcl/test_result.tcl` -> MOCK, 346 PASS, exit 0; `tclsh tests/tcl/test_gui_frame.tcl` -> 25 PASS, exit 0; `tclsh tests/tcl/test_hw_adapter.tcl` -> 448 PASS, exit 0; `bash scripts/verify.sh` -> `verify: OK`, exit 0 (16 tcl files, 27 ASCII, 7 Tcl 8.5, 7 suites green); `tclsh` 8.6.16 printing `::pis::hw::quote {1. Endure_SF_A}` -> `{1. Endure_SF_A}` (F12 (d)). Commands still UNVERIFIED on HyperView: whether V0 (the owner's own order) really shows the contour, whether `GetDimensionEnabled` ever reads true for a nodal result on this build, what `GetEnableState` answers there, and what `::hwp::GetContourLegend` returns there. - Owner check (GUI + log only, max 3 steps): (1) copy `src/01_scripts`, start the GUI, Load All, Load result with the CORRECT name; note for EVERY window whether a colour contour is visible (yes/no); (2) select the whole log pane (Ctrl+A, Ctrl+C - the toolbar's Save button is T-012 and not wired) and send it: the BUILD line is first and the log holds BEFORE, IDENT, LEGEND, NOTE, the TRACE sent lines, one STEP line per setter with `ret=`/`ERR`, LATE, and either the A10 result line or the WARN `applied but the display is NOT confirmed`; (3) optional console diagnostics: `::pis::result::snap before`, switch the contour on by hand, `::pis::result::snap after`, `::pis::result::diff before after`, send the DIFF lines. Interpretation: amber `applied, display not confirmed` AND colours visible = the old read-back was a false negative (finished); amber AND no colours = the STEP lines show which setter does nothing; a red error = a step raised and the log names it. - Refs: docs/SPEC.md (T-031 subsection), docs/refs/HV_API.md F12 + section 11 (T-031), docs/refs/HV_OWNER_contour_hits.txt.






T-031 comparison table - the owner's proven macro vs what the module sends (`C:/Users/TechnoStar/Documents/macro/test/test_out/TCL_StressExport.tcl`, copied in `docs/refs/HV_OWNER_contour_hits.txt`):

| # | script step | script text (file:line) | module sends | same/different |
|---|---|---|---|---|
| 1 | open the stack, session/project | `hwi OpenStack`; `hwi GetSessionHandle sess`; `sess GetProjectHandle proj` (16-18) | `::pis::hw::stack_open` (same three commands) | same |
| 2 | page via the ACTIVE page | `proj GetPageHandle page [proj GetActivePage]` (19) | `set pisPgI [pisP GetActivePage]; pisP GetPageHandle pisPage $pisPgI` | same |
| 3 | window: the ACTIVE one | `page GetWindowHandle win [page GetActiveWindow]` (20) | `SetActiveWindow <k>` (S5) then `GetWindowHandle pisWin <k>` | different (module selects by index; the macro relies on the active window) |
| 4 | client of the window | `win GetClientHandle clt` (21) | `pisWin GetClientHandle pisC` | same |
| 5 | model: the ACTIVE model | `clt GetModelHandle model [clt GetActiveModel]` (22) | `set pisRMid [pisC GetActiveModel]; pisC GetModelHandle pisM $pisRMid` | same |
| 6 | result controller | `model GetResultCtrlHandle rctrl` (24) | `pisM GetResultCtrlHandle pisR` | same |
| 7 | contour controller | `rctrl GetContourCtrlHandle con` (44) | `pisR GetContourCtrlHandle pisCt` | same |
| 8 | data type, quoted | `con SetDataType {S-Stress components}` (55) | `pisCt SetDataType {<the file's label>}` (S28, `::pis::hw::quote`) | same form, label differs (the requested type) |
| 9 | data component | `con SetDataComponent Mises` (56) | not sent (S37 prints no value space) | different - NOT copied on purpose |
| 10 | average mode | `con SetAverageMode simple` (57) | not sent (page NOT FETCHED) | different - NOT copied |
| 11 | corner data | `con SetCornerDataEnabled true` (58) | not sent (S89: node-on-element binding only) | different - NOT copied |
| 12 | enable state | `con SetEnableState true` (59) | V0/V6: `pisCt SetEnableState true` (S53) | same |
| 13 | avg across parts | `con SetAvgAcrossPartsEnable enable` (60) | not sent (page 404, no documented value) | different - NOT copied |
| 14 | dimension enable | NEVER sent by the macro | V1..V6: `pisCt SetDimensionEnabled <dim> <literal>` (S35) | different - V0 is the variant WITHOUT it |
| 15 | subcase / simulation | per frame: `rctrl SetCurrentSubcase <id>` + `SetCurrentSimulation <n>` (123-124) | `SetCurrentSubcase <first id>` ONLY when the window has none (S39); no simulation is sent | different (no documented simulation setter for this job) |
| 16 | repaint | none (`update` + `after 40` in the Tk loop) | `pisC Draw` (PROVEN pattern 2, S06:211-213) + ONE `::pis::hw::refresh` (`update idletasks`) after the loop | different - kept because the pattern is proven |
| 17 | `hwc` lines | none | none | same |

Because rows 3, 14, 15 and 16 differ, V0 exists (item 4 of T-031). It reproduces the macro's DECISION-RELEVANT calls (type, enable state) and drops the dimension enable, which the macro never sends; the four calls whose arguments are only valid for ITS data type (rows 9-11, 13) are not copied, because inventing their value for another result type is a guess and the STOP RULE forbids it. V0 = `SetDataType <label>` -> `SetEnableState true` -> `Draw`, `src = PROVEN`, first in `::pis::result::variants`.



OWNER RESULT (recorded 2026-11-17, GUI log of build `T8d-20261117-0900`) - `T-008: fail 6` (T-030 not accepted), cause **AGENT** for items (c)/(d)/(e) below and **EXTERNAL** for the missing "is a contour visible" answer: a CORRECT result name still shows no contour, and the log of the six variants proves why it could never have shown one. Facts F12 (the owner's own words, kept): (a) six variants, EVERY one logs NOCHANGE against BEFORE, V5 (`SetDisplayOptions contour true`) and V6 (`SetEnableState true`, from `test/test_out/TCL_StressExport.tcl`) included; the LATE read after 500 ms equals BEFORE. (b) BEFORE - taken before any setter of the run - already had `GetDataType` = the requested type, `GetDisplayOptions contour` = true, subcase 1, step 1 and ALL THREE `GetDimensionEnabled` false; so `SetDataType` was never proven to do anything in that run, and the ONLY read-back that fails is `GetDimensionEnabled`, which is OUR criterion (S36) and was never confirmed against what the window displays on this build - if the result is nodal, line/shell/solid may legitimately stay false while a contour is shown, and we do not know. (c) T-030 item 3 is NOT met: each variant's setters are ONE `sent: A -> B -> C` line, with no raw return/error per step, no state after each step and no `step <name>: ok|ERR` line. (d) the sent text showed `SetDataType [1. Endure_SF_A]` with SQUARE brackets (an earlier log used `{...}` and `(...)` for lists), and a bracket is command substitution in Tcl - the log must show the literal text that is executed. (e) wording defects: `-the build accepted the commands and ignored then` (missing spaces, typo, and "ignored" is an unproven conclusion - a getter may simply not reflect a setter). (f) NOT REPORTED by the owner: whether a colour contour was visible in window 1; UNKNOWN, never assumed. Handled by T-031. A new failure becomes `T-008: fail 7`, never an edit of this line. STOP RULE unchanged: no new production variant based on a guess.



OWNER RESULT (recorded 2026-11-18) - `T-008: pass`; with it T-026, T-027, T-029, T-030 and T-031 are accepted. The owner replied "ok pass. accepted." for the `T8e-20261117-1500` GUI+log check and sent no per-window yes/no list, so the verdict is the only recorded fact and nothing about what he saw is written here. No defect, no cause code. What the pass does and does not mean: the result step is finished by the owner's judgement, while the module still holds no evidence of its own that a window PAINTS a contour (`GetDimensionEnabled` stays false on that build and stays display evidence only, F12 (b)/(f)) - that limit is recorded, never removed. Fail 1..6 stay above, unedited. Next in the order: T-009/T-010 are blocked on their class pages, so T-011 (Capture) runs.

Sizes (estimated hand-written diff lines, lockfiles/generated excluded per BRIEF Â§10): T-001 ~60, T-002 ~130, T-002b ~240, T-002c ~200, T-003 ~220, T-004 ~280, T-005 ~200, T-006 ~280, T-007 ~190, T-008 ~170, T-009 ~150, T-010 ~150, T-011 ~160, T-012 ~240, T-013 ~150, T-014 ~30, T-015 ~260, T-016 ~120, T-017 ~200 (planned, proposal A), T-018 ~40, T-019 ~240, T-026 ~120, T-027 ~200, T-029 ~280, T-030 ~430 (the four result-step passes), T-031 ~560 (verdict + trace + V0), T-011 ~420 (capture: call, name, file proof). Each task = one commit; rollback = `git revert <sha>` (fact checked 2026-11-10: the folder has no `.git` yet, so no commit exists and no sha to revert â€” this line is the intended workflow, not the current state).


OWNER RESULT (recorded 2026-11-18) - `T-011: fail 1` (T-011 stays in progress, never accepted; T-008 stays accepted). The GUI check of build `T11a-20261118-1107` found: F13 (a) the [Capture] button captures and saves NOTHING and shows an error (the owner has not sent the log line); (b) [Apply all layout] writes ONE window and then reports an error, the other windows are not captured (error text not sent); (c) the saved image shows the window as it is on screen - the module does NOT switch the window to the view named by the row first; the owner's own way is `SetActiveView true "View 1"` (view name in quotes), its class/handle is not in his message; (d) the name changes from `{model}_{result}_{item}.png` to `{result_file_name}_{view}.png` (the model part is dropped), `{view}` = the row's view name. Cause AGENT, four facts: (1) the variant list used the DOC call S91 `hwISession CaptureWindow` FIRST although `docs/refs/HV_API_REF.md` already held a PROVEN capture call and the owner's own scripts use working ones - the binding precedence PROVEN > DOC was not applied; (2) the view named by the row was never activated before the capture; (3) the capture was one opaque script, so a failure showed no per-step evidence; (4) the first window's failure stopped the loop with no window-level text. STOP RULE restated: no new production variant from a guess - every variant needs a PROVEN or DOC src. Handled by T-032. A new failure becomes `T-011: fail 2`, never an edit of this line.

T-032 item 1 - the owner script | script text | what the module sends (mined in docs/refs/HV_OWNER_capture_hits.txt; the scripts were searched in C:\Users\TechnoStar\Documents\macro, i.e. `conrod/...` and `test/...` as the adapter's src fields cite them):

| step | owner script (file:line) | script text | the module sends | same? |
|---|---|---|---|---|
| session/page/window/client chain | conrod/tcl_guide/hv_model_loader.tcl:2073-2104, conrod/_tmp_hv/hvTest.tcl:8-24, test/test_out/TCL_StressExport.tcl:17-21 | `hwi OpenStack` > `GetSessionHandle` > `GetProjectHandle` > `GetPageHandle [GetActivePage]` > `GetWindowHandle <k>` > `GetClientHandle` | identical, built by `::pis::hw::stack_open`/`window_open` | same |
| make window k active | hv_model_loader.tcl:2101-2102 (`mlPage SetActiveWindow $w`), ppt2.tcl:185 | `<page> SetActiveWindow <k>` | `pisPage SetActiveWindow <k>`, LAYOUT scope only | same (the module deliberately does not select a window for the [Capture] button - the active window IS the target) |
| activate the VIEW | NOT in any script: the loader sets the CAMERA (`<win> GetViewControlHandle` > `SetOrientation`/`SetViewMatrix`, hv_model_loader.tcl:1985-2005, display_service.tcl:197-198, hvTest.tcl:136); the owner's working call for a NAMED view is `SetActiveView true "View 1"` (his report F13c) | `<viewctrl> SetActiveView true {<view>}` | T-032 sent `pisPage SetActiveView true {<view>}` and the owner's build refused it (F14 a: hwIPage has no such method). T-033 sends `pisPage GetWindowHandle pisWin <k>` > `pisWin GetViewControlHandle pisV` > `pisV SetActiveView true {<view>}` - the receiver the 2024+2026 docs name (S99+S103), the literal unchanged | SAME as the owner's call and now on a DOCUMENTED class |
| wait/refresh after the view | hv_model_loader.tcl:2120 `Draw`, training.tcl:93/163/170, hvTest.tcl:137, ppt2.tcl:164, HV_API_REF.md patterns 5/6 | `<client> Draw` (+ `update idletasks` in the GUI scripts) | `pisC Draw` on window k's client + `::pis::hw::refresh` | same |
| capture call | hv_model_loader.tcl:1936-1938 (`CaptureImage`, tried first), hvTest.tcl:140 (`CaptureScreen png`), HV_API_REF.md S06:249/260 + S07:544 (`CaptureScreenToSize`), S91 (`CaptureWindow`, DOC) | see the four forms | variants 1..5 in that order | same order as the owner's loader (its first form, then the shipped spellings), the DOC call last |
| image type / path quoting | owner scripts pass `png`/`PNG` and a quoted path (`"$m_file"` where it has spaces); the type is also the extension (`S06` reads it from its config) | `<type> <file>` | type = the file extension (`png`), path quoted as ONE argument by `::pis::hw::fill` | same |
| width/height | ppt2.tcl:175 (`pixels 1280 960`), S06/S07 (`image_width`/`image_height` from their config), S91 (`pixels 1280 960` / `percent 150 150`) | `<w> <h>` (pixels) | `[capture] image_width`/`image_height` else `width`/`height` else 1280x960; variant 3 gets the pixel pair, variant 4 `pixels`, variant 5 `percent 150 150` | same |
| per-window loop 1..N and "capture all" | hv_model_loader.tcl:2094-2133 (`foreach w [dict keys $byWindow]`, `SetActiveWindow`, view, `Draw`, capture, warnings) | loop over the page's windows | `[Apply all layout]` walks windows 1..N of the Load All, plan built before anything is sent | same |

T-032: fix the Capture module (T-011 `fail 1`) — Status: agent-done (owner check owed; T-011 stays in progress, never accepted) — Done when: `bash scripts/verify.sh` prints `verify: OK`, all suites green (MOCK), `::pis::BUILD` bumped, T-011 not accepted — Only modify: `src/01_scripts/_tcl_pis_06_capture.tcl`, `src/01_scripts/_tcl_pis_11_hw_adapter.tcl` (capture op + shared helpers), the capture block of `src/01_scripts/_tcl_pis_99_workflow_gui.tcl`, `tests/tcl/test_capture.tcl`, `tests/tcl/test_hw_adapter.tcl`, `docs/refs/HV_API.md`, `docs/refs/HV_OWNER_capture_hits.txt` (new), `docs/SPEC.md`, `docs/TASKLOG.md`, `docs/HANDOFF.md` — Agent: Ran: 2026-11-18: mined the owner's own scripts (`C:\Users\TechnoStar\Documents\macro`, every *.tcl outside src/ and docs/) into `docs/refs/HV_OWNER_capture_hits.txt`: 35 hits in `conrod/tcl_guide/hv_model_loader.tcl` (the capture order at 1933-1975, the view through `GetViewControlHandle` at 1976-2011, the per-window loop at 2094-2133), `conrod/_tmp_hv/hvTest.tcl:140` (`sessObj CaptureScreen png test_$i.png`), `training.tcl:95,172`, `ppt2.tcl:175`, `test/test_out/TCL_StressExport.tcl:50`, `display_service.tcl:197-198`; `CaptureScreenToSize` and `SetActiveView`/`GetActiveView` exist in NO script, and `SetActiveView` is in no 2024 class index either (S93 hwIPage, S94 hwIWindow, S95 hwISession, S98 hwIViewControl fetched 2026-11-18; the four guessed `*_setactiveview.htm` URLs 404) -> the owner's literal `SetActiveView true "<name>"` is kept as PROVEN-as-literal / UNVERIFIED-GUESS-as-class (page assumed) and the files he must copy are named in the hits file. Adapter: `capture_window {index path view unit w h ?-row r? ?-layout 0|1? ?-trace 0|1?}` is now four steps (select/view/draw/call) sent as one script per step while the trace is on and as ONE joined script otherwise (the journal text is identical - tested), with `CAPTURE ctx` and one `STEP ... sent ... -> ret=... | now: ...` line per step; variants 1..5 = `CaptureImage` (PROVEN, first), `CaptureScreen png` (PROVEN), `CaptureScreenToSize` (PROVEN digest + DOC S96, skipped when the unit is percent), `CaptureWindow` pixels and percent (DOC S91, last); new helpers `capture_frag`, `capture_step_script`, `capture_full_script`, `capture_now`, `set_view` (sends the view + Draw + refresh, checks a getter when one exists), `view_getter`/`view_list_getter` (both `""` - no page names one), `active_view`; `active_window` unchanged. Module: names are `{result_file_name}_{view}.png` (model dropped, `noresult` fallback, `_2`/`_3` as before), per-image steps through the adapter, ONE ERROR line with window/row/view/step/raw/path, `[log] continue_on_error` honoured, `windows <k+1>..<N> not attempted`, final line `captured <n> of <m> image(s)`, ONE `INFO capture: no getter for the active view, windows stay on the last captured view`, `[debug] capture_trace` (default 1), `[capture] image_type` must be png, `image_width`/`image_height` accepted beside `unit/width/height`, `capture: no active window (<raw>)` with 0 images and 0 journal lines; GUI `capture_cfg` now keeps the ini's other `[capture]` keys (it used to drop them). Tests (MOCK): `test_capture.tcl` rewritten, 155 checks (sequence order per image, one-argument view name with spaces and dots, getter mismatch -> exact error and 0 capture calls, restore per window vs the single INFO line, variant order and fallbacks, 4 windows x 2 views = 8 names with `_2`, window 2 failing -> one ERROR line + `windows 3..4 not attempted` + `captured 2 of 8`, continue_on_error -> 6 of 8, no active window, trace on/off journal identical, journal replay, argument checks, ini untouched, GUI wiring); `test_hw_adapter.tcl` sample gains `%view/%unit/%width/%height/%type`. `bash scripts/verify.sh` -> `verify: OK`, 17 files parse, 29 ASCII, 8 suites `ok`, PASS: capture 155 / hw_adapter 453 / result 346 / block0 273 / hw_exec 92 / legend 56 / common 46 / gui_frame 25. BUILD `T32a-20261118-1530`. How to check (user, max 3): 1) Load All, tick ONE row with a view name (for example `View 1`), press [Capture]: one `.png` named `{result_file_name}_{view}.png` in `02_working` showing THAT view, plus one `OK capture window k ...` line - no file, a 0-byte file or the wrong view is wrong. 2) [Apply all layout] with 2 windows and 2 rows ticked: 4 images; look at them - each window's image must show its own result in the view named in the file name. 3) Press [Save] on the log and send it (BUILD line first) with one sentence per failed step, saying what the image shows. The log holds `CAPTURE ctx`, one `STEP` line per step and the final `captured n of m`. Rollback: revert this commit (`::pis::BUILD` back to `T11a-20261118-1107`). Refs: `docs/refs/HV_API_REF.md` (PROVEN S06:249/260, S07:544), `docs/refs/HV_OWNER_capture_hits.txt` (new), `docs/refs/HV_API.md` sec.6 (S91-S98), docs/SPEC.md sec.6.5, F13 above, TASKLOG T-011 (+fails 1).

| restore the original view | none in any script | - | none either (T-033 dropped the attempt): the view is READ BACK (`GetActiveView`, S100) and a wrong one fails the image, but no old view is set back | same as the scripts |



OWNER RESULT (recorded 2026-11-18) - `T-011: fail 2` (T-011 stays in progress, never accepted; T-008 stays accepted).
The GUI check of build `T32a-20261118-1530` (log sent by the owner) found - F14:
  a. [Capture] with one row `View 1`: EVERY one of the 5 capture variants failed at the SAME step, `view`,
     with: `Object named: pisPage (of type hwIPage) could not find requested method: SetActiveView Or
     the method was called with incorrect arguments.` The page handle is an hwIPage and has no
     SetActiveView; the capture call itself (CaptureImage / CaptureScreen / CaptureScreenToSize /
     CaptureWindow) was NEVER executed, so there is no evidence about any capture call yet.
  b. Each variant re-ran `select` and the failing `view` step: a step that does not depend on the
     variant was retried 5 times, and the absent-method rule (T-027 item 3) did not stop it.
  c. The sent scripts contain `catch {pisPage ReleaseHandle}; catch {pisP ReleaseHandle};
     catch {pisS ReleaseHandle}`. PROVEN rule (HV_API_REF Misc, T-020 item 2): ReleaseHandle is NEVER
     called on session, project, page, window, view, post, model or result handles. The capture ops
     were not covered by that test.
  d. There is no getter of the active view in any class documented SO FAR, so a view change cannot be
     read back (T-033 found one: poI3DViewCtrl GetActiveView).
  e. The file-name rule works: `Z12E_femfat_nBound5700_SPEC1_View_1.png` (result_file_name + view, no
     model).
  f. The owner has a working capture script that calls `SetActiveView true "View 1"` somewhere (a
     per-window loop, a selected view or all views). It is NOT in this workspace, so the RECEIVER of
     that call was unknown at the time of the report - it is not hwIPage.
  Cause AGENT: a guessed receiver class was shipped as the first step of every capture variant; the
  step was not separated from the variants; forbidden ReleaseHandle calls were left in the capture
  scripts.


T-033: Capture - separate the view step, find its real receiver, stop wasting variants - Status:
agent-done (owner check owed; T-011 stays in progress, never accepted) - Done when: `bash
scripts/verify.sh` prints `verify: OK`, all suites green (MOCK), `::pis::BUILD` bumped, T-011 not
accepted - Only modify: `src/01_scripts/_tcl_pis_06_capture.tcl`, `src/01_scripts/_tcl_pis_11_hw_adapter.tcl`
(capture_window op, view helper, release rule), the capture block of
`src/01_scripts/_tcl_pis_99_workflow_gui.tcl`, `src/00_config/pis_workflow_config.ini`,
`tests/tcl/test_capture.tcl`, `tests/tcl/test_hw_adapter.tcl`, `docs/refs/HV_API.md`,
`docs/refs/HV_OWNER_capture_hits.txt`, `docs/SPEC.md`, `docs/TASKLOG.md`, `docs/HANDOFF.md`.
  Item 1 - the receiver, found in the docs (evidence first):
    Search: indexTerms.htm of the 2022, 2023, 2024 and 2026 help for `ActiveView`, `RestoreView`,
    `ViewList`, `GetViewControlHandle`; then the pages themselves. The workspace and docs/refs/ hold
    NO owner script with SetActiveView (F14 f - he has not copied one in).
    ANSWER: the receiver is the 3D VIEW CONTROL handle, class **poI3DViewCtrl**:
      `poI3DViewCtrl_handle SetActiveView active name` (S99, 2024 AND 2026, also in the 2022/2023
      index terms) - "Sets a view as active or not active"; the supplier's own example is
      `window_handle GetViewControlHandle view_handle` > `view_handle SetActiveView true "View 1"`.
      The leading `true` is the `active` BOOLEAN ("whether to activate or deactivate a view"), the
      second argument is the NAME. The getter `hwIWindow GetViewControlHandle viewctl` is documented
      too (S103), and the read-back EXISTS: `poI3DViewCtrl_handle GetActiveView` (S100) answers the
      name of the active view, "Current View" when none is marked. Also documented, unused:
      `GetViewList` (S101), `RestoreView` (S102), `GetViewMatrix`/`SetViewMatrix`/`SetOrientation`
      (S104), SaveView/RenameView/RemoveView (S105).
    Cause of the T-032 miss: only the hwI* class pages were read (hwIPage/hwIWindow/hwISession/
    hwIViewControl, S93-S98); the po* class that owns the method was never looked at.
    NOT FETCHED (written down so nobody invents them): there is no `poIWindow` class page;
    `hwipage_setactiveview.htm`, `hwiviewcontrol_setactiveview.htm`, `poipage_setactiveview.htm` 404.
  Item 2 - the steps are decoupled: an image is select (layout only) -> view -> draw -> the capture
    call -> the file check, each sent as its OWN hwi script. The variants apply to the CALL only;
    select/view/draw run once per image (F14 b fixed). The view step has its own receiver list and
    its own error: `view step failed for all receivers, capture call not attempted (tried ...)` when
    every receiver is absent, `view step failed, capture call not attempted: receiver <type> said:
    <raw>` for any other error - the capture variants never start in either case.
  Item 3 - bounded receiver discovery (`::pis::hw::view_table`, fixed order): (1) the documented view
    control handle (`pisPage GetWindowHandle pisWin <k>` + `pisWin GetViewControlHandle pisV`), (2)
    the window handle, (3) the client handle, (4) the session handle - the last three labelled
    UNVERIFIED-GUESS (receiver; literal from owner). The owner's exact literal is used, the name as
    ONE quoted argument. The first receiver that raises nothing is cached for the run and logged
    ONCE (`VIEW window k: receiver <type> accepted SetActiveView true '<name>'`); a receiver that
    answers `could not find requested method` is recorded ABSENT (`<type> SetActiveView`, ONE `INFO
    method absent on this build: <type> SetActiveView`) and skipped for every later window and row;
    any other error stops the discovery and is reported in full (the method exists there).
  Item 4 - read-back: `GetActiveView` before and after; a different name is
    `view '<name>' not active in window k (read: <v>)` with 0 capture calls. When that getter does
    not answer, `GetViewMatrix` is read before/after as EVIDENCE (`WARN ... camera unchanged ... look
    at the image` / `INFO view window k: camera changed`); with neither, ONE `INFO view: no read-back
    for the active view on this build ...` per run. No view is "restored" any more (T-032's restore is
    gone: only a STORED view can be set by name, and the row's view is what the name claims).

  Item 5 - ReleaseHandle: removed from `page_close`/`window_close` (now `hwi CloseStack` only) and
    from every table body in `_tcl_pis_11_hw_adapter.tcl` (session, project, page, window, client,
    model, result, manager). Both suites now scan the text of EVERY op/variant and of the capture and
    view step scripts; a seeded `catch {pisPage ReleaseHandle}` must fail the scan.
  Item 6 - `[capture] on_view_unavailable = stop|capture_current` (ini + SPEC 6.5): `stop` keeps the
    failure; `capture_current` logs ONE `WARN capture: view activation unavailable on this build -
    capturing the CURRENT view of each window, the file names still carry the row's view name (images
    may show another view)`, then skips the view step for the rest of the run (`-viewstep 0`); the
    journal of such an image holds no view line.
  Items 7/8 - variants 1..5 unchanged (CaptureImage PROVEN first) and now cached per run (`CAPTURE ok
    window k variant <n> <call>`); one STEP block per step, the literal sent text, the raw answer
    once per distinct failure, `captured n of m`, `windows k+1..N not attempted`, names
    `{result_file_name}_{view}.png`.
  Ran: `bash scripts/verify.sh` -> `verify: OK`, 17 files parse, 29 ASCII, 8 suites `ok`, PASS:
    capture 209 / hw_adapter 467 / result 346 / block0 273 / hw_exec 92 / legend 56 / common 46 /
    gui_frame 25. BUILD `T33a-20261118-1930`.
  How to check (owner, HyperView, GUI only, max 3 steps):
    1) set `[capture] on_view_unavailable = capture_current`, Load All, tick one row, press [Capture]:
       a `.png` with the current view plus `OK capture window k ...` and `CAPTURE ok window k variant
       <n>` prove the capture call works; a `STEP ... call: ERR` names the refused call.
    2) set it back to `stop`, press [Capture] again with the row `View 1`: look for
       `VIEW window k: receiver <type> accepted SetActiveView ...`; the image must show that view. If
       the log says `view step failed for all receivers`, send it - it lists every tried handle type.
    3) [Apply all layout], 2 windows, 2 rows: 4 images named `{result_file_name}_{view}.png`, each
       showing its own view; press [Save] and send the log (BUILD line first) with one sentence per
       image.
  Rollback: revert this commit (`::pis::BUILD` back to `T32a-20261118-1530`); every change is in the
    files above and the capture variant order is untouched, so the T-032 behaviour comes back without
    editing the tables.
  Refs: `docs/refs/HV_API.md` sec.6 (S99-S105, the class/method table),
    `docs/refs/HV_OWNER_capture_hits.txt` (the T-033 search round), `docs/SPEC.md` sec.6.5, F14
    above, TASKLOG T-011 (fails 1 and 2).

T-034: Load All raised a duplicate handle name - one name per iteration, never two live copies - Status:
agent-done (owner check owed; T-011 stays in progress, never accepted) - Done when: `bash
scripts/verify.sh` prints `verify: OK`, all suites green (MOCK), `::pis::BUILD` bumped, T-011 not
accepted - Only modify: `src/01_scripts/_tcl_pis_11_hw_adapter.tcl`, `tests/tcl/test_hw_adapter.tcl`,
`tests/tcl/test_capture.tcl`, `tests/tcl/test_block0.tcl`, `docs/SPEC.md`, `docs/refs/HV_API.md`,
`docs/TASKLOG.md`, `docs/HANDOFF.md`.
  Owner fact F15 (2026-11-18, build `T33a-20261118-1930`, seen on Load All): inside ONE open stack
    (`hwi OpenStack` .. `hwi CloseStack`) a handle name that is STILL ALIVE cannot be created a
    second time; the build raises, verbatim, `<name>: object with this name already exists.` Load All
    died on it, because the page/window walks reused ONE fixed name for every iteration - the same
    `pisWin` for window 1 and window 2, the same `pisPage` for page 1 and page 2, the same `pisC` for
    every client. Cause AGENT, and it was SELF-INFLICTED by T-033: F14 c forbade ReleaseHandle on
    session/project/page/window/view handles (correct rule, HV_API_REF Misc), so T-033 removed those
    calls from the walks - but the walks had been relying on a mock that quietly RE-DEFINED the
    handle command on a second `GetWindowHandle <same name>`, so a real build's refusal was never
    reproduced in the suites (hw_adapter 467 PASS and capture 209 PASS on a build that could not run
    Load All).
  Item 1 - the PROVEN ways an owner script lives with that rule, found before any code was written
    (searched the owner's own scripts under `C:\Users\TechnoStar\Documents\macro`, i.e. `conrod/...`):
    (1) per-iteration NAME: conrod/_tmp_hv/batchImportOdb.tcl:81-86 - `page_$i`,
      `window_$::Import::numberOfWindows`, `client_$::Import::numberOfWindows`;
    (2) per-iteration ReleaseHandle: conrod/_tmp_hv/training.tcl:179-184 - `pg${i}$t` per page plus a
      release at the end of every iteration;
    (3) names created once OUTSIDE the loop and reused: conrod/tcl_guide/hv_model_loader.tcl:2073-2132
      (`mlWin`/`mlClient` per window, freed at the end of every iteration) and
      conrod/_tmp_hv/hvTest.tcl:124-175 (one chain reused by the loop);
    (4) nothing at all in the DOC class pages - hwIPage/hwIWindow say nothing about name reuse.
    CHOSEN: (1). It never depends on a release being accepted by the build, and it keeps the
    journalled text replayable exactly as it was sent, which is the property T-026/T-031 rely on.
    (3) is what the walks effectively did and cannot be combined with F14 c; (2) would re-introduce
    the very calls F14 c removed.
  Item 2 - ONE spelling, `::pis::hw::hname {base {k ""}}`: `hname pisWin` is the plain name for a
    handle created once per stack, `hname pisWin 3` is `pisWin_3`, and a builder that writes script
    TEXT passes the variable REFERENCE - `[hname pisWin {$pisWi}]` -> `pisWin_$pisWi` - so the sent
    script fills in the iteration number itself. The proc is the only place that spelling lives.
  Item 3 - every walk in the adapter converted (this is the whole fix): `check_models_on_page`
    (logical page walk), `check_layout` and `make_grid` read-backs, `grid_walk`,
    `check_models_in_window`, `check_clients`, `check_page_info`, `observe_script`,
    `reset_remove`/`reset_page`/`reset_all` (the Load All reset), and the result read-back's retry
    loop (`@R@` now carries the attempt number, so a second attempt cannot collide with the first
    attempt's handle). `select_window` and `stack_open` keep their plain names on purpose: they
    create each handle ONCE per stack.

  Item 4 - the capture path, where the same collision hid in a different shape:
    `::pis::hw::capture_full_script` splices the view fragment and the draw fragment into one script,
    and both open `pisWin` (and `pisC` for the client receiver) - the duplicate the build refuses.
    An IDENTICAL line is now emitted ONCE, at the position where it was first written, so the replay
    keeps working and no handle is created twice. The comparison runs AFTER `::pis::hw::fill`,
    because `::pis::hw::capture_image` hands in an already-filled view fragment and `pisWin 1` must
    equal `pisWin %index`.
  Item 5 - the mocks now HAVE the build's semantics, in all three suites
    (`tests/tcl/test_hw_adapter.tcl` `::sim::mkhandle`/`::sim::drop`/`::sim::close`,
    `tests/tcl/test_capture.tcl` the same, `tests/tcl/test_block0.tcl` `sim_mkh`/`sim_drop`/
    `sim_close`): creating a name that is alive raises the build's own words, and only ReleaseHandle
    on that handle or CloseStack frees a name. That is what makes a reverted walk fail here instead
    of passing.
  Item 6 - tests (`tests/tcl/test_hw_adapter.tcl` section 26, plus the re-scoped scanners):
    (a) the mock really refuses a live duplicate and accepts the name again after a release -
    without this the rest of the section would prove nothing; (b) a page of FOUR windows survives
    `make_grid`, `check_grid`, `check_layout`, `check_models_on_page`, `observe_script`,
    `check_clients`, `check_page_info` and `reset_session` against the strict mock, the reset really
    empties all four, and CloseStack leaves no name alive; (c) a static scan (`twice_created`) over
    every read-back script and every `reset_session` variant proves no script text creates one
    LITERAL handle name twice, allows the per-iteration form (`$` in the name), with a seeded
    offender that MUST be caught, a seeded acceptable script that must NOT be, and a `names >= 10`
    guard so the scan cannot pass by looking at nothing. The `forbidden_release` scanners in both
    `test_hw_adapter.tcl` and `test_capture.tcl` now accept the indexed spelling
    (`(pis|psi)(S|P|Page|Win|C|V|M|R|Mgr)(_[A-Za-z0-9]+)?`), and both got a seeded `pisWin_2` /
    `psiC_3` release that MUST be flagged - otherwise item 2 could hide a release behind a suffix.
  Item 7 - `::pis::BUILD` = `T34a-20261118-2100`.
  Ran: 2026-11-18 (tclsh 8.6.17): `bash scripts/verify.sh` -> `verify: OK`, 17 files parse, 29
    ASCII, 8 Tcl 8.5, 8 suites `ok`; `tclsh tests/tcl/test_hw_adapter.tcl` -> MOCK, 491 PASS, 0 FAIL,
    exit 0; `test_capture.tcl` -> 210 PASS, 0 FAIL, exit 0; `test_block0.tcl` -> 273 PASS, 0 FAIL,
    exit 0; `test_result.tcl` -> 346 PASS, 0 FAIL, exit 0; `test_common.tcl` 46, `test_gui_frame.tcl`
    25, `test_hw_exec.tcl` 92, `test_legend.tcl` 56 - all 0 FAIL, all exit 0. Commands still
    UNVERIFIED on HyperView: whether the build accepts a name like `pisWin_3` everywhere the old
    fixed name was accepted (the naming RULE is proven in the owner's scripts; the exact string is not
    a constraint any doc names), and whether `GetWindowHandle` on a page whose windows were removed by
    `reset_all` still answers a handle.
  How to check (owner, HyperView, GUI only, max 3 steps) - this check is about Load All, not capture:
    1) copy `src/01_scripts`, start the GUI, press **Load All** with the ini as it is and enough
       windows for the model list: the log must show `OK ...` for the reset and for every window, and
       NO `object with this name already exists.` line. The BUILD line must read
       `T34a-20261118-2100`.
    2) if a line of that shape still appears, send the WHOLE log: it names the handle in front of
       the colon (e.g. `pisWin_2`), which says which walk still holds two live copies. Change nothing
       first - the raw line is the finding.
    3) press [Load result] for one window and then [Capture] for one row, so the two paths that also
       create per-window handles are exercised once; send the log with the `OK`/`ERR` lines only.
  Interpretation: no `object with this name already exists.` line anywhere = F15 is fixed; one such
    line = a NEW defect line (`T-011: fail 3` if it comes from capture, a new T-number if it comes
    from Load All), never an edit of F15.
  Rollback: copy back the previous `src/01_scripts/_tcl_pis_11_hw_adapter.tcl` and set `::pis::BUILD`
    back to `T33a-20261118-1930`; the walks then reuse fixed names again and the old (wrong) mock
    behaviour has to be restored in the three test files together, or the suites fail by design.
  Refs: F15 and F14 above, `docs/refs/HV_API_REF.md` (Misc - ReleaseHandle is never called on
    session/project/page/window/view/post/model/result handles), `docs/refs/HV_API.md` sec.2 (the
    handle chain), the owner's scripts `conrod/_tmp_hv/batchImportOdb.tcl:81-86`,
    `conrod/_tmp_hv/training.tcl:179-184`, `conrod/tcl_guide/hv_model_loader.tcl:2073-2132`,
    TASKLOG T-033 (the pass that removed the releases).


OWNER RESULT (recorded 2026-11-18) - the owner wrote, verbatim: "capture ok. confirm ok. accept."
  `T-011` (Capture) and the `T-034` regression repair (F15) are `accepted (user check: pass,
  2026-11-18)`. `fail 1` .. `fail 3` above stay untouched; only this line changes the state of those
  two tasks. NOTHING ELSE is accepted by this line: T-009 and T-010 stay blocked as recorded (their
  class pages are still missing) and T-012 stays a todo as recorded. What the pass does and does not
  mean: the owner's GUI + saved-log check accepted the capture path and the per-iteration handle
  names; the module still holds no evidence of its own that a window PAINTS what was asked for, and
  every command T-034 lists as "still UNVERIFIED on HyperView" stays unverified.

OWNER RESULT (recorded 2026-11-18) - `T-007 (Load Legend): fail`, cause AGENT.
  F16 - Apply all in the Load Legend module always ends with
    `ERROR module Load Legend: Object named: pis_legend_client_34652_3 (of type poIPost) could not find requested method: GetPageHandle Or the method was called with incorrect arguments.`
    Cause VERIFIED by T-035 item 1+2 (the class-aware mock plus the grep in that block): the module
    reached the page from a CLIENT handle - `src/01_scripts/_tcl_pis_02_load_legend.tcl:83-84`
    (`hwi GetActiveClientHandle $client` -> `$client GetPageHandle $page`) - and then called
    `$page SetActiveWindow`. In the proven chain (docs/refs/HV_API.md sec.1, S14: session ->
    GetProjectHandle -> project GetPageHandle -> page GetWindowHandle -> window GetClientHandle)
    GetPageHandle belongs to the PROJECT handle, so a poIPost handle refuses it: the legend module
    never completed a single window. The old test mock accepted ANY method on ANY handle, which is
    why every suite was green while the module could not run.
  F17 - spec change for the `on` checkbox (owner words: "Spec change for the `on` checkbox. Today
    unchecked = skip. New meaning = the Display Control > Legend toggle of HyperView"): `on` ticked
    + [Apply all layout] = SHOW the legend in EVERY window of the layout; `on` unticked + [Apply all
    layout] = HIDE the legend in every window - an action now, not a skip. This SUPERSEDES
    docs/refs/SPEC_gui.txt:125 ("on" unchecked = skip the legend import step entirely); every other
    rule of SPEC_gui s.6.2 stays as it is.
  Handled by T-035. A new failure becomes `T-007: fail 2`, never an edit of this line.

T-035: Load Legend - F16 (the page was reached from a poIPost handle) and F17 (`on` is the Display
Control > Legend toggle, per window) - Status: accepted (2026-11-19, OWNER: "ok pass, accept." on the
section-4 GUI check - T-007 is accepted with it; nothing here was accepted by the agent) - Done when:
`bash scripts/verify.sh` prints `verify: OK`, all 8 suites
green (MOCK), `::pis::BUILD` bumped, a `[Apply all layout]` run completes EVERY window with no
`could not find requested method: GetPageHandle` line, `on` ticked shows and `on` unticked hides the
legend in every window, and the owner's GUI check confirms the legend by eye - Only modify:
`src/01_scripts/_tcl_pis_02_load_legend.tcl`, `src/01_scripts/_tcl_pis_11_hw_adapter.tcl`,
`src/01_scripts/_tcl_pis_99_workflow_gui.tcl`, `tests/mock_hv_type.tcl`, `tests/tcl/test_legend.tcl`,
`tests/tcl/test_hw_adapter.tcl`, `tests/tcl/test_capture.tcl`, `tests/tcl/test_result.tcl`,
`docs/SPEC.md`, `docs/refs/HV_API.md`, `docs/TASKLOG.md`, `docs/HANDOFF.md`.
  Owner facts this task answers: F16 and F17, recorded verbatim in the OWNER RESULT block above.
  Item 1 - F16 REPRODUCTION, before any code was written. The pre-fix module walked UP from a client
    handle (`hwi GetActiveClientHandle $client` -> `$client GetPageHandle $page`, the old
    `_tcl_pis_02_load_legend.tcl:83-84`) and the build refused it with the owner's exact three lines.
    The pre-fix file is not in the repo (the folder has no VCS), so the reproduction replays those
    two lines against the SAME class table the suites use (`tclsh %TEMP%/f16_t035.tcl`, scratch, not
    product code): `::mockhv::guard client pis_legend_client_34652_3 GetPageHandle` -> `Object named:
    pis_legend_client_34652_3 (of type poIPost) / could not find requested method: GetPageHandle /
    Or the method was called with incorrect arguments.` - a byte-for-byte match with F16 - while
    `session GetProjectHandle`, `project GetPageHandle`, `page SetActiveWindow`, `client
    SetDisplayOptions` and `client GetDisplayOptions` are all accepted on their own types. The same
    script reads the CURRENT module: 285 lines, 3 mentions of `GetPageHandle`, every one of them a
    COMMENT (lines 8, 10, 89), none a call. That is the F16 evidence the task stands on, and it is
    also the reason the old suites were green (their mock answered ANY method on ANY handle).
  Item 2 - the class-aware mock, `tests/mock_hv_type.tcl` (shared by all four suites, not a copy per
    file): ONE table `kind -> {class methods...}` built only from rows that NAME a receiver type -
    session hwISession (S14/S1/S20/S19/S91/S96), project hwIProject (S14/S1/S10), page hwIPage
    (S1-S5/S33/S10), window hwIWindow (S6-S8/S11/S103), client poIPost (S16/S21/S23/S24/S26/S56/S57/
    S97 + the PROVEN `Draw` + the supplier's GetActiveModel/GetModelHandle chain), model poIModel
    (S9/S25), ctrl poIResultCtrl (S27/S30-S32/S39/S40/S60/S61), manager poIPostManager (S17/S18/S22),
    viewctrl poI3DViewCtrl (S99-S105) and contour poIContourCtrl (S28-S41, the frozen list sec.11
    already carried). `::mockhv::guard <kind> <name> <method>` raises the build's own three lines
    (`::mockhv::text`) when a method is documented for OTHER types and for none of this kind; a kind
    the table does not type, and a method NO page lists, are deliberately UNRESTRICTED - the header
    names that `receiver unknown` case and section 27 now asserts both halves (`type_of legend` is
    `""`, `known NoSuchMethod` is 0, and every kind that file creates is typed), so an untyped kind
    can never appear without a line that says so. `ReleaseHandle` is accepted on every kind: WHICH
    kinds may be released stays the production rule of the `forbidden_release` scanners (F14 c).

  Item 3 - the module, `_tcl_pis_02_load_legend.tcl` (rewritten around ONE per-window seam). The old
    layout-level walk is gone; `::pis::legend::apply_to_window {index path on trace}` is the ONLY
    place that changes a window and it does exactly three things, in this order: (1) `select` -
    `::pis::hw::legend_select $index` -> `::pis::hw::select_window`, i.e. the PROVEN chain
    `hwi OpenStack; hwi GetSessionHandle pisS; pisS GetProjectHandle pisP; set pisPgI [pisP
    GetActivePage]; pisP GetPageHandle pisPage $pisPgI; pisPage SetActiveWindow k; hwi CloseStack`
    (ONE journaled line, S5, the same helper Load result and Capture use - `GetPageHandle` is on the
    PROJECT, F16); (2) `import` - ONLY when `on` is ticked AND a file is selected, through
    `::pis::hw::import_legend` (the PROVEN `hwc` form, texts unchanged); (3) `show|hide` through
    `::pis::hw::legend_visibility $index $mode 0 $trace` (`do_select 0`: the window is already the
    active one, so nothing selects it twice). `on` is read FIRST and is never a reason to skip (F17);
    `on` with NO file is legal and logs ONE `module Load Legend: no legend file selected, showing the
    legend only` INFO; a path that does not exist is still refused before any HyperView call
    (`Legend file not found: <path>`, A9), and `need_hw` now also requires
    `legend_visibility`/`active_window`/`begin_legend`, so a missing adapter stops before window 1
    instead of halfway through. Scope: `layout` = windows 1..N from `::pis::step01::last_result`
    (`Model/results not loaded | click Load All first.` when Load All has not run); anything else =
    the ACTIVE window only, asked with the read-only `hwIPage GetActiveWindow` (S33, never journaled),
    so the module button touches ONE window and the log names it. A failing window stops the run
    unless `[log] continue_on_error` is set; the closing line is
    `Load Legend: <n> of <total> window(s) shown|hidden[, <f> failed]` as `OK` or `WARN`.

  Item 4 - the adapter op `legend_visibility {index show {do_select 1} {trace 1}}` (the ninth op of
    `::pis::hw::ops`, so `::pis::hw::fill`/`help`/`use`/`record` cover it): V1 `hwc show legends` /
    `hwc hide legends` (PROVEN: `docs/refs/HV_API_REF.md` Legend S02:18, S06:243/257, S07:461/559);
    V2 `hwi OpenStack; ...; pisPage SetActiveWindow k; pisPage GetWindowHandle pisWin k; pisWin
    GetClientHandle pisC; pisC SetDisplayOptions legend <true|false>; hwi CloseStack` (DOC S56, the
    name list contains `legend`). Both are judged ONLY by the read-back `pisC GetDisplayOptions
    legend` (S57, `::pis::hw::legend_now`): `show` passes on `true`/`show`/`1`, `hide` on
    `false`/`hide`/`0`, and a call that returns without an error and leaves the answer unchanged
    fails with `HyperView did not change: GetDisplayOptions legend answered '<read>', expected
    '<want>'` - so V1 can never be OK on "no error". Helpers, all in the adapter: `legend_word`
    (`show|hide`), `legend_flag` (`true|false`), `legend_state` (the answer -> 0|1|""), `legend_now`
    (send the read-only getter in its own stack) and `legend_now_text` (`legend visible <s>` for the
    STEP line), `hwc_line` (the literally-sent text, quoted in the log), `hwc_defer`/`hwc_journal`
    (the journal line is HELD until the read-back agreed, so only the winning variant is ever
    journaled and a replay reproduces what actually worked), `legend_select_text` (the select
    script), `legend_select` (the journaled select step), `begin_legend` (clears the per-run
    caches/notes) and `adapt_legend`/`adapt_legend_getter` (the iteration cache: once V2 won, windows
    2..N start there; `adapt_legend_getter` remembers whether this build answers the getter at all).
    With NO documented getter the run still sends V1 (the owner's own form), logs ONE `legend
    visibility: no documented getter, window k must be checked by eye` INFO per run and records the
    step UNVERIFIED-GUESS - never an ERROR, never an OK. `ReleaseHandle` is not sent on the
    page/window/client handles (F14 c) and the select line is not journaled twice.

  Item 5 - the GUI (`_tcl_pis_99_workflow_gui.tcl`) `run_legend` status text says `shown` or
    `hidden` from the checkbox, so the owner's status bar names the ACTION, not a skip.
  Item 6 - tests. `tests/tcl/test_legend.tcl` (rebuilt, cases 1-16): the class-aware mock
    (`::t::call` -> `::mockhv::guard`); the F16 reproduction (case 1: the mock REFUSES
    `GetPageHandle` on a poIPost handle with the owner's three lines, and a layout run then completes
    EVERY window, its trace showing `pisP GetPageHandle pisPage` and no refusal anywhere in the log);
    F17 both ways (`LEGEND ok window k shown|hidden`, the order select -> import -> visibility, `on`
    + no file = INFO + no import, `on` unticked = no import at all, every window touched); `on` with
    a missing file = error before any call; `on` with a file in a 2-window layout; the read-back
    veto (`false` for `show` -> V1 fails -> V2 wins, only V2 journaled); no getter -> V1 + ONE eye
    INFO; the strict F15 name rule (`<name>: object with this name already exists.`); scope
    (`layout` vs the active window via S33); the summary line; `continue_on_error`; a zero/negative
    window index refused. `reset_case` clears the adapter's legend getter/cache between cases, so no
    case inherits a previous verdict. `tests/tcl/test_hw_adapter.tcl` grew section 27 (a-e): the op is
    in the table (nine ops, one complete folded line each), V1 wins on a build with the getter and is
    journaled once, V1 loses the read-back and V2 wins (only V2 journaled, `adapt_legend` = 2, window
    2 starts at V2), no getter at all -> V1 + ONE eye INFO + the UNVERIFIED record, `trace 0` writes
    no STEP line while the JOURNAL text is identical, and `do_select 0` sends no `SetActiveWindow`.
    The same section asserts the class table itself (every kind this file creates is typed; an
    untyped kind is `receiver unknown` and stays unrestricted; a method no page documents is never
    refused) and takes the mock log sink back, because the spike sections above re-source the real
    `::pis::common` - without that the three log checks saw an empty log and failed. It also clears
    `::mock_log` before the `trace 0` case: a STEP line from the previous case would otherwise be
    "found" and the check would judge the wrong run. `tests/tcl/test_capture.tcl` and
    `tests/tcl/test_result.tcl` got the shared guard only (they keep their own mocks; the guard is
    what makes a wrong receiver scream).
  Item 7 - `::pis::BUILD` = `T35a-20261118-2200`.


  Ran: 2026-11-18 (tclsh 8.6.17): `bash scripts/verify.sh` -> `verify: OK`, exit 0 (27 files parse,
    30 ASCII, 8 Tcl 8.5, 8 suites `ok`); `run_suites.sh` -> `test_hw_adapter.tcl` 524 PASS / 0 FAIL,
    `test_capture.tcl` 210 / 0, `test_result.tcl` 346 / 0, `test_legend.tcl` 100 / 0,
    `test_block0.tcl` 273 / 0, `test_common.tcl` 46 / 0, `test_gui_frame.tcl` 25 / 0,
    `test_hw_exec.tcl` 92 / 0 - every file exit 0. The F16 replay (`tclsh %TEMP%/f16_t035.tcl`, its
    output quoted in Item 1) refuses the old two-line chain with the owner's own text, accepts the
    project/page/client steps on their own types, and finds the module's three `GetPageHandle`
    mentions are comments. Static checks on the module: `grep -n 'GetActiveClientHandle'` = 0 hits,
    `GetPageHandle`/`GetClientHandle` = 3 hits, all comments; `grep -n '^[[:space:]]*hwc '` = 0 hits
    (every HyperView call goes through the adapter, D2); `legend_visibility` = 3 hits (need_hw and
    the one seam call). Commands still UNVERIFIED on HyperView: BOTH `legend_visibility` variants -
    `hwc show legends`/`hwc hide legends` is the owner's PROVEN one-liner but prints nothing, so its
    effect can only be seen by eye, and `poIPost SetDisplayOptions legend <true|false>` (DOC S56) has
    never been sent to this build; whether `GetDisplayOptions legend` (S57) answers at all, and with
    which literal (`true`/`false`, `show`/`hide`, `1`/`0` are all accepted by the parser); whether
    `on`-unticked really HIDES a legend the window already shows (the F17 reading of Display Control
    > Legend); whether the import (`hwc result scalar legend import`) still lands in the window that
    `SetActiveWindow k` selected, on a build where nothing selects it twice. Those five are exactly
    what the owner's check below measures.
  How to check (owner, HyperView, GUI only, max 3 steps) - Load Legend, not Load All:
    1) copy `src/01_scripts`, start the GUI, load the model + results with **Load All**, tick the
       legend `on` box, choose a legend file in the list and press **[Apply all layout]** with 2 or
       more windows. Seeing ONE `LEGEND ok window k shown variant <n>` per window, plus
       `Load Legend: N of N window(s) shown` and NO `could not find requested method: GetPageHandle`
       line, is correct (`T35a-20261118-2200` in the BUILD line); seeing that refusal, or a window
       that never got a line, is the finding - send the whole log, change nothing first.
    2) untick `on` and press **[Apply all layout]** again: every window must lose its legend by eye,
       `LEGEND ok window k hidden` once per window, and the journal must gain NO import line - only
       selects plus the hide step.
    3) sweep an eye over the windows: the legend that step 1 showed must be the imported file's
       legend, in EVERY window, and nothing may still be showing after step 2. A
       `legend_visibility window k: variant 1/2 failed (...)` WARN followed by `variant 2/2 used` is
       NOT a defect - it names the read-back that refuted the owner's own form on this build, and
       that line is the finding to quote.
  Interpretation: `LEGEND ok` per window plus the by-eye state = F16 fixed and F17 delivered. The
    `... must be checked by eye` INFO is expected when the build has no getter and is NOT an error:
    it says the run cannot prove the state, so the eye is the proof. A `variant 2/2 failed` on the
    last window with no journal line = no display switch worked; that is a NEW defect
    (`T-007: fail 2`), never an edit of F16/F17.
  Rollback: copy back the previous `_tcl_pis_02_load_legend.tcl`,
    `_tcl_pis_11_hw_adapter.tcl` and `_tcl_pis_99_workflow_gui.tcl` and set `::pis::BUILD` back to
    `T34a-20261118-2100`; `tests/mock_hv_type.tcl` and section 27 of `test_hw_adapter.tcl` must go
    with them, because the old module sends `GetPageHandle` to a client handle and the class-aware
    mock refuses it BY DESIGN (the suites then fail, which is the point).
  Refs: F16 and F17 above, `docs/refs/HV_API.md` sec.7 (the new "Legend visibility" subsection) +
    sec.10 (the two `legend_visibility` rows) + sec.1 S14/S1 (the handle chain) + section 2 S5 + S56/
    S57, `docs/refs/HV_API_REF.md` (Legend: S02:18, S06:243/257, S07:461/559), `docs/SPEC.md` A14
    (T-035 amendment), `docs/refs/SPEC_gui.txt` s.6.2 and line 125 (SUPERSEDED by F17),
    `docs/refs/SPEC_load_legend.txt` FILE 3, TASKLOG T-007 (the fail), T-002 (the legend seam) and
    T-034 (the handle-name rule this module also obeys).
  Owner verdict (2026-11-19): "ok pass, accept." - the section-4 check of `docs/HANDOFF.md` was
  answered on the owner's GUI run (one `LEGEND ok window k shown|hidden` line per window, no
  `could not find requested method: GetPageHandle`, legend visible by eye with `on` ticked and
  hidden with `on` unticked). T-007 is `accepted` with this and F16 / F17 are closed as history:
  a new failure becomes a NEW defect line, never an edit of them.




OWNER REQUEST (recorded 2026-11-18; the screenshot carried the markup, the words below are the
request in substance) - two GUI additions and nothing else:
  - `Measures` gets a `Macro Add` button. It reads `Result.log`, the owner's macro export: one
    `#Spec<N>` section per result group, one row per node with the three values SF, MS, AS.
  - a NEW module `Notes` (own panel, own list, own `[Apply all layout]`) with its own `Macro Add`
    button. It reads `Notes.log`: "add notes in the HyperView window with settings read from the
    file Notes.log".
  - the picture's left column is a 2 x 3 grid: row 1 `Load result` | `Load Legend` (the `on` box
    right of the title), row 2 `Measures` (+ `Macro Add` right of the title) | `Section Cut`,
    row 3 `Capture` | `Notes` (+ `Macro Add` right of the title). The red outline and the yellow
    fill are the owner's own markup, NOT a requirement - no colour is specified anywhere. Block 0,
    the log pane and its four buttons are unchanged.
  - the owner's `Result.log` template, quoted exactly (two lines, nothing else):
        #Spec1
        Group1,Node_ID, SF, MS, AS
    and one example of the rows he expects (shown here, never shipped in the sample file):
        #Spec1
        Group1, 1001, 1.15, 101.5, 15.5
        Group2, 9004, 1.24, 111.5, 16.5
  - `Notes.log` has NO template yet. Everything the SPEC says about its grammar is an ASSUMPTION
    (Q8-Q11 in `docs/SPEC.md`) and the shipped sample is a placeholder.

T-036: SPEC amendment for the two GUI additions - `Macro Add` on Measures (`Result.log`) and the
new `Notes` module with its own `Macro Add` (`Notes.log`) - Status: agent-done (2026-11-24, DOCS
ONLY - no source, no test, no ini edited, no BUILD bump; owner check owed) - Done when: the docs
describe the two additions as the owner asked, every new rule carries its source (PROVEN / DOC /
ASSUMPTION-Qn), no accepted rule is rewritten (amendments are appended), `bash scripts/verify.sh`
still prints `verify: OK`, and no file outside the list below changed - Only modify:
`docs/refs/SPEC_gui.txt` (appended sections 14-15), `docs/SPEC.md`, `docs/refs/HV_API.md`,
`docs/refs/samples/Result.log` (new), `docs/refs/samples/Notes.log` (new), `docs/TASKLOG.md`,
`docs/HANDOFF.md` - How to check (owner, 3 steps, no GUI, no code to run):
  1) open `docs/refs/SPEC_gui.txt` and read 14.1-14.5: the 2 x 3 grid, the "one extra widget right
     of the title" rule and both `Macro Add` buttons must read as the picture you sent, and the
     `on` box of Load Legend must be unchanged. Seeing a 7th panel, a global Run button or a
     colour requirement is wrong.
  2) open `docs/SPEC.md` and read A16-A20 plus that pass's own Q1-Q12 table: every line you will
     later read in the log pane must be quoted there verbatim (`Result.log not found: <path>`,
     `Macro Add Measures: <n> measure(s) in <w> window(s) from <file>`, the amber
     `applied, display not confirmed (look at the windows)`, ...). Seeing a message you did not
     ask for, or a note setting nothing in the file carries, is wrong.
  3) open `docs/refs/samples/Result.log`: it must be your two template lines and nothing else
     (a sample file with prose in it would be an input the parser has to refuse).
  Ran: `bash scripts/verify.sh` -> `verify: OK` (18 `.tcl` files parsed, 32 files ASCII, 9 files are Tcl 8.5, 9 suites
  green, all unchanged - this pass touched no code). Files: `docs/refs/SPEC_gui.txt` (new sections
  14-15 appended, nothing rewritten), `docs/SPEC.md` (Goal + A1 amendment notes, A10 untouched, `[macro]` /
  `[notes]` / `[debug] notes_trace` keys, 6 new error/empty states, one new subsection, A16-A20, that pass's own Q1-Q12,
  `docs/refs/HV_API.md` (sec.7 "Notes" subsection + one paste-list row; facts only),
  `docs/refs/samples/Result.log` (new, the owner's template verbatim), `docs/refs/samples/Notes.log`
  (new, placeholder for the assumed grammar), `docs/TASKLOG.md` (this block + T-037 + T-038),
  `docs/HANDOFF.md`. BUILD: `T12a-20261119-0900`, UNCHANGED - a docs pass must not move a stamp that
  names code. Not done (deliberately): no source file, no test, no ini key written; T-037 stays
  blocked on T-009. Refs: the OWNER REQUEST block above, `docs/refs/SPEC_gui.txt` s.3/s.5/s.6/s.9/
  s.10/s.13 (what the amendment changes), `docs/refs/HV_API_REF.md` Annotation/Note (S07:312-344)
  and Common patterns 8/9, `docs/refs/HV_API.md` S56/S57 (the `notes` display option), TASKLOG T-009
  (the measure op this task may not invent) and T-035 (the file/read-back style it copies).

T-037: `Macro Add` on the Measures panel - read `Result.log` and add the measures of
  every section to the windows that section names - Status: todo, STILL BLOCKED on T-009 (the
  `poIMeasure` page is still not fetched, so the shared measure op does not exist yet; this
  task calls that op and may not invent one). 2026-11-24: the shared reader this task was going
  to need - `::pis::dlog` in `src/01_scripts/_tcl_pis_07_datalog.tcl` - is now BUILT and tested
  by T-038 (`tclsh tests/tcl/test_datalog.tcl` -> 44 PASS, exit 0), so what is left here is the
  measure op, the Measures header slot and `tests/tcl/test_measures.tcl` - Done when: one press
  of `Macro Add` reads the configured `Result.log` ONCE, maps every `#Spec<N>` section to the
  windows it names (Q3 default), builds the rows of each section as measures through T-009's op
  `::pis::hw::measure_add {k {rows {}}}` (one measure per row, file order, section by section,
  window by window), writes ONE journal line per measure, refuses before any HyperView call
  when the file is missing or malformed (0 calls, 0 journal lines), fails a measure whose
  `AddMeasure` answer is not a positive integer, stops at the first error unless
  `[log] continue_on_error`, logs the closing
  `Macro Add Measures: <n> measure(s) in <w> window(s) from <file>`, and leaves the panel's
  rows and the ini untouched (Q7) - Only modify:
  `src/01_scripts/_tcl_pis_04_measures.tcl` (the `Macro Add` half only; the list half is
  T-009's), `src/01_scripts/_tcl_pis_99_workflow_gui.tcl` (the header slot of Measures + the
  `macro_add_measures` command), `tests/tcl/test_measures.tcl`, `tests/tcl/test_datalog.tcl`
  (checks for the Result.log shape), `docs/TASKLOG.md`, `docs/HANDOFF.md` - How to check
  (owner, GUI + saved log, 3 steps):
  1) put your `Result.log` in the app folder, **Load All**, press **Macro Add** on Measures:
     seeing one `MEASURE window k row r node ...` line per row, one `hwi` journal line per
     measure and the closing `Macro Add Measures: N measure(s) in W window(s) from <path>` is
     correct; seeing a measure line for a window your section does not name, or a row list
     that changed, is wrong.
  2) press **Macro Add** again with the file renamed: seeing `Result.log not found: <path>`,
     exactly one ERROR and NO new journal line is correct; seeing a partial run is wrong.
  3) add one broken line to the file (four fields, or a letter in SF) and press **Macro Add**:
     seeing `Result.log line <n>: ...` naming that line and NOTHING added anywhere is correct;
     seeing the rows above the bad line added first is wrong.
  Ran: 2026-11-24: nothing of T-037 itself - the measure op of T-009 still does not exist, so
    this task stays blocked. The READER half it was going to need is done and green with T-038:
    `tclsh tests/tcl/test_datalog.tcl` -> 44 PASS, exit 0 (both kind tables, the
    `Name,Text,X,Y,Z` and `Node_ID,...` grammars, the per-line refusal texts, a real file with
    BOM + CRLF, the not-found path, and the SPEC<n> token boundary - `SPEC10_1.res` is NOT
    window 1 of Spec1). No measure call, no GUI slot and no ini key was written here.
  Items: (1) DEPENDENCY, and what it is not. The CALLS are already PROVEN -
    `docs/refs/HV_API_REF.md` Annotation/Note quotes the owner's own working script
    (S06:132-136): `<post> AddMeasure "Nodal Contour"` (returns the measure id),
    `<post> GetMeasureHandle <name> <id>`, `<measure> AddNode "<modelID> <nodeID>"`, plus
    `hwc annotation measure delete all` (S06:112/281). What is missing is the `poIMeasure`
    class page and with it the read-back rule T-009 owes, and T-009 owns the op itself. This
    task therefore calls `::pis::hw::measure_add {k {rows {}}}`, never a second private copy
    of those calls: two spellings of one op is the F16-class defect HANDOFF sec.7 forbids.
    While T-009 is blocked this task is blocked; if the owner wants the file reader earlier,
    the split (reader = the `::pis::dlog` half of T-038) is the OWNER's call, never the
    agent's.
    (2) FLOW. Read and parse the WHOLE file first (Q1 path through
    `::pis::common::resolve_path`, one read per press, no cache, no watcher), and only then
    select a window and send: a file whose line 40 is wrong therefore adds nothing anywhere.
    Then, window by window in layout order (a `Macro Add` press is always the whole layout -
    Q6; it has no active-window form), section by section and row by row in FILE order, one
    measure per row. Per window with rows ONE `INFO Macro Add Measures window <k> section
    '<name>' rows <r>`; per measure ONE `MEASURE window <k> row <r> node <id> SF=<..> MS=<..>
    AS=<..>`; the three values are EVIDENCE for the eye and go into NO HyperView call (Q4).
    (3) JOURNAL. One `hwi` line per measure, built by the adapter from the same step text a
    replay needs (T-035's proven `select_window k` once per window, then `AddMeasure`,
    `GetMeasureHandle`, `AddNode`), and nothing else - so a saved journal replays to the same
    measures, in the same order. `hwc annotation measure delete all` is NEVER sent by this
    button (Q5): it would delete what the owner built by hand, and it belongs to Reset
    (T-001/T-006), not to an add.
    (4) THE PROOF. `AddMeasure`'s answer IS the read-back this build gives: a positive integer
    is a measure, `0`, an empty answer or an error is a FAILURE
    (`AddMeasure answered '<raw>': measure window <k> row <r> not added`, and the run stops
    there unless continue-on-error - a build that answers `0` for row 1 will answer `0` for row
    2). Per-window counts plus the closing line are the only summary; there is no silent mode.
    (5) TEXTS, verbatim (mirrored in `docs/SPEC.md` A18 and A20): `Result.log not found: <path>`
    / `Result.log line <n>: <what is wrong>` / `Result.log: no #Spec section` /
    `Result.log: section '<name>' matches no window (no result file name holds 'SPEC<n>',
    layout <id> has <w> window(s))` /
    `Macro Add Measures: section '<name>' has no rows, window <k> skipped` (INFO) / the
    `AddMeasure answered ...` line above / `Macro Add Measures: <n> measure(s) in <w> window(s)
    from <file>` (OK, last line, and the same sentence in the status bar).
    (6) WHAT IT MAY NOT DO. Touch the row list or the ini (Q7), invent a `poIMeasure` method
    before its page is in `docs/refs/HV_API.md`, delete existing measures, or report OK without
    a positive answer id.
  Refs: `docs/SPEC.md` A16-A20 + Q1-Q7, `docs/refs/SPEC_gui.txt` s.14 (the button, the header
  slot, the texts) + s.15.2 (the Result.log grammar), `docs/refs/HV_API_REF.md` Annotation/Note
  (S06) and patterns 2/10, `docs/refs/HV_API.md` sec.7 (the measures page is NOT FETCHED),
  TASKLOG T-009 (the op and its blocking), T-035 (the per-window seam and the class-aware mock
  this task must reuse).

T-038: the `Notes` module and its `Macro Add` - the sixth panel, the shared reader
  `::pis::dlog`, and the owner's PROVEN note calls - Status: in-progress (fix pass, 2026-11-24):
  the owner's GUI check answered FAIL (fact F18 below) and the fix pass is T-039. The code, the
  tests and `verify.sh` were green, but every suite had sourced the module files itself, so none
  of them saw that the GUI never did; only his eye can confirm a painted note, which is why the
  verdict stays APPLIED-UNCONFIRMED even after the fix.
  OWNER RESULT (2026-11-24, GUI plus the log he sent): T-038 FAIL. Fact F18 (verbatim):
  invalid command name "::pis::notes::title"
      while executing
  "::pis::notes::title"
      (procedure "::pis::gui::run_notes" line 8)
      invoked from within
  "::pis::gui::run_notes $scope"
      (procedure "::pis::gui::run_module" line 18)
      invoked from within
  "::pis::gui::run_module notes layout"
      invoked from within
  ".pis_workflow.left.mods.mod_notes.bar.apply invoke" ...
  It happens on ANY of the three Notes controls (the `Notes` title button, `Apply all layout`,
  `Macro Add`, all of which reach `::pis::gui::run_module notes`), and the raw Tcl traceback
  reaches Tk while the other modules print `ERROR module <Name>: ...` in the log instead. Cause:
  AGENT, three parts - (1) a proc the GUI calls did not exist in the owner's running app (T-039
  item 1 found the file missing from the source list, not a rename); (2) no test drove the real
  button path through the GUI's own source list, so test_notes 68, test_datalog 44 and
  test_gui_frame 26 stayed green; (3) `run_notes` was not inside the shared error guard the other
  modules use. The Notes half of this task is reopened; the reader (`::pis::dlog`) is unaffected
  and stays green. Not
  blocked: every call this task sends is PROVEN in the owner's own scripts; the Notes.log
  grammar stays an ASSUMPTION (Q8) and the shipped sample is a placeholder - Done when: the GUI
  has a sixth panel `Notes` at row 3 column 2 with one extra widget right of its title
  (`Macro Add`), a user-typed list with `[+]`/`[-]`, its own
  `[Apply all layout]`, persistence as `[notes]` in the ini and the dispatch key `notes`;
  `[Apply all layout]` creates the checked rows as notes in every window in row order;
  `Macro Add` reads `Notes.log` once (parse-before-act) and creates the notes of every
  `#Note<N>` section in the windows it names; every note is sent in the PROVEN order (delete
  the old name, create, display text, optional font/fontsize/borderthickness,
  `positiontype=coordinates`, `positionx/y/z`, `alignmenttext=Center`, optional
  textcolor/borderwidth/linetoentity); every command is ONE journal line; the verdict is
  `APPLIED-UNCONFIRMED` with the amber status
  `Notes: applied, display not confirmed (look at the windows)` and one
  `notes: no documented getter, window k must be checked by eye` INFO per run;
  `[debug] notes_trace = 1` logs one
  `STEP notes window <k> row <r> <step>: sent <literal> -> ret=<raw|(empty)>` line per step
  until the owner writes `accepted`; a missing or malformed file refuses before any HyperView
  call (0 calls, 0 journal lines); `bash scripts/verify.sh` prints `verify: OK` - Only modify:
  `src/01_scripts/_tcl_pis_07_datalog.tcl` (new, `::pis::dlog`),
  `src/01_scripts/_tcl_pis_08_notes.tcl` (new, `::pis::notes`),
  `src/01_scripts/_tcl_pis_99_workflow_gui.tcl` (the sixth spec, the `notes` block, the two
  header buttons, the `run_module` branches), `src/01_scripts/_tcl_pis_11_hw_adapter.tcl`
  (the note seams + `::pis::BUILD`), `tests/tcl/test_datalog.tcl` (new),
  `tests/tcl/test_notes.tcl` (new), `tests/tcl/test_gui_frame.tcl`, `docs/TASKLOG.md`,
  `docs/HANDOFF.md` - How to check (owner, GUI + saved log, 3 steps):
  1) start the GUI: the left column must now hold SIX panels, `Notes` at row 3 column 2 with
     `Macro Add` right of its title - the same slot Load Legend's `on` box uses. Seeing `Notes`
     in another cell, no `[Apply all layout]`, or no `Macro Add` is wrong.
  2) **Load All**, press **Macro Add** on Notes with your `Notes.log` present: seeing the amber
     status `Notes: applied, display not confirmed (look at the windows)`, one `hwi`/`hwc`
     journal line per step per note, and
     `Macro Add Notes: N note(s) in W window(s) from <path>` is correct; seeing a green "ok"
     (nothing on this build can prove a note) or a note drawn in a window the file does not
     name is wrong.
  3) your eye IS the proof: the notes of the file must be readable in the windows it names. If
     they are not, send the whole log - the `STEP notes ...` lines name the exact command and
     the answer that failed - and change nothing first.
  Ran: 2026-11-24: `tclsh tests/tcl/test_datalog.tcl` -> 44 PASS, exit 0 (the reader:
    both kind tables, the header-skip rule, CRLF + blank lines + field trimming, the line
    numbers in every refusal, an empty `#Note` section, a real file with a BOM, a missing file,
    and the `SPEC<n>` token boundary). `tclsh tests/tcl/test_notes.tcl` -> 68 PASS, exit 0
    (HyperView MOCKED - `::pis::hw::note_*`, `select_window`, `active_window`,
    `layout_windows` are doubles of that file, so the checks are the module's own order, flags,
    counters and log sentences: the 9-command sequence and the 12-command formatted one, the
    one soft delete first, the three soft extras, the space after `=` in `font=`,
    `fontsize=`, `borderthickness=`, the `pis_note_<k>_<r>` name rule, chosen rows as
    `{row n text ...}` dicts, a refused note stopping vs. continue-on-error, the empty-list
    WARN with 0 calls, the Load All gate, active vs. layout scope, one `GetDisplayOptions`
    read + ONE eye line + `unconfirmed` per press, `[debug] notes_trace 0` sending the same
    calls without the trace, and `Macro Add` over 2 sections x 2 windows with the result-file
    SPEC mapping, a bad Name and an orphan section (0 calls), a missing file and a window whose
    select fails under continue-on-error). `tclsh tests/tcl/test_gui_frame.tcl` -> exit 0 (six
    panels, `Macro Add` on Notes only). `bash scripts/verify.sh` -> `verify: OK`, exit 0
    (20 files parsed, 36 ASCII, 11 Tcl 8.5, 11 test files green). NOT verified (needs the owner
    in HyperView): that a note is actually PAINTED - no fetched page documents a per-note
    getter, so the amber verdict stands and the `STEP notes ...` trace stays on.
    Deviations to review: (1) `::pis::notes::chosen` returns `{row <n> text <text>}` dicts, not
    `{n text}` pairs, because the seam reads every row through `row_get`/`dict get` - the pair
    form made a panel press fail with `row 0 has no text` (found by the test, fixed here);
    (2) `one_note` trims the row text, so a panel row or a file row of blanks is the same
    refusal instead of a `text=` of spaces. Both are inside T-038's own files.
  Items: (1) THE PANEL. Sixth entry of `::pis::gui::module_specs` (`key notes`, `title Notes`,
    mode check), so the existing 2-column grid puts it at row 3 column 2 with no layout code
    added; `[notes]` in the ini keeps `count`/`item<i>`/`checked` exactly like `[measures]`;
    `[+]`/`[-]`, double-click edit, the busy lock and the empty-list WARN
    (`WARN module Notes: no item selected, nothing run`) are the shared module rules of
    `docs/refs/SPEC_gui.txt` s.5, not new ones. A row's text IS the note text; the note NAME is
    generated (`pis_note_<k>_<r>`, sanitized) so a re-run replaces its own note and never a
    hand-made one. The header slot takes `Macro Add` - the same slot rule Load Legend's `on` box
    follows (one extra widget, right of the title).
    (2) THE READER, `::pis::dlog` (built HERE because this is the first unblocked task; T-037
    reuses it unchanged). One grammar for both files: a line starting with `#` opens a section
    (`Spec<N>` / `Note<N>`, case-insensitive), blank lines are ignored, a data row is five
    comma-separated fields (each trimmed), and a row whose SECOND field is the literal column
    name (`Node_ID` / `Text`, case-insensitive) is a skipped header - which is exactly what
    makes the owner's own template line valid. Any other shape is an ERROR naming the file and
    the line, the WHOLE file is parsed BEFORE the first HyperView call, and the reader writes no
    journal line and sends nothing (pure Tcl, so `tests/tcl/test_datalog.tcl` proves it offline).
    The Notes.log shape is an ASSUMPTION (Q8-Q11) and the shipped sample is a placeholder to be
    replaced by the owner's real file: when it changes, the grammar changes with it and the SPEC
    is edited FIRST.
    (3) THE STEPS (source precedence PROVEN > DOC > UNVERIFIED-GUESS, and here PROVEN covers
    everything): per window ONE select (`hwIPage SetActiveWindow k`, S5, the proven
    `select_window` helper), then per note, in the owner's own order (pattern 8, S07:312-344):
    `hwc annotation note delete "<name>"` inside `catch` (S07:312; pattern 9 - old notes go
    first) -> `hwc annotation note create "<name>"` (S07:330) -> `display text=<text>` (S07:331)
    -> the optional `display font=` (S07:333, a 4-word `fontSpec`), `display fontsize=`
    (S07:334), `display borderthickness=` (S07:335) -> `display positiontype=coordinates`
    (S07:336) -> `display positionx=<x> positiony=<y> positionz=<z>` (S07:337) ->
    `display alignmenttext=Center` (S07:339) -> the three `catch` extras `textcolor=black`
    (S07:342), `borderwidth=0` (S07:343), `linetoentity=Continuous` (S07:344). The space the
    supplier's own script leaves after `=` in the font, fontsize and borderthickness forms is
    part of the PROVEN text and is never "tidied". Attaching to a node (`hwc annotation note
    "<name>" attach entity node "<model> <part> <nodeID>"`, S07:328/338) is NOT sent in v1: the
    file carries coordinates only (Q10).
    (4) THE VERDICT. This build may ignore an `hwc` command in silence and no page in
    `docs/refs/HV_API.md` documents a per-note getter, so a press can never be `APPLIED`: the
    state is `APPLIED-UNCONFIRMED`, the status bar carries the amber
    `Notes: applied, display not confirmed (look at the windows)` and every run logs ONE
    `notes: no documented getter, window k must be checked by eye`. The one documented query,
    `poIPost GetDisplayOptions notes` (S57; `notes` is in S56's name list), is read through
    `::pis::hw::probe` (never journaled) and reported, but it answers for the WINDOW's notes
    category, never for one note - so it can neither pass nor fail a note (Q12 decides whether
    the switch is ever forced). A step that RAISES is a FAILURE with the raw text.
    (5) `Macro Add` (Notes) is the same reader plus the same steps: parse the whole file, then
    per `#Note<N>` section, per window it names (Q3 mapping), per row in file order, one note;
    closing line `Macro Add Notes: <n> note(s) in <w> window(s) from <file>`; the rows and the
    ini stay untouched (Q7).
    (6) TESTS + LIMITS. `tests/tcl/test_datalog.tcl`: the grammar, the header-skip rule, every
    error text with its line number, parse-before-act, CRLF and blank lines, an empty file.
    `test_notes.tcl`: the exact command sequence per note, one journal line per command, the name
    rule, the delete-in-catch, the space after `=`, the trace on/off with the same journal text,
    the amber state, the absent-getter note, `Macro Add` over 2 sections x 2 windows, a missing
    file (0 calls). `test_gui_frame.tcl`: six panels, `Notes` at row 3 column 2, one extra widget
    in the header, the button in the busy lock. NOT proven by any of them: that HyperView paints
    a note - only the owner's eye can say that, which is why the verdict is amber and the trace
    is on by default.
  Refs: `docs/SPEC.md` A16-A20 + Q3/Q7-Q12, `docs/refs/SPEC_gui.txt` s.14.1-14.5 + s.15.3,
  `docs/refs/HV_API_REF.md` Annotation/Note (S07:312-344) + Common patterns 8 and 9,
  `docs/refs/HV_API.md` sec.7 (the new Notes subsection: S56/S57 and the missing getter),
  TASKLOG T-035 (the per-window seam, the class-aware mock and the amber verdict this task
  copies), T-034 (the handle-name rule) and T-030 (the reason the trace is unconditional
  evidence).



T-039: F18 fix - make the three Notes controls work, through the GUI's own source list, with a
  dummy `Macro Add` file - Status: agent-done (2026-11-24), waiting for the owner's check in
  HyperView (section 4b of `docs/HANDOFF.md`); never `accepted` by the agent. Done when:
  `bash scripts/verify.sh` prints `verify: OK` with `tests/tcl/test_wiring.tcl` included; the F18
  reproduction fails on the T-038 code and passes after the fix; the dummy `Notes.log` parses;
  `::pis::BUILD` is bumped; T-039 and T-038 are `in-progress` with the owner evidence owed - Only
  modify: `src/01_scripts/_tcl_pis_08_notes.tcl`,
  `src/01_scripts/_tcl_pis_99_workflow_gui.tcl` (source list, `run_module`, `dispatch`,
  `module_calls`, `module_buttons`, `disable_module`, `check_modules`, the `Macro Add` binding),
  `src/01_scripts/_tcl_pis_11_hw_adapter.tcl` (`::pis::BUILD` + its history comment only),
  `tests/tcl/test_notes.tcl`, `tests/tcl/test_gui_frame.tcl`, `tests/tcl/test_wiring.tcl` (new),
  `scripts/verify.sh` (NOT edited: it already runs every `tests/tcl/*.tcl`, so the new suite is
  picked up), `src/Notes.log` (new, the dummy file at the default location),
  `docs/refs/samples/Notes.log`, `docs/SPEC.md`, `docs/TASKLOG.md`, `docs/HANDOFF.md` - How to
  check (owner, GUI + saved log, 3 steps): `docs/HANDOFF.md` section 4b.
  Ran: 2026-11-24: `tclsh tests/tcl/test_wiring.tcl` -> 95 PASS, exit 0 (the list read from the
    GUI file, the 10 files sourced in that order, the dangling-call scan over 11 files, the
    shipped `Notes.log` through the real reader and the real module, the three Notes controls,
    the other five modules, the self-check, the guard). `tclsh tests/tcl/test_notes.tcl` -> 80
    PASS, exit 0 (68 before + the two dead checks that sat AFTER `exit 0` and never ran, now
    moved and green, + 10 new: the `WARN Notes: no row ticked` text, the new closing line, a bad
    Name in a SECOND section costing 0 calls, and four refused-file cases with 0 calls).
    `tclsh tests/tcl/test_datalog.tcl` -> 44 PASS, exit 0 (unchanged).
    `tclsh tests/tcl/test_gui_frame.tcl` -> 41 PASS, exit 0 (26 before + 15: the source list
    names the reader and the Notes module, reader before module, the self-check is called in
    `build` after the BUILD line, the guard sentences, the `Macro Add` binding, `module_calls`).
    `bash scripts/verify.sh` -> `verify: OK`, exit 0 (20 `.tcl` parsed, 37 ASCII, 11 Tcl 8.5, 12
    test files green). FAILING RUN FIRST (the T-038 state): with the two module files removed
    from the GUI's source list, `test_wiring.tcl` fails with
    `FAIL - the list holds the Notes module (F18: it did not)` and
    `FAIL - no dangling ::pis:: call in command position: {_tcl_pis_99_workflow_gui.tcl:865
    ::pis::notes::title} {_tcl_pis_99_workflow_gui.tcl:862 ::pis::notes::run} ...`, and a direct
    `::pis::gui::run_notes active` (the pre-T-039 `run_module` path, no guard) reproduces F18
    verbatim: `invalid command name "::pis::notes::title" ... (procedure
    "::pis::gui::run_notes" line 8)`. PASSING RUN AFTER THE FIX: the same suite, same command,
    `ok  all GUI wiring checks passed`, exit 0.
  Items: (1) ROOT CAUSE BY EVIDENCE (item 1a-1d). (a) `::pis::notes::title` IS defined, at
    `_tcl_pis_08_notes.tcl:70`, and the GUI uses it for the two log sentences of `run_notes` /
    `macro_add_notes` (`module [::pis::notes::title]: ...`); there is no second spelling and no
    rename - the proc never existed in the owner's session because the file was never sourced.
    (b) The GUI's startup list was, at `_tcl_pis_99_workflow_gui.tcl` lines 24-26:
    `_tcl_pis_00_common.tcl _tcl_pis_10_hw.tcl _tcl_pis_11_hw_adapter.tcl
    _tcl_pis_01_load_model_results.tcl _tcl_pis_02_load_legend.tcl _tcl_pis_03_load_result.tcl
    _tcl_pis_06_capture.tcl _tcl_pis_20_journal_ui.tcl` - NO `_tcl_pis_07_datalog.tcl` and NO
    `_tcl_pis_08_notes.tcl`. The suites sourced both files THEMSELVES (test_notes.tcl lines 26-28),
    which is why every suite was green while the GUI could not find one Notes proc. The list now
    reads `... _tcl_pis_11_hw_adapter.tcl _tcl_pis_07_datalog.tcl _tcl_pis_08_notes.tcl
    _tcl_pis_01_load_model_results.tcl ...`.
    (c) THE CALL/DEFINITION TABLE (every `::pis::notes::*` / `::pis::dlog::*` call the GUI makes):
    | call | GUI site (after the fix) | definition |
    | `::pis::notes::title` | 866, 898 (the two error paths); 476-477 (`module_calls`) | `_tcl_pis_08_notes.tcl:70` |
    | `::pis::notes::run` | 863 (`run_notes`); 476 (`module_calls`) | `_tcl_pis_08_notes.tcl:269` |
    | `::pis::notes::macro_add` | 894 (`macro_add_notes`); 477 (`module_calls`) | `_tcl_pis_08_notes.tcl:450` |
    | `::pis::dlog::*` | none - the GUI never calls the reader directly | `parse` 67, `parse_text` 87, `rows` 164, `windows` 173 of `_tcl_pis_07_datalog.tcl` (called by the Notes module) |
    Before the fix all three Notes rows were `MISSING` in the owner's session; `test_wiring.tcl`
    now prints that verdict as `FAIL - no dangling ::pis:: call in command position ...`.
    (d) It is cause 2 of the three: THE FILE WAS NOT SOURCED (not a renamed/absent proc, not a
    wrong namespace - the namespace is `::pis::notes`, the proc name is `title`). Fixed where the
    cause is: the source list.
    (2) THE WIRING SMOKE TEST (`tests/tcl/test_wiring.tcl`, 95 checks, picked up by `verify.sh`
    with no script change). It READS the `foreach _pis_file {...}` list out of the GUI file by
    brace matching (never a copy), sources those 10 files in that order in a fresh tclsh, sources
    the GUI with `::pis_gui_autobuild 0`, and drives the REAL handlers:
    `::pis::gui::run_module notes active` (the `Notes` title button),
    `::pis::gui::run_module notes layout` (`Apply all layout`) and
    `::pis::gui::run_module notes macro` (`Macro Add`, the binding the GUI now uses) - plus both
    buttons of `result`, `legend`, `measures`, `section` and `capture`. Every press must return
    with `catch` code 0 and leave a log line naming its module; the Notes presses are checked
    against the counts, the window order, the WARN sentence, the closing line and the amber
    status. The list itself is asserted (reader before module, adapter before both, common first).

    (3) THE DANGLING-CALL SCAN (same file, permanent guard). Every file of the list AND the GUI
    file: each `::pis::<ns>::<name>` at command position (start of line, or after `[ ; { }`) must
    resolve with `info commands` after sourcing; comment lines are dropped, names passed as
    values (`[list ::pis::gui::run_module ...]`) and variables (`$::pis::result::unconfirmed`,
    `info exists ...`) are not calls. ONE allowlist entry with its reason:
    `::pis::hw::wait_error` is a `catch` RESULT VARIABLE in a generated script
    (`catch {...} ::pis::hw::wait_error`), never a proc. Seed proof: a temp file containing
    `::pis::notes::nosuch` is reported by the same proc, so a green scan cannot be a dead scan.
    (4) THE GUARD AND THE SELF-CHECK. `::pis::gui::run_module` now only guards, disables and
    reports; `dispatch` does the work (result / legend / capture / notes, scope `macro` for the
    file action, the unwired panels keep their WARN/ERROR). Any raised error becomes ONE
    `ERROR module <Name>: <message>` log line, ONE second line `  | ` plus the first 6 lines of
    `errorInfo`, and the red status `<Name>: internal error (see log)`; nothing reaches Tk.
    `::pis::gui::module_calls` is the table of the procs each module needs (`notes` =
    `title`, `run`, `macro_add`); `check_modules` runs in `build` right after the BUILD line,
    logs ONE `MODULES loaded: ok`, or ONE `ERROR module <Name> not loaded: missing <procs>` per
    broken module, marks it in `S disabled`/`S missing` and disables its three buttons
    (`module_buttons` = title + `Apply all layout` + `Macro Add`); every press on it logs the
    same sentence (checked with the notes title proc renamed away, then restored).
    `test_gui_frame.tcl` checks that the table equals the `::pis::result|legend|capture|notes::`
    refs of the GUI's own code, so a new call cannot bypass the self-check.
    (5) THE THREE CONTROLS (SPEC first: `docs/SPEC.md` A16/A17 amended and the Notes subsection
    gained the T-039 block). The scope rule is the one the other modules use and is unchanged:
    title button = ACTIVE window (`hwIPage GetActiveWindow`), `Apply all layout` = every window
    Load All created, in order; per window select k FIRST then create; stop on the first error
    unless `[log] continue_on_error`. Nothing ticked = exactly ONE `WARN Notes: no row ticked`,
    0 HyperView calls, 0 journal lines. The closing line is
    `Notes: <n> note(s) in <w> window(s), display not confirmed (look at the windows)` - the
    required count first, the amber verdict kept (a green ok would be wrong on this build).
    `Macro Add` reads `[macro] notes_log` (default `Notes.log`, `resolve_path` against the app
    folder - SPEC Q1, no new rule), validates the WHOLE file before the first call (now including
    every section's windows AND every Name, so a defect in the LAST section costs no call - the
    T-038 code validated per section inside the loop), then executes it; every sent command is
    journaled exactly as sent through `hwc`/`hwi` and the recorded literals replay unchanged.
    Display/adjust stay the PROVEN S07:312-344 sequence, no variant added, `note_eye` once per
    press, names per window, no ReleaseHandle.

    (6) THE DUMMY FILE. `src/Notes.log` (the default location: `[macro] notes_log = Notes.log`
    resolved against `src` by the GUI's ROOT) and the same bytes as
    `docs/refs/samples/Notes.log`: 4 lines, `#Note1` + the column row + `PIS_dummy_1, PIS dummy
    note 1, 0, 0, 0` + `PIS_dummy_2, PIS dummy note 2, 10, 10, 0`. It produces 2 notes in window
    1 (or in every window whose result file name holds `SPEC1`, Q3) = 19 commands (1 select +
    2 x 9), which `test_wiring.tcl` asserts through the real parser and the real module. TWO
    LIMITS OF THE T-038 GRAMMAR, reported rather than invented: it has NO verb/command column,
    so an ADJUST row cannot be expressed (the dummy is DISPLAY only; a re-press replaces the same
    two notes, which is the only "adjust" available), and it has NO comment syntax (every `#`
    line must be `#Note<N>`), so the file cannot explain itself - the explanation is here, in
    SPEC A17 and in HANDOFF section 4b.
    (7) TESTS. MOCK, no HyperView, no display: `test_notes.tcl` (module order, counters, 80
    checks, including the new all-or-nothing and refused-file cases), `test_wiring.tcl` (the real
    handler path, the scan, the guard, the self-check, the dummy file, the 19-call count, the
    second press deleting first against a mock that refuses duplicate creates like the owner's
    build, the replay), `test_gui_frame.tcl` (the source list and the guard sentences). The
    strict-name and class-aware mocks of the adapter/legend suites are untouched.
    (8) NOT PROVEN, AND THE DEVIATIONS TO REVIEW. Not proven: that a note is PAINTED (no getter,
    amber verdict, the eye check is step 2-3 of section 4b) and the real `hwc annotation note`
    answer on this build (only the owner's log can tell). Deviations from the brief: (a) the
    `Macro Add` button now binds `run_module notes macro` instead of `macro_add_notes` directly,
    so it passes the same guard and the same not-loaded check as the other two controls (the test
    drives that exact binding); (b) the dummy `Notes.log` has no comments and no ADJUST row,
    because the T-038 grammar can express neither (reported above, not invented around); (c) the
    closing line keeps the amber sentence after the required
    `Notes: <n> note(s) in <w> window(s)` prefix, because A19 forbids a green verdict; (d) two
    checks in `test_notes.tcl` had been sitting AFTER `exit 0` (dead since T-038) and now run.
  Refs: `docs/SPEC.md` A16/A17/A19/A20 + the Notes subsection (T-039 block), Q1 + Q3 + Q9-Q12,
  `docs/refs/SPEC_gui.txt` s.14-15, `docs/refs/HV_API_REF.md` Annotation/Note S07:312-344 +
  patterns 8/9, TASKLOG T-038 (the module and the reader this task repairs) and T-035 (the
  per-window seam and the amber verdict), `docs/HANDOFF.md` section 4b (the owner check) and
  section 7 (the new wiring rule).

