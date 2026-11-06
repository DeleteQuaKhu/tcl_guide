set root [lindex $argv 0]
puts "== step02 root: $root"
source [file join $root 01_scripts _tcl_pis_00_common.tcl]
set cfg [::pis::common::load_config $root]

# GUI mode flag: skip the standalone footer
set ::pis::run_from_gui 1
source [file join $root 01_scripts _tcl_pis_02_apply_contact_pressure_legend.tcl]
puts "step02 procs: [lsort [info commands ::pis::step02::*]]"

puts "--- 1 empty path"
if {[catch {::pis::step02::apply_file {}} e1]} {puts "OK err: $e1"}

puts "--- 2 missing file"
if {[catch {::pis::step02::apply_file [file join $root 00_config no_such_legend.tcl]} e2]} {puts "OK err: $e2"}

puts "--- 3 directory instead of file"
if {[catch {::pis::step02::apply_file [file join $root 00_config]} e3]} {puts "OK err: $e3"}

puts "--- 4 refresh_active_post without HyperView"
if {[catch {::pis::step02::refresh_active_post} e4]} {puts "OK err: $e4"}

puts "--- 5 apply_file on the placeholder legend (no hwc, no hwp)"
if {[catch {::pis::step02::apply_file [file join $root 00_config legend_default.tcl]} e5]} {puts "OK err: $e5"}

puts "--- 6 run through run_step (config legend_file = placeholder)"
set rc [catch {::pis::common::run_step $cfg 02 {Apply Contact Pressure Legend} [list ::pis::step02::run $root $cfg]} msg opts]
puts "rc=$rc"
puts "msg=$msg"
puts "ecode=[dict get $opts -errorcode]"

puts "--- 7 run with an absolute legend_file override"
set cfg2 $cfg
dict set cfg2 format legend_file [file join $root 00_config legend_default.tcl]
set rc2 [catch {::pis::step02::run $root $cfg2} msg2]
puts "rc2=$rc2"
puts "msg2=$msg2"

puts "--- 8 run with a missing legend_file key"
set cfg3 [dict remove $cfg format]
set rc3 [catch {::pis::step02::run $root $cfg3} msg3]
puts "rc3=$rc3"
puts "msg3=$msg3"

puts "--- 9 step02 usable without the common library"
foreach p [lsort [info commands ::pis::common::*]] { rename $p {} }
puts "common procs left: [llength [info commands ::pis::common::*]]"
set rc4 [catch {::pis::step02::apply_file [file join $root 00_config no_such_legend.tcl]} msg4]
puts "rc4=$rc4"
puts "msg4=$msg4"

puts "== step02 tests done"
