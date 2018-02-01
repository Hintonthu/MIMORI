set_host_options -max_cores 8
analyze -format sverilog -define SRAM_GEN_MODE=SYNOPSYS32 ../include/Top_include.sv >  ./rpt/00_analelab.txt
elaborate Top                                                                       >> ./rpt/00_analelab.txt
uniquify                                                                            >  ./rpt/05_uniqlink.txt
link                                                                                >> ./rpt/05_uniqlink.txt
check_design                                                                        >  ./rpt/10_check.txt
read_sdc ./timing.sdc
