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

module Top(
	`clk_port,
	`rdyack_port(src),
	i_bgrid_frac,
	i_bgrid_shamt,
	i_bgrid_last,
	i_bboundary,
	i_blocal_last,
	i_bsubofs,
	i_bsub_up_order,
	i_bsub_lo_order,
	i_agrid_frac,
	i_agrid_shamt,
	i_agrid_last,
	i_aboundary,
	i_alocal_last,
	i_i0_local_xor_masks,
	i_i0_local_xor_schemes,
	i_i0_local_bit_swaps,
	i_i0_local_mofs_bsteps,
	i_i0_local_mofs_bsubsteps,
	i_i0_local_mofs_asteps,
	i_i0_local_sizes,
	i_i0_local_pads,
	i_i0_global_mofs_bsteps,
	i_i0_global_mofs_asteps,
	i_i0_global_mofs_starts,
	i_i0_global_mofs_linears,
	i_i0_global_cboundaries,
	i_i0_global_mboundaries,
	i_i0_global_mofs_bshufs,
	i_i0_global_mofs_ashufs,
	i_i0_id_begs,
	i_i0_id_ends,
	i_i0_stencil,
	i_i0_stencil_begs,
	i_i0_stencil_ends,
	i_i0_stencil_lut,
	i_i1_local_xor_masks,
	i_i1_local_xor_schemes,
	i_i1_local_bit_swaps,
	i_i1_local_mofs_bsteps,
	i_i1_local_mofs_bsubsteps,
	i_i1_local_mofs_asteps,
	i_i1_local_sizes,
	i_i1_local_pads,
	i_i1_global_mofs_bsteps,
	i_i1_global_mofs_asteps,
	i_i1_global_mofs_starts,
	i_i1_global_mofs_linears,
	i_i1_global_cboundaries,
	i_i1_global_mboundaries,
	i_i1_global_mofs_bshufs,
	i_i1_global_mofs_ashufs,
	i_i1_id_begs,
	i_i1_id_ends,
	i_i1_stencil,
	i_i1_stencil_begs,
	i_i1_stencil_ends,
	i_i1_stencil_lut,
	i_o_global_mofs_bsteps,
	i_o_global_mofs_bsubsteps,
	i_o_global_mofs_asteps,
	i_o_global_mofs_linears,
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
// Parameter
//======================================
localparam WBW = TauCfg::WORK_BW;
localparam GBW = TauCfg::GLOBAL_ADDR_BW;
localparam LBW0 = TauCfg::LOCAL_ADDR_BW0;
localparam LBW1 = TauCfg::LOCAL_ADDR_BW1;
localparam DBW = TauCfg::DATA_BW;
localparam TDBW = TauCfg::TMP_DATA_BW;
localparam DIM = TauCfg::DIM;
localparam N_ICFG = TauCfg::N_ICFG;
localparam N_OCFG = TauCfg::N_OCFG;
localparam N_INST = TauCfg::N_INST;
localparam BF_BW = TauCfg::BOFS_FRAC_BW;
localparam BS_BW = TauCfg::BOFS_SHAMT_BW;
localparam AF_BW = TauCfg::AOFS_FRAC_BW;
localparam AS_BW = TauCfg::AOFS_SHAMT_BW;
localparam ISA_BW = TauCfg::ISA_BW;
localparam VSIZE = TauCfg::VECTOR_SIZE;
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
// I/O
//======================================
`clk_input;
`rdyack_input(src);
input [BF_BW-1:0]   i_bgrid_frac     [DIM];
input [BS_BW-1:0]   i_bgrid_shamt    [DIM];
input [WBW-1:0]     i_bgrid_last     [DIM];
input [WBW-1:0]     i_bboundary      [DIM];
input [WBW-1:0]     i_blocal_last    [DIM];
input [CV_BW-1:0]   i_bsubofs [VSIZE][DIM];
input [CCV_BW  :0]  i_bsub_up_order  [DIM];
input [CCV_BW-1:0]  i_bsub_lo_order  [DIM];
input [AF_BW-1:0]   i_agrid_frac     [DIM];
input [AS_BW-1:0]   i_agrid_shamt    [DIM];
input [WBW-1:0]     i_agrid_last     [DIM];
input [WBW-1:0]     i_aboundary      [DIM];
input [WBW-1:0]     i_alocal_last    [DIM];
input [CV_BW-1:0]   i_i0_local_xor_masks      [N_ICFG];
input [CX_BW-1:0]   i_i0_local_xor_schemes    [N_ICFG][CV_BW];
input [CCV_BW-1:0]  i_i0_local_bit_swaps      [N_ICFG];
input [LBW0-1:0]    i_i0_local_mofs_bsteps    [N_ICFG][DIM];
input [LBW0-1:0]    i_i0_local_mofs_bsubsteps [N_ICFG][CV_BW];
input [LBW0-1:0]    i_i0_local_mofs_asteps    [N_ICFG][DIM];
input [LBW0  :0]    i_i0_local_sizes          [N_ICFG];
input [CV_BW-1:0]   i_i0_local_pads           [N_ICFG][DIM];
input [GBW-1:0]     i_i0_global_mofs_bsteps   [N_ICFG][DIM];
input [GBW-1:0]     i_i0_global_mofs_asteps   [N_ICFG][DIM];
input [GBW-1:0]     i_i0_global_mofs_starts   [N_ICFG][DIM];
input [GBW-1:0]     i_i0_global_mofs_linears  [N_ICFG];
input [GBW-1:0]     i_i0_global_cboundaries   [N_ICFG][DIM];
input [GBW-1:0]     i_i0_global_mboundaries   [N_ICFG][DIM];
input [DIM_BW-1:0]  i_i0_global_mofs_bshufs   [N_ICFG][DIM];
input [DIM_BW-1:0]  i_i0_global_mofs_ashufs   [N_ICFG][DIM];
input [ICFG_BW-1:0] i_i0_id_begs [DIM+1];
input [ICFG_BW-1:0] i_i0_id_ends [DIM+1];
input               i_i0_stencil;
input [ST_BW-1:0]   i_i0_stencil_begs [N_ICFG];
input [ST_BW-1:0]   i_i0_stencil_ends [N_ICFG];
input [LBW0-1:0]    i_i0_stencil_lut [STSIZE];
input [CV_BW-1:0]   i_i1_local_xor_masks      [N_ICFG];
input [CX_BW-1:0]   i_i1_local_xor_schemes    [N_ICFG][CV_BW];
input [CCV_BW-1:0]  i_i1_local_bit_swaps      [N_ICFG];
input [LBW1-1:0]    i_i1_local_mofs_bsteps    [N_ICFG][DIM];
input [LBW1-1:0]    i_i1_local_mofs_bsubsteps [N_ICFG][CV_BW];
input [LBW1-1:0]    i_i1_local_mofs_asteps    [N_ICFG][DIM];
input [LBW1  :0]    i_i1_local_sizes          [N_ICFG];
input [CV_BW-1:0]   i_i1_local_pads           [N_ICFG][DIM];
input [GBW-1:0]     i_i1_global_mofs_bsteps   [N_ICFG][DIM];
input [GBW-1:0]     i_i1_global_mofs_asteps   [N_ICFG][DIM];
input [GBW-1:0]     i_i1_global_mofs_starts   [N_ICFG][DIM];
input [GBW-1:0]     i_i1_global_mofs_linears  [N_ICFG];
input [GBW-1:0]     i_i1_global_cboundaries   [N_ICFG][DIM];
input [GBW-1:0]     i_i1_global_mboundaries   [N_ICFG][DIM];
input [DIM_BW-1:0]  i_i1_global_mofs_bshufs   [N_ICFG][DIM];
input [DIM_BW-1:0]  i_i1_global_mofs_ashufs   [N_ICFG][DIM];
input [ICFG_BW-1:0] i_i1_id_begs [DIM+1];
input [ICFG_BW-1:0] i_i1_id_ends [DIM+1];
input               i_i1_stencil;
input [ST_BW-1:0]   i_i1_stencil_begs [N_ICFG];
input [ST_BW-1:0]   i_i1_stencil_ends [N_ICFG];
input [LBW1-1:0]    i_i1_stencil_lut [STSIZE];
input [GBW-1:0]     i_o_global_mofs_bsteps    [N_OCFG][DIM];
input [GBW-1:0]     i_o_global_mofs_bsubsteps [N_OCFG][CV_BW];
input [GBW-1:0]     i_o_global_mofs_asteps    [N_OCFG][DIM];
input [GBW-1:0]     i_o_global_mofs_linears   [N_OCFG][1]; // [1] for convenience
input [OCFG_BW-1:0] i_o_id_begs [DIM+1];
input [OCFG_BW-1:0] i_o_id_ends [DIM+1];
input [INST_BW-1:0] i_inst_id_begs [DIM+1];
input [INST_BW-1:0] i_inst_id_ends [DIM+1];
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

//======================================
// Internal
//======================================
`rdyack_logic(blk_tau_bofs);
logic [WBW-1:0] blk_tau_bofs [DIM];
`rdyack_logic(blk_tau_i0_mofs);
logic [GBW-1:0] blk_tau_i0_mofs [DIM];
`rdyack_logic(blk_tau_i1_mofs);
logic [GBW-1:0] blk_tau_i1_mofs [DIM];
`rdyack_logic(blk_tau_o_mofs);
logic [GBW-1:0] blk_tau_o_mofs [1];
`dval_logic(tau_blk_done);

//======================================
// Submodule
//======================================
BlockMemoryLooper u_bl(
	`clk_connect,
	`rdyack_connect(src, src),
	.i_bgrid_frac(i_bgrid_frac),
	.i_bgrid_shamt(i_bgrid_shamt),
	.i_bgrid_last(i_bgrid_last),
	.i_i0_mofs_starts(i_i0_global_mofs_starts),
	.i_i0_mofs_steps(i_i0_global_mofs_bsteps),
	.i_i0_mofs_shufs(i_i0_global_mofs_bshufs),
	.i_i0_id_end(i_i0_id_ends[DIM]),
	.i_i1_mofs_starts(i_i1_global_mofs_starts),
	.i_i1_mofs_steps(i_i1_global_mofs_bsteps),
	.i_i1_mofs_shufs(i_i1_global_mofs_bshufs),
	.i_i1_id_end(i_i1_id_ends[DIM]),
	.i_o_mofs_linears(i_o_global_mofs_linears),
	.i_o_mofs_steps(i_o_global_mofs_bsteps),
	.i_o_id_end(i_o_id_ends[DIM]),
	`rdyack_connect(bofs, blk_tau_bofs),
	.o_bofs(blk_tau_bofs),
	`rdyack_connect(i0_mofs, blk_tau_i0_mofs),
	.o_i0_mofs(blk_tau_i0_mofs),
	`rdyack_connect(i1_mofs, blk_tau_i1_mofs),
	.o_i1_mofs(blk_tau_i1_mofs),
	`rdyack_connect(o_mofs, blk_tau_o_mofs),
	.o_o_mofs(blk_tau_o_mofs),
	`dval_connect(blkdone, tau_blk_done)
);

TileAccumUnit u_tau(
	`clk_connect,
	`rdyack_connect(bofs, blk_tau_bofs),
	.i_bofs(blk_tau_bofs),
	.i_bboundary(i_bboundary),
	.i_blocal_last(i_blocal_last),
	.i_bsubofs(i_bsubofs),
	.i_bsub_up_order(i_bsub_up_order),
	.i_bsub_lo_order(i_bsub_lo_order),
	.i_agrid_frac(i_agrid_frac),
	.i_agrid_shamt(i_agrid_shamt),
	.i_agrid_last(i_agrid_last),
	.i_aboundary(i_aboundary),
	.i_alocal_last(i_alocal_last),
	.i_i0_local_xor_masks(i_i0_local_xor_masks),
	.i_i0_local_xor_schemes(i_i0_local_xor_schemes),
	.i_i0_local_bit_swaps(i_i0_local_bit_swaps),
	.i_i0_local_mofs_bsteps(i_i0_local_mofs_bsteps),
	.i_i0_local_mofs_bsubsteps(i_i0_local_mofs_bsubsteps),
	.i_i0_local_mofs_asteps(i_i0_local_mofs_asteps),
	.i_i0_local_sizes(i_i0_local_sizes),
	.i_i0_local_pads(i_i0_local_pads),
	.i_i0_global_mofs_bsteps(i_i0_global_mofs_bsteps),
	.i_i0_global_mofs_asteps(i_i0_global_mofs_asteps),
	.i_i0_global_mofs_linears(i_i0_global_mofs_linears),
	.i_i0_global_cboundaries(i_i0_global_cboundaries),
	.i_i0_global_mboundaries(i_i0_global_mboundaries),
	.i_i0_global_mofs_ashufs(i_i0_global_mofs_ashufs),
	.i_i0_id_begs(i_i0_id_begs),
	.i_i0_id_ends(i_i0_id_ends),
	.i_i0_stencil(i_i0_stencil),
	.i_i0_stencil_begs(i_i0_stencil_begs),
	.i_i0_stencil_ends(i_i0_stencil_ends),
	.i_i0_stencil_lut(i_i0_stencil_lut),
	.i_i1_local_xor_masks(i_i1_local_xor_masks),
	.i_i1_local_xor_schemes(i_i1_local_xor_schemes),
	.i_i1_local_bit_swaps(i_i1_local_bit_swaps),
	.i_i1_local_mofs_bsteps(i_i1_local_mofs_bsteps),
	.i_i1_local_mofs_bsubsteps(i_i1_local_mofs_bsubsteps),
	.i_i1_local_mofs_asteps(i_i1_local_mofs_asteps),
	.i_i1_local_sizes(i_i1_local_sizes),
	.i_i1_local_pads(i_i1_local_pads),
	.i_i1_global_mofs_bsteps(i_i1_global_mofs_bsteps),
	.i_i1_global_mofs_asteps(i_i1_global_mofs_asteps),
	.i_i1_global_mofs_linears(i_i1_global_mofs_linears),
	.i_i1_global_cboundaries(i_i1_global_cboundaries),
	.i_i1_global_mboundaries(i_i1_global_mboundaries),
	.i_i1_global_mofs_ashufs(i_i1_global_mofs_ashufs),
	.i_i1_id_begs(i_i1_id_begs),
	.i_i1_id_ends(i_i1_id_ends),
	.i_i1_stencil(i_i1_stencil),
	.i_i1_stencil_begs(i_i1_stencil_begs),
	.i_i1_stencil_ends(i_i1_stencil_ends),
	.i_i1_stencil_lut(i_i1_stencil_lut),
	.i_o_global_mofs_bsteps(i_o_global_mofs_bsteps),
	.i_o_global_mofs_bsubsteps(i_o_global_mofs_bsubsteps),
	.i_o_global_mofs_asteps(i_o_global_mofs_asteps),
	.i_o_id_begs(i_o_id_begs),
	.i_o_id_ends(i_o_id_ends),
	.i_inst_id_begs(i_inst_id_begs),
	.i_inst_id_ends(i_inst_id_ends),
	.i_insts(i_insts),
	.i_consts(i_consts),
	.i_const_texs(i_const_texs),
	.i_reg_per_warp(i_reg_per_warp),
	`rdyack_connect(i0_mofs, blk_tau_i0_mofs),
	.i_i0_mofs(blk_tau_i0_mofs),
	`rdyack_connect(i1_mofs, blk_tau_i1_mofs),
	.i_i1_mofs(blk_tau_i1_mofs),
	`rdyack_connect(o_mofs, blk_tau_o_mofs),
	.i_o_mofs(blk_tau_o_mofs),
	`dval_connect(blkdone, tau_blk_done),
	`rdyack_connect(dramra, dramra),
	.o_dramra(o_dramra),
	`rdyack_connect(dramrd, dramrd),
	.i_dramrd(i_dramrd),
	`rdyack_connect(dramw, dramw),
	.o_dramwa(o_dramwa),
	.o_dramwd(o_dramwd),
	.o_dramw_mask(o_dramw_mask)
);

endmodule
