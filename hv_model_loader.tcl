#=============================================================================
#  hv_model_loader.tcl
#  HyperView 2022 - step based "Model Loader + Contour" wizard
#
#  TARGET : Altair HyperWorks / HyperView 2022 ONLY.
#           Nothing introduced in 2023 or later is used.
#           Every command/option that could not be 100 % confirmed for
#           HyperView 2022 is flagged with a "# VERIFY:" comment.
#
#  GUI    : hwtk::* widgets only (HyperWorks Tk library).  Plain Tk widgets are
#           used ONLY where hwtk has no equivalent (read-only listbox +
#           scrollbar) - every such place carries a "# PLAIN TK:" comment
#           explaining why.  tk_messageBox is used for the modal warnings.
#
#  ENTRY  : ::ModelLoader::Show
#
#  FIXES  : F1 (window count)  the number the user typed is written back into the
#           Tcl variable AND the widget, and a refused layout keeps it in the
#           field.  Logic::InterpretWindowCount turns both forms of
#           '<page> GetNumberOfWindows' (the scalar '4' and the list '1 2 3 4')
#           into the real count - [llength] alone would answer 1 for the scalar.
#          F2 (reader free)    there is no 'Reader' entry any more:
#           '<client> AddModel <file>' detects the reader from the file, a result
#           file is attached with '<model> SetResult <file>' first and
#           '<model> AddResultFile <file>' second.  Logic::ReaderHint survives as
#           a status-line suggestion only.
#          F3 (layout mapping) 'Apply layout' did not map a window count to ONE
#           layout: 'Logic::LayoutCandidates' was sorted alphabetically, so the
#           same count could be applied as '1 X 2' or as '16' or as '2x1'
#           depending on the build - i.e. the arrangement was a lottery and a
#           count like 6 could end up 6x1 instead of 2x3.  The candidates now
#           follow a fixed, documented preference order (Logic::LayoutPreference:
#           squarest arrangement first, the token HyperView itself reported for
#           that count always at the very front), and the new 'Learn layouts'
#           button probes the page once - it caches the token every count really
#           accepts and puts the original layout back afterwards.
#          F4 (legend file)    step 2 can load a saved legend from a *.tcl file
#           into the target window (Adapter::LoadLegendFromFile): the file is
#           sourced (that is what a saved legend script contains - hwi calls),
#           the legend is switched on and the window is redrawn.
#          F5 (capture png)    new step 3 captures the graphic area of the target
#           window - or of every window of the page - as PNG files
#           (Adapter::CapturePng).  A view list file can be imported: every
#           entry of the file is applied as a view and gets its own PNG name.
#
#  LAYERS (single file, clearly separated):
#     SECTION 1  STATE / LOGIC     - pure Tcl, no hwi and no hwtk calls
#     SECTION 2  HYPERVIEW ADAPTER - the ONLY place that calls hwi
#     SECTION 3  UI                - hwtk only, calls logic + adapter
#
#  DEBUG  : set ::ModelLoader::debug 1  -> every hwi call and its catch result
#           is printed to the Tcl console.
#
#  --- hwi commands used ------------------------------------------------------
#     OpenStack, CloseStack, GetSessionHandle
#     <session>  GetProjectHandle, CaptureScreen (V12), CaptureActiveWindow (V12)
#     <project>  GetPageHandle, GetActivePage
#     <page>     GetWindowHandle, GetNumberOfWindows,
#                GetLayout, SetLayout, SetActiveWindow (V13)
#     <window>   GetClientHandle, GetViewControlHandle (V12)
#     <view>     SetOrientation, SetViewMatrix, Fit (V12)
#     <client>   Draw, GetActiveModel, GetModelHandle, GetModelList,
#                AddModel, SetDisplayOptions ('contour true' after a contour /
#                'legend true', V11), CaptureImage (V12)
#     <model>    GetFileName, GetResultCtrlHandle, SetResult, AddResultFile (V10)
#     <result>   GetSubcaseList, GetSubcaseLabel, GetCurrentSubcase,
#                SetCurrentSubcase, GetSimulationList, GetCurrentSimulation,
#                SetCurrentSimulation, GetDataTypeList,
#                GetDataComponentList, GetContourCtrlHandle
#     <contour>  SetDataType, SetDataComponent, SetAverageMode, SetEnableState,
#                SetLayer, GetLegendHandle
#     <legend>   SetType
#     every handle: ReleaseHandle
#     The vocabulary also mentions 'GetNumberOfPages / AddPage' (<project>),
#     'GetActiveWindow' (<page>), 'RemoveAllModels' (<client>) and
#     'GetNumberOfSimulations' (<result>) - none of them is called by the
#     wizard, it drives the active page and the windows the page really has.
#
#  --- hwtk / hwt commands used ----------------------------------------------
#     hwtk::dialog, hwtk::frame, hwtk::labelframe, hwtk::label, hwtk::button,
#     hwtk::entry, hwtk::openfileentry, hwtk::combobox, hwtk::checkbutton
#     <dialog> recess / insert apply / buttonconfigure / hide / post
#     plain Tk : listbox + scrollbar (read-only information pane),
#                tk_getOpenFile (the 'Browse...' buttons of the file fields,
#                with the same -filetypes list the fields offer),
#                tk_chooseDirectory (the PNG output folder of step 3) and
#                tk_messageBox for the modal warnings
#                (plus 'wm deiconify' / 'wm withdraw' as the fallback when the
#                 <dialog> methods 'post' / 'hide' are refused)
#
#  --- "# VERIFY:" list (see README.md for the detail) -----------------------
#     V1  <page> SetLayout <token>          token spelling is installation
#                                          specific -> auto discovery is used
#                                          (fix 3: ordered candidates, the
#                                          learned token first, plus the new
#                                          'Learn layouts' probe)
#     V2  <contour> SetAverageMode <mode>   exact mode strings
#     V3  <contour> SetLayer <layer>        command presence in 2022
#     V4  <contour> GetLegendHandle + <legend> SetType dynamic
#     V5  <client> AddModel <file>          NO reader argument is passed any
#                                          more - HyperView detects the reader
#                                          from the file itself (fix 2); the
#                                          ReaderHint of Logic is printed as a
#                                          note in the info pane only
#     V6  <result> GetDataComponentList <subcaseId> <dataType>
#     V7  hwtk::dialog modality (-modal)
#     V8  hwtk::combobox configure -values (dynamic re-population)
#     V9  hwtk combobox <<ComboboxSelected>> virtual event
#     V10 - VERIFY: attaching a RESULT file to a model that is already in the
#         window (<model> SetResult <resultFile> first - exactly as Altair's own
#         training.tcl does it -, <model> AddResultFile <resultFile> second,
#         <client> AddModel <resultFile> last); no reader label is used.
#         a refusal is a warning, never a failed load
#     V11 - VERIFY: 'load legend from file' (fix 4).  There is no hwi command
#         that reads a legend file, so the file is 'source'd (a saved legend is
#         a Tcl script of hwi calls) and only the switch-on + redraw afterwards
#         is done with <client> SetDisplayOptions legend true / <client> Draw.
#         A file that cannot be read or sourced is reported, never fatal
#     V12 - VERIFY: PNG capture (fix 5).  FOUR forms are tried in this order -
#         '<client> CaptureImage <file>' (one window, graphic area only),
#         '<session> CaptureActiveWindow png <file>' (the active window),
#         '<session> CaptureScreen png <file>' (the whole screen / client
#         area - this is the form used by hvTest.tcl) and
#         '<session> CaptureScreen png <file> <quality>' (training.tcl adds the
#         quality argument).  Whichever form worked first is cached in
#         State::captureMode and tried FIRST from then on.  View entries are
#         applied with <window> GetViewControlHandle -> <view> SetOrientation
#         (then <view> Fit, like display_service.tcl) or <view> SetViewMatrix
#         (one argument, no Fit) - both are non fatal, the PNG is written anyway
#     V13 - VERIFY: '<page> SetActiveWindow <idx>' before each single window
#         capture (also for every window of 'Capture all'), because the
#         active-window / screen forms need it.  Best effort: the answer is not
#         checked, so a build without the call still captures - it may then just
#         grab the window that was active already.  A capture that really fails
#         is reported as FAILED plus a warning per window / view
#=============================================================================

#=============================================================================
# SECTION 0 - BOOTSTRAP
#=============================================================================
# The namespace has to exist BEFORE the first 'proc ::ModelLoader::...' is
# evaluated, otherwise Tcl fails with "unknown namespace".
namespace eval ::ModelLoader {
    # Master debug switch: exactly the requested ::ModelLoader::debug
    variable debug 0
}
proc ::ModelLoader::Bootstrap {} {
    foreach pkg {hwt hwtk} {
        if {[catch {package require $pkg} msg]} {
            puts "\[ModelLoader\] WARNING: 'package require $pkg' failed: $msg"
        }
    }
    set missing {}
    # NOTE: the check must use the FULLY QUALIFIED name (::hwtk::...), a plain
    # 'hwtk::dialog' pattern is resolved against the current namespace (here
    # ::ModelLoader) and would report every command as missing.
    foreach cmd {dialog frame label button combobox entry checkbutton labelframe} {
        if {[llength [info commands ::hwtk::$cmd]] == 0} { lappend missing hwtk::$cmd }
    }
    if {[llength $missing] > 0} {
        error "ModelLoader needs the HyperWorks Tk library (hwtk). Missing: $missing"
    }
    # hwtk::openfileentry is OPTIONAL: when a build does not provide it (or
    # refuses -filetypes), UI::CreateFileChooser falls back to
    # 'hwtk::entry' + a Browse button that calls 'tk_getOpenFile -filetypes'.
    if {[llength [info commands ::hwtk::openfileentry]] == 0} {
        puts "\[ModelLoader\] NOTE: hwtk::openfileentry is not available -\
the file fields fall back to an entry + 'tk_getOpenFile' browser."
    }
    return 1
}
#=============================================================================
# SECTION 1 - STATE / LOGIC LAYER  (pure Tcl - NO hwi, NO hwtk)
#=============================================================================
namespace eval ::ModelLoader::State {
    # One dict keyed by "window index on the active page".
    # value = dict with the keys:
    #   page        <page index the model was loaded on>
    #   file        <full path of the primary loaded file (model, else result)>
    #   modelFile   <full path of the 'Input Model' file (may be empty)>
    #   resultFile  <full path of the 'Input Result' file (may be empty)>
    #   name        <file tail, for display>
    #   loaded      <0|1>
    #   subcases    <list of {subcaseId subcaseLabel}>
    #   simulations <dict subcaseId -> {simulationLabel ...}>
    #   datatypes   <dict subcaseId -> {dataType ...}>
    #   components  <dict subcaseId -> <dict dataType -> {component ...}>>
    variable windows {}
    # Discovered page layout tokens: dict windowCount -> layout token   (V1)
    variable layoutTokenByCount {}
    # Fix 4: path of the legend file that was loaded last, per window
    # (dict windowIdx -> path).  Display only.
    variable legendFileByWindow {}
    # Fix 5: the imported view list.  A list of dicts
    # {name <file name stem> orientation <front|iso|...> matrix <16 numbers|{}>}
    variable viewList {}
    variable viewListFile ""
    # Fix 5: last PNG folder and the capture form that worked
    # (V12: clientImage | activeWindow | screen)
    variable outputDir ""
    variable captureMode ""
    variable lastError ""
    variable statusText ""
}

proc ::ModelLoader::State::SetLastError {msg} {
    variable lastError
    set lastError $msg
    return $msg
}
proc ::ModelLoader::State::GetLastError {} {
    variable lastError
    return $lastError
}
proc ::ModelLoader::State::ClearLastError {} {
    variable lastError
    set lastError ""
    return ""
}
proc ::ModelLoader::State::SetStatus {text} {
    variable statusText
    set statusText $text
    return $text
}
proc ::ModelLoader::State::GetStatus {} {
    variable statusText
    return $statusText
}

#--------------------------------- per window --------------------------------
proc ::ModelLoader::State::WindowExists {idx} {
    variable windows
    return [dict exists $windows $idx]
}
proc ::ModelLoader::State::WindowInit {idx args} {
    variable windows
    set attrs [dict merge {
        page {} file {} name {} loaded 0
        modelFile {} resultFile {}
        subcases {} simulations {} datatypes {} components {}
    } [dict create {*}$args]]
    dict set windows $idx $attrs
    return $attrs
}
proc ::ModelLoader::State::WindowSet {idx key value} {
    variable windows
    if {![dict exists $windows $idx]} { ::ModelLoader::State::WindowInit $idx }
    dict set windows $idx $key $value
    return $value
}
proc ::ModelLoader::State::WindowGet {idx key {default {}}} {
    variable windows
    if {![dict exists $windows $idx $key]} { return $default }
    return [dict get $windows $idx $key]
}
proc ::ModelLoader::State::WindowDrop {idx} {
    variable windows
    dict unset windows $idx
    return 1
}
proc ::ModelLoader::State::WindowIndices {} {
    variable windows
    return [lsort -integer [dict keys $windows]]
}
proc ::ModelLoader::State::LoadedWindows {} {
    variable windows
    set out {}
    foreach idx [lsort -integer [dict keys $windows]] {
        if {[dict get $windows $idx loaded]} { lappend out $idx }
    }
    return $out
}
proc ::ModelLoader::State::AnyModelLoaded {} {
    return [expr {[llength [::ModelLoader::State::LoadedWindows]] > 0}]
}
# Called after the layout changed / the window count shrank:
# drop state of windows that no longer exist, keep the surviving ones.
proc ::ModelLoader::State::PruneTo {maxIdx} {
    variable windows
    set dropped {}
    foreach idx [lsort -integer [dict keys $windows]] {
        if {$idx > $maxIdx} {
            dict unset windows $idx
            lappend dropped $idx
        }
    }
    return $dropped
}
#--------------------------------- layout cache -------------------------------
# The token '<page> SetLayout <token>' that was accepted for a window count
# (fix 3).  An EMPTY token is not a token: it CLEARS the entry, so
# GetLayoutToken answers "" and LayoutTokenMap does not report a count the
# wizard knows nothing about.
proc ::ModelLoader::State::SetLayoutToken {count token} {
    variable layoutTokenByCount
    set token [string trim $token]
    if {$token eq ""} {
        dict unset layoutTokenByCount $count
        return ""
    }
    dict set layoutTokenByCount $count $token
    return $token
}
proc ::ModelLoader::State::GetLayoutToken {count} {
    variable layoutTokenByCount
    if {![dict exists $layoutTokenByCount $count]} { return "" }
    return [dict get $layoutTokenByCount $count]
}
proc ::ModelLoader::State::LayoutTokenMap {} {
    variable layoutTokenByCount
    return $layoutTokenByCount
}
#--------------------------------- legend file / capture (fix 4 + 5) ----------
proc ::ModelLoader::State::SetLegendFile {idx path} {
    variable legendFileByWindow
    dict set legendFileByWindow $idx $path
    return $path
}
proc ::ModelLoader::State::GetLegendFile {idx} {
    variable legendFileByWindow
    if {![dict exists $legendFileByWindow $idx]} { return "" }
    return [dict get $legendFileByWindow $idx]
}
# The imported view list: a list of entry dicts, see Logic::ParseViewList.
proc ::ModelLoader::State::SetViewList {entries {file {}}} {
    variable viewList
    variable viewListFile
    set viewList $entries
    if {$file ne ""} { set viewListFile $file }
    return $viewList
}
proc ::ModelLoader::State::GetViewList {} {
    variable viewList
    return $viewList
}
proc ::ModelLoader::State::SetViewListFile {file} {
    variable viewListFile
    set viewListFile $file
    return $file
}
proc ::ModelLoader::State::GetViewListFile {} {
    variable viewListFile
    return $viewListFile
}
proc ::ModelLoader::State::SetOutputDir {dir} {
    variable outputDir
    set outputDir $dir
    return $dir
}
proc ::ModelLoader::State::GetOutputDir {} {
    variable outputDir
    return $outputDir
}
# V12: remember which capture form worked so the next run starts with it.
proc ::ModelLoader::State::SetCaptureMode {mode} {
    variable captureMode
    set captureMode $mode
    return $mode
}
proc ::ModelLoader::State::GetCaptureMode {} {
    variable captureMode
    return $captureMode
}
# Wipes the whole State layer - the wizard starts from scratch ('reset all').
# The discovered layout tokens belong to the page that was open when they were
# learned, so they go too (fix 3): after a ResetAll the next 'Apply layout'
# probes again instead of replaying a token of a page that is long gone.  The
# same is true for the legend files of the windows, the view list, the output
# folder and the capture mode (fix 4 + fix 5).
proc ::ModelLoader::State::ResetAll {} {
    variable windows
    variable layoutTokenByCount
    variable lastError
    variable statusText
    variable legendFileByWindow
    variable viewList
    variable viewListFile
    variable outputDir
    variable captureMode
    set windows {}
    set layoutTokenByCount {}
    set lastError ""
    set statusText ""
    set legendFileByWindow {}
    set viewList {}
    set viewListFile ""
    set outputDir ""
    set captureMode ""
    return 1
}
namespace eval ::ModelLoader::Logic {
    # Pure user-interface choice data - never touches hwi.
    variable windowCountChoices {1 2 3 4 6 8 9 12 16}
    # V2 - VERIFY: averaging mode strings accepted by <contour> SetAverageMode.
    #      Adjust here if your installation uses other spellings; the strings are
    #      passed to SetAverageMode unchanged.
    variable averagingModes {None Simple Advanced Maximum Minimum}
    # V3 - VERIFY: shell / composite layer selection.  Keep <default> first: the
    #      adapter then skips the layer call completely.
    variable layerChoices {<default> Z1 Z2 Lower Upper Mid}
    variable noSelection {(none)}
    # V12 - VERIFY: orientation names accepted by <view> SetOrientation.  They are
    #      the view names the shipped scripts use (display_service.tcl).
    variable viewPresets {iso front back left right top bottom}
    # Fix 5: the two capture scopes of step 3.
    variable captureScopes {target all}
    # Fix 5: file filters of step 3 (view list) and step 2 (legend).
    variable viewListExtensions {.txt .lst .csv .tcl}
    variable legendExtensions {.tcl .hvl .txt}
    # PNG quality passed to CaptureScreen as the third argument (0..100).  It is
    # only used by the CaptureScreen fallback of V12.
    variable captureQuality 100
}

#--------------------------------- pure helpers ------------------------------
proc ::ModelLoader::Logic::Basename {path} {
    if {$path eq ""} { return "" }
    return [file tail $path]
}
proc ::ModelLoader::Logic::WindowCountChoices {} {
    variable windowCountChoices
    return $windowCountChoices
}
proc ::ModelLoader::Logic::AveragingModes {} {
    variable averagingModes
    return $averagingModes
}
proc ::ModelLoader::Logic::LayerChoices {} {
    variable layerChoices
    return $layerChoices
}
#--------------------------------- layout token candidates -------------------
# V1 - VERIFY: <page> SetLayout <token> itself is confirmed (real HyperView
#      scripts call 'pageHandle SetLayout $layout'), but the accepted token
#      spelling depends on the installation, so several candidates are tried
#      and the working one is cached in State::layoutTokenByCount.
#
# FIX 3 - "Windows on active page": the candidates were returned as
# 'lsort -unique' of everything that was generated, so the order in which the
# tokens were tried had nothing to do with the window count: for 6 windows the
# first try could be "1 X 6", for 12 windows the token "12" (a single window!)
# and so on.  The mapping count -> layout was therefore not stable, and a count
# with two possible arrangements (2 -> 1x2 or 2x1, 6 -> 2x3 or 3x2, ...) could
# end up in either of them, seemingly at random.
#
# The order is now generated explicitly, and it is documented:
#   1. the token this count was already accepted with (learned automatically
#      after a successful SetLayout, or by the 'Learn layouts' probe)
#   2. the PREFERRED arrangement of the count (Logic::LayoutPreference): the
#      squarest one, rows first - 2 -> 1x2, 6 -> 2x3, 8 -> 2x4, 12 -> 3x4
#   3. the transposed arrangement (2 -> 2x1, 6 -> 3x2, ...)
#   4. every remaining divisor arrangement, squarest first
#   5. the plain count and the legacy tokens (single, 2H, 2V, ...)
# so 'Apply layout' always applies THE same layout for a given count, and once
# HyperView reported a token for that count it is the very first candidate.
#
# Rows and columns of a count are the divisors of the count; rows <= cols is
# what '1x2' means here (1 row, 2 columns = side by side), so for the small
# counts the wizard prefers the wide arrangement - which is what the "windows on
# active page" list of step 1 offers: 2 means two windows next to each other.
proc ::ModelLoader::Logic::LayoutPreference {count} {
    if {$count < 1} { return {1 1} }
    set best {}
    set bestSpread -1
    for {set r 1} {$r <= $count} {incr r} {
        if {$count % $r} { continue }
        set c [expr {$count / $r}]
        # 'spread' = how far the arrangement is from a square (0 = square).
        set spread [expr {abs($r - $c)}]
        if {$best eq "" || $spread < $bestSpread} {
            set best [list $r $c]
            set bestSpread $spread
        }
    }
    return $best
}
# All arrangements of <count> that a 'RxC' style token can express, the
# preferred one first, each as {rows cols}.
proc ::ModelLoader::Logic::LayoutArrangements {count} {
    set preferred [::ModelLoader::Logic::LayoutPreference $count]
    set out {}
    foreach pair [list $preferred [lreverse $preferred]] {
        if {[lsearch -exact $out $pair] < 0} { lappend out $pair }
    }
    set rest {}
    for {set r 1} {$r <= $count} {incr r} {
        if {$count % $r} { continue }
        set c [expr {$count / $r}]
        set spread [expr {abs($r - $c)}]
        lappend rest [list $spread $r $c]
    }
    foreach item [lsort -index 0 -integer $rest] {
        set pair [lrange $item 1 2]
        if {[lsearch -exact $out $pair] < 0} { lappend out $pair }
    }
    return $out
}
proc ::ModelLoader::Logic::PreferredLayoutToken {count} {
    lassign [::ModelLoader::Logic::LayoutPreference $count] r c
    return "${r}x${c}"
}
proc ::ModelLoader::Logic::LayoutCandidates {count} {
    if {![string is integer -strict $count] || $count < 1} { return {} }
    set cand {}
    # 1. what HyperView itself accepted for this count (never overwritten by a
    #    guess - see Adapter::ApplyLayout / Adapter::LearnLayouts)
    set cached [::ModelLoader::State::GetLayoutToken $count]
    if {$cached ne ""} { lappend cand $cached }
    # 2.-4. the arrangements, preferred one first, in four spellings each
    foreach pair [::ModelLoader::Logic::LayoutArrangements $count] {
        lassign $pair r c
        foreach t [list "${r}x${c}" "${r} X ${c}" "${r} x ${c}" "${r} - ${c}"] {
            lappend cand $t
        }
    }
    # 5. the plain count and the legacy words
    lappend cand $count
    foreach t [list single 1x1 2H 2V 3H 3V 4H 4V] { lappend cand $t }
    # Remove duplicates but KEEP THE ORDER (this is the actual fix - the old
    # code ended with 'lsort -unique', which threw the preference away).
    set out {}
    foreach t $cand {
        if {[lsearch -exact $out $t] < 0} { lappend out $t }
    }
    return $out
}
#--------------------------------- page window count --------------------------
# BUG FIX 1: the return value of '<page> GetNumberOfWindows' is NOT the same in
# every build.  Altair's own scripts use it as a NUMBER
# ('for {set i 0} {$i < [$pageHandle GetNumberOfWindows]} {incr i}', see
# _tmp_hv/batchImportOdb.tcl), while some builds hand out the LIST of window
# indices ('1 2 3 4') instead.  Both spellings are accepted here:
#   "4"       -> 4          (the usual, numeric form)
#   "1 2 3 4" -> 4          (the list form)
#   "1"       -> 1
#   ""        -> 0
# Before this helper the value was passed through 'llength' - that turned any
# scalar '4' into 1, so the wizard believed the page had a single window after
# every layout change (that is why the window count jumped back to 1).
proc ::ModelLoader::Logic::InterpretWindowCount {raw} {
    set raw [string trim $raw]
    if {[string is integer -strict $raw] && $raw >= 0} { return $raw }
    return [llength $raw]
}
#--------------------------------- file type filters (GUI data) --------------
# Both lists below are ONE Tcl list in the standard Tk 'filetypes' format:
#   { {"Label" {.ext1 .ext2}} {"Label2" {.ext3}} {"All Files" {*}} }
# The same list is handed to 'hwtk::openfileentry -filetypes' AND to
# 'tk_getOpenFile -filetypes' (see UI::BrowseFile), so the two browsers of
# step 1 always offer exactly the same filters.
# The FIRST entry is the filter the browser starts with - therefore the format
# the field is meant for comes first: Abaqus *.inp for "Input Model",
# FEMFAT *.res for "Input Result".
# 'Input Model' browser: FE model / input decks.
proc ::ModelLoader::Logic::ModelFileTypes {} {
    return {
        {"Abaqus Input Files"  {.inp}}
        {"Nastran Input Files" {.bdf .dat .nas}}
        {"OptiStruct Input"    {.fem}}
        {"Hyper3D Model Files" {.h3d}}
        {"Abaqus ODB Model"    {.odb}}
        {"All Model Files"     {.inp .bdf .dat .nas .fem .h3d .odb .mvw .sim .mod}}
        {"All Files"           {*}}
    }
}
# 'Input Result' browser: result / output files (*.res = FEMFAT, *.op2 = Nastran,
# *.odb = Abaqus, *.rst = Ansys, *.d3plot = LS-DYNA, *.h3d = Altair).
proc ::ModelLoader::Logic::ResultFileTypes {} {
    return {
        {"FEMFAT Result Files" {.res}}
        {"Nastran OP2 Results" {.op2}}
        {"Abaqus ODB Results"  {.odb}}
        {"Ansys RST Results"   {.rst}}
        {"LS-DYNA Results"     {.d3plot}}
        {"Hyper3D Results"     {.h3d}}
        {"All Result Files"    {.res .op2 .odb .rst .d3plot .h3d .xdb .mvw}}
        {"All Files"           {*}}
    }
}
# Extensions the two fields accept.  They are used for a WARNING only, a file
# with an unexpected extension is still handed to HyperView.
proc ::ModelLoader::Logic::ModelExtensions {} {
    return {.inp .bdf .dat .nas .fem .h3d .odb .mvw .sim .mod}
}
proc ::ModelLoader::Logic::ResultExtensions {} {
    return {.res .op2 .odb .rst .d3plot .h3d .xdb .mvw}
}
# Reader label SUGGESTION for the info pane.  It is only printed as a hint:
# no reader label is ever handed to HyperView any more, AddModel detects the
# reader from the file itself (fix 2 / V5).
proc ::ModelLoader::Logic::ReaderHint {path} {
    switch -- [string tolower [file extension [string trim $path]]] {
        .inp    { return "Abaqus Input Reader" }
        .res    { return "FEMFAT Result Reader" }
        .op2    { return "Nastran OP2 Reader" }
        .odb    { return "Abaqus ODB Reader" }
        .rst    { return "Ansys Result Reader" }
        .xdb    { return "Ansys Result Reader" }
        .d3plot { return "LS-DYNA Reader" }
        .h3d    { return "Hyper3D Reader" }
        .fem    { return "OptiStruct Input Reader" }
        .bdf    { return "Nastran Input Reader" }
        .nas    { return "Nastran Input Reader" }
        .dat    { return "Nastran Input Reader" }
    }
    return ""
}
# Post-processing of a path that was chosen in a file browser or typed by the
# user: trims it, normalises it, checks that it really is a readable file and
# flags an extension that does not belong to <kind> (model | result).
# Returns dict: {ok <0|1> path <normalised path> kind <model|result>
#                message <reason when ok 0 / warning when ok 1>}
proc ::ModelLoader::Logic::CheckChosenFile {path kind} {
    set raw [string trim [string map [list \" ""] $path]]
    if {$raw eq ""} {
        return [dict create ok 0 path "" kind $kind message "no file was chosen"]
    }
    set norm $raw
    catch { set norm [file normalize $raw] }
    if {![file exists $norm]} {
        return [dict create ok 0 path $norm kind $kind \
            message "the file does not exist: $norm"]
    }
    if {[file isdirectory $norm]} {
        return [dict create ok 0 path $norm kind $kind \
            message "'$norm' is a directory, not a file"]
    }
    set ext [string tolower [file extension $norm]]
    if {$kind eq "model"} { set known [::ModelLoader::Logic::ModelExtensions] } \
        else               { set known [::ModelLoader::Logic::ResultExtensions] }
    set warn ""
    if {[lsearch -exact $known $ext] < 0} {
        set warn "'$ext' is unusual for a $kind file - it is passed to HyperView anyway"
    }
    return [dict create ok 1 path $norm kind $kind message $warn]
}
#--------------------------------- file filters of step 2 / step 3 ------------
# 'Legend file' browser of step 2 (fix 4): a saved legend is a Tcl script.
proc ::ModelLoader::Logic::LegendFileTypes {} {
    return {
        {"Legend Tcl Scripts" {.tcl}}
        {"HyperView Legend"   {.hvl}}
        {"All Files"          {*}}
    }
}
# 'View list' browser of step 3 (fix 5): a plain text list, one view per line.
proc ::ModelLoader::Logic::ViewListFileTypes {} {
    return {
        {"View List Files" {.txt .lst .csv}}
        {"Tcl Scripts"     {.tcl}}
        {"All Files"       {*}}
    }
}
proc ::ModelLoader::Logic::LegendExtensions {} {
    variable legendExtensions
    return $legendExtensions
}
proc ::ModelLoader::Logic::ViewListExtensions {} {
    variable viewListExtensions
    return $viewListExtensions
}
#--------------------------------- views / view list (fix 5) -----------------
proc ::ModelLoader::Logic::ViewPresets {} {
    variable viewPresets
    return $viewPresets
}
proc ::ModelLoader::Logic::CaptureScopes {} {
    variable captureScopes
    return $captureScopes
}
proc ::ModelLoader::Logic::CaptureQuality {} {
    variable captureQuality
    return $captureQuality
}
# Alias -> canonical orientation.  The canonical names are the ones
# display_service.tcl hands to the view control.
proc ::ModelLoader::Logic::ViewAliases {} {
    return {
        iso    {iso isometric iso_view}
        front  {front fr frontal}
        back   {back rear}
        left   {left}
        right  {right}
        top    {top}
        bottom {bottom base}
    }
}
# Maps one token of a view list onto a canonical orientation, or "" when the
# token is not a known orientation (then it is treated as a name only).
proc ::ModelLoader::Logic::ViewOrientation {token} {
    set t [string tolower [string trim $token]]
    if {$t eq ""} { return "" }
    foreach target [::ModelLoader::Logic::ViewPresets] {
        set aliases [dict get [::ModelLoader::Logic::ViewAliases] $target]
        if {[lsearch -exact $aliases $t] >= 0} { return $target }
    }
    return ""
}
#--------------------------------- view list file (fix 5) --------------------
# A view list is a small text file with ONE entry per line, e.g.
#
#     # my steady views
#     iso
#     front_left    front
#     custom_bottom bottom
#     tilted        0.62 -0.39 0.69 0.0  -0.35 -0.91 0.21 0.0  ...
#
# * blank lines and comments (#, //, ;) are skipped,
# * the FIRST token is the name; it is sanitised so that it can be used as a
#   PNG file name,
# * a remaining single token is read as an orientation (front, rear, iso, ...),
# * a remaining group of 16 numbers is read as a view MATRIX (exactly what
#   '<view> SetViewMatrix' expects),
# * a line with a name only is orientation AND name (so 'front' works alone),
# * duplicate names are made unique ('iso', 'iso-2') so no PNG is overwritten.
# Returns a list of dicts: {name <stem> orientation <front|iso|...|{}> matrix
#                           <16 numbers|{}> raw <original line>}
proc ::ModelLoader::Logic::ParseViewList {text} {
    set entries {}
    set used {}
    foreach rawLine [split [string map [list "\r" ""] $text] "\n"] {
        set line $rawLine
        foreach mark {# // ;} {
            set p [string first $mark $line]
            if {$p >= 0} { set line [string range $line 0 [expr {$p - 1}]] }
        }
        set toks [split [string map [list "," " " "\t" " "] $line] " "]
        set toks [lsearch -all -inline -not $toks ""]
        if {[llength $toks] == 0} { continue }
        set name [::ModelLoader::Logic::SanitizeName [lindex $toks 0]]
        set rest [lrange $toks 1 end]
        set orientation ""
        set matrix ""
        if {[llength $rest] == 16 && [::ModelLoader::Logic::AllNumbers $rest]} {
            set matrix $rest
        } elseif {[llength $rest] >= 1} {
            set orientation [::ModelLoader::Logic::ViewOrientation [lindex $rest 0]]
        } else {
            set orientation [::ModelLoader::Logic::ViewOrientation $name]
        }
        set name [::ModelLoader::Logic::UniqueName $used $name]
        lappend used $name
        lappend entries [dict create name $name orientation $orientation \
            matrix $matrix raw [string trim $rawLine]]
    }
    return $entries
}
proc ::ModelLoader::Logic::AllNumbers {values} {
    if {[llength $values] == 0} { return 0 }
    foreach v $values {
        if {![string is double -strict $v]} { return 0 }
    }
    return 1
}
# Makes a string usable as a file name stem: spaces -> _, everything that is
# not [A-Za-z0-9._-] -> _, and an empty result becomes 'view'.
proc ::ModelLoader::Logic::SanitizeName {name} {
    set n [string trim $name]
    set n [string map [list " " "_" "\\" "_" "/" "_" ":" "_"] $n]
    regsub -all {[^A-Za-z0-9._-]} $n "_" n
    set n [string trim $n "_.-"]
    if {$n eq ""} { set n "view" }
    return $n
}
# 'iso' twice -> 'iso', 'iso-2'
proc ::ModelLoader::Logic::UniqueName {used name} {
    if {[lsearch -exact $used $name] < 0} { return $name }
    set i 2
    while {[lsearch -exact $used "${name}-${i}"] >= 0} { incr i }
    return "${name}-${i}"
}
# Reads a view list file and parses it.  Returns
# {ok <0|1> entries <list of entry dicts> message <reason / warning>}
proc ::ModelLoader::Logic::ViewListFromFile {path} {
    set p [string trim [string map [list \" ""] $path]]
    if {$p eq ""} {
        return [dict create ok 0 entries {} message "no view list file was chosen"]
    }
    set norm $p
    catch { set norm [file normalize $p] }
    if {![file exists $norm]} {
        return [dict create ok 0 entries {} \
            message "the view list does not exist: $norm"]
    }
    if {[file isdirectory $norm]} {
        return [dict create ok 0 entries {} \
            message "'$norm' is a directory, not a file"]
    }
    if {[catch { set fh [open $norm r] ; set text [read $fh] ; close $fh } msg]} {
        return [dict create ok 0 entries {} \
            message "the view list could not be read: $msg"]
    }
    set entries [::ModelLoader::Logic::ParseViewList $text]
    if {[llength $entries] == 0} {
        return [dict create ok 0 entries {} \
            message "no view entry was found in $norm"]
    }
    set ext [string tolower [file extension $norm]]
    set warn ""
    if {[lsearch -exact [::ModelLoader::Logic::ViewListExtensions] $ext] < 0} {
        set warn "'$ext' is unusual for a view list - it is read as plain text anyway"
    }
    return [dict create ok 1 entries $entries message $warn]
}
#--------------------------------- PNG capture (fix 5) -----------------------
# PNG output folder of step 3: it may not exist yet (the adapter creates it),
# but it must not be an existing file.
proc ::ModelLoader::Logic::CheckOutputDir {dir} {
    set d [string trim [string map [list \" ""] $dir]]
    if {$d eq ""} {
        return [dict create ok 0 path "" message "no PNG output folder was chosen"]
    }
    set norm $d
    catch { set norm [file normalize $d] }
    if {[file exists $norm] && ![file isdirectory $norm]} {
        return [dict create ok 0 path $norm \
            message "'$norm' is a file, not a folder"]
    }
    return [dict create ok 1 path $norm message ""]
}
# File name of one capture: <dir>/w<window>_<view>.png - the window index is
# always part of the name, so a capture of 'all windows' can never overwrite a
# file of another window.
proc ::ModelLoader::Logic::CaptureFileName {dir window name {ext .png}} {
    return [file join $dir "w${window}_[::ModelLoader::Logic::SanitizeName $name]${ext}"]
}
# Builds the list of capture jobs of step 3.
#   <scope>        'target' (only <targetWindow>) or 'all' (<windowIndices>)
#   <viewEntries>  the imported view list (may be empty -> one job per window)
# Returns a list of dicts: {window <idx> name <stem> view <entry|{}> file <png>}
proc ::ModelLoader::Logic::CapturePlan {scope targetWindow viewEntries \
        windowIndices outDir} {
    if {$scope eq "all"} {
        set wins $windowIndices
    } else {
        set wins [list $targetWindow]
    }
    if {[llength $viewEntries] == 0} {
        set viewEntries [list [dict create name view orientation "" matrix "" raw ""]]
    }
    set jobs {}
    foreach w $wins {
        foreach entry $viewEntries {
            set name [dict get $entry name]
            lappend jobs [dict create \
                window $w \
                name   $name \
                view   $entry \
                file   [::ModelLoader::Logic::CaptureFileName $outDir $w $name]]
        }
    }
    return $jobs
}
# How one capture job is described in the information pane / status line.
proc ::ModelLoader::Logic::DescribeJob {job} {
    set entry [dict get $job view]
    set how ""
    if {[dict get $entry matrix] ne ""} {
        set how " (matrix)"
    } elseif {[dict get $entry orientation] ne ""} {
        set how " ([dict get $entry orientation])"
    }
    return "window [dict get $job window], view '[dict get $job name]'$how ->\
[::ModelLoader::Logic::Basename [dict get $job file]]"
}
#--------------------------------- layout probe order (fix 3) ----------------
# Order in which the 'Learn layouts' probe visits the window counts.  It only
# visits counts >= <current>: a probe has to change the page layout, and a page
# that is switched to FEWER windows loses the models of the closed windows, so
# the probe never shrinks the page.  Counts below the current one are learned
# when the layout is really applied (Adapter::SetWindowCount caches the token
# that worked) or from 'page GetLayout' after a manual change
# (Adapter::QueryPage).
proc ::ModelLoader::Logic::LayoutProbeOrder {current {choices {}}} {
    if {[llength $choices] == 0} {
        set choices [::ModelLoader::Logic::WindowCountChoices]
    }
    set out {}
    foreach c [lsort -integer -decreasing $choices] {
        if {$c >= $current} { set out [linsert $out 0 $c] }
    }
    return $out
}
#--------------------------------- step validation ---------------------------
proc ::ModelLoader::Logic::ValidateStep1 {} {
    if {![::ModelLoader::State::AnyModelLoaded]} {
        return -code error "Step 1: no model has been loaded into any window yet."
    }
    return 1
}
proc ::ModelLoader::Logic::ValidateStep2 {winIdx spec} {
    if {![::ModelLoader::State::WindowGet $winIdx loaded 0]} {
        return -code error "Step 2: window $winIdx has no model / results loaded."
    }
    if {[llength [::ModelLoader::State::WindowGet $winIdx subcases]] == 0} {
        return -code error "Step 2: window $winIdx has no subcases (no result data)."
    }
    foreach key {subcaseId dataType component} {
        if {[dict get $spec $key] eq ""} {
            return -code error "Step 2: '$key' has not been selected."
        }
    }
    return 1
}
# Step 3 (fix 5): the capture has to know what to capture and where to put it.
# The window is NOT checked here - 'Capture target' needs a loaded window and
# reports that itself, but 'all windows' captures every window of the page.
proc ::ModelLoader::Logic::ValidateStep3 {scope targetWindow outDir} {
    if {[lsearch -exact [::ModelLoader::Logic::CaptureScopes] $scope] < 0} {
        return -code error "Step 3: '$scope' is not a capture scope (target | all)."
    }
    if {$scope eq "target" && (![string is integer -strict $targetWindow] || \
            $targetWindow < 1)} {
        return -code error "Step 3: no target window is selected."
    }
    set dir [::ModelLoader::Logic::CheckOutputDir $outDir]
    if {![dict get $dir ok]} {
        return -code error "Step 3: [dict get $dir message]."
    }
    return 1
}
proc ::ModelLoader::Logic::SpecIsComplete {spec} {
    foreach key {subcaseId dataType component} {
        if {[dict get $spec $key] eq ""} { return 0 }
    }
    return 1
}
#--------------------------------- label <-> id resolution -------------------
proc ::ModelLoader::Logic::SubcaseLabel {winIdx subcaseId} {
    foreach pair [::ModelLoader::State::WindowGet $winIdx subcases] {
        if {[lindex $pair 0] eq $subcaseId} { return [lindex $pair 1] }
    }
    return ""
}
proc ::ModelLoader::Logic::SubcaseIdFromLabel {winIdx label} {
    foreach pair [::ModelLoader::State::WindowGet $winIdx subcases] {
        if {[lindex $pair 1] eq $label} { return [lindex $pair 0] }
    }
    return ""
}
# Build the dict the adapter understands, out of plain strings.
proc ::ModelLoader::Logic::MakeSpec {subcaseId simulationIndex dataType component averaging layer} {
    return [dict create \
        subcaseId       $subcaseId \
        simulationIndex $simulationIndex \
        dataType        $dataType \
        component       $component \
        averaging       $averaging \
        layer           $layer]
}
# "Apply to all windows": for every loaded window find the subcase whose LABEL
# matches the selected one and reuse the same contour settings.
# Returns { { {winIdx spec} ...} {unmatchedWinIdx ...} }
proc ::ModelLoader::Logic::FanOutSpec {referenceLabel spec} {
    set jobs {}
    set unmatched {}
    foreach idx [::ModelLoader::State::LoadedWindows] {
        set localId [::ModelLoader::Logic::SubcaseIdFromLabel $idx $referenceLabel]
        if {$localId eq ""} { lappend unmatched $idx ; continue }
        set localSpec [dict replace $spec subcaseId $localId]
        set sims [::ModelLoader::State::WindowGet $idx simulations]
        if {[dict exists $sims $localId]} {
            if {[dict get $spec simulationIndex] >= [llength [dict get $sims $localId]]} {
                set localSpec [dict replace $localSpec simulationIndex 0]
            }
        }
        lappend jobs [list $idx $localSpec]
    }
    return [list $jobs $unmatched]
}

#--------------------------------- state accessors used by the UI ------------
# The UI layer never reaches into the state dicts itself, it always goes
# through these small read-only helpers.
proc ::ModelLoader::Logic::Subcases {winIdx} {
    return [::ModelLoader::State::WindowGet $winIdx subcases]
}
proc ::ModelLoader::Logic::SubcaseLabels {winIdx} {
    set out {}
    foreach pair [::ModelLoader::State::WindowGet $winIdx subcases] {
        lappend out [lindex $pair 1]
    }
    return $out
}
proc ::ModelLoader::Logic::SimulationLabels {winIdx subcaseId} {
    set sims [::ModelLoader::State::WindowGet $winIdx simulations]
    if {![dict exists $sims $subcaseId]} { return {} }
    return [dict get $sims $subcaseId]
}
# GetSimulationList returns labels, a simulation is applied by index.
proc ::ModelLoader::Logic::SimulationIndex {winIdx subcaseId label} {
    return [lsearch -exact [::ModelLoader::Logic::SimulationLabels $winIdx $subcaseId] $label]
}
proc ::ModelLoader::Logic::DataTypes {winIdx subcaseId} {
    set dts [::ModelLoader::State::WindowGet $winIdx datatypes]
    if {![dict exists $dts $subcaseId]} { return {} }
    return [dict get $dts $subcaseId]
}
proc ::ModelLoader::Logic::Components {winIdx subcaseId dataType} {
    set comps [::ModelLoader::State::WindowGet $winIdx components]
    if {![dict exists $comps $subcaseId]} { return {} }
    set forType [dict get $comps $subcaseId]
    if {![dict exists $forType $dataType]} { return {} }
    return [dict get $forType $dataType]
}
proc ::ModelLoader::Logic::ModelName {winIdx} {
    set name [::ModelLoader::State::WindowGet $winIdx name]
    if {$name eq ""} { set name [::ModelLoader::State::WindowGet $winIdx file] }
    if {$name eq ""} { set name "<empty>" }
    return $name
}
# One line per window for the step 1 list.
proc ::ModelLoader::Logic::WindowSummary {winIdx} {
    set name [::ModelLoader::Logic::ModelName $winIdx]
    set n    [llength [::ModelLoader::Logic::Subcases $winIdx]]
    if {![::ModelLoader::State::WindowGet $winIdx loaded 0]} {
        return [format "Window %-2s : (empty)" $winIdx]
    }
    set extra ""
    set res [::ModelLoader::State::WindowGet $winIdx resultFile]
    if {$res ne "" && $res ne [::ModelLoader::State::WindowGet $winIdx modelFile]} {
        set extra "  + [file tail $res]"
    }
    return [format "Window %-2s : %s%s  \[%s subcase(s)\]" $winIdx $name $extra $n]
}
# Multi line dump of everything that was found for one window (step 1 + step 2).
proc ::ModelLoader::Logic::ResultSummary {winIdx} {
    set lines {}
    if {![::ModelLoader::State::WindowGet $winIdx loaded 0]} {
        lappend lines "Window $winIdx : no model loaded."
        return $lines
    }
    lappend lines "Window $winIdx : [::ModelLoader::Logic::ModelName $winIdx]"
    set subs [::ModelLoader::Logic::Subcases $winIdx]
    if {[llength $subs] == 0} {
        lappend lines "  (no subcases - no result data)"
        return $lines
    }
    foreach pair $subs {
        set sc  [lindex $pair 0]
        set lbl [lindex $pair 1]
        lappend lines "  subcase $sc : $lbl"
        set simLabels [::ModelLoader::Logic::SimulationLabels $winIdx $sc]
        if {[llength $simLabels] > 0} {
            lappend lines "      simulations : [join $simLabels {, }]"
        }
        foreach dt [::ModelLoader::Logic::DataTypes $winIdx $sc] {
            set comps [::ModelLoader::Logic::Components $winIdx $sc $dt]
            lappend lines [format "      %-28s : %s" $dt [join $comps {, }]]
        }
    }
    return $lines
}
#=============================================================================
# SECTION 2 - HYPERVIEW ADAPTER LAYER
#   This is the ONLY layer that talks to hwi.  Every single hwi call goes
#   through Adapter::HvRun, which wraps it in catch and (when
#   ::ModelLoader::debug is 1) prints the call and its result to the console.
#   Nothing here knows anything about the GUI.
#=============================================================================
namespace eval ::ModelLoader::Adapter {
    # The adapter keeps no state of its own - everything it finds is written
    # into ::ModelLoader::State.  The namespace only has to exist before the
    # first 'proc ::ModelLoader::Adapter::...' is evaluated.
}
proc ::ModelLoader::Adapter::Log {msg} {
    # Debug logger.  Silent unless ::ModelLoader::debug is set to 1.
    if {![info exists ::ModelLoader::debug] || !$::ModelLoader::debug} { return }
    catch { puts "\[ModelLoader\] $msg" }
    catch { flush stdout }
    return
}

# Runs one hwi command in the CALLER's frame, so handles created by commands
# such as 'hwi GetSessionHandle sess' stay visible to the caller.
# Returns 1 when the command succeeded, 0 when it failed.
# On failure the message is stored in State::lastError (never thrown).
proc ::ModelLoader::Adapter::HvRun {label script} {
    set code [catch {uplevel 1 $script} result]
    if {$code} {
        ::ModelLoader::Adapter::Log "FAIL  $label  =>  $result"
        ::ModelLoader::State::SetLastError "$label: $result"
        return 0
    }
    ::ModelLoader::Adapter::Log "ok    $label  =>  $result"
    return 1
}

# Release every handle that was really created.  hwi object handles are
# commands in the global namespace, therefore they are found by 'info commands'
# no matter which proc created them.
proc ::ModelLoader::Adapter::ReleaseHandles {names} {
    foreach name $names {
        if {[llength [info commands $name]] == 0} { continue }
        if {[catch { $name ReleaseHandle } msg]} {
            ::ModelLoader::Adapter::Log "release $name failed: $msg"
        } else {
            ::ModelLoader::Adapter::Log "release $name"
        }
    }
    return 1
}

#--------------------------------------------------------------- page info ---
# Returns a dict: {page <idx> windows <count> layout <token>} or {} on failure.
# Also feeds the layout token cache (V1) with whatever token is currently used.
proc ::ModelLoader::Adapter::QueryPage {} {
    ::ModelLoader::State::ClearLastError
    set out {}
    set pageIdx ""
    set winCount -1
    set layout ""

    if {![::ModelLoader::Adapter::HvRun "hwi OpenStack" {hwi OpenStack}]} { return {} }
    if {[::ModelLoader::Adapter::HvRun "GetSessionHandle" {hwi GetSessionHandle mlSess}]} {
        if {[::ModelLoader::Adapter::HvRun "GetProjectHandle" {mlSess GetProjectHandle mlProj}]} {
            if {[::ModelLoader::Adapter::HvRun "GetActivePage" {set pageIdx [mlProj GetActivePage]}]} {
                if {[::ModelLoader::Adapter::HvRun "GetPageHandle" \
                        {mlProj GetPageHandle mlPage $pageIdx}]} {
                    ::ModelLoader::Adapter::HvRun "GetNumberOfWindows" \
                        {set winCount [::ModelLoader::Logic::InterpretWindowCount \
                                          [mlPage GetNumberOfWindows]]}
                    ::ModelLoader::Adapter::HvRun "GetLayout" {set layout [mlPage GetLayout]}
                }
            }
        }
    }
    ::ModelLoader::Adapter::ReleaseHandles {mlPage mlProj mlSess}
    ::ModelLoader::Adapter::HvRun "hwi CloseStack" {hwi CloseStack}

    if {$pageIdx eq "" || $winCount < 0} { return {} }
    set out [dict create page $pageIdx windows $winCount layout $layout]

    # V1 - remember the token the GUI is currently using, this is exactly the
    #      token 'page SetLayout <token>' expects (see batchImportOdb.tcl).
    if {$layout ne "" && [::ModelLoader::State::GetLayoutToken $winCount] eq ""} {
        ::ModelLoader::State::SetLayoutToken $winCount $layout
        ::ModelLoader::Adapter::Log "layout cache: $winCount windows -> '$layout'"
    }
    return $out
}
#-------------------------------------------------------------- layout (V1) ---
# Makes the active page show exactly <wanted> windows.
# V1 - VERIFY: 'page SetLayout <token>' is confirmed to exist, but the accepted
#      token string is installation specific, therefore every candidate returned
#      by Logic::LayoutCandidates is tried until GetNumberOfWindows matches.
#      The token that worked is cached in State::layoutTokenByCount.
# Returns dict: {ok <0|1> windows <n> layout <token> message <text> unchanged <0|1>}
proc ::ModelLoader::Adapter::SetWindowCount {wanted} {
    ::ModelLoader::State::ClearLastError
    set info [::ModelLoader::Adapter::QueryPage]
    if {[llength $info] == 0} {
        return [dict create ok 0 windows 0 layout "" unchanged 0 \
            message "Cannot read the active page: [::ModelLoader::State::GetLastError]"]
    }
    set current  [dict get $info windows]
    set pageIdx  [dict get $info page]
    set curToken [dict get $info layout]
    if {$current == $wanted} {
        return [dict create ok 1 windows $current layout $curToken unchanged 1 message ""]
    }

    set candidates [::ModelLoader::Logic::LayoutCandidates $wanted]
    set tried {}
    set result {}
    set actual $current

    if {![::ModelLoader::Adapter::HvRun "hwi OpenStack" {hwi OpenStack}]} {
        return [dict create ok 0 windows $current layout $curToken unchanged 0 \
            message "hwi OpenStack failed."]
    }
    if {[::ModelLoader::Adapter::HvRun "GetSessionHandle" {hwi GetSessionHandle mlSess}]} {
        if {[::ModelLoader::Adapter::HvRun "GetProjectHandle" \
                {mlSess GetProjectHandle mlProj}]} {
            if {[::ModelLoader::Adapter::HvRun "GetPageHandle" \
                    {mlProj GetPageHandle mlPage $pageIdx}]} {
                foreach cand $candidates {
                    lappend tried $cand
                    if {![::ModelLoader::Adapter::HvRun "SetLayout '$cand'" \
                            [list mlPage SetLayout $cand]]} { continue }
                    if {![::ModelLoader::Adapter::HvRun "GetNumberOfWindows" \
                            {set actual [::ModelLoader::Logic::InterpretWindowCount \
                                             [mlPage GetNumberOfWindows]]}]} { continue }
                    if {$actual == $wanted} {
                        ::ModelLoader::State::SetLayoutToken $wanted $cand
                        set result [dict create ok 1 windows $actual layout $cand \
                            unchanged 0 message ""]
                        break
                    }
                }
            }
        }
    }
    ::ModelLoader::Adapter::ReleaseHandles {mlPage mlProj mlSess}
    ::ModelLoader::Adapter::HvRun "hwi CloseStack" {hwi CloseStack}

    if {[llength $result] > 0} { return $result }
    return [dict create ok 0 windows $current layout $curToken unchanged 0 \
        message "No layout token produced $wanted window(s); the page still has $current.\n\
                 Tried: $tried\n\
                 (Set the $wanted-window layout once by hand, then press 'Refresh page' -\
                  the script reads the layout token with 'page GetLayout' and reuses it,\n\
                  exactly like batchImportOdb.tcl does.)"]
}

#--------------------------------------------------- learn layouts (fix 3) ---
# Applies ONE layout token and returns the window count the page has afterwards
# (-1 when the token was refused / the page could not be read).  The token is
# cached for the count it produced, so 'Apply layout' prefers it from then on.
proc ::ModelLoader::Adapter::ApplyLayoutToken {token} {
    set count -1
    set info [::ModelLoader::Adapter::QueryPage]
    if {[llength $info] == 0} { return -1 }
    set pageIdx [dict get $info page]
    if {![::ModelLoader::Adapter::HvRun "hwi OpenStack" {hwi OpenStack}]} { return -1 }
    if {[::ModelLoader::Adapter::HvRun "GetSessionHandle" \
            {hwi GetSessionHandle mlSess}]} {
        if {[::ModelLoader::Adapter::HvRun "GetProjectHandle" \
                {mlSess GetProjectHandle mlProj}]} {
            if {[::ModelLoader::Adapter::HvRun "GetPageHandle" \
                    {mlProj GetPageHandle mlPage $pageIdx}]} {
                if {[::ModelLoader::Adapter::HvRun "SetLayout '$token'" \
                        [list mlPage SetLayout $token]]} {
                    ::ModelLoader::Adapter::HvRun "GetNumberOfWindows" \
                        {set count [::ModelLoader::Logic::InterpretWindowCount \
                                        [mlPage GetNumberOfWindows]]}
                    if {$count >= 1} {
                        ::ModelLoader::State::SetLayoutToken $count $token
                    }
                }
            }
        }
    }
    ::ModelLoader::Adapter::ReleaseHandles {mlPage mlProj mlSess}
    ::ModelLoader::Adapter::HvRun "hwi CloseStack" {hwi CloseStack}
    return $count
}
# FIX 3: learns the layout token of every window count the page can be switched
# to, so the count -> layout mapping of the wizard is HyperView's own mapping
# and not a guess any more.
#   * only counts >= the current one are probed (Logic::LayoutProbeOrder): a
#     probe has to change the layout and a page switched to FEWER windows loses
#     the models of the closed windows - so the probe never shrinks the page
#     (the README explains how the small counts are learned),
#   * every count that already has a token is skipped,
#   * afterwards the ORIGINAL layout is restored (the exact token 'page
#     GetLayout' reported, otherwise the original window count again).
# Returns dict: {ok <0|1> learned <dict count->token> skipped <list>
#                restored <window count after the restore> attempted <list>
#                message <text>}
proc ::ModelLoader::Adapter::LearnLayouts {} {
    ::ModelLoader::State::ClearLastError
    set info [::ModelLoader::Adapter::QueryPage]
    if {[llength $info] == 0} {
        return [dict create ok 0 learned {} skipped {} attempted {} restored -1 \
            message "Cannot read the active page: [::ModelLoader::State::GetLastError]"]
    }
    set current  [dict get $info windows]
    set curToken [dict get $info layout]
    set order    [::ModelLoader::Logic::LayoutProbeOrder $current]

    set learned   {}
    set skipped   {}
    set attempted {}

    foreach c $order {
        set known [::ModelLoader::State::GetLayoutToken $c]
        if {$known ne ""} { dict set learned $c $known ; continue }
        lappend attempted $c
        set res [::ModelLoader::Adapter::SetWindowCount $c]
        if {[dict get $res ok] && [dict get $res layout] ne ""} {
            dict set learned $c [dict get $res layout]
        } elseif {[dict get $res ok]} {
            # the page already had that many windows and 'GetLayout' answered
            # nothing - the count is fine, the token stays unknown
            lappend skipped $c
        } else {
            lappend skipped $c
        }
    }

    # --- put the original layout back ----------------------------------------
    set restored -1
    if {$curToken ne ""} {
        set restored [::ModelLoader::Adapter::ApplyLayoutToken $curToken]
    }
    if {$restored < 0} {
        set res [::ModelLoader::Adapter::SetWindowCount $current]
        if {[dict get $res ok]} { set restored [dict get $res windows] }
    }

    set msg ""
    if {$restored != $current} {
        set msg "The original layout of the page could not be restored\
($current window(s) were requested, the page shows $restored)."
    }
    if {[llength $skipped] > 0} {
        append msg "\nNo token found for: $skipped"
    }
    return [dict create ok 1 learned $learned skipped $skipped \
        attempted $attempted restored $restored message [string trim $msg]]
}
#--------------------------------------------------------------- load model ---
# Loads <path> into window <winIdx> of the ACTIVE page.
# FIX 2 (V5): NO reader label is passed any more.  'client AddModel <file>' lets
#        HyperView detect the reader from the file itself - that is the only
#        spelling this wizard uses, so the user never has to know a reader name.
#        Older callers passed '<reader>' as third argument; such an extra
#        argument is accepted and IGNORED, the API stays call compatible.
# Returns 1 on success, 0 on failure (State::lastError holds the reason).
proc ::ModelLoader::Adapter::LoadModel {winIdx path args} {
    ::ModelLoader::State::ClearLastError
    if {![file exists $path]} {
        ::ModelLoader::State::SetLastError "File not found: $path"
        return 0
    }
    set pageIdx ""
    set mlModelId ""
    set ok 0
    if {![::ModelLoader::Adapter::HvRun "hwi OpenStack" {hwi OpenStack}]} { return 0 }
    if {[::ModelLoader::Adapter::HvRun "GetSessionHandle" {hwi GetSessionHandle mlSess}]} {
        if {[::ModelLoader::Adapter::HvRun "GetProjectHandle" {mlSess GetProjectHandle mlProj}]} {
            if {[::ModelLoader::Adapter::HvRun "GetActivePage" \
                    {set pageIdx [mlProj GetActivePage]}]} {
                if {[::ModelLoader::Adapter::HvRun "GetPageHandle" \
                        {mlProj GetPageHandle mlPage $pageIdx}]} {
                    if {[::ModelLoader::Adapter::HvRun "GetWindowHandle" \
                            {mlPage GetWindowHandle mlWin $winIdx}]} {
                        if {[::ModelLoader::Adapter::HvRun "GetClientHandle" \
                                {mlWin GetClientHandle mlClient}]} {
                            # the reader is auto detected; AddModel answers with
                            # the id of the model it created (see training.tcl)
                            if {[::ModelLoader::Adapter::HvRun "AddModel" \
                                    {set mlModelId [mlClient AddModel $path]}]} {
                                set ok 1
                            }
                            ::ModelLoader::Adapter::HvRun "Draw" {mlClient Draw}
                        }
                    }
                }
            }
        }
    }
    ::ModelLoader::Adapter::ReleaseHandles {mlClient mlWin mlPage mlProj mlSess}
    ::ModelLoader::Adapter::HvRun "hwi CloseStack" {hwi CloseStack}

    if {$ok} {
        ::ModelLoader::State::WindowInit $winIdx \
            page $pageIdx file $path name [file tail $path] loaded 1 \
            modelFile $path modelId $mlModelId
    }
    return $ok
}

#----------------------------------------------------------- attach a result ---
# Attaches <resultPath> to the model that is currently in the window.
# Has to be called while the stack is OPEN, because <clientVar> is the live
# client handle of the caller's frame (hence the upvar).
# FIX 2 (V10): '<client> AddModel <resultFile>' does NOT attach a result file to
# a model that is already in the window - that is why results "did not load".
# The order below is the one Altair's own training.tcl uses:
#   1. <model> SetResult <resultFile>      (modelHandle SetResult <file>)
#   2. <model> AddResultFile <resultFile>  (older name of the same operation)
#   3. <client> AddModel <resultFile>      (last resort: separate result model)
# <modelId> is the id AddModel returned; when the caller does not know it, it is
# read with '<client> GetActiveModel' (again as in training.tcl).
# A refusal is NOT fatal: the model stays loaded and the reason is appended to
# <warningsVar>, so the caller prints a hint instead of failing the whole load.
# Returns 1 when the result file was handed to HyperView, 0 otherwise.
proc ::ModelLoader::Adapter::AttachResult {clientVar warningsVar resultPath {modelId ""}} {
    upvar 1 $clientVar mlClient
    upvar 1 $warningsVar warnings
    set label [::ModelLoader::Logic::Basename $resultPath]
    set why ""

    if {$modelId eq "" || $modelId eq "0"} {
        ::ModelLoader::Adapter::HvRun "GetActiveModel" \
            {set modelId [mlClient GetActiveModel]}
    }
    if {$modelId ne "" && $modelId ne "0"} {
        if {[::ModelLoader::Adapter::HvRun "GetModelHandle" \
                {mlClient GetModelHandle mlResModel $modelId}]} {
            if {[::ModelLoader::Adapter::HvRun "SetResult" \
                    [list mlResModel SetResult $resultPath]]} {
                ::ModelLoader::Adapter::HvRun "release mlResModel" {mlResModel ReleaseHandle}
                return 1
            }
            set why "model SetResult: [::ModelLoader::State::GetLastError]"
            if {[::ModelLoader::Adapter::HvRun "AddResultFile" \
                    [list mlResModel AddResultFile $resultPath]]} {
                ::ModelLoader::Adapter::HvRun "release mlResModel" {mlResModel ReleaseHandle}
                return 1
            }
            set why "$why / model AddResultFile: [::ModelLoader::State::GetLastError]"
            ::ModelLoader::Adapter::HvRun "release mlResModel" {mlResModel ReleaseHandle}
        } else {
            set why "GetModelHandle: [::ModelLoader::State::GetLastError]"
        }
    } else {
        set why "no model is loaded in the window"
    }

    # last resort: let AddModel build a second model out of the result file
    if {[::ModelLoader::Adapter::HvRun "AddModel <result>" \
            [list mlClient AddModel $resultPath]]} { return 1 }

    lappend warnings "the result file '$label' could not be attached to the loaded\
model (model SetResult / model AddResultFile / client AddModel were all refused).  \
The model is loaded - add the results with 'File > Load > Results'.  Reported: $why"
    return 0
}

#------------------------------------------------------------ load both inputs -
# Loads the two step-1 inputs into window <winIdx> of the ACTIVE page:
#   <modelPath>  'Input Model'  file - FE model / input deck (may be empty)
#   <resultPath> 'Input Result' file - result file          (may be empty)
# At least one of the two has to be given; a path that is not an existing file
# aborts the load before any hwi call (ok 0 + reason in the message).
# FIX 2: no reader argument is needed any more - HyperView picks the reader from
#        the file.  The trailing arguments of older callers (<modelReader>
#        <resultReader>) are accepted and IGNORED.
# What is loaded:
#   model only      -> AddModel <model>
#   result only     -> AddModel <result>  (HyperView builds the model from it)
#   model + result  -> AddModel <model>, then Adapter::AttachResult (V10)
# Returns dict: {ok <0|1> mode <text> files <list> models <n>
#                warnings {text ...} message <text>}
proc ::ModelLoader::Adapter::LoadInputs {winIdx modelPath resultPath args} {
    # Call compatibility (FIX 2): older callers used the signature
    #   LoadInputs <winIdx> <modelPath> <modelReader> <resultPath> <resultReader>
    # The reader arguments are gone, so such a call would hand the reader label
    # in the <resultPath> slot and the real result path in <args>.  When the
    # <resultPath> slot is empty or does not hold an existing file, but the
    # first extra argument does, the old layout is assumed and repaired here -
    # an extra argument never harms a caller that uses the new signature.
    if {[llength $args] >= 1} {
        set legacy [lindex $args 0]
        if {[file exists $legacy] && \
                ([string trim $resultPath] eq "" || ![file exists $resultPath])} {
            ::ModelLoader::Adapter::Log \
                "legacy LoadInputs call detected: result '$resultPath' -> '$legacy'"
            set resultPath $legacy
        }
    }
    ::ModelLoader::State::ClearLastError
    set warnings {}
    set files    {}
    set modelCnt 0
    set mode     ""
    set pageIdx  ""
    set mlModelId ""

    set ok 1
    if {$modelPath eq "" && $resultPath eq ""} {
        set ok 0
        ::ModelLoader::State::SetLastError \
            "Neither 'Input Model' nor 'Input Result' holds a file."
    }
    if {$ok} {
        foreach {p what} [list $modelPath "model" $resultPath "result"] {
            if {$p eq ""} { continue }
            if {![file exists $p]} {
                set ok 0
                ::ModelLoader::State::SetLastError "The $what file does not exist: $p"
                break
            }
        }
    }
    if {!$ok} {
        return [dict create ok 0 mode "" files {} models 0 warnings {} \
            message [::ModelLoader::State::GetLastError]]
    }

    if {$ok} { set ok [::ModelLoader::Adapter::HvRun "hwi OpenStack" {hwi OpenStack}] }
    if {$ok} { set ok [::ModelLoader::Adapter::HvRun "GetSessionHandle" \
                    {hwi GetSessionHandle mlSess}] }
    if {$ok} { set ok [::ModelLoader::Adapter::HvRun "GetProjectHandle" \
                    {mlSess GetProjectHandle mlProj}] }
    if {$ok} { set ok [::ModelLoader::Adapter::HvRun "GetActivePage" \
                    {set pageIdx [mlProj GetActivePage]}] }
    if {$ok} { set ok [::ModelLoader::Adapter::HvRun "GetPageHandle" \
                    {mlProj GetPageHandle mlPage $pageIdx}] }
    if {$ok} { set ok [::ModelLoader::Adapter::HvRun "GetWindowHandle" \
                    {mlPage GetWindowHandle mlWin $winIdx}] }
    if {$ok} { set ok [::ModelLoader::Adapter::HvRun "GetClientHandle" \
                    {mlWin GetClientHandle mlClient}] }

    # --- 1. the model file (if any) ------------------------------------------
    # V5 - VERIFY: 'client AddModel <file>' is called with ONE argument, the
    #      reader is detected by HyperView from the file itself (fix 2).  The
    #      two argument form 'client AddModel <file> <readerLabel>' also exists,
    #      but reader labels are installation specific, so this wizard never
    #      passes one - that is why the 'Reader (optional)' entry was removed.
    # FIX 2: 'AddModel <file>' without a reader - HyperView detects it and
    #        answers with the id of the new model (see training.tcl:36).
    if {$ok && $modelPath ne ""} {
        if {[::ModelLoader::Adapter::HvRun "AddModel <model>" \
                {set mlModelId [mlClient AddModel $modelPath]}]} {
            lappend files $modelPath
            set mode "model"
        } else {
            set ok 0
        }
    }
    # --- 2. the result file (if any) -----------------------------------------
    if {$ok && $resultPath ne ""} {
        if {$mode eq ""} {
            # no model file: the result file has to bring its own mesh
            if {[::ModelLoader::Adapter::HvRun "AddModel <result>" \
                    {set mlModelId [mlClient AddModel $resultPath]}]} {
                lappend files $resultPath
                set mode "result"
            } else {
                set ok 0
            }
        } else {
            # FIX 2: attach the results to the model that is already loaded
            if {[::ModelLoader::Adapter::AttachResult mlClient warnings \
                    $resultPath $mlModelId]} {
                lappend files $resultPath
                set mode "$mode+result"
            }
        }
    }

    if {$ok} { ::ModelLoader::Adapter::HvRun "Draw" {mlClient Draw} }
    if {$ok} { ::ModelLoader::Adapter::HvRun "GetModelList" \
                    {set modelCnt [llength [mlClient GetModelList]]} }

    ::ModelLoader::Adapter::ReleaseHandles \
        {mlResModel mlClient mlWin mlPage mlProj mlSess}
    ::ModelLoader::Adapter::HvRun "hwi CloseStack" {hwi CloseStack}

    if {!$ok} {
        return [dict create ok 0 mode $mode files $files models $modelCnt \
            warnings $warnings message [::ModelLoader::State::GetLastError]]
    }
    set primary [expr {$modelPath ne "" ? $modelPath : $resultPath}]
    ::ModelLoader::State::WindowInit $winIdx \
        page $pageIdx file $primary name [file tail $primary] loaded 1 \
        modelFile $modelPath resultFile $resultPath modelId $mlModelId
    return [dict create ok 1 mode $mode files $files models $modelCnt \
        warnings $warnings message ""]
}
#------------------------------------------------ read results of one window ---
# Opens the stack, walks session -> project -> page -> window -> client ->
# model -> result and stores everything it finds in the State layer.
# Every hwi call is individually catch-wrapped through HvRun and logged when
# ::ModelLoader::debug is set.
# Returns dict: {ok <0|1> models <n> files <list> subcases {{id label} ...}
#                simulations <dict> datatypes <dict> components <dict>
#                current <id> message <text>}
proc ::ModelLoader::Adapter::RefreshWindowResults {winIdx} {
    ::ModelLoader::State::ClearLastError
    set ok        1
    set pageIdx   ""
    set modelList {}
    set modelId   ""
    set files     {}
    set subcases  {}
    set sims      {}
    set dts       {}
    set comps     {}
    set current   ""
    set message   ""

    if {$ok} { set ok [::ModelLoader::Adapter::HvRun "hwi OpenStack" {hwi OpenStack}] }
    if {$ok} { set ok [::ModelLoader::Adapter::HvRun "GetSessionHandle" \
                    {hwi GetSessionHandle mlSess}] }
    if {$ok} { set ok [::ModelLoader::Adapter::HvRun "GetProjectHandle" \
                    {mlSess GetProjectHandle mlProj}] }
    if {$ok} { set ok [::ModelLoader::Adapter::HvRun "GetActivePage" \
                    {set pageIdx [mlProj GetActivePage]}] }
    if {$ok} { set ok [::ModelLoader::Adapter::HvRun "GetPageHandle" \
                    {mlProj GetPageHandle mlPage $pageIdx}] }
    if {$ok} { set ok [::ModelLoader::Adapter::HvRun "GetWindowHandle" \
                    {mlPage GetWindowHandle mlWin $winIdx}] }
    if {$ok} { set ok [::ModelLoader::Adapter::HvRun "GetClientHandle" \
                    {mlWin GetClientHandle mlClient}] }

    # --- which models / files are in this window? ----------------------------
    if {$ok} {
        set ok [::ModelLoader::Adapter::HvRun "GetModelList" \
                    {set modelList [mlClient GetModelList]}]
    }
    foreach mid $modelList {
        ::ModelLoader::Adapter::HvRun "GetModelHandle $mid" \
            {mlClient GetModelHandle mlTmpModel $mid}
        if {[llength [info commands mlTmpModel]]} {
            ::ModelLoader::Adapter::HvRun "GetFileName $mid" \
                {lappend files [mlTmpModel GetFileName]}
            ::ModelLoader::Adapter::HvRun "release mlTmpModel" {mlTmpModel ReleaseHandle}
        }
    }
    if {$ok} {
        set ok [::ModelLoader::Adapter::HvRun "GetActiveModel" \
                    {set modelId [mlClient GetActiveModel]}]
    }
    if {$ok && ($modelId eq "" || $modelId eq "0")} {
        set ok 0
        set message "No model is loaded in window $winIdx."
    }

    # --- results are optional: a window may hold a model without result data --
    set resultOk 0
    if {$ok} {
        set resultOk [::ModelLoader::Adapter::HvRun "GetModelHandle" \
                        {mlClient GetModelHandle mlModel $modelId}]
    }
    if {$resultOk} {
        set resultOk [::ModelLoader::Adapter::HvRun "GetResultCtrlHandle" \
                        {mlModel GetResultCtrlHandle mlResult}]
    }
    if {$resultOk} {
        # current subcase / simulation are informational only
        ::ModelLoader::Adapter::HvRun "GetCurrentSubcase" \
            {set current [mlResult GetCurrentSubcase]}
        set resultOk [::ModelLoader::Adapter::HvRun "GetSubcaseList" \
                        {set subcaseIds [mlResult GetSubcaseList]}]
    }
    if {$resultOk} {
        foreach sc $subcaseIds {
            set label ""
            ::ModelLoader::Adapter::HvRun "GetSubcaseLabel $sc" \
                {set label [mlResult GetSubcaseLabel $sc]}
            lappend subcases [list $sc $label]

            # GetSimulationList returns LABELS; a simulation is applied by
            # INDEX (SetCurrentSimulation <index>), see Logic::SimulationIndex.
            set simLabels {}
            ::ModelLoader::Adapter::HvRun "GetSimulationList $sc" \
                {set simLabels [mlResult GetSimulationList $sc]}
            if {[llength $simLabels] > 0} { dict set sims $sc $simLabels }

            set dtList {}
            ::ModelLoader::Adapter::HvRun "GetDataTypeList $sc" \
                {set dtList [mlResult GetDataTypeList $sc]}
            if {[llength $dtList] > 0} { dict set dts $sc $dtList }

            # V6 - VERIFY: 'result GetDataComponentList <subcaseId> <dataType>'
            #      is the form used by Altair's own result_service.tcl.
            foreach dt $dtList {
                set compList {}
                ::ModelLoader::Adapter::HvRun "GetDataComponentList $sc $dt" \
                    {set compList [mlResult GetDataComponentList $sc $dt]}
                dict set comps $sc $dt $compList
            }
        }
        if {[llength $subcaseIds] == 0} {
            set message "The model in window $winIdx carries no result data."
        }
    } elseif {$ok && $message eq ""} {
        set message "Window $winIdx holds a model without result data."
    }

    ::ModelLoader::Adapter::ReleaseHandles \
        {mlResult mlModel mlTmpModel mlClient mlWin mlPage mlProj mlSess}
    ::ModelLoader::Adapter::HvRun "hwi CloseStack" {hwi CloseStack}

    if {!$ok} {
        return [dict create ok 0 models [llength $modelList] files $files \
            subcases {} simulations {} datatypes {} components {} current "" \
            message [::ModelLoader::State::GetLastError]]
    }

    # --- store the result tree in the State layer ----------------------------
    ::ModelLoader::State::WindowSet $winIdx subcases    $subcases
    ::ModelLoader::State::WindowSet $winIdx simulations $sims
    ::ModelLoader::State::WindowSet $winIdx datatypes   $dts
    ::ModelLoader::State::WindowSet $winIdx components  $comps
    ::ModelLoader::State::WindowSet $winIdx loaded      1
    if {[llength $files] > 0} {
        ::ModelLoader::State::WindowSet $winIdx file [lindex $files 0]
        ::ModelLoader::State::WindowSet $winIdx name [file tail [lindex $files 0]]
    }
    return [dict create ok 1 models [llength $modelList] files $files \
        subcases $subcases simulations $sims datatypes $dts components $comps \
        current $current message $message]
}

# Load <path> into window <winIdx> and immediately re-read its result tree.
# The reader is auto detected (fix 2); a trailing reader argument of older
# callers is accepted and ignored.
# Returns the dict of RefreshWindowResults (ok 0 when the load itself failed).
proc ::ModelLoader::Adapter::LoadAndRefresh {winIdx path args} {
    if {![::ModelLoader::Adapter::LoadModel $winIdx $path]} {
        return [dict create ok 0 models 0 files {} subcases {} simulations {} \
            datatypes {} components {} current "" \
            message [::ModelLoader::State::GetLastError]]
    }
    return [::ModelLoader::Adapter::RefreshWindowResults $winIdx]
}

# Load BOTH step-1 inputs into <winIdx> and immediately re-read the window, so
# that the result tree of the info pane is up to date.
# The readers are auto detected (fix 2); the trailing reader arguments of older
# callers are accepted and ignored.
# Returns the dict of RefreshWindowResults, extended by the LoadInputs keys
# "mode" and "warnings" (non fatal problems, e.g. a refused result attach).
proc ::ModelLoader::Adapter::LoadAllAndRefresh {winIdx modelPath resultPath args} {
    set res [::ModelLoader::Adapter::LoadInputs $winIdx $modelPath $resultPath {*}$args]
    if {![dict get $res ok]} {
        return [dict create ok 0 models 0 files {} subcases {} simulations {} \
            datatypes {} components {} current "" mode [dict get $res mode] \
            warnings [dict get $res warnings] message [dict get $res message]]
    }
    set tree [::ModelLoader::Adapter::RefreshWindowResults $winIdx]
    dict set tree mode     [dict get $res mode]
    dict set tree warnings [dict get $res warnings]
    return $tree
}
#------------------------------------------------------------- contour plot ---
# Applies one contour specification to one window.
# <spec> is the dict built by Logic::MakeSpec:
#   {subcaseId simulationIndex dataType component averaging layer}
# Core steps (subcase, simulation, data type, component, contour on, draw) must
# succeed for the result to be ok 1.  Averaging, layer and legend are treated as
# optional refinements: when they fail the reason is returned in "warnings"
# instead of failing the whole operation (they are the V2/V3/V4 items).
proc ::ModelLoader::Adapter::ApplyContour {winIdx spec} {
    ::ModelLoader::State::ClearLastError
    set subcaseId [dict get $spec subcaseId]
    set simIndex  [dict get $spec simulationIndex]
    set dataType  [dict get $spec dataType]
    set component [dict get $spec component]
    set averaging [dict get $spec averaging]
    set layer     [dict get $spec layer]

    set warnings {}
    set ok     1
    set pageIdx ""
    set applied 0

    if {$ok} { set ok [::ModelLoader::Adapter::HvRun "hwi OpenStack" {hwi OpenStack}] }
    if {$ok} { set ok [::ModelLoader::Adapter::HvRun "GetSessionHandle" \
                    {hwi GetSessionHandle mlSess}] }
    if {$ok} { set ok [::ModelLoader::Adapter::HvRun "GetProjectHandle" \
                    {mlSess GetProjectHandle mlProj}] }
    if {$ok} { set ok [::ModelLoader::Adapter::HvRun "GetActivePage" \
                    {set pageIdx [mlProj GetActivePage]}] }
    if {$ok} { set ok [::ModelLoader::Adapter::HvRun "GetPageHandle" \
                    {mlProj GetPageHandle mlPage $pageIdx}] }
    if {$ok} { set ok [::ModelLoader::Adapter::HvRun "GetWindowHandle" \
                    {mlPage GetWindowHandle mlWin $winIdx}] }
    if {$ok} { set ok [::ModelLoader::Adapter::HvRun "GetClientHandle" \
                    {mlWin GetClientHandle mlClient}] }
    if {$ok} { set ok [::ModelLoader::Adapter::HvRun "GetActiveModel" \
                    {set modelId [mlClient GetActiveModel]}] }
    if {$ok} { set ok [::ModelLoader::Adapter::HvRun "GetModelHandle" \
                    {mlClient GetModelHandle mlModel $modelId}] }
    if {$ok} { set ok [::ModelLoader::Adapter::HvRun "GetResultCtrlHandle" \
                    {mlModel GetResultCtrlHandle mlResult}] }

    # --- core: subcase / simulation / contour handle -------------------------
    if {$ok} { set ok [::ModelLoader::Adapter::HvRun "SetCurrentSubcase $subcaseId" \
                    {mlResult SetCurrentSubcase $subcaseId}] }
    if {$ok && $simIndex >= 0} {
        if {![::ModelLoader::Adapter::HvRun "SetCurrentSimulation $simIndex" \
                {mlResult SetCurrentSimulation $simIndex}]} {
            set ok 0
        }
    }
    if {$ok} { set ok [::ModelLoader::Adapter::HvRun "GetContourCtrlHandle" \
                    {mlResult GetContourCtrlHandle mlContour}] }
    if {$ok} { set ok [::ModelLoader::Adapter::HvRun "SetDataType $dataType" \
                    {mlContour SetDataType $dataType}] }
    if {$ok} { set ok [::ModelLoader::Adapter::HvRun "SetDataComponent $component" \
                    {mlContour SetDataComponent $component}] }

    # --- optional refinements (never fatal) ---------------------------------
    if {$ok && $averaging ne "" && $averaging ne "<default>"} {
        # V2 - VERIFY: the accepted averaging mode strings
        if {![::ModelLoader::Adapter::HvRun "SetAverageMode $averaging" \
                {mlContour SetAverageMode $averaging}]} {
            lappend warnings "SetAverageMode '$averaging' was refused"
        }
    }
    if {$ok && $layer ne "" && $layer ne "<default>"} {
        # V3 - VERIFY: <contour> SetLayer may not exist in every 2022 build
        if {![::ModelLoader::Adapter::HvRun "SetLayer $layer" \
                {mlContour SetLayer $layer}]} {
            lappend warnings "SetLayer '$layer' was refused"
        }
    }
    if {$ok && $dataType ne ""} {
        # V4 - VERIFY: legend handle + dynamic legend
        if {[::ModelLoader::Adapter::HvRun "GetLegendHandle" \
                {mlContour GetLegendHandle mlLegend}]} {
            if {![::ModelLoader::Adapter::HvRun "legend SetType dynamic" \
                    {mlLegend SetType dynamic}]} {
                lappend warnings "legend SetType dynamic was refused"
            }
        } else {
            lappend warnings "no legend handle available"
        }
    }

    # --- switch the contour on and redraw -----------------------------------
    if {$ok} {
        if {[::ModelLoader::Adapter::HvRun "SetEnableState true" \
                {mlContour SetEnableState true}]} {
            ::ModelLoader::Adapter::HvRun "SetDisplayOptions contour true" \
                {mlClient SetDisplayOptions contour true}
            ::ModelLoader::Adapter::HvRun "SetDisplayOptions legend true" \
                {mlClient SetDisplayOptions legend true}
            ::ModelLoader::Adapter::HvRun "Draw" {mlClient Draw}
            set applied 1
        } else {
            set ok 0
        }
    }

    ::ModelLoader::Adapter::ReleaseHandles \
        {mlLegend mlContour mlResult mlModel mlClient mlWin mlPage mlProj mlSess}
    ::ModelLoader::Adapter::HvRun "hwi CloseStack" {hwi CloseStack}

    if {!$ok} {
        return [dict create ok 0 applied 0 warnings $warnings \
            message [::ModelLoader::State::GetLastError]]
    }
    return [dict create ok 1 applied $applied warnings $warnings message ""]
}
#------------------------------------------------------- legend from file ----
# V11 - VERIFY: loads a legend that was saved to a *.tcl file (fix 4).
# There is no hwi command that reads a legend file, and a saved legend IS a Tcl
# script of hwi calls, therefore the file is 'source'd:
#   1. the file is checked (exists, is a file, not empty),
#   2. an hwi stack is opened first, so a legend script that does NOT open its
#      own stack works as well; a script that opens / closes its own stack is
#      fine too, because every hwi failure of this proc is caught,
#   3. the file is sourced and its Tcl result + the error message are captured,
#   4. afterwards a fresh stack is opened to switch the legend of the window on
#      and to redraw it ('<client> SetDisplayOptions legend true' + Draw), so the
#      loaded legend is actually visible.
# Returns dict: {ok <0|1> winIdx <n> file <path> warnings <list> message <text>}
proc ::ModelLoader::Adapter::LoadLegendFromFile {winIdx path} {
    ::ModelLoader::State::ClearLastError
    set p [string trim [string map [list \" ""] $path]]
    if {$p eq ""} {
        return [dict create ok 0 winIdx $winIdx file "" warnings {} \
            message "No legend file was chosen."]
    }
    set norm $p
    catch { set norm [file normalize $p] }
    if {![file exists $norm]} {
        return [dict create ok 0 winIdx $winIdx file $norm warnings {} \
            message "Legend file not found: $norm"]
    }
    if {[file isdirectory $norm]} {
        return [dict create ok 0 winIdx $winIdx file $norm warnings {} \
            message "'$norm' is a directory, not a legend file."]
    }
    if {[catch { set fh [open $norm r] ; set text [read $fh] ; close $fh } msg]} {
        return [dict create ok 0 winIdx $winIdx file $norm warnings {} \
            message "The legend file could not be read: $msg"]
    }
    if {[string trim $text] eq ""} {
        return [dict create ok 0 winIdx $winIdx file $norm warnings {} \
            message "The legend file $norm is empty."]
    }
    set warnings {}
    set ext [string tolower [file extension $norm]]
    if {[lsearch -exact [::ModelLoader::Logic::LegendExtensions] $ext] < 0} {
        lappend warnings "'$ext' is unusual for a legend file - it is sourced anyway"
    }

    # 2. an ambient stack, so a 'bare' legend script works as well
    ::ModelLoader::Adapter::HvRun "hwi OpenStack (legend)" {hwi OpenStack}
    # 3. source the file - this is the actual 'load legend from file' step
    set code [catch { uplevel #0 [list source $norm] } ret]
    ::ModelLoader::Adapter::HvRun "hwi CloseStack (legend)" {hwi CloseStack}
    if {$code} {
        return [dict create ok 0 winIdx $winIdx file $norm warnings $warnings \
            message "The legend file could not be applied: $ret"]
    }
    ::ModelLoader::Adapter::Log "legend file '$norm' sourced -> $ret"

    # 4. switch the legend on and redraw the window (non fatal)
    set drawn 0
    set pageIdx ""
    if {[::ModelLoader::Adapter::HvRun "hwi OpenStack" {hwi OpenStack}]} {
        if {[::ModelLoader::Adapter::HvRun "GetSessionHandle" \
                {hwi GetSessionHandle mlSess}]} {
            if {[::ModelLoader::Adapter::HvRun "GetProjectHandle" \
                    {mlSess GetProjectHandle mlProj}]} {
                if {[::ModelLoader::Adapter::HvRun "GetActivePage" \
                        {set pageIdx [mlProj GetActivePage]}]} {
                    if {[::ModelLoader::Adapter::HvRun "GetPageHandle" \
                            {mlProj GetPageHandle mlPage $pageIdx}]} {
                        if {[::ModelLoader::Adapter::HvRun "GetWindowHandle" \
                                {mlPage GetWindowHandle mlWin $winIdx}]} {
                            if {[::ModelLoader::Adapter::HvRun "GetClientHandle" \
                                    {mlWin GetClientHandle mlClient}]} {
                                if {![::ModelLoader::Adapter::HvRun \
                                        "SetDisplayOptions legend true" \
                                        {mlClient SetDisplayOptions legend true}]} {
                                    lappend warnings \
                                        "SetDisplayOptions legend true was refused -\
the legend may stay hidden"
                                }
                                ::ModelLoader::Adapter::HvRun "Draw" {mlClient Draw}
                                set drawn 1
                            }
                        }
                    }
                }
            }
        }
    }
    ::ModelLoader::Adapter::ReleaseHandles {mlClient mlWin mlPage mlProj mlSess}
    ::ModelLoader::Adapter::HvRun "hwi CloseStack" {hwi CloseStack}
    if {!$drawn} {
        lappend warnings "the window could not be redrawn\
([::ModelLoader::State::GetLastError])"
    }
    set msg "Legend loaded from [::ModelLoader::Logic::Basename $norm]"
    if {[llength $warnings] > 0} { append msg " (with warnings)" }
    return [dict create ok 1 winIdx $winIdx file $norm warnings $warnings \
        redrawn $drawn message $msg]
}
#------------------------------------------------------------ PNG capture ----
# One graphic-area capture.  The handle names are passed in, because hwi object
# handles are commands in the global namespace - the caller frame does not
# matter.  <mode> selects the API, see Adapter::CaptureWindow for the order.
# Returns 1 on success (State::lastError holds the reason on failure).
#   clientImage   : '<client>  CaptureImage <file>'            window only
#   activeWindow  : '<session> CaptureActiveWindow png <file>' window only
#   screen        : '<session> CaptureScreen png <file>'       whole application
#   screenQuality : '<session> CaptureScreen png <file> <q>'   whole application
# The '<session> CaptureScreen png <file>' spelling is the one used by the
# shipped example scripts (hvTest.tcl); training.tcl adds the quality argument,
# therefore both spellings are tried.
proc ::ModelLoader::Adapter::CaptureGraphicArea {sess client file mode} {
    switch -- $mode {
        clientImage {
            return [::ModelLoader::Adapter::HvRun "CaptureImage" \
                [list $client CaptureImage $file]]
        }
        activeWindow {
            return [::ModelLoader::Adapter::HvRun "CaptureActiveWindow png" \
                [list $sess CaptureActiveWindow png $file]]
        }
        screen {
            return [::ModelLoader::Adapter::HvRun "CaptureScreen png" \
                [list $sess CaptureScreen png $file]]
        }
        screenQuality {
            return [::ModelLoader::Adapter::HvRun "CaptureScreen png <quality>" \
                [list $sess CaptureScreen png $file \
                    [::ModelLoader::Logic::CaptureQuality]]]
        }
    }
    ::ModelLoader::State::SetLastError "unknown capture mode '$mode'"
    return 0
}
# Captures <file> and returns the mode that worked ("" when none of them did).
# The mode that worked once is cached in State::captureMode and tried FIRST from
# then on, so only the first capture of a session pays the probing cost.
proc ::ModelLoader::Adapter::CaptureWindow {sess client file} {
    set all    {clientImage activeWindow screen screenQuality}
    set cached [::ModelLoader::State::GetCaptureMode]
    set modes  $all
    if {$cached ne "" && [lsearch -exact $all $cached] >= 0} {
        set rest {}
        foreach m $all { if {$m ne $cached} { lappend rest $m } }
        set modes [linsert $rest 0 $cached]
    }
    foreach mode $modes {
        if {[::ModelLoader::Adapter::CaptureGraphicArea $sess $client $file $mode]} {
            if {$cached ne $mode} { ::ModelLoader::State::SetCaptureMode $mode }
            return $mode
        }
    }
    return ""
}
# Applies one view list entry to a window ('<window> GetViewControlHandle' ->
# '<view> SetOrientation' / '<view> SetViewMatrix'), exactly like the shipped
# display_service.tcl does.  The name of the window handle command is passed in.
# A view is a nicety - nothing here is fatal, the warnings are returned.
proc ::ModelLoader::Adapter::ApplyViewEntry {winHandle entry} {
    set warnings {}
    set orientation [dict get $entry orientation]
    set matrix      [dict get $entry matrix]
    if {$orientation eq "" && $matrix eq ""} { return $warnings }
    if {![::ModelLoader::Adapter::HvRun "GetViewControlHandle" \
            [list $winHandle GetViewControlHandle mlView]]} {
        lappend warnings "'$winHandle' has no view control - the view was skipped"
        return $warnings
    }
    if {$matrix ne ""} {
        # the matrix is ONE argument, exactly like in hvTest.tcl /
        # display_service.tcl
        if {![::ModelLoader::Adapter::HvRun "SetViewMatrix" \
                [list mlView SetViewMatrix $matrix]]} {
            lappend warnings "the view matrix was refused:\
[::ModelLoader::State::GetLastError]"
        }
    } elseif {$orientation ne ""} {
        if {![::ModelLoader::Adapter::HvRun "SetOrientation $orientation" \
                [list mlView SetOrientation $orientation]]} {
            lappend warnings "orientation '$orientation' was refused:\
[::ModelLoader::State::GetLastError]"
        } else {
            # display_service.tcl fits the view after an orientation - but NOT
            # after a matrix (that would throw the stored zoom away)
            ::ModelLoader::Adapter::HvRun "Fit" {mlView Fit}
        }
    }
    ::ModelLoader::Adapter::ReleaseHandles {mlView}
    return $warnings
}
# STEP 3 (fix 5): captures the target window or every window of the page into
# <outDir> as PNG, one file per window and view.
#   scope        : 'target' | 'all'   (Logic::ValidateStep3 checked it before)
#   targetWindow : window index of 'target'
#   viewEntries  : parsed view list (may be empty -> one view per window)
# Every window is made the active window first (best effort, V13) so that the
# active-window / screen capture APIs grab the right window, and every view is
# applied before its file is written.  A failed capture does NOT abort the run -
# the report lists what worked and what did not.
# Returns dict: {ok <0|1> files <list of png> captured <n> failed <n>
#                mode <used capture mode> warnings <list> message <text>}
proc ::ModelLoader::Adapter::CapturePng {scope targetWindow viewEntries outDir} {
    ::ModelLoader::State::ClearLastError
    set base [dict create ok 1 files {} captured 0 failed 0 mode "" warnings {} \
        message ""]
    set dir [::ModelLoader::Logic::CheckOutputDir $outDir]
    if {![dict get $dir ok]} {
        return [dict merge $base [dict create ok 0 \
            message "PNG capture: [dict get $dir message]."]]
    }
    set outDir [dict get $dir path]
    if {[catch { file mkdir $outDir } msg]} {
        return [dict merge $base [dict create ok 0 \
            message "PNG capture: the output folder could not be created: $msg"]]
    }

    set indices [::ModelLoader::State::WindowIndices]
    if {[llength $indices] == 0} {
        set page [::ModelLoader::Adapter::QueryPage]
        if {[llength $page] > 0} {
            for {set i 1} {$i <= [dict get $page windows]} {incr i} {
                lappend indices $i
            }
        }
    }
    if {$scope eq "target"} { set indices [list $targetWindow] }
    set jobs [::ModelLoader::Logic::CapturePlan $scope $targetWindow \
        $viewEntries $indices $outDir]
    if {[llength $jobs] == 0} {
        return [dict merge $base [dict create ok 0 \
            message "PNG capture: there is no window to capture."]]
    }

    # one batch of jobs per window - a window handle is fetched once
    set byWindow {}
    foreach job $jobs {
        dict lappend byWindow [dict get $job window] $job
    }

    set files    {}
    set warnings {}
    set captured 0
    set failed   0
    set mode     ""

    if {![::ModelLoader::Adapter::HvRun "hwi OpenStack" {hwi OpenStack}]} {
        return [dict merge $base [dict create ok 0 \
            message "PNG capture: [::ModelLoader::State::GetLastError]"]]
    }
    set pageIdx ""
    set ready 0
    if {[::ModelLoader::Adapter::HvRun "GetSessionHandle" \
            {hwi GetSessionHandle mlSess}]} {
        if {[::ModelLoader::Adapter::HvRun "GetProjectHandle" \
                {mlSess GetProjectHandle mlProj}]} {
            if {[::ModelLoader::Adapter::HvRun "GetActivePage" \
                    {set pageIdx [mlProj GetActivePage]}]} {
                if {[::ModelLoader::Adapter::HvRun "GetPageHandle" \
                        {mlProj GetPageHandle mlPage $pageIdx}]} {
                    set ready 1
                }
            }
        }
    }
    if {!$ready} {
        ::ModelLoader::Adapter::ReleaseHandles {mlPage mlProj mlSess}
        ::ModelLoader::Adapter::HvRun "hwi CloseStack" {hwi CloseStack}
        return [dict merge $base [dict create ok 0 \
            message "PNG capture: the active page is not readable:\
[::ModelLoader::State::GetLastError]"]]
    }

    foreach w [lsort -integer [dict keys $byWindow]] {
        set wOk 0
        if {[::ModelLoader::Adapter::HvRun "GetWindowHandle $w" \
                {mlPage GetWindowHandle mlWin $w}]} {
            # V13 - VERIFY: '<page> SetActiveWindow' is not part of every
            # HyperView build; when it is missing the capture still works, it may
            # then just grab the window that was active already.
            ::ModelLoader::Adapter::HvRun "SetActiveWindow $w" \
                {mlPage SetActiveWindow $w}
            if {[::ModelLoader::Adapter::HvRun "GetClientHandle $w" \
                    {mlWin GetClientHandle mlClient}]} {
                set wOk 1
            }
        }
        if {!$wOk} {
            lappend warnings "window $w: [::ModelLoader::State::GetLastError]"
            incr failed [llength [dict get $byWindow $w]]
            ::ModelLoader::Adapter::ReleaseHandles {mlClient mlWin}
            continue
        }
        foreach job [dict get $byWindow $w] {
            set file  [dict get $job file]
            set entry [dict get $job view]
            foreach wmsg [::ModelLoader::Adapter::ApplyViewEntry mlWin $entry] {
                lappend warnings "window $w: $wmsg"
            }
            ::ModelLoader::Adapter::HvRun "Draw" {mlClient Draw}
            set mode [::ModelLoader::Adapter::CaptureWindow mlSess mlClient $file]
            if {$mode ne ""} {
                incr captured
                lappend files $file
                ::ModelLoader::Adapter::Log "captured '$file' via $mode"
            } else {
                incr failed
                lappend warnings "window $w, view '[dict get $job name]':\
[::ModelLoader::State::GetLastError]"
            }
        }
        ::ModelLoader::Adapter::ReleaseHandles {mlClient mlWin}
    }
    ::ModelLoader::Adapter::ReleaseHandles {mlView}
    ::ModelLoader::Adapter::ReleaseHandles {mlPage mlProj mlSess}
    ::ModelLoader::Adapter::HvRun "hwi CloseStack" {hwi CloseStack}

    set msg "PNG capture: $captured file(s) written to $outDir"
    if {$failed > 0} { append msg ", $failed capture(s) failed" }
    return [dict merge $base [dict create ok [expr {$captured > 0}] files $files \
        captured $captured failed $failed mode $mode warnings $warnings \
        message $msg]]
}
#=============================================================================
# SECTION 3 - UI LAYER (hwtk widgets only - Logic + Adapter are used here)
#     STEP 1 : page layout + load one model/result file per window (all windows
#              of the active page are handled, the results are then listed)
#     STEP 2 : choose subcase / simulation / result type / component, apply the
#              contour plot and (fix 4) load a legend from a file
#     STEP 3 : (fix 5) import a view list and capture the target window or every
#              window of the page as PNG
#   PLAIN TK is used in exactly one place: the read-only information listbox
#   and its scrollbar, because hwtk has no listbox wrapper.  Everything else is
#   hwtk (dialog / frame / labelframe / label / button / entry / combobox /
#   checkbutton / openfileentry).
#=============================================================================
namespace eval ::ModelLoader::UI {
    variable dlg       ""
    variable recess    ""
    variable step      1
    # 0 = the buttons live in the hwtk::dialog button box,
    # 1 = 'insert apply' was not available, own button bar is used (fallback).
    variable customBar 0
    # widget paths
    variable wBody      ""
    variable wStep1     ""
    variable wStep2     ""
    variable wStep3     ""
    variable wInfo      ""
    variable wStatus    ""
    variable wWindowCount ""
    variable wTargetWin   ""
    variable wTargetWin2  ""
    variable wPageInfo    ""
    variable wFile        ""   ;# kept: points at the 'Input Model' widget
    variable wModelFile   ""
    variable wResultFile  ""
    variable wModelInfo   ""
    variable wSubcase     ""
    variable wSimulation  ""
    variable wDataType    ""
    variable wComponent   ""
    variable wAveraging   ""
    variable wLayer       ""
    variable wApplyAll    ""
    variable wLegendFile  ""   ;# FIX 4: legend file field of step 2
    variable wStepTitle   ""
    variable wStepHelp    ""
    # FIX 5: step 3 widgets (view list + PNG capture)
    variable wViewListFile ""
    variable wViewListInfo ""
    variable wOutputDir    ""
    variable wCaptureScope ""
    variable wTargetWin3   ""
    # values bound to the widgets (they survive a rebuild of the dialog)
    variable varWindowCount 2
    # last window count that was accepted (invalid typing is reverted to it)
    variable lastGoodWindowCount 2
    variable varTargetWin   1
    variable varFile        ""       ;# primary file, mirrors varModelFile
    variable varModelFile   ""
    variable varResultFile  ""
    variable varModelInfo   ""
    variable varSubcase     ""
    variable varSimulation  {<default>}
    variable varDataType    ""
    variable varComponent   ""
    variable varAveraging   {<default>}
    variable varLayer       {<default>}
    variable varApplyAll    1
    variable varLegendFile  ""      ;# FIX 4: legend file of the target window
    # FIX 5: step 3 values
    variable varViewListFile ""     ;# view list file
    variable varViewListInfo "no view list imported - one PNG per window"
    variable varOutputDir    ""     ;# PNG output folder
    variable varCaptureScope target ;# 'target' | 'all'
    variable statusText     "Ready."
}

#------------------------------------- tiny widget helpers -------------------
proc ::ModelLoader::UI::SetStatus {text} {
    variable statusText
    set statusText $text
    ::ModelLoader::State::SetStatus $text
    return
}
# Replace the whole content of the information pane.
proc ::ModelLoader::UI::SetInfo {lines} {
    variable wInfo
    if {$wInfo eq "" || ![winfo exists $wInfo]} { return }
    $wInfo delete 0 end
    foreach line $lines { $wInfo insert end $line }
    catch { $wInfo yview moveto 0 }
    catch { $wInfo xview moveto 0 }
    return
}
proc ::ModelLoader::UI::AppendInfo {lines} {
    variable wInfo
    if {$wInfo eq "" || ![winfo exists $wInfo]} { return }
    foreach line $lines { $wInfo insert end $line }
    catch { $wInfo yview moveto 1 }
    return
}
# Repopulate a read-only combobox.
# V8 - VERIFY: 'hwtk::combobox configure -values <list>' is the documented way
#      to change the list of an existing combobox; hwtk comboboxes are ttk
#      widgets, so the option is the same as for ttk::combobox.
proc ::ModelLoader::UI::SetComboValues {widget values} {
    if {$widget eq "" || ![winfo exists $widget]} { return 0 }
    # '-values' is a LIST option of every hwtk/ttk combobox, therefore the list
    # must be passed as it is: 'configure -values [list $values]' would wrap it
    # into a second list and the combobox would show ONE glued entry.
    if {[catch { $widget configure -values $values } msg]} {
        ::ModelLoader::Adapter::Log "configure -values failed on $widget: $msg"
        return 0
    }
    return 1
}
# Writes <value> into a combobox / entry widget and reports whether it worked.
# BUG FIX 1: '$widget set <value>' is the ttk way and works for ttk::combobox,
# but it is not guaranteed on every hwtk build.  The fallbacks below prevent the
# field from silently showing something else: an hwtk combobox that ignores
# 'set' would keep displaying the FIRST entry of its '-values' list, which for
# the window-count box is exactly "1" (the value that "jumped back").
proc ::ModelLoader::UI::SetWidgetValue {widget value} {
    if {$widget eq "" || ![winfo exists $widget]} { return 0 }
    if {![catch { $widget set $value }]} { return 1 }
    # combobox: select the matching entry by its index
    set values {}
    catch { set values [$widget cget -values] }
    set idx [lsearch -exact $values $value]
    if {$idx >= 0 && ![catch { $widget current $idx }]} { return 1 }
    # entry-like widget: replace the content
    if {![catch { $widget delete 0 end }]} {
        if {![catch { $widget insert 0 $value }]} { return 1 }
    }
    ::ModelLoader::Adapter::Log "cannot write '$value' into the widget $widget"
    return 0
}
# Reads the LIVE content of a widget ('get'), falling back to <default> when the
# widget does not exist or does not understand 'get'.
# The 'winfo' guard keeps the proc usable in a session without Tk (the pure
# selftest does exactly that).
proc ::ModelLoader::UI::WidgetText {widget {default ""}} {
    if {$widget eq ""} { return $default }
    if {[llength [info commands winfo]] == 0} { return $default }
    if {![winfo exists $widget]} { return $default }
    if {[catch { set v [$widget get] }]} { return $default }
    return $v
}
#------------------------------------------------- window count (bug 1 fix) ---
# The window count is read from the WIDGET first and only then from the Tcl
# variable.  If a build does not honour '-textvariable' on that combobox the
# variable keeps its initial value, so reading the variable alone would apply
# the default instead of what the user picked ("the value jumps back").
# Returns the validated number, or "" when the input is not usable at all.
proc ::ModelLoader::UI::ReadWindowCount {} {
    variable wWindowCount
    variable varWindowCount
    set raw [string trim [::ModelLoader::UI::WidgetText $wWindowCount $varWindowCount]]
    if {$raw eq ""} { set raw [string trim $varWindowCount] }
    if {![string is integer -strict $raw] || $raw < 1} { return "" }
    return $raw
}
# Writes <n> into the variable AND into the combobox and makes sure <n> is one
# of the offered values - so the number the user typed can never be dropped and
# the field can never silently fall back to 1.
# BUG FIX 1: (a) a value that is not a positive integer is refused here instead
# of being stored - that keeps 'lastGoodWindowCount' intact, which
# OnWindowCountChanged falls back to; (b) '-values' is only reconfigured when
# <n> is not offered yet, because every needless 'configure -values' is a chance
# for the widget to lose the current selection (and to show its first entry = 1).
proc ::ModelLoader::UI::SetWindowCountValue {n} {
    variable wWindowCount
    variable varWindowCount
    variable lastGoodWindowCount
    if {![string is integer -strict $n] || $n < 1} { return $n }
    set varWindowCount $n
    set lastGoodWindowCount $n
    if {$wWindowCount ne "" && [winfo exists $wWindowCount]} {
        set values [::ModelLoader::Logic::WindowCountChoices]
        if {[lsearch -exact $values $n] < 0} {
            lappend values $n
            ::ModelLoader::UI::SetComboValues $wWindowCount $values
        }
    }
    ::ModelLoader::UI::SetWidgetValue $wWindowCount $n
    return $n
}
# Handler of <<ComboboxSelected>> / <Return> / <FocusOut> of that combobox.
# Only genuinely invalid input (letters, 0, negative) is reverted to the last
# good number - every valid number is kept and applied.
proc ::ModelLoader::UI::OnWindowCountChanged {} {
    variable wWindowCount
    variable varWindowCount
    variable lastGoodWindowCount
    set raw [string trim [::ModelLoader::UI::WidgetText $wWindowCount $varWindowCount]]
    if {$raw eq ""} { set raw [string trim $varWindowCount] }
    if {![string is integer -strict $raw] || $raw < 1} {
        ::ModelLoader::UI::SetStatus \
            "'$raw' is not a number of windows - kept $lastGoodWindowCount."
        return [::ModelLoader::UI::SetWindowCountValue $lastGoodWindowCount]
    }
    return [::ModelLoader::UI::SetWindowCountValue $raw]
}
# Same widget -> variable sync for the two 'Target window' comboboxes: whatever
# the user selected in the widget WINS over the stored variable.
proc ::ModelLoader::UI::OnTargetWindowChanged {} {
    variable wTargetWin
    variable wTargetWin2
    variable varTargetWin
    set raw [string trim [::ModelLoader::UI::WidgetText $wTargetWin $varTargetWin]]
    if {$raw eq ""} {
        set raw [string trim [::ModelLoader::UI::WidgetText $wTargetWin2 $varTargetWin]]
    }
    if {[string is integer -strict $raw] && $raw >= 1} {
        set varTargetWin $raw
        ::ModelLoader::UI::SetWidgetValue $wTargetWin2 $raw
    }
    return $varTargetWin
}
#----------------------------------------------- file chooser (bug 2 fix) -----
# Creates one file field of step 1.
#   <parent> parent widget  <name> widget path component
#   <varname> fully qualified variable the field is bound to
#   <types>  filetypes list - Logic::ModelFileTypes or Logic::ResultFileTypes
# Preferred widget is 'hwtk::openfileentry -filetypes <types>'.  When the build
# does not provide that command, or refuses the widget / the -filetypes option,
# the field degrades gracefully to a plain 'hwtk::entry'; the caller always adds
# a 'Browse...' button that uses 'tk_getOpenFile -filetypes <types>' with the
# very same list (UI::BrowseFile).
# Returns the widget path the caller has to grid.
proc ::ModelLoader::UI::CreateFileChooser {parent name varname types width} {
    set path $parent.$name
    if {[llength [info commands ::hwtk::openfileentry]] > 0} {
        if {![catch {
            hwtk::openfileentry $path -width $width -filetypes $types \
                -textvariable $varname
        } msg]} {
            return $path
        }
        ::ModelLoader::Adapter::Log \
            "openfileentry -filetypes refused on $path ($msg) - retry without it"
        catch { destroy $path }
        if {![catch {
            hwtk::openfileentry $path -width $width -textvariable $varname
        } msg2]} {
            return $path
        }
        ::ModelLoader::Adapter::Log \
            "openfileentry refused on $path ($msg2) - using entry + tk_getOpenFile"
        catch { destroy $path }
    }
    return [hwtk::entry $path -width $width -textvariable $varname]
}
# Writes a path into a file field: the Tcl variable first (that is what the
# script reads) and then the widget - with fallbacks, because hwtk entries are
# ttk entries and not every build implements a 'set' subcommand.
proc ::ModelLoader::UI::SetFileWidget {widget varname value} {
    if {$varname ne ""} { uplevel #0 [list set $varname $value] }
    if {$widget eq "" || ![winfo exists $widget]} { return $value }
    if {[catch { $widget set $value }]} {
        catch { $widget delete 0 end }
        catch { $widget insert 0 $value }
    }
    return $value
}
# 'Browse...' button of a file field - the plain Tk browser with the same
# filetypes list the field itself offers:
#     tk_getOpenFile -title ... -filetypes <types>
# The chosen path is checked, normalised and written back into the field.
proc ::ModelLoader::UI::BrowseFile {widget varname types kind} {
    if {[catch {
        set file [tk_getOpenFile -title "Choose the $kind file" -filetypes $types]
    } msg]} {
        ::ModelLoader::UI::SetStatus "The file browser could not be opened: $msg"
        return ""
    }
    if {$file eq ""} { return "" }
    return [::ModelLoader::UI::ApplyChosenFile $widget $varname $kind $file]
}
# Post-processing of a path that came out of a browser (or was typed): validate
# it with Logic::CheckChosenFile, normalise it, write it back into the field and
# report the outcome - including a reader suggestion - in the status line.
proc ::ModelLoader::UI::ApplyChosenFile {widget varname kind path} {
    set check [::ModelLoader::Logic::CheckChosenFile $path $kind]
    set norm  [dict get $check path]
    if {$norm eq ""} { set norm $path }
    ::ModelLoader::UI::SetFileWidget $widget $varname $norm
    if {![dict get $check ok]} {
        ::ModelLoader::UI::SetStatus \
            "[string totitle $kind] file rejected: [dict get $check message]"
        return ""
    }
    set hint [::ModelLoader::Logic::ReaderHint $norm]
    if {[dict get $check message] ne ""} {
        ::ModelLoader::UI::SetStatus "$norm - [dict get $check message]"
    } elseif {$hint ne ""} {
        ::ModelLoader::UI::SetStatus "Chosen $kind file:\
[::ModelLoader::Logic::Basename $norm] (reader suggestion: $hint)"
    } else {
        ::ModelLoader::UI::SetStatus "Chosen $kind file: [::ModelLoader::Logic::Basename $norm]"
    }
    return $norm
}
#------------------------------------- dialog buttons --------------------------
# Adds one button to the wizard.  Preferred place is the button box of the
# hwtk::dialog ('insert apply <name>', exactly like review_tools.tcl does);
# when that is refused an own button bar inside the recess is created instead.
proc ::ModelLoader::UI::AddButton {name text command} {
    variable dlg
    variable recess
    variable customBar
    # Lower case key for the dialog button name AND for the widget path of the
    # fallback button bar: hwtk widgets are ttk widgets and Tk refuses every
    # path component that starts with a capital letter.
    set key [string tolower $name]
    if {!$customBar && [catch { $dlg insert apply $key } msg]} {
        ::ModelLoader::Adapter::Log "dialog 'insert apply $key' failed ($msg) - using own button bar"
        set customBar 1
    }
    if {$customBar} {
        if {![winfo exists $recess.btnbar]} {
            hwtk::frame $recess.btnbar
            pack $recess.btnbar -side bottom -fill x -pady 4
        }
        if {![winfo exists $recess.btnbar.$key]} {
            hwtk::button $recess.btnbar.$key -text $text -command $command
            pack $recess.btnbar.$key -side right -padx 4
        } else {
            $recess.btnbar.$key configure -text $text -command $command
        }
        return $key
    }
    $dlg buttonconfigure $key -text $text -command $command -state normal
    return $key
}
proc ::ModelLoader::UI::SetButtonState {name state} {
    variable dlg
    variable recess
    variable customBar
    set key [string tolower $name]
    if {$customBar} {
        catch { $recess.btnbar.$key configure -state $state }
        return
    }
    catch { $dlg buttonconfigure $key -state $state }
    return
}
#------------------------------------- post / close ---------------------------
proc ::ModelLoader::UI::Post {} {
    variable dlg
    if {[catch { $dlg post } msg]} {
        ::ModelLoader::Adapter::Log "dialog post failed ($msg) - wm deiconify fallback"
        catch { wm deiconify $dlg }
    }
    catch { raise $dlg }
    return
}
# cancel button of the dialog (confirmed: buttonconfigure cancel -command ...)
proc ::ModelLoader::UI::DoClose {} {
    variable dlg
    if {$dlg eq ""} { return }
    catch { destroy $dlg }
    # both close idioms are used by real scripts (lc_tree.tcl / review_tools.tcl)
    catch { wm withdraw $dlg }
    set dlg ""
    return
}
#=============================================================================
# SECTION 3a - BUILD THE WIZARD SHELL
#=============================================================================
# Creates the dialog, its buttons, the banner, the three step frames, the
# information pane and the status line.  The content of the steps is created by
# BuildStep1 / BuildStep2 / BuildStep3, all of which are called from here.
proc ::ModelLoader::UI::Build {} {
    variable dlg
    variable recess
    variable customBar
    variable wBody
    variable wStep1
    variable wStep2
    variable wStep3
    variable wInfo
    variable wStatus
    variable wStepTitle
    variable wStepHelp

    if {[winfo exists .modelLoaderGUI]} { catch { destroy .modelLoaderGUI } }
    set customBar 0

    # Options exactly as used by the real HyperView scripts lc_tree.tcl and
    # review_tools.tcl: -propagate -buttonboxpos -minwidth -minheight -x -y
    # -title.
    # V7 - VERIFY: some hwtk builds accept a '-modal' option for hwtk::dialog.
    #      It is NOT used here because it could not be confirmed for 2022.
    set x [winfo pointerx .]
    set y [winfo pointery .]
    hwtk::dialog .modelLoaderGUI \
        -propagate 1 \
        -buttonboxpos se \
        -minwidth 800 \
        -minheight 580 \
        -x $x -y $y \
        -title "Model Loader / Contour - HyperView 2022"
    set dlg .modelLoaderGUI
    set recess [.modelLoaderGUI recess]

    # --- the buttons ---------------------------------------------------------
    ::ModelLoader::UI::AddButton Back  "< Back"        ::ModelLoader::UI::StepBack
    ::ModelLoader::UI::AddButton Next  "Next >"        ::ModelLoader::UI::StepNext
    ::ModelLoader::UI::AddButton Apply "Apply contour" ::ModelLoader::UI::OnApply
    ::ModelLoader::UI::AddButton Close "Close"         ::ModelLoader::UI::DoClose
    # the predefined ok / apply buttons of hwtk::dialog are not needed
    catch { $dlg hide ok }
    catch { $dlg hide apply }
    catch { $dlg buttonconfigure cancel -command ::ModelLoader::UI::DoClose }

    # --- status line (packed first so that it stays visible) -----------------
    set wStatus [hwtk::label $recess.status \
        -textvariable ::ModelLoader::UI::statusText -justify left -anchor w]
    pack $wStatus -side bottom -fill x -pady 2

    # --- information pane ----------------------------------------------------
    # PLAIN TK: hwtk provides no listbox wrapper, therefore the read-only
    # information pane is a plain Tk listbox with a plain Tk scrollbar.  Both
    # exist in every HyperView 2022.
    set infol [hwtk::labelframe $recess.info -text " Information " -padding 4]
    pack $infol -side bottom -fill both -expand 1 -pady 4
    frame $infol.inner
    pack $infol.inner -fill both -expand 1
    set wInfo [listbox $infol.inner.lb -height 14 -activestyle none \
        -exportselection 0 -font TkFixedFont -yscrollcommand "$infol.inner.sb set"]
    scrollbar $infol.inner.sb -orient vertical -command "$infol.inner.lb yview"
    pack $infol.inner.sb -side right -fill y
    pack $infol.inner.lb -side left -fill both -expand 1

    # --- banner --------------------------------------------------------------
    set head [hwtk::frame $recess.head]
    pack $head -side top -fill x
    set wStepTitle [hwtk::label $head.title -text "Step 1 of 3" -justify left -anchor w]
    pack $wStepTitle -side top -fill x
    set wStepHelp [hwtk::label $head.help -text "" -justify left -anchor w -wraplength 760]
    pack $wStepHelp -side top -fill x

    # --- body (holds the two step frames, only one is packed at a time) ------
    set wBody [hwtk::frame $recess.body]
    pack $wBody -side top -fill both -expand 1 -pady 4
    set wStep1 [hwtk::frame $wBody.step1]
    set wStep2 [hwtk::frame $wBody.step2]
    set wStep3 [hwtk::frame $wBody.step3]
    ::ModelLoader::UI::BuildStep1
    ::ModelLoader::UI::BuildStep2
    ::ModelLoader::UI::BuildStep3
    ::ModelLoader::UI::BindStep2
    ::ModelLoader::UI::BindStep3

    ::ModelLoader::UI::ShowStep 1
    ::ModelLoader::UI::RefreshWindowList
    return $dlg
}










#=============================================================================
# SECTION 3b - STEP SWITCHING AND GLOBAL REFRESH
#=============================================================================
proc ::ModelLoader::UI::ShowStep {n} {
    variable step
    variable wStep1
    variable wStep2
    variable wStep3
    variable wStepTitle
    variable wStepHelp

    set step $n
    if {[winfo exists $wStep1]} { pack forget $wStep1 }
    if {[winfo exists $wStep2]} { pack forget $wStep2 }
    if {[winfo exists $wStep3]} { pack forget $wStep3 }

    if {$step == 1} {
        pack $wStep1 -side top -fill both -expand 1
        catch { $wStepTitle configure -text "STEP 1 of 3 - Page layout and model loading" }
        catch { $wStepHelp configure -text "Set how many windows the active page shows,\
then load one model or result file into each window.  'Learn layouts' lets HyperView \
itself report which layout token belongs to which window count (fix 3).  The results that \
HyperView finds in every window are listed in the information pane below." }
        ::ModelLoader::UI::SetButtonState Back  disabled
        ::ModelLoader::UI::SetButtonState Next  normal
        ::ModelLoader::UI::SetButtonState Apply disabled
        ::ModelLoader::UI::RefreshWindowList
    } elseif {$step == 2} {
        pack $wStep2 -side top -fill both -expand 1
        catch { $wStepTitle configure -text "STEP 2 of 3 - Contour plot and legend" }
        catch { $wStepHelp configure -text "Pick the subcase, the simulation, the result\
(data) type and the component of the selected window, then apply the contour plot.  \
'Apply to all loaded windows' repeats the same settings in every window that holds a \
subcase with the same label.  'Load legend' applies a legend that was saved to a *.tcl \
file (fix 4)." }
        ::ModelLoader::UI::SetButtonState Back  normal
        ::ModelLoader::UI::SetButtonState Next  normal
        ::ModelLoader::UI::SetButtonState Apply normal
        ::ModelLoader::UI::RefreshStep2
    } else {
        pack $wStep3 -side top -fill both -expand 1
        catch { $wStepTitle configure -text "STEP 3 of 3 - Capture PNG" }
        catch { $wStepHelp configure -text "Optional: import a view list (one view per\
line), choose the PNG output folder and capture the target window or every window of the \
active page.  A view list is a plain text file, the PNG name is \
'w<window>_<view>.png'." }
        ::ModelLoader::UI::SetButtonState Back  normal
        ::ModelLoader::UI::SetButtonState Next  disabled
        ::ModelLoader::UI::SetButtonState Apply normal
        ::ModelLoader::UI::RefreshStep3
    }
    return $step
}
proc ::ModelLoader::UI::StepNext {} {
    variable step
    if {[catch { ::ModelLoader::Logic::ValidateStep1 } msg]} {
        ::ModelLoader::UI::SetStatus "Step 1 is not finished: $msg"
        catch { tk_messageBox -title "Model Loader" -icon warning -message $msg \
            -parent .modelLoaderGUI }
        return
    }
    if {$step >= 3} { return }
    if {$step == 1} {
        ::ModelLoader::UI::ShowStep 2
        ::ModelLoader::UI::SetStatus "Step 2: choose the contour settings."
    } else {
        # FIX 5: step 3 does not need a contour, it captures what the windows show
        ::ModelLoader::UI::ShowStep 3
        ::ModelLoader::UI::SetStatus "Step 3: import a view list and capture PNG files."
    }
    return
}
proc ::ModelLoader::UI::StepBack {} {
    variable step
    if {$step <= 1} { return }
    # compute the target step FIRST - ShowStep writes the variable
    set target [expr {$step - 1}]
    ::ModelLoader::UI::ShowStep $target
    switch -- $target {
        1 { ::ModelLoader::UI::SetStatus "Step 1: page layout and model loading." }
        2 { ::ModelLoader::UI::SetStatus "Step 2: contour plot and legend." }
        default { ::ModelLoader::UI::SetStatus "Step 3: PNG capture." }
    }
    return
}
# Shows everything the State layer knows about all windows of the active page.
proc ::ModelLoader::UI::RefreshWindowList {} {
    variable wTargetWin
    variable varTargetWin
    set lines {}

    set info [::ModelLoader::Adapter::QueryPage]
    if {[llength $info] > 0} {
        lappend lines "ACTIVE PAGE" \
            "  page index          : [dict get $info page]" \
            "  windows on the page : [dict get $info windows]" \
            "  layout token        : [dict get $info layout]"
    } else {
        lappend lines "ACTIVE PAGE" \
            "  (could not be read: [::ModelLoader::State::GetLastError])"
    }
    lappend lines "" "WINDOWS"
    set idxList [::ModelLoader::State::WindowIndices]
    if {[llength $idxList] == 0} {
        lappend lines "  nothing handled yet - load a model into a window first"
    } else {
        foreach idx $idxList {
            lappend lines "  [::ModelLoader::Logic::WindowSummary $idx]"
        }
    }
    lappend lines "" "RESULT TREE OF WINDOW $varTargetWin"
    foreach line [::ModelLoader::Logic::ResultSummary $varTargetWin] {
        lappend lines "  $line"
    }
    ::ModelLoader::UI::SetInfo $lines

    # the target-window combobox follows the windows of the active page, but it
    # must NEVER throw away the window the user picked (bug fix): the page only
    # reports the windows that exist RIGHT NOW (usually 1 before a layout was
    # applied), so a blind "[lindex $choices 0]" reset the field to 1 on every
    # refresh.  The user's number is kept and stays selectable instead.
    set choices {}
    if {[llength $info] > 0} {
        for {set i 1} {$i <= [dict get $info windows]} {incr i} { lappend choices $i }
    }
    set cur $varTargetWin
    if {![string is integer -strict $cur] || $cur < 1} { set cur 1 }
    if {[llength $choices] == 0} {
        # page could not be read: keep what the user had, do not invent a value
        set choices [list $cur]
    }
    while {[llength $choices] < $cur} { lappend choices [expr {[llength $choices] + 1}] }
    set varTargetWin $cur
    ::ModelLoader::UI::SetComboValues $wTargetWin $choices
    ::ModelLoader::UI::SetWidgetValue $wTargetWin $varTargetWin
    return $info
}


#=============================================================================
# SECTION 3c - STEP 1 WIDGETS (page layout + load a model into every window)
#=============================================================================
proc ::ModelLoader::UI::BuildStep1 {} {
    variable wStep1
    variable wWindowCount
    variable wTargetWin
    variable wPageInfo
    variable wFile
    variable wModelFile
    variable wResultFile
    variable varFile
    variable varModelFile
    variable varResultFile

    # --- active page layout --------------------------------------------------
    set lf [hwtk::labelframe $wStep1.layout -text " Active page layout " -padding 4]
    grid $lf -row 0 -column 0 -sticky ew -pady 2 -padx 2
    grid columnconfigure $wStep1 0 -weight 1
    grid columnconfigure $lf 1 -weight 1

    hwtk::label $lf.l1 -text "Windows on the active page:" -width 26 -anchor w
    grid $lf.l1 -row 0 -column 0 -sticky w -padx 2 -pady 2
    set wWindowCount [hwtk::combobox $lf.cb -state readonly -width 8 \
        -values [::ModelLoader::Logic::WindowCountChoices] \
        -textvariable ::ModelLoader::UI::varWindowCount]
    grid $lf.cb -row 0 -column 1 -sticky w -padx 2 -pady 2
    # The value the user picked has to reach the variable - a build that does
    # not honour '-textvariable' on this combobox would otherwise keep the
    # initial value and "reset" the field (bug 1).
    # V9 - VERIFY: hwtk comboboxes generate the ttk <<ComboboxSelected>> event.
    foreach ev {<<ComboboxSelected>> <Return> <FocusOut>} {
        catch { bind $lf.cb $ev { ::ModelLoader::UI::OnWindowCountChanged } }
    }
    # the field shows what the script really has (never a stale variable value);
    # an unreadable field is left alone - SetWindowCountValue ignores garbage
    # instead of blanking the box (bug 1 fix)
    catch { bind $lf.cb <Map> { ::ModelLoader::UI::SetWindowCountValue \
        [::ModelLoader::UI::ReadWindowCount] } }
    hwtk::button $lf.apply -text "Apply layout" -command ::ModelLoader::UI::OnApplyLayout
    grid $lf.apply -row 0 -column 2 -sticky w -padx 6 -pady 2
    # FIX 3: asks HyperView ITSELF which layout token belongs to which window
    # count (Adapter::LearnLayouts) - one probe per count, the token every count
    # accepted is cached and the original layout is put back afterwards.
    hwtk::button $lf.learn -text "Learn layouts" \
        -command ::ModelLoader::UI::OnLearnLayouts
    grid $lf.learn -row 0 -column 3 -sticky w -padx 6 -pady 2
    hwtk::button $lf.refresh -text "Refresh page info" \
        -command ::ModelLoader::UI::OnRefreshPage
    grid $lf.refresh -row 0 -column 4 -sticky w -padx 6 -pady 2
    set wPageInfo [hwtk::label $lf.info -text "" -anchor w -justify left -wraplength 740]
    grid $wPageInfo -row 1 -column 0 -columnspan 4 -sticky w -padx 2 -pady 2

    # --- load model and results ----------------------------------------------
    set lf2 [hwtk::labelframe $wStep1.load -text " Load model and results " -padding 4]
    grid $lf2 -row 1 -column 0 -sticky ew -pady 2 -padx 2
    grid columnconfigure $lf2 1 -weight 1

    hwtk::label $lf2.l1 -text "Target window:" -width 26 -anchor w
    grid $lf2.l1 -row 0 -column 0 -sticky w -padx 2 -pady 2
    set wTargetWin [hwtk::combobox $lf2.cb -state readonly -width 8 -values {1} \
        -textvariable ::ModelLoader::UI::varTargetWin]
    grid $lf2.cb -row 0 -column 1 -sticky w -padx 2 -pady 2
    # the selection wins over the stored variable (same reason as bug 1)
    foreach ev {<<ComboboxSelected>> <Return> <FocusOut>} {
        catch { bind $lf2.cb $ev { ::ModelLoader::UI::OnTargetWindowChanged } }
    }
    hwtk::button $lf2.reload -text "Re-read results of this window" \
        -command ::ModelLoader::UI::OnRefreshWindow
    grid $lf2.reload -row 0 -column 2 -sticky w -padx 6 -pady 2

    # --- 'Input Model' : FE model / input deck, *.inp first -------------------
    hwtk::label $lf2.l2 -text "Input Model:" -width 26 -anchor w
    grid $lf2.l2 -row 1 -column 0 -sticky w -padx 2 -pady 2
    set modelTypes [::ModelLoader::Logic::ModelFileTypes]
    set wModelFile [::ModelLoader::UI::CreateFileChooser $lf2 model \
        ::ModelLoader::UI::varModelFile $modelTypes 50]
    set wFile $wModelFile ;# backwards compatible alias
    grid $wModelFile -row 1 -column 1 -sticky ew -padx 2 -pady 2
    hwtk::button $lf2.modelBrowse -text "Browse..." -command [list \
        ::ModelLoader::UI::BrowseFile $wModelFile \
        ::ModelLoader::UI::varModelFile $modelTypes model]
    grid $lf2.modelBrowse -row 1 -column 2 -sticky w -padx 6 -pady 2

    # --- 'Input Result' : result file, *.res (FEMFAT) first -------------------
    hwtk::label $lf2.l2b -text "Input Result:" -width 26 -anchor w
    grid $lf2.l2b -row 2 -column 0 -sticky w -padx 2 -pady 2
    set resultTypes [::ModelLoader::Logic::ResultFileTypes]
    set wResultFile [::ModelLoader::UI::CreateFileChooser $lf2 result \
        ::ModelLoader::UI::varResultFile $resultTypes 50]
    grid $wResultFile -row 2 -column 1 -sticky ew -padx 2 -pady 2
    hwtk::button $lf2.resultBrowse -text "Browse..." -command [list \
        ::ModelLoader::UI::BrowseFile $wResultFile \
        ::ModelLoader::UI::varResultFile $resultTypes result]
    grid $lf2.resultBrowse -row 2 -column 2 -sticky w -padx 6 -pady 2

    # --- the load button ------------------------------------------------------
    # FIX 2: there is NO reader field any more - 'AddModel <file>' lets
    # HyperView detect the reader from the file, so the user only picks the two
    # files.  (Logic::ReaderHint is still shown in the status line as a hint,
    # it is never handed to HyperView.)
    hwtk::label $lf2.l3 -anchor w -justify left \
        -text "The reader is detected automatically from the file."
    grid $lf2.l3 -row 3 -column 0 -columnspan 2 -sticky w -padx 2 -pady 2
    hwtk::button $lf2.load -text "Load into window" -command ::ModelLoader::UI::OnLoadModel
    grid $lf2.load -row 3 -column 2 -sticky w -padx 6 -pady 2

    hwtk::label $lf2.l4 -anchor w -justify left -wraplength 740 \
        -text "'Input Model' offers *.inp (Abaqus) first, 'Input Result' offers *.res (FEMFAT)\
first - the 'Browse...' buttons and the widget browsers of both fields use the same filter \
list.  Fill in only what you have: model only, result only, or both.  \
The file loaded into window N is kept per window; the result tree of every window is listed below."
    grid $lf2.l4 -row 4 -column 0 -columnspan 3 -sticky w -padx 2 -pady 2
    return
}



#=============================================================================
# SECTION 3d - STEP 2 WIDGETS (contour selection)
#=============================================================================
proc ::ModelLoader::UI::BuildStep2 {} {
    variable wStep2
    variable wModelInfo
    variable wSubcase
    variable wSimulation
    variable wDataType
    variable wComponent
    variable wAveraging
    variable wLayer
    variable wApplyAll
    variable wTargetWin2
    variable wLegendFile

    set lf [hwtk::labelframe $wStep2.contour -text " Contour settings " -padding 4]
    grid $lf -row 0 -column 0 -sticky ew -pady 2 -padx 2
    grid columnconfigure $wStep2 0 -weight 1
    grid columnconfigure $lf 1 -weight 1
    grid columnconfigure $lf 3 -weight 1

    # --- row 0 : target window / model name ---------------------------------
    hwtk::label $lf.l0 -text "Target window:" -width 22 -anchor w
    grid $lf.l0 -row 0 -column 0 -sticky w -padx 2 -pady 2
    set wTargetWin2 [hwtk::combobox $lf.win -state readonly -width 28 -values {1} \
        -textvariable ::ModelLoader::UI::varTargetWin]
    grid $lf.win -row 0 -column 1 -sticky w -padx 2 -pady 2
    hwtk::label $lf.l0b -text "Model:" -width 22 -anchor w
    grid $lf.l0b -row 0 -column 2 -sticky w -padx 2 -pady 2
    set wModelInfo [hwtk::label $lf.model -textvariable ::ModelLoader::UI::varModelInfo \
        -anchor w -justify left]
    grid $lf.model -row 0 -column 3 -sticky w -padx 2 -pady 2

    # --- row 1 : subcase / simulation ---------------------------------------
    hwtk::label $lf.l1 -text "Subcase:" -width 22 -anchor w
    grid $lf.l1 -row 1 -column 0 -sticky w -padx 2 -pady 2
    # V8 - VERIFY: the list of an existing hwtk::combobox is changed with
    #      'configure -values <list>'.
    set wSubcase [hwtk::combobox $lf.subcase -state readonly -width 28 -values {} \
        -textvariable ::ModelLoader::UI::varSubcase]
    grid $lf.subcase -row 1 -column 1 -sticky w -padx 2 -pady 2
    hwtk::label $lf.l1b -text "Simulation:" -width 22 -anchor w
    grid $lf.l1b -row 1 -column 2 -sticky w -padx 2 -pady 2
    set wSimulation [hwtk::combobox $lf.sim -state readonly -width 28 -values {<default>} \
        -textvariable ::ModelLoader::UI::varSimulation]
    grid $lf.sim -row 1 -column 3 -sticky w -padx 2 -pady 2
    # a simulation is applied by index, so the label is translated back with
    # Logic::SimulationIndex; '<default>' means 'do not touch it'.

    # --- row 2 : result type / component ------------------------------------
    hwtk::label $lf.l2 -text "Result type:" -width 22 -anchor w
    grid $lf.l2 -row 2 -column 0 -sticky w -padx 2 -pady 2
    # V6 - VERIFY: 'result GetDataComponentList <subcaseId> <dataType>' is
    #      queried by the adapter for every result type of the subcase.
    set wDataType [hwtk::combobox $lf.dtype -state readonly -width 28 -values {} \
        -textvariable ::ModelLoader::UI::varDataType]
    grid $lf.dtype -row 2 -column 1 -sticky w -padx 2 -pady 2
    hwtk::label $lf.l2b -text "Component:" -width 22 -anchor w
    grid $lf.l2b -row 2 -column 2 -sticky w -padx 2 -pady 2
    set wComponent [hwtk::combobox $lf.comp -state readonly -width 28 -values {} \
        -textvariable ::ModelLoader::UI::varComponent]
    grid $lf.comp -row 2 -column 3 -sticky w -padx 2 -pady 2

    # --- row 3 : averaging / layer ------------------------------------------
    hwtk::label $lf.l3 -text "Averaging:" -width 22 -anchor w
    grid $lf.l3 -row 3 -column 0 -sticky w -padx 2 -pady 2
    # V2 - VERIFY: the averaging strings are passed to SetAverageMode unchanged.
    set wAveraging [hwtk::combobox $lf.avg -state readonly -width 28 \
        -values [linsert [::ModelLoader::Logic::AveragingModes] 0 "<default>"] \
        -textvariable ::ModelLoader::UI::varAveraging]
    grid $lf.avg -row 3 -column 1 -sticky w -padx 2 -pady 2
    hwtk::label $lf.l3b -text "Layer:" -width 22 -anchor w
    grid $lf.l3b -row 3 -column 2 -sticky w -padx 2 -pady 2
    # V3 - VERIFY: '<default>' makes the adapter skip the layer call completely.
    set wLayer [hwtk::combobox $lf.layer -state readonly -width 28 \
        -values [::ModelLoader::Logic::LayerChoices] \
        -textvariable ::ModelLoader::UI::varLayer]
    grid $lf.layer -row 3 -column 3 -sticky w -padx 2 -pady 2

    # --- row 4 : options and buttons ----------------------------------------
    set wApplyAll [hwtk::checkbutton $lf.all \
        -text "Apply to all loaded windows (same subcase label)" \
        -variable ::ModelLoader::UI::varApplyAll]
    grid $lf.all -row 4 -column 0 -columnspan 3 -sticky w -padx 2 -pady 2
    hwtk::button $lf.reload -text "Reload lists" -command ::ModelLoader::UI::RefreshStep2
    grid $lf.reload -row 4 -column 3 -sticky e -padx 2 -pady 2

    # --- row 5 : hint --------------------------------------------------------
    hwtk::label $lf.hint -anchor w -justify left -wraplength 740 \
        -text "The result type list follows the selected subcase, the component list follows\
the selected result type.  Should this build not deliver the automatic update, press \
'Reload lists' after changing the subcase or the result type."
    grid $lf.hint -row 5 -column 0 -columnspan 4 -sticky w -padx 2 -pady 2

    # --- FIX 4 : legend from a file ------------------------------------------
    # A saved legend is a Tcl script of hwi calls, so 'Load legend' sources the
    # file (Adapter::LoadLegendFromFile) and then switches the legend on.  The
    # file is remembered per window (State::legendFileByWindow).
    set lfl [hwtk::labelframe $wStep2.legend -text " Legend " -padding 4]
    grid $lfl -row 1 -column 0 -sticky ew -pady 2 -padx 2
    grid columnconfigure $lfl 1 -weight 1

    hwtk::label $lfl.l0 -text "Legend file:" -width 22 -anchor w
    grid $lfl.l0 -row 0 -column 0 -sticky w -padx 2 -pady 2
    set legendTypes [::ModelLoader::Logic::LegendFileTypes]
    set wLegendFile [::ModelLoader::UI::CreateFileChooser $lfl legend \
        ::ModelLoader::UI::varLegendFile $legendTypes 44]
    grid $wLegendFile -row 0 -column 1 -sticky ew -padx 2 -pady 2
    hwtk::button $lfl.legendBrowse -text "Browse..." -command [list \
        ::ModelLoader::UI::BrowseFile $wLegendFile \
        ::ModelLoader::UI::varLegendFile $legendTypes legend]
    grid $lfl.legendBrowse -row 0 -column 2 -sticky w -padx 6 -pady 2
    hwtk::button $lfl.load -text "Load legend" -command ::ModelLoader::UI::OnLoadLegend
    grid $lfl.load -row 0 -column 3 -sticky w -padx 6 -pady 2

    hwtk::label $lfl.hint -anchor w -justify left -wraplength 740 \
        -text "A legend that was saved to a file is a Tcl script - it is sourced into the\
running HyperView session, then the legend of the selected window is switched on and the \
window is redrawn.  *.tcl (an exported legend), *.hvl and *.txt are offered; the legend \
belongs to the window that is selected above."
    grid $lfl.hint -row 1 -column 0 -columnspan 4 -sticky w -padx 2 -pady 2
    return
}

#=============================================================================
# SECTION 3e - STEP 3 WIDGETS (fix 5: view list, PNG folder, capture buttons)
#=============================================================================
# Optional view list, PNG output folder and the two capture buttons.  The scope
# is offered as a combobox AND as the two buttons - a button captures right away
# with the scope it names.
proc ::ModelLoader::UI::BuildStep3 {} {
    variable wStep3
    variable wViewListFile
    variable wViewListInfo
    variable wOutputDir
    variable wCaptureScope
    variable wTargetWin3

    grid columnconfigure $wStep3 0 -weight 1

    # --- view list ------------------------------------------------------------
    set lfv [hwtk::labelframe $wStep3.views -text " View list (optional) " -padding 4]
    grid $lfv -row 0 -column 0 -sticky ew -pady 2 -padx 2
    grid columnconfigure $lfv 1 -weight 1

    hwtk::label $lfv.l0 -text "View list file:" -width 22 -anchor w
    grid $lfv.l0 -row 0 -column 0 -sticky w -padx 2 -pady 2
    set viewTypes [::ModelLoader::Logic::ViewListFileTypes]
    set wViewListFile [::ModelLoader::UI::CreateFileChooser $lfv viewlist \
        ::ModelLoader::UI::varViewListFile $viewTypes 44]
    grid $wViewListFile -row 0 -column 1 -sticky ew -padx 2 -pady 2
    hwtk::button $lfv.browse -text "Browse..." -command [list \
        ::ModelLoader::UI::BrowseFile $wViewListFile \
        ::ModelLoader::UI::varViewListFile $viewTypes viewlist]
    grid $lfv.browse -row 0 -column 2 -sticky w -padx 6 -pady 2
    hwtk::button $lfv.import -text "Import views" -command ::ModelLoader::UI::OnImportViewList
    grid $lfv.import -row 0 -column 3 -sticky w -padx 6 -pady 2

    set wViewListInfo [hwtk::label $lfv.info -anchor w -justify left -wraplength 740 \
        -textvariable ::ModelLoader::UI::varViewListInfo]
    grid $lfv.info -row 1 -column 0 -columnspan 4 -sticky w -padx 2 -pady 2
    hwtk::label $lfv.hint -anchor w -justify left -wraplength 740 \
        -text "One view per line: 'name' (the name doubles as a view preset), 'name front'\
(or rear / iso / left / right / top / bottom) or 'name' followed by the 16 numbers of a \
view matrix - the format 'hvw' uses.  Blank lines and '#' / '//' / ';' comments are \
skipped.  Without a view list one PNG per window is written."
    grid $lfv.hint -row 2 -column 0 -columnspan 4 -sticky w -padx 2 -pady 2

    # --- PNG output folder ----------------------------------------------------
    set lfo [hwtk::labelframe $wStep3.output -text " PNG output " -padding 4]
    grid $lfo -row 1 -column 0 -sticky ew -pady 2 -padx 2
    grid columnconfigure $lfo 1 -weight 1
    hwtk::label $lfo.l0 -text "Output folder:" -width 22 -anchor w
    grid $lfo.l0 -row 0 -column 0 -sticky w -padx 2 -pady 2
    set wOutputDir [hwtk::entry $lfo.dir -width 44 \
        -textvariable ::ModelLoader::UI::varOutputDir]
    grid $wOutputDir -row 0 -column 1 -sticky ew -padx 2 -pady 2
    hwtk::button $lfo.browse -text "Choose folder..." \
        -command ::ModelLoader::UI::OnBrowseOutputDir
    grid $lfo.browse -row 0 -column 2 -sticky w -padx 6 -pady 2
    hwtk::label $lfo.hint -anchor w -justify left -wraplength 740 \
        -text "The folder is created when it does not exist.  The files are named\
'w<window>_<view>.png', so the capture of a whole page can never overwrite a file of \
another window.  (Plain Tk 'tk_chooseDirectory' is used for the folder browser - hwtk has \
no folder entry.)"
    grid $lfo.hint -row 1 -column 0 -columnspan 3 -sticky w -padx 2 -pady 2

    # --- capture --------------------------------------------------------------
    set lfc [hwtk::labelframe $wStep3.capture -text " Capture " -padding 4]
    grid $lfc -row 2 -column 0 -sticky ew -pady 2 -padx 2
    grid columnconfigure $lfc 1 -weight 1
    hwtk::label $lfc.l0 -text "Scope:" -width 22 -anchor w
    grid $lfc.l0 -row 0 -column 0 -sticky w -padx 2 -pady 2
    set wCaptureScope [hwtk::combobox $lfc.scope -state readonly -width 28 \
        -values [::ModelLoader::Logic::CaptureScopes] \
        -textvariable ::ModelLoader::UI::varCaptureScope]
    grid $lfc.scope -row 0 -column 1 -sticky w -padx 2 -pady 2
    set wTargetWin3 [hwtk::label $lfc.target -anchor w -justify left]
    grid $lfc.target -row 0 -column 2 -columnspan 2 -sticky w -padx 2 -pady 2

    hwtk::button $lfc.bTarget -text "Capture target" \
        -command [list ::ModelLoader::UI::OnCapture target]
    grid $lfc.bTarget -row 1 -column 1 -sticky w -padx 2 -pady 2
    hwtk::button $lfc.bAll -text "Capture all" \
        -command [list ::ModelLoader::UI::OnCapture all]
    grid $lfc.bAll -row 1 -column 2 -sticky w -padx 6 -pady 2

    hwtk::label $lfc.hint -anchor w -justify left -wraplength 740 \
        -text "'Capture target' captures the window of step 2 (default 1), 'Capture all'\
captures every window of the active page - both use the scope field above and the view \
list.  The contour plots of the windows should be applied in step 2 before a capture; \
each file is written for the view the window really shows."
    grid $lfc.hint -row 2 -column 0 -columnspan 4 -sticky w -padx 2 -pady 2
    return
}
#=============================================================================
# SECTION 3f - STEP 2 LOGIC (refresh, selection changes, spec assembly)
#=============================================================================
# Keeps the current value when it is still available, otherwise takes the first
# entry of <allowed>.  Returns the value that has to be used from now on.
proc ::ModelLoader::UI::KeepOrFirst {current allowed} {
    if {[llength $allowed] == 0} { return "" }
    if {[lsearch -exact $allowed $current] >= 0} { return $current }
    return [lindex $allowed 0]
}
# '<default>' means: leave the simulation of the window untouched.
proc ::ModelLoader::UI::SimulationIndexFromChoice {winIdx subcaseId choice} {
    if {$choice eq "<default>" || $choice eq ""} { return -1 }
    return [::ModelLoader::Logic::SimulationIndex $winIdx $subcaseId $choice]
}
# Reads the step 2 widgets into the spec dict that Logic::MakeSpec defines.
proc ::ModelLoader::UI::CurrentSpec {} {
    variable varTargetWin
    variable varSubcase
    variable varSimulation
    variable varDataType
    variable varComponent
    variable varAveraging
    variable varLayer
    set subcaseId [::ModelLoader::Logic::SubcaseIdFromLabel $varTargetWin $varSubcase]
    set simIndex  [::ModelLoader::UI::SimulationIndexFromChoice \
        $varTargetWin $subcaseId $varSimulation]
    return [::ModelLoader::Logic::MakeSpec $subcaseId $simIndex \
        $varDataType $varComponent $varAveraging $varLayer]
}
# One readable line per setting - used by the information pane and the log.
proc ::ModelLoader::UI::DescribeSpec {winIdx spec} {
    set subcaseId [dict get $spec subcaseId]
    set label     [::ModelLoader::Logic::SubcaseLabel $winIdx $subcaseId]
    set simIdx    [dict get $spec simulationIndex]
    if {$simIdx < 0} {
        set sim "<default>"
    } else {
        set sim [lindex [::ModelLoader::Logic::SimulationLabels $winIdx $subcaseId] $simIdx]
        if {$sim eq ""} { set sim "<index $simIdx>" }
    }
    return "window $winIdx : subcase '$subcaseId' ($label), simulation $sim, type\
'[dict get $spec dataType]', component '[dict get $spec component]', averaging \
'[dict get $spec averaging]', layer '[dict get $spec layer]'"
}
# Fills every step 2 combobox from the State layer.
proc ::ModelLoader::UI::RefreshStep2 {} {
    variable wTargetWin2
    variable wSubcase
    variable wSimulation
    variable varTargetWin
    variable varSubcase
    variable varSimulation
    variable varModelInfo

    # --- the windows that really hold a model -------------------------------
    set allowed [::ModelLoader::State::LoadedWindows]
    if {[llength $allowed] == 0} { set allowed [::ModelLoader::State::WindowIndices] }
    if {[llength $allowed] == 0} {
        set varModelInfo "no model loaded yet - go back to step 1"
        ::ModelLoader::UI::SetComboValues $wTargetWin2 {}
        ::ModelLoader::UI::SetComboValues $wSubcase {}
        ::ModelLoader::UI::SetComboValues $wSimulation {<default>}
        ::ModelLoader::UI::RefreshComponentLists
        ::ModelLoader::UI::ShowSpecPreview
        return
    }
    set varTargetWin [::ModelLoader::UI::KeepOrFirst $varTargetWin $allowed]
    ::ModelLoader::UI::SetComboValues $wTargetWin2 $allowed
    ::ModelLoader::UI::SetWidgetValue $wTargetWin2 $varTargetWin
    set varModelInfo "window $varTargetWin : [::ModelLoader::Logic::ModelName $varTargetWin]"

    # --- subcases -----------------------------------------------------------
    set scLabels [::ModelLoader::Logic::SubcaseLabels $varTargetWin]
    set varSubcase [::ModelLoader::UI::KeepOrFirst $varSubcase $scLabels]
    ::ModelLoader::UI::SetComboValues $wSubcase $scLabels
    ::ModelLoader::UI::SetWidgetValue $wSubcase $varSubcase

    # --- simulations --------------------------------------------------------
    set subcaseId [::ModelLoader::Logic::SubcaseIdFromLabel $varTargetWin $varSubcase]
    set simLabels [linsert [::ModelLoader::Logic::SimulationLabels $varTargetWin $subcaseId] \
        0 "<default>"]
    set varSimulation [::ModelLoader::UI::KeepOrFirst $varSimulation $simLabels]
    ::ModelLoader::UI::SetComboValues $wSimulation $simLabels
    ::ModelLoader::UI::SetWidgetValue $wSimulation $varSimulation

    # --- data types and components ------------------------------------------
    ::ModelLoader::UI::RefreshComponentLists
    ::ModelLoader::UI::ShowSpecPreview
    return
}
# Data types of the selected subcase, then the components of the selected type.
proc ::ModelLoader::UI::RefreshComponentLists {} {
    variable wDataType
    variable wComponent
    variable varTargetWin
    variable varSubcase
    variable varDataType
    variable varComponent

    set subcaseId [::ModelLoader::Logic::SubcaseIdFromLabel $varTargetWin $varSubcase]
    set dts [::ModelLoader::Logic::DataTypes $varTargetWin $subcaseId]
    set varDataType [::ModelLoader::UI::KeepOrFirst $varDataType $dts]
    ::ModelLoader::UI::SetComboValues $wDataType $dts
    ::ModelLoader::UI::SetWidgetValue $wDataType $varDataType

    set comps [::ModelLoader::Logic::Components $varTargetWin $subcaseId $varDataType]
    set varComponent [::ModelLoader::UI::KeepOrFirst $varComponent $comps]
    ::ModelLoader::UI::SetComboValues $wComponent $comps
    ::ModelLoader::UI::SetWidgetValue $wComponent $varComponent
    return
}



#=============================================================================
# SECTION 3g - PREVIEW, EVENTS AND THE STEP 1 ACTIONS
#=============================================================================
# Writes the current contour selection (and, when switched on, what 'apply to
# all windows' would do) into the information pane.
proc ::ModelLoader::UI::ShowSpecPreview {} {
    variable varApplyAll
    variable varTargetWin
    variable varSubcase

    set spec [::ModelLoader::UI::CurrentSpec]
    set lines {}
    lappend lines "CONTOUR SELECTION"
    if {[dict get $spec subcaseId] eq ""} {
        lappend lines "  no subcase selected - load a model in step 1 first"
        ::ModelLoader::UI::AppendInfo [list "" {*}$lines]
        return
    }
    if {[::ModelLoader::Logic::SpecIsComplete $spec]} {
        lappend lines "  ready : [::ModelLoader::UI::DescribeSpec $varTargetWin $spec]"
    } else {
        lappend lines "  incomplete : [::ModelLoader::UI::DescribeSpec $varTargetWin $spec]"
    }
    if {$varApplyAll} {
        set res [::ModelLoader::Logic::FanOutSpec $varSubcase $spec]
        lappend lines "  apply to all loaded windows : [llength [lindex $res 0]] match(es)"
        foreach job [lindex $res 0] {
            lappend lines "      window [lindex $job 0] : subcase '[dict get [lindex $job 1] subcaseId]'"
        }
        if {[llength [lindex $res 1]] > 0} {
            lappend lines "      no subcase with this label in window(s): [lindex $res 1]"
        }
    } else {
        lappend lines "  apply to window $varTargetWin only"
    }
    ::ModelLoader::UI::AppendInfo [list "" {*}$lines]
    return
}

# V9 - VERIFY: hwtk comboboxes are ttk based, therefore the virtual event
#      <<ComboboxSelected>> is generated when the user picks an entry.  If a
#      build does not generate it, the 'Reload lists' button of step 2 does
#      exactly the same job, so nothing is lost.
proc ::ModelLoader::UI::BindStep2 {} {
    variable wTargetWin2
    variable wSubcase
    variable wDataType
    catch { bind $wSubcase    <<ComboboxSelected>> { ::ModelLoader::UI::OnSubcaseChanged } }
    catch { bind $wDataType   <<ComboboxSelected>> { ::ModelLoader::UI::OnDataTypeChanged } }
    catch { bind $wTargetWin2 <<ComboboxSelected>> { ::ModelLoader::UI::RefreshStep2 } }
    return
}
proc ::ModelLoader::UI::OnSubcaseChanged {} {
    variable varSubcase
    variable wSubcase
    catch { set varSubcase [$wSubcase get] }
    # a new subcase brings new result types, so everything below is refilled
    ::ModelLoader::UI::RefreshStep2
    return
}
proc ::ModelLoader::UI::OnDataTypeChanged {} {
    variable varDataType
    variable wDataType
    catch { set varDataType [$wDataType get] }
    ::ModelLoader::UI::RefreshComponentLists
    ::ModelLoader::UI::ShowSpecPreview
    return
}

#=============================================================================
# SECTION 3h - STEP 2 LEGEND + STEP 3 CAPTURE ACTIONS (fix 4 + fix 5)
#=============================================================================
# V9 - VERIFY: hwtk comboboxes generate <<ComboboxSelected>>; the two capture
# buttons do not depend on it at all, they write the scope themselves.
proc ::ModelLoader::UI::BindStep3 {} {
    variable wCaptureScope
    catch { bind $wCaptureScope <<ComboboxSelected>> { ::ModelLoader::UI::RefreshStep3 } }
    return
}
# Shows the step 3 state: scope, target window, the imported view list and the
# plan (how many PNG files a capture would write).  Writes it into the
# information pane below.
proc ::ModelLoader::UI::RefreshStep3 {} {
    variable varTargetWin
    variable varOutputDir
    variable varCaptureScope
    variable varViewListInfo
    variable wCaptureScope
    variable wTargetWin3

    # --- scope ---------------------------------------------------------------
    set scope $varCaptureScope
    if {[lsearch -exact [::ModelLoader::Logic::CaptureScopes] $scope] < 0} {
        set scope "target"
        set varCaptureScope $scope
    }
    ::ModelLoader::UI::SetComboValues $wCaptureScope [::ModelLoader::Logic::CaptureScopes]
    ::ModelLoader::UI::SetWidgetValue $wCaptureScope $scope
    if {$wTargetWin3 ne "" && [winfo exists $wTargetWin3]} {
        catch { $wTargetWin3 configure -text "target window: $varTargetWin" }
    }

    # --- output folder (default is a suggestion, nothing is written here) -----
    set stored [::ModelLoader::State::GetOutputDir]
    if {$stored ne "" && [string trim $varOutputDir] eq ""} { set varOutputDir $stored }
    if {[string trim $varOutputDir] eq ""} {
        set varOutputDir [file join [pwd] hv_capture]
    }

    # --- view list -----------------------------------------------------------
    set entries [::ModelLoader::State::GetViewList]
    if {[llength $entries] == 0} {
        set varViewListInfo "no view list imported - one PNG per window"
    } else {
        set names {}
        foreach e $entries { lappend names [dict get $e name] }
        set varViewListInfo "[llength $entries] view(s): [join $names {, }]"
    }

    # --- plan ----------------------------------------------------------------
    set lines {}
    lappend lines "" "PNG CAPTURE (step 3)" \
        "  scope         : $scope (target = window $varTargetWin, all = every window of the page)" \
        "  view list     : $varViewListInfo"
    if {[llength $entries] > 0} {
        foreach e $entries {
            set how "name only - no orientation"
            if {[dict get $e matrix] ne ""} {
                set how "view matrix ([llength [dict get $e matrix]] numbers)"
            } elseif {[dict get $e orientation] ne ""} {
                set how "orientation '[dict get $e orientation]'"
            }
            lappend lines "      [dict get $e name] : $how"
        }
    }
    lappend lines "  output folder : $varOutputDir"
    set check [::ModelLoader::Logic::CheckOutputDir $varOutputDir]
    if {![dict get $check ok]} {
        lappend lines "  not ready     : [dict get $check message]"
    } else {
        set dir [dict get $check path]
        set indices [::ModelLoader::State::WindowIndices]
        if {[llength $indices] == 0} { set indices [list $varTargetWin] }
        set jobs [::ModelLoader::Logic::CapturePlan $scope $varTargetWin \
            $entries $indices $dir]
        lappend lines "  files         : [llength $jobs] PNG file(s) would be written"
        foreach job [lrange $jobs 0 2] {
            lappend lines "      [::ModelLoader::Logic::DescribeJob $job]"
        }
        if {[llength $jobs] > 3} {
            lappend lines "      ... ([expr {[llength $jobs] - 3}] more)"
        }
    }
    ::ModelLoader::UI::AppendInfo $lines
    return
}
#--------------------------------- fix 5 : view list import -------------------
# Reads and parses the view list file, keeps the parsed entries in the State
# layer and shows what was understood.  Called by the 'Import views' button and
# by 'Capture ...' when a file is set but was not imported yet.
proc ::ModelLoader::UI::OnImportViewList {} {
    variable wViewListFile
    variable varViewListFile
    variable varViewListInfo

    set path [string trim [::ModelLoader::UI::WidgetText $wViewListFile $varViewListFile]]
    if {$path eq ""} { set path [string trim $varViewListFile] }
    if {$path eq ""} {
        ::ModelLoader::State::SetViewList {}
        set varViewListInfo "no view list imported - one PNG per window"
        ::ModelLoader::UI::SetStatus "No view list file was chosen - one PNG per window."
        ::ModelLoader::UI::RefreshStep3
        return ""
    }
    set res [::ModelLoader::Logic::ViewListFromFile $path]
    if {![dict get $res ok]} {
        ::ModelLoader::State::SetViewList {}
        set varViewListInfo "no view list imported - one PNG per window"
        ::ModelLoader::UI::SetStatus "View list rejected: [dict get $res message]"
        ::ModelLoader::UI::AppendInfo [list "" "VIEW LIST" \
            "  [::ModelLoader::Logic::Basename $path] was rejected:\
[dict get $res message]"]
        catch { tk_messageBox -title "Model Loader" -icon warning \
            -message "View list rejected: [dict get $res message]" \
            -parent .modelLoaderGUI }
        ::ModelLoader::UI::RefreshStep3
        return ""
    }

    set entries [dict get $res entries]
    set file    [string trim $path]
    catch { set file [file normalize $file] }
    ::ModelLoader::State::SetViewList $entries $file
    ::ModelLoader::UI::SetFileWidget $wViewListFile \
        ::ModelLoader::UI::varViewListFile $file
    set names {}
    foreach e $entries { lappend names [dict get $e name] }
    set varViewListInfo "[llength $entries] view(s): [join $names {, }]"
    if {[dict get $res message] ne ""} {
        ::ModelLoader::UI::SetStatus "View list imported from\
[::ModelLoader::Logic::Basename $file]: [dict get $res message]."
    } else {
        ::ModelLoader::UI::SetStatus "View list imported: [llength $entries] view(s) from\
[::ModelLoader::Logic::Basename $file]."
    }
    ::ModelLoader::UI::AppendInfo [list "" "VIEW LIST" \
        "  file  : $file" \
        "  views : [join $names {, }]"]
    foreach e $entries {
        set how "name only - no orientation"
        if {[dict get $e matrix] ne ""} {
            set how "matrix ([dict get $e matrix])"
        } elseif {[dict get $e orientation] ne ""} {
            set how "orientation [dict get $e orientation]"
        }
        ::ModelLoader::UI::AppendInfo [list "      [dict get $e name] : $how"]
    }
    ::ModelLoader::UI::RefreshStep3
    return $file
}
#--------------------------------- fix 5 : PNG output folder ------------------
# Writes a folder into the State layer and the entry widget.  Returns the
# normalised folder, or "" when it was refused.
proc ::ModelLoader::UI::SetOutputDirValue {dir} {
    variable varOutputDir
    variable wOutputDir
    set check [::ModelLoader::Logic::CheckOutputDir $dir]
    if {![dict get $check ok]} {
        ::ModelLoader::UI::SetStatus "Output folder rejected: [dict get $check message]"
        return ""
    }
    set varOutputDir [dict get $check path]
    ::ModelLoader::State::SetOutputDir $varOutputDir
    ::ModelLoader::UI::SetFileWidget $wOutputDir \
        ::ModelLoader::UI::varOutputDir $varOutputDir
    return $varOutputDir
}
# PLAIN TK: tk_chooseDirectory - hwtk has no folder entry widget.  An empty
# result (the user cancelled) changes nothing.
proc ::ModelLoader::UI::OnBrowseOutputDir {} {
    variable varOutputDir
    set start [string trim $varOutputDir]
    if {$start eq "" || ![file isdirectory $start]} { set start [pwd] }
    if {[catch {
        set dir [tk_chooseDirectory -title "Choose the PNG output folder" \
            -initialdir $start -mustexist 0]
    } msg]} {
        ::ModelLoader::UI::SetStatus "The folder browser could not be opened: $msg"
        return ""
    }
    if {$dir eq ""} { return "" }
    set out [::ModelLoader::UI::SetOutputDirValue $dir]
    if {$out ne ""} {
        ::ModelLoader::UI::SetStatus "PNG output folder: $out"
        ::ModelLoader::UI::RefreshStep3
    }
    return $out
}
#--------------------------------- fix 4 : load a legend from a file ----------
proc ::ModelLoader::UI::OnLoadLegend {} {
    variable varTargetWin
    variable varLegendFile
    variable wLegendFile

    set path [string trim [::ModelLoader::UI::WidgetText $wLegendFile $varLegendFile]]
    if {$path eq ""} { set path [string trim $varLegendFile] }
    if {$path eq ""} {
        ::ModelLoader::UI::SetStatus "Choose a legend file first."
        return ""
    }
    ::ModelLoader::UI::SetStatus "Loading the legend from\
[::ModelLoader::Logic::Basename $path] into window $varTargetWin ..."
    catch { update idletasks }
    set res [::ModelLoader::Adapter::LoadLegendFromFile $varTargetWin $path]
    ::ModelLoader::UI::AppendInfo [list "" "LEGEND (step 2)"]
    if {![dict get $res ok]} {
        ::ModelLoader::UI::SetStatus "Legend: [dict get $res message]"
        ::ModelLoader::UI::AppendInfo [list \
            "  window $varTargetWin : FAILED - [dict get $res message]"]
        catch { tk_messageBox -title "Model Loader" -icon warning \
            -message "Legend: [dict get $res message]" -parent .modelLoaderGUI }
        return ""
    }
    set file [dict get $res file]
    ::ModelLoader::State::SetLegendFile $varTargetWin $file
    ::ModelLoader::UI::SetFileWidget $wLegendFile \
        ::ModelLoader::UI::varLegendFile $file
    ::ModelLoader::UI::AppendInfo [list \
        "  window $varTargetWin : OK - [dict get $res message]"]
    foreach warning [dict get $res warnings] {
        ::ModelLoader::UI::AppendInfo [list "      warning: $warning"]
    }
    ::ModelLoader::UI::SetStatus "[dict get $res message] (window $varTargetWin)"
    return $file
}
#--------------------------------- fix 5 : capture ----------------------------
# <scope> is 'target' or 'all' - it comes from the button that was pressed, so
# the two buttons can never disagree with the scope field.
proc ::ModelLoader::UI::OnCapture {scope} {
    variable varTargetWin
    variable varOutputDir
    variable varCaptureScope
    variable varViewListFile
    variable wViewListFile

    set varCaptureScope $scope
    # a view list file that is set but was never imported is imported now
    if {[llength [::ModelLoader::State::GetViewList]] == 0} {
        set typed [string trim [::ModelLoader::UI::WidgetText $wViewListFile \
            $varViewListFile]]
        if {$typed ne ""} { ::ModelLoader::UI::OnImportViewList }
    }
    set dir [::ModelLoader::UI::SetOutputDirValue $varOutputDir]
    if {$dir eq ""} {
        ::ModelLoader::UI::RefreshStep3
        catch { tk_messageBox -title "Model Loader" -icon warning \
            -message "Choose the PNG output folder first (step 3)." \
            -parent .modelLoaderGUI }
        return
    }
    if {[catch { ::ModelLoader::Logic::ValidateStep3 $scope $varTargetWin $dir } msg]} {
        ::ModelLoader::UI::SetStatus $msg
        ::ModelLoader::UI::RefreshStep3
        catch { tk_messageBox -title "Model Loader" -icon warning -message $msg \
            -parent .modelLoaderGUI }
        return
    }

    set entries [::ModelLoader::State::GetViewList]
    ::ModelLoader::UI::SetStatus "Capturing PNG files ($scope) - please wait ..."
    catch { update idletasks }
    set res [::ModelLoader::Adapter::CapturePng $scope $varTargetWin $entries $dir]

    ::ModelLoader::UI::AppendInfo [list "" "PNG CAPTURE (step 3)"]
    if {[dict get $res ok]} {
        ::ModelLoader::UI::AppendInfo [list \
            "  [dict get $res captured] file(s) written to $dir"]
        foreach file [dict get $res files] {
            ::ModelLoader::UI::AppendInfo [list \
                "      OK   [::ModelLoader::Logic::Basename $file]"]
        }
    } else {
        ::ModelLoader::UI::AppendInfo [list "  FAILED - [dict get $res message]"]
    }
    foreach warning [dict get $res warnings] {
        ::ModelLoader::UI::AppendInfo [list "      warning: $warning"]
    }
    if {[dict get $res mode] ne ""} {
        ::ModelLoader::UI::AppendInfo [list \
            "  capture form : [dict get $res mode] (remembered for the next run)"]
    }
    ::ModelLoader::UI::SetStatus [dict get $res message]
    ::ModelLoader::UI::RefreshStep3
    return
}
#--------------------------------- step 1 actions -----------------------------
proc ::ModelLoader::UI::OnApplyLayout {} {
    # BUG FIX 1: the number is taken from the WIDGET first (see
    # UI::ReadWindowCount) and the result of the layout change is read back from
    # HyperView - the field must never show something the page does not have.
    # Before the fix Adapter::QueryPage counted the windows with 'llength', which
    # turned the numeric answer of 'page GetNumberOfWindows' (e.g. "4", compare
    # _tmp_hv/batchImportOdb.tcl) into 1 - so every layout change seemed to end
    # with a single window and the wizard tried token after token.
    set wanted [::ModelLoader::UI::ReadWindowCount]
    if {$wanted eq ""} {
        set raw [string trim [::ModelLoader::UI::WidgetText \
            [set ::ModelLoader::UI::wWindowCount] $::ModelLoader::UI::varWindowCount]]
        ::ModelLoader::UI::SetStatus \
            "Layout: '$raw' is not a valid number of windows - kept $::ModelLoader::UI::lastGoodWindowCount."
        ::ModelLoader::UI::SetWindowCountValue $::ModelLoader::UI::lastGoodWindowCount
        return
    }
    # keep what the user picked, even while the layout is being applied
    ::ModelLoader::UI::SetWindowCountValue $wanted
    ::ModelLoader::UI::SetStatus "Applying a $wanted window layout to the active page ..."
    catch { update idletasks }
    set res [::ModelLoader::Adapter::SetWindowCount $wanted]
    if {![dict get $res ok]} {
        # the request was refused: the user's number is NOT thrown away, it stays
        # in the field so it can be retried after the layout was fixed by hand
        ::ModelLoader::UI::SetWindowCountValue $wanted
        ::ModelLoader::UI::SetStatus \
            "Layout '$wanted' was refused - the value stays in the field: [dict get $res message]"
        ::ModelLoader::UI::RefreshWindowList
        ::ModelLoader::UI::AppendInfo [list "" "LAYOUT" \
            "  $wanted window(s) requested - refused: [dict get $res message]"]
        return
    }
    if {[dict get $res unchanged]} {
        ::ModelLoader::UI::SetStatus "The active page already shows $wanted window(s)."
    } else {
        ::ModelLoader::UI::SetStatus "Layout applied: $wanted window(s), token '[dict get $res layout]'."
    }
    # BUG FIX 1: write back what HyperView really has now (InterpretWindowCount
    # keeps 'windows' a plain number - a scalar '4' or the list '1 2 3 4' both
    # end up as 4) and touch '-values' only when the number is not offered yet.
    set real [::ModelLoader::Logic::InterpretWindowCount [dict get $res windows]]
    if {$real < 1} { set real $wanted }
    ::ModelLoader::UI::SetWindowCountValue $real
    # windows that do not exist any more lose their recorded state
    ::ModelLoader::State::PruneTo $real
    ::ModelLoader::UI::RefreshWindowList
    # RefreshWindowList rebuilds the target-window list, so the applied count is
    # written into the window-count field once more - this is the LAST write of
    # a layout action, nothing may reset it to 1 afterwards.
    ::ModelLoader::UI::SetWindowCountValue $real
    return
}
proc ::ModelLoader::UI::OnLearnLayouts {} {
    # FIX 3: the 'Learn layouts' button.  The probe asks HyperView which layout
    # token belongs to which window count and caches every answer, so 'Apply
    # layout' stops guessing.  A page that cannot be read is REPORTED - the
    # handler never throws (Adapter::LearnLayouts catches everything).
    ::ModelLoader::UI::SetStatus "Probing the layout tokens of the active page ..."
    catch { update idletasks }
    set res [::ModelLoader::Adapter::LearnLayouts]
    if {![dict get $res ok]} {
        set msg [dict get $res message]
        ::ModelLoader::UI::SetStatus "Learn layouts: $msg"
        # RefreshWindowList REPLACES the whole pane (SetInfo), so it has to run
        # BEFORE the report is appended - the other way round the report of the
        # probe would be wiped the same instant.
        ::ModelLoader::UI::RefreshWindowList
        ::ModelLoader::UI::AppendInfo [list "" "LAYOUT TOKENS" \
            "  the probe did not run: $msg"]
        return 0
    }
    set learned [dict get $res learned]
    set lines [list "" "LAYOUT TOKENS (learned by the probe)"]
    if {[dict size $learned] == 0} {
        lappend lines "  no token was learned from this page"
    } else {
        foreach c [lsort -integer [dict keys $learned]] {
            lappend lines "  [format %2d $c] window(s) -> token '[dict get $learned $c]'"
        }
    }
    foreach line [split [dict get $res message] "\n"] {
        if {$line ne ""} { lappend lines "  $line" }
    }
    ::ModelLoader::UI::SetStatus "Learn layouts: [dict size $learned] token(s)\
 known, the page shows [dict get $res restored] window(s)."
    ::ModelLoader::UI::RefreshWindowList
    ::ModelLoader::UI::AppendInfo $lines
    return 1
}
proc ::ModelLoader::UI::OnRefreshPage {} {
    ::ModelLoader::UI::SetStatus "Reading the active page ..."
    catch { update idletasks }
    set info [::ModelLoader::UI::RefreshWindowList]
    if {[llength $info] == 0} {
        ::ModelLoader::UI::SetStatus "The active page could not be read:\
[::ModelLoader::State::GetLastError]"
    } else {
        ::ModelLoader::UI::SetStatus "Active page [dict get $info page] :\
[dict get $info windows] window(s), layout token '[dict get $info layout]'."
    }
    return
}

proc ::ModelLoader::UI::OnLoadModel {} {
    variable varModelFile
    variable varResultFile
    variable varFile
    variable varTargetWin

    # 1. read what the user (or a browser) put into the two fields ------------
    set winIdx [::ModelLoader::UI::OnTargetWindowChanged]
    if {![string is integer -strict $winIdx] || $winIdx < 1} {
        ::ModelLoader::UI::SetStatus "Step 1: 'Target window' is not a window number."
        return
    }
    set modelPath  [string trim $varModelFile]
    set resultPath [string trim $varResultFile]
    # backwards compatible: an old single field still works
    if {$modelPath eq "" && $resultPath eq "" && [string trim $varFile] ne ""} {
        set maybe [string trim $varFile]
        if {[lsearch -exact [::ModelLoader::Logic::ResultExtensions] \
                [string tolower [file extension $maybe]]] >= 0} {
            set resultPath $maybe
        } else {
            set modelPath $maybe
        }
    }
    if {$modelPath eq "" && $resultPath eq ""} {
        set msg "Step 1: choose an 'Input Model' and/or an 'Input Result' file first."
        ::ModelLoader::UI::SetStatus $msg
        catch { tk_messageBox -title "Model Loader" -icon warning -message $msg \
            -parent .modelLoaderGUI }
        return
    }

    # 2. post-process both paths (normalise, existence, extension warning) ----
    set notes {}
    foreach {kind path widget varname} [list \
            model  $modelPath  $::ModelLoader::UI::wModelFile  ::ModelLoader::UI::varModelFile \
            result $resultPath $::ModelLoader::UI::wResultFile ::ModelLoader::UI::varResultFile] {
        if {[string trim $path] eq ""} { continue }
        set check [::ModelLoader::Logic::CheckChosenFile $path $kind]
        set norm  [dict get $check path]
        if {$norm eq ""} { set norm [string trim $path] }
        ::ModelLoader::UI::SetFileWidget $widget $varname $norm
        if {$kind eq "model"} { set modelPath $norm } else { set resultPath $norm }
        if {![dict get $check ok]} {
            set msg "Step 1: [dict get $check message]"
            ::ModelLoader::UI::SetStatus $msg
            catch { tk_messageBox -title "Model Loader" -icon warning -message $msg \
                -parent .modelLoaderGUI }
            return
        }
        if {[dict get $check message] ne ""} { lappend notes [dict get $check message] }
    }
    set varFile [expr {$modelPath ne "" ? $modelPath : $resultPath}]

    # 3. load model and/or result into the selected window --------------------
    # FIX 2: no reader is passed any more - 'AddModel <file>' detects it (V5).
    ::ModelLoader::UI::SetStatus "Loading into window $winIdx ..."
    catch { update idletasks }
    set res [::ModelLoader::Adapter::LoadAllAndRefresh $winIdx $modelPath $resultPath]
    # the page/window tree is rebuilt FIRST and the report of this action is
    # appended afterwards: RefreshWindowList replaces the WHOLE pane (SetInfo),
    # so an earlier AppendInfo would be wiped the same instant
    ::ModelLoader::UI::RefreshWindowList
    if {![dict get $res ok]} {
        ::ModelLoader::UI::AppendInfo [list "" "LOAD INTO WINDOW $winIdx" \
            "  model  : [expr {$modelPath  eq "" ? {<none>} : $modelPath}]" \
            "  result : [expr {$resultPath eq "" ? {<none>} : $resultPath}]" \
            "  FAILED : [dict get $res message]" \
            "  hint   : check that the file is readable and that its format is\
supported - the reader is detected automatically from the file"]
        ::ModelLoader::UI::SetStatus "Loading failed: [dict get $res message]"
    } else {
        set lines [list "" "LOAD INTO WINDOW $winIdx" \
            "  model   : [expr {$modelPath  eq "" ? {<none>} : $modelPath}]" \
            "  result  : [expr {$resultPath eq "" ? {<none>} : $resultPath}]" \
            "  reader  : auto detected from the file (no reader entry needed)" \
            "  mode    : [dict get $res mode]   models/further files: [dict get $res models]\
[dict get $res files]"\
            "  subcase : [llength [dict get $res subcases]]" \
            "  state   : stored, see the result tree above"]
        foreach note $notes { lappend lines "  note    : $note" }
        foreach warn [dict get $res warnings] { lappend lines "  warning : $warn" }
        ::ModelLoader::UI::AppendInfo $lines
        set status "Loaded into window $winIdx : [llength [dict get $res subcases]] subcase(s) found."
        if {[llength [dict get $res warnings]] > 0} {
            append status " ([llength [dict get $res warnings]] warning(s), see the pane)"
        }
        ::ModelLoader::UI::SetStatus $status
    }
    return
}
proc ::ModelLoader::UI::OnRefreshWindow {} {
    variable varTargetWin
    if {![string is integer -strict $varTargetWin]} { return }
    set winIdx $varTargetWin
    ::ModelLoader::UI::SetStatus "Re-reading the results of window $winIdx ..."
    catch { update idletasks }
    set res [::ModelLoader::Adapter::RefreshWindowResults $winIdx]
    # same order as in OnLoadModel: refresh the tree first, report afterwards
    ::ModelLoader::UI::RefreshWindowList
    if {![dict get $res ok]} {
        ::ModelLoader::UI::AppendInfo [list "" "RE-READ WINDOW $winIdx" \
            "  FAILED : [dict get $res message]"]
        ::ModelLoader::UI::SetStatus "Window $winIdx could not be read: [dict get $res message]"
    } else {
        ::ModelLoader::UI::AppendInfo [list "" "RE-READ WINDOW $winIdx" \
            "  models   : [dict get $res models]  files: [dict get $res files]" \
            "  subcases : [llength [dict get $res subcases]]"]
        ::ModelLoader::UI::SetStatus "Window $winIdx re-read:\
[llength [dict get $res subcases]] subcase(s)."
    }
    return
}

#--------------------------------- step 2 action (apply the contour) ----------
proc ::ModelLoader::UI::OnApply {} {
    variable varTargetWin
    variable varSubcase
    variable varApplyAll

    set spec [::ModelLoader::UI::CurrentSpec]
    if {[catch { ::ModelLoader::Logic::ValidateStep2 $varTargetWin $spec } msg]} {
        ::ModelLoader::UI::SetStatus $msg
        catch { tk_messageBox -title "Model Loader" -icon warning -message $msg \
            -parent .modelLoaderGUI }
        return
    }

    set jobs      [list [list $varTargetWin $spec]]
    set unmatched {}
    if {$varApplyAll} {
        set fanOut    [::ModelLoader::Logic::FanOutSpec $varSubcase $spec]
        set jobs      [lindex $fanOut 0]
        set unmatched [lindex $fanOut 1]
    }

    ::ModelLoader::UI::AppendInfo [list "" "APPLY CONTOUR"]
    if {[llength $unmatched] > 0} {
        ::ModelLoader::UI::AppendInfo [list \
            "  skipped window(s) $unmatched - no subcase labelled '$varSubcase'"]
    }
    set okCount   0
    set failCount 0
    foreach job $jobs {
        set idx   [lindex $job 0]
        set jspec [lindex $job 1]
        ::ModelLoader::UI::SetStatus "Applying the contour in window $idx ..."
        catch { update idletasks }
        set res [::ModelLoader::Adapter::ApplyContour $idx $jspec]
        if {[dict get $res ok]} {
            incr okCount
            ::ModelLoader::UI::AppendInfo [list "  OK   [::ModelLoader::UI::DescribeSpec $idx $jspec]"]
        } else {
            incr failCount
            ::ModelLoader::UI::AppendInfo [list \
                "  FAIL [::ModelLoader::UI::DescribeSpec $idx $jspec]" \
                "       [dict get $res message]"]
        }
        foreach warning [dict get $res warnings] {
            ::ModelLoader::UI::AppendInfo [list "       warning: $warning"]
        }
    }
    ::ModelLoader::UI::SetStatus "Contour applied in $okCount window(s), $failCount failure(s)."
    return
}



#=============================================================================
# SECTION 4 - PUBLIC ENTRY POINT
#=============================================================================
# Starts the wizard.  From the HyperView command line:
#     source "hv_model_loader.tcl"
#     ::ModelLoader::Show        (or the short alias  mlShow )
# Everything the wizard needs is contained in this one file; no other file and
# no other package is required besides the HyperWorks Tk library (hwtk).
proc ::ModelLoader::Show {} {
    if {[catch { ::ModelLoader::Bootstrap } msg]} {
        catch { puts "\n\[ModelLoader\] $msg\n" }
        catch { tk_messageBox -title "Model Loader" -icon error -message $msg }
        return ""
    }
    ::ModelLoader::UI::Build
    ::ModelLoader::UI::Post
    ::ModelLoader::UI::SetStatus \
        "Step 1: set the page layout, then load a model into the selected window."
    return .modelLoaderGUI
}
# Short alias for the HyperView command line or a toolbar button.
proc ::mlShow {} { return [::ModelLoader::Show] }
