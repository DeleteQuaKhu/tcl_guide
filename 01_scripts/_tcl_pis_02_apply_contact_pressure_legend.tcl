#============================================================================
# _tcl_pis_02_apply_contact_pressure_legend.tcl
#
# Step 02 of the PIS workflow: apply a Contact Pressure contour legend Tcl file
# to the active HyperView contour (post) session.
#
# Tcl/Tk 8.5 compatible. No external packages, no tcllib, no try/finally.
#
# This file is deliberately self contained: the legend logic (handle handling,
# import, fallback, file checks) works even when _tcl_pis_00_common.tcl was
# never sourced. The shared helpers are only used when they exist.
#
# Public API (namespace ::pis::step02), one definition per procedure:
#   run                  root cfg
#   apply_file           legendFile
#   refresh_active_post
#   apply_via_hwp        legendFile
#   log_message          level msg ?cfg?
#   client_handle_name   purpose
#   standalone
#
# Strategy used by apply_file
#   1. primary   : hwc result scalar legend import <file>
#   2. fallback  : only when ::hwp::GetContourLegend exists -
#                  source the legend file, require ::post::LoadSettings,
#                  get a contour legend handle, apply, release everything.
#   3. otherwise : one combined error naming both failures.
#
# Assumption to verify once in your HyperView build (the adapter block is the
# only place that needs adapting): the argument lists of ::hwp::GetContourLegend
# and ::post::LoadSettings are read with info args, so a zero argument and a
# one argument (legend handle) form are both supported.
#============================================================================

namespace eval ::pis::step02 {
    variable version 1.0

    # folder of this script, captured while it is being sourced
    variable scriptDir [file dirname [file normalize [info script]]]

    # counter that makes every HyperView client handle name unique
    variable handleCounter 0

    # configuration dict of the current run (used for logging only); empty in
    # standalone mode
    variable currentCfg ""
}

#----------------------------------------------------------------------------
# client_handle_name purpose
#   Unique HyperView client handle name: pis_step02_<purpose>_<pid>_<n>
#----------------------------------------------------------------------------
proc ::pis::step02::client_handle_name {purpose} {
    variable handleCounter
    incr handleCounter
    return [format "pis_step02_%s_%s_%s" $purpose [pid] $handleCounter]
}

#----------------------------------------------------------------------------
# log_message level msg ?cfg?
#   Logs through ::pis::common::log when that procedure and a configuration
#   dict are available, otherwise echoes a timestamped line to the console.
#   Never raises an error because of logging.
#----------------------------------------------------------------------------
proc ::pis::step02::log_message {level msg {cfg ""}} {
    variable currentCfg

    set activeCfg $cfg
    if {$activeCfg eq ""} {
        set activeCfg $currentCfg
    }

    if {$activeCfg ne "" && [llength [info commands ::pis::common::log]] > 0} {
        if {[catch {::pis::common::log $activeCfg $level $msg} logLine]} {
            catch {puts "step02 $level: $msg (workflow log write failed: $logLine)"}
            return $msg
        }
        return $logLine
    }

    set stamp [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]
    set line [format "%s %-7s %s" $stamp [string toupper $level] $msg]
    catch {puts $line}
    return $line
}

#----------------------------------------------------------------------------
# refresh_active_post
#   Opens the HyperView stack, takes the active post client handle with a
#   unique name, redraws it, then always releases the handle and always closes
#   the stack - also when redrawing failed.
#----------------------------------------------------------------------------
proc ::pis::step02::refresh_active_post {} {
    set stackOpen 0
    set postHandle ""

    set rc [catch {
        hwi OpenStack
        set stackOpen 1

        set handleName [client_handle_name post]
        set returned [hwi GetActiveClientHandle $handleName]
        set postHandle $handleName
        if {[string trim $returned] ne ""} {
            set postHandle $returned
        }
        if {[llength [info commands $postHandle]] == 0} {
            error "hwi GetActiveClientHandle returned $postHandle which is not a usable HyperView handle (requested name: $handleName)"
        }

        $postHandle Draw
        if {[llength [info commands update]] > 0} {
            catch {update idletasks}
        }
    } err]

    if {$postHandle ne "" && [llength [info commands $postHandle]] > 0} {
        catch {$postHandle ReleaseHandle}
    }
    if {$stackOpen} {
        catch {hwi CloseStack}
    }

    if {$rc} {
        return -code error "Cannot refresh the active HyperView post session: $err"
    }
    return 1
}

#----------------------------------------------------------------------------
# apply_via_hwp legendFile
#   Fallback path, only reached when ::hwp::GetContourLegend exists.
#   Sources the legend file, requires ::post::LoadSettings, obtains a contour
#   legend handle, applies the settings, and releases every handle on every
#   path (success and error).
#----------------------------------------------------------------------------
proc ::pis::step02::apply_via_hwp {legendFile} {
    set stackOpen 0
    set postHandle ""
    set legendHandle ""
    set result ""

    set rc [catch {
        hwi OpenStack
        set stackOpen 1

        set handleName [client_handle_name hwp]
        set returned [hwi GetActiveClientHandle $handleName]
        set postHandle $handleName
        if {[string trim $returned] ne ""} {
            set postHandle $returned
        }
        if {[llength [info commands $postHandle]] == 0} {
            error "hwi GetActiveClientHandle returned $postHandle which is not a usable HyperView handle (requested name: $handleName)"
        }

        uplevel #0 [list source $legendFile]

        if {[llength [info commands ::post::LoadSettings]] == 0} {
            error "Legend file $legendFile was sourced but does not define the procedure ::post::LoadSettings"
        }

        set legendArgs [info args ::hwp::GetContourLegend]
        if {[llength $legendArgs] > 0} {
            set legendHandle [::hwp::GetContourLegend $handleName]
        } else {
            set legendHandle [::hwp::GetContourLegend]
        }
        if {[string trim $legendHandle] eq ""} {
            error "::hwp::GetContourLegend returned an empty contour legend handle for client handle $handleName"
        }

        set settingsArgs [info args ::post::LoadSettings]
        if {[llength $settingsArgs] > 0} {
            ::post::LoadSettings $legendHandle
            set result "Settings from $legendFile applied to contour legend handle $legendHandle"
        } else {
            ::post::LoadSettings
            set result "Settings from $legendFile applied through ::post::LoadSettings"
        }

        $postHandle Draw
    } err]

    if {$legendHandle ne "" && [llength [info commands $legendHandle]] > 0} {
        catch {$legendHandle ReleaseHandle}
    }
    if {$postHandle ne "" && [llength [info commands $postHandle]] > 0} {
        catch {$postHandle ReleaseHandle}
    }
    if {$stackOpen} {
        catch {hwi CloseStack}
    }

    if {$rc} {
        return -code error "Fallback legend apply failed for $legendFile: $err"
    }
    return $result
}

#----------------------------------------------------------------------------
# apply_file legendFile
#   Applies the legend file to the active HyperView contour.
#   Returns a human readable description of what was done, raises a specific
#   error (naming the path) when the file or the HyperView commands are wrong.
#----------------------------------------------------------------------------
proc ::pis::step02::apply_file {legendFile} {
    if {[string trim $legendFile] eq ""} {
        return -code error "apply_file: legend file path is empty."
    }
    if {![file exists $legendFile]} {
        return -code error "Legend file not found: $legendFile"
    }
    if {![file isfile $legendFile]} {
        return -code error "Legend path is not a regular file: $legendFile"
    }
    set absLegend [file normalize $legendFile]

    set importRc [catch {hwc result scalar legend import $absLegend} importErr]
    if {$importRc == 0} {
        set message "Legend imported with the HyperView command hwc result scalar legend import: $absLegend"
        log_message INFO $message
        if {[catch {refresh_active_post} refreshErr]} {
            log_message WARNING "View refresh after legend import failed: $refreshErr"
            append message " (warning: view refresh failed: $refreshErr)"
        }
        return $message
    }
    log_message WARNING "Legend import failed for $absLegend: $importErr"

    if {[llength [info commands ::hwp::GetContourLegend]] == 0} {
        return -code error "Cannot apply legend file $absLegend. The command hwc result scalar legend import failed: $importErr. The fallback procedure ::hwp::GetContourLegend does not exist in this HyperView session."
    }

    log_message INFO "Trying the ::hwp::GetContourLegend fallback for $absLegend"
    if {[catch {apply_via_hwp $absLegend} fallbackErr]} {
        return -code error "Cannot apply legend file $absLegend. Direct import failed: $importErr. Fallback through ::hwp::GetContourLegend failed: $fallbackErr"
    }

    set message "Legend applied through the ::hwp::GetContourLegend fallback: $fallbackErr"
    log_message INFO $message
    if {[catch {refresh_active_post} refreshErr2]} {
        log_message WARNING "View refresh after the fallback legend apply failed: $refreshErr2"
        append message " (warning: view refresh failed: $refreshErr2)"
    }
    return $message
}

#----------------------------------------------------------------------------
# run root cfg
#   Workflow entry point. Resolves format legend_file against root (unless it
#   is already absolute) and applies it. Logs through ::pis::common::log only
#   when that procedure exists.
#----------------------------------------------------------------------------
proc ::pis::step02::run {root cfg} {
    variable currentCfg

    if {[catch {dict exists $cfg format legend_file} noDict]} {
        return -code error "Step 02: the configuration value is not a dictionary (root: $root): $noDict"
    }
    if {![dict exists $cfg format legend_file]} {
        return -code error "Missing required config value: format legend_file (root: $root)"
    }

    set rawLegend [dict get $cfg format legend_file]
    if {[string trim $rawLegend] eq ""} {
        return -code error "The config value format legend_file is empty (root: $root)"
    }

    if {[file pathtype $rawLegend] eq "absolute"} {
        set legendPath [file normalize $rawLegend]
    } else {
        if {[string trim $root] eq ""} {
            return -code error "Cannot resolve the relative legend path $rawLegend because the workflow root folder is empty."
        }
        set legendPath [file normalize [file join $root $rawLegend]]
    }

    set currentCfg $cfg
    set result ""
    set rc [catch {
        log_message INFO "Step 02: applying legend file $legendPath" $cfg
        set result [apply_file $legendPath]
        log_message INFO "Step 02: $result" $cfg
    } err]
    set currentCfg ""

    if {$rc} {
        return -code error $err
    }
    return $result
}

#----------------------------------------------------------------------------
# standalone
#   Interactive mode used when this script is sourced directly (no
#   ::pis::run_from_gui). Asks for a legend file and applies it.
#----------------------------------------------------------------------------
proc ::pis::step02::standalone {} {
    variable scriptDir

    if {[llength [info commands tk_getOpenFile]] == 0} {
        return -code error "Tk is not available in this session, so no legend file can be picked. Run this script from a HyperView session with the GUI (or from the workflow GUI), or set ::pis::run_from_gui before sourcing it."
    }

    set initDir [file join [file dirname $scriptDir] 00_config]
    if {![file isdirectory $initDir]} {
        set initDir $scriptDir
    }

    set chosen [tk_getOpenFile \
        -title "Select Contact Pressure legend file" \
        -initialdir $initDir \
        -filetypes [list [list "Tcl legend files" .tcl] [list "All files" *]]]
    if {$chosen eq ""} {
        puts "pis::step02: standalone run cancelled, no legend file selected."
        return ""
    }

    set result [apply_file $chosen]
    catch {tk_messageBox -icon info -title "Apply Contact Pressure Legend" -message "Legend applied successfully.\n\n$result"}
    return $result
}

#----------------------------------------------------------------------------
# Standalone footer
#   Only runs when the script is sourced directly. The workflow GUI sets
#   ::pis::run_from_gui 1 before sourcing this file, so the GUI never gets a
#   second file dialog.
#----------------------------------------------------------------------------
if {![info exists ::pis::run_from_gui]} {
    if {[catch {::pis::step02::standalone} standaloneErr]} {
        catch {puts "ERROR: $standaloneErr"}
        if {[llength [info commands tk_messageBox]] > 0} {
            catch {tk_messageBox -icon error -title "Apply Contact Pressure Legend" -message $standaloneErr}
        }
    }
}
