// Copyright 2016-2018 Yu Sheng Lin

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
`include "common/Controllers.sv"
`ifdef SD
`include "TileAccumUnit/SystolicSwitch.sv"
`endif
`include "TileAccumUnit/AccumBlockLooper.sv"
`include "TileAccumUnit/DramArbiter.sv"
`include "TileAccumUnit/AluPipeline/AluPipeline.sv"
`include "TileAccumUnit/ReadPipeline/ReadPipeline.sv"
`include "TileAccumUnit/WritePipeline/WritePipeline.sv"

module TileAccumUnit(
	`clk_port,
	`rdyack_port(bofs),
	i_bofs,
`ifdef SD
	i_i0_systolic_gsize,
	i_i0_systolic_idx,
	i_i1_systolic_gsize,
	i_i1_systolic_idx,
`endif
	i_bboundary,
	i_bsubofs,
	i_bsub_up_order,
	i_bsub_lo_order,
	i_agrid_step,
	i_bgrid_step,
	i_agrid_end,
	i_aboundary,
	i_i0_local_xor_srcs,
	i_i0_local_xor_swaps,
	i_i0_local_boundaries,
	i_i0_local_bsubsteps,
	i_i0_local_pads,
	i_i0_global_starts,
	i_i0_global_linears,
	i_i0_global_cboundaries,
	i_i0_global_boundaries,
	i_i0_global_bshufs,
	i_i0_bstrides_frac,
	i_i0_bstrides_shamt,
	i_i0_global_ashufs,
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
`ifdef SD
	i_i0_systolic_skip,
`endif
	i_i1_local_xor_srcs,
	i_i1_local_xor_swaps,
	i_i1_local_boundaries,
	i_i1_local_bsubsteps,
	i_i1_local_pads,
	i_i1_global_starts,
	i_i1_global_linears,
	i_i1_global_cboundaries,
	i_i1_global_boundaries,
	i_i1_global_bshufs,
	i_i1_bstrides_frac,
	i_i1_bstrides_shamt,
	i_i1_global_ashufs,
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
`ifdef SD
	i_i1_systolic_skip,
`endif
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
	i_inst_id_begs, i_inst_id_ends,
	i_insts,
	i_consts,
	i_const_texs,
	i_reg_per_warp,
	`dval_port(blkdone),
	`rdyack_port(dramra),
	o_dramra,
	`rdyack_port(dramrd),
	i_dramrd,
	`rdyack_port(dramw),
	o_dramwa,
	o_dramwd,
	o_dramw_mask
`ifdef SD
	// For systolic connections
	,
	`rdyack_port(i0_dir0_syst_in),
	i0_dir0_syst_data_in,
	`rdyack_port(i0_dir1_syst_in),
	i0_dir1_syst_data_in,
	`rdyack_port(i0_dir0_syst_out),
	`rdyack_port(i0_dir1_syst_out),
	// the outputs are shared
	i0_syst_data_out,
	`rdyack_port(i1_dir0_syst_in),
	i1_dir0_syst_data_in,
	`rdyack_port(i1_dir1_syst_in),
	i1_dir1_syst_data_in,
	`rdyack_port(i1_dir0_syst_out),
	`rdyack_port(i1_dir1_syst_out),
	// the outputs are shared
	i1_syst_data_out
`endif
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
`ifdef SD
localparam N_TAU_X = TauCfg::N_TAU_X;
localparam N_TAU_Y = TauCfg::N_TAU_Y;
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
`ifdef SD
localparam CN_TAU_X = $clog2(N_TAU_X);
localparam CN_TAU_Y = $clog2(N_TAU_Y);
localparam CN_TAU_X1 = $clog2(N_TAU_X+1);
localparam CN_TAU_Y1 = $clog2(N_TAU_Y+1);
`endif

//======================================
// I/O
//======================================
`clk_input;
`rdyack_input(bofs);
input [WBW-1:0]     i_bofs           [VDIM];
`ifdef SD
input [CN_TAU_X1-1:0] i_i0_systolic_gsize;
input [CN_TAU_Y -1:0] i_i0_systolic_idx;
input [CN_TAU_X1-1:0] i_i1_systolic_gsize;
input [CN_TAU_Y -1:0] i_i1_systolic_idx;
`endif
input [WBW-1:0]     i_bboundary      [VDIM];
input [CV_BW-1:0]   i_bsubofs [VSIZE][VDIM];
input [CCV_BW-1:0]  i_bsub_up_order  [VDIM];
input [CCV_BW-1:0]  i_bsub_lo_order  [VDIM];
input [WBW-1:0]     i_agrid_step     [VDIM];
input [WBW-1:0]     i_bgrid_step     [VDIM];
input [WBW-1:0]     i_agrid_end      [VDIM];
input [WBW-1:0]     i_aboundary      [VDIM];
input [XOR_BW-1:0]  i_i0_local_xor_srcs     [N_ICFG][CV_BW];
input [CCV_BW-1:0]  i_i0_local_xor_swaps    [N_ICFG];
input [LBW0  :0]    i_i0_local_boundaries   [N_ICFG][DIM];
input [LBW0-1:0]    i_i0_local_bsubsteps    [N_ICFG][CV_BW];
input [CV_BW-1:0]   i_i0_local_pads         [N_ICFG][DIM];
input [WBW-1:0]     i_i0_global_starts      [N_ICFG][DIM];
input [GBW-1:0]     i_i0_global_linears     [N_ICFG];
input [GBW-1:0]     i_i0_global_cboundaries [N_ICFG][DIM];
input [GBW-1:0]     i_i0_global_boundaries  [N_ICFG][DIM];
input [DIM_BW-1:0]  i_i0_global_bshufs      [N_ICFG][VDIM];
input [SF_BW-1:0]   i_i0_bstrides_frac      [N_ICFG][VDIM];
input [SS_BW-1:0]   i_i0_bstrides_shamt     [N_ICFG][VDIM];
input [DIM_BW-1:0]  i_i0_global_ashufs      [N_ICFG][VDIM];
input [SF_BW-1:0]   i_i0_astrides_frac      [N_ICFG][VDIM];
input [SS_BW-1:0]   i_i0_astrides_shamt     [N_ICFG][VDIM];
input [N_ICFG-1:0]  i_i0_wrap;
input [DBW-1:0]     i_i0_pad_value [N_ICFG];
input [ICFG_BW-1:0] i_i0_id_begs [VDIM+1];
input [ICFG_BW-1:0] i_i0_id_ends [VDIM+1];
input               i_i0_stencil;
input [ST_BW-1:0]   i_i0_stencil_begs [N_ICFG];
input [ST_BW-1:0]   i_i0_stencil_ends [N_ICFG];
input [LBW0-1:0]    i_i0_stencil_lut [STSIZE];
`ifdef SD
input [N_ICFG-1:0]  i_i0_systolic_skip;
`endif
input [XOR_BW-1:0]  i_i1_local_xor_srcs     [N_ICFG][CV_BW];
input [CCV_BW-1:0]  i_i1_local_xor_swaps    [N_ICFG];
input [LBW1  :0]    i_i1_local_boundaries   [N_ICFG][DIM];
input [LBW1-1:0]    i_i1_local_bsubsteps    [N_ICFG][CV_BW];
input [CV_BW-1:0]   i_i1_local_pads         [N_ICFG][DIM];
input [WBW-1:0]     i_i1_global_starts      [N_ICFG][DIM];
input [GBW-1:0]     i_i1_global_linears     [N_ICFG];
input [GBW-1:0]     i_i1_global_cboundaries [N_ICFG][DIM];
input [GBW-1:0]     i_i1_global_boundaries  [N_ICFG][DIM];
input [DIM_BW-1:0]  i_i1_global_bshufs      [N_ICFG][VDIM];
input [SF_BW-1:0]   i_i1_bstrides_frac      [N_ICFG][VDIM];
input [SS_BW-1:0]   i_i1_bstrides_shamt     [N_ICFG][VDIM];
input [DIM_BW-1:0]  i_i1_global_ashufs      [N_ICFG][VDIM];
input [SF_BW-1:0]   i_i1_astrides_frac      [N_ICFG][VDIM];
input [SS_BW-1:0]   i_i1_astrides_shamt     [N_ICFG][VDIM];
input [N_ICFG-1:0]  i_i1_wrap;
input [DBW-1:0]     i_i1_pad_value [N_ICFG];
input [ICFG_BW-1:0] i_i1_id_begs [VDIM+1];
input [ICFG_BW-1:0] i_i1_id_ends [VDIM+1];
input               i_i1_stencil;
input [ST_BW-1:0]   i_i1_stencil_begs [N_ICFG];
input [ST_BW-1:0]   i_i1_stencil_ends [N_ICFG];
input [LBW1-1:0]    i_i1_stencil_lut [STSIZE];
`ifdef SD
input [N_ICFG-1:0]  i_i1_systolic_skip;
`endif
input [GBW-1:0]     i_o_global_boundaries [N_OCFG][DIM];
input [GBW-1:0]     i_o_global_bsubsteps  [N_OCFG][CV_BW];
input [GBW-1:0]     i_o_global_linears    [N_OCFG];
input [DIM_BW-1:0]  i_o_global_bshufs     [N_OCFG][VDIM];
input [SF_BW-1:0]   i_o_bstrides_frac     [N_OCFG][VDIM];
input [SS_BW-1:0]   i_o_bstrides_shamt    [N_OCFG][VDIM];
input [DIM_BW-1:0]  i_o_global_ashufs     [N_OCFG][VDIM];
input [SF_BW-1:0]   i_o_astrides_frac     [N_OCFG][VDIM];
input [SS_BW-1:0]   i_o_astrides_shamt    [N_OCFG][VDIM];
input [OCFG_BW-1:0] i_o_id_begs [VDIM+1];
input [OCFG_BW-1:0] i_o_id_ends [VDIM+1];
input [INST_BW-1:0] i_inst_id_begs [VDIM+1];
input [INST_BW-1:0] i_inst_id_ends [VDIM+1];
input [ISA_BW-1:0]  i_insts [N_INST];
input [TDBW-1:0]    i_consts [CONST_LUT];
input [TDBW-1:0]    i_const_texs [CONST_TEX_LUT];
input [REG_ABW-1:0] i_reg_per_warp;
`dval_output(blkdone);
`rdyack_output(dramra);
output [GBW-1:0] o_dramra;
`rdyack_input(dramrd);
input [DBW-1:0] i_dramrd [CSIZE];
`rdyack_output(dramw);
output [GBW-1:0]   o_dramwa;
output [DBW-1:0]   o_dramwd [CSIZE];
output [CSIZE-1:0] o_dramw_mask;
`ifdef SD
`rdyack_input(i0_dir0_syst_in);
input [DBW-1:0] i0_dir0_syst_data_in [VSIZE];
`rdyack_input(i0_dir1_syst_in);
input [DBW-1:0] i0_dir1_syst_data_in [VSIZE];
`rdyack_output(i0_dir0_syst_out);
`rdyack_output(i0_dir1_syst_out);
output logic [DBW-1:0] i0_syst_data_out     [VSIZE];
`rdyack_input(i1_dir0_syst_in);
input [DBW-1:0] i1_dir0_syst_data_in [VSIZE];
`rdyack_input(i1_dir1_syst_in);
input [DBW-1:0] i1_dir1_syst_data_in [VSIZE];
`rdyack_output(i1_dir0_syst_out);
`rdyack_output(i1_dir1_syst_out);
output logic [DBW-1:0] i1_syst_data_out     [VSIZE];
`endif

//======================================
// Internal
//======================================
`rdyack_logic(bofs_in);
logic [WBW-1:0] bofs_in_r [VDIM];
`rdyack_logic(abl_alu_abofs);
logic [WBW-1:0] abl_alu_bofs [VDIM];
logic [WBW-1:0] abl_alu_aofs [VDIM];
logic [WBW-1:0] abl_alu_aend [VDIM];
`rdyack_logic(abl_i0_abofs);
logic [WBW-1:0]     abl_i0_bofs [VDIM];
logic [WBW-1:0]     abl_i0_aofs [VDIM];
logic [WBW-1:0]     abl_i0_aend [VDIM];
logic [ICFG_BW-1:0] abl_i0_beg;
logic [ICFG_BW-1:0] abl_i0_end;
`rdyack_logic(abl_i1_abofs);
logic [WBW-1:0]     abl_i1_bofs [VDIM];
logic [WBW-1:0]     abl_i1_aofs [VDIM];
logic [WBW-1:0]     abl_i1_aend [VDIM];
logic [ICFG_BW-1:0] abl_i1_beg;
logic [ICFG_BW-1:0] abl_i1_end;
`rdyack_logic(abl_dma_abofs);
logic               abl_dma_which;
logic [WBW-1:0]     abl_dma_bofs [VDIM];
logic [WBW-1:0]     abl_dma_aofs [VDIM];
logic [ICFG_BW-1:0] abl_dma_beg;
logic [ICFG_BW-1:0] abl_dma_end;
`rdyack_logic(abl_o_abofs);
logic [WBW-1:0]     abl_o_bofs [VDIM];
logic [WBW-1:0]     abl_o_aofs [VDIM];
logic [WBW-1:0]     abl_o_aend [VDIM];
logic [OCFG_BW-1:0] abl_o_beg;
logic [OCFG_BW-1:0] abl_o_end;
`rdyack_logic(i0_alu_sramrd);
logic [DBW-1:0] i0_alu_sramrd [VSIZE];
`rdyack_logic(i1_alu_sramrd);
logic [DBW-1:0] i1_alu_sramrd [VSIZE];
`rdyack_logic(alu_write_dat_alu);
logic [DBW-1:0] alu_write_dat_alu [VSIZE];
`rdyack_logic(alu_write_dat_wp);
logic [DBW-1:0] alu_write_dat_wp [VSIZE];
`rdyack_logic(i0_dramra);
logic [GBW-1:0] i0_dramra;
`rdyack_logic(i0_dramrd);
logic [DBW-1:0] i0_dramrd [CSIZE];
`rdyack_logic(i1_dramra);
logic [GBW-1:0] i1_dramra;
`rdyack_logic(i1_dramrd);
logic [DBW-1:0] i1_dramrd [CSIZE];
`ifdef SD
`rdyack_logic(i0_alu_sramrd2);
`rdyack_logic(i1_alu_sramrd2);
logic [STO_BW-1:0] abl_i0_syst_type;
logic [STO_BW-1:0] abl_i1_syst_type;
logic [STO_BW-1:0] abl_dma_syst_type;
logic [STO_BW-1:0] i0_alu_syst_type;
logic [STO_BW-1:0] i1_alu_syst_type;
`endif

//======================================
// Submodule
//======================================
Forward u_fwd(
	`clk_connect,
	`rdyack_connect(src, bofs),
	`rdyack_connect(dst, bofs_in)
);
Forward u_alu_wp_data(
	`clk_connect,
	`rdyack_connect(src, alu_write_dat_alu),
	`rdyack_connect(dst, alu_write_dat_wp)
);
`ifdef SD
SystolicSwitch u_systs0(
	`clk_connect,
	`rdyack_connect(from_rp, i0_alu_sramrd),
	.i_syst_type(i0_alu_syst_type),
	.rp_data(i0_alu_sramrd),
	`rdyack_connect(src0, i0_dir0_syst_in),
	.s0_data(i0_dir0_syst_data_in),
	`rdyack_connect(src1, i0_dir1_syst_in),
	.s1_data(i0_dir1_syst_data_in),
	`rdyack_connect(dst0, i0_dir0_syst_out),
	`rdyack_connect(dst1, i0_dir1_syst_out),
	`rdyack_connect(to_alu, i0_alu_sramrd2),
	.o_data(i0_syst_data_out)
);
SystolicSwitch u_systs1(
	`clk_connect,
	`rdyack_connect(from_rp, i1_alu_sramrd),
	.i_syst_type(i1_alu_syst_type),
	.rp_data(i1_alu_sramrd),
	`rdyack_connect(src0, i1_dir0_syst_in),
	.s0_data(i1_dir0_syst_data_in),
	`rdyack_connect(src1, i1_dir1_syst_in),
	.s1_data(i1_dir1_syst_data_in),
	`rdyack_connect(dst0, i1_dir0_syst_out),
	`rdyack_connect(dst1, i1_dir1_syst_out),
	`rdyack_connect(to_alu, i1_alu_sramrd2),
	.o_data(i1_syst_data_out)
);
`endif
AccumBlockLooper u_abl(
	`clk_connect,
	`rdyack_connect(src, bofs_in),
	.i_bofs(bofs_in_r),
`ifdef SD
	.i_i0_systolic_gsize(i_i0_systolic_gsize),
	.i_i0_systolic_idx(i_i0_systolic_idx),
	.i_i1_systolic_gsize(i_i1_systolic_gsize),
	.i_i1_systolic_idx(i_i1_systolic_idx),
`endif
	.i_agrid_step(i_agrid_step),
	.i_agrid_end(i_agrid_end),
	.i_aboundary(i_aboundary),
	.i_i0_id_begs(i_i0_id_begs),
	.i_i0_id_ends(i_i0_id_ends),
	.i_i1_id_begs(i_i1_id_begs),
	.i_i1_id_ends(i_i1_id_ends),
	.i_o_id_begs(i_o_id_begs),
	.i_o_id_ends(i_o_id_ends),
	.i_inst_id_begs(i_inst_id_begs),
	.i_inst_id_ends(i_inst_id_ends),
	`rdyack_connect(i0_abofs, abl_i0_abofs),
	.o_i0_bofs(abl_i0_bofs),
	.o_i0_aofs_beg(abl_i0_aofs),
	.o_i0_aofs_end(abl_i0_aend),
	.o_i0_beg(abl_i0_beg),
	.o_i0_end(abl_i0_end),
`ifdef SD
	.o_i0_syst_type(abl_i0_syst_type),
`endif
	`rdyack_connect(i1_abofs, abl_i1_abofs),
	.o_i1_bofs(abl_i1_bofs),
	.o_i1_aofs_beg(abl_i1_aofs),
	.o_i1_aofs_end(abl_i1_aend),
	.o_i1_beg(abl_i1_beg),
	.o_i1_end(abl_i1_end),
`ifdef SD
	.o_i1_syst_type(abl_i1_syst_type),
`endif
	`rdyack_connect(dma_abofs, abl_dma_abofs),
`endif
	.o_dma_which(abl_dma_which),
	.o_dma_bofs(abl_dma_bofs),
	.o_dma_aofs(abl_dma_aofs),
	.o_dma_beg(abl_dma_beg),
	.o_dma_end(abl_dma_end),
`ifdef SD
	.o_dma_syst_type(abl_dma_syst_type),
`endif
	`rdyack_connect(o_abofs, abl_o_abofs),
	.o_o_bofs(abl_o_bofs),
	.o_o_aofs_beg(abl_o_aofs),
	.o_o_aofs_end(abl_o_aend),
	.o_o_beg(abl_o_beg),
	.o_o_end(abl_o_end),
	`rdyack_connect(alu_abofs, abl_alu_abofs),
	.o_alu_bofs(abl_alu_bofs),
	.o_alu_aofs_beg(abl_alu_aofs),
	.o_alu_aofs_end(abl_alu_aend),
	`dval_connect(blkdone, blkdone)
);
AluPipeline u_alu(
	`clk_connect,
	`rdyack_connect(abofs, abl_alu_abofs),
	.i_bofs(abl_alu_bofs),
	.i_aofs_beg(abl_alu_aofs),
	.i_aofs_end(abl_alu_aend),
	.i_bgrid_step(i_bgrid_step),
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
`ifdef SD
	`rdyack_connect(sramrd0, i0_alu_sramrd2),
	.i_sramrd0(i0_syst_data_out),
	`rdyack_connect(sramrd1, i1_alu_sramrd2),
	.i_sramrd1(i1_syst_data_out),
`else
	`rdyack_connect(sramrd0, i0_alu_sramrd),
	.i_sramrd0(i0_alu_sramrd),
	`rdyack_connect(sramrd1, i1_alu_sramrd),
	.i_sramrd1(i1_alu_sramrd),
`endif
	`rdyack_connect(dramwd, alu_write_dat_alu),
	.o_dramwd(alu_write_dat_alu)
);
WritePipeline u_w(
	`clk_connect,
	`rdyack_connect(bofs, abl_o_abofs),
	.i_bofs(abl_o_bofs),
	.i_abeg(abl_o_aofs),
	.i_aend(abl_o_aend),
	.i_bboundary(i_bboundary),
	.i_bsubofs(i_bsubofs),
	.i_bsub_up_order(i_bsub_up_order),
	.i_bsub_lo_order(i_bsub_lo_order),
	.i_aboundary(i_aboundary),
	.i_mboundaries(i_o_global_boundaries),
	.i_mofs_bsubsteps(i_o_global_bsubsteps),
	.i_global_linears(i_o_global_linears),
	.i_bgrid_step(i_bgrid_step),
	.i_global_bshufs(i_o_global_bshufs),
	.i_bstrides_frac(i_o_bstrides_frac),
	.i_bstrides_shamt(i_o_bstrides_shamt),
	.i_global_ashufs(i_o_global_ashufs),
	.i_astrides_frac(i_o_astrides_frac),
	.i_astrides_shamt(i_o_astrides_shamt),
	.i_id_begs(i_o_id_begs),
	.i_id_ends(i_o_id_ends),
	`rdyack_connect(alu_dat, alu_write_dat_wp),
	.i_alu_dat(alu_write_dat_wp),
	`rdyack_connect(dramw, dramw),
	.o_dramwa(o_dramwa),
	.o_dramwd(o_dramwd),
	.o_dramw_mask(o_dramw_mask)
);
ReadPipeline#(.LBW(LBW0)) u_r0(
	`clk_connect,
	`rdyack_connect(bofs, abl_i0_abofs),
	.i_bofs(abl_i0_bofs),
	.i_abeg(abl_i0_aofs),
	.i_aend(abl_i0_aend),
	.i_beg(abl_i0_beg),
	.i_end(abl_i0_end),
`ifdef SD
	.i_syst_type(abl_i0_syst_type),
`endif
	.i_bsub_up_order(i_bsub_up_order),
	.i_bsub_lo_order(i_bsub_lo_order),
	.i_aboundary(i_aboundary),
	.i_bgrid_step(i_bgrid_step),
	.i_global_linears(i_i0_global_linears),
	.i_global_mofs(i_i0_global_starts),
	.i_global_mboundaries(i_i0_global_boundaries),
	.i_global_cboundaries(i_i0_global_cboundaries),
	.i_global_bshufs(i_i0_global_bshufs),
	.i_bstrides_frac(i_i0_bstrides_frac),
	.i_bstrides_shamt(i_i0_bstrides_shamt),
	.i_global_ashufs(i_i0_global_ashufs),
	.i_astrides_frac(i_i0_astrides_frac),
	.i_astrides_shamt(i_i0_astrides_shamt),
	.i_local_xor_srcs(i_i0_local_xor_srcs),
	.i_local_xor_swaps(i_i0_local_xor_swaps),
	.i_local_pads(i_i0_local_pads),
	.i_local_bsubsteps(i_i0_local_bsubsteps),
	.i_local_mboundaries(i_i0_local_boundaries),
	.i_wrap(i_i0_wrap),
	.i_pad_value(i_i0_pad_value),
	.i_id_begs(i_i0_id_begs),
	.i_id_ends(i_i0_id_ends),
	.i_stencil(i_i0_stencil),
	.i_stencil_begs(i_i0_stencil_begs),
	.i_stencil_ends(i_i0_stencil_ends),
	.i_stencil_lut(i_i0_stencil_lut),
`ifdef SD
	.i_systolic_skip(i_i0_systolic_skip),
`endif
	`dval_connect(blkdone, blkdone),
	`dval_connect(rp_en, rp_dma_en0),
	`dval_connect(rmc_write, dma_rmc_write0),
	.i_rmc_whiaddr(dma_rmc_whiaddr0),
	.i_rmc_wdata(dma_rmc_wdata),
	`rdyack_connect(sramrd, i0_alu_sramrd),
`ifdef SD
	.o_syst_type(i0_alu_syst_type),
`endif
	.o_sramrd(i0_alu_sramrd)
);
ReadPipeline#(.LBW(LBW1)) u_r1(
	`clk_connect,
	`rdyack_connect(bofs, abl_i1_abofs),
	.i_bofs(abl_i1_bofs),
	.i_abeg(abl_i1_aofs),
	.i_aend(abl_i1_aend),
	.i_beg(abl_i1_beg),
	.i_end(abl_i1_end),
`ifdef SD
	.i_syst_type(abl_i1_syst_type),
`endif
	.i_bsub_up_order(i_bsub_up_order),
	.i_bsub_lo_order(i_bsub_lo_order),
	.i_aboundary(i_aboundary),
	.i_bgrid_step(i_bgrid_step),
	.i_global_linears(i_i1_global_linears),
	.i_global_mofs(i_i1_global_starts),
	.i_global_mboundaries(i_i1_global_boundaries),
	.i_global_cboundaries(i_i1_global_cboundaries),
	.i_global_bshufs(i_i1_global_bshufs),
	.i_bstrides_frac(i_i1_bstrides_frac),
	.i_bstrides_shamt(i_i1_bstrides_shamt),
	.i_global_ashufs(i_i1_global_ashufs),
	.i_astrides_frac(i_i1_astrides_frac),
	.i_astrides_shamt(i_i1_astrides_shamt),
	.i_local_xor_srcs(i_i1_local_xor_srcs),
	.i_local_xor_swaps(i_i1_local_xor_swaps),
	.i_local_pads(i_i1_local_pads),
	.i_local_bsubsteps(i_i1_local_bsubsteps),
	.i_local_mboundaries(i_i1_local_boundaries),
	.i_wrap(i_i1_wrap),
	.i_pad_value(i_i1_pad_value),
	.i_id_begs(i_i1_id_begs),
	.i_id_ends(i_i1_id_ends),
	.i_stencil(i_i1_stencil),
	.i_stencil_begs(i_i1_stencil_begs),
	.i_stencil_ends(i_i1_stencil_ends),
	.i_stencil_lut(i_i1_stencil_lut),
`ifdef SD
	.i_systolic_skip(i_i1_systolic_skip),
`endif
	`dval_connect(blkdone, blkdone),
	`dval_connect(rp_en, rp_dma_en1),
	`dval_connect(rmc_write, dma_rmc_write1),
	.i_rmc_whiaddr(dma_rmc_whiaddr1),
	.i_rmc_wdata(dma_rmc_wdata),
	`rdyack_connect(sramrd, i1_alu_sramrd),
`ifdef SD
	.o_syst_type(i1_alu_syst_type),
`endif
	.o_sramrd(i1_alu_sramrd)
);
DmaPipeline u_dma(
	`clk_connect,
	`rdyack_connect(bofs),
	.i_which(abl_dma_which),
	.i_bofs(abl_dma_bofs),
	.i_abeg(abl_dma_abeg),
	.i_beg(abl_dma_beg),
	.i_end(abl_dma_end),
`ifdef SD
	.i_syst_type(abl_syst_type),
`endif
	.i_i0_global_linears(i_i0_global_linears),
	.i_i0_global_mofs(i_i0_global_starts),
	.i_i0_global_mboundaries(i_i0_global_boundaries),
	.i_i0_global_cboundaries(i_i0_global_cboundaries),
	.i_i0_global_bshufs(i_i0_global_bshufs),
	.i_i0_bstrides_frac(i_i0_bstrides_frac),
	.i_i0_bstrides_shamt(i_i0_bstrides_shamt),
	.i_i0_global_ashufs(i_i0_global_ashufs),
	.i_i0_astrides_frac(i_i0_astrides_frac),
	.i_i0_astrides_shamti_i0_astrides_shamt),
	.i_i0_local_xor_srcs(i_i0_local_xor_srcs),
	.i_i0_local_xor_swaps(i_i0_local_xor_swaps),
	.i_i0_local_pads(i_i0_local_pads),
	.i_i0_local_mboundaries(i_i0_local_boundaries),
	.i_i0_wraps(i_i0_wrap),
	.i_i0_pad_values(i_i0_pad_value),
`ifdef SD
	.i_i0_systolic_skip(i_i0_systolic_skip),
`endif
	.i_i1_global_linears(i_i1_global_linears),
	.i_i1_global_mofs(i_i1_global_starts),
	.i_i1_global_mboundaries(i_i1_global_boundaries),
	.i_i1_global_cboundaries(i_i1_global_cboundaries),
	.i_i1_global_bshufs(i_i1_global_bshufs),
	.i_i1_bstrides_frac(i_i1_bstrides_frac),
	.i_i1_bstrides_shamt(i_i1_bstrides_shamt),
	.i_i1_global_ashufs(i_i1_global_ashufs),
	.i_i1_astrides_frac(i_i1_astrides_frac),
	.i_i1_astrides_shamti_i1_astrides_shamt),
	.i_i1_local_xor_srcs(i_i1_local_xor_srcs),
	.i_i1_local_xor_swaps(i_i1_local_xor_swaps),
	.i_i1_local_pads(i_i1_local_pads),
	.i_i1_local_mboundaries(i_i1_local_boundaries),
	.i_i1_wraps(i_i1_wrap),
	.i_i1_pad_values(i_i1_pad_value),
`ifdef SD
	.i_i1_systolic_skip(i_i1_systolic_skip),
`endif
	`rdyack_connect(rp_en0, rp_dma_en0),
	`rdyack_connect(rp_en1, rp_dma_en1),
	`dval_connect(rmc_write0, dma_rmc_write0),
	`dval_connect(rmc_write1, dma_rmc_write1),
	.o_rmc_whiaddr0(dma_rmc_whiaddr0),
	.o_rmc_whiaddr1(dma_rmc_whiaddr1),
	.o_rmc_wdata(dma_rmc_wdata),
	`rdyack_connect(dramra, dramra),
	.o_dramra(o_dramra),
	`rdyack_connect(dramrd, dramrd),
	.i_dramrd(i_dramrd)
);

//======================================
// Sequential
//======================================
`ff_rst
	for (int i = 0; i < VDIM; i++) begin
		bofs_in_r[i] <= '0;
	end
`ff_cg(bofs_ack)
	bofs_in_r <= i_bofs;
`ff_end

`ff_rst
	for (int i = 0; i < VSIZE; i++) begin
		alu_write_dat_wp[i] <= '0;
	end
`ff_cg(alu_write_dat_alu_ack)
	alu_write_dat_wp <= alu_write_dat_alu;
`ff_end

endmodule
