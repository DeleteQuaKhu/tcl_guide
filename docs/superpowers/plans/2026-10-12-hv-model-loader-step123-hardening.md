# STEP 1/2/3 Hardening of `hv_model_loader.tcl` — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the six pure-logic defects (P1–P6) of the STEP 1/2/3 features, prove each fix with a selftest check that fails before the fix, and mark every remaining HyperView-only uncertainty with a `V`-marker instead of a guess.

**Architecture:** The wizard keeps its four layers. Every fix moves the *decision* into a pure `Logic::*` helper (testable in plain Tcl), leaves the `hwi` calls in the `Adapter` section and keeps the UI a thin caller. Two selftests: **L1** = the pure/State/Logic/Adapter-failure layers (`selftest_hv_model_loader.tcl`), **L2** = the whole GUI against `hwtk` stubs (`selftest_ui_hv_model_loader.tcl`). One new Python runner per selftest makes both runnable on this host.

**Tech Stack:** Tcl/Tk 8.6 (wizard + tests), Python 3.12 `tkinter.Tcl` / `tkinter.Tk` as the Tcl host (no `tclsh` is installed), git.

**Spec:** `docs/superpowers/specs/2026-10-12-hv-model-loader-step123-hardening-design.md`

## Environment contract (verified on this host)

* There is **no** `tclsh` / `wish`. Python 3.12.2 embeds Tcl/Tk **8.6.13** (`tkinter.Tcl()` = plain Tcl, `tkinter.Tk()` = Tcl + Tk).
* The embedded interpreter has **no `exit` command** (`info commands exit` is empty), so the runners shim it.
* Verified baseline with the runners of Task 0: **L1 = 401 passed, 0 failed, rc 0**; **L2 = 302 passed, 0 failed, rc 0**; a script calling `exit 1` gives rc **1**; a script that dies gives rc **2** plus its Tcl error message.
* Every command below is run from `C:\Users\TechnoStar\.cline\data\workspaces\chat\tcl_guide` (*the repo*). Line numbers are from `abb1cf8` plus the commits of this plan — with one exception: the README edit of **Task 0.5** adds 12 lines to §8, so every README line number **after** :250 (the section descriptions, the two hard-coded totals, the fix-1 paragraphs) is **12 higher** afterwards (`:277` → `:289`, `:326` → `:338`, `:304` → `:316`, …).

## File structure

| File | Responsibility | Change |
| --- | --- | --- |
| `hv_model_loader.tcl` | the wizard (State / Logic / Adapter / UI) | **the only file whose behaviour changes** |
| `selftest_hv_model_loader.tcl` | L1: pure Tcl layers + fake `hwi` scenarios + source scans | checks strengthened, new checks added |
| `selftest_ui_hv_model_loader.tcl` | L2: the whole GUI against `hwtk` stubs | checks strengthened, new checks added |
| `run_selftest.py` | **new** runner for L1 (`tkinter.Tcl`) | created in Task 0 |
| `run_ui_selftest.py` | **new** runner for L2 (`tkinter.Tk`) | created in Task 0 |
| `README.md` | user documentation, `V`-marker table, the helper descriptions of each test section, the test section itself | updated in the task that changes documented behaviour |
| `docs/superpowers/specs/…-step123-hardening-design.md` | the spec this plan implements | already committed |
| `docs/superpowers/plans/…-step123-hardening.md` | this plan | created now |

## Conventions every task follows

1. **TDD, one defect per commit.** Write the failing check first, run the runner and *see* the FAIL, then change `hv_model_loader.tcl`, then run again and see `ok`. A check that was never red proves nothing.
2. **Both runners stay green.** L1 and L2 run at the end of every task; a bigger count in the summary line is expected, a `FAIL` is not.
3. **New `proc` ⇒ two updates.** `expectedProcs` in `selftest_hv_model_loader.tcl` (:56-122) must list it — otherwise `no procedure of the file is missing from the inventory` (:137) fails — **and** the README must name it in the paragraph that describes what L1 covers (:254-267) or in the section of the feature it belongs to (manual edit, nothing checks the README).
4. **`hwi` stays in the Adapter section.** L1 asserts that no line outside `SECTION 2 - HYPERVIEW ADAPTER LAYER` mentions `hwi`. A helper that needs no `hwi` belongs to `Logic`; one that calls `hwi`-backed helpers belongs to the Adapter *section*, even if it calls no `hwi` itself.
5. **Probe mechanisms are never weakened.** Summary counts may grow; an existing check is only ever replaced by a strictly stronger one (the spec lists the five).
6. **Commits:** Conventional Commits, imperative, one defect each.

---

## Task 0 — the Python runners (no wizard change)

**Deliverable:** `python run_selftest.py` and `python run_ui_selftest.py` run the existing tests on this host and return the test's own exit code. Nothing in `hv_model_loader.tcl` changes.

**Why:** `selftest_ui_hv_model_loader.tcl` :31-34 already points at `run_ui_selftest.py`, which does not exist yet, and `tclsh` is not installed here. The README §8 (:246-250) still documents the `tclsh` invocation as *the* way to run them.

- [ ] **0.1** Create `run_selftest.py` with exactly this content:

```python
#!/usr/bin/env python3
"""Run selftest_hv_model_loader.tcl with the Tcl that ships inside Python.

The host has no tclsh/wish, but Python embeds Tcl/Tk 8.6, so the source-only
selftest runs here unchanged.  Two properties of the embedded interpreter are
handled here and nowhere else:
  * it has no 'exit' command, while the test ends with 'exit 0' / 'exit 1': a
    shim records the code and raises -errorcode {SELFTEST EXIT} instead of
    killing the process;
  * '[info script]' inside the test has to be its real path (the test finds the
    wizard next to itself), so the runner chdirs into the test folder and
    sources the file by name.

Exit code: 0 = every check passed, 1 = the selftest reported failures,
           2 = the test itself died with a Tcl error.
"""
import os
import sys

from tkinter import Tcl


def run(script, interp):
    path = script if os.path.isabs(script) else os.path.join(
        os.path.dirname(os.path.abspath(__file__)), script)
    if not os.path.isfile(path):
        print("no such test file: %s" % path)
        return 2
    interp.eval("proc exit {code} { set ::selftestExitCode $code ;"
                " return -code error -errorcode {SELFTEST EXIT} [list $code] }")
    os.chdir(os.path.dirname(path))
    rc = interp.eval("""
        set ::selftestExitCode 0
        set rc 0
        if {[catch {source {%s}} ::selftestMsg opts]} {
            if {[lindex [dict get $opts -errorcode] 0] eq "SELFTEST"} {
                set rc $::selftestExitCode
            } else {
                set rc 2
            }
        }
        set rc
    """ % os.path.basename(path))
    rc = int(rc)
    if rc == 2:
        print("the test died: %s" % interp.getvar("selftestMsg"))
    print("exit code: %d" % rc)
    return rc


def main(argv):
    return run(argv[1] if len(argv) > 1 else "selftest_hv_model_loader.tcl",
               Tcl())


if __name__ == "__main__":
    sys.exit(main(sys.argv))
```

- [ ] **0.2** Create `run_ui_selftest.py` as the same file with **three** differences: the docstring says it needs a display (on a headless Linux box wrap it with `xvfb-run`), it imports `Tk` instead of `Tcl`, and `main()` uses `Tk()` with the default script `selftest_ui_hv_model_loader.tcl`.
- [ ] **0.3** Record the baseline:

```powershell
python run_selftest.py        # expect "... : 401 passed, 0 failed" then "exit code: 0"
python run_ui_selftest.py     # expect " UI smoke test : 302 passed, 0 failed" then "exit code: 0"
```

- [ ] **0.4** Check the exit-code contract: create `_probe_exit1.tcl` holding `puts hi` + `exit 1`, run `python run_selftest.py _probe_exit1.tcl` → expect `hi`, `exit code: 1`, and `$LASTEXITCODE` = 1; then delete the probe file.
- [ ] **0.5** README §8 (`## 8. Tests`, :242-249): keep the `tclsh` lines for a normal Tcl install and add above them the Python route, stating that no `tclsh` is needed, that the runner forwards the test's own exit code (`0` / `1`, `2` if the test itself dies), and that the UI runner needs a display.
- [ ] **0.6** `git add run_selftest.py run_ui_selftest.py README.md` and commit `test: add Python runners for both selftests`.

---

## Task 1 — P2: a page that answers `-1` is not a page with one window

**Defect (spec §5 P2):** `Logic::InterpretWindowCount` :540-544 lets a negative answer fall through to `llength`, which is 1 for every scalar. `Adapter::QueryPage` :1131 then reports a healthy page with **one** window and `Adapter::SetWindowCount` :1159 answers `unchanged 1` for a request of one window although nothing was read; the `< 0` guard of :1131 is dead code because of that.

**Deliverable:** `InterpretWindowCount` returns a clamped, never-negative count and `0` for garbage; `QueryPage` treats a non-positive count as an unreadable page.

**Tests:**

| Where | Check |
| --- | --- |
| L1 :268-269 (replace) | `InterpretWindowCount` of `-1` → `0`, `-5` → `0`, `abc` → `0`, `{1 x}` → `0`, `0` → `0`. Keep the existing checks at :255-267 (`4`, `"4"`, `{1 2 3 4}`, `1`, `" 4 "`, `""`, "is NOT llength") untouched |
| L1 §4b scenario 0, appended after :842 | `::fake::win -1` → `Adapter::QueryPage` is `{}`; `::fake::win 0` → `{}`; control: `::fake::win 4` → `dict get … windows` is `4` |
| L1 §4b, `SetWindowCount` scenario | `::fake::win -1` → `Adapter::SetWindowCount 1` gives `ok 0` (today `ok 1` with `unchanged 1`) |
| L2 :451-458 (add) | `eq "InterpretWindowCount clamps -1 to 0" 0 [::ModelLoader::Logic::InterpretWindowCount -1]` |

- [ ] **1.1** `python run_selftest.py` → expect the baseline `401 passed, 0 failed`.
- [ ] **1.2** Add every check of the table. Write the L1 `-1` checks as `checkEqual "InterpretWindowCount clamps a negative answer to 0" 0 [::ModelLoader::Logic::InterpretWindowCount -1]` and so on; the two `QueryPage` labels are `P2: a page that answers -1 is not a page with one window` and `P2: a page that answers 0 windows is unreadable`; the `SetWindowCount` label is `P2: a -1 page is not 'already showing 1 window'`. Set `::fake::win` back to `4` after the block, exactly like the surrounding scenario does.
- [ ] **1.3** `python run_selftest.py` → expect FAILs on the new checks (the `-1` answer gives `1`, `QueryPage` gives `{page 0 windows 1 layout 1x-1}`, `SetWindowCount` gives `ok 1`). This is the RED state — do not touch the wizard before you have seen it.
- [ ] **1.4** In `Logic::InterpretWindowCount` :540-544: empty answer → `0`; a strict integer → its value with negatives clamped to `0`; otherwise a count **only** if *every* token of the answer is an integer (`1 2 3 4` → `4`), else `0`. Add the sign and garbage rules to the doc comment :527-539 in the voice of the existing lines.
- [ ] **1.5** In `Adapter::QueryPage` :1131 change the guard to `if {$pageIdx eq "" || $winCount <= 0} { return {} }` with a one-line reason: a page always has at least one window, so a non-positive answer means the page was not read.
- [ ] **1.6** `python run_selftest.py` → every new check green, total `410 passed, 0 failed`.
- [ ] **1.7** `python run_ui_selftest.py` → `303 passed, 0 failed`. A red L2 check here is a real regression (L2 drives `OnWindowCountChanged` / `RefreshWindowList` with `1`…`5`, never with `-1`): fix the source, not the test.
- [ ] **1.8** README :304 (the `Logic::InterpretWindowCount` paragraph) — add the clamp rule. Commit `fix: never read a negative page window count as one window`.

**Convention 7 (used from here on):** `check` / `checkEqual` do **not** catch errors, so a check calling a proc that does not exist yet kills the script (rc 2) instead of printing a `FAIL`. Every task therefore proves RED through a proc that **already exists** (`LayoutCandidates`, `CheckChosenFile`, `RefreshStep3`, …) and adds the checks of a brand-new helper in the edit that introduces it.

---

## Task 2 — P1: a legacy layout word belongs to one window count only

**Defect (spec §5 P1):** `Logic::LayoutCandidates` :518 appends `single 1x1 2H 2V 3H 3V 4H 4V` to the candidates of **every** count. `LayoutCandidates 4` therefore offers `2H`/`2V` (a two-window layout) and `LayoutCandidates 3` offers `single`; a build that accepts such a word blindly shrinks the page. L1 :359-360 currently *asserts* the wrong behaviour (`LayoutCandidates 4 contains 2H`).

**Deliverable:** new pure `Logic::LegacyLayoutTokens <count>` backed by a `legacyLayoutTokens` dict; `LayoutCandidates` :518 uses it; the ordering documentation :446-460 and the V1 registry :92-96 say "legacy tokens **of that count**".

**Tests (L1):**

| Where | Check |
| --- | --- |
| :359-360 (replace) | `LegacyLayoutTokens` for `4` → `{4H 4V}`, `1` → `{single 1x1}`, `2` → `{2H 2V}`, `5` → `{}`, `0` → `{}` |
| :359-360 (replace) | `LayoutCandidates 4` still contains `4H`; the new negative check is `checkEqual "a legacy word of another count is not offered" -1 [lsearch -exact [::ModelLoader::Logic::LayoutCandidates 4] 2H]` |
| new, next to it | `LayoutCandidates 2` has no `4H`, `LayoutCandidates 3` has no `single`, `LayoutCandidates 1` **has** `single` |
| :230 (keep) | "LayoutCandidates is unique" — unchanged, it still guards the dedup contract |

- [ ] **2.1** Add the negative behaviour checks against the **existing** `LayoutCandidates` (`2H` not in 4, `4H` not in 2, `single` not in 3, `single` in 1). `python run_selftest.py` → these must FAIL (today every count offers every word), and nothing else may fail.
- [ ] **2.2** Add the `legacyLayoutTokens` dict to the `Logic` variable block (after `variable viewPresets` :404) with the comment `# V1 - VERIFY: the legacy spellings of each window count (see the registry).  Only the count they belong to ever gets them: '2H' on a four-window page would close two windows.` and the value `{1 {single 1x1} 2 {2H 2V} 3 {3H 3V} 4 {4H 4V}}`.
- [ ] **2.3** Add `proc ::ModelLoader::Logic::LegacyLayoutTokens {count}` directly above `LayoutCandidates` :502: `variable legacyLayoutTokens`, `if {![dict exists $legacyLayoutTokens $count]} { return {} }`, `return [dict get $legacyLayoutTokens $count]`.
- [ ] **2.4** Replace :517-518 with `lappend cand $count` plus `foreach t [::ModelLoader::Logic::LegacyLayoutTokens $count] { lappend cand $t }`, and reword the step-5 comment to `# 5. the plain count and the legacy words OF THIS COUNT`.
- [ ] **2.5** Reword :453 step 5 → "the plain count and the legacy tokens of **this** count (`Logic::LegacyLayoutTokens`: `single`/`1x1` for 1, `2H`/`2V` for 2, …; a word of another count is never offered — it would shrink the page)"; keep :457-460. Reword the V1 registry :92-96 the same way ("…the legacy words **of that count**").
- [ ] **2.6** Add `LegacyLayoutTokens` to `expectedProcs` (next to `LayoutCandidates` :66) and to the README L1 paragraph :261-264, then add the five `LegacyLayoutTokens` checks.
- [ ] **2.7** `python run_selftest.py` → all green; `python run_ui_selftest.py` → `303 passed`, unchanged. Commit `fix: offer a legacy layout token only for its own window count`.

---

## Task 3 — P3: mark the guessed token spellings as `V14`

**Defect (spec §5 P3):** the four spellings (`2x2`, `2 X 2`, `2 x 2`, `2 - 2`) :512, the legacy words and the `rows <= cols` convention :457-460 are *guesses* taken from an installed HyperView; only `<page> SetLayout <token>` itself is confirmed. V1's entry :92-96 documents the call, the preference and the cache — not that the **spellings** are unverified.

**Deliverable:** a `V14` block in the marker registry (:92-130, after V13 :130) plus pointers to it in the layout code; the L1 marker check must know the tag.

**Test (L1 :1287-1292):** the registry check loops over `{V1 … V13}` and requires the literal `"<tag> - VERIFY"` in the wizard body, so **`V14` must be added to that loop** and the marker must read exactly `V14 - VERIFY`.

- [ ] **3.1** Extend the L1 loop to `foreach tag {V1 V2 V3 V4 V5 V6 V7 V8 V9 V10 V11 V12 V13 V14}`. `python run_selftest.py` → expect exactly one FAIL (`the wizard documents V14 - VERIFY`) and nothing else. RED.
- [ ] **3.2** Add the registry block after V13 (:130), wrapped like its neighbours and in the same voice:

```tcl
#     V14 - VERIFY: the layout token SPELLINGS and the rows<=cols convention.
#         Only '<page> SetLayout <token>' itself is confirmed.  The four
#         spellings ('2x3', '2 X 3', '2 x 3', '2 - 3'), the legacy words
#         (single, 1x1, 2H/2V, 3H/3V, 4H/4V) and 'prefer the wide arrangement'
#         come from an installed HyperView.  A wrong spelling is harmless - the
#         candidate is refused and the next one is tried - and a legacy word is
#         only offered for its own window count (Logic::LegacyLayoutTokens).
#         Confirm with 'Learn layouts' on a live page, then read the cache.
```

- [ ] **3.3** Point the layout code at it: one extra line in the V1 comment above `LayoutPreference` (:433-436, e.g. `#      The four SPELLINGS and the rows<=cols convention are V14.`) and one inside the spelling loop :509-515.
- [ ] **3.4** README: add a `| **V14** | … |` row to the `V`-marker table after the V13 row (:236), and change the "(V1 - V13)" mention at :219 into "(V1 - V14)".
- [ ] **3.5** `python run_selftest.py` → green (marker count grows by 1); `python run_ui_selftest.py` → unchanged. Commit `docs: mark the guessed layout token spellings as V14`.

---

## Task 4 — P5a: the legend list, the browser and the hint say the same thing

**Defect (spec §5 P5a):** three sources of truth — `legendExtensions` `{.tcl .hvl .txt}` :409, `Logic::LegendFileTypes` (`{.tcl}`, `{.hvl}`, `{*}`) :639-645, and the step-2 hint "*\*.tcl …, \*.hvl and \*.txt are offered*" :2986-2989. The hint promises a filter entry the browser does not have, and the loader treats `.txt` as known while the browser does not.

**Deliverable:** `legendExtensions` = `{.tcl .hvl}`; hint reworded to "*\*.tcl (an exported legend) and \*.hvl are offered*"; `All Files` stays in the filter, so a `.txt` legend is still reachable and still loads — it only gets the existing honest warning :1863-1865. A new check pins the invariant *"the non-`*` extensions of the browser entries == the loader's extension list"* for **both** file fields, so they cannot drift apart again.

**Tests:**

| Where | Check |
| --- | --- |
| L1 :390-391 | expect `{.tcl .hvl}` instead of `{.tcl .hvl .txt}` — RED |
| L1, after :391 | browser/list invariant for the legend field — RED (browser gives `{.hvl .tcl}`, the list `{.hvl .tcl .txt}`) |
| L1, after :391 | the same invariant for the view list (`ViewListFileTypes` vs `ViewListExtensions`) — passes before and after; it is the drift guard |
| L2 :622-623 | expect `".tcl .hvl"` — RED |
| L1 :418-420 | **unchanged** — an unusual extension (`.dat`) is still only a warning |

- [ ] **4.1** Add a test-local helper after `checkEqual` (:34):
```tcl
# the flat extension list of the entries of a file browser ({name {ext ...}} ...)
proc extsOfTypes {types} {
    set out {}
    foreach entry $types {
        foreach e [lindex $entry 1] { if {$e ne "*"} { lappend out $e } }
    }
    return [lsort -unique $out]
}
```
- [ ] **4.2** Change :390-391 to `{.tcl .hvl}` and add next to it:
```tcl
checkEqual "the legend browser offers exactly the legend extensions" \
    [lsort [::ModelLoader::Logic::LegendExtensions]] \
    [extsOfTypes [::ModelLoader::Logic::LegendFileTypes]]
checkEqual "the view list browser offers exactly the view list extensions" \
    [lsort [::ModelLoader::Logic::ViewListExtensions]] \
    [extsOfTypes [::ModelLoader::Logic::ViewListFileTypes]]
```
`python run_selftest.py` → exactly three FAILs (the `.txt` expectation and the two halves of the legend invariant) — the view-list invariant must already pass. RED.
- [ ] **4.3** `hv_model_loader.tcl` :409 → `variable legendExtensions {.tcl .hvl}` with the comment `# P5a: exactly the two entries of Logic::LegendFileTypes.  A .txt legend is not refused - 'All Files' still reaches it, it only gets the warning of Adapter::LoadLegendFromFile.`
- [ ] **4.4** Reword the hint :2986-2989 to: `A legend that was saved to a file is a Tcl script - it is sourced into the running HyperView session, then the legend of the selected window is switched on and the window is redrawn.  *.tcl (an exported legend) and *.hvl are offered; a file with another extension (e.g. *.txt) can still be chosen through 'All Files' - it is sourced with a warning.  The legend belongs to the window that is selected above.`
- [ ] **4.5** L2 :622-623 → `".tcl .hvl"`.
- [ ] **4.6** README :88 (the `*Legend file*` row, "`Logic::LegendExtensions` accepts `.tcl .hvl .txt`") → `{.tcl .hvl}` plus the sentence that another extension only warns.
- [ ] **4.7** `python run_selftest.py` → green, `0 failed` (+3 checks); `python run_ui_selftest.py` → green, `0 failed` (unchanged count). Commit `fix: declare only the legend extensions the loader really accepts`.

---

## Task 5 — P5b: a chosen file is judged by the extensions of its own field

**Defect (spec §5 P5b):** `Logic::CheckChosenFile` :629-630 reads `if {$kind eq "model"} … else ResultExtensions`, so the `else` branch catches *everything that is not a model*: a `.hvl` legend picked through `Browse...` (:2420 → `ApplyChosenFile` :2425, kinds `legend` / `viewlist` from :2980 and :3023) is announced as `"'.hvl' is unusual for a legend file - it is passed to HyperView anyway"`. The loader itself (`Adapter::LoadLegendFromFile` :1863) knows better, so the two paths contradict each other for the same file.

**Deliverable:** the two pure helpers of the spec — `Logic::ExtensionsForKind {kind}` (`model` / `result` / `legend` / `viewlist`, `{}` for anything else) and `Logic::KindLabel {kind}` (`viewlist` → `view list`) — used by `CheckChosenFile`; an empty extension list means "no warning" instead of "warn about everything"; no UI call site changes.

**Tests:**

| Where | Check |
| --- | --- |
| L1, next to :216-220 | `CheckChosenFile $wizard legend` has an **empty** `message` — RED (today "…unusual for a legend file…") |
| L1, next to :216-220 | `CheckChosenFile $wizard viewlist` has an empty `message` — RED |
| L1, next to :216-220 | `CheckChosenFile $wizard whatever` (unknown kind) has an empty `message` — RED |
| L1 | `.txt` probe: `legend` warns (`*unusual for a legend file*`), `viewlist` does **not** |
| L1 | `.hvl` probe: `legend` does **not** warn, `viewlist` warns `*unusual for a view list file*` |
| L1 :216-220 | **unchanged** — kind `result` with a `.tcl` file still warns `*unusual*` |
| L2 :505-517 | **unchanged** — model/result keep their warnings |
| L2, in 5e | `ApplyChosenFile` on the legend field with a `.hvl` file → status `Chosen legend file: _selftest_legend_field.hvl` — RED |
| `expectedProcs` | `ExtensionsForKind`, `KindLabel` |

- [ ] **5.1** Add the three L1 checks that use the already-existing `$wizard` (a real `.tcl` file) as the path, with the labels `a *.tcl legend is a normal legend file`, `a *.tcl view list is a normal view list`, `an unknown kind is never second-guessed`. `python run_selftest.py` → these three FAIL (each returns an "unusual for a result file" message today; `.tcl` is in neither `ResultExtensions` nor `ViewListExtensions`). RED.
- [ ] **5.2** Add the two probe files and their four checks:
```tcl
set probeTxt [file join $here _selftest_probe.txt]
set fh [open $probeTxt w] ; puts $fh "view list" ; close $fh
set probeHvl [file join $here _selftest_probe.hvl]
set fh [open $probeHvl w] ; puts $fh "# legend" ; close $fh
checkEqual "a *.hvl legend is not warned about" "" \
    [dict get [::ModelLoader::Logic::CheckChosenFile $probeHvl legend] message]
checkEqual "a *.txt view list is not warned about" "" \
    [dict get [::ModelLoader::Logic::CheckChosenFile $probeTxt viewlist] message]
check "a *.txt legend IS warned about (it is no longer a legend extension)" \
    [string match "*unusual for a legend file*" \
        [dict get [::ModelLoader::Logic::CheckChosenFile $probeTxt legend] message]]
check "a *.hvl view list IS warned about, with the user's wording" \
    [string match "*unusual for a view list file*" \
        [dict get [::ModelLoader::Logic::CheckChosenFile $probeHvl viewlist] message]]
file delete $probeTxt
file delete $probeHvl
```
The first two are RED as well (`.txt`/`.hvl` are not result extensions); the fourth is RED twice over (wrong extension list *and* the missing `view list` label).
- [ ] **5.3** Add `proc ::ModelLoader::Logic::ExtensionsForKind {kind}` (exactly the `switch -exact --` of the spec §5 P5b) and `proc ::ModelLoader::Logic::KindLabel {kind}` (`if {$kind eq "viewlist"} { return "view list" }` then `return $kind`) directly above `CheckChosenFile` :613.
- [ ] **5.4** Replace :629-630 with `set known [::ModelLoader::Logic::ExtensionsForKind $kind]`, read `set label [::ModelLoader::Logic::KindLabel $kind]`, and warn only `if {[llength $known] > 0 && [lsearch -exact $known $ext] < 0}` with the text `"'$ext' is unusual for a $label file - it is passed to HyperView anyway"`. Extend the doc comment :608-612 with the four kinds and "an unknown kind is never second-guessed".
- [ ] **5.5** Add both procs to `expectedProcs` (next to `CheckChosenFile`) and to the README: the L1 paragraph :257 names the helpers it covers, the section-5c sentence :307-311 mentions `CheckChosenFile` (add "and it is judged by the extensions of its own field - `Logic::ExtensionsForKind` / `Logic::KindLabel`; an unknown kind is never second-guessed").
- [ ] **5.6** L2: at the end of 5e, directly before the "5f" banner (:684) — that is after the cleanup and the `varLegendFile ""` reset (:679-682) — add
```tcl
# P5b: the legend field must judge a legend with the LEGEND extensions
set legField [file join $::here _selftest_legend_field.hvl]
set fh [open $legField w] ; puts $fh "# legend" ; close $fh
runs "ApplyChosenFile on the legend field with a *.hvl legend" \
    {::ModelLoader::UI::ApplyChosenFile $::ModelLoader::UI::wLegendFile \
        ::ModelLoader::UI::varLegendFile legend $legField}
eq "a *.hvl legend is not warned about" \
    "Chosen legend file: _selftest_legend_field.hvl" $::ModelLoader::UI::statusText
file delete $legField
```
- [ ] **5.7** `python run_selftest.py` → green (+7 checks, `0 failed`); `python run_ui_selftest.py` → green (+1 check, `0 failed`). Commit `fix: classify a chosen file by its field, not as a result file`.

---

## Task 6 — P4: the remembered legend file is read back

**Defect (spec §5 P4):** `UI::OnLoadLegend` :3484 stores the loaded path per window (`State::SetLegendFile`), but `UI::OnTargetWindowChanged` :2348-2361 only updates `varTargetWin` — switch the target window and the field still shows the *previous* window's legend, so the per-window state is write-only. Second half: `State::PruneTo` :278-288 drops `windows` entries above the new maximum but leaves `legendFileByWindow` :193 untouched, so a window recreated by a later layout change offers a stale path.

**Deliverable:** `OnTargetWindowChanged` restores the field from `State::GetLegendFile` — **only when the accepted window differs from the window the field shows** (`UI::varLegendWin`, spec R1: never wipe a path the user is typing; see 6.4 for why the draft's `$last`-against-`varTargetWin` cannot work) — through the existing `UI::SetFileWidget` (which already tolerates a missing widget); `State::PruneTo` prunes `legendFileByWindow` for the indices it drops.

**Tests:**

| Where | Check |
| --- | --- |
| L1 State section, around the existing `PruneTo` check (:169) | `SetLegendFile 2`/`3` before `PruneTo 2`: `GetLegendFile 3` is `""`, `GetLegendFile 2` **survives** — RED (`GetLegendFile 3` returns the path today) |
| L1 :169 | the `PruneTo` result `{3}` stays exactly as it is |
| L2, new section 5e2 after the legend block | window 2 selected → handler returns `2` and the remembered path lands in `varLegendFile` **and** in the widget; window 3 (no legend) clears both; back to window 2 shows it again; a path typed while a window is already shown survives a refresh of that same window (R1) — RED (today the field is never written) |
| L2 :666-667 | **unchanged** — the write side (`GetLegendFile 1` after `OnLoadLegend`) |

- [x] **6.1** Add the L1 block. Keep the existing line `checkEqual "PruneTo returns the drop list" {3} [::ModelLoader::State::PruneTo 2]`, add the two `SetLegendFile` calls just above it and the two new checks just below it, with the labels `P4: the legend of a pruned window is gone` and `P4: the legend of a surviving window stays`. Use `[file normalize $wizard]` as the path (it always exists). `python run_selftest.py` → exactly one FAIL (`…pruned window is gone`). RED.
- [x] **6.2** L2: add section 5e2 directly before the "5f" banner (:684), i.e. right after the legend cleanup (:679-682). Shipped with two changes against the draft: the section first puts window **1** into *both* the widget and `varTargetWin` (:706-707) so that the following switch to window 2 is a real change, and after the last handler call it checks R1 — `varLegendFile` set to a typed path, one more handler call for window 1, the path must survive (:727-736):
```tcl
sec "5e2 - P4: the legend field follows the target window"
set leg2 [file join $::here _selftest_legend_win2.tcl]
set fh [open $leg2 w] ; puts $fh "# legend of window 2" ; close $fh
::ModelLoader::State::SetLegendFile 2 [file normalize $leg2]
::ModelLoader::UI::SetWidgetValue $::ModelLoader::UI::wTargetWin 1
set ::ModelLoader::UI::varTargetWin 1
::ModelLoader::UI::SetWidgetValue $::ModelLoader::UI::wTargetWin 2
eq "the handler accepts window 2" 2 [::ModelLoader::UI::OnTargetWindowChanged]
eq "P4: the remembered legend of window 2 is in the variable" \
    [file normalize $leg2] $::ModelLoader::UI::varLegendFile
eq "P4: and in the field" [file normalize $leg2] \
    [::ModelLoader::UI::WidgetText $::ModelLoader::UI::wLegendFile \
        $::ModelLoader::UI::varLegendFile]
::ModelLoader::UI::SetWidgetValue $::ModelLoader::UI::wTargetWin 3
runs "switch to window 3, which has no legend" \
    {::ModelLoader::UI::OnTargetWindowChanged}
eq "P4: a window without a legend clears the field" "" \
    $::ModelLoader::UI::varLegendFile
::ModelLoader::UI::SetWidgetValue $::ModelLoader::UI::wTargetWin 2
runs "switch back to window 2" {::ModelLoader::UI::OnTargetWindowChanged}
eq "P4: the legend of window 2 is shown again" [file normalize $leg2] \
    $::ModelLoader::UI::varLegendFile
::ModelLoader::UI::SetWidgetValue $::ModelLoader::UI::wTargetWin 1
runs "back to window 1 for the next section" \
    {::ModelLoader::UI::OnTargetWindowChanged}
# R1: a path the user is typing for the window that is already shown must
# survive a refresh of the step-2 page.
set ::ModelLoader::UI::varLegendFile \
    [file join $::here _selftest_legend_typed.hvl]
::ModelLoader::UI::SetWidgetValue $::ModelLoader::UI::wTargetWin 1
runs "refresh the same window 1 again" \
    {::ModelLoader::UI::OnTargetWindowChanged}
eq "P4: a path typed for the shown window is not wiped" \
    [file join $::here _selftest_legend_typed.hvl] \
    $::ModelLoader::UI::varLegendFile
set ::ModelLoader::UI::varLegendFile ""   ;# as section 5e left it
file delete $leg2
```
Run `python run_ui_selftest.py` → the three `P4:` checks FAIL. RED. Note that window 1 *has* a remembered legend by then (`$legOK` from :664-667), which is why the last handler call is followed by the explicit reset. The R1 check was proven RED on its own by temporarily replacing the guard with `if {1}` (`1 failed` — exactly `P4: a path typed for the shown window is not wiped`), see 6.4.
- [x] **6.3** `State::PruneTo` :290-314: added `variable legendFileByWindow` and, after the loop over `$dropped`, dropped the remembered paths of exactly those indices (`if {[dict exists $legendFileByWindow $idx]} { dict unset legendFileByWindow $idx }`). The comment above says that the remembered legend files of the dropped windows go with them.
- [x] **6.4** `OnTargetWindowChanged` :2431-2456: add `variable wLegendFile` and `variable varLegendWin`, and inside the accepted branch, guarded by `if {$raw ne $varLegendWin}`, call `::ModelLoader::UI::SetFileWidget $wLegendFile [list ::ModelLoader::UI::varLegendFile] [::ModelLoader::State::GetLegendFile $raw]`. **Deviation from the draft above:** the guard compares against `varLegendWin` — the window whose legend the *field* currently shows, `variable varLegendWin 0` :2294 — and not against `set last $varTargetWin`, because both target-window comboboxes are created with `-textvariable ::ModelLoader::UI::varTargetWin` (:2901, :2984): a conforming ttk/hwtk combobox writes the variable **before** the event fires, so `raw` and `last` are always equal and `if {$raw ne $last}` would never fire — the fix would be dead code in every conforming build (the L2 section proved exactly that: the RED run kept failing with the `$last` guard). `varLegendWin` is set where the field is written: `BuildStep2` :2985-2990 (field created → shows the initial target window) and `OnLoadLegend` :3585-3586 (a loaded legend belongs to `$varTargetWin`). It keeps R1 intact: a refresh (or a step-1 action) for the window that is already shown never touches the field, so a typed path survives; only a real switch reads the state.
- [x] **6.5** README: the `*Legend file*` row :88 now says that the field follows the **target window** — the path is read back from `State::legendFileByWindow` whenever another window is selected (P4; a refresh of the same window never overwrites what the user is typing) — that a window which disappears in a layout change loses its remembered path (`State::PruneTo`), and why the guard compares against `UI::varLegendWin` instead of the target variable.
- [x] **6.6** `python run_selftest.py` → green, `431 passed, 0 failed`; `python run_ui_selftest.py` → green, `316 passed, 0 failed` (+10 checks). Commit `fix: drop the remembered legend of a pruned window, follow the target window`.

---

## Task 7 — P6: the PNG preview and the capture agree on the window set

**Defect (spec §5 P6):** the preview `UI::RefreshStep3` :3341-3342 falls back to `[list $varTargetWin]` whatever the scope is, while the engine `Adapter::CapturePng` :2038-2046 falls back to *every window of the page* when `scope = all`. On a session whose State holds no windows (fresh session / after a layout change) with `scope = all` the pane therefore promises `4 PNG file(s) would be written` (that is one window — the target — times the four views of this section) while the capture writes one file per **page** window times per view. Two different fallbacks for the same scope — they cannot disagree any more.

**Deliverable:** the single rule `Logic::CaptureWindowSet {scope targetWindow windowIndices}` returning `{windows … resolvable …}`, used by `Logic::CapturePlan` (so the preview and the engine share it), plus `Adapter::PageWindowIndices` holding the :2038-2046 page query (also reused by `RefreshStep3`). `CapturePng` asks the page **only** for `scope = all` (spec R3: a target-window capture must keep working when the page cannot be read). When `all` is not resolvable the preview prints the honest line instead of a count.

**Tests:**

| Where | Check |
| --- | --- |
| L2, end of 5g (before "back to step 2" :871) | `scope all` + `PruneTo 0` + unreadable page: the pane has **no** `PNG file(s)` and **does** have `not known here` — RED (today "4 PNG file(s)") |
| L2 :826-830 | **unchanged** — `scope target` still says `4 PNG file(s)` |
| L1, after the `CapturePlan` checks (:560) | `CaptureWindowSet`: `target 2 {1 2 3}` → `{windows 2 resolvable 1}`; `all 1 {1 3}` → `{windows {1 3} resolvable 1}`; `all 1 {}` → `{windows {} resolvable 0}`; `target 2 {}` → `{windows 2 resolvable 1}` |
| L1 §4b scenario 0, after the P2 block | `PageWindowIndices`: `::fake::win 4` → `{1 2 3 4}` (both `listWindows` forms); `::fake::win 0` → `{}` — the second one is RED until Task 1's P2 fix is in, so it is written here as a **guard** (it must be green from Task 1 on) |
| L1 :543-560 | **unchanged** — the `CapturePlan` checks (incl. `all` with `{}` → 0 jobs) stay green after `CapturePlan` switched to the shared rule |
| L1 :587-600 | **unchanged** — `CapturePng all` with no window and no hwi still reports "there is no window to capture" |
| L1 §4b scenario 9, appended after :1163 | R3 guard: with an emptied state and `::fake::win 0` (page unreadable since Task 1) `CapturePng target 1 $views $outPng` still captures 2 files — green before and after; it exists because the refactor must not start asking the page for the `target` scope |
| `expectedProcs` + README | `CaptureWindowSet`, `PageWindowIndices` |

- [x] **7.1** Add the L2 check last in 5g, directly before the "back to step 2" block (:871). Note that :864 has just emptied `varOutputDir`, so the folder has to be put back before the preview can print any plan:
```tcl
# P6: with 'all' the pane must not invent a file count it cannot know
set ::ModelLoader::UI::varOutputDir $outDir
::ModelLoader::UI::SetOutputDirValue $outDir
::ModelLoader::State::PruneTo 0
set ::ModelLoader::UI::varCaptureScope all
runs "RefreshStep3 with scope 'all' on a page that cannot be read" \
    {::ModelLoader::UI::RefreshStep3}
ok "P6: the pane claims no file count for the unresolvable 'all'" \
    [expr {[infohas {PNG file\(s\) would be written}] ? 0 : 1}]
ok "P6: the pane says that the count is not known here" [infohas {files +: not known here}]
set ::ModelLoader::UI::varCaptureScope target
```
Run `python run_ui_selftest.py` → the first `ok` FAILs today ("4 PNG file(s)" from :3345), and the second one as well (the words "not known here" do not exist yet). RED. (The block sits at the very end of 5g so `PruneTo 0` disturbs nothing; it also puts `varCaptureScope` back to `target`.)
- [x] **7.2** Add `proc ::ModelLoader::Logic::CaptureWindowSet {scope targetWindow windowIndices}` exactly as in the spec §5 P6 (returns the dict with `windows` and `resolvable`; `target` always resolves and always yields `[list $targetWindow]`, `all` yields the page list and resolves only for a non-empty one). Rewire `Logic::CapturePlan` :833-837 to `set wins [dict get [::ModelLoader::Logic::CaptureWindowSet $scope $targetWindow $windowIndices] windows]` and keep the job loop :838-852 untouched — the existing L1 checks :543-560 (including `all … {}` → 0 jobs and `target 3 {} {1}` → 4 jobs) must stay green.
- [x] **7.3** Add `proc ::ModelLoader::Adapter::PageWindowIndices {}` (in the Adapter section, next to `QueryPage` :1107) holding exactly the :2038-2046 rule — `set page [::ModelLoader::Adapter::QueryPage]`, `if {[llength $page] == 0} { return {} }`, then `for {set i 1} {$i <= [dict get $page windows]} {incr i} { lappend out $i }` — and call it from `CapturePng` **only** when `$scope eq "all"` (R3: a `target` capture never needed the page, and `QueryPage` has no `hwi` fallback of its own); `all` + empty list keeps the existing "there is no window to capture" path :2039-2045/2050-2053.
- [x] **7.4** `RefreshStep3` :3340-3352 (inside the `else` of the folder check): replace `set indices [::ModelLoader::State::WindowIndices]` / `if {[llength $indices] == 0} { set indices [list $varTargetWin] }` with:
```tcl
set indices [::ModelLoader::State::WindowIndices]
if {$scope eq "all" && [llength $indices] == 0} {
    # R3: only 'all' needs the page - a target capture must keep working
    # when the page cannot be read (Adapter::PageWindowIndices returns {}).
    set indices [::ModelLoader::Adapter::PageWindowIndices]
}
set winSet [::ModelLoader::Logic::CaptureWindowSet $scope $varTargetWin $indices]
set jobs [::ModelLoader::Logic::CapturePlan $scope $varTargetWin $entries $indices $dir]
if {$scope eq "all" && ![dict get $winSet resolvable]} {
    lappend lines "  files         : not known here - the page could not be read, so the file count of 'all' is decided when the capture starts"
} else {
    ... the existing :3345 count line and the job listing :3346-3351, unchanged
}
```
Every other line of the pane stays untouched, and `target` keeps the exact behaviour the L2 checks at :823-830 assert (state indices if any, else the target window).
- [x] **7.5** L1: add the `CaptureWindowSet` checks after :560 and the `PageWindowIndices` checks at the end of scenario 0 (after the P2 block) plus the R3 guard at the end of scenario 9 (:1163); extend `expectedProcs` (next to `CapturePlan`); README: name both procs in the :261-267 paragraph (which already lists the capture helpers), extend the step-3 / step-5g description and the **V12** row with "`all` needs a readable page: the preview then prints no count (`not known here`) and the capture resolves the list itself, while `target` never asks the page".
- [x] **7.6** `python run_selftest.py` → green (+6 checks, `0 failed`); `python run_ui_selftest.py` → green (+2 checks, `0 failed`). Commit `fix: make the PNG preview and the capture agree on the window set`.

**Deviations found while doing Task 7** (the numbers above are the plan's
estimate; what the tests really contain):

* **7.1** - the pane of the UI test is not cleared by itself: `UI::AppendInfo`
  keeps every plan it ever printed, so the new block starts with
  `UI::SetInfo {}` before **each** assertion (otherwise the check would still see
  the `4 PNG file(s)` of the earlier `:879` plan and never go RED).  It also got
  two extra counter-checks for the other half of the rule - with `scope target`,
  `PruneTo 0` and the same unreadable page the pane still prints
  `files : 4 PNG file(s) would be written` and `w1_iso.png`.  That makes the L2
  delta **+6** (two `runs` + four `ok`), not +2.
* **7.2** - the shared rule is used as planned (`CapturePlan` only reads
  `windows` off it); the existing `CapturePlan` checks stayed green untouched.
* **7.3** - `CapturePng` asks the page not literally "when `$scope eq "all"`" but
  when the set of that scope is *unresolvable* - which is exactly `all` with an
  empty window list - so the R3 property (a `target` capture never reads the page
  info) holds for any future scope that is always resolvable.
* **7.5** - the L1 additions are 13 checks: 5 `CaptureWindowSet` checks plus 2
  that pin the *shared* rule (`CapturePlan` uses the set of
  `CaptureWindowSet` for a resolvable and for an unresolvable `all`), 3
  `PageWindowIndices` checks (both `listWindows` forms + the unreadable page) and
  3 R3 guards at the end of scenario 9.  The third guard is stronger than the
  plan's - `::fake::Find GetNumberOfWindows` must stay empty for a `target`
  capture, i.e. the page *info* is never read; it was proven **RED** against the
  pre-Task-7 code (which queried the page whenever the State was empty) and the
  `GetActivePage` call of the capture itself is deliberately *not* asserted,
  because the page **handle** is still fetched once per job.  README: besides
  the two proc names the stale check counts were corrected (`source test`
  401 → 444, `UI smoke test` 302 → 322), the P6 paragraph after the
  `CapturePng` description and the *Scope* row / **V12** row were extended.

---

## Task 8 — documentation sweep, whole-branch verification, `verification-before-completion`

**Deliverable:** every string that the six defects changed is described in `README.md` once; both runners are green on the final commit; the spec's *Provable test* list is checked item by item against the executed tests; nothing was weakened.

- [ ] **8.1** README sweep — for each defect make sure the README agrees with the code in the place a reader would look:
  - P1: the layout-token paragraph (`Logic::LegacyLayoutTokens`, "legacy tokens *of that count*") and the source registry :92-96 / the **V1** row :224,
  - P2: the `Logic::InterpretWindowCount` paragraph :304-306 ("reads both the scalar and the list answer" → add the clamp: a negative answer is `0`, garbage is `0`) and the **V5**/**V13** rows,
  - P3: the `V`-marker table gets the **V14** row (:236) and :219 says `V1 - V14`,
  - P4: `*Legend file*` row :88 (Task 6) + `State::PruneTo`'s description,
  - P5a/P5b: `*Legend file*` row (Task 4) + the section-5c sentence :307-311 (four kinds) + the step-2 hint text,
  - P6: the step-3 description :312-316 + the **V12** row,
  - **the two hard-coded totals**: :277-278 (`401 checks` / `source test   : 401 passed, 0 failed`) and :326 (`UI smoke test : 302 passed, 0 failed`) must carry the numbers the final runs print. Nothing checks them, so they are the one documentation item that *will* go stale silently — this sweep is why the counts live in their own commit.
- [ ] **8.2** Inventory check: every new `proc` is in `expectedProcs` **and** named in the README (the paragraph that describes what the file's test covers, :254-267, or the section of the feature).
```powershell
Select-String -Path README.md -Pattern 'LegacyLayoutTokens|ExtensionsForKind|KindLabel|CaptureWindowSet|PageWindowIndices' | ForEach-Object { $_.LineNumber }
```
Expect at least one hit per name (the L1 procedure-inventory check enforces the other half).
- [ ] **8.3** Final runs on the last commit:
```powershell
python run_selftest.py ; "L1 rc=$LASTEXITCODE"
python run_ui_selftest.py ; "L2 rc=$LASTEXITCODE"
```
Both must print `0 failed` and exit `0`. The failed-counter must never have been edited to make a run green — check with `git --no-pager log -p -- selftest_hv_model_loader.tcl selftest_ui_hv_model_loader.tcl` that each `FAIL` disappeared together with a source change in the same commit.
- [ ] **8.4** Marker count: `(Select-String -Path hv_model_loader.tcl -Pattern ' - VERIFY').Count` → one more than before this branch (V14 added, none removed).
- [ ] **8.5** `git --no-pager log --oneline hardening/step1-3` → one commit per task in this order: runners, P2, V14/P3, P5a, P5b, P4, P6, docs; `git status --short` empty.
- [ ] **8.6** Run the **`verification-before-completion`** skill and walk the spec :§5 P1-P6 *Provable test* table row by row, quoting the test label that proves each row, then the :§8 R1-R4 risks (R1: no write without a real change — Task 6; R2: `.txt` legend still loads with a warning — Task 4; R3: `target` needs no page — Task 7; R4: no new UI dependency, both helpers pure). Report any row without a test as a gap and fix it before the last commit.
- [ ] **8.7** Commit the plan + the documentation sweep: `docs: document the hardened STEP 1/2/3 behaviour` (include the plan file `docs/superpowers/plans/2026-10-12-hv-model-loader-step123-hardening.md`, which was still uncommitted when the branch started).

---

## Definition of done

1. `python run_selftest.py` and `python run_ui_selftest.py` both print `0 failed` and exit `0` on `HEAD`.
2. P1-P6 each have their own commit, and in each of those commits the test that turns green is the test that failed one commit earlier (RED → GREEN visible in `git log -p`).
3. No existing check was deleted or relaxed; the only lines changed in the two selftests are the ones listed in this plan (plus counts of the L1 header, which is printed, not asserted).
4. `expectedProcs` contains all five new procs, each of them is named in the README, and the README `V`-marker table contains V14.
5. `hv_model_loader.tcl` keeps its structure — no new global, no new UI dependency, all five new procs pure (`Logic` / `Adapter` only), and every new `proc` carries a `# Pn:` comment tying it to the defect it closes.
6. The list of V-markers ("guessed / to be verified in a real session") did not shrink; V14 was added with the literal text `V14 - VERIFY`.
7. `docs/superpowers/specs/2026-10-12-...-design.md` (commit `66ed4c1`) is unchanged by the branch, so the design as approved is what was implemented.

## Risks and how the plan handles them

| Risk | Handling |
| --- | --- |
| A new L1 helper cannot be RED-tested through a module `proc` that does not exist yet → rc 2 | Convention 7: the RED run always goes through an **already existing** proc (`CheckChosenFile`, `CapturePlan`, `PruneTo`, `OnTargetWindowChanged`); the pure helpers get their checks in the same edit that introduces them |
| `PruneTo` / `PruneTo 0` in an L2 section leaks into the following sections | Both new blocks are appended at the *end* of their section and restore the mutation (`varCaptureScope target`, `varTargetWin 1`, `varLegendFile ""`) |
| `OnTargetWindowChanged` wiping a path the user typed | Spec R1 → the write happens only when `$raw ne $last`; the "already selected" path is covered by the unchanged L2 checks |
| `CapturePng target` breaking on an unreadable page after the refactor | Spec R3 → the page is queried only for `all`; the new L1 guard at :600 runs with `::fake::win 0` |
| `.txt` legends becoming unreachable | `All Files` stays in `LegendFileTypes`; Task 4 L1 check pins the invariant and L1 :418-420 keeps the warning |

