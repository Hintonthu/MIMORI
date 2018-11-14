// Copyright 2016,2018 Yu Sheng Lin

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

`include "common/define.sv"
`include "common/Controllers.sv"

// With the dual warp scheduling, the all input are repeated twice
// except the i_linear.
// We use this property to design this module.
module AccumWarpLooperStencilStage(
	`clk_port,
	`rdyack_port(src),
	i_id,
	i_linear,
	i_bofs,
	i_retire,
	i_islast,
	i_stencil,
	i_stencil_begs,
	i_stencil_ends,
	i_stencil_lut,
	`rdyack_port(dst),
	o_id,
	o_linear,
	o_bofs,
	o_retire,
	o_islast
);

//======================================
// Parameter
//======================================
parameter N_CFG = TauCfg::N_ICFG;
parameter ABW = TauCfg::GLOBAL_ADDR_BW;
localparam WBW = TauCfg::WORK_BW;
localparam VDIM = TauCfg::VDIM;
localparam STSIZE = TauCfg::STENCIL_SIZE;
// derived
localparam NCFG_BW = $clog2(N_CFG+1);
localparam ST_BW = $clog2(STSIZE+1);

//======================================
// I/O
//======================================
`clk_input;
`rdyack_input(src);
input [NCFG_BW-1:0] i_id;
input [ABW-1:0]     i_linear;
input [WBW-1:0]     i_bofs [VDIM];
input               i_retire;
input               i_islast;
input               i_stencil;
input [ST_BW-1:0]   i_stencil_begs [N_CFG];
input [ST_BW-1:0]   i_stencil_ends [N_CFG];
input [ABW-1:0]     i_stencil_lut [STSIZE];
`rdyack_output(dst);
output logic [NCFG_BW-1:0] o_id;
output logic [ABW-1:0]     o_linear;
output logic [WBW-1:0]     o_bofs [VDIM];
output logic               o_retire;
output logic               o_islast;

//======================================
// Internal
//======================================
logic single_rdy_r, single_rdy_w;
`rdyack_logic(src_2x);
`rdyack_logic(s1);
logic last_stencil;
logic done_cond;
logic warp_hi;
logic [ST_BW-1:0] sid1;
logic [ST_BW-1:0] sid_r;
logic [ST_BW-1:0] sid_w;
logic [ABW-1:0] linears_r [2];
logic [ABW-1:0] single_linear_r;
logic islast_r;
logic retire_r;

//======================================
// Combinational
//======================================
always_comb begin
	src_2x_rdy = single_rdy_r && src_rdy;
	src_ack = src_2x_ack || (src_rdy && !single_rdy_r);
end

always_comb begin
	sid1 = sid_r + 'b1;
	last_stencil = sid1 == i_stencil_ends[o_id];
	done_cond = (!i_stencil || last_stencil) && warp_hi;
	o_linear = linears_r[warp_hi] + (i_stencil ? i_stencil_lut[sid_r] : '0);
	o_islast = islast_r && done_cond;
	o_retire = retire_r && done_cond;
end

always_comb begin
	// The hold conditions are not listed (see the register clock gate part)
	if (src_2x_ack) begin
		sid_w = i_stencil_begs[i_id];
	// end else if (dst_ack) begin
	end else begin
		sid_w = sid1;
	end
end

//======================================
// Submodule
//======================================
Forward u_fwd(
	`clk_connect,
	`rdyack_connect(src, src_2x),
	`rdyack_connect(dst, s1)
);
RepeatIf#(0) u_acc(
	.cond(done_cond),
	`rdyack_connect(src, s1),
	`rdyack_connect(dst, dst),
	.repeated()
);

//======================================
// Sequential
//======================================
`ff_rst
	single_rdy_r <= 1'b0;
`ff_nocg
	single_rdy_r <= single_rdy_r ? !src_2x_ack : src_rdy;
`ff_end

// Buffer single data
`ff_rst
	single_linear_r <= '0;
`ff_cg(!single_rdy_r && src_rdy)
	single_linear_r <= i_linear;
`ff_end

// Warp counter
`ff_rst
	warp_hi <= 1'b0;
`ff_cg(dst_ack)
	warp_hi <= !warp_hi;
`ff_end

// Stencil index counter
`ff_rst
	sid_r <= '0;
`ff_cg((src_2x_ack || dst_ack && warp_hi) && i_stencil)
	sid_r <= sid_w;
`ff_end

// Buffer single data + input
`ff_rst
	o_id <= '0;
	for (int i = 0; i < VDIM; i++) begin
		o_bofs[i] <= '0;
	end
	islast_r <= 1'b0;
	retire_r <= 1'b0;
	linears_r[0] <= '0;
	linears_r[1] <= '0;
`ff_cg(src_2x_ack)
	o_id <= i_id;
	for (int i = 0; i < VDIM; i++) begin
		o_bofs[i] <= i_bofs[i];
	end
	islast_r <= i_islast;
	retire_r <= i_retire;
	linears_r[0] <= single_linear_r;
	linears_r[1] <= i_linear;
`ff_end

endmodule
