source ./before.tcl
set_max_area 0
# compile > ./rpt/15_compile_ultra.txt
# compile_ultra -no_autoungroup > ./rpt/15_compile_ultra.txt
compile_ultra > ./rpt/15_compile_ultra.txt
# compile_ultra -gate_clock > ./rpt/15_compile_ultra.txt
source ./after.tcl
