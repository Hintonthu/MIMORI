report_timing -net -max_path 10
report_area -hier
write_sdf Top_syn.sdf
write_sdc Top_syn.sdc
write -format ddc -o ./Top_syn.ddc -hier
write -format verilog -o ./Top_syn.v -hier
