set CLK_PERIOD 3.0
set CLK_PIN [get_ports i_clk]
set RESET_PIN [get_ports i_rst]
create_clock -name clk -period $CLK_PERIOD \
  -waveform [list 0 [expr $CLK_PERIOD*0.5]] $CLK_PIN
set_ideal_network $RESET_PIN
set_input_delay [expr $CLK_PERIOD*0.1] -clock clk [all_inputs]
set_output_delay [expr $CLK_PERIOD*0.1] -clock clk [all_outputs]
set_load 0.05 [all_outputs]
