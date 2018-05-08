`ifndef __DEFINE__
`define __DEFINE__

`define rdyack_input(name) output logic name``_ack; input name``_rdy
`define rdyack_output(name) output logic name``_rdy; input name``_ack
`define rdyack_logic(name) logic name``_rdy, name``_ack
`define rdyack_port(name) name``_rdy, name``_ack
`define rdyack_connect(port_name, logic_name) .port_name``_rdy(logic_name``_rdy), .port_name``_ack(logic_name``_ack)
`define rdyack_unconnect(port_name) .port_name``_rdy(), .port_name``_ack()
`define dval_input(name) input name``_dval
`define dval_output(name) output logic name``_dval
`define dval_logic(name) logic name``_dval
`define dval_port(name) name``_dval
`define dval_connect(port_name, logic_name) .port_name``_dval(logic_name``_dval)
`define dval_unconnect(port_name) .port_name``_dval()
`define clk_port i_clk, i_rst
`define clk_connect .i_clk(i_clk), .i_rst(i_rst)
`define clk_input input i_clk; input i_rst
`define ff_rst always_ff @(posedge i_clk or negedge i_rst) if (!i_rst) begin
`define ff_cg(cg) end else if (cg) begin
`define ff_nocg end else begin
`define ff_end end

`endif
