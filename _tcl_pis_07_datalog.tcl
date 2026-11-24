# src/01_scripts/_tcl_pis_07_datalog.tcl
# ::pis::dlog - the reader of the two comma-separated data files (task T-038; T-037 reuses it
# unchanged for Result.log).
# Tcl/Tk 8.5 compatible, no tcllib, no network, no package require.
# Sourcing this file defines procs only: it never calls HyperView and never writes a journal line,
# which is exactly what "parse before act" needs (docs/refs/SPEC_gui.txt s.15.1).
#
# THE GRAMMAR (one grammar, two files - docs/refs/SPEC_gui.txt s.15.1):
#   - blank lines are ignored everywhere; a line's trailing and leading blanks are trimmed;
#   - a line whose first non-blank character is "#" opens a SECTION, named <Kind><N>
#     (`Spec1` in Result.log, `Note1` in Notes.log, case-insensitive);
#   - any other line is a DATA ROW: exactly FIVE comma-separated fields, each trimmed;
#   - a row whose SECOND field is the literal column name (`Node_ID` / `Text`, case-insensitive)
#     is a skipped header - that is what makes the owner's own template line valid input;
#   - an EMPTY field, a field count other than five, a non-numeric number field, a row outside a
#     section, the same section twice and a file without any section are ERRORs.
#
# Every refusal is ONE line that names the file (its own name, not the full path) and the line
# number, because the owner reads it in the log pane and edits the file with it.
#
# WHAT IS AN ASSUMPTION: the Notes.log row shape (Q8-Q11 of docs/SPEC.md) and the #Note<N> section
# word. docs/refs/samples/Notes.log ships as a placeholder and is replaced together with the spec
# row the day the owner pastes his real file.
#
# Public procs:
#   ::pis::dlog::parse {path kind}                  -> the whole document (raises the ERRORs)
#   ::pis::dlog::parse_text {text kind {tail}}      -> the same over text (offline tests)
#   ::pis::dlog::windows {cfg path section count id} -> windows a section names (Q3), raises A20
#   ::pis::dlog::rows {section}                     -> the data rows of one section
#   ::pis::dlog::kind_table {kind}                  -> the per-file table (words, fields, header)

namespace eval ::pis::dlog {
}

# The per-file table: the section WORD, the file's own NAME (the one every message starts with),
# the skipped header's second column, the five field names and which of them are numbers.
# `spec` is Result.log (T-037), `note` is Notes.log (T-038).
proc ::pis::dlog::kind_table {kind} {
    switch -- [string tolower [string trim $kind]] {
        spec {
            return [dict create word Spec tail Result.log header Node_ID \
                fields {Group Node_ID SF MS AS} numeric {0 0 1 1 1} integer {0 1 0 0 0}]
        }
        note {
            return [dict create word Note tail Notes.log header Text \
                fields {Name Text X Y Z} numeric {0 0 1 1 1} integer {0 0 0 0 0}]
        }
    }
    error "::pis::dlog: unknown kind '$kind' (expected spec for Result.log or note for Notes.log)"
}

# Offline this file is useless without ::pis::common: say so instead of a confusing error.
proc ::pis::dlog::need_common {} {
    foreach p {get} {
        if {[llength [info commands ::pis::common::$p]] == 0} {
            error "::pis::dlog: source _tcl_pis_00_common.tcl first (missing ::pis::common::$p)"
        }
    }
    return
}

# Read the WHOLE file and parse it completely. Nothing is sent and nothing is journaled, so one
# bad line 40 means no HyperView call at all - the rule of docs/SPEC_gui.txt s.15.1.
# Returned dict: {file <name> kind <kind> sections <section...>}, where one section is
#   {name Note1 num 1 line 3 rows {<row> ...}}
# and one row of Notes.log is {line 4 name a text b x 1 y 2 z 3} (Result.log: group node sf ms as).
proc ::pis::dlog::parse {path kind} {
    set t [::pis::dlog::kind_table $kind]
    set tail [dict get $t tail]
    set p [string trim $path]
    if {$p eq ""} { error "$tail not found: $p" }
    # A missing AND an unreadable file share one sentence on purpose (s.15.1): the owner's fix is
    # the same for both (put the file where the ini says), and `file isfile` cannot tell them apart.
    if {![file isfile $p]} { error "$tail not found: $p" }
    if {[catch {open $p r} fh]} { error "$tail not found: $p" }
    fconfigure $fh -encoding utf-8 -translation auto
    set text ""
    if {[catch {read $fh} text]} {
        catch {close $fh}
        error "$tail is not readable as UTF-8: [string trim $text]"
    }
    close $fh
    return [::pis::dlog::parse_text $text $kind $tail]
}

# The pure half: the same grammar over a string, so tests/tcl/test_datalog.tcl needs no file.
proc ::pis::dlog::parse_text {text kind {tail ""}} {
    set t [::pis::dlog::kind_table $kind]
    if {$tail eq ""} { set tail [dict get $t tail] }
    set word [dict get $t word]
    set header [dict get $t header]
    set names [dict get $t fields]
    set numeric [dict get $t numeric]
    set integ [dict get $t integer]
    # CRLF and LF are both accepted (Q2); a UTF-8 BOM is not part of the contract but is dropped,
    # so a Windows editor's mark cannot turn line 1 into a section nobody recognises.
    set body [string map {"\r\n" "\n" "\r" "\n"} $text]
    if {[string index $body 0] eq "\ufeff"} { set body [string range $body 1 end] }
    set sections [list]
    set opened [dict create]
    set cur -1
    set n 0
    foreach raw [split $body "\n"] {
        incr n
        set line [string trim $raw]
        if {$line eq ""} { continue }
        if {[string index $line 0] eq "#"} {
            set name [string trim [string range $line 1 end]]
            set re "^${word}(\[0-9\]+)\$"
            set num ""
            if {![regexp -nocase -- $re $name all num]} {
                error "$tail line $n: section '$name' is not #${word}<N>"
            }
            set key [string tolower $name]
            if {[dict exists $opened $key]} {
                error "$tail line $n: section '$name' already opened at line [dict get $opened $key]"
            }
            dict set opened $key $n
            lappend sections [dict create name $name num [scan $num %d] line $n rows [list]]
            set cur [expr {[llength $sections] - 1}]
            continue
        }
        set fields [split $line ,]
        if {[llength $fields] != 5} {
            error "$tail line $n: expected 5 fields, found [llength $fields]"
        }
        set f [list]
        foreach v $fields { lappend f [string trim $v] }
        # The column line of a hand-made file: its SECOND field is the column name (s.15.1).
        if {[string equal -nocase [lindex $f 1] $header]} { continue }
        if {$cur < 0} {
            error "$tail line $n: row outside a #${word} section"
        }
        set row [dict create line $n]
        set k 0
        foreach v $f {
            set fn [lindex $names $k]
            if {$v eq ""} { error "$tail line $n: $fn is empty" }
            if {[lindex $integ $k] && (![string is integer -strict $v] || $v < 1)} {
                error "$tail line $n: $fn '$v' is not a positive integer"
            }
            if {[lindex $numeric $k] && ![string is double -strict $v]} {
                error "$tail line $n: $fn '$v' is not a number"
            }
            dict set row [string tolower $fn] $v
            incr k
        }
        # NOTE: `dict lappend` takes a VARIABLE name, never a value, so the section is read out,
        # extended and written back (a row dict holds spaces and must stay ONE list element).
        set sec [lindex $sections $cur]
        set rl [dict get $sec rows]
        lappend rl $row
        dict set sec rows $rl
        lset sections $cur $sec
    }
    if {[llength $sections] == 0} {
        error "$tail: no #${word} section"
    }
    return [dict create file $tail kind [string tolower [string trim $kind]] \
        sections $sections]
}

# The data rows of one section ({row row ...}); a header-only section answers {}.
proc ::pis::dlog::rows {section} {
    if {[dict exists $section rows]} { return [dict get $section rows] }
    return [list]
}

# The windows a section names (Q3 DEFAULT): every window whose configured result file NAME holds
# the token SPEC<n> (`..._SPEC1_1.res` and `..._SPEC1_2.res` are the two windows of Spec1); with no
# such file, window <n> when the layout has it; otherwise the ERROR of docs/SPEC.md A20.
# `count` is the layout's window count and `id` its id - used for the message, never guessed.
proc ::pis::dlog::windows {cfg path section count id} {
    ::pis::dlog::need_common
    set tail [file tail [string trim $path]]
    set name [dict get $section name]
    set n [dict get $section num]
    set out [list]
    set files [list]
    catch {set files [::pis::common::get $cfg session result_files ""]}
    set i 0
    foreach f $files {
        incr i
        # The token ends at a non-digit, so `SPEC10_1.res` is never window 1 of Spec1.
        if {[regexp -nocase "SPEC${n}(\[^0-9\]|\$)" [file tail [string trim $f]]]} {
            lappend out $i
        }
    }
    if {[llength $out] == 0} {
        if {[string is integer -strict $n] && $n >= 1 && $n <= $count} {
            return [list $n]
        }
        error [format "%s: section '%s' matches no window (no result file name holds 'SPEC%d', layout %s has %d window(s))" \
            $tail $name $n $id $count]
    }
    return $out
}
