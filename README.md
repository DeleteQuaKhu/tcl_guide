# tcl_guide
HyperView 2022 Tcl/Tk (hwtk) model loader + contour guide script

---

# hv_model_loader.tcl - HyperView 2022 model loader + contour wizard

A single-file Tcl wizard for **HyperView 2022** that

1. sets the window layout of the active page and loads one model / result file
   **per window**, then
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
| *Windows on the active page* | Target number of windows (1 2 3 4 6 8 9 12 16). |
| **Apply layout** | Sets the active page to that many windows (see V1). Already correct layouts are left untouched. |
| **Refresh page info** | Re-reads page index, window count and layout token and prints them. |
| *Target window* | The window the following actions work on. |
| *Model / result file* | `hwtk::openfileentry` with a result-file filter. |
| *Reader (optional)* | Reader label for `AddModel` (see V5). Empty = let HyperView pick the reader from the file extension. |
| **Load into window** | Loads the file into the target window and immediately re-reads its result tree. |
| **Re-read results of this window** | Rebuilds the subcase / simulation / result-type / component tree of a window without reloading the file. |
| *Information pane* | One line per loaded window: file, subcases, simulations, result types, components. |

Repeat *Load into window* once per window; each window keeps its own file.

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
<model>    GetFileName, GetResultCtrlHandle
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
hwtk::combobox      (-state readonly -values -textvariable, configure -values)
hwtk::checkbutton   (-variable)
```

Plain Tk is used in exactly **one** place plus the modal warnings:

* the read-only **information pane** - `listbox` + `scrollbar` inside a
  `hwtk::labelframe`, because hwtk has no listbox wrapper;
* `tk_messageBox` for the blocking validation / error pop-ups.

The dialog buttons are added with `$dlg insert apply <key>` exactly like the
real HyperView script `review_tools.tcl` does.  If that method is unavailable in
a build, the wizard silently falls back to its **own button bar** inside the
recess (`Adapter::Log` records the reason), so the GUI stays usable.

---

## 7. "# VERIFY:" list - every item that could not be confirmed for 2022

All of them are marked in the code with a `# VERIFY:` comment (V1 - V9) and are
written so that a wrong guess degrades instead of failing:

| # | Item | What is done / how to adapt |
|---|------|-----------------------------|
| **V1** | `<page> SetLayout <token>` | The call itself is confirmed (real scripts call `pageHandle SetLayout $layout`), but the accepted token spelling is installation specific. `Logic::LayoutCandidates` tries candidates (`1x2`, `2x1`, `1 X 2`, `1 x 2`, `2`, `single`, `2H`, ...), keeps the first token whose `GetNumberOfWindows` matches and caches it in `State::layoutTokenByCount`. An already correct layout is never touched. |
| **V2** | `<contour> SetAverageMode <mode>` | Mode strings `None Simple Advanced Maximum Minimum` live in `Logic::averagingModes`. Non-fatal: a refused mode is reported as a warning for that window. Adjust the list if your installation spells them differently. |
| **V3** | `<contour> SetLayer <layer>` | `Logic::layerChoices` = `<default> Z1 Z2 Lower Upper Mid`. `<default>` makes the adapter skip the call completely, so a build without `SetLayer` still works; a refused layer is a warning, not an error. |
| **V4** | `<contour> GetLegendHandle` + `<legend> SetType dynamic` | Non-fatal. If the legend handle or the dynamic legend type is refused, the contour is still applied and a warning is printed. |
| **V5** | `<client> AddModel <file> <reader>` | Called with one argument (reader auto-detected from the file extension) when the *Reader* entry is empty, with two when it is filled in. Reader labels are installation specific, hence the optional entry (for example `Nastran OP2 Reader`). `hwtk::openfileentry -filetypes` may be refused by a build - the widget is then recreated without that option. |
| **V6** | `<result> GetDataComponentList <subcaseId> <dataType>` | Queried for every result type of every subcase while the result tree is built; the form is the one used by Altair's own `result_service.tcl`. If the call is refused, the result tree still lists subcases / simulations / result types. |
| **V7** | `hwtk::dialog` modality (`-modal`) | **Not used.** The dialog is created with only the options seen in real HyperView scripts, so it cannot fail on an unknown option. Add `-modal 1` yourself if your build accepts it. |
| **V8** | `hwtk::combobox configure -values <list>` | Used to re-populate the subcase / result type / component lists. hwtk comboboxes are ttk widgets, so `-values` is a list option and the list is passed **as it is** (wrapping it in `[list ...]` would glue all entries into one). |
| **V9** | `<<ComboboxSelected>>` on hwtk comboboxes | Bound so that changing the subcase refills the result type list and changing the result type refills the component list. If a build does not generate the virtual event, the **Reload lists** button in step 2 does exactly the same job. |

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
fan-out, validation), the pure `UI` helpers, and the adapter paths that fail
before an `hwi` call is reached.  Its last line is `ALL CHECKS PASSED`.

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

Every `hwi` call fails in this environment - which is exactly the point: the
test proves that all of those failures are reported to the user instead of
aborting the GUI.  Expected summary:

```
 UI smoke test : 88 passed, 0 failed
 stub notes    : 1 (unmodelled options, pop-up windows and the missing hwi - expected)
```

---

## 9. Troubleshooting

| Symptom | Cause / fix |
|---------|-------------|
| `ModelLoader needs the HyperWorks Tk library (hwtk). Missing: ...` | The wizard was sourced outside HyperView, or `hwt` / `hwtk` could not be loaded. Source it inside HyperView (`source hv_model_loader.tcl`). |
| `Apply layout` reports "no candidate worked" | V1: the layout token of your installation has another spelling. Add it to `Logic::LayoutCandidates` (or run the wizard once with a manually correct layout - the token is then cached in `State::layoutTokenByCount`). |
| `Cannot read the active page` | `hwi OpenStack` or one of the `Get*Handle` calls failed. `set ::ModelLoader::debug 1` then repeat the action - the console shows the exact failing call. |
| No subcases / result types listed | The file in that window holds no result data, or `GetDataTypeList` was refused. Press **Re-read results of this window**. |
| The component list stays empty | V6: `GetDataComponentList` was refused for that result type. The result type can still be applied; pick the component in HyperView's own contour panel. |
| Averaging / layer / legend warning in the information pane | V2 / V3 / V4 - the contour itself was applied; only the optional refinement was refused. |
| Step 2 lists do not follow the subcase | V9: the build does not emit `<<ComboboxSelected>>`. Press **Reload lists**. |
| Contour applied but nothing visible | The contour is switched on with `SetEnableState true` and `SetDisplayOptions contour true`; if the display options call is refused, enable the contour in HyperView manually. |

### Limitations

* **2022 only.** Nothing newer than 2022 is used; on 2023+ everything should
  still work but the automatic token/reader discovery may find different names.
* The wizard works on the **active page** only.  Multi-page handling
  (`AddPage`, `GetNumberOfPages`) is prepared in the adapter's command list but
  not driven by the GUI.
* No undo: applying a contour changes the window immediately.
* No persistent settings; the dialog starts from its defaults after each
  `::ModelLoader::Show`.

---

## 10. Bugs the smoke tests caught (kept for reference)

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

