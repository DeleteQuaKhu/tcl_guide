set root [lindex $argv 0]
source [file join $root 01_scripts _tcl_pis_02_apply_contact_pressure_legend.tcl]

namespace eval ::sim {
    variable n 0
    variable events {}
    variable stack 0
    variable failImport 0
    variable importArgs {}
    variable mode returned
}
proc sim_reset {} {
    set ::sim::n 0
    set ::sim::events {}
    set ::sim::stack 0
    set ::sim::failImport 0
    set ::sim::importArgs {}
    catch {rename ::post::LoadSettings {}}
}
proc sim_new_handle {requested} {
    incr ::sim::n
    set h "::sim::clientHandle[set ::sim::n]"
    if {$requested ne ""} { set h "::sim::req[string map {:: _} $requested]" }
    proc $h {cmd args} {
        set me [lindex [info level 0] 0]
        lappend ::sim::events "HANDLE:[namespace tail $me]:$cmd"
        if {$cmd eq "ReleaseHandle"} { rename $me {} }
        return ""
    }
    lappend ::sim::events "CREATED:[namespace tail $h]"
    return $h
}
proc hwi {args} {
    set sub [lindex $args 0]
    switch -- $sub {
        OpenStack  { set ::sim::stack 1; lappend ::sim::events OPEN; return "" }
        CloseStack { set ::sim::stack 0; lappend ::sim::events CLOSE; return "" }
        GetActiveClientHandle {
            lappend ::sim::events "GET:[lindex $args 1]"
            switch -- $::sim::mode {
                empty   { return "" }
                bogus   { return "no_such_handle" }
                default { return [sim_new_handle ""] }
            }
        }
        default { error "unsupported hwi subcommand: $sub" }
    }
}
proc hwc {args} {
    lappend ::sim::events "HWC:[join $args { }]"
    set ::sim::importArgs $args
    if {$::sim::failImport} { error "stub import rejected" }
    return "imported"
}
proc sim_make_legend {path} {
    set fid [open $path w]
    puts $fid "namespace eval ::post {}"
    puts $fid "proc ::post::LoadSettings {legendHandle} {"
    puts $fid "    lappend ::sim::events \"LOADSETTINGS:\$legendHandle\""
    puts $fid "    return 1"
    puts $fid "}"
    close $fid
    return $path
}

set legend [sim_make_legend [file join [lindex $argv 1] sim_legend.tcl]]
puts "legend stub  : $legend"

puts "\n--- A primary path (hwc import works)"
sim_reset; set ::sim::mode returned
set msgA [::pis::step02::apply_file $legend]
puts "message  : $msgA"
puts "events   : $::sim::events"
puts "stack    : $::sim::stack   (expected 0)"
puts "handles  : [llength [info commands ::sim::req*]] leftover (expected 0)"
puts "imported : $::sim::importArgs"

puts "\n--- B primary path where hwi returns an empty handle name (code uses the requested name)"
sim_reset; set ::sim::mode empty
set msgB [::pis::step02::apply_file $legend]
puts "message  : $msgB"
puts "events   : $::sim::events"
puts "leftover requested handles: [llength [info commands ::sim::req*]] (expected 0)"

puts "\n--- C hwi returns a handle name that is not a command"
sim_reset; set ::sim::mode bogus
set rcC [catch {::pis::step02::apply_file $legend} msgC]
puts "rc=$rcC msg=$msgC"
puts "events   : $::sim::events"
puts "stack    : $::sim::stack   (expected 0)"

puts "\n--- D fallback through ::hwp::GetContourLegend (hwc fails)"
sim_reset; set ::sim::failImport 1; set ::sim::mode returned
namespace eval ::hwp {}
proc ::hwp::GetContourLegend {clientHandle} {
    lappend ::sim::events "GETLEGEND:$clientHandle"
    return [sim_new_handle ""]
}
set msgD [::pis::step02::apply_file $legend]
puts "message  : $msgD"
puts "events   : $::sim::events"
puts "stack    : $::sim::stack   (expected 0)"
puts "legend handles left: [llength [info commands ::sim::clientHandle*]] (expected 0)"

puts "\n--- E fallback where the legend file does not define ::post::LoadSettings"
sim_reset; set ::sim::failImport 1
set badLegend [file join [lindex $argv 1] sim_legend_no_proc.tcl]
set fid [open $badLegend w]
puts $fid "# no ::post::LoadSettings here"
close $fid
set rcE [catch {::pis::step02::apply_file $badLegend} msgE]
puts "rc=$rcE msg=$msgE"
puts "stack    : $::sim::stack   (expected 0)"
puts "legend handles left: [llength [info commands ::sim::clientHandle*]] (expected 0)"

puts "\n--- F fallback where both paths fail"
sim_reset; set ::sim::failImport 1
proc ::hwp::GetContourLegend {} { error "no legend in this session" }
set rcF [catch {::pis::step02::apply_file $legend} msgF]
puts "rc=$rcF msg=$msgF"
puts "stack    : $::sim::stack   (expected 0)"

puts "\n--- G handle names are unique and prefixed"
puts "names: [::pis::step02::client_handle_name post] [::pis::step02::client_handle_name post] [::pis::step02::client_handle_name hwp]"
puts "\n== stub tests done"
