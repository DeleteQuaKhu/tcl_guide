# PIS Workflow - shared configuration helpers (task T-004).
# ::pis::common is the ONLY reader/writer of 00_config/pis_workflow_config.ini.
# Tcl/Tk 8.5 compatible, no tcllib, no network, no HyperView calls.
# Sourcing this file defines procs only: it never builds a GUI and never throws.
#
# Public procs (SPEC.md API contract):
#   load_config {root}      ini -> nested dict (lowercase section/key) + defaults
#   get {cfg section key ?default?}
#   save_config {cfg}       write the whole ini back (atomic: temp file + rename)
#   resolve_path {root path}
#   log {cfg level msg}     single sink: GUI pane when present, else stderr
#   require_file {label path}
#   to_bool {value label}

namespace eval ::pis::common {
    variable ini_name "pis_workflow_config.ini"

    # Section order used when the ini is written back (SPEC.md data model).
    variable sections {
        folders layout session result legend measures section capture log
    }

    # Sections whose keys are counted items: count, item1..itemN, then a state key.
    variable item_sections {result legend measures section capture}

    # State key that carries the selection of each item section.
    variable state_key [dict create \
        result selected legend selected \
        measures checked section checked capture checked]
}

# The full shipping schema with every default value.
proc ::pis::common::defaults {} {
    return [dict create \
        root "" \
        config_file "" \
        folders [dict create \
            config_dir 00_config script_dir 01_scripts working_dir 02_working] \
        layout [dict create cols 4 rows 2] \
        session [dict create model_file "" result_files ""] \
        result [dict create count 0 selected 0] \
        legend [dict create on 0 count 0 selected 0] \
        measures [dict create count 0 checked ""] \
        section [dict create count 0 checked ""] \
        capture [dict create count 0 checked ""] \
        log [dict create journal_file "" continue_on_error 0]]
}

# Parse ini text into a dict of {section {key value}}. Throws on a value that
# appears before the first section header and on any line without 'key = value'.
proc ::pis::common::parse_ini {text path} {
    set out [dict create]
    set cur ""
    set n 0
    foreach line [split $text "\n"] {
        incr n
        set line [string trim [string trimright $line "\r"] " \t"]
        if {$line eq ""} { continue }
        set first [string index $line 0]
        if {$first eq "#" || $first eq ";"} { continue }
        if {[regexp {^\[([^\[\]]+)\]$} $line -> name]} {
            set cur [string tolower [string trim $name]]
            if {![dict exists $out $cur]} { dict set out $cur [dict create] }
            continue
        }
        if {$cur eq ""} {
            error [format "%s line %d: value before the first section header: %s" \
                $path $n $line]
        }
        set pos [string first "=" $line]
        if {$pos < 1} {
            error [format "%s line %d: expected 'key = value': %s" $path $n $line]
        }
        set key [string tolower [string trim [string range $line 0 [expr {$pos - 1}]]]]
        set val [string trim [string range $line [expr {$pos + 1}] end]]
        if {$key eq ""} {
            error [format "%s line %d: empty key" $path $n]
        }
        dict set out $cur $key $val
    }
    return $out
}

# The [layout_tokens] section of ONE ini file, read-only: {"<cols>x<rows>" -> "<token>"}.
# A layout token belongs to the BUILD, not to a doc: on the owner's machine a guessed spelling
# is answered with silence, and the only token that cannot be wrong is the one the page itself
# reports through '<page> GetLayout' (::pis::hw::grid_capture). The owner pastes that line into
# the ini BY HAND - nothing here writes it.
# Never throws: a missing, unreadable or corrupt file answers {} and the caller falls back to
# its documented forms. Keys are "<cols>x<rows>" in GUI order; an entry that is not a positive
# pair with a non-empty value is dropped, never guessed.
proc ::pis::common::read_layout_tokens {path} {
    if {[string trim $path] eq ""} { return [dict create] }
    if {[catch {open $path r} fh]} { return [dict create] }
    set text ""
    if {[catch {set text [read $fh]}]} {
        catch {close $fh}
        return [dict create]
    }
    close $fh
    set kv [dict create]
    if {[catch {set kv [dict get [parse_ini $text $path] layout_tokens]}]} {
        return [dict create]
    }
    set out [dict create]
    dict for {k v} $kv {
        set val [string trim $v]
        if {$val eq ""} { continue }
        if {![regexp {^([0-9]+)x([0-9]+)$} $k -> c r]} { continue }
        if {$c < 1 || $r < 1} { continue }
        dict set out $k $val
    }
    return $out
}

# Fill in missing item-section keys so later tasks can read them blindly, and
# coerce the boolean keys (a bad value warns once, it never crashes the load).
proc ::pis::common::normalize {cfg} {
    variable item_sections
    variable state_key
    foreach sec $item_sections {
        if {![dict exists $cfg $sec]} { dict set cfg $sec [dict create] }
        set kv [dict get $cfg $sec]
        set max 0
        foreach k [dict keys $kv] {
            if {[regexp {^item([0-9]+)$} $k -> idx] && $idx > $max} { set max $idx }
        }
        set count 0
        if {[dict exists $kv count]} {
            set count [string trim [dict get $kv count]]
        }
        if {![string is integer -strict $count] || $count < 0} { set count 0 }
        if {$count < $max} { set count $max }
        dict set cfg $sec count $count
        set sk [dict get $state_key $sec]
        if {![dict exists $kv $sk]} {
            if {$sk eq "selected"} {
                dict set cfg $sec $sk [expr {$max > 0 ? 1 : 0}]
            } else {
                dict set cfg $sec $sk ""
            }
        }
    }
    foreach {sec key def} {legend on 0 log continue_on_error 0} {
        set val $def
        if {[dict exists $cfg $sec $key]} {
            set raw [dict get $cfg $sec $key]
            if {[catch {to_bool $raw [format "%s %s" $sec $key]} val]} {
                log $cfg WARN [format "invalid value for %s %s: '%s' (using %s): %s" \
                    $sec $key $raw $def [dict get $cfg config_file]]
                set val $def
            }
        }
        dict set cfg $sec $key $val
    }
    return $cfg
}

# Read the ini for a workflow root. A missing, unreadable or corrupt file never
# throws: the defaults are returned and exactly one WARN names the path.
proc ::pis::common::load_config {root} {
    variable ini_name
    if {[string trim $root] eq ""} { error "load_config: root path is empty" }
    set cfg [defaults]
    set root [file normalize $root]
    dict set cfg root $root
    set path [file join $root 00_config $ini_name]
    dict set cfg config_file $path

    if {![file isfile $path]} {
        log $cfg WARN "config file not found, using defaults: $path"
        return [normalize $cfg]
    }
    if {[catch {open $path r} fh]} {
        log $cfg WARN "config file unreadable, using defaults: $path ($fh)"
        return [normalize $cfg]
    }
    if {[catch {set text [read $fh]} err]} {
        catch {close $fh}
        log $cfg WARN "config file unreadable, using defaults: $path ($err)"
        return [normalize $cfg]
    }
    close $fh
    if {[catch {parse_ini $text $path} parsed]} {
        log $cfg WARN "config file corrupt, using defaults: $path ($parsed)"
        return [normalize $cfg]
    }
    dict for {sec kv} $parsed {
        dict for {k v} $kv { dict set cfg $sec $k $v }
    }
    set cdir [string trim [dict get $cfg folders config_dir]]
    if {$cdir ne ""} {
        dict set cfg config_file [file join $root $cdir $ini_name]
    }
    return [normalize $cfg]
}

# Write the whole cfg back to its config_file. Written to a temp file first and
# renamed, so an interrupted save can never leave a half ini behind.
proc ::pis::common::save_config {cfg} {
    if {[catch {dict get $cfg config_file} path]} {
        error "save_config: cfg has no config_file (run load_config first)"
    }
    if {[string trim $path] eq ""} { error "save_config: config_file is empty" }
    set dir [file dirname $path]
    if {![file isdirectory $dir]} {
        if {[catch {file mkdir $dir} err]} {
            error "save_config: cannot create $dir ($err)"
        }
    }
    set tmp "$path.tmp[pid]"
    if {[catch {open $tmp w} fh]} {
        error "save_config: cannot write $tmp ($fh)"
    }
    set failed [catch {write_ini $fh $cfg} err]
    if {[catch {close $fh} cerr] && !$failed} {
        set failed 1
        set err $cerr
    }
    if {$failed} {
        catch {file delete -force $tmp}
        error "save_config: cannot write $path ($err)"
    }
    if {[catch {file rename -force $tmp $path} err]} {
        catch {file delete -force $tmp}
        error "save_config: cannot replace $path ($err)"
    }
    return $path
}

proc ::pis::common::write_ini {fh cfg} {
    variable sections
    set done [dict create]
    foreach sec $sections {
        if {![dict exists $cfg $sec]} { continue }
        puts $fh "\[$sec\]"
        write_section $fh $cfg $sec
        puts $fh ""
        dict set done $sec 1
    }
    foreach sec [lsort [dict keys $cfg]] {
        if {$sec eq "root" || $sec eq "config_file"} { continue }
        if {[dict exists $done $sec]} { continue }
        if {[catch {dict size [dict get $cfg $sec]}]} { continue }
        puts $fh "\[$sec\]"
        write_section $fh $cfg $sec
        puts $fh ""
        dict set done $sec 1
    }
}

# count, item1..itemN, then the state key; any other key of the section is
# written after those in sorted order, so unknown keys survive a round trip.
proc ::pis::common::write_section {fh cfg sec} {
    variable item_sections
    variable state_key
    set kv [dict get $cfg $sec]
    set written [dict create]
    if {[lsearch -exact $item_sections $sec] >= 0} {
        if {[dict exists $kv count]} {
            puts $fh "count = [dict get $kv count]"
            dict set written count 1
        }
        set idxs {}
        foreach k [dict keys $kv] {
            if {[regexp {^item([0-9]+)$} $k -> n]} { lappend idxs $n }
        }
        foreach n [lsort -integer $idxs] {
            puts $fh "item$n = [dict get $kv item$n]"
            dict set written item$n 1
        }
        set sk [dict get $state_key $sec]
        if {[dict exists $kv $sk]} {
            puts $fh "$sk = [dict get $kv $sk]"
            dict set written $sk 1
        }
    }
    foreach k [lsort [dict keys $kv]] {
        if {[dict exists $written $k]} { continue }
        puts $fh "$k = [dict get $kv $k]"
    }
}

# Fetch one config value. With a default argument a missing key returns the
# default; without one it raises the SPEC message naming section and key.
proc ::pis::common::get {cfg section key args} {
    if {[llength $args] > 1} {
        error "wrong # args: should be \"::pis::common::get cfg section key ?default?\""
    }
    set s [string tolower $section]
    set k [string tolower $key]
    if {[dict exists $cfg $s $k]} { return [dict get $cfg $s $k] }
    if {[llength $args] == 1} { return [lindex $args 0] }
    error "Missing required config value: $section $key"
}

# Relative paths are joined to root; absolute paths (C:/..., /..., //host/...)
# are normalised and kept. An empty path is an error, never "." or the root.
proc ::pis::common::resolve_path {root path} {
    if {[string trim $path] eq ""} { error "resolve_path: empty path" }
    set p [string trim $path]
    if {[file pathtype $p] eq "absolute"} { return [file normalize $p] }
    if {[string trim $root] eq ""} {
        error "resolve_path: empty root for relative path '$p'"
    }
    return [file normalize [file join [file normalize $root] $p]]
}

# The single log sink. The GUI pane owns the timestamp and the colours, so this
# only forwards level + text; without a GUI (offline tests) it writes to stderr.
# cfg is part of the signature for the journal added in T-005.
proc ::pis::common::log {cfg level msg} {
    set level [string toupper [string trim $level]]
    if {[llength [info commands ::pis::gui::log_line]] > 0} {
        catch {::pis::gui::log_line $level $msg}
        return
    }
    puts stderr [format "%-5s %s" $level $msg]
}

# Error with the offending path unless file exists (and is a file, not a dir).
proc ::pis::common::require_file {label path} {
    if {[string trim $path] eq ""} { error "$label path is empty" }
    if {![file isfile $path]} { error "$label not found: $path" }
    return $path
}

# true/false/1/0/yes/no/on/off -> 1/0; anything else errors naming label+value.
proc ::pis::common::to_bool {value label} {
    set v [string tolower [string trim $value]]
    foreach {name result} {
        1 1 true 1 yes 1 on 1
        0 0 false 0 no 0 off 0
    } {
        if {$v eq $name} { return $result }
    }
    error [format "Invalid boolean for %s: '%s' (expected true/false/1/0/yes/no/on/off)" \
        $label $value]
}
