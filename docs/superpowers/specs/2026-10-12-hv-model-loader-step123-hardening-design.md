# hv_model_loader.tcl — STEP 1/2/3 hardening design

**Date:** 2026-10-12
**Status:** Awaiting review (brainstorming output — no implementation before approval)
**Scope:** `hv_model_loader.tcl`, its two selftests, and the selftest runners of `tcl_guide`
**Baseline:** `abb1cf8` ("Add layout learning (fix 3), legend file (fix 4) and PNG capture (fix 5)")

## 1. Intent

The STEP 1 / STEP 2 / STEP 3 features of `hv_model_loader.tcl` (active-page layout,
legend-from-file, PNG capture) already exist and are already tested. This is a
**verification and hardening pass**, not a feature drop.

**The goal** is that a maintainer can trust the wizard on a machine where HyperView
cannot be started: every decision that can be checked by pure Tcl logic is checked by a
failing-then-passing test, and every decision that *only* a live HyperView can settle is
marked as such in the source instead of being silently assumed.

**Non-goal** (explicit): no new user-facing capability is added. Where the current code
does not match the issue text, the mismatch is recorded (section 8) rather than closed.

## 2. Success criteria

1. `selftest_hv_model_loader.tcl` and `selftest_ui_hv_model_loader.tcl` both **exit 0**
   in this environment (no `tclsh`, no HyperView, no `hwtk`).
2. Every defect in section 5 has at least one test that **failed before** the fix and
   **passes after** it (TDD RED → GREEN, recorded in the plan).
3. The `V`-marker block at the top of the file and the per-`proc` `VERIFY` notes describe
   the *current* candidate logic — nothing unverified is presented as confirmed.
4. No test asserts a behaviour that a live HyperView would contradict.

## 3. Current behaviour (verified against the source)

| # | Area | Where | Verified behaviour |
|---|------|-------|--------------------|
| 1 | Layout candidates | `Logic::LayoutCandidates` :502 | learned token first, then arrangements in four spellings, then **the plain count and a fixed legacy tail for *every* count**, deduplicated in order |
| 2 | Layout preference | `Logic::LayoutPreference` :461 | squarest divisor pair, `rows <= cols` (`2 -> 1x2`) |
| 3 | Layout probe order | `Logic::LayoutProbeOrder` :874 | counts `>= current`, ascending |
| 4 | Count read-back | `Logic::InterpretWindowCount` :540 | scalar `>= 0` passes through, anything else falls back to `llength` |
| 5 | Apply layout | `Adapter::SetWindowCount` :1149 | tries candidates, verifies with `GetNumberOfWindows`, caches the winner |
| 6 | Legend load | `Adapter::LoadLegendFromFile` :1836 | trims quotes, checks exists/dir/readable/empty, warns on odd extension, `hwi OpenStack` + `source`, then `SetDisplayOptions legend true` + `Draw` |
| 7 | Legend state | `UI::OnLoadLegend` :3459 | on success writes `State::SetLegendFile` **and** the widget |
| 8 | Target window | `UI::OnTargetWindowChanged` :2348 | writes `varTargetWin`, mirrors the second combobox — **never reads the legend back** |
| 9 | Capture plan | `Logic::CapturePlan` :831 | `target` → one window, `all` → the indices it is given |
| 10 | Capture engine | `Adapter::CapturePng` :2023 | `State::WindowIndices`, else **all page windows** for `all`; four-form fallback; `w<window>_<view>.png` |
| 11 | Step 3 preview | `UI::RefreshStep3` :3282 | `State::WindowIndices`, else **`{targetWindow}` — regardless of scope** |
| 12 | Selftests | the two `selftest_*.tcl` | end in `exit 0` / `exit 1`; the UI test header :31-34 documents `python run_ui_selftest.py`, **which does not exist** |

Environment facts established for this pass: no `tclsh`/`wish` on the host; Python 3.12.2
with Tcl/Tk **8.6.13** (both `tkinter.Tcl()` and `tkinter.Tk()` open successfully); the
embedded Tcl interp does **not** define `exit` (`info commands exit` → empty), which is
why the tests cannot currently terminate.

## 4. Decisions

**D-1 — This is a hardening pass, not a feature pass.** The issue text describes
behaviour the code already has. Chosen: verify and harden what exists. Rejected:
re-implementing the three steps (would duplicate working, tested code) and
"documentation only" (would leave provable defects in place).

**D-2 — Split the uncertainty in two.** Anything provable by pure logic is *fixed and
tested*; anything only a live HyperView can settle is *marked* (`V`-marker) and left with
a safe fallback. Rejected: guessing a native token spelling (would hide a real defect
behind a plausible-looking one) and refusing to touch unverified paths at all (would
leave the wrong-count candidate bug in place, although that bug is provable without
HyperView).

**D-3 — The selftests must run here, so the documented runner gets committed.**
`selftest_ui_hv_model_loader.tcl` :31-34 already tells the reader to use
`python run_ui_selftest.py`; that file is missing from the repo. Chosen: add
`run_selftest.py` (pure Tcl via `tkinter.Tcl()`) and `run_ui_selftest.py` (Tk via
`tkinter.Tk()`), commit them, and update `README.md` next to the existing `tclsh`
instructions. Rejected: installing a system Tcl/Tk (the host is fixed, and the repo
already documents the Python route) and keeping the runner outside the repo (the repo's
own test header would keep pointing at a file that does not exist).

**D-4 — Docs live in-repo** under `docs/superpowers/specs/` and `docs/superpowers/plans/`,
committed with the code, so the spec travels with the plan.

**D-5 — Scope is P1–P6** (section 5). The STEP 3 *view-selection combobox* is **out of
scope**: the issue's "populate a list/combobox allowing the user to select from those
imported views" is a capability the wizard does not have today, so closing it would be a
new feature, not hardening. It is recorded in section 8 instead.

## 5. Defects and fixes

Each defect is stated as *symptom → evidence → provable test → change*. Line numbers are
from `abb1cf8`.

### P1 — a layout token of a *foreign* window count is applied to the live page

*Where:* `Logic::LayoutCandidates` :516-518
```tcl
    # 5. the plain count and the legacy words
    lappend cand $count
    foreach t [list single 1x1 2H 2V 3H 3V 4H 4V] { lappend cand $t }
```
*Symptom:* the tail is appended for **every** count. For `wanted = 1` the candidate list
ends with `2H 2V 3H 3V 4H 4V`; for `wanted = 2` with `3H 3V 4H 4V`. `Adapter::SetWindowCount`
:1177-1189 applies each candidate to the live page and only then compares
`GetNumberOfWindows`. So a request for one window transiently switches the page to a
2/3/4-window layout — and on a page that already holds models, `SetLayout` to a *different*
count can drop windows together with their models.
*Evidence:* pure list arithmetic; no HyperView is needed to see that `2H` cannot mean one
window — the token's own name states the count.
*Provable test:* `lsearch LayoutCandidates 1 2H` is `-1`; `lsearch LayoutCandidates 2 2H`
is `>= 0`; `1x1` is absent from the candidates of 2; the candidate list of `n` contains no
legacy word whose leading integer differs from `n`; `2H`/`2V` are still offered for 2.
*Change:* the tail becomes count-scoped through a new pure helper
`Logic::LegacyLayoutTokens <count>` backed by a `legacyLayoutTokens` dict in
`namespace eval ::ModelLoader::Logic` (`1 -> {single 1x1}`, `2 -> {2H 2V}`,
`3 -> {3H 3V}`, `4 -> {4H 4V}`). The `lappend cand $count` line stays (the plain count is
the same count by name). Ordering, deduplication and "learned token first" are untouched,
so `Adapter::SetWindowCount` needs no change.
*Note:* the *words themselves* stay unverified — see V1/V14 in section 7. Restricting them
to their own count is what makes keeping them safe. The ordering documentation :446-460
(step 5 reads "the plain count and the legacy tokens (single, 2H, 2V, ...)") and the `V1`
registry entry :92-96 are reworded to "the plain count and the legacy tokens **of that
count**", so the prose matches the code.

### P2 — a negative or garbage answer is reported as a window count

*Where:* `Logic::InterpretWindowCount` :540-544
```tcl
    if {[string is integer -strict $raw] && $raw >= 0} { return $raw }
    return [llength $raw]
```
*Symptom:* `-1` fails the `>= 0` test and falls through to `llength -1`, which is **1**. A
page that answers `-1` (an error sentinel in several hwi wrappers) is therefore read as
"one window". Any non-numeric answer (`abc`) also becomes 1 through `llength`. The
consequence is visible at `Adapter::QueryPage` :1131
```tcl
    if {$pageIdx eq "" || $winCount < 0} { return {} }
```
— the guard that is supposed to detect an unreadable page cannot fire, because `-1` never
survives into `$winCount`. Today a page that answers `-1` is reported as a healthy page with
**one** window, and `Adapter::SetWindowCount` :1159 that is asked for one window then
believes the page already matches (`unchanged 1`) although nothing was read.
*Evidence:* `llength -1` = 1 and `llength abc` = 1 are core Tcl facts; the existing test only
asserts the weak property `>= 0` (:268-269). The L1 fake harness drives this end to end —
`::fake::win` (:678) is what `GetNumberOfWindows` returns (:764-773).
*Provable test:* `-1` → `0`; `-5` → `0`; `abc` → `0`; `0` → `0`; `{1 2 3 4}` → `4`;
`4` → `4`; `" 4 "` → `4`; `{1 x}` → `0`. Plus, against the fake: `::fake::win -1` →
`QueryPage` is `{}` (today: a page with `windows 1`), `::fake::win 0` → `{}`,
`::fake::win 4`/`1` → unchanged (:823-836).
*Change:* two coordinated edits, because either alone leaves the contradiction in place.
1. `InterpretWindowCount`: empty → `0`; a strict integer → its value with negatives clamped
   to `0`; a non-integer is a count **only** when every token is itself an integer (the
   `1 2 3 4` list form), otherwise `0`. The doc comment :527-539 states the sign and garbage
   rules.
2. `QueryPage`: the guard becomes `$winCount <= 0` (a page always has at least one window in
   HyperView, so a non-positive answer means "cannot read"), which makes the guard reachable
   — exactly what its comment claims.
*Why the clamp cannot write `0` into the UI:* `UI::OnApplyLayout` :3597-3598 already falls
back to `$wanted` when the read-back is `< 1`, and `UI::SetWindowCountValue` :2317 refuses
any `n < 1` without storing it.
*Rejected alternative:* returning `-1` so that `QueryPage`'s existing `< 0` guard fires. It
would contradict the documented contract "never returns a negative count" and the existing
test's title; clamping to `0` plus a reachable guard keeps one contract — the count is never
negative, and a non-positive count means the page was not read.


### P3 — the guessed token spellings are not marked as guesses

*Where:* `Logic::LayoutCandidates` :509-515 (four spellings `RxC`, `R X C`, `R x C`, `R - C`),
`Logic::LayoutPreference` :461 (`rows <= cols`).
*Symptom:* the four spellings and the "prefer the wide arrangement" convention are
presented as facts in the source, although only `SetLayout` itself is confirmed. A
maintainer reading the file cannot tell which parts a live HyperView could falsify.
*Provable test:* none of the *spellings* is provable — but the *ordering contract* is:
the learned token is always first (`:507-508` + the ordered dedup `:521-524`) and no
candidate is duplicated. Both get an explicit test so a later edit cannot silently break
them.
*Change:* prose only. The `V1` block :92-96 and the `LayoutCandidates` comment :432-460
state that the spellings and the `rows <= cols` convention are **unverified**, and new
`V14` (section 7) records exactly what a HyperView install has to confirm. No code change.

### P4 — the remembered legend file is written but never read back

*Where:* `UI::OnTargetWindowChanged` :2348-2361; `State::PruneTo` :278-288.
*Symptom:* `UI::OnLoadLegend` :3484 stores the loaded path per window
(`State::SetLegendFile`), but `OnTargetWindowChanged` only updates `varTargetWin`. Switch
the target window and the legend field still shows the *previous* window's file — the
per-window state the issue asks for is half-implemented (write-only). Second half: after a
layout change shrinks the page, `OnApplyLayout`/`OnRefreshWindow` call `State::PruneTo`
:3601, which drops `windows` entries above the new maximum but leaves
`legendFileByWindow` untouched; if the page later grows again, the stale path of the
recreated window index is offered as if it belonged to that window.
*Evidence:* `PruneTo` only ever touches the `windows` variable; `OnTargetWindowChanged`
contains no `GetLegendFile` call. The UI test only asserts the *write* side (:666-667) and
that the handler returns the widget's number (:465).
*Provable test (UI harness, no HyperView):* after `State::SetLegendFile 2 <path>`, calling
`OnTargetWindowChanged` with window 2 selected puts `<path>` into
`::ModelLoader::UI::varLegendFile` and into the widget; switching to window 3 (no legend)
clears both; a window with a remembered legend shows it again when re-selected.
`State::SetLegendFile 3 <path>` followed by `State::PruneTo 1` leaves
`State::GetLegendFile 3` empty while `GetLegendFile 1` survives.
*Change:* `OnTargetWindowChanged` restores the field from `State::GetLegendFile` after it
accepts a new target window (via the existing `UI::SetFileWidget`, which already tolerates
a missing widget). `State::PruneTo` also prunes `legendFileByWindow` above `maxIdx`.
*Note:* restoring an *empty* path for a window that has no legend is intended — the field
mirrors the window that is currently selected, which is what "state per window" means.

### P5 — the legend extension knowledge disagrees with the legend browser

Two halves, one root cause: the legend's extension list is not a single source of truth.

**P5a — three versions of "which legend files are accepted".**

*Where:*

| Source of truth | Value | Line |
|---|---|---|
| `legendExtensions` (used by `Adapter::LoadLegendFromFile`) | `.tcl .hvl .txt` | :409 |
| `Logic::LegendFileTypes` (the browser filter) | `{.tcl}`, `{.hvl}`, `{*}` | :639-645 |
| the user-visible hint of step 2 | "*.tcl …, *.hvl and *.txt are offered" | :2986-2989 |

*Symptom:* the hint promises `.txt` in a browser that does not offer it, and the loader
treats `.txt` as a *known* legend extension while the browser does not. Which of the three
is right is not written down anywhere.
*Evidence:* pure set comparison; the issue text says the legend feature accepts "*.tcl or
\*.hvl*".
*Provable test:* the set of non-`*` extensions of `LegendFileTypes` equals the set of
`LegendExtensions`; the same invariant already holds for the *sibling* pair
(`ViewListFileTypes` `{.txt .lst .csv}` + `{.tcl}` vs `ViewListExtensions`
`{.txt .lst .csv .tcl}`) and gets a test too, so the two file fields cannot drift apart
again.
*Change:* `legendExtensions` becomes `{.tcl .hvl}` (the browser's two entries, matching the
issue) and the step-2 hint :2988 is reworded to "*\*.tcl (an exported legend) and \*.hvl are
offered*". A `.txt` legend is **not** refused: it still loads, it only gets the honest
"unusual for a legend file - it is sourced anyway" warning (:1864). `All Files` stays in the
filter, so nothing becomes unreachable.

**P5b — the legend and view-list browsers warn about the wrong extensions.**

*Where:* `Logic::CheckChosenFile` :628-634
```tcl
    if {$kind eq "model"} { set known [::ModelLoader::Logic::ModelExtensions] } \
        else               { set known [::ModelLoader::Logic::ResultExtensions] }
```
reached from `UI::ApplyChosenFile` :2426 ← `UI::BrowseFile` :2420 ← the `Browse...` buttons
of the legend field :2978-2980 (`kind = legend`) and of the view-list field :3021-3023
(`kind = viewlist`).
*Symptom:* the `else` branch catches *everything that is not a model*, so a `.hvl` legend
picked through `Browse...` is announced as `"'.hvl' is unusual for a legend file - it is
passed to HyperView anyway"` — `hvl` is simply not in `ResultExtensions`
`{.res .op2 .odb .rst .d3plot .h3d .xdb .mvw}`. The same happens to `.txt` / `.lst` / `.csv`
view lists. The status line of a *correct* choice therefore reports a problem.
*Evidence:* `.hvl` and `.txt` are absent from `ResultExtensions`; `Adapter::LoadLegendFromFile`
:1863 and the view-list loader do it correctly, so only the browser path is wrong — the two
paths contradict each other for the same file.
*Provable test:* `CheckChosenFile <file.hvl> legend` has an empty `message`;
`<file.txt> viewlist` has an empty `message`; `<file.hvl> viewlist` and `<file.txt> legend`
**do** warn; an unknown kind (e.g. `whatever`) does not warn; the existing `model`/`result`
assertions :211-220 and UI :505-517 are unchanged; the browser warning text equals the
loader warning text for the same file and kind.
*Change:* a pure helper resolves the list by kind —
```tcl
proc ::ModelLoader::Logic::ExtensionsForKind {kind} {
    switch -exact -- $kind {
        model    { return [::ModelLoader::Logic::ModelExtensions] }
        result   { return [::ModelLoader::Logic::ResultExtensions] }
        legend   { return [::ModelLoader::Logic::LegendExtensions] }
        viewlist { return [::ModelLoader::Logic::ViewListExtensions] }
    }
    return {}   ;# an unknown field is never second-guessed
}
```
plus `Logic::KindLabel {kind}` (`viewlist` → `view list`, others unchanged) so the browser
warning reads like the loader warning. `CheckChosenFile` uses them, and an empty extension
list means "no warning" instead of "warn about everything". No UI call site changes, so
`CreateFileChooser` keeps its `legend` / `viewlist` names.
*Why it is in scope:* same defect class as P5a (two places deciding which legend file is
normal), provable without HyperView, and *inside* the STEP 2 field the issue asks about. It
is called out here so it can be dropped at review if you want the strict P1–P6 list.

### P6 — the step-3 preview and the capture disagree about "all windows"

*Where:* preview `UI::RefreshStep3` :3341-3345 vs engine `Adapter::CapturePng` :2038-2047.
```tcl
# preview                                   # engine
set indices [State::WindowIndices]          set indices [State::WindowIndices]
if {[llength $indices] == 0} {              if {[llength $indices] == 0} {
    set indices [list $varTargetWin] }          set page [Adapter::QueryPage]
                                                ... 1..N of the page ...
                                            }
                                            if {$scope eq "target"} { set indices [list $targetWindow] }
```
*Symptom:* for `scope = all` on a page whose windows the wizard has not loaded yet (a fresh
HyperView session — the normal case), the preview says **"1 PNG file(s) would be written"**
because it falls back to the target window, while the capture enumerates every window of the
page and writes `N x views` files. The plan in the information pane is the promise the user
acts on, so the promise is wrong exactly where STEP 3 ("capture every window") matters. The
two rules have to be one rule.
*Evidence:* the fallback lines differ (`{targetWindow}` vs `1..page windows`), and no test
covers `RefreshStep3` with `scope = all` (the UI test only refreshes with `target` :821-830).
*Provable test:* `Logic::CaptureWindowSet` unit cases — `target 2 {1 2 3}` → `{2}`,
resolvable; `all 1 {1 3}` → `{1 3}`, resolvable; `all 1 {}` → `{}`, **not** resolvable;
`target 2 {}` → `{2}`, resolvable. UI test — `scope = all`, four views, no window loaded and
no `hwi` (so the page cannot be read): the pane must **not** claim `1 PNG file(s)` nor
`4 PNG file(s)`, and must show the honest "not known here" line; `scope = target` keeps
claiming `4 PNG file(s)`. Source test — `CapturePng all …` :1113-1139 (2 windows) and
`CapturePng target …` :1142-1150 are unchanged, and `CapturePng all` with no window and no
`hwi` :596-598 still reports "there is no window to capture".
*Change:* one pure decision function, used by both sides —
```tcl
# {windows <list> resolvable <0|1>}
proc ::ModelLoader::Logic::CaptureWindowSet {scope targetWindow windowIndices} {
    if {$scope ne "all"} { return [list windows [list $targetWindow] resolvable 1] }
    if {[llength $windowIndices] == 0} { return [list windows {} resolvable 0] }
    return [list windows $windowIndices resolvable 1]
}
```
plus one adapter helper that owns the "1..N of the page" loop so it exists once:
`Adapter::PageWindowIndices`, moved verbatim out of `CapturePng` :2039-2046.
`CapturePng` uses the helper and, when the set is not resolvable, falls back to
`PageWindowIndices` — exactly today's behaviour, minus the page read that `CapturePng`
currently performs **even for `scope = target`** (a needless `hwi` round trip that can make a
target capture fail on a page that is unreadable as a whole).
`RefreshStep3` uses the same helper and, when the set is still not resolvable, prints
`  files         : not known here - the page could not be read, so the file count of 'all'
is decided when the capture starts` instead of a number it cannot know. With a reachable
HyperView the preview therefore prints the *real* count; without one it stops lying.
*Rejected alternative:* keeping the `{targetWindow}` fallback and labelling it — the pane
would then show a number that is knowingly wrong for the selected scope.

## 6. Test strategy

### 6.1 Three layers, two of them runnable here

| Layer | File | What it proves | How it runs here |
|---|---|---|---|
| L1 — pure logic | `selftest_hv_model_loader.tcl` | `Logic` + `State` + adapter guards, no Tk, no `hwi` | `python run_selftest.py` → exit 0 |
| L2 — UI under stubs | `selftest_ui_hv_model_loader.tcl` | widget wiring, handlers, the pane, with a `hwtk`/`hwi` stub | `python run_ui_selftest.py` → exit 0 |
| L3 — live HyperView | *(does not exist)* | the `V`-markers | **out of scope** — a host without HyperView cannot run it; the markers carry the uncertainty instead |

Baseline that must not go down: **L1 = 401 checks, 0 failed** (measured at `abb1cf8`), L2 =
all checks green. Every fix below **adds** checks; none may be deleted except the five
listed in 6.3, which are replaced by stricter ones.

### 6.2 TDD loop (per defect, per commit)

1. Add the check(s) that describe the wanted behaviour → run the runner → **RED** (record
   the failure line in the plan).
2. Fix the code → run again → **GREEN** for L1 *and* L2.
3. Refactor only with both runners green.
4. One Conventional-Commits commit per defect (`fix(logic): …`, `fix(ui): …`, `test: …`).
   The `RED` output belongs in the plan document, not in the commit message.

Because L1 has no Tk and no `hwi`, a defect that can only be seen in the UI gets its check
in L2 against the stub — the stub is what makes P4/P6 testable at all.

### 6.3 Existing checks that change (all five are *strengthened*)

| File | Line | Today | After |
|---|---|---|---|
| L1 | :359-360 | "the legacy tokens survived" — `2H` in the candidates of 4 | `4H`/`4V` are in the candidates of 4, and `2H`/`single` are **not**; `2H`/`single` are in the candidates of 2 / 1 |
| L1 | :268-269 | "never returns a negative count" — `>= 0` | `-1` returns exactly `0`; `-5` returns `0`; `abc` returns `0` |
| L1 | :390-391 | "the legend extensions" — `.tcl .hvl .txt` | `.tcl .hvl`, plus the filter/extension invariant |
| L2 | :560-561 | "the legacy tokens are still tried" — `2H` **and** `single` in the candidates of 4 | `4H` in the candidates of 4, `single` absent; `2H` present for 2 |
| L2 | :622-623 | "the legend extensions are declared" — `.tcl .hvl .txt` | `.tcl .hvl` |

Nothing else in either file is weakened.

### 6.4 The runners (new files, committed)

Both are thin, dependency-free launchers around the interpreter the host actually has
(Python 3.12 + Tcl/Tk 8.6.13), because there is no `tclsh`/`wish` here and the UI selftest's
own header (:31-34) already points at `python run_ui_selftest.py`.

Shared contract:

* usage `python run_selftest.py [script.tcl …]`, default script = the sibling selftest;
* `sys.exit` code = the code the selftest passed to `exit` (0 = all checks passed, 1 = a
  check failed), so CI can gate on it; a `TclError` that is *not* an `exit` is reported and
  also returns 1;
* `cd`-independent: the script is sourced by absolute path, so `[info script]`-based `$here`
  resolution inside the tests keeps working;
* `exit` is provided as a Tcl command that raises a private exception — the embedded interp
  has no `exit` (`info commands exit` → empty), and without the shim every run would die
  with `invalid command name "exit"`;
* stdout/stderr pass through unchanged, so the `OK`/`FAIL` line stream is visible.

`run_selftest.py` uses `tkinter.Tcl()` (pure Tcl, no display needed).
`run_ui_selftest.py` uses `tkinter.Tk()` (the L2 test creates widgets and calls
`update idletasks`), keeps the root hidden-free — i.e. it does not `withdraw` a window the
test may rely on — and destroys the root before returning.

`README.md` gets the two commands next to the existing `tclsh` line, so the documented route
and the actual route agree.

## 7. Verification markers (`V`)

The file keeps a marker registry in its header (:92-130, `V1`–`V13`) plus per-`proc` notes
(`V1` :433-436 with the ordering documentation :446-460, `V2` :394-396, `V3` :398-400,
`V12` :402-404, `V13` :2098-2100, …). This pass keeps that convention:

* **No marker is removed or "resolved".** Nothing in this pass can confirm a HyperView API
  from a host without HyperView; the markers stay exactly as uncertain as they are.
* **`V1` is narrowed, not weakened.** After P1 the comment states the new, provable part
  ("a legacy word is only ever tried for its own count") *and* keeps the unverified part
  ("the words themselves are historical Altair spellings and are not confirmed on this
  installation").
* **`V14` (new)** is added both to the registry (:130, after `V13`) and next to the layout
  code (:433-460), to record precisely what a HyperView install must confirm and what
  happens if it is wrong:
  * the *native* token of the small counts (is one window `1x1`, `1` or `single`? is two
    windows `1x2` or `2x1`?) — the wizard asks HyperView and caches the answer
    (`State::layoutTokenByCount`), which is why the legacy words are safe to keep last;
  * the arrangement spelling (`2x2`, `2 X 2`, `2 x 2`, `2 - 2`) and the `rows <= cols`
    preference — a refusal is harmless (the next candidate is tried) and the winner is
    verified by reading `GetNumberOfWindows` back.
  Failing side, stated in the marker: if a guessed word *is* accepted for the wrong count,
  the count is read back afterwards and the token is not cached; but a page that already
  held models could have lost windows. That is why P1 scopes the words to their own count
  even though the words are unverified.

## 8. Out of scope (recorded, not closed)

* **The STEP 3 view-selection combobox.** The issue asks to "populate a list/combobox
  allowing the user to select from those imported views". Today step 3 applies *every*
  entry of the imported view list to the capture (`State::GetViewList` →
  `Logic::CapturePlan`); there is no per-view selection widget, no state slot to remember a
  choice, and no `V`-marked HyperView call involved. Adding it means a new widget, a new
  `State` entry, persistence across refreshes and its own tests — a new feature, not
  hardening. It is the one item that has to be planned on its own.
* **No live-HyperView test harness.** L3 stays "the markers", as decided in D-2.
* **No changes to model/result loading** (`AddModel`, reader detection, `LoadInputs`) or to
  the STEP 1 fields beyond the P5b extension-warning fix, which is reachable from step 1's
  browser too but only *corrects* its message.
* **`.txt` legends stay loadable.** P5a changes the *warning*, not the ability to source a
  `.txt` file.
* **`V`-marked calls are not rewritten**, only annotated (section 7).
* **No reformatting, renaming or re-layout of the file.** Diffs stay minimal and reviewable.

## 9. Risks and open questions

| # | Risk | Mitigation |
|---|---|---|
| R1 | P4: restoring the legend field could wipe a path the user is typing | the read-back happens only when the *accepted* target window differs from the previous one, so re-firing the handler for the same window is a no-op |
| R2 | P6: the preview now reads the page for `scope = all` | only when no window is loaded yet, once per refresh; a failure yields the honest "not known here" line, never an error |
| R3 | P6: `CapturePng` no longer reads the page for `scope = target` | this removes a `hwi` call nothing used — the target window never depended on the page count |
| R4 | P5a: a `.txt` legend now shows a warning it did not show before | status line only, the file still loads; it is the same warning the feature already produces for every other unusual extension |
| R5 | P4: pruning legend paths could drop a path a user still expects | only indexes above the new maximum, i.e. windows that no longer exist; the surviving ones are untouched and `PruneTo`'s return value is unchanged |
| R6 | five existing checks change (6.3) | each is replaced by a strictly stronger one; the count of checks only grows |

Open questions for the review gate:

1. **P5b in or out?** It is the same defect class as P5a but touches `CheckChosenFile`,
   which step 1 also calls. Recommended: **in** (it is provable and user-visible).
2. **P5a direction:** drop `.txt` from the legend list (recommended, matches the issue) or
   add `.txt` to the legend browser (keeps today's silent accept, grows the filter to three
   entries plus `All Files`)?
3. **Wording** of the step-3 "not known here" line (P6) — it is the only new user-visible
   string besides the step-2 hint.

## 10. Acceptance criteria

A maintainer must be able to reproduce all of the following:

1. `python run_selftest.py` → prints the L1 summary with **0 failed** and **exits 0**
   (check count ≥ the 401 baseline).
2. `python run_ui_selftest.py` → **0 failed** and **exits 0**.
3. `git log --oneline` on `hardening/step1-3` shows one Conventional-Commits commit per
   defect, and the plan records the RED run that preceded each GREEN one.
4. `grep -n "V14" hv_model_loader.tcl` finds the new marker; the `V1` block still names the
   legacy words as unverified; no `V` marker was deleted.
5. `README.md` documents both runner commands.
6. Both layering invariants hold as tests: `LegendFileTypes` ↔ `LegendExtensions` and
   `ViewListFileTypes` ↔ `ViewListExtensions`.
7. No file outside `tcl_guide/` changed, and no test check was weakened.






