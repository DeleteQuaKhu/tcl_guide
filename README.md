# PIS workflow - apply a Contact Pressure legend (minimal Tcl/Tk 8.5 workflow)

One GUI window, one button ("Load Legend"): the button sources the step script
configured in the .ini file and applies the Contact Pressure legend the user
picked to the active HyperView contour. More steps can be added without touching
the GUI (see "Adding a step").

```
pis_workflow/
  00_config/
    pis_workflow_config.ini    structure: folders, working files, format, workflow, script_02
    legend_default.tcl         loud-failing placeholder, replace with a real legend
  01_scripts/
    _tcl_pis_00_common.tcl                        shared library  (namespace ::pis::common)
    _tcl_pis_02_apply_contact_pressure_legend.tcl step 02         (namespace ::pis::step02)
    _tcl_pis_99_workflow_gui.tcl                  the GUI         (namespace ::pis099::gui)
  02_working/                  created automatically on the first run
    workflow.log  errors.log  run_status.csv  workflow_status.ini
  03_tests/                    optional harnesses, see "Re-running the tests"
```

## How to run

In a HyperView session with the Tcl/Tk command window:

```tcl
source C:/path/to/pis_workflow/01_scripts/_tcl_pis_99_workflow_gui.tcl
```

The window opens, reads `00_config/pis_workflow_config.ini`, creates `02_working`
and prefills the legend entry with `format legend_file`.

* **Browse Legend...** picks another .tcl file for **this session only**; the .ini
  file is never written.
* **Reload Config** re-reads the .ini (useful after editing it).
* **Load Legend** resolves the legend path against the workflow root, checks it,
  sources the configured step script and runs its procedure through
  `::pis::common::run_step`.

To load the procedures without opening the window:

```tcl
set ::pis099_no_autolaunch 1
source C:/path/to/pis_workflow/01_scripts/_tcl_pis_99_workflow_gui.tcl
::pis099::gui::launch            ;# opens it later
```

Sourcing the step script on its own (no GUI) asks for a legend file with
`tk_getOpenFile`; setting `::pis::run_from_gui 1` before sourcing suppresses that
dialog (that is what the GUI does).

## Adding a step

1. Create `01_scripts/_tcl_pis_03_<name>.tcl` with one entry procedure
   `::pis::step03::run {root cfg}`.
2. Add a `[script_03]` section to the .ini (`enabled`, `file`, `proc`, `title`).
3. Put `03` in `workflow run_order`.

The GUI reads the id/file/proc/title from the .ini and needs no code change. When
more than one id is listed in `run_order` the GUI will need a loop; today it runs
the first id only (one button, by design).

## Procedure arity and call sites

`n` is the declared argument count; `?x = d?` marks an optional argument.
Every call site was cross-checked against the declaration - all match.

### ::pis::common (shared library)

| procedure | declared arguments | called from (argument count) |
|---|---|---|
| `append_run_status` | 5 - `cfg stepID stepName status message` | `run_step` x2 (5) |
| `append_text_file` | 2 - `path text` | `log`, `error_log`, `append_run_status` (2) |
| `cfg_path` | 3 - `cfg section key` | GUI `reload_config` (3), GUI `step_settings` (3) |
| `ensure_directories` | 1 - `cfg` | GUI `reload_config` (1) |
| `ensure_parent_dir` | 2 - `path label` | `write_text_file`, `append_text_file` (2) |
| `error_log` | 2 - `cfg msg` | `run_step` (2) |
| `get` | 3 - `cfg section key ?default?` | `log` (4), GUI `step_settings` x4 (3) |
| `is_true` | 1 - `value` | GUI `step_settings` (1) |
| `load_config` | 1 - `root` | GUI `reload_config` (1) |
| `log` | 3 - `cfg level msg` | GUI `reload_config` x2, GUI `load_legend` x3, step02 `log_message` (3) |
| `quote_csv` | 1 - `text` | `append_run_status` (1) |
| `require_file` | 2 - `label file` | GUI `load_legend` x2 (2) |
| `resolve_path` | 2 - `root path` | GUI `load_legend` (2) |
| `run_step` | 4 - `cfg stepID stepName body` | GUI `load_legend` (4) |
| `timestamp` | 0 | GUI `ui_log` (0) |
| `write_status` | 5 - `cfg runStatus completedStep errorStep errorMessage` | `run_step` (5, three times: running / passed / failed) |
| `write_text_file` | 2 - `path text` | `write_status` (2) |

### ::pis::step02 (the legend step)

| procedure | declared arguments | called from (argument count) |
|---|---|---|
| `apply_file` | 1 - `legendFile` | `run` (1), `standalone` (1) |
| `apply_via_hwp` | 1 - `legendFile` | `apply_file` (1) |
| `client_handle_name` | 1 - `purpose` | `refresh_active_post` (1), `apply_via_hwp` (1) |
| `log_message` | 3 - `level msg ?cfg = ""?` | `apply_file` (2), `run` (3) |
| `refresh_active_post` | 0 | `apply_file` x2 (0) |
| `run` | 2 - `root cfg` | GUI body `[list $stepProc $rootDir $cfg]` (2) |
| `standalone` | 0 | step02 footer (0) |

### ::pis099::gui (the window)

| procedure | declared arguments | called from (argument count) |
|---|---|---|
| `browse_legend` | 0 | "Browse Legend" button |
| `browse_root` | 0 | "Browse..." button |
| `build_ui` | 0 | `launch` (0) |
| `launch` | 1 - `?rootDir = ""?` | GUI footer (0), tests / console (1) |
| `load_legend` | 0 | "Load Legend" button |
| `reload_config` | 0 | "Reload Config" button, `browse_root` (0), `launch` (0) |
| `show_error` | 1 - `msg` | every guard and failure path (1) |
| `show_info` | 1 - `msg` | `load_legend` success path (1) |
| `step_settings` | 1 - `cfg` | `load_legend` (1) |
| `ui_log` | 1 - `msg` | start / config / error / success paths (1) |

## Manual test plan in HyperView

Preparation: load a model with results, start a Contour plot, set the result to
Contact Pressure, and export the legend you want to `00_config/legend_contact_pressure.tcl`
(HyperView legend dialog > save/export as Tcl). Open the Tcl command window.

| # | Action | Expected result |
|---|---|---|
| 0 | `source .../01_scripts/_tcl_pis_99_workflow_gui.tcl` | Window "PIS Workflow - Apply Contact Pressure Legend" opens; log shows "Configuration loaded from: ..."; status label "Config loaded: pis_workflow_config.ini"; `02_working` created |
| 1 | Valid legend: set `legend_file` to your real legend (edit the .ini + Reload Config, or Browse Legend), press **Load Legend** | Info dialog "Step 02 - Legend imported with the HyperView command hwc result scalar legend import: ..."; the contour legend changes; log "Step 02 finished"; `workflow_status.ini` shows `run_status = passed`, `completed_step = 02`; `run_status.csv` gets a PASSED row |
| 2 | Run twice: press **Load Legend** again (and once more) | Same success output every time, no error dialog, no complaint about existing handles; `run_status.csv` gets one PASSED row per run; `llength [info commands *pis_step02*]` is `0` afterwards (no leaked handles) |
| 3 | Empty path: clear the "Legend file" entry, press **Load Legend** | Error dialog "The legend file path is empty. Use Browse Legend to select a legend Tcl file."; nothing is written to the status file; HyperView keeps running |
| 4 | Missing file: type `C:/nope/legend.tcl`, press **Load Legend** | Error dialog "Step 02 failed: Legend file not found: C:/nope/legend.tcl"; log shows ERROR; `workflow_status.ini` -> `run_status = failed`, `error_step = 02`; `errors.log` gets the line |
| 5 | Wrong file: pick a file that exists but is not a legend (the .ini, or `legend_default.tcl`), press **Load Legend** | Error dialog "Step 02 failed: Cannot apply legend file ... The command hwc result scalar legend import failed: ... The fallback procedure ::hwp::GetContourLegend does not exist in this HyperView session." (or the fallback error when that procedure exists). The wrong file is never silently accepted |
| 6 | Invalid working folder: type `C:/nope` in the working folder entry, press **Reload Config** | Error dialog "Cannot load the workflow configuration: ..."; the previously loaded configuration stays usable |
| 7 | Disabled step: set `enabled = false` in `[script_02]`, Reload Config, press **Load Legend** | Error dialog "Step 02 is disabled in the configuration (enabled = false)." |

Working files to inspect after each run:

* `02_working/workflow_status.ini` - `run_status`, `completed_step`, `error_step`,
  `error_message`, `updated`.
* `02_working/run_status.csv` - one header line, then one quoted row per step run.
* `02_working/workflow.log` / `errors.log` - timestamped INFO / WARNING / ERROR lines.

## Assumptions to confirm once in your HyperView build

Only the fallback block of `_tcl_pis_02_apply_contact_pressure_legend.tcl` may
need adapting:

1. The primary path is `hwc result scalar legend import <file>`; it must exist in
   your build, otherwise the fallback is used.
2. The fallback is only tried when `::hwp::GetContourLegend` exists. Its arity is
   read with `info args`, so both `::hwp::GetContourLegend` and
   `::hwp::GetContourLegend <clientHandle>` are supported; the same is done for
   `::post::LoadSettings` (zero or one argument). Confirm the real signatures in
   the HyperView console:

   ```tcl
   info args ::hwp::GetContourLegend
   info args ::post::LoadSettings
   ```

3. `hwi GetActiveClientHandle <name>` is expected to return a handle name that is
   a usable command; when it returns an empty string the requested name is used.

## Re-running the tests

The harnesses used for the checks above live in `03_tests/`. They need only
`tclsh86.exe` / `wish86.exe` (Tcl/Tk 8.5) - no HyperView, no extra packages.
`<root>` is the folder that contains `00_config` and `01_scripts`.

```
tclsh86 03_tests/test_common.tcl           <root>
tclsh86 03_tests/test_step02.tcl           <root>
tclsh86 03_tests/test_hv_stubs.tcl         <root> <scratch-dir>
tclsh86 03_tests/test_standalone_footer.tcl <root>
tclsh86 03_tests/list_arity.tcl            <root>     ;# prints the arity tables
wish86  03_tests/test_gui.tcl              <root> <result-file>
wish86  03_tests/test_gui_success.tcl      <root> <result-file>
```

The two `wish86` harnesses open the real window (with `tk_messageBox` replaced by
a logger), so run them on a desktop session; they write their findings to
`<result-file>` and close the window themselves. They stub `hwi` / `hwc`, so they
also cover the "legend applied successfully" path without HyperView.


`tclsh86` / `wish86` (Git for Windows, Tcl/Tk 8.5) with stubbed `hwi` / `hwc`:

* INI parser: sections and keys lowercased, `#` and `;` comments, BOM + CRLF
  files, stray-record and malformed-line errors, "missing required value" error,
  "too many default arguments" error.
* Paths and file IO: `resolve_path`, `cfg_path`, `ensure_directories` (idempotent),
  `write_text_file`, `append_text_file`, CSV quoting, `require_file`.
* `run_step`: success, `TCL_RETURN` from the body treated as success, failure
  rethrown with `-errorcode {pis STEP02 FAILED}`, status / log / CSV updated.
* Step 02 without HyperView: empty path, missing file, folder instead of file, no
  `hwi`/`hwc` at all, `run` with the placeholder legend, absolute override,
  missing `legend_file` key, usable with the common library absent.
* Step 02 with `hwi`/`hwc` stubs: primary import success, empty and invalid
  handle names, fallback through `::hwp::GetContourLegend`, legend file without
  `::post::LoadSettings`, both paths failing, unique handle names, the stack is
  always closed and every handle is always released.
* GUI under `wish86`: window build and widget layout, configuration load,
  empty-path guard, failing run (status `failed`, `error_step = 02`), successful
  run (status `passed`, `completed_step = 02`, CSV PASSED), the session-only
  legend override leaves the .ini untouched, `::pis::run_from_gui` is removed
  again and the busy flag is reset.
