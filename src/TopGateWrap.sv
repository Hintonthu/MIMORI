// Copyright 2018 Yu Sheng Lin

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
`include "common/TauCfg.sv"

module TopGateWrap(
	`clk_port,
	`rdyack_port(src),
	i_bgrid_step,
	i_bgrid_end,
	i_bboundary,
	i_bsubofs,
	i_bsub_up_order,
	i_bsub_lo_order,
	i_agrid_step,
	i_agrid_end,
	i_aboundary,
	i_i0_local_xor_masks,
	i_i0_local_xor_schemes,
	i_i0_local_xor_configs,
	i_i0_local_boundaries,
	i_i0_local_bsubsteps,
	i_i0_local_pads,
	i_i0_global_starts,
	i_i0_global_linears,
	i_i0_global_cboundaries,
	i_i0_global_boundaries,
	i_i0_global_bshufs,
	i_i0_global_ashufs,
	i_i0_bstrides_frac,
	i_i0_bstrides_shamt,
	i_i0_astrides_frac,
	i_i0_astrides_shamt,
	i_i0_wrap,
	i_i0_pad_value,
	i_i0_id_begs,
	i_i0_id_ends,
	i_i0_stencil,
	i_i0_stencil_begs,
	i_i0_stencil_ends,
	i_i0_stencil_lut,
	i_i1_local_xor_masks,
	i_i1_local_xor_schemes,
	i_i1_local_xor_configs,
	i_i1_local_boundaries,
	i_i1_local_bsubsteps,
	i_i1_local_pads,
	i_i1_global_starts,
	i_i1_global_linears,
	i_i1_global_cboundaries,
	i_i1_global_boundaries,
	i_i1_global_bshufs,
	i_i1_global_ashufs,
	i_i1_bstrides_frac,
	i_i1_bstrides_shamt,
	i_i1_astrides_frac,
	i_i1_astrides_shamt,
	i_i1_wrap,
	i_i1_pad_value,
	i_i1_id_begs,
	i_i1_id_ends,
	i_i1_stencil,
	i_i1_stencil_begs,
	i_i1_stencil_ends,
	i_i1_stencil_lut,
	i_o_global_boundaries,
	i_o_global_bsubsteps,
	i_o_global_linears,
	i_o_global_bshufs,
	i_o_bstrides_frac,
	i_o_bstrides_shamt,
	i_o_global_ashufs,
	i_o_astrides_frac,
	i_o_astrides_shamt,
	i_o_id_begs,
	i_o_id_ends,
	i_inst_id_begs,
	i_inst_id_ends,
	i_insts,
	i_consts,
	i_const_texs,
	i_reg_per_warp,
	`rdyack_port(dramra),
	o_dramras,
	`rdyack_port(dramrd),
	i_dramrds,
	`rdyack_port(dramw),
	o_dramwas,
	o_dramwds,
	o_dramw_masks
);

//======================================
//
//======================================
localparam WBW = TauCfg::WORK_BW;
localparam GBW = TauCfg::GLOBAL_ADDR_BW;
localparam LBW0 = TauCfg::LOCAL_ADDR_BW0;
localparam LBW1 = TauCfg::LOCAL_ADDR_BW1;
localparam DBW = TauCfg::DATA_BW;
localparam TDBW = TauCfg::TMP_DATA_BW;
localparam DIM = TauCfg::DIM;
localparam VDIM = TauCfg::VDIM;
localparam N_ICFG = TauCfg::N_ICFG;
localparam N_OCFG = TauCfg::N_OCFG;
localparam N_INST = TauCfg::N_INST;
localparam SS_BW = TauCfg::STRIDE_BW;
localparam SF_BW = TauCfg::STRIDE_FRAC_BW;
localparam ISA_BW = TauCfg::ISA_BW;
localparam VSIZE = TauCfg::VSIZE;
localparam CSIZE = TauCfg::CACHE_SIZE;
localparam XOR_BW = TauCfg::XOR_BW;
localparam REG_ADDR = TauCfg::WARP_REG_ADDR_SPACE;
localparam CONST_LUT = TauCfg::CONST_LUT;
localparam CONST_TEX_LUT = TauCfg::CONST_TEX_LUT;
localparam STSIZE = TauCfg::STENCIL_SIZE;
localparam N_TAU = TauCfg::N_TAU;
`ifdef SD
localparam N_TAU_X = TauCfg::N_TAU_X;
localparam N_TAU_Y = TauCfg::N_TAU_Y;
localparam CN_TAU_X = $clog2(N_TAU_X);
localparam CN_TAU_Y = $clog2(N_TAU_Y);
localparam CN_TAU_X1 = $clog2(N_TAU_X+1);
localparam CN_TAU_Y1 = $clog2(N_TAU_Y+1);
`endif
// derived
localparam ICFG_BW = $clog2(N_ICFG+1);
localparam OCFG_BW = $clog2(N_OCFG+1);
localparam INST_BW = $clog2(N_INST+1);
localparam DIM_BW = $clog2(DIM);
localparam CV_BW = $clog2(VSIZE);
localparam CCV_BW = $clog2(CV_BW+1);
localparam CX_BW = $clog2(XOR_BW);
localparam REG_ABW = $clog2(REG_ADDR);
localparam ST_BW = $clog2(STSIZE+1);

//======================================
// Parameter
//======================================
`clk_input;
`rdyack_input(src);
input [WBW-1:0]     i_bgrid_step     [VDIM];
input [WBW-1:0]     i_bgrid_end      [VDIM];
input [WBW-1:0]     i_bboundary      [VDIM];
input [CV_BW-1:0]   i_bsubofs [VSIZE][VDIM];
input [CCV_BW-1:0]  i_bsub_up_order  [VDIM];
input [CCV_BW-1:0]  i_bsub_lo_order  [VDIM];
input [WBW-1:0]     i_agrid_step     [VDIM];
input [WBW-1:0]     i_agrid_end      [VDIM];
input [WBW-1:0]     i_aboundary      [VDIM];
input [CV_BW-1:0]   i_i0_local_xor_masks      [N_ICFG];
input [CCV_BW-1:0]  i_i0_local_xor_schemes    [N_ICFG][CV_BW];
input [XOR_BW-1:0]  i_i0_local_xor_configs    [N_ICFG];
input [LBW0-1:0]    i_i0_local_boundaries     [N_ICFG][DIM];
input [LBW0-1:0]    i_i0_local_bsubsteps      [N_ICFG][CV_BW];
input [CV_BW-1:0]   i_i0_local_pads           [N_ICFG][DIM];
input [WBW-1:0]     i_i0_global_starts        [N_ICFG][DIM];
input [GBW-1:0]     i_i0_global_linears       [N_ICFG];
input [GBW-1:0]     i_i0_global_cboundaries   [N_ICFG][DIM];
input [GBW-1:0]     i_i0_global_boundaries    [N_ICFG][DIM];
input [DIM_BW-1:0]  i_i0_global_bshufs        [N_ICFG][VDIM];
input [DIM_BW-1:0]  i_i0_global_ashufs        [N_ICFG][VDIM];
input [SF_BW-1:0]   i_i0_bstrides_frac        [N_ICFG][VDIM];
input [SS_BW-1:0]   i_i0_bstrides_shamt       [N_ICFG][VDIM];
input [SF_BW-1:0]   i_i0_astrides_frac        [N_ICFG][VDIM];
input [SS_BW-1:0]   i_i0_astrides_shamt       [N_ICFG][VDIM];
input [N_ICFG-1:0]  i_i0_wrap;
input [DBW-1:0]     i_i0_pad_value [N_ICFG];
input [ICFG_BW-1:0] i_i0_id_begs [VDIM+1];
input [ICFG_BW-1:0] i_i0_id_ends [VDIM+1];
input               i_i0_stencil;
input [ST_BW-1:0]   i_i0_stencil_begs [N_ICFG];
input [ST_BW-1:0]   i_i0_stencil_ends [N_ICFG];
input [LBW0-1:0]    i_i0_stencil_lut [STSIZE];
input [CV_BW-1:0]   i_i1_local_xor_masks      [N_ICFG];
input [CCV_BW-1:0]  i_i1_local_xor_schemes    [N_ICFG][CV_BW];
input [XOR_BW-1:0]  i_i1_local_xor_configs    [N_ICFG];
input [LBW1-1:0]    i_i1_local_boundaries     [N_ICFG][DIM];
input [LBW1-1:0]    i_i1_local_bsubsteps      [N_ICFG][CV_BW];
input [CV_BW-1:0]   i_i1_local_pads           [N_ICFG][DIM];
input [WBW-1:0]     i_i1_global_starts        [N_ICFG][DIM];
input [GBW-1:0]     i_i1_global_linears       [N_ICFG];
input [GBW-1:0]     i_i1_global_cboundaries   [N_ICFG][DIM];
input [GBW-1:0]     i_i1_global_boundaries    [N_ICFG][DIM];
input [DIM_BW-1:0]  i_i1_global_bshufs        [N_ICFG][VDIM];
input [DIM_BW-1:0]  i_i1_global_ashufs        [N_ICFG][VDIM];
input [SF_BW-1:0]   i_i1_bstrides_frac        [N_ICFG][VDIM];
input [SS_BW-1:0]   i_i1_bstrides_shamt       [N_ICFG][VDIM];
input [SF_BW-1:0]   i_i1_astrides_frac        [N_ICFG][VDIM];
input [SS_BW-1:0]   i_i1_astrides_shamt       [N_ICFG][VDIM];
input [N_ICFG-1:0]  i_i1_wrap;
input [DBW-1:0]     i_i1_pad_value [N_ICFG];
input [ICFG_BW-1:0] i_i1_id_begs [VDIM+1];
input [ICFG_BW-1:0] i_i1_id_ends [VDIM+1];
input               i_i1_stencil;
input [ST_BW-1:0]   i_i1_stencil_begs [N_ICFG];
input [ST_BW-1:0]   i_i1_stencil_ends [N_ICFG];
input [LBW1-1:0]    i_i1_stencil_lut [STSIZE];
input [GBW-1:0]     i_o_global_boundaries    [N_OCFG][DIM];
input [GBW-1:0]     i_o_global_bsubsteps     [N_OCFG][CV_BW];
input [GBW-1:0]     i_o_global_linears       [N_OCFG];
input [DIM_BW-1:0]  i_o_global_bshufs        [N_OCFG][VDIM];
input [SF_BW-1:0]   i_o_bstrides_frac        [N_OCFG][VDIM];
input [SS_BW-1:0]   i_o_bstrides_shamt       [N_OCFG][VDIM];
input [DIM_BW-1:0]  i_o_global_ashufs        [N_OCFG][VDIM];
input [SF_BW-1:0]   i_o_astrides_frac        [N_OCFG][VDIM];
input [SS_BW-1:0]   i_o_astrides_shamt       [N_OCFG][VDIM];
input [OCFG_BW-1:0] i_o_id_begs [VDIM+1];
input [OCFG_BW-1:0] i_o_id_ends [VDIM+1];
input [INST_BW-1:0] i_inst_id_begs [VDIM+1];
input [INST_BW-1:0] i_inst_id_ends [VDIM+1];
input [ISA_BW-1:0]  i_insts [N_INST];
input [TDBW-1:0]    i_consts [CONST_LUT];
input [TDBW-1:0]    i_const_texs [CONST_TEX_LUT];
input [REG_ABW-1:0] i_reg_per_warp;
output [N_TAU-1:0] dramra_rdy;
input  [N_TAU-1:0] dramra_ack;
output [GBW-1:0]   o_dramras [N_TAU];
input  [N_TAU-1:0] dramrd_rdy;
output [N_TAU-1:0] dramrd_ack;
input  [DBW-1:0]   i_dramrds [N_TAU][CSIZE];
output [N_TAU-1:0] dramw_rdy;
input  [N_TAU-1:0] dramw_ack;
output [GBW-1:0]   o_dramwas [N_TAU];
output [DBW-1:0]   o_dramwds [N_TAU][CSIZE];
output [CSIZE-1:0] o_dramw_masks [N_TAU];

Top u_top(
	`clk_connect,
	`rdyack_connect(src, src),
	.i_bgrid_step({>>{i_bgrid_step}}),
	.i_bgrid_end({>>{i_bgrid_end}}),
	.i_bboundary({>>{i_bboundary}}),
	.i_bsubofs({>>{i_bsubofs}}),
	.i_bsub_up_order({>>{i_bsub_up_order}}),
	.i_bsub_lo_order({>>{i_bsub_lo_order}}),
	.i_agrid_step({>>{i_agrid_step}}),
	.i_agrid_end({>>{i_agrid_end}}),
	.i_aboundary({>>{i_aboundary}}),
	.i_i0_local_xor_masks({>>{i_i0_local_xor_masks}}),
	.i_i0_local_xor_schemes({>>{i_i0_local_xor_schemes}}),
	.i_i0_local_xor_configs({>>{i_i0_local_xor_configs}}),
	.i_i0_local_boundaries({>>{i_i0_local_boundaries}}),
	.i_i0_local_bsubsteps({>>{i_i0_local_bsubsteps}}),
	.i_i0_local_pads({>>{i_i0_local_pads}}),
	.i_i0_global_starts({>>{i_i0_global_starts}}),
	.i_i0_global_linears({>>{i_i0_global_linears}}),
	.i_i0_global_cboundaries({>>{i_i0_global_cboundaries}}),
	.i_i0_global_boundaries({>>{i_i0_global_boundaries}}),
	.i_i0_global_bshufs({>>{i_i0_global_bshufs}}),
	.i_i0_global_ashufs({>>{i_i0_global_ashufs}}),
	.i_i0_bstrides_frac({>>{i_i0_bstrides_frac}}),
	.i_i0_bstrides_shamt({>>{i_i0_bstrides_shamt}}),
	.i_i0_astrides_frac({>>{i_i0_astrides_frac}}),
	.i_i0_astrides_shamt({>>{i_i0_astrides_shamt}}),
	.i_i0_wrap(i_i0_wrap),
	.i_i0_pad_value({>>{i_i0_pad_value}}),
	.i_i0_id_begs({>>{i_i0_id_begs}}),
	.i_i0_id_ends({>>{i_i0_id_ends}}),
	.i_i0_stencil(i_i0_stencil),
	.i_i0_stencil_begs({>>{i_i0_stencil_begs}}),
	.i_i0_stencil_ends({>>{i_i0_stencil_ends}}),
	.i_i0_stencil_lut({>>{i_i0_stencil_lut}}),
	.i_i1_local_xor_masks({>>{i_i1_local_xor_masks}}),
	.i_i1_local_xor_schemes({>>{i_i1_local_xor_schemes}}),
	.i_i1_local_xor_configs({>>{i_i1_local_xor_configs}}),
	.i_i1_local_boundaries({>>{i_i1_local_boundaries}}),
	.i_i1_local_bsubsteps({>>{i_i1_local_bsubsteps}}),
	.i_i1_local_pads({>>{i_i1_local_pads}}),
	.i_i1_global_starts({>>{i_i1_global_starts}}),
	.i_i1_global_linears({>>{i_i1_global_linears}}),
	.i_i1_global_cboundaries({>>{i_i1_global_cboundaries}}),
	.i_i1_global_boundaries({>>{i_i1_global_boundaries}}),
	.i_i1_global_bshufs({>>{i_i1_global_bshufs}}),
	.i_i1_global_ashufs({>>{i_i1_global_ashufs}}),
	.i_i1_bstrides_frac({>>{i_i1_bstrides_frac}}),
	.i_i1_bstrides_shamt({>>{i_i1_bstrides_shamt}}),
	.i_i1_astrides_frac({>>{i_i1_astrides_frac}}),
	.i_i1_astrides_shamt({>>{i_i1_astrides_shamt}}),
	.i_i1_wrap(i_i1_wrap),
	.i_i1_pad_value({>>{i_i1_pad_value}}),
	.i_i1_id_begs({>>{i_i1_id_begs}}),
	.i_i1_id_ends({>>{i_i1_id_ends}}),
	.i_i1_stencil(i_i1_stencil),
	.i_i1_stencil_begs({>>{i_i1_stencil_begs}}),
	.i_i1_stencil_ends({>>{i_i1_stencil_ends}}),
	.i_i1_stencil_lut({>>{i_i1_stencil_lut}}),
	.i_o_global_boundaries({>>{i_o_global_boundaries}}),
	.i_o_global_bsubsteps({>>{i_o_global_bsubsteps}}),
	.i_o_global_linears({>>{i_o_global_linears}}),
	.i_o_global_bshufs({>>{i_o_global_bshufs}}),
	.i_o_bstrides_frac({>>{i_o_bstrides_frac}}),
	.i_o_bstrides_shamt({>>{i_o_bstrides_shamt}}),
	.i_o_global_ashufs({>>{i_o_global_ashufs}}),
	.i_o_astrides_frac({>>{i_o_astrides_frac}}),
	.i_o_astrides_shamt({>>{i_o_astrides_shamt}}),
	.i_o_id_begs({>>{i_o_id_begs}}),
	.i_o_id_ends({>>{i_o_id_ends}}),
	.i_inst_id_begs({>>{i_inst_id_begs}}),
	.i_inst_id_ends({>>{i_inst_id_ends}}),
	.i_insts({>>{i_insts}}),
	.i_consts({>>{i_consts}}),
	.i_const_texs({>>{i_const_texs}}),
	.i_reg_per_warp(i_reg_per_warp),
	.dramra_rdy(dramra_rdy),
	.dramra_ack(dramra_ack),
	.o_dramras({>>{o_dramras}}),
	.dramrd_rdy(dramrd_rdy),
	.dramrd_ack(dramrd_ack),
	.i_dramrds({>>{i_dramrds}}),
	.dramw_rdy(dramw_rdy),
	.dramw_ack(dramw_ack),
	.o_dramwas({>>{o_dramwas}}),
	.o_dramwds({>>{o_dramwds}}),
	.o_dramw_masks({>>{o_dramw_masks}})
);

endmodule
