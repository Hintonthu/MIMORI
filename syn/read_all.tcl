set_host_options -max_cores 8
analyze -format sverilog -define SRAM_GEN_MODE=SYNOPSYS32 ../include/Top_include.sv
elaborate Top
set_max_area 0
