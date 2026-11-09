# src/01_scripts/_tcl_pis_99_workflow_gui.tcl
# ::pis::gui — the single "PIS Workflow" window. Task T-003 builds the FRAME: window,
# block 0, the five module blocks (one shared module-list helper), log pane, status bar,
# busy lock. Layout per docs/refs/SPEC_gui.txt s.3, s.5, s.13.
# An action owned by a later task logs one explicit ERROR ("not wired yet"): no silent
# no-op, no fake run. Tcl 8.5 only: no tcllib, no try/finally, package require = Tk only.
namespace eval ::pis::gui {
    variable S [dict create busy 0]
    variable LOCK [list]
    variable BASE [dict create]
    variable EDIT [dict create]
}

proc ::pis::gui::log_line {level msg} {
    variable S
    if {![dict exists $S log]} {
        return ""
    }
    set w [dict get $S log]
    set line "[clock format [clock seconds] -format %H:%M:%S] [format %-5s $level] $msg"
    $w configure -state normal
    $w insert end "$line\n" [string tolower $level]
    $w see end
    $w configure -state disabled
    return $line
}

proc ::pis::gui::set_status {msg {color ""}} {
    variable S
    if {![dict exists $S status]} {
        return ""
    }
    if {$color eq ""} {
        set color black
    }
    set w [dict get $S status]
    $w configure -text "Status: $msg" -foreground $color
    return $msg
}

# Busy lock (SPEC_gui s.7): each lockable widget keeps its baseline state, so releasing
# the lock restores exactly the pre-lock state.
proc ::pis::gui::lock {path} {
    variable LOCK
    variable BASE
    if {[lsearch -exact $LOCK $path] < 0} {
        lappend LOCK $path
        dict set BASE $path [$path cget -state]
    }
    return $path
}

proc ::pis::gui::set_busy {flag} {
    variable S
    variable LOCK
    variable BASE
    set flag [expr {$flag ? 1 : 0}]
    dict set S busy $flag
    if {![dict exists $S top] || ![winfo exists [dict get $S top]]} {
        return $flag
    }
    foreach p $LOCK {
        if {![winfo exists $p]} {
            continue
        }
        set state disabled
        if {!$flag} {
            set state normal
            if {[dict exists $BASE $p]} {
                set state [dict get $BASE $p]
            }
        }
        $p configure -state $state
    }
    return $flag
}

# key | title | mode (radio = exactly one, check = multiple) | extra ("on" = legend switch)
proc ::pis::gui::module_specs {} {
    return [list \
        [dict create key result title "Load result" mode radio extra ""] \
        [dict create key legend title "Load Legend" mode radio extra on] \
        [dict create key measures title "Measures" mode check extra ""] \
        [dict create key section title "Section Cut" mode check extra ""] \
        [dict create key capture title "Capture" mode check extra ""]]
}

# Row indexes a module would run: the radio row, or every ticked checkbox row.
proc ::pis::gui::chosen {key} {
    variable S
    if {[dict get $S mode $key] eq "radio"} {
        set sel [dict get $S sel $key]
        if {$sel < 0} {
            return [list]
        }
        return [list $sel]
    }
    set out [list]
    set i 0
    foreach flag [dict get $S checked $key] {
        if {$flag} {
            lappend out $i
        }
        incr i
    }
    return $out
}

proc ::pis::gui::render {key} {
    variable S
    set lb [dict get $S mods $key lb]
    set check [expr {[dict get $S mode $key] eq "check"}]
    set flags [dict get $S checked $key]
    $lb delete 0 end
    set i 0
    foreach text [dict get $S items $key] {
        if {$check && [lindex $flags $i]} {
            $lb insert end "\[v\] $text"
        } elseif {$check} {
            $lb insert end "\[ \] $text"
        } else {
            $lb insert end $text
        }
        incr i
    }
    set sel [dict get $S sel $key]
    $lb selection clear 0 end
    if {$sel >= 0 && $sel < [$lb size]} {
        $lb selection set $sel
    }
    return [$lb size]
}

# Click: radio = select the row; check = toggle its box (row order never changes).
proc ::pis::gui::click {key x y} {
    variable S
    set lb [dict get $S mods $key lb]
    set idx [$lb nearest $y]
    if {$idx < 0 || $idx >= [$lb size]} {
        return 0
    }
    if {[dict get $S mode $key] eq "check"} {
        set flags [dict get $S checked $key]
        dict set S checked $key [lreplace $flags $idx $idx [expr {![lindex $flags $idx]}]]
    }
    dict set S sel $key $idx
    ::pis::gui::render $key
    return $idx
}

proc ::pis::gui::edit_at {key y} {
    variable S
    set lb [dict get $S mods $key lb]
    return [::pis::gui::edit_row $key [$lb nearest $y]]
}

# [+] inserts below the selected row (or at the end) and edits it immediately (s.5).
proc ::pis::gui::add_row {key} {
    variable S
    set sel [dict get $S sel $key]
    if {$sel < 0} {
        set sel [llength [dict get $S items $key]]
    } else {
        incr sel
    }
    dict set S items $key [linsert [dict get $S items $key] $sel ""]
    dict set S checked $key [linsert [dict get $S checked $key] $sel 1]
    dict set S sel $key $sel
    ::pis::gui::render $key
    ::pis::gui::edit_row $key $sel
    return $sel
}

proc ::pis::gui::del_row {key} {
    variable S
    set sel [dict get $S sel $key]
    if {$sel < 0 || $sel >= [llength [dict get $S items $key]]} {
        ::pis::gui::log_line WARN "module [dict get $S title $key]: no row selected, nothing removed"
        return 0
    }
    dict set S items $key [lreplace [dict get $S items $key] $sel $sel]
    dict set S checked $key [lreplace [dict get $S checked $key] $sel $sel]
    dict set S sel $key -1
    ::pis::gui::render $key
    return 1
}

# Inline edit: one entry placed over the row; Return/FocusOut commit, Escape drops it.
proc ::pis::gui::edit_row {key index} {
    variable S
    variable EDIT
    set lb [dict get $S mods $key lb]
    set bb ""
    if {$index >= 0 && $index < [$lb size]} {
        set bb [$lb bbox $index]
    }
    if {[llength $bb] == 0} {
        return 0
    }
    ::pis::gui::commit $key
    set e "$lb.edit"
    if {![winfo exists $e]} {
        set e [entry $e]
        bind $e <Return> [list ::pis::gui::commit $key]
        bind $e <Escape> [list ::pis::gui::edit_cancel $key]
        bind $e <FocusOut> [list ::pis::gui::commit $key]
    }
    $e delete 0 end
    $e insert 0 [lindex [dict get $S items $key] $index]
    place $e -in $lb -x [lindex $bb 0] -y [lindex $bb 1] -width [expr {[winfo width $lb] - 6}] -height [lindex $bb 3]
    focus $e
    $lb see $index
    dict set EDIT $key $index
    return 1
}

proc ::pis::gui::commit {key} {
    variable S
    variable EDIT
    if {![dict exists $EDIT $key]} {
        return ""
    }
    set idx [dict get $EDIT $key]
    dict unset EDIT $key
    set e "[dict get $S mods $key lb].edit"
    set text [$e get]
    place forget $e
    if {$idx >= 0 && $idx < [llength [dict get $S items $key]]} {
        dict set S items $key [lreplace [dict get $S items $key] $idx $idx $text]
    }
    ::pis::gui::render $key
    return $text
}

proc ::pis::gui::edit_cancel {key} {
    variable S
    variable EDIT
    place forget "[dict get $S mods $key lb].edit"
    dict unset EDIT $key
    ::pis::gui::render $key
    return 0
}

# Run seam. T-003 has no execution layer, so a real request is reported as an ERROR naming
# the module; an empty module is the WARN required by the SPEC error/empty states.
proc ::pis::gui::run_module {key scope} {
    variable S
    ::pis::gui::commit $key
    set title [dict get $S title $key]
    if {[llength [::pis::gui::chosen $key]] == 0} {
        ::pis::gui::log_line WARN "module $title: no item selected, nothing run"
        return 0
    }
    ::pis::gui::log_line ERROR "module $title: execution is not wired yet (frame task T-003, scope $scope)"
    ::pis::gui::set_status "Error: $title not available yet" red
    return 0
}

proc ::pis::gui::not_wired {what} {
    ::pis::gui::log_line ERROR "$what: not wired yet (frame task T-003)"
    ::pis::gui::set_status "Error: $what not available yet" red
    return 0
}

proc ::pis::gui::clear_log {} {
    variable S
    set w [dict get $S log]
    $w configure -state normal
    $w delete 1.0 end
    $w configure -state disabled
    return 1
}

# Shared module-list helper (SPEC_gui s.5): the module name IS the run-for-active-window
# button; then the user-typed list, [+] [-], and one [Apply all layout]. No global Run button.
proc ::pis::gui::module_block {parent spec} {
    variable S
    set key [dict get $spec key]
    set f [ttk::frame $parent.mod_$key -borderwidth 1 -relief groove -padding 4]
    set head [ttk::frame $f.head]
    pack $head -side top -fill x
    set name [ttk::button $head.run -text [dict get $spec title] -command [list ::pis::gui::run_module $key active]]
    pack $name -side left -fill x -expand 1
    if {[dict get $spec extra] eq "on"} {
        set ::pis::gui::on_$key 1
        set on [ttk::checkbutton $head.on -text "on" -variable ::pis::gui::on_$key]
        pack $on -side right -padx {6 0}
        dict set S on $key $on
    }
    set box [ttk::frame $f.box]
    pack $box -side top -fill both -expand 1 -pady {4 0}
    set lb [listbox $box.list -height 5 -exportselection 0 -activestyle none -yscrollcommand [list $box.yscroll set] -selectmode [expr {[dict get $spec mode] eq "radio" ? "browse" : "extended"}]]
    set sb [ttk::scrollbar $box.yscroll -orient vertical -command [list $lb yview]]
    pack $sb -side right -fill y
    pack $lb -side left -fill both -expand 1
    bind $lb <Button-1> [list ::pis::gui::click $key %x %y]
    bind $lb <Double-Button-1> [list ::pis::gui::edit_at $key %y]
    set bar [ttk::frame $f.bar]
    pack $bar -side top -fill x -pady {4 0}
    set plus [ttk::button $bar.plus -text "+" -width 3 -command [list ::pis::gui::add_row $key]]
    set minus [ttk::button $bar.minus -text "-" -width 3 -command [list ::pis::gui::del_row $key]]
    set apply [ttk::button $bar.apply -text "Apply all layout" -command [list ::pis::gui::run_module $key layout]]
    pack $plus -side left
    pack $minus -side left -padx {4 0}
    pack $apply -side right
    dict set S mods $key [dict create frame $f name $name lb $lb apply $apply]
    dict set S items $key [list]
    dict set S checked $key [list]
    dict set S sel $key -1
    dict set S mode $key [dict get $spec mode]
    dict set S title $key [dict get $spec title]
    ::pis::gui::lock $name
    ::pis::gui::lock $apply
    return $f
}

# Block 0 (SPEC_gui s.4): one model file, one result file per line/window, cols x rows,
# [Reset (New)], [Load All]. Behaviour arrives with T-006; the buttons say so when clicked.
proc ::pis::gui::block0 {parent} {
    variable S
    set f [ttk::labelframe $parent.block0 -text "0. Load model & results" -padding 4]
    grid columnconfigure $f 1 -weight 1
    grid rowconfigure $f 2 -weight 1
    ttk::label $f.modelLabel -text "Model file"
    set model [ttk::entry $f.model]
    set browse [ttk::button $f.modelBrowse -text "..." -width 3 -command [list ::pis::gui::not_wired "Browse model (T-006)"]]
    grid $f.modelLabel -row 0 -column 0 -sticky w
    grid $model -row 0 -column 1 -sticky we -padx 4
    grid $browse -row 0 -column 2 -sticky e
    ttk::label $f.resLabel -text "Result files (one per line = one window)"
    grid $f.resLabel -row 1 -column 0 -columnspan 3 -sticky w -pady {6 2}
    set lb [listbox $f.results -height 5 -exportselection 0 -yscrollcommand [list $f.resScroll set]]
    set sb [ttk::scrollbar $f.resScroll -orient vertical -command [list $lb yview]]
    grid $lb -row 2 -column 0 -columnspan 2 -sticky nsew -padx {0 4}
    grid $sb -row 2 -column 2 -sticky ns
    set bar [ttk::frame $f.bar]
    grid $bar -row 3 -column 0 -columnspan 3 -sticky we -pady {6 0}
    set add [ttk::button $bar.add -text "Add.." -command [list ::pis::gui::not_wired "Add result files (T-006)"]]
    set cols [ttk::entry $bar.cols -width 3]
    set rows [ttk::entry $bar.rows -width 3]
    pack $add -side left
    pack [ttk::label $bar.layoutLabel -text "Layout"] -side left -padx {12 4}
    pack $cols -side left
    pack [ttk::label $bar.x -text "x"] -side left -padx 2
    pack $rows -side left
    pack [ttk::label $bar.hint -text "(cols x rows)"] -side left -padx 4
    set buttons [ttk::frame $f.buttons]
    grid $buttons -row 4 -column 0 -columnspan 3 -sticky we -pady {6 0}
    set reset [ttk::button $buttons.reset -text "Reset (New)" -command [list ::pis::gui::not_wired "Reset (New) (T-006)"]]
    set loadAll [ttk::button $buttons.loadAll -text "Load All" -command [list ::pis::gui::not_wired "Load All (T-006)"]]
    pack $reset -side left
    pack $loadAll -side right
    dict set S block0 [dict create frame $f model $model cols $cols rows $rows results $lb add $add reset $reset loadAll $loadAll]
    ::pis::gui::lock $loadAll
    return $f
}

# The window (SPEC_gui s.3): LEFT = block 0 + five module blocks, RIGHT = log toolbar,
# log pane, status bar. Resizable: the left column keeps a sane width, the log stretches.
proc ::pis::gui::build {} {
    variable S
    if {[catch {package require Tk} err]} {
        error "::pis::gui::build needs Tk: $err"
    }
    set top .pis_workflow
    if {[winfo exists $top]} {
        wm deiconify $top
        raise $top
        return $top
    }
    set w [toplevel $top]
    wm title $w "PIS Workflow"
    wm minsize $w 960 600
    grid columnconfigure $w 0 -weight 0 -minsize 660
    grid columnconfigure $w 1 -weight 1
    grid rowconfigure $w 0 -weight 1
    set left [ttk::frame $w.left -padding 4]
    set right [ttk::frame $w.right -padding 4]
    grid $left -row 0 -column 0 -sticky nsew
    grid $right -row 0 -column 1 -sticky nsew
    grid columnconfigure $left 0 -weight 1
    grid rowconfigure $left 1 -weight 1
    grid [::pis::gui::block0 $left] -row 0 -column 0 -sticky nsew
    set mods [ttk::frame $left.mods]
    grid $mods -row 1 -column 0 -sticky nsew -pady {8 0}
    grid columnconfigure $mods 0 -weight 1
    grid columnconfigure $mods 1 -weight 1
    set i 0
    foreach spec [::pis::gui::module_specs] {
        grid [::pis::gui::module_block $mods $spec] -row [expr {$i / 2}] -column [expr {$i % 2}] -sticky nsew -padx {0 6} -pady {0 6}
        grid rowconfigure $mods [expr {$i / 2}] -weight 1
        incr i
    }
    grid columnconfigure $right 0 -weight 1
    grid rowconfigure $right 1 -weight 1
    set bar [ttk::frame $right.bar]
    grid $bar -row 0 -column 0 -sticky we
    pack [ttk::button $bar.clear -text "Clear" -command [list ::pis::gui::clear_log]] -side left
    pack [ttk::button $bar.save -text "Save" -command [list ::pis::gui::not_wired "Save journal (T-012)"]] -side left -padx {4 0}
    pack [ttk::button $bar.load -text "Load..." -command [list ::pis::gui::not_wired "Load log (T-012)"]] -side left -padx {4 0}
    set run [ttk::button $bar.run -text "Run log >" -command [list ::pis::gui::not_wired "Run log (T-012)"]]
    pack $run -side left -padx {4 0}
    set ::pis::gui::continue_on_error 0
    pack [ttk::checkbutton $bar.coe -text "continue on error" -variable ::pis::gui::continue_on_error] -side left -padx {12 0}
    set lf [ttk::frame $right.logframe]
    grid $lf -row 1 -column 0 -sticky nsew -pady {4 0}
    grid rowconfigure $lf 0 -weight 1
    grid columnconfigure $lf 0 -weight 1
    set log [text $lf.text -wrap none -height 20 -state disabled -font TkFixedFont -background white]
    set ysb [ttk::scrollbar $lf.yscroll -orient vertical -command [list $log yview]]
    set xsb [ttk::scrollbar $lf.xscroll -orient horizontal -command [list $log xview]]
    $log configure -yscrollcommand [list $ysb set] -xscrollcommand [list $xsb set]
    grid $log -row 0 -column 0 -sticky nsew
    grid $ysb -row 0 -column 1 -sticky ns
    grid $xsb -row 1 -column 0 -sticky we
    foreach pair {info #1f4e79 ok #1e6b28 warn #9a6400 error #a11c1c} {
        lassign $pair tag color
        $log tag configure $tag -foreground $color
    }
    set status [label $right.status -text "Status: Idle" -anchor w -relief sunken -borderwidth 1 -padx 4]
    grid $status -row 2 -column 0 -sticky we -pady {4 0}
    dict set S top $top
    dict set S log $log
    dict set S status $status
    ::pis::gui::lock $run
    ::pis::gui::log_line INFO "Workflow GUI started (frame only, task T-003)"
    ::pis::gui::set_status "Idle"
    return $top
}

# Sourcing this file opens the window. Set ::pis_gui_autobuild 0 first to load the procs
# without a display (tests/tcl/test_gui_frame.tcl does exactly that).
if {![info exists ::pis_gui_autobuild] || $::pis_gui_autobuild} {
    ::pis::gui::build
}
