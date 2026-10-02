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
#     <session>  GetProjectHandle
#     <project>  GetPageHandle, GetActivePage, GetNumberOfPages, AddPage
#     <page>     GetWindowHandle, GetNumberOfWindows, GetActiveWindow,
#                GetLayout, SetLayout
#     <window>   GetClientHandle
#     <client>   Draw, GetActiveModel, GetModelHandle, GetModelList,
#                AddModel, RemoveAllModels, SetDisplayOptions
#     <model>    GetFileName, GetResultCtrlHandle, AddResultFile (V10)
#     <result>   GetSubcaseList, GetSubcaseLabel, GetCurrentSubcase,
#                SetCurrentSubcase, GetSimulationList, GetCurrentSimulation,
#                SetCurrentSimulation, GetNumberOfSimulations, GetDataTypeList,
#                GetDataComponentList, GetContourCtrlHandle
#     <contour>  SetDataType, SetDataComponent, SetAverageMode, SetEnableState,
#                GetLegendHandle
#     <legend>   SetType
#     every handle: ReleaseHandle
#
#  --- hwtk / hwt commands used ----------------------------------------------
#     hwtk::dialog, hwtk::frame, hwtk::labelframe, hwtk::label, hwtk::button,
#     hwtk::entry, hwtk::openfileentry, hwtk::combobox, hwtk::checkbutton
#     <dialog> recess / insert apply / buttonconfigure / hide / post
#     plain Tk : listbox + scrollbar (read-only information pane),
#                tk_getOpenFile (the 'Browse...' buttons of the two file fields,
#                with the same -filetypes list the fields offer) and
#                tk_messageBox for the modal warnings
#
#  --- "# VERIFY:" list (see README.md for the detail) -----------------------
#     V1  <page> SetLayout <token>          token spelling is installation
#                                          specific -> auto discovery is used
#     V2  <contour> SetAverageMode <mode>   exact mode strings
#     V3  <contour> SetLayer <layer>        command presence in 2022
#     V4  <contour> GetLegendHandle + <legend> SetType dynamic
#     V5  <client> AddModel <file> <reader> reader labels
#     V6  <result> GetDataComponentList <subcaseId> <dataType>
#     V7  hwtk::dialog modality (-modal)
#     V8  hwtk::combobox configure -values (dynamic re-population)
#     V9  hwtk combobox <<ComboboxSelected>> virtual event
#     V10 - VERIFY: attaching a RESULT file to a model that is already in the
#         window (<client> AddModel <resultFile> first, <model> AddResultFile
#         second); a refusal is a warning, never a failed load
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
        puts "\[ModelLoader\] NOTE: hwtk::openfileentry is not available - \
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
    #   reader      <optional reader label passed to AddModel for 'file'>
    #   modelReader <reader label used for modelFile>          (V5)
    #   resultReader<reader label used for resultFile>         (V5)
    #   name        <file tail, for display>
    #   loaded      <0|1>
    #   subcases    <list of {subcaseId subcaseLabel}>
    #   simulations <dict subcaseId -> {simulationLabel ...}>
    #   datatypes   <dict subcaseId -> {dataType ...}>
    #   components  <dict subcaseId -> <dict dataType -> {component ...}>>
    variable windows {}
    # Discovered page layout tokens: dict windowCount -> layout token   (V1)
    variable layoutTokenByCount {}
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
        page {} file {} reader {} name {} loaded 0
        modelFile {} modelReader {} resultFile {} resultReader {}
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
proc ::ModelLoader::State::SetLayoutToken {count token} {
    variable layoutTokenByCount
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
proc ::ModelLoader::State::ResetAll {} {
    variable windows
    variable lastError
    variable statusText
    set windows {}
    set lastError ""
    set statusText ""
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
proc ::ModelLoader::Logic::LayoutCandidates {count} {
    set cand {}
    set cached [::ModelLoader::State::GetLayoutToken $count]
    if {$cached ne ""} { lappend cand $cached }
    for {set r 1} {$r <= $count} {incr r} {
        if {$count % $r} { continue }
        set c [expr {$count / $r}]
        lappend cand "${r}x${c}" "${c}x${r}" "${r} X ${c}" "${c} X ${r}"
        lappend cand "${r} x ${c}" "${c} x ${r}"
    }
    lappend cand $count
    lappend cand "single" "2H" "2V" "3H" "3V"
    return [lsort -unique $cand]
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
# Reader label SUGGESTION for the info pane - never applied automatically,
# because the exact label is installation specific (see V5).
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
                        {set winCount [llength [mlPage GetNumberOfWindows]]}
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
                            {set actual [llength [mlPage GetNumberOfWindows]]}]} { continue }
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

#--------------------------------------------------------------- load model ---
# Loads <path> into window <winIdx> of the ACTIVE page.
# <reader> may be empty (HyperView auto-detects the reader) or a reader label.
# V5 - VERIFY: 'client AddModel <file>' (auto reader) and
#      'client AddModel <file> <readerLabel>' are both used by real HyperView
#      scripts; the correct label for a given format depends on the
#      installation (example: "NASTRAN Model Input Reader").
# Returns 1 on success, 0 on failure (State::lastError holds the reason).
proc ::ModelLoader::Adapter::LoadModel {winIdx path reader} {
    ::ModelLoader::State::ClearLastError
    if {![file exists $path]} {
        ::ModelLoader::State::SetLastError "File not found: $path"
        return 0
    }
    set pageIdx ""
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
                            if {$reader eq ""} {
                                set ok [::ModelLoader::Adapter::HvRun "AddModel (auto reader)" \
                                    [list mlClient AddModel $path]]
                            } else {
                                set ok [::ModelLoader::Adapter::HvRun "AddModel '$reader'" \
                                    [list mlClient AddModel $path $reader]]
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
            page $pageIdx file $path reader $reader name [file tail $path] loaded 1 \
            modelFile $path modelReader $reader
    }
    return $ok
}

#----------------------------------------------------------- attach a result ---
# Attaches <resultPath> to the model that is currently in the window.
# Has to be called while the stack is OPEN, because <clientVar> is the live
# client handle of the caller's frame (hence the upvar).
# V10 - VERIFY: two forms are tried, the first one that is accepted wins:
#   1. <client> AddModel <resultFile> [<reader>]  - HyperView attaches the
#      results to the existing model when the readers are compatible; this is
#      how Altair's own examples load a model and a result file together.
#   2. <model> AddResultFile <resultFile>         - explicit attach form.
# A refusal is NOT fatal: the model stays loaded and the reason is appended to
# <warningsVar>, so the caller prints a hint instead of failing the whole load.
# Returns 1 when the result file was handed to HyperView, 0 otherwise.
proc ::ModelLoader::Adapter::AttachResult {clientVar warningsVar resultPath reader} {
    upvar 1 $clientVar mlClient
    upvar 1 $warningsVar warnings
    set label [::ModelLoader::Logic::Basename $resultPath]

    if {$reader eq ""} {
        set cmd  [list mlClient AddModel $resultPath]
        set desc "AddModel <result> (auto reader)"
    } else {
        set cmd  [list mlClient AddModel $resultPath $reader]
        set desc "AddModel <result> '$reader'"
    }
    if {[::ModelLoader::Adapter::HvRun $desc $cmd]} { return 1 }
    set why [::ModelLoader::State::GetLastError]

    # second chance: attach through the active model handle
    set attached 0
    ::ModelLoader::Adapter::HvRun "GetActiveModel" \
        {set mlResModelId [mlClient GetActiveModel]}
    if {[info exists mlResModelId] && $mlResModelId ne "" && $mlResModelId ne "0"} {
        if {[::ModelLoader::Adapter::HvRun "GetModelHandle (active)" \
                {mlClient GetModelHandle mlResModel $mlResModelId}]} {
            if {[::ModelLoader::Adapter::HvRun "AddResultFile" \
                    [list mlResModel AddResultFile $resultPath]]} {
                set attached 1
            }
            ::ModelLoader::Adapter::HvRun "release mlResModel" \
                {mlResModel ReleaseHandle}
        }
    }
    if {$attached} { return 1 }

    lappend warnings "the result file '$label' could not be attached \
(client AddModel / model AddResultFile were both refused: $why).  The model is \
loaded - add the results with 'File > Load > Results' or fill in a suitable \
reader label (V10)."
    return 0
}

#------------------------------------------------------------ load both inputs -
# Loads the two step-1 inputs into window <winIdx> of the ACTIVE page:
#   <modelPath>  'Input Model'  file - FE model / input deck (may be empty)
#   <resultPath> 'Input Result' file - result file          (may be empty)
# At least one of the two has to be given; a path that is not an existing file
# aborts the load before any hwi call (ok 0 + reason in the message).
# What is loaded:
#   model only      -> AddModel <model>
#   result only     -> AddModel <result>  (HyperView builds the model from it)
#   model + result  -> AddModel <model>, then Adapter::AttachResult (V10)
# Returns dict: {ok <0|1> mode <text> files <list> models <n>
#                warnings {text ...} message <text>}
proc ::ModelLoader::Adapter::LoadInputs {winIdx modelPath modelReader \
                                             resultPath resultReader} {
    ::ModelLoader::State::ClearLastError
    set warnings {}
    set files    {}
    set modelCnt 0
    set mode     ""
    set pageIdx  ""

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
    if {$ok && $modelPath ne ""} {
        if {$modelReader eq ""} {
            set ok [::ModelLoader::Adapter::HvRun "AddModel <model> (auto reader)" \
                [list mlClient AddModel $modelPath]]
        } else {
            set ok [::ModelLoader::Adapter::HvRun "AddModel <model> '$modelReader'" \
                [list mlClient AddModel $modelPath $modelReader]]
        }
        if {$ok} {
            lappend files $modelPath
            set mode "model"
        }
    }
    # --- 2. the result file (if any) -----------------------------------------
    if {$ok && $resultPath ne ""} {
        if {$mode eq ""} {
            # no model file: the result file has to bring its own mesh
            if {$resultReader eq ""} {
                set ok [::ModelLoader::Adapter::HvRun \
                    "AddModel <result> (auto reader)" \
                    [list mlClient AddModel $resultPath]]
            } else {
                set ok [::ModelLoader::Adapter::HvRun \
                    "AddModel <result> '$resultReader'" \
                    [list mlClient AddModel $resultPath $resultReader]]
            }
            if {$ok} {
                lappend files $resultPath
                set mode "result"
            }
        } else {
            if {[::ModelLoader::Adapter::AttachResult mlClient warnings \
                    $resultPath $resultReader]} {
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
        reader $modelReader modelFile $modelPath modelReader $modelReader \
        resultFile $resultPath resultReader $resultReader
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
# Returns the dict of RefreshWindowResults (ok 0 when the load itself failed).
proc ::ModelLoader::Adapter::LoadAndRefresh {winIdx path reader} {
    if {![::ModelLoader::Adapter::LoadModel $winIdx $path $reader]} {
        return [dict create ok 0 models 0 files {} subcases {} simulations {} \
            datatypes {} components {} current "" \
            message [::ModelLoader::State::GetLastError]]
    }
    return [::ModelLoader::Adapter::RefreshWindowResults $winIdx]
}

# Load BOTH step-1 inputs into <winIdx> and immediately re-read the window, so
# that the result tree of the info pane is up to date.
# Returns the dict of RefreshWindowResults, extended by the LoadInputs keys
# "mode" and "warnings" (non fatal problems, e.g. a refused result attach).
proc ::ModelLoader::Adapter::LoadAllAndRefresh {winIdx modelPath modelReader \
                                                      resultPath resultReader} {
    set res [::ModelLoader::Adapter::LoadInputs $winIdx $modelPath $modelReader \
                                                   $resultPath $resultReader]
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
#=============================================================================
# SECTION 3 - UI LAYER (hwtk widgets only - Logic + Adapter are used here)
#   The wizard has exactly two steps:
#     STEP 1 : page layout + load one model/result file per window (all windows
#              of the active page are handled, the results are then listed)
#     STEP 2 : choose subcase / simulation / result type / component and apply
#              the contour plot
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
    variable wInfo      ""
    variable wStatus    ""
    variable wWindowCount ""
    variable wTargetWin   ""
    variable wTargetWin2  ""
    variable wPageInfo    ""
    variable wFile        ""   ;# kept: points at the 'Input Model' widget
    variable wModelFile   ""
    variable wResultFile  ""
    variable wReader      ""
    variable wModelInfo   ""
    variable wSubcase     ""
    variable wSimulation  ""
    variable wDataType    ""
    variable wComponent   ""
    variable wAveraging   ""
    variable wLayer       ""
    variable wApplyAll    ""
    variable wStepTitle   ""
    variable wStepHelp    ""
    # values bound to the widgets (they survive a rebuild of the dialog)
    variable varWindowCount 2
    # last window count that was accepted (invalid typing is reverted to it)
    variable lastGoodWindowCount 2
    variable varTargetWin   1
    variable varFile        ""       ;# primary file, mirrors varModelFile
    variable varModelFile   ""
    variable varResultFile  ""
    variable varReader      ""
    variable varModelInfo   ""
    variable varSubcase     ""
    variable varSimulation  {<default>}
    variable varDataType    ""
    variable varComponent   ""
    variable varAveraging   {<default>}
    variable varLayer       {<default>}
    variable varApplyAll    1
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
proc ::ModelLoader::UI::SetWidgetValue {widget value} {
    if {$widget eq "" || ![winfo exists $widget]} { return }
    catch { $widget set $value }
    return
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
proc ::ModelLoader::UI::SetWindowCountValue {n} {
    variable wWindowCount
    variable varWindowCount
    variable lastGoodWindowCount
    set varWindowCount $n
    set lastGoodWindowCount $n
    if {$wWindowCount ne "" && [winfo exists $wWindowCount]} {
        set values [::ModelLoader::Logic::WindowCountChoices]
        if {[lsearch -exact $values $n] < 0} { lappend values $n }
        ::ModelLoader::UI::SetComboValues $wWindowCount $values
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
        ::ModelLoader::UI::SetStatus "Chosen $kind file: \
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
# Creates the dialog, its buttons, the banner, the two step frames, the
# information pane and the status line.  The content of the steps is created by
# BuildStep1 / BuildStep2, both of which are called from here.
proc ::ModelLoader::UI::Build {} {
    variable dlg
    variable recess
    variable customBar
    variable wBody
    variable wStep1
    variable wStep2
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
    set wStepTitle [hwtk::label $head.title -text "Step 1 of 2" -justify left -anchor w]
    pack $wStepTitle -side top -fill x
    set wStepHelp [hwtk::label $head.help -text "" -justify left -anchor w -wraplength 760]
    pack $wStepHelp -side top -fill x

    # --- body (holds the two step frames, only one is packed at a time) ------
    set wBody [hwtk::frame $recess.body]
    pack $wBody -side top -fill both -expand 1 -pady 4
    set wStep1 [hwtk::frame $wBody.step1]
    set wStep2 [hwtk::frame $wBody.step2]
    ::ModelLoader::UI::BuildStep1
    ::ModelLoader::UI::BuildStep2
    ::ModelLoader::UI::BindStep2

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
    variable wStepTitle
    variable wStepHelp

    set step $n
    if {[winfo exists $wStep1]} { pack forget $wStep1 }
    if {[winfo exists $wStep2]} { pack forget $wStep2 }

    if {$step == 1} {
        pack $wStep1 -side top -fill both -expand 1
        catch { $wStepTitle configure -text "STEP 1 of 2 - Page layout and model loading" }
        catch { $wStepHelp configure -text "Set how many windows the active page shows, \
then load one model or result file into each window.  The results that HyperView finds \
in every window are listed in the information pane below." }
        ::ModelLoader::UI::SetButtonState Back  disabled
        ::ModelLoader::UI::SetButtonState Next  normal
        ::ModelLoader::UI::SetButtonState Apply disabled
        ::ModelLoader::UI::RefreshWindowList
    } else {
        pack $wStep2 -side top -fill both -expand 1
        catch { $wStepTitle configure -text "STEP 2 of 2 - Contour plot" }
        catch { $wStepHelp configure -text "Pick the subcase, the simulation, the result \
(data) type and the component of the selected window, then apply the contour plot.  \
'Apply to all loaded windows' repeats the same settings in every window that holds a \
subcase with the same label." }
        ::ModelLoader::UI::SetButtonState Back  normal
        ::ModelLoader::UI::SetButtonState Next  disabled
        ::ModelLoader::UI::SetButtonState Apply normal
        ::ModelLoader::UI::RefreshStep2
    }
    return $step
}
proc ::ModelLoader::UI::StepNext {} {
    if {[catch { ::ModelLoader::Logic::ValidateStep1 } msg]} {
        ::ModelLoader::UI::SetStatus "Step 1 is not finished: $msg"
        catch { tk_messageBox -title "Model Loader" -icon warning -message $msg \
            -parent .modelLoaderGUI }
        return
    }
    ::ModelLoader::UI::ShowStep 2
    ::ModelLoader::UI::SetStatus "Step 2: choose the contour settings."
    return
}
proc ::ModelLoader::UI::StepBack {} {
    ::ModelLoader::UI::ShowStep 1
    ::ModelLoader::UI::SetStatus "Step 1: page layout and model loading."
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
    variable wReader
    variable varFile
    variable varModelFile
    variable varResultFile
    variable varReader

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
    # the field shows what the script really has (never a stale variable value)
    catch { bind $lf.cb <Map> { ::ModelLoader::UI::SetWindowCountValue \
        [::ModelLoader::UI::ReadWindowCount] } }
    hwtk::button $lf.apply -text "Apply layout" -command ::ModelLoader::UI::OnApplyLayout
    grid $lf.apply -row 0 -column 2 -sticky w -padx 6 -pady 2
    hwtk::button $lf.refresh -text "Refresh page info" \
        -command ::ModelLoader::UI::OnRefreshPage
    grid $lf.refresh -row 0 -column 3 -sticky w -padx 6 -pady 2
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

    hwtk::label $lf2.l3 -text "Reader (optional):" -width 26 -anchor w
    grid $lf2.l3 -row 3 -column 0 -sticky w -padx 2 -pady 2
    # V5 - VERIFY: 'client AddModel <file> <readerLabel>' needs the exact reader
    #      label of the installation.  Leave this empty to let HyperView pick the
    #      reader from the file extension; fill it in (for example
    #      "Nastran OP2 Reader") when auto detection picks the wrong one.
    #      It is used for the model file and for the result file.
    set wReader [hwtk::entry $lf2.reader -width 40 \
        -textvariable ::ModelLoader::UI::varReader]
    grid $lf2.reader -row 3 -column 1 -sticky ew -padx 2 -pady 2
    hwtk::button $lf2.load -text "Load into window" -command ::ModelLoader::UI::OnLoadModel
    grid $lf2.load -row 3 -column 2 -sticky w -padx 6 -pady 2

    hwtk::label $lf2.l4 -anchor w -justify left -wraplength 740 \
        -text "'Input Model' offers *.inp (Abaqus) first, 'Input Result' offers *.res (FEMFAT) \
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
        -text "The result type list follows the selected subcase, the component list follows \
the selected result type.  Should this build not deliver the automatic update, press \
'Reload lists' after changing the subcase or the result type."
    grid $lf.hint -row 5 -column 0 -columnspan 4 -sticky w -padx 2 -pady 2
    return
}

#=============================================================================
# SECTION 3e - STEP 2 LOGIC (refresh, selection changes, spec assembly)
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
    return "window $winIdx : subcase '$subcaseId' ($label), simulation $sim, type \
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
# SECTION 3f - PREVIEW, EVENTS AND THE STEP 1 ACTIONS
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

#--------------------------------- step 1 actions -----------------------------
proc ::ModelLoader::UI::OnApplyLayout {} {
    # BUG FIX: the number is taken from the WIDGET first (see UI::ReadWindowCount).
    # Reading only the Tcl variable could apply a default instead of the value
    # the user picked, and the following UI::RefreshWindowList used to overwrite
    # the field with the first entry of the list (=1) whenever the active page
    # still showed fewer windows than requested.
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
        ::ModelLoader::UI::AppendInfo [list "" "LAYOUT" \
            "  $wanted window(s) requested - refused: [dict get $res message]"]
        ::ModelLoader::UI::RefreshWindowList
        return
    }
    if {[dict get $res unchanged]} {
        ::ModelLoader::UI::SetStatus "The active page already shows $wanted window(s)."
    } else {
        ::ModelLoader::UI::SetStatus "Layout applied: $wanted window(s), token '[dict get $res layout]'."
    }
    # write the applied value back into variable AND widget, then refresh
    ::ModelLoader::UI::SetWindowCountValue $wanted
    # windows that do not exist any more lose their recorded state
    ::ModelLoader::State::PruneTo [dict get $res windows]
    ::ModelLoader::UI::RefreshWindowList
    ::ModelLoader::UI::SetWindowCountValue $wanted
    return
}
proc ::ModelLoader::UI::OnRefreshPage {} {
    ::ModelLoader::UI::SetStatus "Reading the active page ..."
    catch { update idletasks }
    set info [::ModelLoader::UI::RefreshWindowList]
    if {[llength $info] == 0} {
        ::ModelLoader::UI::SetStatus "The active page could not be read: \
[::ModelLoader::State::GetLastError]"
    } else {
        ::ModelLoader::UI::SetStatus "Active page [dict get $info page] : \
[dict get $info windows] window(s), layout token '[dict get $info layout]'."
    }
    return
}

proc ::ModelLoader::UI::OnLoadModel {} {
    variable varModelFile
    variable varResultFile
    variable varFile
    variable varReader
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
    ::ModelLoader::UI::SetStatus "Loading into window $winIdx ..."
    catch { update idletasks }
    set res [::ModelLoader::Adapter::LoadAllAndRefresh $winIdx $modelPath $varReader \
                                                              $resultPath $varReader]
    if {![dict get $res ok]} {
        ::ModelLoader::UI::AppendInfo [list "" "LOAD INTO WINDOW $winIdx" \
            "  model  : [expr {$modelPath  eq "" ? {<none>} : $modelPath}]" \
            "  result : [expr {$resultPath eq "" ? {<none>} : $resultPath}]" \
            "  FAILED : [dict get $res message]" \
            "  hint   : if HyperView picked the wrong reader, type the exact reader \
label into 'Reader (optional)' and load again"]
        ::ModelLoader::UI::SetStatus "Loading failed: [dict get $res message]"
    } else {
        set lines [list "" "LOAD INTO WINDOW $winIdx" \
            "  model   : [expr {$modelPath  eq "" ? {<none>} : $modelPath}]" \
            "  result  : [expr {$resultPath eq "" ? {<none>} : $resultPath}]" \
            "  reader  : [expr {$varReader eq "" ? {<auto detected>} : $varReader}]" \
            "  mode    : [dict get $res mode]   models/further files: [dict get $res models] \
[dict get $res files]" \
            "  subcase : [llength [dict get $res subcases]]" \
            "  state   : stored, see the result tree below"]
        foreach note $notes { lappend lines "  note    : $note" }
        foreach warn [dict get $res warnings] { lappend lines "  warning : $warn" }
        ::ModelLoader::UI::AppendInfo $lines
        set status "Loaded into window $winIdx : [llength [dict get $res subcases]] subcase(s) found."
        if {[llength [dict get $res warnings]] > 0} {
            append status " ([llength [dict get $res warnings]] warning(s), see the pane)"
        }
        ::ModelLoader::UI::SetStatus $status
    }
    ::ModelLoader::UI::RefreshWindowList
    return
}
proc ::ModelLoader::UI::OnRefreshWindow {} {
    variable varTargetWin
    if {![string is integer -strict $varTargetWin]} { return }
    set winIdx $varTargetWin
    ::ModelLoader::UI::SetStatus "Re-reading the results of window $winIdx ..."
    catch { update idletasks }
    set res [::ModelLoader::Adapter::RefreshWindowResults $winIdx]
    if {![dict get $res ok]} {
        ::ModelLoader::UI::AppendInfo [list "" "RE-READ WINDOW $winIdx" \
            "  FAILED : [dict get $res message]"]
        ::ModelLoader::UI::SetStatus "Window $winIdx could not be read: [dict get $res message]"
    } else {
        ::ModelLoader::UI::AppendInfo [list "" "RE-READ WINDOW $winIdx" \
            "  models   : [dict get $res models]  files: [dict get $res files]" \
            "  subcases : [llength [dict get $res subcases]]"]
        ::ModelLoader::UI::SetStatus "Window $winIdx re-read: \
[llength [dict get $res subcases]] subcase(s)."
    }
    ::ModelLoader::UI::RefreshWindowList
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
