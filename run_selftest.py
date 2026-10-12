#!/usr/bin/env python3
"""Run selftest_hv_model_loader.tcl with the Tcl that ships inside Python.

The host has no tclsh/wish, but Python embeds Tcl/Tk 8.6, so the source-only
selftest runs here unchanged.  Two properties of the embedded interpreter are
handled here and nowhere else:
  * it has no 'exit' command, while the test ends with 'exit 0' / 'exit 1': a
    shim records the code and raises -errorcode {SELFTEST EXIT} instead of
    killing the process;
  * '[info script]' inside the test has to be its real path (the test finds the
    wizard next to itself), so the runner chdirs into the test folder and
    sources the file by name.

Exit code: 0 = every check passed, 1 = the selftest reported failures,
           2 = the test itself died with a Tcl error.
"""
import os
import sys

from tkinter import Tcl


def run(script, interp):
    path = script if os.path.isabs(script) else os.path.join(
        os.path.dirname(os.path.abspath(__file__)), script)
    if not os.path.isfile(path):
        print("no such test file: %s" % path)
        return 2
    interp.eval("proc exit {code} { set ::selftestExitCode $code ;"
                " return -code error -errorcode {SELFTEST EXIT} [list $code] }")
    os.chdir(os.path.dirname(path))
    rc = interp.eval("""
        set ::selftestExitCode 0
        set rc 0
        if {[catch {source {%s}} ::selftestMsg opts]} {
            if {[lindex [dict get $opts -errorcode] 0] eq "SELFTEST"} {
                set rc $::selftestExitCode
            } else {
                set rc 2
            }
        }
        set rc
    """ % os.path.basename(path))
    rc = int(rc)
    if rc == 2:
        print("the test died: %s" % interp.getvar("selftestMsg"))
    print("exit code: %d" % rc)
    return rc


def main(argv):
    return run(argv[1] if len(argv) > 1 else "selftest_hv_model_loader.tcl",
               Tcl())


if __name__ == "__main__":
    sys.exit(main(sys.argv))
