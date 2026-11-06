set root [lindex $argv 0]
set outFile [lindex $argv 1]
set fid [open $outFile w]
fconfigure $fid -encoding utf-8 -translation lf

proc report {text} {
    global fid
    puts $fid $text
    flush $fid
}

report "== gui test, root: $root"
set ::pis099_no_autolaunch 1
report "source result: [catch {source [file join $root 01_scripts _tcl_pis_99_workflow_gui.tcl]} srcErr] $srcErr"
report "gui procs: [lsort [info commands ::pis099::gui::*]]"

# replace the modal dialogs so the test can never block
proc ::pis099::gui::show_error {msg} {
    report "DIALOG-ERROR: $msg"
    return 0
}
proc ::pis099::gui::show_info {msg} {
    report "DIALOG-INFO: $msg"
    return 0
}

report "launch rc: [catch {::pis099::gui::launch $root} launchErr] $launchErr"
catch {wm withdraw .pis099_workflow}
update
report "window exists: [winfo exists .pis099_workflow]"
report "rootVar: [set ::pis099::gui::rootVar]"
report "legendVar: [set ::pis099::gui::legendVar]"
report "configLoaded: [set ::pis099::gui::configLoaded]"
report "widgets: [lsort [winfo children .pis099_workflow]]"
report "load button text: [.pis099_workflow.rowAction.run cget -text]"
report "log state: [.pis099_workflow.logFrame.txt cget -state]"
report "entry text: [.pis099_workflow.rowRoot.ent get]"
report "legend entry: [.pis099_workflow.rowLegend.ent get]"
report "scrollbar exists: [winfo exists .pis099_workflow.logFrame.sb]"
report "log text so far:"
report [.pis099_workflow.logFrame.txt get 1.0 end]

# guard: empty legend path
set savedLegend [set ::pis099::gui::legendVar]
set ::pis099::gui::legendVar ""
report "empty-path load_legend rc: [::pis099::gui::load_legend]"
set ::pis099::gui::legendVar $savedLegend

# full run: the placeholder legend must fail with the combined error message
report "load_legend rc: [catch {::pis099::gui::load_legend} legacyErr] $legacyErr"
update
report "gui-mode flag cleaned: [expr {[info exists ::pis::run_from_gui] ? {STILL SET} : {unset ok}}]"
report "busy flag: [set ::pis099::gui::busy]"
report "cfg legend after failed run: [dict get [set ::pis099::gui::cfg] format legend_file]"
report "legendVar after failed run: [set ::pis099::gui::legendVar]"
set iniFid [open [file join $root 00_config pis_workflow_config.ini] r]
set iniText [read $iniFid]
close $iniFid
set iniLines {}
foreach line [split $iniText \n] {
    if {[string first "legend_file" $line] >= 0} { lappend iniLines [string trim $line] }
}
report "ini legend_file lines (must still be the placeholder): $iniLines"
report "log after run:"
report [.pis099_workflow.logFrame.txt get 1.0 end]

report "== gui test done"
flush $fid
close $fid
destroy .pis099_workflow
exit
