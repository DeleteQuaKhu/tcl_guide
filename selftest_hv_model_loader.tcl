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

proc check {label condition} {
    if {[expr {$condition}]} {
        puts "  ok   : $label"
    } else {
        puts "  FAIL : $label"
        incr ::fails
    }
}
proc checkEqual {label expected actual} {
    if {$expected eq $actual} {
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
set missing {}
foreach p {
    ::ModelLoader::Bootstrap
    ::ModelLoader::Show ::mlShow
    ::ModelLoader::State::WindowInit ::ModelLoader::State::WindowSet
    ::ModelLoader::State::WindowGet ::ModelLoader::State::WindowExists
    ::ModelLoader::State::PruneTo ::ModelLoader::State::LoadedWindows
    ::ModelLoader::State::WindowIndices ::ModelLoader::State::AnyModelLoaded
    ::ModelLoader::State::SetLayoutToken ::ModelLoader::State::GetLayoutToken
    ::ModelLoader::State::SetLastError ::ModelLoader::State::GetLastError
    ::ModelLoader::State::ResetAll
    ::ModelLoader::Logic::LayoutCandidates ::ModelLoader::Logic::MakeSpec
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
    ::ModelLoader::Adapter::ApplyContour
    ::ModelLoader::UI::Build ::ModelLoader::UI::BuildStep1 ::ModelLoader::UI::BuildStep2
    ::ModelLoader::UI::ShowStep ::ModelLoader::UI::StepNext ::ModelLoader::UI::StepBack
    ::ModelLoader::UI::RefreshStep2 ::ModelLoader::UI::RefreshWindowList
    ::ModelLoader::UI::OnApplyLayout ::ModelLoader::UI::OnRefreshPage
    ::ModelLoader::UI::OnLoadModel ::ModelLoader::UI::OnRefreshWindow
    ::ModelLoader::UI::OnApply ::ModelLoader::UI::Post ::ModelLoader::UI::DoClose
    ::ModelLoader::UI::CurrentSpec ::ModelLoader::UI::DescribeSpec
    ::ModelLoader::UI::KeepOrFirst ::ModelLoader::UI::SimulationIndexFromChoice
} {
    if {[llength [info commands $p]] == 0} { lappend missing $p }
}
checkEqual "every expected procedure exists" {} $missing
checkEqual "debug switch initialised" 0 $::ModelLoader::debug

puts "== 2. State layer ===================================================="
::ModelLoader::State::ResetAll
::ModelLoader::State::WindowInit 1 page 0 file {C:/x/model.h3d} reader {} \
    name model.h3d loaded 1 \
    subcases {{1 {Subcase 1}} {2 {Subcase 2}}} \
    simulations [dict create 1 [list {Sim 1} {Sim 2}]] \
    datatypes [dict create 1 [list Stress Displacement]] \
    components [dict create 1 [dict create Stress {vonMises P1}]]
::ModelLoader::State::WindowInit 2 page 0 loaded 1 subcases {{7 {Subcase 2}}}
::ModelLoader::State::WindowInit 3 page 0 loaded 0

checkEqual "WindowGet name"              model.h3d [::ModelLoader::State::WindowGet 1 name]
checkEqual "WindowGet returns a default" 9         [::ModelLoader::State::WindowGet 91 subcases 9]
checkEqual "WindowExists"                1         [::ModelLoader::State::WindowExists 3]
checkEqual "WindowExists free slot"      0         [::ModelLoader::State::WindowExists 91]
checkEqual "LoadedWindows"               {1 2}     [::ModelLoader::State::LoadedWindows]
checkEqual "WindowIndices"               {1 2 3}   [::ModelLoader::State::WindowIndices]
checkEqual "AnyModelLoaded"              1         [::ModelLoader::State::AnyModelLoaded]
checkEqual "WindowSet writes"            X         [::ModelLoader::State::WindowSet 3 reader X]
checkEqual "WindowSet is readable"       X         [::ModelLoader::State::WindowGet 3 reader]
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

::ModelLoader::State::SetLayoutToken 4 "my token"
set cand [::ModelLoader::Logic::LayoutCandidates 4]
check "LayoutCandidates keeps the cached token" \
    [expr {[lsearch -exact $cand "my token"] >= 0}]
foreach want {2x2 1x4 4x1 4} {
    check "LayoutCandidates 4 contains $want" [expr {[lsearch -exact $cand $want] >= 0}]
}
checkEqual "LayoutCandidates is unique" [llength $cand] [llength [lsort -unique $cand]]

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
    "SECTION 3f"
} {
    check "section present: $section" [expr {[string first $section $body] >= 0}]
}
foreach tag {V1 V2 V3 V4 V5 V6 V7 V8 V9} {
    check "VERIFY note $tag present" [expr {[string first "$tag - VERIFY" $body] >= 0}]
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
if {$::fails == 0} {
    puts "ALL CHECKS PASSED"
    exit 0
}
puts "$::fails CHECK(S) FAILED"
exit 1




