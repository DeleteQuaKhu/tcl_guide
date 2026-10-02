# tcl_guide
HyperView 2022 Tcl/Tk (hwtk) model loader + contour guide script

---

# hv_model_loader.tcl - HyperView 2022 model loader + contour wizard

A single-file Tcl wizard for **HyperView 2022** that

1. sets the window layout of the active page and loads a **model file and/or a
   result file per window** (Abaqus `*.inp` for the model, FEMFAT `*.res` and
   the common result formats for the results), then
2. applies a contour plot (subcase, simulation, result type, component,
   averaging, layer) to the chosen window - or to every loaded window at once.

Everything lives in one file.  The only thing the file needs besides plain Tcl
is the HyperWorks Tk library (`hwtk`) that ships with HyperView.

---

## 1. Files

| File | Purpose |
|------|---------|
| `hv_model_loader.tcl` | The wizard itself (single file, no other file required). |
| `selftest_hv_model_loader.tcl` | Plain-Tcl smoke test (State / Logic / the non-hwi Adapter paths / pure UI helpers). No hwtk, no HyperView needed. |
| `selftest_ui_hv_model_loader.tcl` | GUI smoke test. Replaces `hwtk` with stubs built on stock Tk and builds the whole dialog headless, so wrong widget paths, unknown options, bad `grid`/`pack` usage and handler arity errors are caught without HyperView. |

---

## 2. Requirements

* Altair HyperView **2022** (nothing introduced later is used).
* Plain Tcl **8.5+** for the tests (`tclsh`).  The wizard itself is only ever
  sourced inside HyperView.
* No external package, no additional `.tcl` file, no `.pkgIndex.tcl`.

---

## 3. Usage

Inside HyperView, in the command line / Tcl console:

```tcl
source "hv_model_loader.tcl"
::ModelLoader::Show        ;# or the short alias:  mlShow
```

The dialog opens at the mouse pointer.

### Step 1 - layout and model loading

| Widget | What it does |
|--------|--------------|
| *Windows on the active page* | Target number of windows (1 2 3 4 6 8 9 12 16 - any other positive number you type is added to the list). The value you enter is **kept and applied**, also when the layout request is refused (fix 1). |
| **Apply layout** | Sets the active page to that many windows (see V1). Already correct layouts are left untouched. |
| **Refresh page info** | Re-reads page index, window count and layout token and prints them. |
| *Target window* | The window the following actions work on. Your selection is never reset by a refresh - the list simply grows when the page has fewer windows (fix 1). |
| *Input Model* | `hwtk::openfileentry` (or an entry + **Browse...**) with a **model** filter: `*.inp` (Abaqus) first, then `*.bdf/*.dat/*.nas` (Nastran), `*.fem` (OptiStruct), `*.h3d`, `*.odb` and an `All Files` entry. |
| *Input Result* | Same widget with a **result** filter: `*.res` (**FEMFAT**) first, then `*.op2` (Nastran), `*.odb` (Abaqus), `*.rst` (Ansys), `*.d3plot` (LS-DYNA), `*.h3d` and an `All Files` entry. |
| **Browse...** (per field) | Opens `tk_getOpenFile -filetypes <the same list>` - usable in every build, no matter whether the `openfileentry` widget or its `-filetypes` option is available. The chosen path is normalised, checked and written back into the field. |
| **Load into window** | Loads the model file, the result file, or both, into the target window and immediately re-reads its result tree (see V5 / V10). There is **no Reader field**: the reader is detected from the file itself (fix 2). |
| **Re-read results of this window** | Rebuilds the subcase / simulation / result-type / component tree of a window without reloading the file. |
| *Information pane* | One line per loaded window: file(s), subcases, simulations, result types, components - plus a `note:` / `warning:` line for anything that was only partly accepted (including the reader *suggestion* of `Logic::ReaderHint`, which is never passed to HyperView). |

Fill in **only what you have**: model only, result only, or both.  If both are
given, the model is loaded first and the result file is attached to it
(`<model> SetResult`, see V10).  Both paths are handed to HyperView **without a
reader label** - `AddModel`/`SetResult` detect the reader from the file (fix 2).
Repeat *Load into window* once per window; each window keeps its own file(s).

### Step 2 - contour

| Widget | What it does |
|--------|--------------|
| *Target window* | Window to apply the contour to. |
| *Model* | Name of the file loaded in that window (read-only display). |
| *Subcase* | Subcase label of that window. |
| *Simulation* | `<default>` = leave the current simulation untouched, otherwise the simulation is selected by index. |
| *Result type* | Data type list of the selected subcase. |
| *Component* | Component list of the selected result type. |
| *Averaging* | `<default>` or one of the V2 strings. |
| *Layer* | `<default>` = skip the layer call completely, otherwise one of the V3 strings. |
| **Apply to all loaded windows (same subcase label)** | Fans the settings out to every loaded window that has a subcase with the same label; windows without it are reported as skipped. |
| **Reload lists** | Manual refresh of subcase / result type / component lists (fallback for V9). |
| **Apply contour** | Runs the contour for the selected job(s) and reports OK / FAIL plus any V2/V3/V4 warnings per window. |

Buttons: **< Back**, **Next >**, **Apply contour**, **Close** (plus the dialog's
`cancel` re-bound to Close).

---

## 4. Architecture (three layers in one file)

| Section | Namespace | Rules |
|---------|-----------|-------|
| 0 | `::ModelLoader` | Bootstrap: `package require hwt hwtk`, verify that the needed `hwtk::*` commands exist, `Show` / `mlShow`. |
| 1 | `::ModelLoader::State`, `::ModelLoader::Logic` | Pure Tcl. **No `hwi`, no `hwtk`.** All testable without HyperView. |
| 2 | `::ModelLoader::Adapter` | The **only** place that calls `hwi`. Every call goes through `Adapter::HvRun`, which wraps it in `catch`, logs it and stores the message in `State::lastError` - nothing is ever thrown at the GUI. |
| 3 | `::ModelLoader::UI` | hwtk widgets only, calls Logic + Adapter. |

Debug logging: `set ::ModelLoader::debug 1` prints every `hwi` call and its
result (including failures) to the Tcl console.

Handle hygiene: every object handle (`mlSess`, `mlProj`, `mlPage`, `mlWin`,
`mlClient`, `mlModel`, `mlResult`, `mlContour`, `mlLegend`) is released through
`Adapter::ReleaseHandles`, so `info commands`-based lookups never leave stale
handles behind.  `hwi OpenStack` / `hwi CloseStack` are paired around every
adapter entry point.

---

## 5. hwi commands used

```
hwi        OpenStack, CloseStack, GetSessionHandle
<session>  GetProjectHandle
<project>  GetActivePage, GetPageHandle, GetNumberOfPages, AddPage
<page>     GetWindowHandle, GetNumberOfWindows, GetActiveWindow,
           GetLayout, SetLayout
<window>   GetClientHandle
<client>   Draw, GetActiveModel, GetModelHandle, GetModelList, AddModel,
           RemoveAllModels, SetDisplayOptions
<model>    GetFileName, GetResultCtrlHandle, SetResult (V10), AddResultFile (V10)
<result>   GetSubcaseList, GetSubcaseLabel, GetCurrentSubcase,
           SetCurrentSubcase, GetSimulationList, GetCurrentSimulation,
           SetCurrentSimulation, GetNumberOfSimulations, GetDataTypeList,
           GetDataComponentList, GetContourCtrlHandle
<contour>  SetDataType, SetDataComponent, SetAverageMode, SetEnableState,
           SetLayer, GetLegendHandle
<legend>   SetType
any handle ReleaseHandle
```

---

## 6. hwtk / hwt commands used

```
hwtk::dialog        (options -propagate -buttonboxpos -minwidth -minheight
                     -x -y -title, methods recess / insert apply /
                     buttonconfigure / hide / post)
hwtk::frame         hwtk::labelframe   hwtk::label    hwtk::button
hwtk::entry         hwtk::openfileentry (-filetypes, see V5)
hwtk::combobox      (-state readonly -values -textvariable, configure -values,
                     bind <<ComboboxSelected>> / <Return> / <FocusOut>)
hwtk::checkbutton   (-variable)
```

Plain Tk is used in exactly **three** places plus the modal warnings:

* the read-only **information pane** - `listbox` + `scrollbar` inside a
  `hwtk::labelframe`, because hwtk has no listbox wrapper;
* `tk_getOpenFile` for the two **Browse...** buttons of step 1 (with the same
  `-filetypes` list the fields offer), which also serves as the fallback browser
  when a build has no `hwtk::openfileentry` or refuses `-filetypes`;
* `tk_messageBox` for the blocking validation / error pop-ups.

The fields themselves degrade in three steps, so the two inputs work in every
build: `hwtk::openfileentry -filetypes` -> `hwtk::openfileentry` without the
option -> `hwtk::entry` + the **Browse...** button.

The dialog buttons are added with `$dlg insert apply <key>` exactly like the
real HyperView script `review_tools.tcl` does.  If that method is unavailable in
a build, the wizard silently falls back to its **own button bar** inside the
recess (`Adapter::Log` records the reason), so the GUI stays usable.

---

## 7. "# VERIFY:" list - every item that could not be confirmed for 2022

All of them are marked in the code with a `# VERIFY:` comment (V1 - V10) and are
written so that a wrong guess degrades instead of failing:

| # | Item | What is done / how to adapt |
|---|------|-----------------------------|
| **V1** | `<page> SetLayout <token>` | The call itself is confirmed (real scripts call `pageHandle SetLayout $layout`), but the accepted token spelling is installation specific. `Logic::LayoutCandidates` tries candidates (`1x2`, `2x1`, `1 X 2`, `1 x 2`, `2`, `single`, `2H`, ...), keeps the first token whose `GetNumberOfWindows` matches and caches it in `State::layoutTokenByCount`. An already correct layout is never touched. |
| **V2** | `<contour> SetAverageMode <mode>` | Mode strings `None Simple Advanced Maximum Minimum` live in `Logic::averagingModes`. Non-fatal: a refused mode is reported as a warning for that window. Adjust the list if your installation spells them differently. |
| **V3** | `<contour> SetLayer <layer>` | `Logic::layerChoices` = `<default> Z1 Z2 Lower Upper Mid`. `<default>` makes the adapter skip the call completely, so a build without `SetLayer` still works; a refused layer is a warning, not an error. |
| **V4** | `<contour> GetLegendHandle` + `<legend> SetType dynamic` | Non-fatal. If the legend handle or the dynamic legend type is refused, the contour is still applied and a warning is printed. |
| **V5** | `<client> AddModel <file>` | Called with **one** argument - no reader label (fix 2: there is no *Reader* entry any more, HyperView detects the reader from the file itself, which is how the shipped examples call it). If a build should refuse that, use *File > Load > Model* in HyperView. Reader labels are installation specific, so no guess is handed over; `Logic::ReaderHint` only prints a *suggestion* for the chosen extension into the info pane / status line. `hwtk::openfileentry -filetypes` may be refused by a build - the field is then recreated without that option, and the **Browse...** button still offers the full filter list. |
| **V6** | `<result> GetDataComponentList <subcaseId> <dataType>` | Queried for every result type of every subcase while the result tree is built; the form is the one used by Altair's own `result_service.tcl`. If the call is refused, the result tree still lists subcases / simulations / result types. |
| **V7** | `hwtk::dialog` modality (`-modal`) | **Not used.** The dialog is created with only the options seen in real HyperView scripts, so it cannot fail on an unknown option. Add `-modal 1` yourself if your build accepts it. |
| **V8** | `hwtk::combobox configure -values <list>` | Used to re-populate the subcase / result type / component lists. hwtk comboboxes are ttk widgets, so `-values` is a list option and the list is passed **as it is** (wrapping it in `[list ...]` would glue all entries into one). |
| **V9** | `<<ComboboxSelected>>` on hwtk comboboxes | Bound so that changing the subcase refills the result type list and changing the result type refills the component list. If a build does not generate the virtual event, the **Reload lists** button in step 2 does exactly the same job. The same event - plus `<Return>` / `<FocusOut>` - guarantees that the window count and the target window reach their variables (fix 1). |
| **V10** | Attaching a **result** file to a model that is already in the window | `Adapter::AttachResult` tries `<model> SetResult <resultFile>` first (the documented, reader-free way - `AddModel <result>` alone only reports the file and never attaches it, which was bug 2), falls back to `<model> AddResultFile <resultFile>` and then to `<client> AddModel <resultFile>`. **A refusal is never fatal**: the model stays loaded and the reason is printed as a `warning:` line with the hint to use *File > Load > Results*. If only a result file is given, it is loaded with a single `AddModel` and HyperView builds the model from it. |

---

## 8. Tests

Both tests run in a normal `tclsh` - no HyperView, no `hwtk` package, no GUI
display needed.

```powershell
tclsh selftest_hv_model_loader.tcl       ;# pure Tcl layers
tclsh selftest_ui_hv_model_loader.tcl    ;# whole GUI against hwtk stubs
```

Exit code `0` = every check passed, `1` = at least one check failed.

### `selftest_hv_model_loader.tcl` (source-only)

Everything that contains no `hwi` and no widget call: the `State` store, the
`Logic` helpers (subcase / simulation / component tree, spec assembly and
fan-out, validation, the two file-type filters, `ReaderHint` - now a status-line
suggestion only - and `CheckChosenFile`), the pure `UI` helpers (including
`ReadWindowCount` / `InterpretWindowCount` of fix 1) and the adapter paths that
fail before an `hwi` call is reached.

Section **4b** additionally installs a small **fake `hwi`** (skipped if a real
`hwi` is present, so the file is safe to source inside HyperView) and walks the
whole reader-free load sequence of fix 2 with it: model only, model + result via
`SetResult`, via the `<model> AddResultFile` fallback and via the legacy
`AddModel` form, all attach forms refused (warning path, model stays loaded),
result only, and `LoadAllAndRefresh` carrying `mode` + `warnings` into the result
tree.  `GetNumberOfWindows` answers with the scalar `4` in one scenario and with
the list `1 2 3 4` in the other, so both shapes of fix 1 are covered.  Its last
line is `ALL CHECKS PASSED` (203 checks; the line above it prints
` source test   : 203 passed, 0 failed`).

### `selftest_ui_hv_model_loader.tcl` (GUI)

It first defines a stub `hwtk` namespace: every `hwtk::frame / label /
labelframe / button / entry / openfileentry / combobox / checkbutton` is a thin
wrapper around the corresponding ttk/Tk widget, and `hwtk::dialog` is a frame
that additionally understands the methods `recess`, `insert apply`,
`buttonconfigure`, `hide` and `post`.  Because of that the **real** `UI::Build`
code runs and is verified:

* `Bootstrap` succeeds with the stubs in place,
* the whole dialog including banner, both steps, information pane and status
  line is built, once with `insert apply` **and** once with the own-button-bar
  fallback,
* `ShowStep` 1/2, `StepNext`, `StepBack`, `RefreshWindowList`, `RefreshStep2`,
* every event handler: `OnSubcaseChanged`, `OnDataTypeChanged`,
  `OnApplyLayout`, `OnRefreshPage`, `OnLoadModel`, `OnRefreshWindow`, `OnApply`,
* `DoClose` and a second `Build` afterwards.

Section **5b** is the regression test of **fix 1** (the window field keeps the
number the user picked - in the variable *and* in the widget - also when the
layout request is refused, the target window is no longer reset to 1, and
`Logic::InterpretWindowCount` reads both the scalar and the list answer of
`GetNumberOfWindows` as the real count, while plain `llength` would answer 1 for
the scalar).
Section **5c** is the regression test of **fix 2** (`*.inp` in the model filter,
`*.res` in the result filter, `CheckChosenFile` accepting/rejecting paths,
`ApplyChosenFile` writing the normalised path back, both paths reaching the
adapter, and - since the reader entry was removed - that no `Load into window`
path needs a reader field while the `ReaderHint` suggestion survives).

Every `hwi` call fails in this environment - which is exactly the point: the
test proves that all of those failures are reported to the user instead of
aborting the GUI.  Expected summary:

```
 UI smoke test : 149 passed, 0 failed
 stub notes    : 4 (unmodelled options, pop-up windows and the missing hwi - expected;
                 three of them are the tk_messageBox warnings of the fix-2 failure paths)
```

---

## 9. Troubleshooting

| Symptom | Cause / fix |
|---------|-------------|
| `ModelLoader needs the HyperWorks Tk library (hwtk). Missing: ...` | The wizard was sourced outside HyperView, or `hwt` / `hwtk` could not be loaded. Source it inside HyperView (`source hv_model_loader.tcl`). |
| `Apply layout` reports "no candidate worked" | V1: the layout token of your installation has another spelling. Add it to `Logic::LayoutCandidates` (or run the wizard once with a manually correct layout - the token is then cached in `State::layoutTokenByCount`). The number you typed **stays in the field** so you can simply press *Apply layout* again after the manual layout. |
| The window count / target window "jumps back" to 1 | Fixed (fix 1). If you still see it, the combo box of that build neither honours `-textvariable` nor emits `<<ComboboxSelected>>` - press `<Tab>`/`<Return>` in the field (the `<FocusOut>` / `<Return>` binding normalises and keeps the value) and check the info pane, which always prints what was really applied. |
| `Cannot read the active page` | `hwi OpenStack` or one of the `Get*Handle` calls failed. `set ::ModelLoader::debug 1` then repeat the action - the console shows the exact failing call. |
| No subcases / result types listed | The file in that window holds no result data, or `GetDataTypeList` was refused. Press **Re-read results of this window**. |
| The component list stays empty | V6: `GetDataComponentList` was refused for that result type. The result type can still be applied; pick the component in HyperView's own contour panel. |
| Averaging / layer / legend warning in the information pane | V2 / V3 / V4 - the contour itself was applied; only the optional refinement was refused. |
| Step 2 lists do not follow the subcase | V9: the build does not emit `<<ComboboxSelected>>`. Press **Reload lists**. |
| `.inp` / `.res` files do not show up in the browser | The filter list is the first entry of each field (`Abaqus Input Files`, `FEMFAT Result Files`). Pick the `All Files` entry at the end of the list, or type/paste the path into the field - the path is then normalised and checked when you press *Load into window*. |
| `note : '.xyz' is unusual for a model file` | Only a hint - the file is passed to HyperView anyway (`AddModel <file>` detects the reader). Rename the file to its usual extension if the detection picks the wrong reader. |
| `warning : the result file '...' could not be attached` | V10: none of `model SetResult <result>`, `model AddResultFile <result>` and `client AddModel <result>` was accepted. The model is loaded; add the results with *File > Load > Results*. |
| Contour applied but nothing visible | The contour is switched on with `SetEnableState true` and `SetDisplayOptions contour true`; if the display options call is refused, enable the contour in HyperView manually. |

### Limitations

* **2022 only.** Nothing newer than 2022 is used; on 2023+ everything should
  still work but the automatic token/reader discovery may find different names.
* The wizard works on the **active page** only.  Multi-page handling
  (`AddPage`, `GetNumberOfPages`) is prepared in the adapter's command list but
  not driven by the GUI.
* No undo: applying a contour changes the window immediately.
* Attaching a result file to an already loaded model (V10) is the one step whose
  exact API could not be confirmed for 2022; the three known forms are tried
  (`model SetResult`, `model AddResultFile`, `client AddModel`) and a refusal is
  only a warning, so a failed attach never blocks the workflow.
* The two file fields are remembered per window in the State layer, but only the
  files that HyperView itself reports (`<model> GetFileName`) are re-read when a
  window is refreshed.
* No persistent settings; the dialog starts from its defaults after each
  `::ModelLoader::Show`.

---

## 10. Bugs found and fixed (kept for reference)

The GUI smoke test found four real defects that a source-only test cannot see -
all fixed in `hv_model_loader.tcl`:

1. `Bootstrap` looked up `hwtk::dialog` etc. **unqualified**.  Inside
   `::ModelLoader` Tcl resolves that against the current namespace, so every
   command was reported missing.  Now `::hwtk::$cmd` is checked.
2. `UI::SetComboValues` passed the values as `[list $values]`, which wrapped the
   list and made the combobox show one glued entry.  The list is now passed as
   it is (V8).
3. `UI::AddButton` / `UI::SetButtonState` used capitalised widget paths
   (`...btnbar.Apply`).  Tk refuses path components starting with a capital
   letter; the key is now lower-cased.
4. The stub `hwtk::dialog` of the test created its proc inside the `::hwtk`
   namespace, so `rename`ing the underlying Tk command failed.  Fixed in the
   test with `uplevel #0 [list proc ...]` plus fully qualified `rename ::$path
   ::$tkcmd`.

Three more defects were reported from real use and fixed in this revision:

5. **The "windows on the active page" value reset to 1.**  Two causes, both
   removed: `UI::RefreshWindowList` force-wrote `[lindex $choices 0]` (= 1) into
   the target-window field whenever the value was not in the list it had just
   rebuilt from the page - and the page only reports the windows that exist
   *right now* (1 before a layout is applied) - and both step-1 number fields
   were read from the Tcl variable only, although nothing ever wrote an applied
   value back.  Now: `UI::ReadWindowCount` reads the **widget first**, the value
   is written back into variable **and** widget, an unknown-but-valid number is
   added to the offered values instead of being dropped, a refused layout keeps
   the number, and `RefreshWindowList` never overwrites the user's choice (it
   extends the list instead).  Covered by section 5b of the GUI test.
6. **`*.inp` and `*.res` could not be selected.**  The old build had a single
   combined field with a result-only filter list.  There are now two fields:
   *Input Model* (`Logic::ModelFileTypes`, `*.inp` first) and *Input Result*
   (`Logic::ResultFileTypes`, `*.res`/FEMFAT first), each with a **Browse...**
   button that calls `tk_getOpenFile -filetypes` with the very same list, and
   `Logic::CheckChosenFile` normalises/validates the chosen path before it is
   loaded (`Adapter::LoadInputs` -> V10).  Covered by section 5c of the GUI test
   and section 4b of the pure test.
7. **`[expr {... \"\" ...}]` inside a quoted string.**  The braces already
   protect the quotes, so `expr` received literal backslashes
   (`invalid character "\" in expression`).  The load *success* path of
   `OnLoadModel` therefore threw as soon as a file really loaded - it was never
   reached in the earlier stubs-only runs.  All five occurrences now use plain
   `""`, and section 5c and the fake-`hwi` section execute those branches.

Three defects were reported from real use *after* that and are fixed in this
revision:

8. **The window count jumped back to 1 after *Apply layout*.**  `OnApplyLayout`
   derived the new number from `[llength [<page> GetNumberOfWindows]]`; HyperView
   answers with a **number** (`4`), and `[llength 4]` is `1` - so every refresh
   wrote 1 back.  `Logic::InterpretWindowCount` now turns both the scalar and the
   list form into the real count, `OnApplyLayout` writes the applied number into
   the variable **and** the widget, and `UI::SetWindowCountValue` adds an
   unknown-but-valid number to `-values` instead of dropping it.  Covered by
   section 5b of the GUI test and by the fix-1 block of the pure test (the fake
   `hwi` switches between the scalar and the list answer).
9. **Results were never attached** (`<client> AddModel <resultFile>` only reports
   the file; it does not attach its results to the model already in the window).
   `Adapter::AttachResult` now tries `<model> SetResult <resultFile>` first,
   `<model> AddResultFile <resultFile>` second and the old `AddModel` call last,
   and reports every refusal as a `warning:` - the model stays loaded.  Covered
   by the fake-`hwi` scenarios of the pure test (all three forms, plus the
   all-refused warning path).
10. **The reader entry was pointless.**  `AddModel` detects the reader from the
    file, so the *Reader* field (with its installation-specific labels) was
    removed from step 1: `Logic::ReaderHint` only prints a suggestion into the
    status line / info pane, and nothing is handed to `hwi` any more.  The GUI
    test asserts that neither `UI::varReader` nor `UI::wReader` exists and that
    the note "the reader is detected automatically from the file" is shown.
    Step-1/step-2 signatures dropped their reader argument; a legacy 5-argument
    `Adapter::LoadInputs` call is still understood (the extra argument is then
    used as the result path).

Two harness bugs were fixed on the way (they only ever affected the tests): the
multi-pattern `-` fall-through of the fake-`hwi` `switch` needs a `-` on **both**
sides of a line continuation, and `UI::WidgetText` now guards `winfo` so the
pure test can exercise the widget-first fallback without Tk.

