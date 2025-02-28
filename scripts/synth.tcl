set ROOT "/directory/to/your/working/directory"

set SYNT_SCRIPT "$ROOT/scripts"
set SYNT_OUT "$ROOT/output"
set SYNT_REPORT "$ROOT/reports"


puts "\n\n\n DESIGN FILES \n\n\n"
source $SYNT_SCRIPT/design_setup.tcl

puts "\n\n\n ANALYZE HDL DESIGN \n\n\n"
read_hdl -vhdl ${Design_Files}

puts "\n\n\n ELABORATE \n\n\n"
elaborate ${DESIGN}

check_design
report timing -lint

puts "\n\n\n TIMING CONSTRAINTS \n\n\n"
source $SYNT_SCRIPT/create_clock.tcl

puts "\n\n\n SYN GENERIC \n\n\n"
syn_generic

puts "\n\n\n SYN MAP \n\n\n"
syn_map

puts "\n\n\n SYN OPT \n\n\n"
syn_opt

report_summary -outdir $SYNT_REPORT

puts "\n\n\n EXPORT DESIGN \n\n\n"
write_hdl   > ${SYNT_OUT}/${DESIGN}.v
write_sdc   > ${SYNT_OUT}/${DESIGN}.sdc
write_sdf   -version 2.1 > ${SYNT_OUT}/${DESIGN}.sdf

puts "\n\n\n REPORTING \n\n\n"
report qor          > $SYNT_REPORT/qor_${DESIGN}.rpt
report area         > $SYNT_REPORT/area_${DESIGN}.rpt
report datapath     > $SYNT_REPORT/datapath_${DESIGN}.rpt
report messages     > $SYNT_REPORT/messages_${DESIGN}.rpt
report gates        > $SYNT_REPORT/gates_${DESIGN}.rpt
report timing       > $SYNT_REPORT/timing_${DESIGN}.rpt