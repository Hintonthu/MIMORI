# Initialize
set_host_options -max_cores 8
analyze -format sverilog -define SRAM_GEN_MODE=SYNOPSYS32,SC ../include/Top_include.sv
elaborate Top
link
# Important for making make DC output a reasonable timing
set high_fanout_net_threshold 20
set high_fanout_net_pin_capacitance 1

# Ungroup
## ungroup the inner of the cells (no-parameter and parametered cells)
foreach_in_collection d [get_designs { \
	ParallelBlockLooper \
	DramArbiter DramWriteCollectorAddrDecode DramWriteCollectorOutput \
	SimdOperand Alu SimdTmpBuffer SimdDriver \
	AccumWarpLooper AccumWarpLooper_* \
	ChunkAddrLooper ChunkAddrLooper_* \
	ChunkHead ChunkHead_* \
	LinearCollector LinearCollector_* \
	Allocator Allocator_* \
	RemapCache RemapCache_*
}] {
	current_design $d
	ungroup -all -flatten
}
## return to the top level
current_design Top
## ungroup the cells itself
set ungroup_cells {}
foreach_in_collection d [get_designs { \
	OffsetStage OffsetStage_* \
	Semaphore Semaphore_* \
	ForwardIf ForwardIf_* \
	AcceptIf AcceptIf_* \
	IgnoreIf IgnoreIf_* \
	Reverse Reverse_* \
	FindFromLsb FindFromLsb_* \
	FindFromMsb FindFromMsb_* \
	SFifoCtrl SFifoCtrl_* \
	BroadcastInorder BroadcastInorder_* \
	Broadcast Broadcast_* \
	ForwardMulti ForwardMulti_* \
	SRAMTwoPort SRAMTwoPort_* \
	IdSelect IdSelect_* \
	OneCycleInit Forward ForwardSlow
}] {
	set dname [get_object_name $d]
	echo $dname
	foreach_in_collection c [get_cells -hier -filter ref_name==$dname] {
		lappend ungroup_cells [get_object_name $c]
	}
}
uniquify
ungroup -flatten $ungroup_cells

# Timing
set CLK_PERIOD 2.7
set TRANSIT 0.1
set CLK_PIN [get_ports i_clk]
set RESET_PIN [get_ports i_rst]
create_clock -name clk -period $CLK_PERIOD \
  -waveform [list 0 [expr $CLK_PERIOD*0.5]] $CLK_PIN
set_clock_uncertainty $TRANSIT [get_clocks clk]
set_clock_latency $TRANSIT [get_clocks clk]
set_clock_transition $TRANSIT [get_clocks clk]
## Clock/signal trees should be done at APR.
## Remember to remove these lines at the output SDC.
set_fix_hold [get_clocks clk]
set_ideal_network [all_inputs]
## It would be more meaningful to add it at APR, but also OK here.
set_input_delay $TRANSIT -clock clk [all_inputs]
set_output_delay $TRANSIT -clock clk [all_outputs]
set_max_area 0

# TODO: Try to make a looser condition if DC spends much time on fixing DRC
set_max_transition 0.3 [current_design]
set_max_fanout 100 [current_design]
# Separate timing path groups.
set ports_clock_root [filter_collection [get_attribute [get_clocks] sources] object_class==port]
group_path -name REGOUT -to [all_outputs]
group_path -name REGIN -from [remove_from_collection [all_inputs] ${ports_clock_root}]
group_path -name FEEDTHROUGH -from [remove_from_collection [all_inputs] ${ports_clock_root}] -to [all_outputs]
# I am not sure what's these lines, but it is a common settings.
set_fix_multiple_port_nets -all -buffer_constants
# It seems that this is done automitically in newer DC,
# but I add this for safety.
propagate_constraints
check_design

# Can we enable boundary_optimization and seq_output_inversion
compile_ultra -no_autoungroup -no_boundary_optimization -no_seq_output_inversion -gate_clock

report_timing -net -max_path 10 -nosplit
report_area -hier -nosplit
write_sdf Top_syn.sdf
write_sdc Top_syn.sdc
write -format ddc -o ./Top_syn.ddc -hier
write -format verilog -o ./Top_syn.v -hier
