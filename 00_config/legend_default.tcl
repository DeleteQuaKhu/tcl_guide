#============================================================================
# legend_default.tcl
#
# PLACEHOLDER FILE - THIS FILE CONTAINS NO LEGEND DEFINITION.
#
# Purpose
#   pis_workflow_config.ini points its legend_file key at this path so the
#   workflow can be started before the real legend exists. Keep this file as a
#   clearly failing placeholder: it raises an explicit error instead of doing
#   nothing, so a missing real legend is never silently ignored.
#
# What to do
#   1. In HyperView, build / load the Contact Pressure contour legend you want,
#      then export it (Results > Legend > ... > Save, or File > Export) to a
#      Tcl file inside 00_config (for example 00_config/legend_contact_pressure.tcl).
#   2. Either overwrite this file with that exported content, or point the
#      legend_file key of 00_config/pis_workflow_config.ini at the exported
#      file, or select the exported file with the Browse Legend button in the
#      workflow GUI (that only changes the running session, never the .ini).
#   3. Re-run "Load Legend".
#
# This placeholder is intentionally inert: sourcing it or feeding it to the
# HyperView legend import must fail with the message below.
#============================================================================

return -code error "Placeholder legend file used: 00_config/legend_default.tcl contains no Contact Pressure legend definition. Replace it with a real legend Tcl file exported from HyperView, or point the legend_file key of 00_config/pis_workflow_config.ini at the real file."
