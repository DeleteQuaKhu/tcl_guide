set root [lindex $argv 0]
puts "== standalone footer test, root: $root"
# no ::pis::run_from_gui, no Tk -> the footer must try the standalone path and
# report the clear "Tk is not available" error instead of hanging
source [file join $root 01_scripts _tcl_pis_02_apply_contact_pressure_legend.tcl]
puts "standalone procs ok: [llength [info commands ::pis::step02::*]]"
puts "== standalone footer test done"
