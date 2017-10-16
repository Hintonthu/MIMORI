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

module TileAccumUnit(
	`clk_port,
	`rdyack_port(bofs),
	i_bofs,
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
	i_i0_global_mofs_linears,
	i_i0_global_cboundaries,
	i_i0_global_mboundaries,
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
	i_i1_global_mofs_linears,
	i_i1_global_cboundaries,
	i_i1_global_mboundaries,
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
	i_o_id_begs,
	i_o_id_ends,
	i_inst_id_begs,
	i_inst_id_ends,
	i_insts,
	i_consts,
	i_const_texs,
	i_reg_per_warp,
	`rdyack_port(i0_mofs),
	i_i0_mofs,
	`rdyack_port(i1_mofs),
	i_i1_mofs,
	`rdyack_port(o_mofs),
	i_o_mofs,
	`dval_port(blkdone),
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
`rdyack_input(bofs);
input [WBW-1:0]     i_bofs           [DIM];
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
input [GBW-1:0]     i_i0_global_mofs_linears  [N_ICFG];
input [GBW-1:0]     i_i0_global_cboundaries   [N_ICFG][DIM];
input [GBW-1:0]     i_i0_global_mboundaries   [N_ICFG][DIM];
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
input [LBW1-1:0]    i_i1_local_mofs_bsubsteps [N_ICFG][CV_BW];
input [LBW1-1:0]    i_i1_local_mofs_bsteps    [N_ICFG][DIM];
input [LBW1-1:0]    i_i1_local_mofs_asteps    [N_ICFG][DIM];
input [LBW1  :0]    i_i1_local_sizes          [N_ICFG];
input [CV_BW-1:0]   i_i1_local_pads           [N_ICFG][DIM];
input [GBW-1:0]     i_i1_global_mofs_bsteps   [N_ICFG][DIM];
input [GBW-1:0]     i_i1_global_mofs_asteps   [N_ICFG][DIM];
input [GBW-1:0]     i_i1_global_mofs_linears  [N_ICFG];
input [GBW-1:0]     i_i1_global_cboundaries   [N_ICFG][DIM];
input [GBW-1:0]     i_i1_global_mboundaries   [N_ICFG][DIM];
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
input [OCFG_BW-1:0] i_o_id_begs [DIM+1];
input [OCFG_BW-1:0] i_o_id_ends [DIM+1];
input [INST_BW-1:0] i_inst_id_begs [DIM+1];
input [INST_BW-1:0] i_inst_id_ends [DIM+1];
input [ISA_BW-1:0]  i_insts [N_INST];
input [TDBW-1:0]    i_consts [CONST_LUT];
input [TDBW-1:0]    i_const_texs [CONST_TEX_LUT];
input [REG_ABW-1:0] i_reg_per_warp;
`rdyack_input(i0_mofs);
input [GBW-1:0] i_i0_mofs [DIM];
`rdyack_input(i1_mofs);
input [GBW-1:0] i_i1_mofs [DIM];
`rdyack_input(o_mofs);
input [GBW-1:0] i_o_mofs [1];
`dval_output(blkdone);
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
`rdyack_logic(sw_core_bofs);
logic [WBW-1:0] sw_core_bofs [DIM];
`rdyack_logic(sw_i0);
logic [WBW-1:0] sw_i0_bofs  [DIM];
logic [GBW-1:0] sw_i0_mofss [N_ICFG][DIM];
`rdyack_logic(sw_i1);
logic [WBW-1:0] sw_i1_bofs  [DIM];
logic [GBW-1:0] sw_i1_mofss [N_ICFG][DIM];
`rdyack_logic(sw_o);
logic [WBW-1:0] sw_o_bofs  [DIM];
logic [GBW-1:0] sw_o_mofss [N_OCFG][1];
`rdyack_logic(core_alu_abofs);
logic [WBW-1:0] core_alu_bofs  [DIM];
logic [WBW-1:0] core_alu_aofs  [DIM];
logic [WBW-1:0] core_alu_alast [DIM];
`rdyack_logic(core_i0_abofs);
logic [WBW-1:0] core_i0_bofs  [DIM];
logic [WBW-1:0] core_i0_aofs  [DIM];
logic [WBW-1:0] core_i0_alast [DIM];
`rdyack_logic(core_i1_abofs);
logic [WBW-1:0] core_i1_bofs  [DIM];
logic [WBW-1:0] core_i1_aofs  [DIM];
logic [WBW-1:0] core_i1_alast [DIM];
`rdyack_logic(i0_alu_sramrd);
logic [DBW-1:0] i0_alu_sramrd [VSIZE];
`rdyack_logic(i1_alu_sramrd);
logic [DBW-1:0] i1_alu_sramrd [VSIZE];
`rdyack_logic(alu_write_dat);
logic [DBW-1:0] alu_write_dat [VSIZE];
`rdyack_logic(i0_dramra);
logic [GBW-1:0] i0_dramra;
`rdyack_logic(i0_dramrd);
logic [DBW-1:0] i0_dramrd [CSIZE];
`rdyack_logic(i1_dramra);
logic [GBW-1:0] i1_dramra;
`rdyack_logic(i1_dramrd);
logic [DBW-1:0] i1_dramrd [CSIZE];

//======================================
// Submodule
//======================================
TauCollector u_tc(
	`clk_connect,
	.i_i0_id_end(i_i0_id_ends[DIM]),
	.i_i1_id_end(i_i1_id_ends[DIM]),
	.i_o_id_end(i_o_id_ends[DIM]),
	`rdyack_connect(bofs, bofs),
	.i_bofs(i_bofs),
	`rdyack_connect(i0_mofs, i0_mofs),
	.i_i0_mofs(i_i0_mofs),
	`rdyack_connect(i1_mofs, i1_mofs),
	.i_i1_mofs(i_i1_mofs),
	`rdyack_connect(o_mofs, o_mofs),
	.i_o_mofs(i_o_mofs),
	`rdyack_connect(core, sw_core_bofs),
	.o_core_bofs(sw_core_bofs),
	`rdyack_connect(i0_bofs, sw_i0),
	.o_i0_bofs(sw_i0_bofs),
	.o_i0_mofss(sw_i0_mofss),
	`rdyack_connect(i1_bofs, sw_i1),
	.o_i1_bofs(sw_i1_bofs),
	.o_i1_mofss(sw_i1_mofss),
	`rdyack_connect(o_bofs, sw_o),
	.o_o_bofs(sw_o_bofs),
	.o_o_mofss(sw_o_mofss)
);

CoreAccumLooper u_core_accum(
	`clk_connect,
	`rdyack_connect(src, sw_core_bofs),
	.i_bofs(sw_core_bofs),
	.i_agrid_frac(i_agrid_frac),
	.i_agrid_shamt(i_agrid_shamt),
	.i_agrid_last(i_agrid_last),
	.i_aboundary(i_aboundary),
	.i_alocal_last(i_alocal_last),
	`rdyack_connect(i0_abofs, core_i0_abofs),
	.o_i0_bofs(core_i0_bofs),
	.o_i0_aofs(core_i0_aofs),
	.o_i0_alast(core_i0_alast),
	`rdyack_connect(i1_abofs, core_i1_abofs),
	.o_i1_bofs(core_i1_bofs),
	.o_i1_aofs(core_i1_aofs),
	.o_i1_alast(core_i1_alast),
	`rdyack_connect(alu_abofs, core_alu_abofs),
	.o_alu_bofs(core_alu_bofs),
	.o_alu_aofs(core_alu_aofs),
	.o_alu_alast(core_alu_alast),
	`dval_connect(blkdone, blkdone)
);

AluPipeline u_alu(
	`clk_connect,
	`rdyack_connect(abofs, core_alu_abofs),
	.i_bofs(core_alu_bofs),
	.i_aofs(core_alu_aofs),
	.i_alast(core_alu_alast),
	.i_blocal_last(i_blocal_last),
	.i_bsubofs(i_bsubofs),
	.i_bsub_up_order(i_bsub_up_order),
	.i_bsub_lo_order(i_bsub_lo_order),
	.i_aboundary(i_aboundary),
	.i_inst_id_begs(i_inst_id_begs),
	.i_inst_id_ends(i_inst_id_ends),
	.i_insts(i_insts),
	.i_consts(i_consts),
	.i_const_texs(i_const_texs),
	.i_reg_per_warp(i_reg_per_warp),
	`rdyack_connect(sramrd0, i0_alu_sramrd),
	.i_sramrd0(i0_alu_sramrd),
	`rdyack_connect(sramrd1, i1_alu_sramrd),
	.i_sramrd1(i1_alu_sramrd),
	`rdyack_connect(dramwd, alu_write_dat),
	.o_dramwd(alu_write_dat)
);

WritePipeline u_w(
	`clk_connect,
	`rdyack_connect(bofs, sw_o),
	.i_bofs(sw_o_bofs),
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
	.i_mofs_starts(sw_o_mofss),
	.i_mofs_bsteps(i_o_global_mofs_bsteps),
	.i_mofs_bsubsteps(i_o_global_mofs_bsubsteps),
	.i_mofs_asteps(i_o_global_mofs_asteps),
	.i_id_begs(i_o_id_begs),
	.i_id_ends(i_o_id_ends),
	`rdyack_connect(alu_dat, alu_write_dat),
	.i_alu_dat(alu_write_dat),
	`dval_connect(blkdone, blkdone),
	`rdyack_connect(dramw, dramw),
	.o_dramwa(o_dramwa),
	.o_dramwd(o_dramwd),
	.o_dramw_mask(o_dramw_mask)
);

ReadPipeline#(.LBW(LBW0)) u_r0(
	`clk_connect,
	`rdyack_connect(bofs, sw_i0),
	.i_bofs(sw_i0_bofs),
	.i_bboundary(i_bboundary),
	.i_blocal_last(i_blocal_last),
	.i_bsubofs(i_bsubofs),
	.i_bsub_up_order(i_bsub_up_order),
	.i_bsub_lo_order(i_bsub_lo_order),
	.i_agrid_frac(i_agrid_frac),
	.i_agrid_shamt(i_agrid_shamt),
	.i_agrid_last(i_agrid_last),
	.i_aboundary(i_aboundary),
	.i_local_xor_masks(i_i0_local_xor_masks),
	.i_local_xor_schemes(i_i0_local_xor_schemes),
	.i_local_bit_swaps(i_i0_local_bit_swaps),
	.i_local_mofs_bsteps(i_i0_local_mofs_bsteps),
	.i_local_mofs_bsubsteps(i_i0_local_mofs_bsubsteps),
	.i_local_mofs_asteps(i_i0_local_mofs_asteps),
	.i_local_sizes(i_i0_local_sizes),
	.i_local_pads(i_i0_local_pads),
	.i_global_mofss(sw_i0_mofss),
	.i_global_mofs_bsteps(i_i0_global_mofs_bsteps),
	.i_global_mofs_asteps(i_i0_global_mofs_asteps),
	.i_global_mofs_linears(i_i0_global_mofs_linears),
	.i_global_cboundaries(i_i0_global_cboundaries),
	.i_global_mboundaries(i_i0_global_mboundaries),
	.i_global_mofs_ashufs(i_i0_global_mofs_ashufs),
	.i_id_begs(i_i0_id_begs),
	.i_id_ends(i_i0_id_ends),
	.i_stencil(i_i0_stencil),
	.i_stencil_begs(i_i0_stencil_begs),
	.i_stencil_ends(i_i0_stencil_ends),
	.i_stencil_lut(i_i0_stencil_lut),
	`rdyack_connect(warp_abofs, core_i0_abofs),
	.i_warp_bofs(core_i0_bofs),
	.i_warp_aofs(core_i0_aofs),
	.i_warp_alast(core_i0_alast),
	`dval_connect(blkdone, blkdone),
	`rdyack_connect(dramra, i0_dramra),
	.o_dramra(i0_dramra),
	`rdyack_connect(dramrd, i0_dramrd),
	.i_dramrd(i0_dramrd),
	`rdyack_connect(sramrd, i0_alu_sramrd),
	.o_sramrd(i0_alu_sramrd)
);

ReadPipeline#(.LBW(LBW1)) u_r1(
	`clk_connect,
	`rdyack_connect(bofs, sw_i1),
	.i_bofs(sw_i1_bofs),
	.i_bboundary(i_bboundary),
	.i_blocal_last(i_blocal_last),
	.i_bsubofs(i_bsubofs),
	.i_bsub_up_order(i_bsub_up_order),
	.i_bsub_lo_order(i_bsub_lo_order),
	.i_agrid_frac(i_agrid_frac),
	.i_agrid_shamt(i_agrid_shamt),
	.i_agrid_last(i_agrid_last),
	.i_aboundary(i_aboundary),
	.i_local_xor_masks(i_i1_local_xor_masks),
	.i_local_xor_schemes(i_i1_local_xor_schemes),
	.i_local_bit_swaps(i_i1_local_bit_swaps),
	.i_local_mofs_bsteps(i_i1_local_mofs_bsteps),
	.i_local_mofs_bsubsteps(i_i1_local_mofs_bsubsteps),
	.i_local_mofs_asteps(i_i1_local_mofs_asteps),
	.i_local_sizes(i_i1_local_sizes),
	.i_local_pads(i_i1_local_pads),
	.i_global_mofss(sw_i1_mofss),
	.i_global_mofs_bsteps(i_i1_global_mofs_bsteps),
	.i_global_mofs_asteps(i_i1_global_mofs_asteps),
	.i_global_mofs_linears(i_i1_global_mofs_linears),
	.i_global_cboundaries(i_i1_global_cboundaries),
	.i_global_mboundaries(i_i1_global_mboundaries),
	.i_global_mofs_ashufs(i_i1_global_mofs_ashufs),
	.i_id_begs(i_i1_id_begs),
	.i_id_ends(i_i1_id_ends),
	.i_stencil(i_i1_stencil),
	.i_stencil_begs(i_i1_stencil_begs),
	.i_stencil_ends(i_i1_stencil_ends),
	.i_stencil_lut(i_i1_stencil_lut),
	`rdyack_connect(warp_abofs, core_i1_abofs),
	.i_warp_bofs(core_i1_bofs),
	.i_warp_aofs(core_i1_aofs),
	.i_warp_alast(core_i1_alast),
	`dval_connect(blkdone, blkdone),
	`rdyack_connect(dramra, i1_dramra),
	.o_dramra(i1_dramra),
	`rdyack_connect(dramrd, i1_dramrd),
	.i_dramrd(i1_dramrd),
	`rdyack_connect(sramrd, i1_alu_sramrd),
	.o_sramrd(i1_alu_sramrd)
);

DramArbiter u_arb(
	`clk_connect,
	`rdyack_connect(i0_dramra, i0_dramra),
	.i_i0_dramra(i0_dramra),
	`rdyack_connect(i0_dramrd, i0_dramrd),
	.o_i0_dramrd(i0_dramrd),
	`rdyack_connect(i1_dramra, i1_dramra),
	.i_i1_dramra(i1_dramra),
	`rdyack_connect(i1_dramrd, i1_dramrd),
	.o_i1_dramrd(i1_dramrd),
	`rdyack_connect(dramra, dramra),
	.o_dramra(o_dramra),
	`rdyack_connect(dramrd, dramrd),
	.i_dramrd(i_dramrd)
);

endmodule
