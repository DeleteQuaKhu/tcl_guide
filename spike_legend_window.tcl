# src/spike/spike_legend_window.tcl — T-002 SPIKE HARNESS. Throwaway probe, NOT product code.
# Question: does `hwc result scalar legend import` act on the active window only or on
# every window of the layout, and which Tcl 8.5-only commands select window k of a CxR
# layout? Refs: docs/refs/SPEC_load_legend.txt FILE 3 (refresh_active_post, apply_file).
# Every HyperView call is probed with catch and its raw result is printed as
#   SPIKE: <label> | OK|ERROR | <value>
# so a wrong candidate command is data, not a crash, and nothing is guessed.
# ::spike::probe imports nothing; only ::spike::import* touch a legend file.
namespace eval ::spike {
    variable legendFile ""
    variable clicks 0
    variable lines {}
    variable clientName ""
    variable pageName ""
    variable windowName ""
}

proc ::spike::say {msg} {
    set line "[clock format [clock seconds] -format %H:%M:%S] SPIKE: $msg"
    puts $line
    lappend ::spike::lines $line
    return $line
}

# Run one candidate command and report its raw result. Never hides an error.
proc ::spike::attempt {label script} {
    if {[catch {uplevel 1 $script} res]} {
        ::spike::say "$label | ERROR | $res"
        return ""
    }
    ::spike::say "$label | OK | $res"
    return $res
}

proc ::spike::unique {tag} {
    incr ::spike::clicks
    return "pis_spike_${tag}_[pid]_$::spike::clicks"
}

proc ::spike::open {} {
    ::spike::attempt "hwi OpenStack" {hwi OpenStack}
    set ::spike::clientName [::spike::unique client]
    if {[catch {hwi GetActiveClientHandle $::spike::clientName} err]} {
        ::spike::say "hwi GetActiveClientHandle | ERROR | $err"
        return 0
    }
    ::spike::say "hwi GetActiveClientHandle | OK | $::spike::clientName"
    return 1
}

# HARD CONSTRAINT: every handle is released on the error path too.
proc ::spike::close {} {
    foreach h [list $::spike::windowName $::spike::pageName $::spike::clientName] {
        if {$h ne ""} {
            ::spike::attempt "ReleaseHandle $h" [list $h ReleaseHandle]
        }
    }
    set ::spike::windowName ""
    set ::spike::pageName ""
    set ::spike::clientName ""
    ::spike::attempt "hwi CloseStack" {hwi CloseStack}
}

# Read-only discovery: build/version commands, page and window handles, helper procs.
proc ::spike::probe {} {
    set ::spike::lines {}
    ::spike::say "=== probe start (imports nothing) ==="
    ::spike::attempt "info patchlevel" {info patchlevel}
    ::spike::attempt "hwi GetVersion" {hwi GetVersion}
    ::spike::attempt "hwc GetVersion" {hwc GetVersion}
    if {![::spike::open]} {
        ::spike::close
        ::spike::say "=== probe end: no client handle (is this the HyperView console?) ==="
        return
    }
    set c $::spike::clientName
    ::spike::attempt "$c GetPageCount" [list $c GetPageCount]
    set ::spike::pageName [::spike::unique page]
    ::spike::attempt "$c GetPageHandle" [list $c GetPageHandle $::spike::pageName]
    set p $::spike::pageName
    ::spike::attempt "$p GetWindowCount" [list $p GetWindowCount]
    ::spike::attempt "$p GetLayoutType" [list $p GetLayoutType]
    set ::spike::windowName [::spike::unique window]
    ::spike::attempt "$p GetWindowHandle (active)" [list $p GetWindowHandle $::spike::windowName]
    set probeWin [::spike::unique windowidx]
    ::spike::attempt "$p GetWindowHandle <name> 2" [list $p GetWindowHandle $probeWin 2]
    ::spike::attempt "ReleaseHandle $probeWin" [list $probeWin ReleaseHandle]
    ::spike::attempt "$p SetActiveWindow 2" [list $p SetActiveWindow 2]
    ::spike::attempt "info commands hwc" {info commands hwc}
    ::spike::attempt "info commands ::post::LoadSettings" {info commands ::post::LoadSettings}
    ::spike::attempt "info commands ::hwp::GetContourLegend" {info commands ::hwp::GetContourLegend}
    ::spike::close
    ::spike::say "=== probe end ==="
}

# A spike must fail loudly: no silent fallback, the offending path is in the message.
proc ::spike::check_file {path} {
    if {$path eq ""} {
        error "no legend file given: set ::spike::legendFile or pass an absolute path"
    }
    if {![file isfile $path]} {
        error "legend file not found: $path"
    }
    return $path
}

# Import into whatever window is active, then report. Watch which windows change.
proc ::spike::import {{path ""}} {
    if {$path eq ""} {
        set path $::spike::legendFile
    }
    ::spike::check_file $path
    ::spike::say "=== import start (active window) ==="
    if {![::spike::open]} {
        ::spike::close
        return
    }
    set c $::spike::clientName
    ::spike::attempt "hwc result scalar legend import $path" \
        [list hwc result scalar legend import $path]
    ::spike::attempt "$c Draw" [list $c Draw]
    ::spike::attempt "update idletasks" {update idletasks}
    ::spike::close
    ::spike::say "=== import end: note WHICH windows show the legend ==="
}

# Try to target window <index> of the layout, then import. Every step is probed.
proc ::spike::import_in_window {index {path ""}} {
    if {$path eq ""} {
        set path $::spike::legendFile
    }
    ::spike::check_file $path
    ::spike::say "=== import start (window index $index) ==="
    if {![::spike::open]} {
        ::spike::close
        return
    }
    set c $::spike::clientName
    set p [::spike::unique page]
    ::spike::attempt "$c GetPageHandle" [list $c GetPageHandle $p]
    set w [::spike::unique window]
    ::spike::attempt "$p GetWindowHandle $index" [list $p GetWindowHandle $w $index]
    ::spike::attempt "$p SetActiveWindow $index" [list $p SetActiveWindow $index]
    ::spike::attempt "hwc result scalar legend import $path" \
        [list hwc result scalar legend import $path]
    ::spike::attempt "$c Draw" [list $c Draw]
    ::spike::attempt "update idletasks" {update idletasks}
    ::spike::attempt "ReleaseHandle $w" [list $w ReleaseHandle]
    ::spike::attempt "ReleaseHandle $p" [list $p ReleaseHandle]
    ::spike::close
    ::spike::say "=== import end: note WHICH windows show the legend ==="
}

proc ::spike::report {} {
    puts "----- BEGIN COPY-BACK BLOCK -----"
    foreach line $::spike::lines {
        puts $line
    }
    puts "----- END COPY-BACK BLOCK -----"
}

proc ::spike::save {file} {
    set fh [open $file w]
    foreach line $::spike::lines {
        puts $fh $line
    }
    close $fh
    return $file
}

proc ::spike::help {} {
    puts "SPIKE usage (HyperView Tcl console):"
    puts "  ::spike::probe                           ;# build, handles, window count (imports nothing)"
    puts "  ::spike::import <legend.tcl>              ;# import into the ACTIVE window"
    puts "  ::spike::import_in_window 2 <legend.tcl>  ;# try window 2 of the layout"
    puts "  ::spike::report                           ;# print a copy-back block"
    puts "  ::spike::save <out.txt>                   ;# same block to a file"
}

::spike::say "harness loaded (T-002 spike); run ::spike::help"

