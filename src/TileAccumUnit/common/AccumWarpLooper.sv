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

module AccumWarpLooper(
	`clk_port,
	`rdyack_port(abofs),
	i_bofs,
	i_abeg,
	i_aend,
	i_linears,
	i_bboundary,
	i_bsubofs,
	i_bsub_up_order,
	i_bsub_lo_order,
	i_aboundary,
	i_bgrid_step,
	i_global_bshufs,
	i_bstrides_frac,
	i_bstrides_shamt,
	i_global_ashufs,
	i_astrides_frac,
	i_astrides_shamt,
	i_mofs_bsubsteps,
	i_mboundaries,
	i_id_begs,
	i_id_ends,
	// only for i_stencil == 1 & STENCIL is enabled
	i_stencil,
	i_stencil_begs,
	i_stencil_ends,
	i_stencil_lut,
	`rdyack_port(addrval),
	o_id,
	o_address,
	o_valid,
	o_retire
);

//======================================
// Parameter
//======================================
parameter N_CFG = TauCfg::N_ICFG;
parameter ABW = TauCfg::GLOBAL_ADDR_BW;
parameter STENCIL = 0;
parameter USE_LOFS = 0;
localparam WBW = TauCfg::WORK_BW;
localparam VDIM = TauCfg::VDIM;
localparam DIM = TauCfg::DIM;
localparam VSIZE = TauCfg::VSIZE;
localparam STSIZE = TauCfg::STENCIL_SIZE;
localparam SS_BW = TauCfg::STRIDE_BW;
localparam SF_BW = TauCfg::STRIDE_FRAC_BW;
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
input [WBW-1:0]     i_bofs [VDIM];
input [WBW-1:0]     i_abeg [VDIM];
input [WBW-1:0]     i_aend [VDIM];
input [ABW-1:0]     i_linears [N_CFG];
input [WBW-1:0]     i_bboundary      [VDIM];
input [CV_BW-1:0]   i_bsubofs [VSIZE][VDIM];
input [CCV_BW-1:0]  i_bsub_up_order  [VDIM];
input [CCV_BW-1:0]  i_bsub_lo_order  [VDIM];
input [WBW-1:0]     i_aboundary      [VDIM];
input [WBW-1:0]     i_bgrid_step     [VDIM];
input [DIM_BW-1:0]  i_global_bshufs  [N_CFG][VDIM];
input [SF_BW-1:0]   i_bstrides_frac  [N_CFG][VDIM];
input [SS_BW-1:0]   i_bstrides_shamt [N_CFG][VDIM];
input [DIM_BW-1:0]  i_global_ashufs  [N_CFG][VDIM];
input [SF_BW-1:0]   i_astrides_frac  [N_CFG][VDIM];
input [SS_BW-1:0]   i_astrides_shamt [N_CFG][VDIM];
input [ABW-1:0]     i_mofs_bsubsteps [N_CFG][CV_BW];
input [ABW-1:0]     i_mboundaries    [N_CFG][DIM];
input [NCFG_BW-1:0] i_id_begs [VDIM+1];
input [NCFG_BW-1:0] i_id_ends [VDIM+1];
input               i_stencil;
input [ST_BW-1:0]   i_stencil_begs [N_CFG];
input [ST_BW-1:0]   i_stencil_ends [N_CFG];
input [ABW-1:0]     i_stencil_lut [STSIZE];
`rdyack_output(addrval);
output [NCFG_BW-1:0] o_id;
output [ABW-1:0]     o_address [VSIZE];
output [VSIZE-1:0]   o_valid;
output               o_retire;

//======================================
// Internal
//======================================
`rdyack_logic(wait_fin);
`rdyack_logic(s0_src);
`rdyack_logic(s0_dst);
`rdyack_logic(s1_src);
`rdyack_logic(s12);
`rdyack_logic(s23);
`rdyack_logic(s34);
`dval_logic(s4_fin);
logic stencil_en;
logic [WBW-1:0] abeg [VDIM];
logic [WBW-1:0] aend [VDIM];
logic [WBW-1:0] s01_aofs  [VDIM];
logic [WBW-1:0] s01_alofs [VDIM];
logic [VDIM:0] s01_sel_beg;
logic [VDIM:0] s01_sel_end;
logic [VDIM:0] s01_sel_ret;
logic               s01_bypass;
logic               s01_skipped;
logic               s01_islast;
logic [NCFG_BW-1:0] s01_id_beg;
logic [NCFG_BW-1:0] s01_id_end;
logic [NCFG_BW-1:0] s01_id_ret;
logic [NCFG_BW-1:0] s12_id;
logic [WBW-1:0]     s12_bgofs [VDIM];
logic [WBW-1:0]     s12_agofs [VDIM];
logic [WBW-1:0]     s12_blofs [VDIM];
logic [WBW-1:0]     s12_alofs [VDIM];
logic [WBW-1:0]     s12_bofs  [VDIM];
logic [WBW-1:0]     s12_aofs  [VDIM];
logic               s12_retire;
logic               s12_islast;
logic [NCFG_BW-1:0] s23_id;
logic [ABW-1:0]     s23_linear;
logic [WBW-1:0]     s23_bofs [VDIM];
logic               s23_retire;
logic               s23_islast;
logic [NCFG_BW-1:0] s34_id;
logic [ABW-1:0]     s34_linear;
logic [WBW-1:0]     s34_bofs [VDIM];
logic               s34_retire;
logic               s34_islast;

//======================================
// Combinational
//======================================
assign s01_bypass = s01_id_beg == s01_id_end;
assign wait_fin_ack = wait_fin_rdy && (s4_fin_dval || s01_skipped && s01_islast);
assign stencil_en = STENCIL != 0 && i_stencil;
assign s12_bofs = USE_LOFS ? s12_blofs : s12_bgofs;
assign s12_aofs = USE_LOFS ? s12_alofs : s12_agofs;
always_comb for (int i = 0; i < VDIM; i++) begin
	abeg[i] = stencil_en ? 'b0 : i_abeg[i];
	aend[i] = stencil_en ? 'b1 : i_aend[i];
end

//======================================
// Submodule
//======================================
BroadcastInorder#(2) u_brd0(
	`clk_connect,
	`rdyack_connect(src, abofs),
	.dst_rdys({wait_fin_rdy,s0_src_rdy}),
	.dst_acks({wait_fin_ack,s0_src_ack})
);
OffsetStage#(.BW(WBW), .DIM(VDIM), .FROM_ZERO(0), .UNIT_STRIDE(1)) u_s0_ofs(
	`clk_connect,
	`rdyack_connect(src, s0_src),
	.i_ofs_beg(abeg),
	.i_ofs_end(aend),
	.i_ofs_gend(i_aboundary),
	.i_stride(),
	`rdyack_connect(dst, s0_dst),
	.o_ofs(s01_aofs),
	.o_lofs(s01_alofs),
	.o_sel_beg(s01_sel_beg),
	.o_sel_end(s01_sel_end),
	.o_sel_ret(s01_sel_ret),
	.o_islast(s01_islast)
);
IdSelect#(.BW(NCFG_BW), .DIM(VDIM), .RETIRE(0)) u_s0_sel_beg(
	.i_sel(s01_sel_beg),
	.i_begs(i_id_begs),
	.i_ends(),
	.o_dat(s01_id_beg)
);
IdSelect#(.BW(NCFG_BW), .DIM(VDIM), .RETIRE(0)) u_s0_sel_end(
	.i_sel(s01_sel_end),
	.i_begs(i_id_ends),
	.i_ends(),
	.o_dat(s01_id_end)
);
IdSelect#(.BW(NCFG_BW), .DIM(VDIM), .RETIRE(1)) u_s0_sel_ret(
	.i_sel(s01_sel_ret),
	.i_begs(i_id_begs),
	.i_ends(i_id_ends),
	.o_dat(s01_id_ret)
);
IgnoreIf#(1) u_ign_01(
	.cond(s01_bypass),
	`rdyack_connect(src, s0_dst),
	`rdyack_connect(dst, s1_src),
	.skipped(s01_skipped)
);
AccumWarpLooperIndexStage#(.N_CFG(N_CFG)) u_s1_idx(
	`clk_connect,
	`rdyack_connect(src, s1_src),
	.i_bofs(i_bofs),
	.i_aofs(s01_aofs),
	.i_alofs(s01_alofs),
	.i_islast(s01_islast),
	.i_id_beg(s01_id_beg),
	.i_id_end(s01_id_end),
	.i_id_ret(s01_id_ret),
	.i_bgrid_step(i_bgrid_step),
	.i_bsub_up_order(i_bsub_up_order),
	.i_bsub_lo_order(i_bsub_lo_order),
	`rdyack_connect(dst, s12),
	.o_id(s12_id),
	.o_warpid(),
	.o_bofs(s12_bgofs),
	.o_aofs(s12_agofs),
	.o_blofs(s12_blofs),
	.o_alofs(s12_alofs),
	.o_retire(s12_retire),
	.o_islast(s12_islast)
);
AccumWarpLooperMemofsStage#(.N_CFG(N_CFG), .ABW(ABW)) u_s2_mofs(
	`clk_connect,
	`rdyack_connect(src, s12),
	.i_id(s12_id),
	.i_bofs(s12_bofs),
	.i_aofs(s12_aofs),
	.i_retire(s12_retire),
	.i_islast(s12_islast),
	.i_global_bshuf(i_global_bshufs[s12_id]),
	.i_global_ashuf(i_global_ashufs[s12_id]),
	.i_bstride_frac(i_bstrides_frac[s12_id]),
	.i_bstride_shamt(i_bstrides_shamt[s12_id]),
	.i_astride_frac(i_astrides_frac[s12_id]),
	.i_astride_shamt(i_astrides_shamt[s12_id]),
	.i_linear(i_linears[s12_id]),
	.i_mboundary(i_mboundaries[s12_id]),
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
	`rdyack_connect(dst, s34),
	.o_id(s34_id),
	.o_linear(s34_linear),
	.o_bofs(s34_bofs),
	.o_retire(s34_retire),
	.o_islast(s34_islast)
);
end else begin: StencilBypass
	assign s34_rdy = s23_rdy;
	assign s23_ack = s34_ack;
	assign s34_id     = s23_id;
	assign s34_linear = s23_linear;
	assign s34_bofs   = s23_bofs;
	assign s34_retire = s23_retire;
	assign s34_islast = s23_islast;
end endgenerate
AccumWarpLooperVectorStage#(.N_CFG(N_CFG), .ABW(ABW)) u_s4_vofs(
	`clk_connect,
	`rdyack_connect(src, s34),
	.i_id(s34_id),
	.i_linear(s34_linear),
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
