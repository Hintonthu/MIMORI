// Copyright 2016 Yu Sheng Lin

// This file is part of Ocean.

// MIMORI is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// MIMORI is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with Ocean.  If not, see <http://www.gnu.org/licenses/>.

import TauCfg::*;

module Allocator(
	`clk_port,
	i_sizes,
	`rdyack_port(alloc),
	i_alloc_id,
	`rdyack_port(linear),
	o_linear,
	o_linear_id,
	`dval_port(free),
	i_free_id,
	`dval_port(blkdone)
);

//======================================
// Parameter
//======================================
parameter LBW = TauCfg::LOCAL_ADDR_BW0;
localparam N_ICFG = TauCfg::N_ICFG;
// derived
localparam ICFG_BW = $clog2(N_ICFG+1);
localparam [LBW:0] CAPACITY = 1<<LBW;

//======================================
// I/O
//======================================
`clk_input;
input [LBW:0] i_sizes [N_ICFG];
`rdyack_input(alloc);
input [ICFG_BW-1:0] i_alloc_id;
`rdyack_output(linear);
output logic [LBW-1:0]     o_linear;
output logic [ICFG_BW-1:0] o_linear_id;
`dval_input(free);
input [ICFG_BW-1:0] i_free_id;
`dval_input(blkdone);

//======================================
// Internal
//======================================
logic               linear_rdy_w;
logic [LBW-1:0]     linear_w;
logic [ICFG_BW-1:0] linear_id_w;
logic [LBW-1:0]     cur_r;
logic [LBW-1:0]     cur_w;
logic [LBW:0] capacity_r;
logic [LBW:0] capacity_w;
logic [LBW:0] asize;
logic [LBW:0] fsize;

//======================================
// Combinational
//======================================
assign asize = i_sizes[i_alloc_id];
assign fsize = i_sizes[i_free_id];
always_comb begin
	linear_rdy_w = linear_rdy;
	cur_w = cur_r;
	alloc_ack = 1'b0;
	if (linear_rdy) begin
		linear_rdy_w = ~linear_ack;
	end else if (alloc_rdy && capacity_r >= asize) begin
		linear_rdy_w = 1'b1;
		alloc_ack = 1'b1;
		cur_w = cur_r + asize[LBW-1:0];
	end
	cur_w = blkdone_dval ? '0 : cur_w;
end

always_comb begin
	case({alloc_ack,free_dval})
		2'b00: capacity_w = capacity_r;
		2'b01: capacity_w = capacity_r         + fsize;
		2'b10: capacity_w = capacity_r - asize;
		2'b11: capacity_w = capacity_r - asize + fsize;
	endcase
end

//======================================
// Sequential
//======================================
`ff_rst
	linear_rdy <= 1'b0;
`ff_nocg
	linear_rdy <= linear_rdy_w;
`ff_end

`ff_rst
	capacity_r <= CAPACITY;
`ff_cg(alloc_ack||free_dval||blkdone_dval)
	capacity_r <= capacity_w;
`ff_end

`ff_rst
	cur_r <= '0;
	o_linear <= '0;
	o_linear_id <= '0;
`ff_cg(alloc_ack)
	cur_r <= cur_w;
	o_linear <= cur_r;
	o_linear_id <= i_alloc_id;
`ff_end

endmodule
