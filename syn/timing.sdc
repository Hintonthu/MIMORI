# Clock settings
set CLK_PERIOD 10
set CLK_PIN [get_ports i_clk]
set RESET_PIN [get_ports i_rst]
create_clock -name clk -period $CLK_PERIOD \
  -waveform [list 0 [expr $CLK_PERIOD*0.5]] $CLK_PIN
# Clock/signal trees should be done at APR.
# Remember to remove these lines at the output SDC.
set_dont_touch_network [all_inputs]
set_ideal_network [all_inputs]
# It seems that this is done automitically in newer DC,
# but I add this for safety.
propagate_constraints
# It would be more meaningful to add it at APR, but also OK here.
set_input_delay [expr $CLK_PERIOD*0.1] -clock clk [all_inputs]
set_output_delay [expr $CLK_PERIOD*0.1] -clock clk [all_outputs]
set_load 0.05 [all_outputs]
# Similarly, this should be calculated at APR, default = 1000.
# However, 1000 causes a crazy delay, we must use a smaller one to help timing closure.
set_max_area 0
set_max_transition 30 [current_design]
set_max_fanout [expr $CLK_PERIOD*0.3] [current_design]
set high_fanout_net_threshold 60
