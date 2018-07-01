# Clock settings
set CLK_PERIOD 2.8
set TRANSIT 0.5
set CLK_PIN [get_ports i_clk]
set RESET_PIN [get_ports i_rst]
create_clock -name clk -period $CLK_PERIOD \
  -waveform [list 0 [expr $CLK_PERIOD*0.5]] $CLK_PIN
set_clock_uncertainty $TRANSIT [get_clocks clk]
set_clock_latency $TRANSIT [get_clocks clk]
set_clock_transition $TRANSIT [get_clocks clk]
# Clock/signal trees should be done at APR.
# Remember to remove these lines at the output SDC.
set_dont_touch_network [all_inputs]
set_fix_hold [get_clocks clk]
set_ideal_network [all_inputs]
# It seems that this is done automitically in newer DC,
# but I add this for safety.
propagate_constraints
# It would be more meaningful to add it at APR, but also OK here.
set_input_delay $TRANSIT -clock clk [all_inputs]
set_output_delay $TRANSIT -clock clk [all_outputs]
set_max_area 0
set_max_transition $TRANSIT [current_design]
set_max_fanout 8 [current_design]
# The most important to make DC output a reasonable timing
set high_fanout_net_threshold 20
set high_fanout_net_pin_capacitance 1
