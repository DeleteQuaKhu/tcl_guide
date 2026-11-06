#============================================================================
# _tcl_pis_99_workflow_gui.tcl
#
# Minimal PIS workflow GUI: one button, one step (apply the Contact Pressure
# legend to the active HyperView contour).
#
# Tcl/Tk 8.5 compatible. Needs Tk (no other package). No tcllib, no
# try/finally. All state lives in namespace ::pis099::gui, nothing is shared
# with older workflow GUIs.
#
# Layout of the window
#   working folder entry + Browse + Reload Config
#   legend file entry    + Browse Legend
#   Load Legend button
#   read-only log text with scroll bar
#
# Public API (namespace ::pis099::gui), one definition per procedure:
#   launch          ?rootDir?
#   build_ui
#   browse_root
#   browse_legend
#   reload_config
#   load_legend
#   step_settings   cfg
#   ui_log          msg
#   show_error      msg
#   show_info       msg
#
# Notes
#   - The step id, script file, proc name and title are all read from the
#     configuration (workflow run_order + the matching script section), no step
#     table is hard coded here.
#   - Browse Legend only changes the in memory configuration dictionary; the
#     .ini file is never written by this GUI.
#   - Set ::pis099_no_autolaunch (plain global name) before sourcing to load
#     the procedures without opening the window.
#============================================================================

namespace eval ::pis099::gui {
    variable version 1.0

    # folder of this script, captured while it is being sourced
    variable scriptDir [file dirname [file normalize [info script]]]
    variable commonFile ""

    # window / widget handles
    variable win .pis099_workflow
    variable logWidget ""
    variable statusWidget ""

    # state: root folder text, legend file text, configuration, flags
    variable rootVar ""
    variable legendVar ""
    variable cfg ""
    variable configLoaded 0
    variable busy 0
}

#----------------------------------------------------------------------------
# Load the shared library from the folder that contains this script.
#----------------------------------------------------------------------------
set ::pis099::gui::commonFile [file join $::pis099::gui::scriptDir _tcl_pis_00_common.tcl]
if {[llength [info commands ::pis::common::load_config]] == 0} {
    if {![file isfile $::pis099::gui::commonFile]} {
        return -code error "Cannot load the shared library, file not found: $::pis099::gui::commonFile"
    }
    uplevel #0 [list source $::pis099::gui::commonFile]
}

#----------------------------------------------------------------------------
# launch ?rootDir?
#   Creates (or raises) the toplevel .pis099_workflow. When rootDir is empty
#   the parent folder of this script folder is used, i.e. the folder that
#   contains 00_config and 01_scripts.
#----------------------------------------------------------------------------
proc ::pis099::gui::launch {{rootDir ""}} {
    variable win
    variable rootVar
    variable scriptDir

    if {[llength [info commands toplevel]] == 0} {
        return -code error "Tk is not available in this session, the workflow GUI cannot be created."
    }

    if {$rootDir eq ""} {
        set rootDir [file dirname $scriptDir]
    }

    if {[winfo exists $win]} {
        wm deiconify $win
        raise $win
        return $win
    }

    set rootVar [file normalize $rootDir]
    build_ui

    wm deiconify $win
    raise $win
    catch {focus $win}

    ui_log "Workflow GUI started. Script folder: $scriptDir"
    reload_config
    return $win
}

#----------------------------------------------------------------------------
# build_ui
#   Creates every widget of the window (no -command uses string substitution,
#   each callback is a fully qualified procedure name).
#----------------------------------------------------------------------------
proc ::pis099::gui::build_ui {} {
    variable win
    variable logWidget
    variable statusWidget

    if {[winfo exists $win]} {
        destroy $win
    }
    toplevel $win
    wm title $win "PIS Workflow - Apply Contact Pressure Legend"
    catch {wm minsize $win 660 420}

    # ---- working folder row ------------------------------------------------
    set rowRoot [frame $win.rowRoot]
    pack $rowRoot -side top -fill x -padx 8 -pady 6
    label $rowRoot.lbl -text "Working folder:" -width 15 -anchor w
    entry $rowRoot.ent -textvariable ::pis099::gui::rootVar -width 54
    button $rowRoot.browse -text "Browse..." -command ::pis099::gui::browse_root
    button $rowRoot.reload -text "Reload Config" -command ::pis099::gui::reload_config
    pack $rowRoot.lbl -side left
    pack $rowRoot.ent -side left -fill x -expand 1 -padx 4
    pack $rowRoot.browse -side left
    pack $rowRoot.reload -side left -padx 4

    # ---- legend file row ---------------------------------------------------
    set rowLegend [frame $win.rowLegend]
    pack $rowLegend -side top -fill x -padx 8 -pady 6
    label $rowLegend.lbl -text "Legend file:" -width 15 -anchor w
    entry $rowLegend.ent -textvariable ::pis099::gui::legendVar -width 54
    button $rowLegend.browse -text "Browse Legend..." -command ::pis099::gui::browse_legend
    pack $rowLegend.lbl -side left
    pack $rowLegend.ent -side left -fill x -expand 1 -padx 4
    pack $rowLegend.browse -side left

    # ---- action row --------------------------------------------------------
    set rowAction [frame $win.rowAction]
    pack $rowAction -side top -fill x -padx 8 -pady 6
    button $rowAction.run -text "Load Legend" -width 18 -command ::pis099::gui::load_legend
    label $rowAction.status -text "Configuration not loaded." -anchor w
    pack $rowAction.run -side left
    pack $rowAction.status -side left -padx 8
    set statusWidget $rowAction.status

    # ---- log area ----------------------------------------------------------
    set logFrame [frame $win.logFrame -borderwidth 1 -relief sunken]
    pack $logFrame -side top -fill both -expand 1 -padx 8 -pady 6
    set txt [text $logFrame.txt -height 14 -wrap none -state disabled -font TkFixedFont]
    set sb [scrollbar $logFrame.sb -orient vertical -command [list $txt yview]]
    $txt configure -yscrollcommand [list $sb set]
    pack $sb -side right -fill y
    pack $txt -side left -fill both -expand 1
    set logWidget $txt

    return $win
}

#----------------------------------------------------------------------------
# browse_root
#   Pick the workflow root folder, then reload the configuration from it.
#----------------------------------------------------------------------------
proc ::pis099::gui::browse_root {} {
    variable rootVar

    if {[llength [info commands tk_chooseDirectory]] == 0} {
        show_error "Folder selection is not available in this Tcl/Tk build (tk_chooseDirectory is missing)."
        return 0
    }

    set current [string trim $rootVar]
    if {![file isdirectory $current]} {
        set current [pwd]
    }

    set chosen ""
    if {[catch {tk_chooseDirectory -title "Select the workflow root folder" -initialdir $current -mustexist 1} chosen]} {
        show_error "Folder selection failed:\n$chosen"
        return 0
    }
    if {$chosen eq ""} {
        return 0
    }

    set rootVar [file normalize $chosen]
    ui_log "Working folder set to: $rootVar"
    return [reload_config]
}

#----------------------------------------------------------------------------
# browse_legend
#   Pick a legend Tcl file. The choice is stored in the in memory configuration
#   dictionary only; the .ini file is never modified.
#----------------------------------------------------------------------------
proc ::pis099::gui::browse_legend {} {
    variable cfg
    variable configLoaded
    variable legendVar

    if {[llength [info commands tk_getOpenFile]] == 0} {
        show_error "File selection is not available in this Tcl/Tk build (tk_getOpenFile is missing)."
        return 0
    }
    if {!$configLoaded} {
        show_error "No configuration is loaded yet. Press Reload Config first, then pick the legend file."
        return 0
    }

    set startDir [string trim $legendVar]
    if {$startDir ne ""} {
        set startDir [file dirname $startDir]
    }
    if {$startDir eq "" || ![file isdirectory $startDir]} {
        set projectRoot [dict get $cfg root]
        set startDir [file join $projectRoot 00_config]
        if {![file isdirectory $startDir]} {
            set startDir $projectRoot
        }
    }

    set chosen ""
    if {[catch {tk_getOpenFile -title "Select the Contact Pressure legend file" -initialdir $startDir -filetypes [list [list "Tcl legend files" .tcl] [list "All files" *]]} chosen]} {
        show_error "File selection failed:\n$chosen"
        return 0
    }
    if {$chosen eq ""} {
        return 0
    }

    set absLegend [file normalize $chosen]
    set legendVar $absLegend
    dict set cfg format legend_file $absLegend
    ui_log "Legend file override (session only, the .ini file is untouched): $absLegend"
    return 1
}

#----------------------------------------------------------------------------
# reload_config
#   Reads the configuration file from the folder shown in the working folder
#   entry, creates the working folders and prefills the legend entry.
#----------------------------------------------------------------------------
proc ::pis099::gui::reload_config {} {
    variable rootVar
    variable legendVar
    variable cfg
    variable configLoaded
    variable statusWidget

    set rootDir [string trim $rootVar]
    if {$rootDir eq ""} {
        show_error "The working folder is empty. Enter the workflow root folder (the folder that contains 00_config and 01_scripts)."
        return 0
    }
    if {![file isdirectory $rootDir]} {
        show_error "The working folder does not exist or is not a folder:\n$rootDir"
        return 0
    }

    set loaded ""
    if {[catch {::pis::common::load_config $rootDir} loaded]} {
        ui_log "ERROR configuration not loaded: $loaded"
        show_error "Cannot load the workflow configuration:\n$loaded"
        return 0
    }

    set created ""
    if {[catch {::pis::common::ensure_directories $loaded} created]} {
        ui_log "ERROR working folders not created: $created"
        show_error "Cannot create the workflow folders:\n$created"
        return 0
    }

    set cfg $loaded
    set configLoaded 1
    set rootDir [dict get $cfg root]
    set rootVar $rootDir

    set legendPath ""
    set rc [catch {::pis::common::cfg_path $cfg format legend_file} legendPath]
    if {$rc} {
        ui_log "WARNING legend file path cannot be resolved: $legendPath"
        set legendPath ""
    }
    set legendVar $legendPath

    set cfgFile [dict get $cfg config_file]
    set loadedMsg "Configuration loaded from: $cfgFile"
    ui_log $loadedMsg
    if {[llength $created] > 0} {
        ui_log "Created folders: [join $created {, }]"
    }
    catch {::pis::common::log $cfg INFO $loadedMsg} errLog1
    catch {::pis::common::log $cfg INFO "Legend file from configuration: $legendPath"} errLog2

    if {$statusWidget ne ""} {
        if {[winfo exists $statusWidget]} {
            set shortName [file tail $cfgFile]
            $statusWidget configure -text "Config loaded: $shortName"
        }
    }
    return 1
}

#----------------------------------------------------------------------------
# step_settings cfg
#   Reads workflow run_order and the matching script section and returns a
#   dict with id, file (absolute), proc and title. Nothing is hard coded.
#----------------------------------------------------------------------------
proc ::pis099::gui::step_settings {cfg} {
    set runOrder [::pis::common::get $cfg workflow run_order]
    set stepID [string trim [lindex $runOrder 0]]
    if {$stepID eq ""} {
        return -code error "The workflow run_order value is empty in the configuration."
    }

    set section "script_$stepID"
    if {![dict exists $cfg $section]} {
        return -code error "The configuration has no step section for step $stepID (expected a section named $section in the .ini file)."
    }

    set stepEnabled [::pis::common::get $cfg $section enabled]
    if {![::pis::common::is_true $stepEnabled]} {
        return -code error "Step $stepID is disabled in the configuration (enabled = $stepEnabled)."
    }

    set stepFile [::pis::common::get $cfg $section file]
    set stepProc [::pis::common::get $cfg $section proc]
    set stepTitle [::pis::common::get $cfg $section title]

    if {[file pathtype $stepFile] eq "absolute"} {
        set absFile [file normalize $stepFile]
    } else {
        set scriptDir [::pis::common::cfg_path $cfg folders script_dir]
        set absFile [file normalize [file join $scriptDir $stepFile]]
    }

    return [dict create id $stepID file $absFile proc $stepProc title $stepTitle]
}

#----------------------------------------------------------------------------
# load_legend
#   The single workflow action: source the step script named in the
#   configuration, then run its procedure through ::pis::common::run_step.
#----------------------------------------------------------------------------
proc ::pis099::gui::load_legend {} {
    variable cfg
    variable configLoaded
    variable legendVar
    variable busy
    variable statusWidget

    if {$busy} {
        show_error "A step is already running. Wait until it has finished."
        return 0
    }
    if {!$configLoaded} {
        show_error "No configuration is loaded. Press Reload Config first."
        return 0
    }

    set rawLegend [string trim $legendVar]
    if {$rawLegend eq ""} {
        show_error "The legend file path is empty. Use Browse Legend to select a legend Tcl file."
        ui_log "ERROR Load Legend aborted: the legend file path is empty."
        return 0
    }

    set rootDir [dict get $cfg root]
    set legendPath ""
    if {[catch {::pis::common::resolve_path $rootDir $rawLegend} legendPath]} {
        show_error "Cannot resolve the legend file path:\n$legendPath"
        ui_log "ERROR $legendPath"
        return 0
    }

    set stepInfo ""
    if {[catch {step_settings $cfg} stepInfo]} {
        show_error "Cannot read the step configuration:\n$stepInfo"
        ui_log "ERROR step configuration: $stepInfo"
        return 0
    }
    set stepID [dict get $stepInfo id]
    set stepProc [dict get $stepInfo proc]
    set stepTitle [dict get $stepInfo title]
    set stepFile ""

    if {[catch {::pis::common::require_file "Step $stepID script" [dict get $stepInfo file]} stepFile]} {
        show_error $stepFile
        ui_log "ERROR $stepFile"
        return 0
    }
    if {[catch {::pis::common::require_file "Legend file" $legendPath} checkedLegend]} {
        show_error $checkedLegend
        ui_log "ERROR $checkedLegend"
        return 0
    }
    set legendPath $checkedLegend
    # session override only - the .ini file is never written
    dict set cfg format legend_file $legendPath
    set legendVar $legendPath

    set busy 1
    if {$statusWidget ne ""} {
        if {[winfo exists $statusWidget]} {
            $statusWidget configure -text "Running step $stepID ..."
        }
    }

    set startMsg "Starting step $stepID ($stepTitle) with legend file $legendPath"
    ui_log $startMsg
    catch {::pis::common::log $cfg INFO $startMsg} errLogStart

    # GUI mode: the step script must not open its own file dialog
    set ::pis::run_from_gui 1
    set body [list $stepProc $rootDir $cfg]

    set rc [catch {
        uplevel #0 [list source $stepFile]
        if {[llength [info commands $stepProc]] == 0} {
            error "The procedure $stepProc was not defined after sourcing $stepFile"
        }
        set stepResult [::pis::common::run_step $cfg $stepID $stepTitle $body]
    } stepResult]

    # cleanup in the style of finally: catch plus explicit unset
    catch {unset -nocomplain ::pis::run_from_gui}
    set busy 0

    if {$rc} {
        set failMsg "Step $stepID failed: $stepResult"
        ui_log "ERROR $failMsg"
        if {$statusWidget ne ""} {
            if {[winfo exists $statusWidget]} {
                $statusWidget configure -text "Step $stepID failed."
            }
        }
        show_error $failMsg
        return 0
    }

    set doneMsg "Step $stepID finished: $stepResult"
    ui_log $doneMsg
    catch {::pis::common::log $cfg INFO $doneMsg} errLogDone
    if {$statusWidget ne ""} {
        if {[winfo exists $statusWidget]} {
            $statusWidget configure -text "Step $stepID finished."
        }
    }
    show_info "Step $stepID\n\n$stepResult"
    return 1
}

#----------------------------------------------------------------------------
# ui_log msg
#   Appends a timestamped line to the read only log widget (last 2000 lines
#   are kept). Does nothing when the widget is not created yet.
#----------------------------------------------------------------------------
proc ::pis099::gui::ui_log {msg} {
    variable logWidget

    if {$logWidget eq ""} {
        return 0
    }
    if {![winfo exists $logWidget]} {
        return 0
    }

    set stamp [::pis::common::timestamp]
    $logWidget configure -state normal
    $logWidget insert end "$stamp $msg\n"

    set lineCount [lindex [split [$logWidget index end] .] 0]
    if {$lineCount > 2000} {
        $logWidget delete 1.0 500.0
    }
    $logWidget see end
    $logWidget configure -state disabled
    return 1
}

#----------------------------------------------------------------------------
# show_error msg
#   Error dialog (falls back to the console when Tk is missing).
#----------------------------------------------------------------------------
proc ::pis099::gui::show_error {msg} {
    variable win

    if {[llength [info commands tk_messageBox]] == 0} {
        catch {puts "ERROR: $msg"}
        return 0
    }
    if {[winfo exists $win]} {
        catch {tk_messageBox -icon error -title "PIS Workflow" -message $msg -parent $win}
    } else {
        catch {tk_messageBox -icon error -title "PIS Workflow" -message $msg}
    }
    return 0
}

#----------------------------------------------------------------------------
# show_info msg
#   Information dialog (falls back to the console when Tk is missing).
#----------------------------------------------------------------------------
proc ::pis099::gui::show_info {msg} {
    variable win

    if {[llength [info commands tk_messageBox]] == 0} {
        catch {puts "INFO: $msg"}
        return 0
    }
    if {[winfo exists $win]} {
        catch {tk_messageBox -icon info -title "PIS Workflow" -message $msg -parent $win}
    } else {
        catch {tk_messageBox -icon info -title "PIS Workflow" -message $msg}
    }
    return 0
}

#----------------------------------------------------------------------------
# Footer: open the window when Tk is available.
#   To load the procedures only (no window), set one of these before sourcing:
#       set ::pis099_no_autolaunch 1            (plain global, always works)
#       set ::pis099::gui_no_autolaunch 1       (after namespace eval ::pis099 {})
#----------------------------------------------------------------------------
if {![info exists ::pis099_no_autolaunch]} {
    if {![info exists ::pis099::gui_no_autolaunch]} {
        if {[llength [info commands tk_messageBox]] == 0} {
            puts "pis099::gui: Tk is not available in this session, source this script from a GUI enabled HyperView session."
        } else {
            if {[catch {::pis099::gui::launch} launchErr]} {
                catch {puts "ERROR: cannot start the workflow GUI: $launchErr"}
                catch {tk_messageBox -icon error -title "PIS Workflow" -message "Cannot start the workflow GUI:\n$launchErr"}
            }
        }
    }
}
