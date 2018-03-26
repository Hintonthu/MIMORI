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
`rdyack_logic(s1);
logic last_stencil;
logic acc_cond;
logic [ST_BW-1:0] sid1;
logic [ST_BW-1:0] sid_r;
logic [ST_BW-1:0] sid_w;
logic [ABW-1:0]   linear_r;
logic [ABW-1:0]   linear_w;
logic islast_r;
logic retire_r;

//======================================
// Combinational
//======================================
assign sid1 = sid_r + 'b1;
assign last_stencil = sid1 == i_stencil_ends[o_id];
assign acc_cond = !i_stencil || last_stencil;
assign o_linear = linear_r + (i_stencil ? i_stencil_lut[sid_r] : '0);
assign o_islast = islast_r && acc_cond;
assign o_retire = retire_r && acc_cond;
always_comb begin
	casez ({src_ack,dst_ack})
		2'b1?: sid_w = i_stencil_begs[i_id];
		2'b01: sid_w = sid1;
		2'b00: sid_w = sid_r;
	endcase
end

//======================================
// Submodule
//======================================
Forward u_fwd(
	`clk_connect,
	`rdyack_connect(src, src),
	`rdyack_connect(dst, s1)
);
AcceptIf u_acc(
	.cond(acc_cond),
	`rdyack_connect(src, s1),
	`rdyack_connect(dst, dst)
);

//======================================
// Sequential
//======================================
`ff_rst
	sid_r <= '0;
`ff_cg((src_ack || dst_ack) && i_stencil)
	sid_r <= sid_w;
`ff_end

`ff_rst
	o_id <= '0;
	for (int i = 0; i < VDIM; i++) begin
		o_bofs[i] <= '0;
	end
	islast_r <= 1'b0;
	retire_r <= 1'b0;
	linear_r <= '0;
`ff_cg(src_ack)
	o_id <= i_id;
	for (int i = 0; i < VDIM; i++) begin
		o_bofs[i] <= i_bofs[i];
	end
	islast_r <= i_islast;
	retire_r <= i_retire;
	linear_r <= i_linear;
`ff_end

endmodule
