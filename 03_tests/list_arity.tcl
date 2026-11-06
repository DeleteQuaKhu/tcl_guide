set root [lindex $argv 0]
source [file join $root 01_scripts _tcl_pis_00_common.tcl]
set ::pis::run_from_gui 1
source [file join $root 01_scripts _tcl_pis_02_apply_contact_pressure_legend.tcl]
source [file join $root 01_scripts _tcl_pis_99_workflow_gui.tcl]

proc describe {procName} {
    set parts {}
    foreach a [info args $procName] {
        if {[info default $procName $a def]} {
            lappend parts "?$a = $def?"
        } else {
            lappend parts $a
        }
    }
    return [format "%-46s %2s  %s" $procName [llength [info args $procName]] [join $parts { }]]
}
puts "== procs and their declared arguments (name, count, args with defaults)"
foreach n [lsort [info procs ::pis::common::*]] { puts [describe $n] }
puts ""
foreach n [lsort [info procs ::pis::step02::*]] { puts [describe $n] }
puts ""
foreach n [lsort [info procs ::pis099::gui::*]] { puts [describe $n] }
