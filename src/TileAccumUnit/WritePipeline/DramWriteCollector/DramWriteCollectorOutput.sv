// Copyright 2016 Yu Sheng Lin

// This file is part of MIMORI.

// MIMORI is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// MIMORI is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with MIMORI.  If not, see <http://www.gnu.org/licenses/>.

import TauCfg::*;

module DramWriteCollectorOutput(
	`clk_port,
	`rdyack_port(dec),
	i_addr,
	i_dec,
	i_islast,
	`rdyack_port(alu_dat),
	i_alu_dat,
	`rdyack_port(dramw),
	o_dramwa,
	o_dramwd,
	o_dramw_mask
);

//======================================
// Parameter
//======================================
localparam GBW = TauCfg::GLOBAL_ADDR_BW;
localparam DBW = TauCfg::DATA_BW;
localparam VSIZE = TauCfg::VECTOR_SIZE;
localparam CSIZE = TauCfg::CACHE_SIZE;

//======================================
// I/O
//======================================
`clk_input;
`rdyack_input(dec);
input [GBW-1:0]   i_addr;
input [VSIZE-1:0] i_dec [CSIZE];
input             i_islast;
`rdyack_input(alu_dat);
input [DBW-1:0] i_alu_dat [VSIZE];
`rdyack_output(dramw);
output logic [GBW-1:0]   o_dramwa;
output logic [DBW-1:0]   o_dramwd [CSIZE];
output logic [CSIZE-1:0] o_dramw_mask;

//======================================
// Internal
//======================================
`rdyack_logic(src);
`rdyack_logic(dst);
logic has_data;
logic both_rdy;
logic [DBW-1:0]   dramwd_w [CSIZE];
logic [CSIZE-1:0] dramw_mask_w;

//======================================
// Submodule
//======================================
Forward u_fwd(
	`clk_connect,
	`rdyack_connect(src, src),
	`rdyack_connect(dst, dst)
);
OrCrossBar#(DBW, VSIZE, CSIZE) u_oxbar(
	.i_data(i_alu_dat),
	.i_routing(i_dec),
	.o_data(dramwd_w),
	.o_mask(dramw_mask_w)
);
IgnoreIf#(0) u_ign_if_no_data(
	.cond(has_data),
	`rdyack_connect(src, dst),
	`rdyack_connect(dst, dramw)
);

//======================================
// Combinational
//======================================
assign both_rdy = dec_rdy && alu_dat_rdy;
assign src_rdy = both_rdy;
assign dec_ack = src_ack;
assign alu_dat_ack = src_ack && i_islast;
assign has_data = |o_dramw_mask;

//======================================
// Sequential
//======================================
`ff_rst
	o_dramwa <= '0;
	for (int i = 0; i < CSIZE; i++) begin
		o_dramwd[i] <= '0;
	end
	o_dramw_mask <= '0;
`ff_cg(src_ack)
	o_dramwa <= i_addr;
	o_dramwd <= dramwd_w;
	o_dramw_mask <= dramw_mask_w;
`ff_end

endmodule
