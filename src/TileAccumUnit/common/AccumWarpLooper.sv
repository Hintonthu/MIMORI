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
import Default::*;

module AccumWarpLooper(
	`clk_port,
	`rdyack_port(abofs),
	i_bofs,
	i_aofs,
	i_alast,
	i_bboundary,
	i_blocal_last,
	i_bsubofs,
	i_bsub_up_order,
	i_bsub_lo_order,
	i_aboundary,
	i_mofs_bsteps,
	i_mofs_bsubsteps,
	i_mofs_asteps,
	i_id_begs,
	i_id_ends,
	// only for i_stencil == 1 & STENCIL is enabled
	i_stencil,
	i_stencil_begs,
	i_stencil_ends,
	i_stencil_lut,
	`rdyack_port(mofs),
	i_mofs,
	i_id,
	`rdyack_port(addrval),
	o_id,
	o_address,
	o_valid,
	o_retire
);

//======================================
// Parameter
//======================================
parameter N_CFG = Default::N_CFG;
parameter ABW = Default::ABW;
parameter STENCIL = 0;
localparam WBW = TauCfg::WORK_BW;
localparam DIM = TauCfg::DIM;
localparam VSIZE = TauCfg::VECTOR_SIZE;
localparam STSIZE = TauCfg::STENCIL_SIZE;
// derived
localparam NCFG_BW = $clog2(N_CFG+1);
localparam CV_BW = $clog2(VSIZE);
localparam CCV_BW = $clog2(CV_BW+1);
localparam ST_BW = $clog2(STSIZE+1);

//======================================
// I/O
//======================================
`clk_input;
`rdyack_input(abofs);
input [WBW-1:0]     i_bofs  [DIM];
input [WBW-1:0]     i_aofs  [DIM];
input [WBW-1:0]     i_alast [DIM];
input [WBW-1:0]     i_bboundary      [DIM];
input [WBW-1:0]     i_blocal_last    [DIM];
input [CV_BW-1:0]   i_bsubofs [VSIZE][DIM];
input [CCV_BW  :0]  i_bsub_up_order  [DIM];
input [CCV_BW-1:0]  i_bsub_lo_order  [DIM];
input [WBW-1:0]     i_aboundary      [DIM];
input [ABW-1:0]     i_mofs_bsteps    [N_CFG][DIM];
input [ABW-1:0]     i_mofs_bsubsteps [N_CFG][CV_BW];
input [ABW-1:0]     i_mofs_asteps    [N_CFG][DIM];
input [NCFG_BW-1:0] i_id_begs [DIM+1];
input [NCFG_BW-1:0] i_id_ends [DIM+1];
input               i_stencil;
input [ST_BW-1:0]   i_stencil_begs [N_CFG];
input [ST_BW-1:0]   i_stencil_ends [N_CFG];
input [ABW-1:0]     i_stencil_lut [STSIZE];
`rdyack_input(mofs);
input [ABW-1:0]     i_mofs;
input [NCFG_BW-1:0] i_id;
`rdyack_output(addrval);
output [NCFG_BW-1:0] o_id;
output [ABW-1:0]     o_address [VSIZE];
output [VSIZE-1:0]   o_valid;
output               o_retire;

//======================================
// Internal
//======================================
logic [WBW-1:0] aofs [DIM];
logic [N_CFG-1:0] awlc_linear_rdys;
logic [N_CFG-1:0] awlc_linear_acks;
logic [ABW-1:0]   awlc_linears [N_CFG];
`rdyack_logic(wait_fin);
`rdyack_logic(s0_src);
`rdyack_logic(s0_dst);
`rdyack_logic(s1_src);
`rdyack_logic(s12);
`rdyack_logic(s23);
`rdyack_logic(s3_dst);
`rdyack_logic(s4_src);
`dval_logic(s4_fin);
logic [DIM-1:0]     s01_reset_flag;
logic [DIM-1:0]     s01_add_flag;
logic [DIM  :0]     s01_sel_beg;
logic [DIM  :0]     s01_sel_end;
logic [DIM  :0]     s01_sel_ret;
logic               s01_bypass;
logic               s01_islast;
logic [NCFG_BW-1:0] s01_id_beg;
logic [NCFG_BW-1:0] s01_id_end;
logic [NCFG_BW-1:0] s01_id_ret;
logic [DIM-1:0]     s12_a_reset_flag;
logic [DIM-1:0]     s12_a_add_flag;
logic [DIM-1:0]     s12_bu_reset_flag;
logic [DIM-1:0]     s12_bu_add_flag;
logic [DIM-1:0]     s12_bl_reset_flag;
logic [DIM-1:0]     s12_bl_add_flag;
logic [NCFG_BW-1:0] s12_id;
logic [WBW-1:0]     s12_bofs [DIM];
logic               s12_retire;
logic               s12_islast;
logic [NCFG_BW-1:0] s23_id;
logic [ABW-1:0]     s23_linear;
logic [WBW-1:0]     s23_bofs [DIM];
logic               s23_retire;
logic               s23_islast;
logic [NCFG_BW-1:0] s34_id;
logic [ABW-1:0]     s34_linear;
logic [WBW-1:0]     s34_bofs [DIM];
logic               s34_retire;
logic               s34_islast;

//======================================
// Combinational
//======================================
assign s01_bypass = s01_id_beg == s01_id_end;
assign s1_src_rdy = s0_dst_rdy && !s01_bypass;
assign s0_dst_ack = s1_src_ack || s0_dst_rdy && s01_bypass;
assign wait_fin_ack = s4_fin_dval || s0_dst_rdy && s01_bypass && s01_islast;
assign s4_src_rdy = s3_dst_rdy && awlc_linear_rdys[s34_id];
assign s3_dst_ack = s4_src_ack;
always_comb for (int i = 0; i < DIM; i++) begin
	aofs[i] = (STENCIL != 0 && i_stencil) ? i_alast[i] : i_aofs[i];
end
always_comb begin
	if (o_retire && addrval_ack) begin
		awlc_linear_acks = 'b1 << o_id;
	end else begin
		awlc_linear_acks = '0;
	end
end

//======================================
// Submodule
//======================================
Broadcast#(2) u_brd0(
	`clk_connect,
	`rdyack_connect(src, abofs),
	.acked(),
	.dst_rdys({wait_fin_rdy,s0_src_rdy}),
	.dst_acks({wait_fin_ack,s0_src_ack})
);
AccumWarpLooperCollector#(.N_CFG(N_CFG), .ABW(ABW)) u_awlc(
	`clk_connect,
	`rdyack_connect(src, mofs),
	.i_linear(i_mofs),
	.i_linear_id(i_id),
	.linear_rdys(awlc_linear_rdys),
	.linear_acks(awlc_linear_acks),
	.o_linears(awlc_linears)
);
OffsetStage#(.FRAC_BW(0), .SHAMT_BW(0)) u_s0_ofs(
	`clk_connect,
	`rdyack_connect(src, s0_src),
	.i_ofs_frac(),
	.i_ofs_shamt(),
	.i_ofs_local_start(aofs),
	.i_ofs_local_last(i_alast),
	.i_ofs_global_last(i_aboundary),
	`rdyack_connect(dst, s0_dst),
	.o_ofs(),
	.o_reset_flag(s01_reset_flag),
	.o_add_flag(s01_add_flag),
	.o_sel_beg(s01_sel_beg),
	.o_sel_end(s01_sel_end),
	.o_sel_ret(s01_sel_ret),
	.o_islast(s01_islast)
);
IdSelect#(.BW(NCFG_BW), .DIM(DIM), .RETIRE(0)) u_s0_sel_beg(
	.i_sel(s01_sel_beg),
	.i_begs(i_id_begs),
	.i_ends(),
	.o_dat(s01_id_beg)
);
IdSelect#(.BW(NCFG_BW), .DIM(DIM), .RETIRE(0)) u_s0_sel_end(
	.i_sel(s01_sel_end),
	.i_begs(i_id_ends),
	.i_ends(),
	.o_dat(s01_id_end)
);
IdSelect#(.BW(NCFG_BW), .DIM(DIM), .RETIRE(1)) u_s0_sel_ret(
	.i_sel(s01_sel_ret),
	.i_begs(i_id_begs),
	.i_ends(i_id_ends),
	.o_dat(s01_id_ret)
);
AccumWarpLooperIndexStage#(.N_CFG(N_CFG)) u_s1_idx(
	`clk_connect,
	`rdyack_connect(src, s1_src),
	.i_bofs(i_bofs),
	.i_aofs(),
	.i_a_reset_flag(s01_reset_flag),
	.i_a_add_flag(s01_add_flag),
	.i_islast(s01_islast),
	.i_id_beg(s01_id_beg),
	.i_id_end(s01_id_end),
	.i_id_ret(s01_id_ret),
	.i_blocal_last(i_blocal_last),
	.i_bsub_up_order(i_bsub_up_order),
	.i_bsub_lo_order(i_bsub_lo_order),
	`rdyack_connect(dst, s12),
	.o_a_reset_flag(s12_a_reset_flag),
	.o_a_add_flag(s12_a_add_flag),
	.o_bu_reset_flag(s12_bu_reset_flag),
	.o_bu_add_flag(s12_bu_add_flag),
	.o_bl_reset_flag(s12_bl_reset_flag),
	.o_bl_add_flag(s12_bl_add_flag),
	.o_id(s12_id),
	.o_warpid(),
	.o_bofs(s12_bofs),
	.o_aofs(),
	.o_retire(s12_retire),
	.o_islast(s12_islast)
);
AccumWarpLooperMemofsStage#(.N_CFG(N_CFG), .ABW(ABW)) u_s2_mofs(
	`clk_connect,
	`rdyack_connect(src, s12),
	.i_a_reset_flag(s12_a_reset_flag),
	.i_a_add_flag(s12_a_add_flag),
	.i_bu_reset_flag(s12_bu_reset_flag),
	.i_bu_add_flag(s12_bu_add_flag),
	.i_bl_reset_flag(s12_bl_reset_flag),
	.i_bl_add_flag(s12_bl_add_flag),
	.i_id(s12_id),
	.i_bofs(s12_bofs),
	.i_retire(s12_retire),
	.i_islast(s12_islast),
	.i_bsub_up_order(i_bsub_up_order),
	.i_mofs_bsteps(i_mofs_bsteps),
	.i_mofs_asteps(i_mofs_asteps),
	`rdyack_connect(dst, s23),
	.o_id(s23_id),
	.o_linear(s23_linear),
	.o_bofs(s23_bofs),
	.o_retire(s23_retire),
	.o_islast(s23_islast)
);
generate if (STENCIL != 0) begin: StencilExpand
AccumWarpLooperStencilStage#(.N_CFG(N_CFG), .ABW(ABW)) u_s3_stencil(
	`clk_connect,
	`rdyack_connect(src, s23),
	.i_id(s23_id),
	.i_linear(s23_linear),
	.i_bofs(s23_bofs),
	.i_retire(s23_retire),
	.i_islast(s23_islast),
	.i_stencil(i_stencil),
	.i_stencil_begs(i_stencil_begs),
	.i_stencil_ends(i_stencil_ends),
	.i_stencil_lut(i_stencil_lut),
	`rdyack_connect(dst, s3_dst),
	.o_id(s34_id),
	.o_linear(s34_linear),
	.o_bofs(s34_bofs),
	.o_retire(s34_retire),
	.o_islast(s34_islast)
);
end else begin: StencilBypass
	assign s3_dst_rdy = s23_rdy;
	assign s23_ack    = s3_dst_ack;
	assign s34_id     = s23_id;
	assign s34_linear = s23_linear;
	assign s34_bofs   = s23_bofs;
	assign s34_retire = s23_retire;
	assign s34_islast = s23_islast;
end endgenerate
AccumWarpLooperVectorStage#(.N_CFG(N_CFG), .ABW(ABW)) u_s4_vofs(
	`clk_connect,
	`rdyack_connect(src, s4_src),
	.i_id(s34_id),
	.i_linear1(s34_linear),
	.i_linear2(awlc_linears[s34_id]),
	.i_bofs(s34_bofs),
	.i_retire(s34_retire),
	.i_islast(s34_islast),
	.i_bboundary(i_bboundary),
	.i_bsubofs(i_bsubofs),
	.i_bsub_lo_order(i_bsub_lo_order),
	.i_mofs_bsubsteps(i_mofs_bsubsteps),
	`rdyack_connect(dst, addrval),
	.o_id(o_id),
	.o_address(o_address),
	.o_valid(o_valid),
	.o_retire(o_retire),
	`dval_connect(fin, s4_fin)
);

endmodule
