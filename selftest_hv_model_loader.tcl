#=============================================================================
#  selftest_hv_model_loader.tcl
#  Plain-Tcl smoke test for hv_model_loader.tcl.
#
#  It runs in a normal tclsh (8.5+) and does NOT need HyperView or hwtk, because
#  it only touches the layers that contain no hwi and no widget calls:
#     SECTION 1  State / Logic  (pure Tcl)
#     SECTION 2  Adapter        (only the paths that fail before hwi is called)
#     SECTION 3  UI             (only the pure helpers, no widget is created)
#
#  Run :  tclsh selftest_hv_model_loader.tcl
#  Exit:  0 = every check passed, 1 = at least one check failed.
#=============================================================================
set ::fails 0
set ::oks   0

proc check {label condition} {
    if {[expr {$condition}]} {
        incr ::oks
        puts "  ok   : $label"
    } else {
        puts "  FAIL : $label"
        incr ::fails
    }
}
proc checkEqual {label expected actual} {
    if {$expected eq $actual} {
        incr ::oks
        puts "  ok   : $label"
    } else {
        puts "  FAIL : $label (expected '$expected', got '$actual')"
        incr ::fails
    }
}

set here   [file dirname [file normalize [info script]]]
set wizard [file join $here hv_model_loader.tcl]

puts "== 0. parsing / loading ==============================================="
if {[catch { source $wizard } msg]} {
    puts "  FAIL : the file could not be parsed: $msg"
    exit 1
}
puts "  ok   : [file tail $wizard] parsed and loaded"

puts "== 1. procedure inventory ============================================="
# The list below is grouped, in this order: the core state/logic/adapter/UI
# procedures, then the fix 3 procedures (layout mapping), the fix 4 procedures
# (legend from a file) and finally the fix 5 procedures (view list and PNG
# capture).  The groups are NOT marked with '#' inside the list on purpose: a
# braced word is a list, and '#' is only special where a script is evaluated.
# It is held in a variable instead of being handed to 'foreach' directly,
# because it is also the contract of this selftest: section 1 checks BOTH
# directions - every listed procedure must exist, and every procedure the
# wizard defines must be listed here.
set expectedProcs {
    ::ModelLoader::Bootstrap
    ::ModelLoader::Show ::mlShow
    ::ModelLoader::State::WindowInit ::ModelLoader::State::WindowSet
    ::ModelLoader::State::WindowGet ::ModelLoader::State::WindowExists
    ::ModelLoader::State::PruneTo ::ModelLoader::State::LoadedWindows
    ::ModelLoader::State::WindowIndices ::ModelLoader::State::AnyModelLoaded
    ::ModelLoader::State::SetLayoutToken ::ModelLoader::State::GetLayoutToken
    ::ModelLoader::State::SetLastError ::ModelLoader::State::GetLastError
    ::ModelLoader::State::ResetAll
    ::ModelLoader::Logic::LayoutCandidates ::ModelLoader::Logic::InterpretWindowCount
    ::ModelLoader::Logic::MakeSpec
    ::ModelLoader::Logic::FanOutSpec ::ModelLoader::Logic::ResultSummary
    ::ModelLoader::Logic::WindowSummary ::ModelLoader::Logic::Subcases
    ::ModelLoader::Logic::SubcaseLabels ::ModelLoader::Logic::SubcaseLabel
    ::ModelLoader::Logic::SubcaseIdFromLabel ::ModelLoader::Logic::SimulationIndex
    ::ModelLoader::Logic::SimulationLabels ::ModelLoader::Logic::DataTypes
    ::ModelLoader::Logic::Components ::ModelLoader::Logic::ModelName
    ::ModelLoader::Logic::SpecIsComplete ::ModelLoader::Logic::ValidateStep1
    ::ModelLoader::Logic::ValidateStep2
    ::ModelLoader::Adapter::HvRun ::ModelLoader::Adapter::QueryPage
    ::ModelLoader::Adapter::SetWindowCount ::ModelLoader::Adapter::LoadModel
    ::ModelLoader::Adapter::RefreshWindowResults ::ModelLoader::Adapter::LoadAndRefresh
    ::ModelLoader::Adapter::AttachResult ::ModelLoader::Adapter::LoadInputs
    ::ModelLoader::Adapter::LoadAllAndRefresh
    ::ModelLoader::Adapter::ApplyContour
    ::ModelLoader::Logic::ModelFileTypes ::ModelLoader::Logic::ResultFileTypes
    ::ModelLoader::Logic::ReaderHint ::ModelLoader::Logic::CheckChosenFile
    ::ModelLoader::UI::CreateFileChooser ::ModelLoader::UI::BrowseFile
    ::ModelLoader::UI::ApplyChosenFile ::ModelLoader::UI::SetFileWidget
    ::ModelLoader::UI::ReadWindowCount ::ModelLoader::UI::SetWindowCountValue
    ::ModelLoader::UI::OnWindowCountChanged ::ModelLoader::UI::OnTargetWindowChanged
    ::ModelLoader::UI::WidgetText
    ::ModelLoader::UI::Build ::ModelLoader::UI::BuildStep1 ::ModelLoader::UI::BuildStep2
    ::ModelLoader::UI::ShowStep ::ModelLoader::UI::StepNext ::ModelLoader::UI::StepBack
    ::ModelLoader::UI::RefreshStep2 ::ModelLoader::UI::RefreshWindowList
    ::ModelLoader::UI::OnApplyLayout ::ModelLoader::UI::OnRefreshPage
    ::ModelLoader::UI::OnLearnLayouts
    ::ModelLoader::UI::OnLoadModel ::ModelLoader::UI::OnRefreshWindow
    ::ModelLoader::UI::OnApply ::ModelLoader::UI::Post ::ModelLoader::UI::DoClose
    ::ModelLoader::UI::CurrentSpec ::ModelLoader::UI::DescribeSpec
    ::ModelLoader::UI::KeepOrFirst ::ModelLoader::UI::SimulationIndexFromChoice
    ::ModelLoader::Logic::LayoutPreference ::ModelLoader::Logic::LayoutArrangements
    ::ModelLoader::Logic::PreferredLayoutToken ::ModelLoader::Logic::LayoutProbeOrder
    ::ModelLoader::Adapter::ApplyLayoutToken ::ModelLoader::Adapter::LearnLayouts
    ::ModelLoader::Logic::LegendFileTypes ::ModelLoader::Logic::LegendExtensions
    ::ModelLoader::State::SetLegendFile ::ModelLoader::State::GetLegendFile
    ::ModelLoader::Adapter::LoadLegendFromFile
    ::ModelLoader::Logic::ViewPresets ::ModelLoader::Logic::ViewAliases
    ::ModelLoader::Logic::ViewOrientation ::ModelLoader::Logic::ParseViewList
    ::ModelLoader::Logic::SanitizeName ::ModelLoader::Logic::UniqueName
    ::ModelLoader::Logic::ViewListFromFile ::ModelLoader::Logic::ViewListFileTypes
    ::ModelLoader::Logic::ViewListExtensions ::ModelLoader::Logic::CaptureScopes
    ::ModelLoader::Logic::CaptureQuality ::ModelLoader::Logic::CheckOutputDir
    ::ModelLoader::Logic::CaptureFileName ::ModelLoader::Logic::CapturePlan
    ::ModelLoader::Logic::DescribeJob ::ModelLoader::Logic::ValidateStep3
    ::ModelLoader::State::SetViewList ::ModelLoader::State::GetViewList
    ::ModelLoader::State::SetViewListFile ::ModelLoader::State::GetViewListFile
    ::ModelLoader::State::SetOutputDir ::ModelLoader::State::GetOutputDir
    ::ModelLoader::State::SetCaptureMode ::ModelLoader::State::GetCaptureMode
    ::ModelLoader::Adapter::CaptureWindow ::ModelLoader::Adapter::CaptureGraphicArea
    ::ModelLoader::Adapter::ApplyViewEntry ::ModelLoader::Adapter::CapturePng
    ::ModelLoader::UI::BuildStep3 ::ModelLoader::UI::BindStep3
    ::ModelLoader::UI::RefreshStep3 ::ModelLoader::UI::OnImportViewList
    ::ModelLoader::UI::SetOutputDirValue ::ModelLoader::UI::OnBrowseOutputDir
    ::ModelLoader::UI::OnLoadLegend ::ModelLoader::UI::OnCapture
}
set missing {}
foreach p $expectedProcs {
    if {[llength [info commands $p]] == 0} { lappend missing $p }
}
checkEqual "every expected procedure exists" {} $missing
# ... and the other direction: a helper that is added to the wizard has to show
# up in the list above (and in the README) instead of going unnoticed.  The two
# glob patterns cover the namespaces of the wizard and the short alias.
set found {}
foreach pattern [list ::ModelLoader::* ::ml*] {
    foreach p [lsort [info procs $pattern]] { lappend found $p }
}
set unlisted {}
foreach p $found {
    if {[lsearch -exact $expectedProcs $p] < 0} { lappend unlisted $p }
}
checkEqual "no procedure of the file is missing from the inventory" {} $unlisted
checkEqual "debug switch initialised" 0 $::ModelLoader::debug

# The State data that sections 3-5 work on.  It is installed again after the
# fake-hwi scenarios of section 4b, because those need an empty State.
proc seedState {} {
    ::ModelLoader::State::ResetAll
    ::ModelLoader::State::WindowInit 1 page 0 file {C:/x/model.h3d} \
        name model.h3d loaded 1 \
        subcases {{1 {Subcase 1}} {2 {Subcase 2}}} \
        simulations [dict create 1 [list {Sim 1} {Sim 2}]] \
        datatypes [dict create 1 [list Stress Displacement]] \
        components [dict create 1 [dict create Stress {vonMises P1}]]
    ::ModelLoader::State::WindowInit 2 page 0 loaded 1 subcases {{7 {Subcase 2}}}
    ::ModelLoader::State::WindowInit 3 page 0 loaded 0
    return
}

puts "== 2. State layer ===================================================="
seedState

checkEqual "WindowGet name"              model.h3d [::ModelLoader::State::WindowGet 1 name]
checkEqual "WindowGet returns a default" 9         [::ModelLoader::State::WindowGet 91 subcases 9]
checkEqual "WindowExists"                1         [::ModelLoader::State::WindowExists 3]
checkEqual "WindowExists free slot"      0         [::ModelLoader::State::WindowExists 91]
checkEqual "LoadedWindows"               {1 2}     [::ModelLoader::State::LoadedWindows]
checkEqual "WindowIndices"               {1 2 3}   [::ModelLoader::State::WindowIndices]
checkEqual "AnyModelLoaded"              1         [::ModelLoader::State::AnyModelLoaded]
checkEqual "WindowSet writes"            X         [::ModelLoader::State::WindowSet 3 note X]
checkEqual "WindowSet is readable"       X         [::ModelLoader::State::WindowGet 3 note]
checkEqual "PruneTo returns the drop list" {3}     [::ModelLoader::State::PruneTo 2]
checkEqual "pruned window is gone"       0         [::ModelLoader::State::WindowExists 3]
checkEqual "last error round trip"       hello     [::ModelLoader::State::SetLastError hello]
checkEqual "ClearLastError"              {}        [::ModelLoader::State::ClearLastError]
checkEqual "Status round trip"           busy      [::ModelLoader::State::SetStatus busy]
checkEqual "GetStatus"                   busy      [::ModelLoader::State::GetStatus]

puts "== 3. Logic layer ==================================================="
checkEqual "Basename" model.h3d [::ModelLoader::Logic::Basename {C:/x/model.h3d}]
check "WindowCountChoices are offered" \
    [expr {[lsearch -exact [::ModelLoader::Logic::WindowCountChoices] 2] >= 0}]
check "averaging modes are offered" \
    [expr {[lsearch -exact [::ModelLoader::Logic::AveragingModes] None] >= 0}]
check "<default> is the first layer choice" \
    [expr {[lindex [::ModelLoader::Logic::LayerChoices] 0] eq "<default>"}]
check "file type filters exist" \
    [expr {[llength [::ModelLoader::Logic::ModelFileTypes]] >= 3}]
check "the model filter offers *.inp (Abaqus)" \
    [expr {[string match "*.inp*" [::ModelLoader::Logic::ModelFileTypes]] ? 1 : 0}]
check "the model filter starts with the *.inp entry" \
    [expr {[string match "*inp*" [lindex [::ModelLoader::Logic::ModelFileTypes] 0]] ? 1 : 0}]
check "the result filter offers *.res (FEMFAT)" \
    [expr {[string match "*.res*" [::ModelLoader::Logic::ResultFileTypes]] ? 1 : 0}]
check "the result filter starts with the *.res entry" \
    [expr {[string match "*res*" [lindex [::ModelLoader::Logic::ResultFileTypes] 0]] ? 1 : 0}]
checkEqual "ReaderHint for a FEMFAT file" "FEMFAT Result Reader" \
    [::ModelLoader::Logic::ReaderHint {C:/r/part.res}]
checkEqual "ReaderHint for an Abaqus input deck" "Abaqus Input Reader" \
    [::ModelLoader::Logic::ReaderHint {C:/m/part.inp}]
checkEqual "ReaderHint for an unknown extension" "" \
    [::ModelLoader::Logic::ReaderHint {C:/m/part.unknown}]
checkEqual "CheckChosenFile refuses an empty path" 0 \
    [dict get [::ModelLoader::Logic::CheckChosenFile "" model] ok]
checkEqual "CheckChosenFile refuses a missing file" 0 \
    [dict get [::ModelLoader::Logic::CheckChosenFile {C:/nope/missing.inp} model] ok]
check "CheckChosenFile explains the missing file" \
    [string match "*does not exist*" \
        [dict get [::ModelLoader::Logic::CheckChosenFile {C:/nope/missing.inp} model] message]]
checkEqual "CheckChosenFile refuses a directory" 0 \
    [dict get [::ModelLoader::Logic::CheckChosenFile [pwd] model] ok]
set hereInp [file join [file dirname [file normalize [info script]]] _selftest_pure.inp]
set fhInp [open $hereInp w] ; puts $fhInp "dummy" ; close $fhInp
set chkInp [::ModelLoader::Logic::CheckChosenFile $hereInp model]
checkEqual "CheckChosenFile accepts an existing *.inp" 1 [dict get $chkInp ok]
checkEqual "CheckChosenFile normalises the path" [file normalize $hereInp] \
    [dict get $chkInp path]
checkEqual "no warning for *.inp in the model field" "" [dict get $chkInp message]
checkEqual "CheckChosenFile warns about an odd extension" 1 \
    [dict get [::ModelLoader::Logic::CheckChosenFile $wizard result] ok]
check "the odd-extension warning is filled in" \
    [string match "*unusual*" \
        [dict get [::ModelLoader::Logic::CheckChosenFile $wizard result] message]]
file delete $hereInp

::ModelLoader::State::SetLayoutToken 4 "my token"
set cand [::ModelLoader::Logic::LayoutCandidates 4]
check "LayoutCandidates keeps the cached token" \
    [expr {[lsearch -exact $cand "my token"] >= 0}]
foreach want {2x2 1x4 4x1 4} {
    check "LayoutCandidates 4 contains $want" [expr {[lsearch -exact $cand $want] >= 0}]
}
checkEqual "LayoutCandidates is unique" [llength $cand] [llength [lsort -unique $cand]]
# The cache is a discovery of ONE page, so the wizard drops it when it starts
# over (State::ResetAll) - and an empty token clears a single entry: an empty
# string is not a token, and LayoutTokenMap must not advertise it as one.
::ModelLoader::State::SetLayoutToken 4 ""
checkEqual "an empty token clears the cache entry" "" \
    [::ModelLoader::State::GetLayoutToken 4]
::ModelLoader::State::SetLayoutToken 4 1x4
checkEqual "the token map reports the known count" {4 1x4} \
    [::ModelLoader::State::LayoutTokenMap]
::ModelLoader::State::ResetAll
checkEqual "ResetAll drops the learned layout token" "" \
    [::ModelLoader::State::GetLayoutToken 4]
checkEqual "ResetAll empties the token map" {} \
    [::ModelLoader::State::LayoutTokenMap]
# the sections below work on the seeded state again
seedState

# --- fix 1: the window count of '<page> GetNumberOfWindows' -----------------
# Real HyperView answers with a NUMBER ('for {set i 0} {$i <
# [$page GetNumberOfWindows]} {incr i}', see batchImportOdb.tcl), some builds
# hand out the LIST of window indices.  Counting the answer with 'llength' made
# every page look like it had ONE window - the reason why the window count of
# the wizard jumped back to 1 after 'Apply layout'.
checkEqual "InterpretWindowCount on the scalar 4" 4 \
    [::ModelLoader::Logic::InterpretWindowCount 4]
checkEqual "InterpretWindowCount on the scalar '4'" 4 \
    [::ModelLoader::Logic::InterpretWindowCount "4"]
checkEqual "InterpretWindowCount on '1 2 3 4'" 4 \
    [::ModelLoader::Logic::InterpretWindowCount {1 2 3 4}]
checkEqual "InterpretWindowCount on the scalar 1" 1 \
    [::ModelLoader::Logic::InterpretWindowCount 1]
checkEqual "InterpretWindowCount ignores surrounding blanks" 4 \
    [::ModelLoader::Logic::InterpretWindowCount " 4 "]
checkEqual "InterpretWindowCount on an empty answer" 0 \
    [::ModelLoader::Logic::InterpretWindowCount ""]
checkEqual "InterpretWindowCount is NOT llength" 4 \
    [expr {[::ModelLoader::Logic::InterpretWindowCount 4] != [llength 4] ? 4 : 0}]
check "InterpretWindowCount never returns a negative count" \
    [expr {[::ModelLoader::Logic::InterpretWindowCount -1] >= 0}]

checkEqual "ModelName"       model.h3d [::ModelLoader::Logic::ModelName 1]
checkEqual "Subcases"        {{1 {Subcase 1}} {2 {Subcase 2}}} \
    [::ModelLoader::Logic::Subcases 1]
checkEqual "SubcaseLabels"   {{Subcase 1} {Subcase 2}} \
    [::ModelLoader::Logic::SubcaseLabels 1]
checkEqual "SubcaseLabel"    {Subcase 2} [::ModelLoader::Logic::SubcaseLabel 1 2]
checkEqual "SubcaseIdFromLabel" 2 [::ModelLoader::Logic::SubcaseIdFromLabel 1 {Subcase 2}]
checkEqual "unknown subcase label" {} [::ModelLoader::Logic::SubcaseIdFromLabel 1 nope]
checkEqual "SimulationLabels" [list {Sim 1} {Sim 2}] [::ModelLoader::Logic::SimulationLabels 1 1]
checkEqual "SimulationLabels count" 2 \
    [llength [::ModelLoader::Logic::SimulationLabels 1 1]]
checkEqual "SimulationIndex"  1 [::ModelLoader::Logic::SimulationIndex 1 1 {Sim 2}]
checkEqual "SimulationIndex unknown" -1 [::ModelLoader::Logic::SimulationIndex 1 1 nope]
checkEqual "DataTypes"  {Stress Displacement} [::ModelLoader::Logic::DataTypes 1 1]
checkEqual "DataTypes count" 2 [llength [::ModelLoader::Logic::DataTypes 1 1]]
checkEqual "Components" {vonMises P1}         [::ModelLoader::Logic::Components 1 1 Stress]

set spec [::ModelLoader::Logic::MakeSpec 1 1 Stress vonMises None <default>]
checkEqual "MakeSpec keys" \
    {subcaseId simulationIndex dataType component averaging layer} [dict keys $spec]
checkEqual "MakeSpec values" {1 1 Stress vonMises None <default>} \
    [list [dict get $spec subcaseId] [dict get $spec simulationIndex] \
          [dict get $spec dataType] [dict get $spec component] \
          [dict get $spec averaging] [dict get $spec layer]]
checkEqual "SpecIsComplete" 1 [::ModelLoader::Logic::SpecIsComplete $spec]
checkEqual "ValidateStep1 accepts a loaded model" 1 \
    [expr {[catch { ::ModelLoader::Logic::ValidateStep1 }] == 0}]
checkEqual "ValidateStep2 accepts a full spec" 1 \
    [expr {[catch { ::ModelLoader::Logic::ValidateStep2 1 $spec }] == 0}]
set badSpec [dict replace $spec dataType ""]
checkEqual "ValidateStep2 rejects an empty data type" 1 \
    [expr {[catch { ::ModelLoader::Logic::ValidateStep2 1 $badSpec }] == 1}]
checkEqual "ValidateStep2 rejects an empty window" 1 \
    [expr {[catch { ::ModelLoader::Logic::ValidateStep2 3 $spec }] == 1}]

set fanOut    [::ModelLoader::Logic::FanOutSpec {Subcase 2} $spec]
set jobs      [lindex $fanOut 0]
set unmatched [lindex $fanOut 1]
checkEqual "FanOutSpec job count" 2 [llength $jobs]
checkEqual "FanOutSpec window 1 keeps the local subcase id" 2 \
    [dict get [lindex [lindex $jobs 0] 1] subcaseId]
checkEqual "FanOutSpec window 2 maps the label to its own id" 7 \
    [dict get [lindex [lindex $jobs 1] 1] subcaseId]
checkEqual "FanOutSpec unmatched" {} $unmatched
checkEqual "FanOutSpec reports windows without that label" {1 2} \
    [lindex [::ModelLoader::Logic::FanOutSpec {does not exist} $spec] 1]

check "WindowSummary names the file" \
    [string match "*model.h3d*2 subcase*" [::ModelLoader::Logic::WindowSummary 1]]
check "WindowSummary marks an empty window" \
    [string match "*(empty)*" [::ModelLoader::Logic::WindowSummary 3]]
set summary [join [::ModelLoader::Logic::ResultSummary 1] "\n"]
check "ResultSummary lists the subcase"   [expr {[string first {subcase 2 : Subcase 2} $summary] >= 0}]
check "ResultSummary lists the type"      [expr {[string first Stress $summary] >= 0}]
check "ResultSummary lists the component" [expr {[string first vonMises $summary] >= 0}]

# ---------------------------------------------------------------------------
# 3b. fix 3 / fix 4 / fix 5 - the pure logic behind the new steps.
#     Nothing here touches hwi or a widget.
# ---------------------------------------------------------------------------
puts "== 3b. fix 3: the layout mapping of a window count ===================="
checkEqual "4 windows are arranged 2x2" {2 2} [::ModelLoader::Logic::LayoutPreference 4]
checkEqual "6 windows are arranged 2x3" {2 3} [::ModelLoader::Logic::LayoutPreference 6]
checkEqual "12 windows are arranged 3x4" {3 4} [::ModelLoader::Logic::LayoutPreference 12]
checkEqual "2 windows are arranged 1x2 (side by side)" {1 2} \
    [::ModelLoader::Logic::LayoutPreference 2]
checkEqual "1 window is 1x1" {1 1} [::ModelLoader::Logic::LayoutPreference 1]
checkEqual "a zero count does not crash" {1 1} [::ModelLoader::Logic::LayoutPreference 0]
checkEqual "the preferred token of 4" 2x2 [::ModelLoader::Logic::PreferredLayoutToken 4]
checkEqual "the preferred token of 9" 3x3 [::ModelLoader::Logic::PreferredLayoutToken 9]
checkEqual "the first arrangement of 4 is the square" {2 2} \
    [lindex [::ModelLoader::Logic::LayoutArrangements 4] 0]
checkEqual "4 has three arrangements" 3 [llength [::ModelLoader::Logic::LayoutArrangements 4]]
check "4 also offers 1x4 and 4x1" [expr {
    [lsearch -exact [::ModelLoader::Logic::LayoutArrangements 4] {1 4}] >= 0 && \
    [lsearch -exact [::ModelLoader::Logic::LayoutArrangements 4] {4 1}] >= 0 ? 1 : 0}]
# FIX 3: the old code ended with 'lsort -unique' and threw the preference away.
# The candidate list now starts with the preferred arrangement, the plain count
# and the legacy words come last.
checkEqual "the first candidate of 4 is 2x2" 2x2 \
    [lindex [::ModelLoader::Logic::LayoutCandidates 4] 0]
checkEqual "the first candidate of 6 is 2x3" 2x3 \
    [lindex [::ModelLoader::Logic::LayoutCandidates 6] 0]
checkEqual "the first candidate of 2 is 1x2" 1x2 \
    [lindex [::ModelLoader::Logic::LayoutCandidates 2] 0]
check "4x1 is tried before the plain count '4'" [expr {
    [lsearch -exact [::ModelLoader::Logic::LayoutCandidates 4] 4x1] < \
    [lsearch -exact [::ModelLoader::Logic::LayoutCandidates 4] 4] ? 1 : 0}]
check "the legacy tokens survived" [expr {
    [lsearch -exact [::ModelLoader::Logic::LayoutCandidates 4] 2H] >= 0 ? 1 : 0}]
# a token HyperView itself accepted wins over every guess (V1)
::ModelLoader::State::SetLayoutToken 4 "4 - 1"
checkEqual "a learned token is the first candidate" {4 - 1} \
    [lindex [::ModelLoader::Logic::LayoutCandidates 4] 0]
checkEqual "the learned token is not duplicated" 1 \
    [llength [lsearch -all -inline -exact \
        [::ModelLoader::Logic::LayoutCandidates 4] {4 - 1}]]
::ModelLoader::State::SetLayoutToken 4 ""
checkEqual "garbage produces no candidate" {} \
    [::ModelLoader::Logic::LayoutCandidates not-a-count]
checkEqual "a zero count produces no candidate" {} \
    [::ModelLoader::Logic::LayoutCandidates 0]
# the probe only visits counts >= the current one (a probe must not shrink the page)
checkEqual "the probe order of 4" {4 6 8 9 12 16} \
    [::ModelLoader::Logic::LayoutProbeOrder 4]
checkEqual "the probe order of 6" {6 8 9 12 16} \
    [::ModelLoader::Logic::LayoutProbeOrder 6]
checkEqual "the probe order of 16" {16} [::ModelLoader::Logic::LayoutProbeOrder 16]
checkEqual "the probe order takes a custom choice list" {4 5} \
    [::ModelLoader::Logic::LayoutProbeOrder 4 {1 2 4 5}]
seedState

puts "== 3c. fix 4: the legend file ======================================="
check "the legend browser offers *.tcl first" \
    [expr {[string match "*Legend Tcl Scripts*.tcl*" \
        [lindex [::ModelLoader::Logic::LegendFileTypes] 0]] ? 1 : 0}]
check "the legend browser offers *.hvl and 'All Files'" [expr {
    [string match "*.hvl*" [::ModelLoader::Logic::LegendFileTypes]] && \
    [string match "*All Files*" [::ModelLoader::Logic::LegendFileTypes]] ? 1 : 0}]
checkEqual "the legend extensions" {.tcl .hvl .txt} \
    [::ModelLoader::Logic::LegendExtensions]
set noLeg [::ModelLoader::Adapter::LoadLegendFromFile 1 ""]
checkEqual "an empty legend path is refused" 0 [dict get $noLeg ok]
check "the refusal says that no file was chosen" \
    [string match "No legend file was chosen.*" [dict get $noLeg message]]
set missLeg [::ModelLoader::Adapter::LoadLegendFromFile 1 {C:/nope/legend.tcl}]
checkEqual "a missing legend file is refused" 0 [dict get $missLeg ok]
check "the missing legend file is named" \
    [string match "*Legend file not found*" [dict get $missLeg message]]
set dirLeg [::ModelLoader::Adapter::LoadLegendFromFile 1 $here]
checkEqual "a folder is not a legend file" 0 [dict get $dirLeg ok]
check "the folder refusal explains itself" \
    [string match "*is a directory*" [dict get $dirLeg message]]
set emptyLegend [file join $here _selftest_empty_legend.tcl]
set fh [open $emptyLegend w] ; close $fh
set emptyLegRes [::ModelLoader::Adapter::LoadLegendFromFile 1 $emptyLegend]
checkEqual "an empty legend file is refused" 0 [dict get $emptyLegRes ok]
check "the empty legend file is named" \
    [string match "*is empty*" [dict get $emptyLegRes message]]
# a saved legend IS a Tcl script, so the file is sourced - a *.dat file with
# Tcl in it works as well, the user is only warned about the extension
set oddLegend [file join $here _selftest_legend.dat]
set fh [open $oddLegend w]
puts $fh "set ::selftestLegendRan 1"
close $fh
set ::selftestLegendRan 0
set oddLegRes [::ModelLoader::Adapter::LoadLegendFromFile 1 $oddLegend]
checkEqual "an unusual legend extension is only a warning" 1 [dict get $oddLegRes ok]
check "the extension is reported" \
    [string match "*unusual for a legend file*" [dict get $oddLegRes warnings]]
checkEqual "the legend script was really sourced and ran" 1 $::selftestLegendRan
checkEqual "no hwi means the window cannot be redrawn" 0 [dict get $oddLegRes redrawn]
check "the missing redraw is a warning, not an error" \
    [string match "*could not be redrawn*" [dict get $oddLegRes warnings]]
checkEqual "the result carries the loaded path, not an empty one" 1 \
    [expr {[dict get $oddLegRes file] ne "" ? 1 : 0}]
set badLegend [file join $here _selftest_legend_bad.tcl]
set fh [open $badLegend w]
puts $fh "error \"boom\""
close $fh
set badLegRes [::ModelLoader::Adapter::LoadLegendFromFile 1 $badLegend]
checkEqual "a failing legend script is reported" 0 [dict get $badLegRes ok]
check "the failure names the Tcl error" \
    [string match "*could not be applied*boom*" [dict get $badLegRes message]]
foreach f [list $emptyLegend $oddLegend $badLegend] { catch { file delete $f } }
seedState

puts "== 3d. fix 5: view list, PNG folder and the capture plan =============="
checkEqual "the view presets" {iso front back left right top bottom} \
    [::ModelLoader::Logic::ViewPresets]
checkEqual "an alias maps onto the preset" back [::ModelLoader::Logic::ViewOrientation rear]
checkEqual "another alias maps onto iso" iso \
    [::ModelLoader::Logic::ViewOrientation isometric]
checkEqual "the case does not matter" front \
    [::ModelLoader::Logic::ViewOrientation FRONTAL]
checkEqual "an unknown token has no orientation" "" \
    [::ModelLoader::Logic::ViewOrientation my_own_view]
checkEqual "an empty token has no orientation" "" \
    [::ModelLoader::Logic::ViewOrientation ""]
checkEqual "'my view:1' becomes a file name stem" my_view_1 \
    [::ModelLoader::Logic::SanitizeName "my view:1"]
checkEqual "an empty name becomes 'view'" view [::ModelLoader::Logic::SanitizeName " .- "]
checkEqual "a duplicate name is made unique" iso-2 \
    [::ModelLoader::Logic::UniqueName {iso} iso]
checkEqual "a second duplicate counts up" iso-3 \
    [::ModelLoader::Logic::UniqueName {iso iso-2} iso]
checkEqual "a fresh name is kept" front [::ModelLoader::Logic::UniqueName {iso} front]

set viewText "# steady views\n\niso\nfront_left front\nmy_own_view\niso\n"
append viewText \
    "tilt 0.62 -0.39 0.69 0 0.35 0.91 -0.21 0 -0.7 -0.13 0.7 0 0 0 0 1\n"
append viewText "; another comment\n"
set vEntries [::ModelLoader::Logic::ParseViewList $viewText]
checkEqual "the comments and blank lines are skipped" 5 [llength $vEntries]
checkEqual "the name doubles as a preset" iso [dict get [lindex $vEntries 0] name]
checkEqual "and its orientation is set" iso [dict get [lindex $vEntries 0] orientation]
checkEqual "the second entry keeps its own name" front_left \
    [dict get [lindex $vEntries 1] name]
checkEqual "the second entry uses the given orientation" front \
    [dict get [lindex $vEntries 1] orientation]
checkEqual "an unknown orientation stays empty" "" \
    [dict get [lindex $vEntries 2] orientation]
checkEqual "a duplicate view name is made unique" iso-2 \
    [dict get [lindex $vEntries 3] name]
checkEqual "the 16 numbers became a view matrix" 16 \
    [llength [dict get [lindex $vEntries 4] matrix]]
checkEqual "a matrix line has no orientation" "" \
    [dict get [lindex $vEntries 4] orientation]
checkEqual "the raw line is kept for the report" "front_left front" \
    [dict get [lindex $vEntries 1] raw]
checkEqual "an empty list has no entry" {} [::ModelLoader::Logic::ParseViewList ""]
checkEqual "a comment only file has no entry" {} \
    [::ModelLoader::Logic::ParseViewList "# nothing\n// here\n; at all\n"]
checkEqual "a comma works as a separator" 16 \
    [llength [dict get [lindex [::ModelLoader::Logic::ParseViewList \
        "m 1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1"] 0] matrix]]
check "the view list browser offers text and Tcl" [expr {
    [string match "*.txt*" [::ModelLoader::Logic::ViewListFileTypes]] && \
    [string match "*.tcl*" [::ModelLoader::Logic::ViewListFileTypes]] ? 1 : 0}]
checkEqual "the view list extensions" {.txt .lst .csv .tcl} \
    [::ModelLoader::Logic::ViewListExtensions]

set noVL [::ModelLoader::Logic::ViewListFromFile ""]
checkEqual "no view list file is refused" 0 [dict get $noVL ok]
set missVL [::ModelLoader::Logic::ViewListFromFile {C:/nope/views.txt}]
checkEqual "a missing view list is refused" 0 [dict get $missVL ok]
set dirVL [::ModelLoader::Logic::ViewListFromFile $here]
checkEqual "a folder is not a view list" 0 [dict get $dirVL ok]
set emptyVLFile [file join $here _selftest_empty_views.txt]
set fh [open $emptyVLFile w] ; close $fh
checkEqual "an empty view list is refused" 0 \
    [dict get [::ModelLoader::Logic::ViewListFromFile $emptyVLFile] ok]
set okVLFile [file join $here _selftest_views.txt]
set fh [open $okVLFile w]
puts $fh "# two views"
puts $fh "iso"
puts $fh "front_left front"
close $fh
set okVL [::ModelLoader::Logic::ViewListFromFile $okVLFile]
checkEqual "a *.txt view list is accepted" 1 [dict get $okVL ok]
checkEqual "both views were read" 2 [llength [dict get $okVL entries]]
checkEqual "a known extension is not a warning" "" [dict get $okVL message]
set oddVLFile [file join $here _selftest_views.dat]
set fh [open $oddVLFile w] ; puts $fh "iso" ; close $fh
set oddVL [::ModelLoader::Logic::ViewListFromFile $oddVLFile]
checkEqual "an unusual extension is still read" 1 [dict get $oddVL ok]
check "but it is reported as unusual" \
    [string match "*unusual for a view list*" [dict get $oddVL message]]
puts "== 3e. fix 5: the PNG output folder and the capture plan =============="
set outDir [file join $here _selftest_png]
checkEqual "a folder that does not exist yet is accepted" 1 \
    [dict get [::ModelLoader::Logic::CheckOutputDir $outDir] ok]
checkEqual "and it is normalised" 1 \
    [expr {[dict get [::ModelLoader::Logic::CheckOutputDir $outDir] path] \
        eq [file normalize $outDir] ? 1 : 0}]
checkEqual "an empty folder is refused" 0 \
    [dict get [::ModelLoader::Logic::CheckOutputDir ""] ok]
check "the empty folder message names the folder" \
    [string match "*no PNG output folder*" \
        [dict get [::ModelLoader::Logic::CheckOutputDir ""] message]]
set notAFolder [file join $here _selftest_not_a_folder.txt]
set fh [open $notAFolder w] ; puts $fh "x" ; close $fh
checkEqual "a file is not a folder" 0 \
    [dict get [::ModelLoader::Logic::CheckOutputDir $notAFolder] ok]
check "the file is named as the reason" \
    [string match "*is a file, not a folder*" \
        [dict get [::ModelLoader::Logic::CheckOutputDir $notAFolder] message]]
checkEqual "the PNG name carries the window" w2_my_view.png \
    [file tail [::ModelLoader::Logic::CaptureFileName {C:/out} 2 "my view"]]
checkEqual "the window index is always part of the name" w11_iso.png \
    [file tail [::ModelLoader::Logic::CaptureFileName {C:/out} 11 iso]]

set planTarget [::ModelLoader::Logic::CapturePlan target 2 $vEntries {1 2 3} {C:/out}]
checkEqual "target: one job per view" 5 [llength $planTarget]
set planWin {}
foreach j $planTarget { lappend planWin [dict get $j window] }
checkEqual "target: every job captures the target window" {2 2 2 2 2} $planWin
checkEqual "target: the file of the first job" w2_iso.png \
    [file tail [dict get [lindex $planTarget 0] file]]
checkEqual "target: the second job keeps the view name" w2_front_left.png \
    [file tail [dict get [lindex $planTarget 1] file]]
set planAll [::ModelLoader::Logic::CapturePlan all 2 $vEntries {1 3} {C:/out}]
set planAllWin {}
foreach j $planAll { lappend planAllWin [dict get $j window] }
checkEqual "all: the jobs of both windows" {1 1 1 1 1 3 3 3 3 3} $planAllWin
set planBare [::ModelLoader::Logic::CapturePlan target 3 {} {1} {C:/out}]
checkEqual "without a view list one job is made" 1 [llength $planBare]
checkEqual "and it is called 'view'" view [dict get [lindex $planBare 0] name]
checkEqual "no window means no job" {} \
    [::ModelLoader::Logic::CapturePlan all 1 {} {} {C:/out}]
checkEqual "DescribeJob names window, view and file" \
    "window 2, view 'iso' (iso) -> w2_iso.png" \
    [::ModelLoader::Logic::DescribeJob [lindex $planTarget 0]]
checkEqual "DescribeJob marks a matrix view" \
    "window 2, view 'tilt' (matrix) -> w2_tilt.png" \
    [::ModelLoader::Logic::DescribeJob [lindex $planTarget 4]]
checkEqual "DescribeJob marks a plain view" \
    "window 2, view 'my_own_view' -> w2_my_own_view.png" \
    [::ModelLoader::Logic::DescribeJob [lindex $planTarget 2]]

checkEqual "the capture scopes" {target all} [::ModelLoader::Logic::CaptureScopes]
checkEqual "the PNG quality" 100 [::ModelLoader::Logic::CaptureQuality]
checkEqual "ValidateStep3 accepts target plus window" 1 \
    [expr {[catch { ::ModelLoader::Logic::ValidateStep3 target 1 $outDir } m] == 0}]
checkEqual "ValidateStep3 accepts 'all' without a window" 1 \
    [expr {[catch { ::ModelLoader::Logic::ValidateStep3 all "" $outDir } m] == 0}]
checkEqual "ValidateStep3 rejects an unknown scope" 1 \
    [expr {[catch { ::ModelLoader::Logic::ValidateStep3 window 1 $outDir } msg3] == 1}]
check "the scope message lists the two scopes" [string match "*target | all*" $msg3]
checkEqual "ValidateStep3 rejects a target without a window" 1 \
    [expr {[catch { ::ModelLoader::Logic::ValidateStep3 target 0 $outDir } m] == 1}]
checkEqual "ValidateStep3 rejects an empty folder" 1 \
    [expr {[catch { ::ModelLoader::Logic::ValidateStep3 all "" ""} msg4] == 1}]
check "the folder message is a step 3 message" \
    [string match "Step 3: no PNG output folder*" $msg4]

set capNoDir [::ModelLoader::Adapter::CapturePng target 1 {} ""]
checkEqual "CapturePng refuses an empty folder" 0 [dict get $capNoDir ok]
checkEqual "nothing was captured" 0 [dict get $capNoDir captured]
checkEqual "no file was listed" {} [dict get $capNoDir files]
checkEqual "CapturePng refuses a file as folder" 0 \
    [dict get [::ModelLoader::Adapter::CapturePng target 1 {} $notAFolder] ok]
check "the refusal is a PNG capture message" \
    [string match "PNG capture*" [dict get $capNoDir message]]
::ModelLoader::State::ResetAll
set capNoWin [::ModelLoader::Adapter::CapturePng all 1 {} $outDir]
checkEqual "without windows there is nothing to capture" 0 [dict get $capNoWin ok]
check "and the report says so" \
    [string match "*no window to capture*" [dict get $capNoWin message]]
set capNoHwi [::ModelLoader::Adapter::CapturePng target 1 {} $outDir]
checkEqual "without hwi the capture fails cleanly" 0 [dict get $capNoHwi ok]
check "the failure is reported" [expr {
    [string length [dict get $capNoHwi message]] > 0 ? 1 : 0}]
check "the failure message names the PNG capture" \
    [string match "PNG capture*" [dict get $capNoHwi message]]
foreach f [list $emptyVLFile $okVLFile $oddVLFile $notAFolder] {
    catch { file delete $f }
}
catch { file delete -force $outDir }
seedState

puts "== 4. Adapter layer (failure paths - no hwi call is reached) =========="
checkEqual "HvRun reports a failing script" 0 \
    [::ModelLoader::Adapter::HvRun "selftest failing call" {error "boom"}]
check "HvRun stored the failure message" \
    [string match "*boom*" [::ModelLoader::State::GetLastError]]
checkEqual "HvRun reports a succeeding script" 1 \
    [::ModelLoader::Adapter::HvRun "selftest ok" {set selftestX 1}]
checkEqual "HvRun runs in the caller frame" 1 $selftestX
checkEqual "LoadModel on a missing file" 0 \
    [::ModelLoader::Adapter::LoadModel 1 {C:/this/file/does/not/exist.h3d} {}]
check "LoadModel stored 'File not found'" \
    [string match "*File not found*" [::ModelLoader::State::GetLastError]]
checkEqual "LoadAndRefresh propagates a load failure" 0 \
    [dict get [::ModelLoader::Adapter::LoadAndRefresh 1 {C:/nope.h3d} {}] ok]
checkEqual "LoadAndRefresh failure message" 1 \
    [expr {[string length [dict get \
        [::ModelLoader::Adapter::LoadAndRefresh 1 {C:/nope.h3d} {}] message]] > 0}]

# --- the two-input loader (fix 2) -------------------------------------------
# FIX 2: the reader arguments are gone - 'LoadInputs <winIdx> <model> <result>'.
set twoEmpty [::ModelLoader::Adapter::LoadInputs 1 "" ""]
checkEqual "LoadInputs refuses two empty fields" 0 [dict get $twoEmpty ok]
check "LoadInputs explains the empty input" \
    [string match "*Neither 'Input Model' nor 'Input Result'*" \
        [dict get $twoEmpty message]]
set twoBadModel [::ModelLoader::Adapter::LoadInputs 1 {C:/nope/part.inp} {C:/nope/part.res}]
checkEqual "LoadInputs refuses a missing model file" 0 [dict get $twoBadModel ok]
check "LoadInputs names the missing model file" \
    [string match "*model file does not exist*" [dict get $twoBadModel message]]
set twoBadRes [::ModelLoader::Adapter::LoadInputs 1 "" {C:/nope/part.res}]
checkEqual "LoadInputs refuses a missing result file" 0 [dict get $twoBadRes ok]
check "LoadInputs names the missing result file" \
    [string match "*result file does not exist*" [dict get $twoBadRes message]]
set twoGood [::ModelLoader::Adapter::LoadInputs 1 $wizard $wizard]
checkEqual "LoadInputs reaches hwi with two existing files (and fails there)" 0 \
    [dict get $twoGood ok]
check "LoadInputs reported the missing hwi" \
    [expr {[string length [dict get $twoGood message]] > 0}]
checkEqual "LoadInputs returns the warnings key" {} [dict get $twoGood warnings]
# an old-style call (with the two reader arguments) must still work: the reader
# slots are ignored, a real result path hiding in them is rescued (the
# observable proof is the 'legacy' check in the hwtk-stub section below)
set twoLegacy [::ModelLoader::Adapter::LoadInputs 1 {C:/nope/part.inp} {Some Reader} {C:/nope/part.res} ""]
checkEqual "a legacy call with reader arguments is still accepted" 0 \
    [dict get $twoLegacy ok]
check "the legacy call still names the missing model file" \
    [string match "*model file does not exist*" [dict get $twoLegacy message]]
set twoAll [::ModelLoader::Adapter::LoadAllAndRefresh 1 "" ""]
checkEqual "LoadAllAndRefresh propagates the refusal" 0 [dict get $twoAll ok]
checkEqual "LoadAllAndRefresh keeps the warnings key" {} [dict get $twoAll warnings]

# ---------------------------------------------------------------------------
# 4b. the adapter's load sequence, driven by a FAKE hwi.
#     Skipped when a real hwi is present, so this file stays safe to run inside
#     HyperView as well.
# ---------------------------------------------------------------------------
if {[llength [info commands hwi]] > 0} {
    puts "== 4b. adapter load sequence - SKIPPED (a real hwi is present) ======="
} else {
puts "== 4b. adapter load sequence against a fake hwi ======================"
namespace eval ::fake {
    variable calls {}
    variable models {}
    variable rejectResultViaAddModel 0
    variable attachOk 1
    variable setResultOk 1
    variable win 4
    variable listWindows 0
    # fix 3: the layout tokens this build offers, and the one it is showing
    variable layouts {1x1 1 1x2 2 2x1 2 2x2 4 2x3 6 3x2 6 4x2 8 3x3 9}
    variable layoutToken ""
    # fix 5: which capture API this build provides, and every PNG it wrote
    variable captureImageOk 0
    variable captureActiveOk 0
    variable captureScreenOk 1
    variable pngs {}
}
# writes a tiny stand-in PNG so the test can see that a file really appeared
proc ::fake::WritePng {file} {
    catch { file mkdir [file dirname $file] }
    set fh [open $file w]
    puts $fh "PNG"
    close $fh
    lappend ::fake::pngs $file
    return 1
}
proc ::fake::Capture {method flag file} {
    if {!$flag} { error "$method is not offered by this build" }
    return [::fake::WritePng $file]
}
# every method call is logged as {<handle> <method> <args...>}
proc ::fake::Find {method} {
    variable calls
    set out {}
    foreach c $calls { if {[lindex $c 1] eq $method} { lappend out $c } }
    return $out
}
# creates a handle command that forwards every method to ::fake::Object
proc ::fake::Handle {name} {
    uplevel #0 [list proc $name {method args} \
        "::fake::Object $name \$method {*}\$args"]
    return 1
}
# Every method of the fake devices lands here.  NOTE: a 'switch' body is parsed
# as a LIST, not as a script, so no '#' comments may sit between the arms -
# they would be taken as patterns and shift the pattern/body pairs.  Comments
# inside an arm body ARE fine (an arm body is a script).
proc ::fake::Object {name method args} {
    variable calls
    variable models
    lappend calls [list $name $method {*}$args]
    switch -- $method {
        GetProjectHandle - GetPageHandle - GetWindowHandle \
        - GetClientHandle - GetModelHandle - GetResultCtrlHandle {
            return [::fake::Handle [lindex $args 0]]
        }
        ReleaseHandle      { return 1 }
        GetActivePage      { return 0 }
        GetLayout          {
            # 'page GetLayout' reports the token the page is really showing.
            # Before any SetLayout the count is mirrored as '1x<count>', so the
            # 'fix 1' scenarios below stay unchanged.
            if {$::fake::layoutToken ne ""} { return $::fake::layoutToken }
            return "1x$::fake::win"
        }
        SetLayout          {
            set tok [lindex $args 0]
            if {![dict exists $::fake::layouts $tok]} {
                error "the layout '$tok' is not offered by this build"
            }
            set ::fake::layoutToken $tok
            set ::fake::win [dict get $::fake::layouts $tok]
            return 1
        }
        SetActiveWindow    { return 1 }
        SetDisplayOptions  { return 1 }
        GetViewControlHandle { return [::fake::Handle [lindex $args 0]] }
        SetOrientation     { return 1 }
        SetViewMatrix      { return 1 }
        Fit                { return 1 }
        CaptureImage {
            return [::fake::Capture CaptureImage $::fake::captureImageOk \
                [lindex $args 0]]
        }
        CaptureActiveWindow {
            return [::fake::Capture CaptureActiveWindow $::fake::captureActiveOk \
                [lindex $args 1]]
        }
        CaptureScreen {
            return [::fake::Capture CaptureScreen $::fake::captureScreenOk \
                [lindex $args 1]]
        }
        GetNumberOfWindows {
            # HyperView answers with a NUMBER ('for {set i 0} {$i <
            # [$page GetNumberOfWindows]} {incr i}', see batchImportOdb.tcl).
            # ::fake::listWindows models a build that hands out the list of
            # window indices instead - both have to give the same count (fix 1).
            if {$::fake::listWindows} {
                return [lrange {1 2 3 4 5 6 7 8 9 10 11 12} 0 [expr {$::fake::win - 1}]]
            }
            return $::fake::win
        }
        AddModel {
            set file   [lindex $args 0]
            set reader [expr {[llength $args] > 1 ? [lindex $args 1] : ""}]
            if {$reader eq "" && [llength $models] > 0 && \
                    [string tolower [file extension $file]] eq ".res" && \
                    $::fake::rejectResultViaAddModel} {
                error "the reader cannot open '$file'"
            }
            lappend models [list $file $reader]
            return [llength $models]
        }
        SetResult {
            # FIX 2 (V10): this is how a result file is attached to the model
            # that is already in the window - 'AddModel <result>' cannot do it.
            if {!$::fake::setResultOk} { error "SetResult is not available" }
            lappend models [list [lindex $args 0] ""]
            return 1
        }
        AddResultFile {
            if {!$::fake::attachOk} { error "AddResultFile is not available" }
            lappend models [list [lindex $args 0] ""]
            return 1
        }
        GetModelList {
            set ids {}
            for {set i 1} {$i <= [llength $models]} {incr i} { lappend ids $i }
            return $ids
        }
        GetActiveModel { return [expr {[llength $models] ? 1 : 0}] }
        GetFileName    { return [lindex [lindex $models 0] 0] }
        Draw           { return 1 }
    }
    error "fake hwi: '$name $method' is not modelled"
}
# the entry point of the hwi API
proc hwi {args} {
    switch -- [lindex $args 0] {
        OpenStack        { return 1 }
        CloseStack       { return 1 }
        GetSessionHandle { return [::fake::Handle [lindex $args 1]] }
    }
    error "fake hwi: unknown call '$args'"
}

# --- scenario 0 (fix 1): reading the window count of the active page --------
# 'GetNumberOfWindows' answers with a NUMBER.  The old code counted that answer
# with 'llength' - which is 1 for every scalar - and so the wizard snapped back
# to 1 window after 'Apply layout'.  Both answer forms are covered here.
set ::fake::listWindows 0
set ::fake::win 4
set pageInfo [::ModelLoader::Adapter::QueryPage]
checkEqual "fix 1: a scalar GetNumberOfWindows is read as a number" 4 \
    [dict get $pageInfo windows]
checkEqual "fix 1: the page index is read" 0 [dict get $pageInfo page]
checkEqual "fix 1: the layout token is read" "1x4" [dict get $pageInfo layout]
set ::fake::listWindows 1
checkEqual "fix 1: a list GetNumberOfWindows counts its windows" 4 \
    [dict get [::ModelLoader::Adapter::QueryPage] windows]
set ::fake::listWindows 0
set ::fake::win 1
checkEqual "fix 1: one window stays one window" 1 \
    [dict get [::ModelLoader::Adapter::QueryPage] windows]
set ::fake::win 4
# the same number has to come out of the layout routine (V1): the page already
# has 4 windows, so nothing is changed and the count is NOT reduced to 1
set lInfo [::ModelLoader::Adapter::SetWindowCount 4]
checkEqual "fix 1: SetWindowCount 4 leaves the layout untouched" 1 \
    [dict get $lInfo unchanged]
checkEqual "fix 1: SetWindowCount 4 reports 4 windows" 4 [dict get $lInfo windows]

# --- scenario 1: model only -------------------------------------------------
::ModelLoader::State::ResetAll
set ::fake::calls {}
set ::fake::models {}
set resM [::ModelLoader::Adapter::LoadInputs 1 $wizard ""]
checkEqual "model only: the load succeeds" 1 [dict get $resM ok]
checkEqual "model only: mode" "model" [dict get $resM mode]
checkEqual "model only: exactly one AddModel call" 1 [llength [::fake::Find AddModel]]
# FIX 2: the call is 'AddModel <file>' - no reader is passed any more
checkEqual "model only: AddModel got exactly one argument" 3 \
    [llength [lindex [::fake::Find AddModel] 0]]
checkEqual "model only: no SetResult was needed" 0 [llength [::fake::Find SetResult]]
checkEqual "model only: AddModel got the file" $wizard \
    [lindex [lindex [::fake::Find AddModel] 0] 2]
checkEqual "model only: state keeps modelFile" $wizard \
    [::ModelLoader::State::WindowGet 1 modelFile]
checkEqual "model only: state has no resultFile" "" \
    [::ModelLoader::State::WindowGet 1 resultFile]
checkEqual "model only: the window is marked as loaded" 1 \
    [::ModelLoader::State::WindowGet 1 loaded]

set pureRes [file join $here _selftest_pure.res]
set fhRes [open $pureRes w] ; puts $fhRes "dummy" ; close $fhRes

# --- scenario 2: model + result - the result is attached with SetResult -----
# FIX 2 (V10): the old code called 'AddModel <result> <reader>' as the FIRST
# attempt, which cannot attach a result to a model that is already in the window
# - that is why the result never showed up.  '<model> SetResult <file>' (the
# order Altair's own training.tcl uses) is tried first now.
::ModelLoader::State::ResetAll
set ::fake::calls {}
set ::fake::models {}
set ::fake::rejectResultViaAddModel 0
set ::fake::setResultOk 1
set ::fake::attachOk 1
set resBoth [::ModelLoader::Adapter::LoadInputs 1 $wizard $pureRes]
checkEqual "model+result: the load succeeds" 1 [dict get $resBoth ok]
checkEqual "model+result: mode" "model+result" [dict get $resBoth mode]
checkEqual "model+result: ONE AddModel call (the model)" 1 \
    [llength [::fake::Find AddModel]]
checkEqual "model+result: no reader is passed to AddModel" 3 \
    [llength [lindex [::fake::Find AddModel] 0]]
checkEqual "model+result: the result goes through <model> SetResult" 1 \
    [llength [::fake::Find SetResult]]
checkEqual "model+result: SetResult got the result file" $pureRes \
    [lindex [lindex [::fake::Find SetResult] 0] 2]
checkEqual "model+result: AddResultFile was not needed" 0 \
    [llength [::fake::Find AddResultFile]]
checkEqual "model+result: the model was looked up with GetModelHandle" 1 \
    [llength [::fake::Find GetModelHandle]]
checkEqual "model+result: no warnings" {} [dict get $resBoth warnings]
checkEqual "model+result: state keeps both files" [list $wizard $pureRes] \
    [list [::ModelLoader::State::WindowGet 1 modelFile] \
          [::ModelLoader::State::WindowGet 1 resultFile]]

# --- scenario 3: fallback <model> AddResultFile (V10) -----------------------
::ModelLoader::State::ResetAll
set ::fake::calls {}
set ::fake::models {}
set ::fake::rejectResultViaAddModel 1
set ::fake::setResultOk 0
set ::fake::attachOk 1
set resFall [::ModelLoader::Adapter::LoadInputs 1 $wizard $pureRes]
checkEqual "fallback: the load still succeeds" 1 [dict get $resFall ok]
checkEqual "fallback: mode" "model+result" [dict get $resFall mode]
checkEqual "fallback: SetResult was tried first" 1 [llength [::fake::Find SetResult]]
checkEqual "fallback: AddResultFile was used once" 1 \
    [llength [::fake::Find AddResultFile]]
checkEqual "fallback: no AddModel <result> was needed" 1 \
    [llength [::fake::Find AddModel]]
checkEqual "fallback: no warning" {} [dict get $resFall warnings]

# --- scenario 4: everything refused -> warning, the model stays loaded ------
::ModelLoader::State::ResetAll
set ::fake::calls {}
set ::fake::models {}
set ::fake::rejectResultViaAddModel 1
set ::fake::setResultOk 0
set ::fake::attachOk 0
set resWarn [::ModelLoader::Adapter::LoadInputs 1 $wizard $pureRes]
checkEqual "warning path: the model load is still a success" 1 [dict get $resWarn ok]
checkEqual "warning path: mode stays 'model'" "model" [dict get $resWarn mode]
checkEqual "warning path: exactly one warning" 1 \
    [llength [dict get $resWarn warnings]]
check "warning path: the warning tells the user what to do" \
    [string match "*.res*File > Load > Results*" \
        [lindex [dict get $resWarn warnings] 0]]
checkEqual "warning path: the model is still recorded" 1 \
    [::ModelLoader::State::WindowGet 1 loaded]

# --- scenario 5: result only (HyperView builds the model from it) -----------
::ModelLoader::State::ResetAll
set ::fake::calls {}
set ::fake::models {}
set ::fake::rejectResultViaAddModel 0
set ::fake::setResultOk 1
set ::fake::attachOk 1
set resOnly [::ModelLoader::Adapter::LoadInputs 1 "" $pureRes]
checkEqual "result only: the load succeeds" 1 [dict get $resOnly ok]
checkEqual "result only: mode" "result" [dict get $resOnly mode]
checkEqual "result only: one AddModel call" 1 [llength [::fake::Find AddModel]]
checkEqual "result only: AddModel got the result file" $pureRes \
    [lindex [lindex [::fake::Find AddModel] 0] 2]
checkEqual "result only: state marks the result file" $pureRes \
    [::ModelLoader::State::WindowGet 1 resultFile]
checkEqual "result only: 'file' falls back to the result file" $pureRes \
    [::ModelLoader::State::WindowGet 1 file]

# --- an old-style call with reader arguments still finds the result ---------
# FIX 2: 'LoadInputs <win> <model> <modelReader> <result> <resultReader>' has to
# keep working - the reader slots are ignored, a real path in them is rescued.
::ModelLoader::State::ResetAll
set ::fake::calls {}
set ::fake::models {}
set ::fake::rejectResultViaAddModel 0
set ::fake::setResultOk 1
set resLegacy [::ModelLoader::Adapter::LoadInputs 1 $wizard {My Reader} $pureRes ""]
checkEqual "legacy: the load succeeds" 1 [dict get $resLegacy ok]
checkEqual "legacy: mode is model+result (the result path was rescued)" \
    "model+result" [dict get $resLegacy mode]
checkEqual "legacy: the result really went through SetResult" $pureRes \
    [lindex [lindex [::fake::Find SetResult] 0] 2]

# --- scenario 6: LoadAllAndRefresh carries mode + warnings into the tree ----
::ModelLoader::State::ResetAll
set ::fake::calls {}
set ::fake::models {}
set ::fake::setResultOk 1
set resTree [::ModelLoader::Adapter::LoadAllAndRefresh 1 $wizard $pureRes]
checkEqual "LoadAllAndRefresh: the window read succeeds" 1 [dict get $resTree ok]
checkEqual "LoadAllAndRefresh: mode is carried over" "model+result" \
    [dict get $resTree mode]
checkEqual "LoadAllAndRefresh: the warnings key is carried over" {} \
    [dict get $resTree warnings]
checkEqual "LoadAllAndRefresh: both models are seen" 2 [dict get $resTree models]
# the old signature (with the two reader arguments) is still accepted
set resTreeOld [::ModelLoader::Adapter::LoadAllAndRefresh 1 $wizard "" $pureRes ""]
checkEqual "LoadAllAndRefresh: old-style call is accepted" 1 [dict get $resTreeOld ok]
checkEqual "LoadAllAndRefresh: old-style call keeps mode" "model+result" \
    [dict get $resTreeOld mode]

# --- scenario 7 (fix 3): the layout mapping of a window count ---------------
# This build only offers the tokens listed in ::fake::layouts, every other
# spelling is refused with an error - exactly like HyperView refuses a layout
# token it does not know.  Only the PREFERENCE ORDER of the candidates makes the
# wizard find the right token (the old code tried an 'lsort -unique' order, so
# for 12 windows the first candidate could be the token for ONE window).
puts "  -- fix 3: layout candidates against a build that only offers RxC"
::ModelLoader::State::ResetAll
checkEqual "fix 3: a ResetAll page knows no token for 4" "" \
    [::ModelLoader::State::GetLayoutToken 4]
set ::fake::calls {}
set ::fake::layoutToken 1x1
set ::fake::win 1
set l4 [::ModelLoader::Adapter::SetWindowCount 4]
checkEqual "fix 3: 4 windows were applied" 1 [dict get $l4 ok]
checkEqual "fix 3: the token of 4 is the square 2x2" 2x2 [dict get $l4 layout]
checkEqual "fix 3: the page really shows 4 windows" 4 [dict get $l4 windows]
checkEqual "fix 3: the token was cached for 4" 2x2 \
    [::ModelLoader::State::GetLayoutToken 4]
set triedTokens {}
foreach c [::fake::Find SetLayout] { lappend triedTokens [lindex $c 2] }
checkEqual "fix 3: the preferred token was the first and only try" {2x2} \
    $triedTokens
set l2 [::ModelLoader::Adapter::SetWindowCount 2]
checkEqual "fix 3: 2 windows use the wide 1x2" 1x2 [dict get $l2 layout]
checkEqual "fix 3: that token is remembered too" 1x2 \
    [::ModelLoader::State::GetLayoutToken 2]
set l6 [::ModelLoader::Adapter::SetWindowCount 6]
checkEqual "fix 3: 6 windows use 2x3" 2x3 [dict get $l6 layout]

# the 'Learn layouts' probe - it must not re-probe a count it already knows and
# it must put the original layout back afterwards
set learned [::ModelLoader::Adapter::LearnLayouts]
checkEqual "fix 3: LearnLayouts succeeded" 1 [dict get $learned ok]
checkEqual "fix 3: 6 was not probed again" 2x3 [dict get [dict get $learned learned] 6]
checkEqual "fix 3: 8 was learned as its transposed 4x2" 4x2 \
    [dict get [dict get $learned learned] 8]
checkEqual "fix 3: 9 was learned as 3x3" 3x3 [dict get [dict get $learned learned] 9]
checkEqual "fix 3: only the unknown counts were probed" {8 9 12 16} \
    [dict get $learned attempted]
checkEqual "fix 3: 12 and 16 have no token in this build" {12 16} \
    [dict get $learned skipped]
checkEqual "fix 3: the original layout is restored" 6 [dict get $learned restored]
checkEqual "fix 3: the page is back on 2x3" 2x3 \
    [::ModelLoader::State::GetLayoutToken 6]
check "fix 3: the report lists the counts without a token" \
    [string match "*No token found for: 12 16*" [dict get $learned message]]

# --- scenario 8 (fix 4): a legend is loaded from a *.tcl file ---------------
# A legend that HyperView saved IS a Tcl script, so the wizard sources it.  The
# fake hwi lets the script run and lets the 'legend on + redraw' follow-up
# succeed - with a real HyperView the file usually opens its own hwi stack, and
# that case is covered by the second legend below.
puts "  -- fix 4: sourcing a legend file"
::ModelLoader::State::ResetAll
set ::fake::calls {}
set legendOk [file join $here _selftest_legend_ok.tcl]
set fh [open $legendOk w]
puts $fh "# a legend saved by HyperView"
puts $fh "set ::selftestLegendRan 1"
close $fh
set ::selftestLegendRan 0
set legOk [::ModelLoader::Adapter::LoadLegendFromFile 1 $legendOk]
checkEqual "fix 4: the legend file is accepted" 1 [dict get $legOk ok]
checkEqual "fix 4: the sourced script really ran" 1 $::selftestLegendRan
checkEqual "fix 4: a *.tcl legend produces no warning" {} [dict get $legOk warnings]
checkEqual "fix 4: the window was redrawn" 1 [dict get $legOk redrawn]
checkEqual "fix 4: the legend was switched on" 1 \
    [llength [::fake::Find SetDisplayOptions]]
checkEqual "fix 4: with 'legend true'" {legend true} \
    [lrange [lindex [::fake::Find SetDisplayOptions] 0] 2 end]
checkEqual "fix 4: the window was drawn once" 1 [llength [::fake::Find Draw]]
check "fix 4: the message names the loaded file" \
    [string match "*Legend loaded from _selftest_legend_ok.tcl*" \
        [dict get $legOk message]]
checkEqual "fix 4: the result carries the normalised path" 1 \
    [expr {[string equal [dict get $legOk file] [file normalize $legendOk]] ? 1 : 0}]

set legendStack [file join $here _selftest_legend_stack.tcl]
set fh [open $legendStack w]
puts $fh "hwi OpenStack"
puts $fh "hwi CloseStack"
close $fh
set legStack [::ModelLoader::Adapter::LoadLegendFromFile 1 $legendStack]
checkEqual "fix 4: a legend with its own hwi stack works too" 1 \
    [dict get $legStack ok]
checkEqual "fix 4: and it is redrawn as well" 1 [dict get $legStack redrawn]

set legendOdd [file join $here _selftest_legend_odd.dat]
set fh [open $legendOdd w] ; puts $fh "set ::x 1" ; close $fh
set legOdd [::ModelLoader::Adapter::LoadLegendFromFile 1 $legendOdd]
checkEqual "fix 4: an unusual extension is only a warning" 1 [dict get $legOdd ok]
check "fix 4: the warning is handed back" \
    [string match "*unusual for a legend file*" [dict get $legOdd warnings]]

set legendBad [file join $here _selftest_legend_bad.tcl]
set fh [open $legendBad w] ; puts $fh "error \"boom\"" ; close $fh
set legBad [::ModelLoader::Adapter::LoadLegendFromFile 1 $legendBad]
checkEqual "fix 4: a legend that raises an error fails" 0 [dict get $legBad ok]
check "fix 4: the report names the Tcl error" \
    [string match "*could not be applied*boom*" [dict get $legBad message]]
check "fix 4: a failed legend is not redrawn" \
    [expr {[string first redrawn $legBad] < 0}]

# the legend is remembered per window (that is what step 2 reports in the tree)
checkEqual "fix 4: the legend file of window 1" $legendOk \
    [::ModelLoader::State::SetLegendFile 1 $legendOk]
checkEqual "fix 4: and it can be read back" $legendOk \
    [::ModelLoader::State::GetLegendFile 1]
checkEqual "fix 4: window 2 has no legend" "" \
    [::ModelLoader::State::GetLegendFile 2]

# --- scenario 9 (fix 5): PNG capture against a build with a limited API -----
# 'clientImage' and 'activeWindow' are refused by this build, only the screen
# capture works - so the wizard has to walk its candidate list, remember the form
# that worked and use it right away the next time.
puts "  -- fix 5: PNG capture (clientImage + activeWindow refused, screen works)"
::ModelLoader::State::ResetAll
::ModelLoader::State::WindowInit 1 page 0 loaded 1
::ModelLoader::State::WindowInit 2 page 0 loaded 1
set ::fake::calls {}
set ::fake::pngs {}
set ::fake::captureImageOk 0
set ::fake::captureActiveOk 0
set ::fake::captureScreenOk 1
set outPng [file join $here _selftest_png]
catch { file delete -force $outPng }
set views [::ModelLoader::Logic::ParseViewList "iso\nfront_left front\n"]
set capAll [::ModelLoader::Adapter::CapturePng all 1 $views $outPng]
checkEqual "fix 5: the capture succeeds" 1 [dict get $capAll ok]
checkEqual "fix 5: two windows x two views = four files" 4 [dict get $capAll captured]
checkEqual "fix 5: every job wrote a file" 4 [llength [dict get $capAll files]]
checkEqual "fix 5: nothing failed" 0 [dict get $capAll failed]
checkEqual "fix 5: the screen form was used" screen [dict get $capAll mode]
checkEqual "fix 5: the working form is cached" screen \
    [::ModelLoader::State::GetCaptureMode]
checkEqual "fix 5: the PNG files really exist" 4 \
    [llength [glob -nocomplain [file join $outPng *.png]]]
check "fix 5: the report names the folder and the count" \
    [string match "*4 file(s) written to*" [dict get $capAll message]]
checkEqual "fix 5: clientImage was probed for the first job only" 1 \
    [llength [::fake::Find CaptureImage]]
checkEqual "fix 5: activeWindow was probed for the first job only" 1 \
    [llength [::fake::Find CaptureActiveWindow]]
checkEqual "fix 5: the screen API wrote every file" 4 \
    [llength [::fake::Find CaptureScreen]]
set activeWins {}
foreach c [::fake::Find SetActiveWindow] { lappend activeWins [lindex $c 2] }
checkEqual "fix 5: both windows were made active" {1 2} $activeWins
set orientations {}
foreach c [::fake::Find SetOrientation] { lappend orientations [lindex $c 2] }
checkEqual "fix 5: both views were applied to both windows" \
    {iso front iso front} $orientations
checkEqual "fix 5: an orientation is followed by a Fit" 4 [llength [::fake::Find Fit]]
checkEqual "fix 5: every job redrew its window" 4 [llength [::fake::Find Draw]]

# second run: the remembered form is tried first, and 'target' captures one window
set capOne [::ModelLoader::Adapter::CapturePng target 1 $views $outPng]
checkEqual "fix 5: the target scope captures the target window" 2 \
    [dict get $capOne captured]
checkEqual "fix 5: the remembered form is used right away (still one probe)" 1 \
    [llength [::fake::Find CaptureImage]]
checkEqual "fix 5: the file names carry the window" \
    {w1_iso.png w1_front_left.png} \
    [list [file tail [lindex [dict get $capOne files] 0]] \
          [file tail [lindex [dict get $capOne files] 1]]]

# every form refused -> the run reports the failure, it does not throw
set ::fake::captureScreenOk 0
set capFail [::ModelLoader::Adapter::CapturePng target 1 {} $outPng]
checkEqual "fix 5: when every form is refused the run fails" 0 [dict get $capFail ok]
checkEqual "fix 5: nothing was captured" 0 [dict get $capFail captured]
checkEqual "fix 5: the failed job is counted" 1 [dict get $capFail failed]
checkEqual "fix 5: the mode stays empty" "" [dict get $capFail mode]
check "fix 5: the warning names the window" \
    [string match "*window 1*" [dict get $capFail warnings]]
checkEqual "fix 5: the folder was not left half written" 4 \
    [llength [glob -nocomplain [file join $outPng *.png]]]
set ::fake::captureScreenOk 1

# a view matrix / an orientation applied to one window
set ::fake::calls {}
::fake::Handle mlFakeWin
set wmsg [::ModelLoader::Adapter::ApplyViewEntry mlFakeWin \
    [dict create name m orientation "" \
        matrix {0.62 -0.39 0.69 0 0.35 0.91 -0.21 0 -0.7 -0.13 0.7 0 0 0 0 1}]]
checkEqual "fix 5: a view matrix is applied without a warning" {} $wmsg
# 'SetViewMatrix' takes the matrix as ONE argument (a list of 16 numbers),
# exactly like the shipped display_service.tcl calls it - so the argument itself
# has to carry all 16 numbers.
checkEqual "fix 5: the view got exactly one matrix argument" 1 \
    [expr {[llength [lindex [::fake::Find SetViewMatrix] 0]] - 2}]
checkEqual "fix 5: all 16 numbers of the matrix reach the view" 16 \
    [llength [lindex [::fake::Find SetViewMatrix] 0 2]]
checkEqual "fix 5: a matrix is not followed by a Fit" 0 [llength [::fake::Find Fit]]
set ::fake::calls {}
set wmsg2 [::ModelLoader::Adapter::ApplyViewEntry mlFakeWin \
    [dict create name i orientation iso matrix ""]]
checkEqual "fix 5: an orientation is applied without a warning" {} $wmsg2
checkEqual "fix 5: an orientation is followed by a Fit" 1 [llength [::fake::Find Fit]]
set ::fake::calls {}
checkEqual "fix 5: a view without orientation and matrix is skipped" {} \
    [::ModelLoader::Adapter::ApplyViewEntry mlFakeWin \
        [dict create name v orientation "" matrix ""]]
checkEqual "fix 5: a skipped view calls nothing" {0 0} \
    [list [llength [::fake::Find SetOrientation]] \
          [llength [::fake::Find SetViewMatrix]]]

foreach f [list $legendOk $legendStack $legendOdd $legendBad] {
    catch { file delete $f }
}
catch { file delete -force $outPng }
file delete $pureRes
# leave no trace of the fake API / fake handles
rename hwi {}
foreach h {mlSess mlProj mlPage mlWin mlClient mlModel mlResModel mlView mlFakeWin} {
    catch { rename $h {} }
}
unset -nocomplain ::selftestLegendRan
# the State was emptied by the scenarios above - bring the test data back
seedState
}

puts "== 5. UI layer (pure helpers only - no widget is created) ============"
checkEqual "KeepOrFirst keeps a valid value" b  [::ModelLoader::UI::KeepOrFirst b {a b c}]
checkEqual "KeepOrFirst falls back to the first" a [::ModelLoader::UI::KeepOrFirst z {a b c}]
checkEqual "KeepOrFirst on an empty list" {} [::ModelLoader::UI::KeepOrFirst z {}]
checkEqual "SimulationIndexFromChoice <default>" -1 \
    [::ModelLoader::UI::SimulationIndexFromChoice 1 1 {<default>}]
checkEqual "SimulationIndexFromChoice empty" -1 \
    [::ModelLoader::UI::SimulationIndexFromChoice 1 1 {}]
checkEqual "SimulationIndexFromChoice label" 1 \
    [::ModelLoader::UI::SimulationIndexFromChoice 1 1 {Sim 2}]

# the window-count / file-field helpers (no widget exists in this test, so the
# widget-first read falls back to the variable)
set ::ModelLoader::UI::varWindowCount 6
checkEqual "ReadWindowCount without a widget" 6 [::ModelLoader::UI::ReadWindowCount]
set ::ModelLoader::UI::varWindowCount not-a-number
checkEqual "ReadWindowCount rejects garbage" "" [::ModelLoader::UI::ReadWindowCount]
set ::ModelLoader::UI::varWindowCount 0
checkEqual "ReadWindowCount rejects zero" "" [::ModelLoader::UI::ReadWindowCount]
set ::ModelLoader::UI::varWindowCount 2
checkEqual "SetWindowCountValue returns the value" 3 \
    [::ModelLoader::UI::SetWindowCountValue 3]
checkEqual "SetWindowCountValue writes the variable" 3 $::ModelLoader::UI::varWindowCount
checkEqual "SetWindowCountValue remembers the good value" 3 \
    $::ModelLoader::UI::lastGoodWindowCount
checkEqual "WidgetText falls back without a widget" fallback \
    [::ModelLoader::UI::WidgetText "" fallback]
checkEqual "WidgetText returns the default for a missing widget" d \
    [::ModelLoader::UI::WidgetText .does.not.exist d]
set ::ModelLoader::UI::varModelFile ""
checkEqual "SetFileWidget writes the variable without a widget" /x/y.inp \
    [::ModelLoader::UI::SetFileWidget "" ::ModelLoader::UI::varModelFile {/x/y.inp}]
checkEqual "SetFileWidget really wrote it" /x/y.inp $::ModelLoader::UI::varModelFile

set ::ModelLoader::UI::varTargetWin  1
set ::ModelLoader::UI::varSubcase    {Subcase 1}
set ::ModelLoader::UI::varSimulation {Sim 2}
set ::ModelLoader::UI::varDataType   Stress
set ::ModelLoader::UI::varComponent  vonMises
set ::ModelLoader::UI::varAveraging  None
set ::ModelLoader::UI::varLayer      {<default>}
set uiSpec [::ModelLoader::UI::CurrentSpec]
checkEqual "CurrentSpec subcaseId"  1        [dict get $uiSpec subcaseId]
checkEqual "CurrentSpec sim index"  1        [dict get $uiSpec simulationIndex]
checkEqual "CurrentSpec data type"  Stress   [dict get $uiSpec dataType]
checkEqual "CurrentSpec component"  vonMises [dict get $uiSpec component]
set text [::ModelLoader::UI::DescribeSpec 1 $uiSpec]
check "DescribeSpec shows the simulation label" [string match "*Sim 2*" $text]
check "DescribeSpec shows the component"        [string match "*vonMises*" $text]
check "DescribeSpec shows the subcase label"    [string match "*Subcase 1*" $text]
set ::ModelLoader::UI::varSimulation {<default>}
check "DescribeSpec shows <default>" [string match "*<default>*" \
    [::ModelLoader::UI::DescribeSpec 1 [::ModelLoader::UI::CurrentSpec]]]

puts "== 6. validate step 1 refuses to continue without a model ============"
::ModelLoader::State::ResetAll
checkEqual "AnyModelLoaded on a fresh state" 0 [::ModelLoader::State::AnyModelLoaded]
checkEqual "ValidateStep1 rejects an empty state" 1 \
    [expr {[catch { ::ModelLoader::Logic::ValidateStep1 } msg1] == 1}]
check "the step 1 message explains the problem" \
    [string match "*no model has been loaded*" $msg1]

puts "== 7. layout and structure of the file ==============================="
set fh [open $wizard r]
set body [read $fh]
close $fh
foreach section {
    "SECTION 0 - BOOTSTRAP"
    "SECTION 1 - STATE / LOGIC LAYER"
    "SECTION 2 - HYPERVIEW ADAPTER LAYER"
    "SECTION 3 - UI LAYER"
    "SECTION 4 - PUBLIC ENTRY POINT"
    "SECTION 3a"
    "SECTION 3e"
    "SECTION 3f"
    "SECTION 3h"
} {
    check "section present: $section" [expr {[string first $section $body] >= 0}]
}
foreach tag {V1 V2 V3 V4 V5 V6 V7 V8 V9 V10 V11 V12 V13} {
    check "VERIFY note $tag present" [expr {[string first "$tag - VERIFY" $body] >= 0}]
}
foreach marker {"FIX 3" "FIX 4" "FIX 5"} {
    check "the fix marker $marker is documented" \
        [expr {[string first $marker $body] >= 0}]
}
check "the PLAIN TK exception is documented" \
    [expr {[string first "PLAIN TK" $body] >= 0}]
check "the entry point is documented in the header" \
    [expr {[string first "::ModelLoader::Show" $body] >= 0}]

# Every real (non comment) 'hwi' call has to live in the adapter section.
set lines [split $body "\n"]
set firstLine 1
set sec2 0
set sec3 0
for {set i 0} {$i < [llength $lines]} {incr i} {
    set ln [lindex $lines $i]
    if {[string first "SECTION 2 - HYPERVIEW ADAPTER LAYER" $ln] >= 0} { set sec2 [expr {$i + 1}] }
    if {[string first "SECTION 3 - UI LAYER" $ln] >= 0}          { set sec3 [expr {$i + 1}] }
}
check "adapter section before the UI section" [expr {$sec2 > 0 && $sec3 > $sec2}]
set leaked {}
for {set i 0} {$i < [llength $lines]} {incr i} {
    set ln [string trim [lindex $lines $i]]
    if {[string index $ln 0] eq "#"} { continue }
    if {![regexp {(^|[^A-Za-z0-9_])hwi([^A-Za-z0-9_]|$)} $ln]} { continue }
    set n [expr {$i + 1}]
    if {$n < $sec2 || $n >= $sec3} { lappend leaked $n }
}
checkEqual "every hwi call sits inside the adapter section" {} $leaked

puts "======================================================================"
puts " source test   : $::oks passed, $::fails failed"
if {$::fails == 0} {
    puts "ALL CHECKS PASSED"
    exit 0
}
puts "$::fails CHECK(S) FAILED"
exit 1




