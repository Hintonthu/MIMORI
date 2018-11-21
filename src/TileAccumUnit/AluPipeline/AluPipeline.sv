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
`include "TileAccumUnit/AluPipeline/SimdDriver.sv"
`include "TileAccumUnit/AluPipeline/Simd/Simd.sv"

module AluPipeline(
	`clk_port,
	`rdyack_port(abofs),
	i_bofs,
	i_aofs_beg,
	i_aofs_end,
	i_bgrid_step,
	i_dual_axis,
	i_dual_order,
	i_bsubofs,
	i_bsub_up_order,
	i_bsub_lo_order,
	i_aboundary,
	i_inst_id_begs,
	i_inst_id_ends,
	i_insts,
	i_consts,
	i_const_texs,
	i_reg_per_warp,
	`rdyack_port(sramrd0),
	i_sramrd0,
	`rdyack_port(sramrd1),
	i_sramrd1,
	`rdyack_port(dramwd),
	o_dramwd
);

//======================================
// Parameter
//======================================
localparam WBW = TauCfg::WORK_BW;
localparam CW_BW = TauCfg::CW_BW;
localparam DBW = TauCfg::DATA_BW;
localparam TDBW = TauCfg::TMP_DATA_BW;
localparam DIM = TauCfg::DIM;
localparam VDIM = TauCfg::VDIM;
localparam VDIM_BW = TauCfg::VDIM_BW;
localparam N_INST = TauCfg::N_INST;
localparam ISA_BW = TauCfg::ISA_BW;
localparam VSIZE = TauCfg::VSIZE;
localparam MAX_WARP = TauCfg::MAX_WARP;
localparam REG_ADDR = TauCfg::WARP_REG_ADDR_SPACE;
localparam CONST_LUT = TauCfg::CONST_LUT;
localparam CONST_TEX_LUT = TauCfg::CONST_TEX_LUT;
// derived
localparam INST_BW = $clog2(N_INST+1);
localparam CV_BW = $clog2(VSIZE);
localparam CCV_BW = $clog2(CV_BW+1);
localparam WID_BW = $clog2(MAX_WARP);
localparam REG_ABW = $clog2(REG_ADDR);

//======================================
// I/O
//======================================
`clk_input;
`rdyack_input(abofs);
input [WBW-1:0]     i_bofs     [VDIM];
input [WBW-1:0]     i_aofs_beg [VDIM];
input [WBW-1:0]     i_aofs_end [VDIM];
input [WBW-1:0]     i_bgrid_step     [VDIM];
input [VDIM_BW-1:0] i_dual_axis;
input [CW_BW-1:0]   i_dual_order;
input [CV_BW-1:0]   i_bsubofs [VSIZE][VDIM];
input [CCV_BW-1:0]  i_bsub_up_order  [VDIM];
input [CCV_BW-1:0]  i_bsub_lo_order  [VDIM];
input [WBW-1:0]     i_aboundary      [VDIM];
input [INST_BW-1:0] i_inst_id_begs [VDIM+1];
input [INST_BW-1:0] i_inst_id_ends [VDIM+1];
input [ISA_BW-1:0]  i_insts [N_INST];
input [TDBW-1:0]    i_consts [CONST_LUT];
input [TDBW-1:0]    i_const_texs [CONST_TEX_LUT];
input [REG_ABW-1:0] i_reg_per_warp;
`rdyack_input(sramrd0);
input [DBW-1:0] i_sramrd0 [VSIZE];
`rdyack_input(sramrd1);
input [DBW-1:0] i_sramrd1 [VSIZE];
`rdyack_output(dramwd);
output [DBW-1:0] o_dramwd [VSIZE];

//======================================
// Internal
//======================================
`rdyack_logic(drv_simd_inst);
logic [WBW-1:0]     drv_simd_bofs [VDIM];
logic [WBW-1:0]     drv_simd_aofs [VDIM];
logic [INST_BW-1:0] drv_simd_pc;
logic [WID_BW-1:0]  drv_simd_wid;
`dval_logic(simd_drv_inst_commit);

//======================================
// Submodule
//======================================
SimdDriver u_simd_drv(
	`clk_connect,
	`rdyack_connect(abofs, abofs),
	.i_bofs(i_bofs),
	.i_aofs_beg(i_aofs_beg),
	.i_aofs_end(i_aofs_end),
	.i_bgrid_step(i_bgrid_step),
	.i_dual_axis(i_dual_axis),
	.i_dual_order(i_dual_order),
	.i_bsub_up_order(i_bsub_up_order),
	.i_bsub_lo_order(i_bsub_lo_order),
	.i_aboundary(i_aboundary),
	.i_inst_id_begs(i_inst_id_begs),
	.i_inst_id_ends(i_inst_id_ends),
	`rdyack_connect(inst, drv_simd_inst),
	.o_bofs(drv_simd_bofs),
	.o_aofs(drv_simd_aofs),
	.o_pc(drv_simd_pc),
	.o_warpid(drv_simd_wid),
	`dval_connect(inst_commit, simd_drv_inst_commit)
);
Simd u_simd(
	`clk_connect,
	`rdyack_connect(inst, drv_simd_inst),
	.i_insts(i_insts),
	.i_consts(i_consts),
	.i_const_texs(i_const_texs),
	.i_bofs(drv_simd_bofs),
	.i_bsubofs(i_bsubofs),
	.i_bsub_lo_order(i_bsub_lo_order),
	.i_aofs(drv_simd_aofs),
	.i_pc(drv_simd_pc),
	.i_wid(drv_simd_wid),
	.i_reg_per_warp(i_reg_per_warp),
	`rdyack_connect(sramrd0, sramrd0),
	.i_sramrd0(i_sramrd0),
	`rdyack_connect(sramrd1, sramrd1),
	.i_sramrd1(i_sramrd1),
	`rdyack_connect(dramwd, dramwd),
	.o_dramwd(o_dramwd),
	`dval_connect(inst_commit, simd_drv_inst_commit)
);

endmodule
