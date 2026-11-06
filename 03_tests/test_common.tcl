set root [lindex $argv 0]
puts "== root: $root"
source [file join $root 01_scripts _tcl_pis_00_common.tcl]
puts "== common procs: [llength [info commands ::pis::common::*]]"

set cfg [::pis::common::load_config $root]
puts "root        = [dict get $cfg root]"
puts "config_file = [dict get $cfg config_file]"
puts "sections    = [dict keys $cfg]"
puts "legend      = [::pis::common::get $cfg format legend_file]"
puts "enabled     = [::pis::common::get $cfg script_02 enabled]"
puts "title       = [::pis::common::get $cfg script_02 title]"
puts "default     = [::pis::common::get $cfg workflow no_such_key fallback-value]"

if {[catch {::pis::common::get $cfg workflow no_such_key} err]} {
    puts "missing-key error = $err"
} else {
    puts "FAIL: missing key did not raise"
}

if {[catch {::pis::common::get $cfg workflow stop_on_error extra1 extra2} err2]} {
    puts "too-many-args error = $err2"
}

puts "cfg_path  = [::pis::common::cfg_path $cfg working workflow_log]"
puts "resolve   = [::pis::common::resolve_path $root 02_working/x.log]"

set created [::pis::common::ensure_directories $cfg]
puts "created   = $created"
puts "created2  = [::pis::common::ensure_directories $cfg]"

puts "log     = [::pis::common::log $cfg INFO {common: log line}]"
puts "errlog  = [::pis::common::error_log $cfg {common: error line}]"
puts "status  = [::pis::common::write_status $cfg running TEST02 {} {}]"
puts "csv     = [::pis::common::append_run_status $cfg TEST02 {Apply Contact Pressure Legend} PASSED {first line
second line}]"
puts "qcsv    = [::pis::common::quote_csv {a "b"	c}]"

if {[catch {::pis::common::require_file {Legend file} [file join $root 00_config no_such.tcl]} err3]} {
    puts "require_file error = $err3"
}
if {[catch {::pis::common::require_file {Legend file} {}} err4]} {
    puts "require_file empty = $err4"
}

set res [::pis::common::run_step $cfg 02 {Apply Contact Pressure Legend} {return {all good}}]
puts "run_step ok = $res"

set rc [catch {::pis::common::run_step $cfg 02 {Apply Contact Pressure Legend} {error {boom happened}}} msg opts]
puts "run_step rc = $rc msg = $msg"
puts "run_step ecode = [dict get $opts -errorcode]"

# bad config file handling
set bad [file join $root 06_bad_cfg]
file mkdir $bad
file mkdir [file join $bad 00_config]
set fid [open [file join $bad 00_config pis_workflow_config.ini] w]
puts $fid "stray = value"
close $fid
if {[catch {::pis::common::load_config $bad} err5]} {
    puts "bad-cfg error = $err5"
}
set fid [open [file join $bad 00_config pis_workflow_config.ini] w]
puts $fid "\[folders]\nbroken line\n"
close $fid
if {[catch {::pis::common::load_config $bad} err6]} {
    puts "bad-line error = $err6"
}
file delete -force $bad

# CRLF config file
set crlf [file join $root 07_crlf_cfg]
file mkdir $crlf
file mkdir [file join $crlf 00_config]
set fid [open [file join $crlf 00_config pis_workflow_config.ini] w]
fconfigure $fid -translation binary
puts -nonewline $fid "\xef\xbb\xbf\[folders]\r\nconfig_dir = 00_config\r\nscript_dir = 01_scripts\r\nworking_dir = 02_working\r\n\r\n\[format]\r\nlegend_file = 00_config/legend_default.tcl\r\n"
close $fid
if {[catch {::pis::common::load_config $crlf} cfgCrlf]} {
    puts "crlf error = $cfgCrlf"
} else {
    puts "crlf ok: folders working_dir = [::pis::common::get $cfgCrlf folders working_dir] / format legend_file = [::pis::common::get $cfgCrlf format legend_file]"
}
file delete -force $crlf

puts "== common tests done"
