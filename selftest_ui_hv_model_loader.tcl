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
#   * UI::ShowStep 1/2/3, StepNext, StepBack
#   * UI::RefreshWindowList, UI::RefreshStep2, UI::RefreshStep3
#   * the event handlers OnSubcaseChanged, OnDataTypeChanged, OnLoadLegend,
#     OnImportViewList, OnCapture, OnApplyLayout, OnRefreshPage, OnLoadModel,
#     OnRefreshWindow, OnApply
#   * the five fixes : 1 (the window count keeps its value), 2 (the file
#     filters), 3 (layout token order + the 'Learn layouts' probe), 4 (the
#     legend file of step 2), 5 (view list, PNG folder, PNG capture plan)
#   * UI::DoClose and a second Build after the close
#
# Everything the hwi adapter tries is reported as a warning by the wizard
# because no 'hwi' command exists here - that is intentional: it proves that
# every failure path is handled instead of aborting the GUI.
#
# Run with:  tclsh selftest_ui_hv_model_loader.tcl   (from this folder)
# A build machine usually has no tclsh with Tk, but the very same file can be
# run with the Tcl/Tk that comes with Python (see run_ui_selftest.py):
#     python run_ui_selftest.py selftest_ui_hv_model_loader.tcl
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
            # name + the whole option list - 'lassign $args name rest' would put
            # only the SECOND element into rest and '-state disabled' (or
            # '-text ... -command ...') would be truncated to '-state'.
            lassign $args name
            set rest [lrange $args 1 end]
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
# 1 when any line of the information pane matches the regular expression
proc infohas {pattern} {
    expr {[lsearch -regexp [$::ModelLoader::UI::wInfo get 0 end] $pattern] >= 0 ? 1 : 0}
}

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
ok "step 3 frame exists"                 [exists .modelLoaderGUI.recess.body.step3]
eq "the banner names step 1 of 3" "STEP 1 of 3 - Page layout and model loading" \
    [textof $::ModelLoader::UI::wStepTitle]
ok "information labelframe exists"       [exists .modelLoaderGUI.recess.info]
ok "information listbox exists"          [exists .modelLoaderGUI.recess.info.inner.lb]
ok "step 1 layout labelframe exists"     [exists .modelLoaderGUI.recess.body.step1.layout]
ok "step 1 load labelframe exists"       [exists .modelLoaderGUI.recess.body.step1.load]
ok "'Input Model' field exists"          [exists .modelLoaderGUI.recess.body.step1.load.model]
ok "'Input Model' browse button exists"  [exists .modelLoaderGUI.recess.body.step1.load.modelBrowse]
ok "'Input Result' field exists"         [exists .modelLoaderGUI.recess.body.step1.load.result]
ok "'Input Result' browse button exists" [exists .modelLoaderGUI.recess.body.step1.load.resultBrowse]
ok "the reader entry is gone (fix 2)" \
    [expr {[exists .modelLoaderGUI.recess.body.step1.load.reader] ? 0 : 1}]
ok "an auto-detection note is shown instead" \
    [string match "*detected automatically*" \
        [textof .modelLoaderGUI.recess.body.step1.load.l3]]
ok "step 1 load button exists"           [exists .modelLoaderGUI.recess.body.step1.load.load]
ok "step 2 contour labelframe exists"    [exists .modelLoaderGUI.recess.body.step2.contour]
ok "subcase combobox exists"             [exists .modelLoaderGUI.recess.body.step2.contour.subcase]
ok "simulation combobox exists"          [exists .modelLoaderGUI.recess.body.step2.contour.sim]
ok "data type combobox exists"           [exists .modelLoaderGUI.recess.body.step2.contour.dtype]
ok "component combobox exists"           [exists .modelLoaderGUI.recess.body.step2.contour.comp]
ok "averaging combobox exists"           [exists .modelLoaderGUI.recess.body.step2.contour.avg]
ok "layer combobox exists"               [exists .modelLoaderGUI.recess.body.step2.contour.layer]
ok "apply-all checkbutton exists"        [exists .modelLoaderGUI.recess.body.step2.contour.all]
# --- fix 4 : the legend field of step 2 --------------------------------------
ok "step 2 legend labelframe exists"     [exists .modelLoaderGUI.recess.body.step2.legend]
ok "legend file field exists"            [exists .modelLoaderGUI.recess.body.step2.legend.legend]
ok "legend browse button exists"         [exists .modelLoaderGUI.recess.body.step2.legend.legendBrowse]
ok "'Load legend' button exists"         [exists .modelLoaderGUI.recess.body.step2.legend.load]
# --- fix 5 : the widgets of step 3 ------------------------------------------
ok "step 3 view-list labelframe exists"  [exists .modelLoaderGUI.recess.body.step3.views]
ok "view list field exists"              [exists .modelLoaderGUI.recess.body.step3.views.viewlist]
ok "'Import views' button exists"        [exists .modelLoaderGUI.recess.body.step3.views.import]
ok "the view list info label exists"     [exists .modelLoaderGUI.recess.body.step3.views.info]
ok "step 3 output labelframe exists"     [exists .modelLoaderGUI.recess.body.step3.output]
ok "the output folder entry exists"      [exists .modelLoaderGUI.recess.body.step3.output.dir]
ok "the folder browse button exists"     [exists .modelLoaderGUI.recess.body.step3.output.browse]
ok "step 3 capture labelframe exists"    [exists .modelLoaderGUI.recess.body.step3.capture]
ok "the scope combobox exists"           [exists .modelLoaderGUI.recess.body.step3.capture.scope]
ok "'Capture target' button exists"      [exists .modelLoaderGUI.recess.body.step3.capture.bTarget]
ok "'Capture all' button exists"         [exists .modelLoaderGUI.recess.body.step3.capture.bAll]
eq "the scope combobox offers target and all" "target all" \
    [valuesof $::ModelLoader::UI::wCaptureScope]
ok "buttons went into the dialog box"    [exists {.modelLoaderGUI.btn_apply}]
ok "own button bar was NOT created"      [expr {[exists .modelLoaderGUI.recess.btnbar] ? 0 : 1}]
# the dialog stand-in must really apply 'buttonconfigure -text -command -state':
# a stand-in that drops them would hide a broken or unwired wizard button.
eq "the Next button carries its label" "Next >" [.modelLoaderGUI.btn_next cget -text]
eq "the Back button carries its label" "< Back" [.modelLoaderGUI.btn_back cget -text]
ok "the Next button is wired to StepNext" \
    [string match "*StepNext*" [.modelLoaderGUI.btn_next cget -command]]
eq "Back is disabled on step 1" disabled [.modelLoaderGUI.btn_back cget -state]
eq "Next is enabled on step 1" normal [.modelLoaderGUI.btn_next cget -state]
eq "Apply is disabled on step 1" disabled [.modelLoaderGUI.btn_apply cget -state]
eq "the dialog refused no buttonconfigure" {} \
    [lsearch -all -regexp $::stub::notes {buttonconfigure}]
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
        file {C:/models/big.op2} name big.op2 loaded 1 \
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
    "STEP 2 of 3 - Contour plot and legend" [textof $::ModelLoader::UI::wStepTitle]
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
# the report of the action must SURVIVE the pane refresh of the same handler
# (RefreshWindowList replaces the whole pane - an AppendInfo before it is lost)
ok "the refusal reached the information pane" [infohas {requested - refused:}]
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
ok "the re-read report survives the pane refresh" [infohas {RE-READ WINDOW 1}]

set ::ModelLoader::UI::varFile ""
set ::ModelLoader::UI::varModelFile {C:/models/does_not_exist.inp}
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

# the pure helper behind fix 1: HyperView answers with a NUMBER, some builds hand
# out the list of window indices - both have to give the real count
eq "InterpretWindowCount on the scalar 4" 4 \
    [::ModelLoader::Logic::InterpretWindowCount 4]
eq "InterpretWindowCount on '1 2 3 4'" 4 \
    [::ModelLoader::Logic::InterpretWindowCount {1 2 3 4}]
ok "llength alone answers 1 for the scalar 4 (the old bug)" \
    [expr {[llength 4] == 1 ? 1 : 0}]

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

# FIX 2: the hint is only printed as a note - the wizard has no reader entry any
# more and never hands a reader label to HyperView
ok "no varReader UI variable exists any more" \
    [expr {[llength [info vars ::ModelLoader::UI::varReader]] == 0}]
ok "no reader widget variable exists any more" \
    [expr {[llength [info vars ::ModelLoader::UI::wReader]] == 0}]
ok "the ReaderHint helper survived (status-line hint only)" \
    [expr {[llength [info commands ::ModelLoader::Logic::ReaderHint]] == 1}]

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
ok "the load report survives the pane refresh" [infohas {LOAD INTO WINDOW 1}]
set ::ModelLoader::UI::varModelFile ""
set ::ModelLoader::UI::varResultFile ""
foreach f [list $okInp $okRes $oddTxt] { catch { file delete $f } }

sec "5d - fix 3: layout token order, the cache and the 'Learn layouts' probe"
# The old candidate builder ended with 'lsort -unique', which threw the
# preferred arrangement away.  The preferred one has to come FIRST, and a token
# that HyperView really accepted wins over every guess.
set cand4 [::ModelLoader::Logic::LayoutCandidates 4]
eq "the preferred token of a 4 window page comes first" 2x2 [lindex $cand4 0]
eq "the candidate list has no duplicates" \
    [llength [lsort -unique $cand4]] [llength $cand4]
ok "the plain count is still tried" [expr {[lsearch -exact $cand4 4] >= 0}]
ok "the legacy tokens are still tried" \
    [expr {[lsearch -exact $cand4 2H] >= 0 && [lsearch -exact $cand4 single] >= 0}]
eq "no candidate for a nonsense count" {} [::ModelLoader::Logic::LayoutCandidates 0]

runs "a learned token is remembered" \
    {::ModelLoader::State::SetLayoutToken 4 My4}
eq "the learned token is read back" My4 [::ModelLoader::State::GetLayoutToken 4]
eq "the learned token moved to the front" My4 \
    [lindex [::ModelLoader::Logic::LayoutCandidates 4] 0]
eq "the learned token is offered only once" 1 \
    [llength [lsearch -all -exact [::ModelLoader::Logic::LayoutCandidates 4] My4]]
eq "the token map holds the count" My4 \
    [dict get [::ModelLoader::State::LayoutTokenMap] 4]
runs "forget the token again" {::ModelLoader::State::SetLayoutToken 4 ""}
eq "the preferred guess is first again" 2x2 \
    [lindex [::ModelLoader::Logic::LayoutCandidates 4] 0]
eq "and the map is empty again" {} [::ModelLoader::State::LayoutTokenMap]

# the probe never shrinks the page (a smaller layout loses the models of the
# closed windows) - it only visits counts >= the current one
eq "the probe order of a 4 window page" "4 6 8 9 12 16" \
    [::ModelLoader::Logic::LayoutProbeOrder 4]
eq "the probe order starts at the current count" "6 8 9 12 16" \
    [::ModelLoader::Logic::LayoutProbeOrder 5]
eq "the probe order respects a custom choice list" "2 4" \
    [::ModelLoader::Logic::LayoutProbeOrder 2 {1 2 4}]
eq "the probe order of the largest count" 16 \
    [::ModelLoader::Logic::LayoutProbeOrder 16]

# Adapter::LearnLayouts needs hwi - without it the failure is REPORTED, never
# thrown, and nothing is learned
set learn [::ModelLoader::Adapter::LearnLayouts]
eq "the probe reports the unreadable page" 0 [dict get $learn ok]
ok "and it names the reason" \
    [string match "Cannot read the active page:*" [dict get $learn message]]
eq "nothing was learned" {} [dict get $learn learned]
eq "no token was applied" {} [dict get $learn attempted]
eq "the restore position is unknown" -1 [dict get $learn restored]

# ... and the probe has its own button in step 1.  The button and its handler
# have to work on a page that cannot be read, too (that is the case here - no
# hwi), so the failure is reported instead of being thrown at the GUI.
ok "the 'Learn layouts' button exists" [exists $::ModelLoader::UI::wStep1.layout.learn]
eq "the button carries its label" "Learn layouts" \
    [textof $::ModelLoader::UI::wStep1.layout.learn]
ok "the button is wired to OnLearnLayouts" \
    [string match "*OnLearnLayouts*" \
        [$::ModelLoader::UI::wStep1.layout.learn cget -command]]
runs "OnLearnLayouts does not throw without hwi" {::ModelLoader::UI::OnLearnLayouts}
ok "the failed probe is reported in the status line" \
    [string match "Learn layouts:*Cannot read the active page*" \
        $::ModelLoader::UI::statusText]
ok "the information pane names the failed probe" [infohas {the probe did not run}]
eq "the failed probe left no token behind" {} \
    [::ModelLoader::State::GetLayoutToken 4]

sec "5e - fix 4: the legend file of step 2 ('Load legend')"
eq "the legend filter starts with the Tcl entry" 1 \
    [string match "*Legend Tcl Scripts*.tcl*" \
        [lindex [::ModelLoader::Logic::LegendFileTypes] 0]]
ok "the legend filter knows *.hvl" \
    [string match "*.hvl*" [::ModelLoader::Logic::LegendFileTypes]]
eq "the legend extensions are declared" ".tcl .hvl .txt" \
    [::ModelLoader::Logic::LegendExtensions]

set legOK    [file join $::here _selftest_legend_ok.tcl]
set legBad   [file join $::here _selftest_legend_bad.tcl]
set legEmpty [file join $::here _selftest_legend_empty.tcl]
set fh [open $legOK w] ; puts $fh "# selftest legend" ; \
    puts $fh {set ::mlLegendMarker ok} ; close $fh
set fh [open $legBad w] ; puts $fh {error "boom"} ; close $fh
set fh [open $legEmpty w] ; close $fh

# an empty field is refused with a hint before anything else happens
set ::ModelLoader::UI::varLegendFile ""
runs "OnLoadLegend with an empty field does not throw" {::ModelLoader::UI::OnLoadLegend}
eq "an empty legend field is refused" "Choose a legend file first." \
    $::ModelLoader::UI::statusText

# a legend file that does not exist is refused by the adapter
set ::ModelLoader::UI::varLegendFile {C:/no/such/legend.tcl}
runs "OnLoadLegend with a missing file" {::ModelLoader::UI::OnLoadLegend}
ok "the missing legend file is reported in the status line" \
    [string match "Legend: Legend file not found:*" $::ModelLoader::UI::statusText]
ok "the failure also reached the information pane" \
    [infohas {FAILED - Legend file not found}]

set ::ModelLoader::UI::varLegendFile $legEmpty
runs "OnLoadLegend with an empty file" {::ModelLoader::UI::OnLoadLegend}
ok "the empty legend file is reported" \
    [string match "Legend: The legend file * is empty.*" $::ModelLoader::UI::statusText]

set ::ModelLoader::UI::varLegendFile $legBad
runs "OnLoadLegend with a broken legend script" {::ModelLoader::UI::OnLoadLegend}
ok "the broken legend script is reported" \
    [string match "Legend: The legend file could not be applied:*" \
        $::ModelLoader::UI::statusText]
ok "the Tcl error of the script is shown" \
    [string match "*boom*" $::ModelLoader::UI::statusText]

# the happy path: a saved legend IS a Tcl script, so it is sourced.  The
# switch-on + redraw afterwards needs hwi and stays a warning in this harness.
set ::mlLegendMarker ""
set ::ModelLoader::UI::varLegendFile $legOK
runs "OnLoadLegend with a readable legend script" {::ModelLoader::UI::OnLoadLegend}
eq "the legend script was really sourced" ok $::mlLegendMarker
eq "the legend file is remembered for the window" [file normalize $legOK] \
    [::ModelLoader::State::GetLegendFile 1]
ok "the loaded legend is reported" \
    [string match "Legend loaded from _selftest_legend_ok.tcl*" \
        $::ModelLoader::UI::statusText]
ok "the missing hwi redraw is a warning, not an error" \
    [string match "*(with warnings)*" $::ModelLoader::UI::statusText]
ok "the modelLoader kept the window number" \
    [string match "* (window 1)" $::ModelLoader::UI::statusText]
ok "the legend section is in the information pane" [infohas {LEGEND \(step 2\)}]
ok "the window is named in the pane" [infohas {window 1 : OK - Legend loaded from}]
eq "the normalised path went back into the field" [file normalize $legOK] \
    $::ModelLoader::UI::varLegendFile
set ::ModelLoader::UI::varLegendFile ""
foreach f [list $legOK $legBad $legEmpty] { catch { file delete $f } }
ok "the legend temporaries are gone" \
    [expr {[file exists $legOK] ? 0 : 1}]

sec "5f - fix 5: the step navigation and the view list of step 3"
runs "StepNext from step 2 reaches step 3" {::ModelLoader::UI::StepNext}
eq "the step counter is 3" 3 $::ModelLoader::UI::step
eq "the banner names step 3 of 3" "STEP 3 of 3 - Capture PNG" \
    [textof $::ModelLoader::UI::wStepTitle]
set body [list .modelLoaderGUI.recess.body.step1 .modelLoaderGUI.recess.body.step2 \
    .modelLoaderGUI.recess.body.step3]
set packed {}
foreach f $body {
    lappend packed [expr {[lsearch -exact [pack slaves .modelLoaderGUI.recess.body] $f] >= 0
        ? 1 : 0}]
}
eq "only step 3 is packed now" "0 0 1" $packed
eq "'Next' is disabled on the last step" disabled \
    [.modelLoaderGUI.btn_next cget -state]
runs "StepNext on the last step does nothing" {::ModelLoader::UI::StepNext}
eq "the step counter is still 3" 3 $::ModelLoader::UI::step

# --- what ShowStep 3 / RefreshStep3 shows ------------------------------------
eq "the view list info starts empty" "no view list imported - one PNG per window" \
    $::ModelLoader::UI::varViewListInfo
eq "the default scope is target" target $::ModelLoader::UI::varCaptureScope
ok "a default PNG folder is suggested" \
    [expr {[file tail $::ModelLoader::UI::varOutputDir] eq "hv_capture" ? 1 : 0}]
eq "the target window is named next to the scope" "target window: 1" \
    [textof $::ModelLoader::UI::wTargetWin3]
ok "the pane explains what a capture would write" \
    [infohas {PNG CAPTURE \(step 3\)}]

# --- the view list parser (pure, no file needed) ------------------------------
# blank lines and '#', '//' and ';' comments are skipped, the first token is the
# name, a single further token is an orientation, a group of 16 numbers is a
# view matrix and duplicate names are made unique.
set parsed [::ModelLoader::Logic::ParseViewList {# comment
iso
front_left    front
tilted  0.62 -0.39 0.69 0.0 -0.35 -0.91 0.21 0.0 0.42 0.35 0.81 0.0 0.0 0.0 0.0 1.0
// slash comment
top ; comment behind a value
iso}]
eq "five entries were parsed" 5 [llength $parsed]
eq "the name is the first token" iso [dict get [lindex $parsed 0] name]
eq "a name alone is its own orientation" iso \
    [dict get [lindex $parsed 0] orientation]
eq "the second token is the orientation" front \
    [dict get [lindex $parsed 1] orientation]
eq "16 numbers are read as a view matrix" 16 \
    [llength [dict get [lindex $parsed 2] matrix]]
eq "a matrix entry carries no orientation" "" \
    [dict get [lindex $parsed 2] orientation]
eq "a comment behind a value is cut off" top [dict get [lindex $parsed 3] name]
eq "a duplicate name is made unique" iso-2 [dict get [lindex $parsed 4] name]

# --- the view list of the wizard ---------------------------------------------
set vlFile [file join $::here _selftest_viewlist.txt]
set fh [open $vlFile w]
puts $fh "# my steady views"
puts $fh "iso"
puts $fh "front_left front"
puts $fh "tilted 0.62 -0.39 0.69 0.0 -0.35 -0.91 0.21 0.0 0.42 0.35 0.81 0.0 0.0 0.0 0.0 1.0"
puts $fh "iso"
close $fh

set ::ModelLoader::UI::varViewListFile $vlFile
runs "'Import views' with a good list" {::ModelLoader::UI::OnImportViewList}
eq "the imported file is remembered" [file normalize $vlFile] \
    [::ModelLoader::State::GetViewListFile]
eq "the info label lists the views" "4 view(s): iso, front_left, tilted, iso-2" \
    $::ModelLoader::UI::varViewListInfo
ok "the status line reports the import" \
    [string match "View list imported: 4 view(s) from _selftest_viewlist.txt*" \
        $::ModelLoader::UI::statusText]
eq "four entries are in the State layer" 4 \
    [llength [::ModelLoader::State::GetViewList]]
ok "the information pane lists the views" [infohas {VIEW LIST}]
ok "the pane shows the matrix entry" [infohas {tilted : matrix \(}]
ok "the pane names the window files" [infohas {w1_iso.png}]

# a file that does not exist is rejected and the imported list is dropped
set ::ModelLoader::UI::varViewListFile {C:/no/such/views.txt}
runs "'Import views' with a missing file" {::ModelLoader::UI::OnImportViewList}
ok "the missing view list is rejected" \
    [string match "View list rejected: the view list does not exist:*" \
        $::ModelLoader::UI::statusText]
eq "the previous import was dropped" {} [::ModelLoader::State::GetViewList]
eq "the info label falls back" "no view list imported - one PNG per window" \
    $::ModelLoader::UI::varViewListInfo
ok "the rejection is in the information pane" \
    [infohas {was rejected: the view list does not exist}]

# an empty file holds no view entry
set vlEmpty [file join $::here _selftest_viewlist_empty.txt]
set fh [open $vlEmpty w] ; close $fh
set ::ModelLoader::UI::varViewListFile $vlEmpty
runs "'Import views' with an empty file" {::ModelLoader::UI::OnImportViewList}
ok "the empty view list is rejected" \
    [string match "View list rejected: no view entry was found in *" \
        $::ModelLoader::UI::statusText]

# an empty field is not an error - it just means 'one PNG per window'
set ::ModelLoader::UI::varViewListFile ""
runs "'Import views' with an empty field" {::ModelLoader::UI::OnImportViewList}
eq "the empty field is explained" \
    "No view list file was chosen - one PNG per window." \
    $::ModelLoader::UI::statusText
eq "and no views are imported" {} [::ModelLoader::State::GetViewList]

# the real list is imported again - the capture tests below need it
set ::ModelLoader::UI::varViewListFile $vlFile
runs "import the good list again" {::ModelLoader::UI::OnImportViewList}
eq "the four views are back" 4 [llength [::ModelLoader::State::GetViewList]]
catch { file delete $vlEmpty }

sec "5g - fix 5: the PNG output folder, the capture plan and the capture"
# --- the output folder -------------------------------------------------------
set outFile [file join $::here _selftest_outdir_file.txt]
set fh [open $outFile w] ; close $fh
set ::ModelLoader::UI::varOutputDir $outFile
set stateBefore [::ModelLoader::State::GetOutputDir]
eq "a FILE cannot be the PNG folder" "" \
    [::ModelLoader::UI::SetOutputDirValue $outFile]
ok "and the refusal explains itself" \
    [string match "Output folder rejected: * is a file, not a folder" \
        $::ModelLoader::UI::statusText]
eq "the refusal did not touch the State layer" $stateBefore \
    [::ModelLoader::State::GetOutputDir]

set outDir [file join $::here _selftest_png]
catch { file delete -force $outDir }
eq "a folder that does not exist yet is accepted" [file normalize $outDir] \
    [::ModelLoader::UI::SetOutputDirValue $outDir]
eq "the folder entry shows it" [file normalize $outDir] \
    [$::ModelLoader::UI::wOutputDir get]
eq "the State layer remembers it" [file normalize $outDir] \
    [::ModelLoader::State::GetOutputDir]

# --- the plan of RefreshStep3 ------------------------------------------------
set ::ModelLoader::UI::varCaptureScope target
set ::ModelLoader::UI::varTargetWin 1
runs "RefreshStep3 with four views" {::ModelLoader::UI::RefreshStep3}
eq "the info label lists the four views" "4 view(s): iso, front_left, tilted, iso-2" \
    $::ModelLoader::UI::varViewListInfo
ok "the pane counts one file per view of the one window" \
    [infohas {files +: 4 PNG file\(s\) would be written}]
ok "the planned file names are listed" [infohas {w1_iso.png}]
ok "the output folder is part of the plan" \
    [infohas {output folder : .*_selftest_png}]

# the scope is validated - garbage falls back to the default
set ::ModelLoader::UI::varCaptureScope everything
runs "RefreshStep3 with a nonsense scope" {::ModelLoader::UI::RefreshStep3}
eq "the scope is back to target" target $::ModelLoader::UI::varCaptureScope
eq "and so is the combobox" target [$::ModelLoader::UI::wCaptureScope get]

# --- the capture (no hwi -> the adapter reports it, the GUI survives) --------
runs "'Capture target' does not throw" {::ModelLoader::UI::OnCapture target}
eq "the button set the scope" target $::ModelLoader::UI::varCaptureScope
ok "the capture failure names the missing hwi" \
    [string match "*invalid command name*hwi*" $::ModelLoader::UI::statusText]
ok "the pane shows the failed capture" [infohas {FAILED - PNG capture}]
eq "no capture form was recorded without hwi" "" \
    [::ModelLoader::State::GetCaptureMode]
ok "the output folder was created before the hwi call" \
    [expr {[file isdirectory $outDir] ? 1 : 0}]

runs "'Capture all' does not throw either" {::ModelLoader::UI::OnCapture all}
eq "the scope is 'all' now" all $::ModelLoader::UI::varCaptureScope
ok "the second failure is reported as well" \
    [string match "PNG capture:*" $::ModelLoader::UI::statusText]

# a view list that was typed but never imported is imported by the capture
::ModelLoader::State::SetViewList {}
set ::ModelLoader::UI::varViewListFile $vlFile
runs "'Capture all' imports a view list that was not imported yet" \
    {::ModelLoader::UI::OnCapture all}
eq "the auto-import brought the four views back" 4 \
    [llength [::ModelLoader::State::GetViewList]]

# without an output folder the capture is refused before any hwi call
set notesBefore [llength $::stub::notes]
set ::ModelLoader::UI::varOutputDir ""
runs "'Capture target' without an output folder" {::ModelLoader::UI::OnCapture target}
ok "the missing folder is refused" \
    [string match "Output folder rejected:*" $::ModelLoader::UI::statusText]
ok "and a message box was offered" \
    [expr {[llength $::stub::notes] > $notesBefore ? 1 : 0}]

# --- back to step 2, ready for the last section ------------------------------
runs "StepBack returns to step 2" {::ModelLoader::UI::StepBack}
eq "the step counter is 2 again" 2 $::ModelLoader::UI::step
eq "the banner names step 2 again" "STEP 2 of 3 - Contour plot and legend" \
    [textof $::ModelLoader::UI::wStepTitle]
eq "'Next' is enabled again" normal [.modelLoaderGUI.btn_next cget -state]
catch { file delete -force $outDir }
catch { file delete $outFile }
catch { file delete $vlFile }
ok "the capture temporaries are gone" \
    [expr {[file exists $vlFile] ? 0 : 1}]

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

