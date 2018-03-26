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

import TauCfg::*;

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
	i_i0_local_bit_swaps,
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
	i_i0_id_begs,
	i_i0_id_ends,
	i_i0_stencil,
	i_i0_stencil_begs,
	i_i0_stencil_ends,
	i_i0_stencil_lut,
	i_i1_local_xor_masks,
	i_i1_local_xor_schemes,
	i_i1_local_bit_swaps,
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
	o_dramra,
	`rdyack_port(dramrd),
	i_dramrd,
	`rdyack_port(dramw),
	o_dramwa,
	o_dramwd,
	o_dramw_mask
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
input [CX_BW-1:0]   i_i0_local_xor_schemes    [N_ICFG][CV_BW];
input [CCV_BW-1:0]  i_i0_local_bit_swaps      [N_ICFG];
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
input [ICFG_BW-1:0] i_i0_id_begs [VDIM+1];
input [ICFG_BW-1:0] i_i0_id_ends [VDIM+1];
input               i_i0_stencil;
input [ST_BW-1:0]   i_i0_stencil_begs [N_ICFG];
input [ST_BW-1:0]   i_i0_stencil_ends [N_ICFG];
input [LBW0-1:0]    i_i0_stencil_lut [STSIZE];
input [CV_BW-1:0]   i_i1_local_xor_masks      [N_ICFG];
input [CX_BW-1:0]   i_i1_local_xor_schemes    [N_ICFG][CV_BW];
input [CCV_BW-1:0]  i_i1_local_bit_swaps      [N_ICFG];
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
`rdyack_output(dramra);
output [GBW-1:0] o_dramra;
`rdyack_input(dramrd);
input [DBW-1:0] i_dramrd [CSIZE];
`rdyack_output(dramw);
output [GBW-1:0]   o_dramwa;
output [DBW-1:0]   o_dramwd [CSIZE];
output [CSIZE-1:0] o_dramw_mask;

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
	.i_i0_local_bit_swaps({>>{i_i0_local_bit_swaps}}),
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
	.i_i0_id_begs({>>{i_i0_id_begs}}),
	.i_i0_id_ends({>>{i_i0_id_ends}}),
	.i_i0_stencil(i_i0_stencil),
	.i_i0_stencil_begs({>>{i_i0_stencil_begs}}),
	.i_i0_stencil_ends({>>{i_i0_stencil_ends}}),
	.i_i0_stencil_lut({>>{i_i0_stencil_lut}}),
	.i_i1_local_xor_masks({>>{i_i1_local_xor_masks}}),
	.i_i1_local_xor_schemes({>>{i_i1_local_xor_schemes}}),
	.i_i1_local_bit_swaps({>>{i_i1_local_bit_swaps}}),
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
	`rdyack_connect(dramra, dramra),
	.o_dramra(o_dramra),
	`rdyack_connect(dramrd, dramrd),
	.i_dramrd({>>{i_dramrd}}),
	`rdyack_connect(dramw, dramw),
	.o_dramwa(o_dramwa),
	.o_dramwd({>>{o_dramwd}}),
	.o_dramw_mask(o_dramw_mask)
);

endmodule
