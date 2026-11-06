#============================================================================
# _tcl_pis_00_common.tcl
#
# Shared helpers for the PIS HyperView workflows.
# Tcl/Tk 8.5 compatible. No external packages, no tcllib, no try/finally.
#
# Public API (namespace ::pis::common), one definition per procedure:
#   load_config        root
#   get                cfg section key ?default?
#   resolve_path       root path
#   cfg_path           cfg section key
#   ensure_directories cfg
#   timestamp
#   log                cfg level msg
#   error_log          cfg msg
#   write_status       cfg runStatus completedStep errorStep errorMessage
#   append_run_status  cfg stepID stepName status message
#   quote_csv          text
#   require_file       label file
#   run_step           cfg stepID stepName body
#
# Internal helpers used by the procedures above:
#   is_true            value
#   ensure_parent_dir  path label
#   write_text_file    path text
#   append_text_file   path text
#
# Conventions
#   - cfg is a nested dictionary: cfg -> section -> key -> value, plus the
#     top level entries root and config_file.
#   - section / key names are lowercase.
#   - every error message names the offending path or key.
#   - every channel opened here is closed on the error path as well.
#============================================================================

namespace eval ::pis::common {
    variable version 1.0

    # location of the configuration file inside the workflow root folder
    variable configSubdir 00_config
    variable configFileName pis_workflow_config.ini

    # character constants: built with format so that no literal square
    # bracket ever appears inside a quoted string in this file
    variable LB [format %c 91]
    variable RB [format %c 93]
    variable DQ [format %c 34]
}

#----------------------------------------------------------------------------
# load_config root
#   Reads <root>/00_config/pis_workflow_config.ini into a nested dictionary.
#   Returns the dictionary (also containing root and config_file).
#----------------------------------------------------------------------------
proc ::pis::common::load_config {root} {
    variable configSubdir
    variable configFileName
    variable LB
    variable RB

    set cleanRoot [string trim $root]
    if {$cleanRoot eq ""} {
        return -code error "load_config: root folder is empty; cannot locate the configuration file."
    }
    if {![file exists $cleanRoot]} {
        return -code error "load_config: root folder does not exist: $cleanRoot"
    }
    if {![file isdirectory $cleanRoot]} {
        return -code error "load_config: root path is not a folder: $cleanRoot"
    }

    set absRoot [file normalize $cleanRoot]
    set cfgFile [file join $absRoot $configSubdir $configFileName]
    if {![file exists $cfgFile]} {
        return -code error "Configuration file not found: $cfgFile"
    }
    if {![file isfile $cfgFile]} {
        return -code error "Configuration path is not a regular file: $cfgFile"
    }

    set fid ""
    if {[catch {set fid [open $cfgFile r]} openErr]} {
        return -code error "Cannot open configuration file: $cfgFile ($openErr)"
    }
    set readRc [catch {
        fconfigure $fid -encoding utf-8 -translation auto
        set data [read $fid]
    } readErr]
    catch {close $fid}
    if {$readRc} {
        return -code error "Cannot read configuration file: $cfgFile ($readErr)"
    }

    set cfg [dict create]
    dict set cfg root $absRoot
    dict set cfg config_file $cfgFile

    # strip a leading UTF-8 byte order mark so that Notepad-saved files work
    if {[string length $data] > 0} {
        if {[string index $data 0] eq "\ufeff"} {
            set data [string range $data 1 end]
        }
    }

    set section ""
    set lineNo 0
    foreach rawLine [split $data "\n"] {
        incr lineNo
        set line [string trim [string trimright $rawLine "\r"]]
        if {$line eq ""} {
            continue
        }
        set firstChar [string index $line 0]
        if {$firstChar eq "#" || $firstChar eq ";"} {
            continue
        }

        if {$firstChar eq $LB} {
            set closeIdx [string last $RB $line]
            if {$closeIdx < 1} {
                return -code error "Invalid section header at line $lineNo of $cfgFile: $line"
            }
            set trailing [string trim [string range $line [expr {$closeIdx + 1}] end]]
            if {$trailing ne ""} {
                return -code error "Unexpected text after the section header at line $lineNo of $cfgFile: $line"
            }
            set section [string tolower [string trim [string range $line 1 [expr {$closeIdx - 1}]]]]
            if {$section eq ""} {
                return -code error "Empty section name at line $lineNo of $cfgFile: $line"
            }
            continue
        }

        set eqIdx [string first "=" $line]
        if {$eqIdx < 1} {
            return -code error "Invalid configuration line $lineNo of $cfgFile (expected key = value): $line"
        }
        set key [string tolower [string trim [string range $line 0 [expr {$eqIdx - 1}]]]]
        set value [string trim [string range $line [expr {$eqIdx + 1}] end]]
        if {$key eq ""} {
            return -code error "Empty key at line $lineNo of $cfgFile: $line"
        }
        if {$section eq ""} {
            return -code error "Configuration record found before any section header at line $lineNo of $cfgFile: $line"
        }
        dict set cfg $section $key $value
    }

    return $cfg
}

#----------------------------------------------------------------------------
# get cfg section key ?default?
#   Returns the value of one configuration key. When the single optional
#   argument is given it is returned if the key is absent, otherwise a
#   "Missing required config value" error is raised.
#----------------------------------------------------------------------------
proc ::pis::common::get {cfg section key args} {
    if {[llength $args] > 1} {
        return -code error "get: at most one optional default value is allowed, got [llength $args] extra arguments for key $section $key"
    }
    set s [string tolower [string trim $section]]
    set k [string tolower [string trim $key]]
    if {$s eq "" || $k eq ""} {
        return -code error "get: section and key must not be empty (section: $section, key: $key)"
    }
    if {[dict exists $cfg $s $k]} {
        return [dict get $cfg $s $k]
    }
    if {[llength $args] == 1} {
        return [lindex $args 0]
    }
    return -code error "Missing required config value: $section $key"
}

#----------------------------------------------------------------------------
# resolve_path root path
#   Absolute path -> normalized. Relative path -> joined to root and
#   normalized. Empty path -> error.
#----------------------------------------------------------------------------
proc ::pis::common::resolve_path {root path} {
    set cleanPath [string trim $path]
    if {$cleanPath eq ""} {
        return -code error "resolve_path: path is empty, cannot resolve it against root folder: $root"
    }
    if {[file pathtype $cleanPath] eq "absolute"} {
        return [file normalize $cleanPath]
    }
    set cleanRoot [string trim $root]
    if {$cleanRoot eq ""} {
        return -code error "resolve_path: root folder is empty, cannot resolve relative path: $path"
    }
    if {![file isdirectory $cleanRoot]} {
        return -code error "resolve_path: root folder does not exist: $cleanRoot"
    }
    return [file normalize [file join [file normalize $cleanRoot] $cleanPath]]
}

#----------------------------------------------------------------------------
# cfg_path cfg section key
#   Convenience wrapper: cfg value -> absolute path resolved against cfg root.
#----------------------------------------------------------------------------
proc ::pis::common::cfg_path {cfg section key} {
    if {![dict exists $cfg root]} {
        return -code error "cfg_path: the configuration dict has no root entry; call load_config first (key: $section $key)"
    }
    set root [dict get $cfg root]
    set raw [get $cfg $section $key]
    return [resolve_path $root $raw]
}

#----------------------------------------------------------------------------
# ensure_directories cfg
#   Creates the three folders folders/*_dir plus the parent folders of the
#   four working files. Returns the list of folders that were created.
#----------------------------------------------------------------------------
proc ::pis::common::ensure_directories {cfg} {
    if {![dict exists $cfg root]} {
        return -code error "ensure_directories: the configuration dict has no root entry; call load_config first."
    }
    set root [dict get $cfg root]
    set created [list]

    foreach dkey {config_dir script_dir working_dir} {
        set raw [get $cfg folders $dkey]
        if {[string trim $raw] eq ""} {
            return -code error "ensure_directories: the folders $dkey value is empty in the configuration."
        }
        set full [resolve_path $root $raw]
        if {[file exists $full]} {
            if {![file isdirectory $full]} {
                return -code error "ensure_directories: path exists but is not a folder: $full (folders $dkey)"
            }
            continue
        }
        if {[catch {file mkdir $full} mkErr]} {
            return -code error "ensure_directories: cannot create folder $full (folders $dkey): $mkErr"
        }
        lappend created $full
    }

    foreach wkey {workflow_log error_log run_status_csv workflow_status} {
        set raw [get $cfg working $wkey]
        if {[string trim $raw] eq ""} {
            return -code error "ensure_directories: the working $wkey value is empty in the configuration."
        }
        set full [resolve_path $root $raw]
        set dir [file dirname $full]
        if {[file isdirectory $dir]} {
            continue
        }
        if {[file exists $dir]} {
            return -code error "ensure_directories: path exists but is not a folder: $dir (parent folder of working $wkey)"
        }
        if {[catch {file mkdir $dir} mkErr2]} {
            return -code error "ensure_directories: cannot create folder $dir (parent folder of working $wkey): $mkErr2"
        }
        if {[lsearch -exact $created $dir] < 0} {
            lappend created $dir
        }
    }

    return $created
}

#----------------------------------------------------------------------------
# timestamp
#   Local time as YYYY-MM-DD HH:MM:SS.
#----------------------------------------------------------------------------
proc ::pis::common::timestamp {} {
    return [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]
}

#----------------------------------------------------------------------------
# is_true value
#   true/yes/on/1 (case insensitive) -> 1, everything else -> 0.
#----------------------------------------------------------------------------
proc ::pis::common::is_true {value} {
    switch -nocase -- [string trim $value] {
        true -
        yes -
        on -
        1 {
            return 1
        }
        default {
            return 0
        }
    }
}

#----------------------------------------------------------------------------
# ensure_parent_dir path label
#   Creates the parent folder of path if needed. Returns 1 when a folder was
#   created, 0 when it already existed.
#----------------------------------------------------------------------------
proc ::pis::common::ensure_parent_dir {path label} {
    set dir [file dirname $path]
    if {$dir eq "" || $dir eq "."} {
        return 0
    }
    if {[file isdirectory $dir]} {
        return 0
    }
    if {[file exists $dir]} {
        return -code error "Cannot create folder $dir for $label: path exists but is not a folder."
    }
    if {[catch {file mkdir $dir} mkErr]} {
        return -code error "Cannot create folder $dir for $label ($mkErr)"
    }
    return 1
}

#----------------------------------------------------------------------------
# write_text_file path text
#   Truncates/creates path and writes text (UTF-8, LF line ends). The channel
#   is closed on the success and on the error path.
#----------------------------------------------------------------------------
proc ::pis::common::write_text_file {path text} {
    if {[string trim $path] eq ""} {
        return -code error "write_text_file: target path is empty"
    }
    ensure_parent_dir $path "output file $path"

    set fid ""
    if {[catch {set fid [open $path w]} openErr]} {
        return -code error "Cannot open file for writing: $path ($openErr)"
    }
    set writeRc [catch {
        fconfigure $fid -encoding utf-8 -translation lf
        puts -nonewline $fid $text
        flush $fid
    } writeErr]
    catch {close $fid}
    if {$writeRc} {
        return -code error "Cannot write file: $path ($writeErr)"
    }
    return 1
}

#----------------------------------------------------------------------------
# append_text_file path text
#   Appends text to path (creates the file and its parent folder if needed).
#   The channel is closed on the success and on the error path.
#----------------------------------------------------------------------------
proc ::pis::common::append_text_file {path text} {
    if {[string trim $path] eq ""} {
        return -code error "append_text_file: target path is empty"
    }
    ensure_parent_dir $path "output file $path"

    set fid ""
    if {[catch {set fid [open $path a]} openErr]} {
        return -code error "Cannot open file for append: $path ($openErr)"
    }
    set writeRc [catch {
        fconfigure $fid -encoding utf-8 -translation lf
        puts -nonewline $fid $text
        flush $fid
    } writeErr]
    catch {close $fid}
    if {$writeRc} {
        return -code error "Cannot append to file: $path ($writeErr)"
    }
    return 1
}

#----------------------------------------------------------------------------
# log cfg level msg
#   Writes one timestamped line to the workflow log (when workflow write_log
#   is true, default true) and echoes it to the console. Returns the line.
#----------------------------------------------------------------------------
proc ::pis::common::log {cfg level msg} {
    set line [format "%s %-7s %s" [timestamp] [string toupper [string trim $level]] $msg]
    catch {puts $line}

    set writeLog [get $cfg workflow write_log true]
    if {![is_true $writeLog]} {
        return $line
    }
    set logPath [cfg_path $cfg working workflow_log]
    append_text_file $logPath "$line\n"
    return $line
}

#----------------------------------------------------------------------------
# error_log cfg msg
#   Appends one ERROR line to the dedicated error log. Returns the line.
#----------------------------------------------------------------------------
proc ::pis::common::error_log {cfg msg} {
    set line [format "%s %-7s %s" [timestamp] ERROR $msg]
    catch {puts $line}

    set errPath [cfg_path $cfg working error_log]
    append_text_file $errPath "$line\n"
    return $line
}

#----------------------------------------------------------------------------
# quote_csv text
#   Returns text as a double quoted CSV field (inner quotes doubled, all
#   whitespace runs collapsed to one space).
#----------------------------------------------------------------------------
proc ::pis::common::quote_csv {text} {
    variable DQ
    set cleaned [string trim [regsub -all {\s+} $text " "]]
    set escaped [string map [list $DQ $DQ$DQ] $cleaned]
    return $DQ$escaped$DQ
}

#----------------------------------------------------------------------------
# write_status cfg runStatus completedStep errorStep errorMessage
#   Rewrites the workflow status file (exactly five parameters).
#----------------------------------------------------------------------------
proc ::pis::common::write_status {cfg runStatus completedStep errorStep errorMessage} {
    set statusPath [cfg_path $cfg working workflow_status]
    set content ""
    append content [format "run_status = %s\n" $runStatus]
    append content [format "completed_step = %s\n" $completedStep]
    append content [format "error_step = %s\n" $errorStep]
    append content [format "error_message = %s\n" $errorMessage]
    append content [format "updated = %s\n" [timestamp]]
    write_text_file $statusPath $content
    return $statusPath
}

#----------------------------------------------------------------------------
# append_run_status cfg stepID stepName status message
#   Appends one quoted CSV record; writes the header line when the file does
#   not exist yet or is empty.
#----------------------------------------------------------------------------
proc ::pis::common::append_run_status {cfg stepID stepName status message} {
    set csvPath [cfg_path $cfg working run_status_csv]

    set isNew 1
    if {[file exists $csvPath]} {
        if {[file size $csvPath] > 0} {
            set isNew 0
        }
    }

    set content ""
    if {$isNew} {
        append content "timestamp,step_id,step_name,status,message\n"
    }
    set fields [list \
        [quote_csv [timestamp]] \
        [quote_csv $stepID] \
        [quote_csv $stepName] \
        [quote_csv $status] \
        [quote_csv $message]]
    append content [join $fields ","]
    append content "\n"

    append_text_file $csvPath $content
    return $csvPath
}

#----------------------------------------------------------------------------
# require_file label file
#   Errors when file is empty, missing or not a regular file. Returns the
#   normalized absolute path.
#----------------------------------------------------------------------------
proc ::pis::common::require_file {label file} {
    if {[string trim $file] eq ""} {
        return -code error "$label path is empty."
    }
    if {![file exists $file]} {
        return -code error "$label not found: $file"
    }
    if {![file isfile $file]} {
        return -code error "$label is not a regular file: $file"
    }
    return [file normalize $file]
}

#----------------------------------------------------------------------------
# run_step cfg stepID stepName body
#   Marks the step as running in the status file, runs body (a script or a
#   command list) in the caller frame inside catch.
#   Failure (TCL_ERROR): error_log, run-status FAILED, status file update, then
#            the error is rethrown with errorcode pis STEP<id> FAILED.
#   Success (TCL_OK, and also TCL_RETURN / TCL_BREAK / TCL_CONTINUE because the
#            body runs in the caller frame): run-status PASSED, status file
#            update, body result returned.
#----------------------------------------------------------------------------
proc ::pis::common::run_step {cfg stepID stepName body} {
    # status file says running until the step ends (survives a HyperView crash)
    if {[catch {write_status $cfg running "" "" ""} preErr]} {
        catch {puts "WARNING: workflow status update failed for step $stepID: $preErr"}
    }

    set rc [catch {uplevel 1 $body} msg]

    if {$rc != 1} {
        if {[catch {append_run_status $cfg $stepID $stepName PASSED "Step finished successfully."} csvErr]} {
            catch {puts "WARNING: run-status logging failed for step $stepID: $csvErr"}
        }
        if {[catch {write_status $cfg passed $stepID "" ""} stErr]} {
            catch {puts "WARNING: workflow status update failed for step $stepID: $stErr"}
        }
        return $msg
    }

    set primaryMsg $msg
    if {[catch {error_log $cfg "Step $stepID ($stepName) failed: $primaryMsg"} errLogErr]} {
        catch {puts "WARNING: error log write failed for step $stepID: $errLogErr"}
    }
    if {[catch {append_run_status $cfg $stepID $stepName FAILED $primaryMsg} csvErr2]} {
        catch {puts "WARNING: run-status logging failed for step $stepID: $csvErr2"}
    }
    if {[catch {write_status $cfg failed "" $stepID $primaryMsg} stErr2]} {
        catch {puts "WARNING: workflow status update failed for step $stepID: $stErr2"}
    }

    return -code error -errorcode [list pis STEP$stepID FAILED] $primaryMsg
}
