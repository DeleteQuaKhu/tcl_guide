#=============================================================================
# selftest_ui_hv_model_loader.tcl
#
# GUI smoke test for hv_model_loader.tcl.
#
# HyperView itself cannot be started from a build machine, therefore this file
# replaces the hwtk package with thin stubs built on stock Tk widgets and runs
# the WHOLE widget construction code of the wizard against them.  That catches
# the errors that a source-only test cannot see: wrong widget paths, unknown
# widget options, grid/pack misuse, undefined variables, wrong # args in the
# event handlers, ...
#
# What is exercised
#   * Bootstrap          (hwtk::* present thanks to the stubs)
#   * UI::Build          (dialog, banner, steps, info pane, status line,
#                         both button bars: dialog insert and own fallback bar)
#   * UI::ShowStep 1/2, StepNext, StepBack
#   * UI::RefreshWindowList, UI::RefreshStep2
#   * the event handlers OnSubcaseChanged, OnDataTypeChanged,
#     OnApplyLayout, OnRefreshPage, OnLoadModel, OnRefreshWindow, OnApply
#   * UI::DoClose and a second Build after the close
#
# Everything the hwi adapter tries is reported as a warning by the wizard
# because no 'hwi' command exists here - that is intentional: it proves that
# every failure path is handled instead of aborting the GUI.
#
# Run with:  tclsh selftest_ui_hv_model_loader.tcl   (from this folder)
#=============================================================================

#-----------------------------------------------------------------------------
# tiny test framework (same output style as selftest_hv_model_loader.tcl)
#-----------------------------------------------------------------------------
set ::passed 0
set ::failed 0
proc ok {name {cond 1}} {
    if {[catch {expr {$cond}} res]} {
        incr ::failed
        puts "  FAIL  $name  (expr error: $res)"
        return 0
    }
    if {$res} {
        incr ::passed
        puts "  ok    $name"
        return 1
    }
    incr ::failed
    puts "  FAIL  $name"
    return 0
}
proc eq {name expected actual} {
    if {[string equal $expected $actual]} {
        incr ::passed
        puts "  ok    $name"
        return 1
    }
    incr ::failed
    puts "  FAIL  $name\n          expected: $expected\n          actual  : $actual"
    return 0
}
proc sec {title} { puts "" ; puts "== $title" }

#-----------------------------------------------------------------------------
# part 1 - the hwtk stand-in
#-----------------------------------------------------------------------------
namespace eval ::stub {
    variable insertApply  1        ;# 0 = dialog refuses 'insert apply'
    variable notes        {}
    variable widgets      {}
}
proc ::stub::note {msg} {
    lappend ::stub::notes $msg
    puts "  note  $msg"
}
# Creates a real Tk widget of type $base at $path and applies every option one
# by one.  An option that the stock Tk widget does not know is reported but
# does not stop the build.
proc ::stub::make {base path args} {
    if {![winfo exists $path]} { $base $path }
    foreach {opt val} $args {
        if {[catch { $path configure $opt $val } msg]} {
            ::stub::note "$base $path : option $opt not accepted ($msg)"
        }
    }
    lappend ::stub::widgets $path
    return $path
}

namespace eval ::hwtk {}
proc hwtk::frame      {path args} { ::stub::make ttk::frame      $path {*}$args }
proc hwtk::labelframe {path args} { ::stub::make ttk::labelframe $path {*}$args }
proc hwtk::label      {path args} { ::stub::make ttk::label      $path {*}$args }
proc hwtk::button     {path args} { ::stub::make ttk::button     $path {*}$args }
proc hwtk::entry      {path args} { ::stub::make ttk::entry      $path {*}$args }
proc hwtk::combobox   {path args} { ::stub::make ttk::combobox   $path {*}$args }
proc hwtk::checkbutton {path args} { ::stub::make ttk::checkbutton $path {*}$args }
proc hwtk::progressbar {path args} { ::stub::make ttk::progressbar $path {*}$args }

# hwtk::openfileentry is a composite widget: entry + browse button.
#-----------------------------------------------------------------------------
# the hwtk::dialog stand-in.
# A real toplevel is created, then the widget command is renamed away and the
# path itself becomes a method dispatcher (recess / insert / hide /
# buttonconfigure / post) - that is exactly how the wizard uses the dialog.
#-----------------------------------------------------------------------------
proc hwtk::dialog {path args} {
    array set o {-title "stub dialog"}
    array set o $args
    set tkcmd "${path}__tk"
    # a second hwtk::dialog call for the same path must not steal the widget
    # command again - the path is already a method dispatcher
    if {[llength [info commands ::$tkcmd]] > 0} { return $path }
    if {![winfo exists $path]} {
        toplevel $path
        wm title $path $o(-title)
    }
    # move the widget command out of the way ... (fully qualified names, so the
    # renamed command really lands in the global namespace)
    rename ::$path ::$tkcmd
    # ... and install the dispatcher IN THE GLOBAL namespace: proc resolves
    # relative names against the current namespace (::hwtk here), which would
    # create ::hwtk::.modelLoaderGUI instead of ::.modelLoaderGUI.
    uplevel #0 [list proc $path {method args} \
        [format {::stub::dialogMethod %s $method {*}$args} $path]]
    return $path
}

proc ::stub::dialogMethod {path method args} {
    switch -exact -- $method {
        recess {
            if {![winfo exists $path.recess]} { ttk::frame $path.recess }
            return $path.recess
        }
        insert {
            lassign $args sub name
            if {!$::stub::insertApply} {
                error "stub: this hwtk build does not support 'insert $sub'"
            }
            if {![winfo exists ${path}.btn_$name]} {
                ttk::button ${path}.btn_$name -text $name
            }
            return $name
        }
        hide { return "" }
        buttonconfigure {
            lassign $args name rest
            if {[winfo exists ${path}.btn_$name]} {
                if {[catch { ${path}.btn_$name configure {*}$rest } msg]} {
                    ::stub::note "dialog buttonconfigure $name : $msg"
                }
            }
            return ""
        }
        post { catch { wm deiconify $path } ; return "" }
        default { error "stub dialog $path: unsupported method '$method'" }
    }
}

#-----------------------------------------------------------------------------
# helpers used by the harness
#-----------------------------------------------------------------------------
proc exists {w} { expr {[winfo exists $w] ? 1 : 0} }
# Runs $script and reports an unexpected Tcl error.
proc runs {name script} {
    if {[catch { uplevel 1 $script } res]} {
        incr ::failed
        puts "  FAIL  $name\n          Tcl error: $res"
        return ""
    }
    incr ::passed
    puts "  ok    $name"
    return $res
}
proc textof {w} { catch { $w cget -text } t ; return $t }
proc valuesof {w} { catch { $w cget -values } v ; return $v }

proc hwtk::openfileentry {path args} {
    if {![winfo exists $path]} {
        ttk::frame $path
        ttk::entry $path.e
        ttk::button $path.b -text "..." -command { # browsing is not modelled }
        pack $path.e -side left -fill x -expand 1
        pack $path.b -side right
    }
    foreach {opt val} $args {
        switch -- $opt {
            -textvariable { $path.e configure -textvariable $val }
            -width        { $path.e configure -width $val }
            -filetypes    { }   ;# accepted but without any effect
            default       { ::stub::note "hwtk::openfileentry $path : option $opt is not modelled" }
        }
    }
    lappend ::stub::widgets $path
    return $path
}


#-----------------------------------------------------------------------------
# part 3 - the harness
#-----------------------------------------------------------------------------
package require Tk
wm withdraw .
# a modal message box would block a batch run, so it is logged instead
proc tk_messageBox {args} {
    ::stub::note "tk_messageBox was called (in HyperView a window would pop up)"
    return ok
}

set ::here [file dirname [file normalize [info script]]]

sec "0 - source the wizard"
runs "source hv_model_loader.tcl" {source [file join $::here hv_model_loader.tcl]}

sec "1 - Bootstrap with the hwtk stubs in place"
eq "Bootstrap returns 1" 1 [::ModelLoader::Bootstrap]

sec "2 - build the wizard (hwtk::dialog with a working 'insert apply')"
set ::stub::insertApply 1
eq "Show returns the dialog path" .modelLoaderGUI [::ModelLoader::Show]
ok "dialog window exists"                [exists .modelLoaderGUI]
ok "recess frame exists"                 [exists .modelLoaderGUI.recess]
ok "banner title label exists"           [exists .modelLoaderGUI.recess.head.title]
ok "banner help label exists"            [exists .modelLoaderGUI.recess.head.help]
ok "status line exists"                  [exists .modelLoaderGUI.recess.status]
ok "body frame exists"                   [exists .modelLoaderGUI.recess.body]
ok "step 1 frame exists"                 [exists .modelLoaderGUI.recess.body.step1]
ok "step 2 frame exists"                 [exists .modelLoaderGUI.recess.body.step2]
ok "information labelframe exists"       [exists .modelLoaderGUI.recess.info]
ok "information listbox exists"          [exists .modelLoaderGUI.recess.info.inner.lb]
ok "step 1 layout labelframe exists"     [exists .modelLoaderGUI.recess.body.step1.layout]
ok "step 1 load labelframe exists"       [exists .modelLoaderGUI.recess.body.step1.load]
ok "'Input Model' field exists"          [exists .modelLoaderGUI.recess.body.step1.load.model]
ok "'Input Model' browse button exists"  [exists .modelLoaderGUI.recess.body.step1.load.modelBrowse]
ok "'Input Result' field exists"         [exists .modelLoaderGUI.recess.body.step1.load.result]
ok "'Input Result' browse button exists" [exists .modelLoaderGUI.recess.body.step1.load.resultBrowse]
ok "reader entry exists"                 [exists .modelLoaderGUI.recess.body.step1.load.reader]
ok "step 1 load button exists"           [exists .modelLoaderGUI.recess.body.step1.load.load]
ok "step 2 contour labelframe exists"    [exists .modelLoaderGUI.recess.body.step2.contour]
ok "subcase combobox exists"             [exists .modelLoaderGUI.recess.body.step2.contour.subcase]
ok "simulation combobox exists"          [exists .modelLoaderGUI.recess.body.step2.contour.sim]
ok "data type combobox exists"           [exists .modelLoaderGUI.recess.body.step2.contour.dtype]
ok "component combobox exists"           [exists .modelLoaderGUI.recess.body.step2.contour.comp]
ok "averaging combobox exists"           [exists .modelLoaderGUI.recess.body.step2.contour.avg]
ok "layer combobox exists"               [exists .modelLoaderGUI.recess.body.step2.contour.layer]
ok "apply-all checkbutton exists"        [exists .modelLoaderGUI.recess.body.step2.contour.all]
ok "buttons went into the dialog box"    [exists {.modelLoaderGUI.btn_apply}]
ok "own button bar was NOT created"      [expr {[exists .modelLoaderGUI.recess.btnbar] ? 0 : 1}]
set s1seen [expr {[lsearch -exact [pack slaves .modelLoaderGUI.recess.body] \
    .modelLoaderGUI.recess.body.step1] >= 0 ? 1 : 0}]
set s2seen [expr {[lsearch -exact [pack slaves .modelLoaderGUI.recess.body] \
    .modelLoaderGUI.recess.body.step2] >= 0 ? 1 : 0}]
eq "step 1 is packed, step 2 is not" "1 0" "$s1seen $s2seen"
eq "step counter is 1" 1 $::ModelLoader::UI::step

sec "3 - status line, step switching and the information pane"
::ModelLoader::UI::SetStatus "hello status"
eq "status label follows its textvariable" "hello status" [$::ModelLoader::UI::wStatus cget -text]
runs "StepNext without any model does not throw" {::ModelLoader::UI::StepNext}
eq "StepNext without a model stays on step 1" 1 $::ModelLoader::UI::step
ok "a warning box was offered" [expr {[lsearch -regexp $::stub::notes {tk_messageBox}] >= 0}]
ok "information pane has content" [expr {[$::ModelLoader::UI::wInfo size] > 0}]
ok "target-window combobox got values" \
    [expr {[llength [valuesof $::ModelLoader::UI::wTargetWin]] >= 1}]

sec "4 - step 2 with a fabricated result tree (no hwi needed)"
# window 1 : two subcases, one with two simulations, two result types nested
runs "fabricate the state of window 1" {
    ::ModelLoader::State::WindowInit 1 page 0 \
        file {C:/models/big.op2} name big.op2 reader {} loaded 1 \
        subcases [list [list 101 {Subcase 1}] [list 102 {Subcase 2}]] \
        simulations [dict create 101 {Sim 1 Sim 2} 102 {Sim 1}] \
        datatypes [dict create 101 {Displacement Stress} 102 {Displacement}] \
        components [dict create \
            101 [dict create Displacement {X Y Z MAG} Stress {vonMises}] \
            102 [dict create Displacement {MAG}]]
}
runs "StepNext with a loaded model" {::ModelLoader::UI::StepNext}
eq "step counter is 2" 2 $::ModelLoader::UI::step
eq "step 2 header names the step" \
    "STEP 2 of 2 - Contour plot" [textof $::ModelLoader::UI::wStepTitle]
eq "model info line" "window 1 : big.op2" $::ModelLoader::UI::varModelInfo
# NOTE: cget -values returns the list in its Tcl list form, elements that
# contain a blank are braced - that is why the subcase labels appear braced.
eq "subcase combobox lists the labels" "{Subcase 1} {Subcase 2}" \
    [valuesof $::ModelLoader::UI::wSubcase]
eq "simulation combobox lists <default> + labels" "<default> Sim 1 Sim 2" \
    [valuesof $::ModelLoader::UI::wSimulation]
eq "data type combobox lists the types" "Displacement Stress" \
    [valuesof $::ModelLoader::UI::wDataType]
eq "component combobox lists the components" "X Y Z MAG" \
    [valuesof $::ModelLoader::UI::wComponent]

set ::ModelLoader::UI::varSubcase "Subcase 2"
runs "OnSubcaseChanged (user picked another subcase)" {::ModelLoader::UI::OnSubcaseChanged}
eq "data type list follows the subcase" "Displacement" \
    [valuesof $::ModelLoader::UI::wDataType]
eq "component list follows the type" "MAG" $::ModelLoader::UI::varComponent

set ::ModelLoader::UI::varSubcase "Subcase 1"
runs "switch back to the first subcase" {::ModelLoader::UI::OnSubcaseChanged}
eq "both result types are back" "Displacement Stress" \
    [valuesof $::ModelLoader::UI::wDataType]
eq "previously chosen component is kept" "MAG" \
    $::ModelLoader::UI::varComponent

set ::ModelLoader::UI::varDataType "Stress"
runs "OnDataTypeChanged (user picked another result type)" {::ModelLoader::UI::OnDataTypeChanged}
eq "component list follows the second type" "vonMises" \
    $::ModelLoader::UI::varComponent
set ::ModelLoader::UI::varDataType "Displacement"
set ::ModelLoader::UI::varComponent "X"
runs "ShowSpecPreview" {::ModelLoader::UI::ShowSpecPreview}
ok "the preview mentions the ready selection" \
    [expr {[lsearch -regexp [$::ModelLoader::UI::wInfo get 0 end] {ready : window 1}] >= 0}]

sec "5 - every action against the missing hwi (all failure paths)"
set ::ModelLoader::UI::varWindowCount 2
runs "OnApplyLayout does not throw" {::ModelLoader::UI::OnApplyLayout}
ok "the refused layout is reported" \
    [string match "Layout '2' was refused*" $::ModelLoader::UI::statusText]
set ::ModelLoader::UI::varWindowCount not-a-number
runs "OnApplyLayout rejects garbage input" {::ModelLoader::UI::OnApplyLayout}
ok "garbage input is reported" \
    [string match "Layout: 'not-a-number' is not a valid number of windows*" \
        $::ModelLoader::UI::statusText]
set ::ModelLoader::UI::varWindowCount 2

runs "OnRefreshPage does not throw" {::ModelLoader::UI::OnRefreshPage}
ok "the page failure was recorded" \
    [expr {[string length [::ModelLoader::State::GetLastError]] > 0}]

runs "OnRefreshWindow does not throw" {::ModelLoader::UI::OnRefreshWindow}
ok "the window failure is reported in the status line" \
    [string match "Window 1 could not be read:*" $::ModelLoader::UI::statusText]

set ::ModelLoader::UI::varFile ""
set ::ModelLoader::UI::varModelFile {C:/models/does_not_exist.inp}
set ::ModelLoader::UI::varReader ""
runs "OnLoadModel does not throw" {::ModelLoader::UI::OnLoadModel}
ok "the missing model file is reported before any hwi call" \
    [string match "Step 1: the file does not exist:*" $::ModelLoader::UI::statusText]
set ::ModelLoader::UI::varModelFile ""
set ::ModelLoader::UI::varResultFile {C:/results/does_not_exist.res}
runs "OnLoadModel with an empty model and a missing result" {::ModelLoader::UI::OnLoadModel}
ok "the missing result file is reported" \
    [string match "Step 1: the file does not exist:*" $::ModelLoader::UI::statusText]
set ::ModelLoader::UI::varResultFile ""
runs "OnLoadModel with both fields empty" {::ModelLoader::UI::OnLoadModel}
ok "the empty input is refused with a hint" \
    [string match "Step 1: choose an 'Input Model'*" $::ModelLoader::UI::statusText]

runs "OnApply does not throw" {::ModelLoader::UI::OnApply}
eq "the failed contour is counted" "Contour applied in 0 window(s), 1 failure(s)." \
    $::ModelLoader::UI::statusText

set ::ModelLoader::UI::varApplyAll 1
runs "OnApply with 'apply to all windows' on" {::ModelLoader::UI::OnApply}
set ::ModelLoader::UI::varApplyAll 0

runs "StepBack returns to step 1" {::ModelLoader::UI::StepBack}
eq "step counter is 1 again" 1 $::ModelLoader::UI::step
runs "StepNext returns to step 2" {::ModelLoader::UI::StepNext}
eq "step counter is 2 again" 2 $::ModelLoader::UI::step

sec "5b - fix 1: the 'windows on the active page' field keeps its value"
set ::ModelLoader::UI::varWindowCount 4
runs "SetWindowCountValue puts 4 into variable and widget" \
    {::ModelLoader::UI::SetWindowCountValue 4}
eq "the variable holds 4" 4 $::ModelLoader::UI::varWindowCount
eq "the combobox shows 4" 4 [$::ModelLoader::UI::wWindowCount get]
eq "ReadWindowCount reads the widget" 4 [::ModelLoader::UI::ReadWindowCount]

set ::ModelLoader::UI::varWindowCount 6
runs "the user picks 6 (<<ComboboxSelected>> / <Return> handler)" \
    {::ModelLoader::UI::OnWindowCountChanged}
eq "the picked number survives the handler" 6 $::ModelLoader::UI::varWindowCount
eq "the widget still shows 6" 6 [$::ModelLoader::UI::wWindowCount get]

runs "Apply layout with 6 (no hwi here -> refused)" {::ModelLoader::UI::OnApplyLayout}
eq "the refused layout does NOT reset the variable to 1" 6 \
    $::ModelLoader::UI::varWindowCount
eq "the refused layout does NOT reset the widget to 1" 6 \
    [$::ModelLoader::UI::wWindowCount get]
ok "the status line says that the value stays" \
    [string match "Layout '6' was refused*" $::ModelLoader::UI::statusText]

set ::ModelLoader::UI::varWindowCount 5
runs "a number that is not in the offered list" {::ModelLoader::UI::OnWindowCountChanged}
eq "the odd number is kept in the variable" 5 $::ModelLoader::UI::varWindowCount
ok "5 was added to the offered values" \
    [expr {[lsearch -exact [valuesof $::ModelLoader::UI::wWindowCount] 5] >= 0}]

set ::ModelLoader::UI::varWindowCount not-a-number
runs "garbage is reverted to the last good number" {::ModelLoader::UI::OnWindowCountChanged}
eq "the last good number is back" 5 $::ModelLoader::UI::varWindowCount

# the 'Target window' field must not be reset to 1 either
set ::ModelLoader::UI::varTargetWin 3
runs "RefreshWindowList while the page cannot be read" {::ModelLoader::UI::RefreshWindowList}
eq "the target window keeps the user's choice" 3 $::ModelLoader::UI::varTargetWin
eq "the target-window widget shows 3" 3 [$::ModelLoader::UI::wTargetWin get]
eq "OnTargetWindowChanged reads the widget" 3 [::ModelLoader::UI::OnTargetWindowChanged]
set ::ModelLoader::UI::varTargetWin 1
set ::ModelLoader::UI::varWindowCount 2

sec "5c - fix 2: 'Input Model' offers *.inp, 'Input Result' offers *.res"
set mTypes [::ModelLoader::Logic::ModelFileTypes]
set rTypes [::ModelLoader::Logic::ResultFileTypes]
ok "the model filter starts with the Abaqus *.inp entry" \
    [string match "*Abaqus Input Files*.inp*" [lindex $mTypes 0]]
ok "*.inp is in the model filter" [string match "*.inp*" $mTypes]
ok "the result filter starts with the FEMFAT *.res entry" \
    [string match "*FEMFAT Result Files*.res*" [lindex $rTypes 0]]
ok "*.res is in the result filter" [string match "*.res*" $rTypes]
ok "the model filter did not lose the model formats" \
    [expr {[string match "*.h3d*" $mTypes] && [string match "*.bdf*" $mTypes] ? 1 : 0}]
ok "the result filter still lists the other result formats" \
    [expr {[string match "*.op2*" $rTypes] && [string match "*.odb*" $rTypes] ? 1 : 0}]
ok "both filters end with an 'All Files' entry" \
    [expr {[string match "*All Files*" $mTypes] && [string match "*All Files*" $rTypes] ? 1 : 0}]
eq "the reader hint for a FEMFAT file" "FEMFAT Result Reader" \
    [::ModelLoader::Logic::ReaderHint {C:/r/part.res}]
eq "the reader hint for an Abaqus input deck" "Abaqus Input Reader" \
    [::ModelLoader::Logic::ReaderHint {C:/m/part.inp}]

# --- path post-processing ---------------------------------------------------
set okInp  [file join $::here _selftest_dummy.inp]
set okRes  [file join $::here _selftest_dummy.res]
set oddTxt [file join $::here _selftest_dummy.txt]
foreach f [list $okInp $okRes $oddTxt] {
    set fh [open $f w] ; puts $fh "dummy" ; close $fh
}
set chk [::ModelLoader::Logic::CheckChosenFile $okInp model]
eq "an existing *.inp is accepted as a model" 1 [dict get $chk ok]
eq "and it is normalised" [file normalize $okInp] [dict get $chk path]
eq "no warning for *.inp" "" [dict get $chk message]
set chkRes [::ModelLoader::Logic::CheckChosenFile $okRes result]
eq "an existing *.res is accepted as a result" 1 [dict get $chkRes ok]
set chkBad [::ModelLoader::Logic::CheckChosenFile {C:/nope/missing.inp} model]
eq "a missing file is refused" 0 [dict get $chkBad ok]
set chkOdd [::ModelLoader::Logic::CheckChosenFile $oddTxt model]
eq "an unusual extension is only a warning" 1 [dict get $chkOdd ok]
ok "the warning explains itself" [expr {[dict get $chkOdd message] ne ""}]
eq "an empty path is refused" 0 \
    [dict get [::ModelLoader::Logic::CheckChosenFile "" model] ok]

# ApplyChosenFile writes the normalised path back into variable and widget
runs "ApplyChosenFile on the model field" \
    {::ModelLoader::UI::ApplyChosenFile $::ModelLoader::UI::wModelFile \
        ::ModelLoader::UI::varModelFile model $okInp}
eq "the model variable holds the path" [file normalize $okInp] \
    $::ModelLoader::UI::varModelFile
ok "the status line names the chosen file" \
    [string match "Chosen model file:*" $::ModelLoader::UI::statusText]
runs "ApplyChosenFile on the result field" \
    {::ModelLoader::UI::ApplyChosenFile $::ModelLoader::UI::wResultFile \
        ::ModelLoader::UI::varResultFile result $okRes}
eq "the result variable holds the path" [file normalize $okRes] \
    $::ModelLoader::UI::varResultFile
eq "the reader suggestion is shown" 1 \
    [string match "*FEMFAT Result Reader*" $::ModelLoader::UI::statusText]
runs "ApplyChosenFile with a missing file" \
    {::ModelLoader::UI::ApplyChosenFile $::ModelLoader::UI::wModelFile \
        ::ModelLoader::UI::varModelFile model {C:/nope/missing.inp}}
ok "a rejected file is reported" \
    [string match "Model file rejected:*" $::ModelLoader::UI::statusText]

# both paths reach the adapter (which then fails, because hwi is missing)
set ::ModelLoader::UI::varModelFile [file normalize $okInp]
set ::ModelLoader::UI::varResultFile [file normalize $okRes]
runs "OnLoadModel with two existing files" {::ModelLoader::UI::OnLoadModel}
ok "the hwi failure of the load is reported" \
    [string match "Loading failed:*" $::ModelLoader::UI::statusText]
set ::ModelLoader::UI::varModelFile ""
set ::ModelLoader::UI::varResultFile ""
foreach f [list $okInp $okRes $oddTxt] { catch { file delete $f } }

sec "6 - own button bar (hwtk build without 'insert apply')"
runs "DoClose destroys the dialog" {::ModelLoader::UI::DoClose}
ok "the dialog window is gone" [expr {[exists .modelLoaderGUI] ? 0 : 1}]
set ::stub::insertApply 0
eq "a second Show builds again" .modelLoaderGUI [::ModelLoader::Show]
ok "own button bar exists now"   [exists .modelLoaderGUI.recess.btnbar]
ok "own Back button exists"      [exists .modelLoaderGUI.recess.btnbar.back]
ok "own Next button exists"      [exists .modelLoaderGUI.recess.btnbar.next]
ok "own Apply button exists"     [exists .modelLoaderGUI.recess.btnbar.apply]
ok "own Close button exists"     [exists .modelLoaderGUI.recess.btnbar.close]
ok "no dialog button this time"  [expr {[exists .modelLoaderGUI.btn_apply] ? 0 : 1}]
runs "SetButtonState on the own bar" {::ModelLoader::UI::SetButtonState Next disabled}
eq "own Next button is disabled" disabled \
    [.modelLoaderGUI.recess.btnbar.next cget -state]
runs "SetButtonState back to normal" {::ModelLoader::UI::SetButtonState Next normal}
eq "own Next button is normal again" normal \
    [.modelLoaderGUI.recess.btnbar.next cget -state]
runs "ShowStep 2 on the second build" {::ModelLoader::UI::ShowStep 2}
runs "final DoClose" {::ModelLoader::UI::DoClose}
ok "dialog closed at the end" [expr {[exists .modelLoaderGUI] ? 0 : 1}]

sec "7 - summary"
puts ""
puts "=============================================================="
puts " UI smoke test : $::passed passed, $::failed failed"
puts " stub notes    : [llength $::stub::notes] (unmodelled options,"
puts "                 pop-up windows and the missing hwi - expected)"
puts "=============================================================="
exit [expr {$::failed == 0 ? 0 : 1}]

