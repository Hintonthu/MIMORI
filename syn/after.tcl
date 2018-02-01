report_timing -max_path 10 > ./rpt/20_timing.txt
report_area                > ./rpt/25_area.txt
write_file -o Top.ddc
write_sdf Top.sdf
write_sdc Top.sdc
write -format ddc -o ./Top.ddc -hier
write -format verilog -o ./Top_syn.v -hier
