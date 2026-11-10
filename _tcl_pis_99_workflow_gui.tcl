# src/01_scripts/_tcl_pis_99_workflow_gui.tcl
# ::pis::gui — the single "PIS Workflow" window. Task T-003 built the FRAME: window,
# block 0, the five module blocks (one shared module-list helper), log pane, status bar,
# busy lock. Task T-006 wires block 0 to ::pis::step01 (Load All / Reset (New), browse,
# Add.., config round-trip): every HyperView command comes from the ::pis::hw adapter
# (T-002c), so a saved journal replays the model and the window grid in a fresh session and
# no user library is involved (SPEC.md D2). Task T-007 wires the "Load Legend" block to
# ::pis::legend (radio list + "on" + journal + busy guard); its HyperView seam is NOT
# verified yet (SPEC Q3, T-002c adapter in place), so that module is partial on purpose. The
# other four modules still log one explicit ERROR ("not wired yet"): no silent no-op.
# Tcl 8.5 only: no tcllib, no try/finally, no package require beyond Tk.
#
# Sourcing order for a HyperView session: this file sources everything it needs, so
# `source <root>/01_scripts/_tcl_pis_99_workflow_gui.tcl` is the only command required.
set _pis_dir [file dirname [file normalize [info script]]]
foreach _pis_file {_tcl_pis_00_common.tcl _tcl_pis_10_hw.tcl _tcl_pis_11_hw_adapter.tcl \
        _tcl_pis_01_load_model_results.tcl _tcl_pis_02_load_legend.tcl} {
    set _pis_path [file join $_pis_dir $_pis_file]
    if {[catch {source $_pis_path} _pis_err]} {
        error "Cannot source $_pis_path: $_pis_err"
    }
}

namespace eval ::pis::gui {
    variable S [dict create busy 0]
    variable LOCK [list]
    variable BASE [dict create]
    variable EDIT [dict create]
    variable DIR $::_pis_dir
    variable ROOT [file dirname $::_pis_dir]
}
unset _pis_dir

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

# Busy guard (SPEC A11: a second click while a module runs does nothing). The buttons are
# locked too, but a queued event can still arrive; this is the one check every entry uses.
proc ::pis::gui::busy_guard {title} {
    variable S
    if {[dict get $S busy]} {
        ::pis::gui::log_line WARN "module $title: busy, request ignored"
        return 1
    }
    return 0
}

# Run seam. "legend" is wired (T-007); the other four modules still report one explicit
# ERROR naming the module, and an empty module is the WARN required by the SPEC states.
proc ::pis::gui::run_module {key scope} {
    variable S
    set title [dict get $S title $key]
    if {[::pis::gui::busy_guard $title]} {
        return 0
    }
    ::pis::gui::commit $key
    if {$key eq "legend"} {
        return [::pis::gui::run_legend $scope]
    }
    if {[llength [::pis::gui::chosen $key]] == 0} {
        ::pis::gui::log_line WARN "module $title: no item selected, nothing run"
        return 0
    }
    ::pis::gui::log_line ERROR "module $title: execution is not wired yet (frame task T-003, scope $scope)"
    ::pis::gui::set_status "Error: $title not available yet" red
    return 0
}

# --- Load Legend wiring (task T-007, partial: seam unverified) --------------
# The "on" checkbutton state; widgets absent (offline tests) = on.
proc ::pis::gui::legend_on {} {
    if {[info exists ::pis::gui::on_legend]} {
        return [expr {$::pis::gui::on_legend ? 1 : 0}]
    }
    return 1
}

# Widgets -> a THROWAWAY cfg for one run: the typed legend list and the radio selection are
# a session-only override and are NEVER written back to the ini (SPEC.md D1, SPEC_gui s.6.2).
proc ::pis::gui::legend_cfg {} {
    variable S
    set cfg [::pis::gui::workflow_cfg]
    set items [list]
    if {[dict exists $S items legend]} {
        set items [dict get $S items legend]
    }
    set sel -1
    if {[dict exists $S sel legend]} {
        set sel [dict get $S sel legend]
    }
    if {$sel < 0 || $sel >= [llength $items]} {
        set stamp 0
    } else {
        set stamp [expr {$sel + 1}]
    }
    set sec [dict create on [::pis::gui::legend_on] count [llength $items] selected $stamp]
    set i 1
    foreach item $items {
        dict set sec "item$i" $item
        incr i
    }
    dict set cfg legend $sec
    return $cfg
}

# Load Legend for the active window or for every window of the layout. Same shape as
# run_block0: build the cfg in memory, busy on, run, ALWAYS busy off, never save the ini.
proc ::pis::gui::run_legend {scope} {
    set cfg [::pis::gui::legend_cfg]
    set root [dict get $cfg root]
    ::pis::gui::set_busy 1
    set code [catch {::pis::legend::run $root $cfg $scope} res]
    ::pis::gui::set_busy 0
    if {$code} {
        ::pis::gui::log_line ERROR "module [::pis::legend::title]: $res"
        ::pis::gui::set_status "Error: $res" red
        return 0
    }
    if {$res == 0} {
        # on unchecked or nothing selected: ::pis::legend::run already logged INFO/WARN.
        ::pis::gui::set_status "Idle"
        return 0
    }
    if {$scope eq "layout"} {
        set msg "Load Legend: $res window(s) imported."
    } else {
        set msg "Load Legend: active window imported."
    }
    ::pis::gui::set_status $msg darkgreen
    return $res
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
        ::pis::gui::lock $on
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

# --- block 0 wiring (task T-006) -------------------------------------------
# The config dict is loaded once per session (SPEC.md D1: one ini, it also carries the
# last-used model/results/layout). Tests point ::pis::gui::ROOT at a scratch workspace.
proc ::pis::gui::workflow_cfg {} {
    variable S
    variable ROOT
    if {![dict exists $S cfg]} {
        dict set S cfg [::pis::common::load_config $ROOT]
    }
    return [dict get $S cfg]
}

# The four block-0 values as a plain dict (ini values, no widget access).
proc ::pis::gui::fields_from_cfg {cfg} {
    return [dict create \
        model_file [::pis::common::get $cfg session model_file ""] \
        result_files [::pis::common::get $cfg session result_files ""] \
        cols [::pis::common::get $cfg layout cols 4] \
        rows [::pis::common::get $cfg layout rows 2]]
}

# Fields -> cfg (in memory only, nothing is written yet).
proc ::pis::gui::cfg_with_fields {cfg fields} {
    dict set cfg session model_file [dict get $fields model_file]
    dict set cfg session result_files [dict get $fields result_files]
    dict set cfg layout cols [dict get $fields cols]
    dict set cfg layout rows [dict get $fields rows]
    return $cfg
}

# Widgets -> fields. Blank result lines are dropped; the rest keeps the list order.
proc ::pis::gui::read_block0 {} {
    variable S
    if {![dict exists $S block0]} {
        error "::pis::gui::read_block0: block 0 is not built"
    }
    set b [dict get $S block0]
    set files [list]
    foreach item [[dict get $b results] get 0 end] {
        set item [string trim $item]
        if {$item ne ""} { lappend files $item }
    }
    return [dict create \
        model_file [string trim [[dict get $b model] get]] \
        result_files $files \
        cols [string trim [[dict get $b cols] get]] \
        rows [string trim [[dict get $b rows] get]]]
}

# Fields -> widgets (used on start and after a reload of the config).
proc ::pis::gui::fill_block0 {fields} {
    variable S
    if {![dict exists $S block0]} {
        error "::pis::gui::fill_block0: block 0 is not built"
    }
    set b [dict get $S block0]
    set model [dict get $b model]
    $model delete 0 end
    $model insert 0 [dict get $fields model_file]
    set lb [dict get $b results]
    $lb delete 0 end
    foreach item [dict get $fields result_files] {
        $lb insert end $item
    }
    set cols [dict get $b cols]
    $cols delete 0 end
    $cols insert 0 [dict get $fields cols]
    set rows [dict get $b rows]
    $rows delete 0 end
    $rows insert 0 [dict get $fields rows]
    return $fields
}

# Persist block 0. A failed save is not fatal but never silent (SPEC.md: one WARN).
proc ::pis::gui::apply_block0 {fields} {
    variable S
    set cfg [::pis::gui::cfg_with_fields [::pis::gui::workflow_cfg] $fields]
    if {[catch {::pis::common::save_config $cfg} path]} {
        ::pis::gui::log_line WARN "config not saved: $path"
        return ""
    }
    dict set S cfg $cfg
    return $path
}

proc ::pis::gui::browse_model {} {
    variable S
    if {![dict exists $S block0]} {
        return 0
    }
    set path [tk_getOpenFile -title "Model file" -parent [dict get $S top] \
        -filetypes {{"Model files" {.inp .fem .key .dyn}} {"All files" {*}}}]
    if {$path eq ""} {
        return 0
    }
    set model [dict get [dict get $S block0] model]
    $model delete 0 end
    $model insert 0 $path
    ::pis::gui::log_line INFO "model selected: $path"
    return 1
}

proc ::pis::gui::add_result_files {} {
    variable S
    if {![dict exists $S block0]} {
        return 0
    }
    set paths [tk_getOpenFile -multiple 1 -title "Result files" -parent [dict get $S top] \
        -filetypes {{"Result files" {.h3d .op2 .odb .res .d3plot}} {"All files" {*}}}]
    if {[llength $paths] == 0} {
        return 0
    }
    set lb [dict get [dict get $S block0] results]
    foreach path $paths {
        $lb insert end $path
    }
    ::pis::gui::log_line INFO "added [llength $paths] result file(s)"
    return [llength $paths]
}

# [Remove] and the Delete/BackSpace keys drop every selected line of the result list, so a
# wrong Add.. needs no restart (the list is the user's, not the program's). Selection is
# extended: Ctrl/Shift+click removes several lines at once. Nothing is persisted here; the
# list reaches the ini only when Load All / Reset (New) succeeds.
proc ::pis::gui::remove_result_files {} {
    variable S
    if {![dict exists $S block0]} {
        return 0
    }
    set lb [dict get [dict get $S block0] results]
    set picked [$lb curselection]
    if {[llength $picked] == 0} {
        ::pis::gui::log_line WARN "no result file selected, nothing removed"
        return 0
    }
    foreach i [lsort -integer -decreasing $picked] {
        $lb delete $i
    }
    ::pis::gui::log_line INFO "removed [llength $picked] result file(s)"
    return [llength $picked]
}

# Load All / Reset (New). Both follow the same shape: read the widgets, build the cfg in
# memory, lock the buttons, run the step, ALWAYS unlock, persist only on success.
# mode: "load" -> ::pis::step01::load_all, "reset" -> ::pis::step01::reset_session.
proc ::pis::gui::run_block0 {mode} {
    variable S
    if {$mode eq "reset"} {
        set label "Reset (New)"
    } else {
        set label "Load All"
    }
    set fields [::pis::gui::read_block0]
    set cfg [::pis::gui::cfg_with_fields [::pis::gui::workflow_cfg] $fields]
    ::pis::gui::lock [dict get [dict get $S block0] loadAll]
    ::pis::gui::set_busy 1
    if {$mode eq "reset"} {
        set code [catch {::pis::step01::reset_session} res]
    } else {
        set code [catch {::pis::step01::load_all $cfg} res]
    }
    ::pis::gui::set_busy 0
    if {$code} {
        ::pis::gui::log_line ERROR "$label: $res"
        ::pis::gui::set_status "Error: $res" red
        return 0
    }
    ::pis::gui::apply_block0 $fields
    if {$mode eq "reset"} {
        ::pis::gui::log_line OK "$label: session cleared"
        ::pis::gui::set_status "Idle" ""
        return 1
    }
    set n [llength [dict get $fields result_files]]
    # The step order is part of the result line: a Load All that needed order 2 must be
    # visible in the status bar, not only in the log (SPEC ENV: no silent mode).
    set msg [format "Loaded %d result(s) into %d window(s), order %d." \
        $n $res [::pis::hw::order]]
    ::pis::gui::log_line OK "$label: $msg"
    ::pis::gui::set_status $msg darkgreen
    return $res
}

proc ::pis::gui::load_all {} {
    return [::pis::gui::run_block0 load]
}

# [Reset (New)] asks first (SPEC_gui s.4: "ask to confirm").
proc ::pis::gui::reset_all {} {
    if {[llength [info commands tk_messageBox]] > 0} {
        set answer [tk_messageBox -type yesno -default no -icon question \
            -title "Reset (New)" -message "Close the windows and reset the session?"]
        if {$answer ne "yes"} {
            ::pis::gui::log_line INFO "Reset (New): cancelled by the user"
            return 0
        }
    }
    return [::pis::gui::run_block0 reset]
}

# Block 0 (SPEC_gui s.4): one model file, one result file per line/window, cols x rows,
# [Reset (New)], [Load All]. Wired in T-006 to ::pis::step01.
proc ::pis::gui::block0 {parent} {
    variable S
    set f [ttk::labelframe $parent.block0 -text "0. Load model & results" -padding 4]
    grid columnconfigure $f 1 -weight 1
    grid rowconfigure $f 2 -weight 1
    ttk::label $f.modelLabel -text "Model file"
    set model [ttk::entry $f.model]
    set browse [ttk::button $f.modelBrowse -text "..." -width 3 -command [list ::pis::gui::browse_model]]
    grid $f.modelLabel -row 0 -column 0 -sticky w
    grid $model -row 0 -column 1 -sticky we -padx 4
    grid $browse -row 0 -column 2 -sticky e
    ttk::label $f.resLabel -text "Result files (one per line = one window)"
    grid $f.resLabel -row 1 -column 0 -columnspan 3 -sticky w -pady {6 2}
    set lb [listbox $f.results -height 5 -exportselection 0 -selectmode extended \
        -yscrollcommand [list $f.resScroll set]]
    set sb [ttk::scrollbar $f.resScroll -orient vertical -command [list $lb yview]]
    grid $lb -row 2 -column 0 -columnspan 2 -sticky nsew -padx {0 4}
    grid $sb -row 2 -column 2 -sticky ns
    # A wrong Add.. must never need a restart: [Remove] and the Delete/BackSpace keys drop
    # the selected line(s) (Ctrl/Shift+click selects several).
    bind $lb <Delete> [list ::pis::gui::remove_result_files]
    bind $lb <BackSpace> [list ::pis::gui::remove_result_files]
    set bar [ttk::frame $f.bar]
    grid $bar -row 3 -column 0 -columnspan 3 -sticky we -pady {6 0}
    set add [ttk::button $bar.add -text "Add.." -command [list ::pis::gui::add_result_files]]
    set remove [ttk::button $bar.remove -text "Remove" \
        -command [list ::pis::gui::remove_result_files]]
    set cols [ttk::entry $bar.cols -width 3]
    set rows [ttk::entry $bar.rows -width 3]
    pack $add -side left
    pack $remove -side left -padx {4 0}
    pack [ttk::label $bar.layoutLabel -text "Layout"] -side left -padx {12 4}
    pack $cols -side left
    pack [ttk::label $bar.x -text "x"] -side left -padx 2
    pack $rows -side left
    pack [ttk::label $bar.hint -text "(cols x rows)"] -side left -padx 4
    set buttons [ttk::frame $f.buttons]
    grid $buttons -row 4 -column 0 -columnspan 3 -sticky we -pady {6 0}
    set reset [ttk::button $buttons.reset -text "Reset (New)" -command [list ::pis::gui::reset_all]]
    set loadAll [ttk::button $buttons.loadAll -text "Load All" -command [list ::pis::gui::load_all]]
    pack $reset -side left
    pack $loadAll -side right
    dict set S block0 [dict create frame $f model $model cols $cols rows $rows results $lb \
        add $add remove $remove reset $reset loadAll $loadAll]
    ::pis::gui::lock $remove
    ::pis::gui::lock $reset
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
    ::pis::gui::log_line INFO "BUILD $::pis::BUILD | Workflow GUI started (block 0 + Load Legend wired; tasks T-006, T-007)"
    ::pis::gui::set_status "Idle"
    ::pis::gui::fill_block0 [::pis::gui::fields_from_cfg [::pis::gui::workflow_cfg]]
    return $top
}

# Sourcing this file opens the window. Set ::pis_gui_autobuild 0 first to load the procs
# without a display (tests/tcl/test_gui_frame.tcl does exactly that).
if {![info exists ::pis_gui_autobuild] || $::pis_gui_autobuild} {
    ::pis::gui::build
}
