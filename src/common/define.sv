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

package TauCfg;
	parameter VSIZE = 32;
	parameter N_ICFG = 3;
	parameter N_OCFG = 3;
	parameter N_INST = 15;
	parameter ISA_BW = 30;         // instruction
	parameter WORK_BW = 16;        // for parallelism/accumumation idx
	parameter DATA_BW = 16;        // data
	parameter STRIDE_BW = 8;       // stride (f)
	parameter STRIDE_FRAC_BW = 3;  // stride (s) ==> actual stride = f<<s
	parameter TMP_DATA_BW = 20;    // tmp data
	parameter GLOBAL_ADDR_BW = 32; // global address (DRAM)
	parameter LOCAL_ADDR_BW0 = 11; // local address (SRAM)
	parameter LOCAL_ADDR_BW1 = 10; // local address (SRAM)
	parameter VDIM = 6; // #DIM of parallelism/accumumation idx
	parameter DIM = 4;  // #DIM of actual tensor
	parameter CACHE_SIZE = 8;
	parameter SRAM_NWORD = 64;
	parameter WARP_REG_ADDR_SPACE = 8;
	parameter MAX_WARP = 64;
	parameter CONST_LUT = 4; // Do not modify it owing to the limitataion of ISA
	parameter CONST_TEX_LUT = 4;
	parameter ALU_DELAY_BUF_SIZE = 2;
	parameter ARB_FIFO_SIZE = 63;
	parameter STENCIL_SIZE = 31;
	parameter MAX_PENDING_BLOCK = 1023;
	parameter MAX_PENDING_INST = 7;
	// This only works for multiple TAU version
	parameter N_TAU = 4;
	// This only works for systolic version
	parameter N_TAU_Y = 4;
	parameter N_TAU_X = 4;
	// derived
	localparam XOR_BW = 8; // this is a magic number for N=32
	localparam ICFG_BW = $clog2(N_ICFG+1);
	localparam OCFG_BW = $clog2(N_OCFG+1);
	localparam INST_BW = $clog2(N_INST+1);
	localparam DIM_BW = $clog2(DIM);
	localparam CV_BW = $clog2(VSIZE);
	localparam CCV_BW = $clog2(CV_BW+1);
	localparam CX_BW = $clog2(XOR_BW);
	localparam REG_ABW = $clog2(WARP_REG_ADDR_SPACE);
	localparam ST_BW = $clog2(STENCIL_SIZE+1);
	localparam BLOCK_PBW = $clog2(MAX_PENDING_BLOCK+1);
	localparam INST_PBW = $clog2(MAX_PENDING_INST+1);
endpackage
`endif
