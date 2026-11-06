set root [lindex $argv 0]
set outFile [lindex $argv 1]
set fid [open $outFile w]
fconfigure $fid -encoding utf-8 -translation lf
proc report {text} {
    global fid
    catch {puts $fid $text}
    catch {flush $fid}
}

# --- HyperView stubs: enough for the primary import path -------------------
namespace eval ::sim {}
set ::sim::n 0
proc hwi {args} {
    switch -- [lindex $args 0] {
        OpenStack  { return "" }
        CloseStack { return "" }
        GetActiveClientHandle {
            incr ::sim::n
            set h "::sim::postHandle[set ::sim::n]"
            proc $h {cmd args} {
                set me [lindex [info level 0] 0]
                if {$cmd eq "ReleaseHandle"} { rename $me {} }
                return ""
            }
            return $h
        }
        default { error "unsupported hwi subcommand: [lindex $args 0]" }
    }
}
proc hwc {args} {
    return "legend imported"
}

set ::pis099_no_autolaunch 1
report "source rc: [catch {source [file join $root 01_scripts _tcl_pis_99_workflow_gui.tcl]} srcErr] $srcErr"
proc ::pis099::gui::show_error {msg} {
    report "DIALOG-ERROR: $msg"
    return 0
}
proc ::pis099::gui::show_info {msg} {
    report "DIALOG-INFO: $msg"
    return 0
}
catch {::pis099::gui::launch $root}
catch {wm withdraw .pis099_workflow}
update
report "load_legend rc: [catch {::pis099::gui::load_legend} loadErr] $loadErr"
update
report "status bar text: [.pis099_workflow.rowAction.status cget -text]"
report "GUI log:"
report [.pis099_workflow.logFrame.txt get 1.0 end]

proc show_file {path} {
    if {![file isfile $path]} { report "MISSING: $path"; return }
    set f [open $path r]
    fconfigure $f -encoding utf-8
    set t [read $f]
    close $f
    report "--- $path"
    report [string trim $t]
}
show_file [file join $root 02_working workflow_status.ini]
show_file [file join $root 02_working run_status.csv]
show_file [file join $root 02_working workflow.log]

report "== success-path gui test done"
flush $fid
close $fid
destroy .pis099_workflow
exit
