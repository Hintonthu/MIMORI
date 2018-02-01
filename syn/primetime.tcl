set search_path "SAED32_EDK/lib/stdcell_rvt/db_ccs SAED32_EDK/lib/sram/db_ccs/ ../src"
set link_library "* saed32rvt_ff1p16v25c.db saed32sram_ff1p16v25c.db"
set target_library "saed32rvt_ff1p16v25c.db saed32sram_ff1p16v25c.db"
set link_path "* $target_library"
read_verilog ./Top_syn.v
current_design Top
link
set power_enable_analysis "true"
set power_analysis_mode "averaged"
read_saif ../sim/Top_syn.330.fsdb.saif -strip_path "Top_test/u_top/u_top"
report_switching_activity -list_not_annotated > ./rpt/30_power.txt
report_power -verbose -hierarchy >> ./rpt/30_power.txt
