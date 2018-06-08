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

`include "common/define.sv"
`include "TileAccumUnit/common/AccumWarpLooper/AccumWarpLooper.sv"
`include "TileAccumUnit/WritePipeline/DramWriteCollector/DramWriteCollector.sv"

module WritePipeline(
	`clk_port,
	`rdyack_port(bofs),
	i_bofs,
	i_abeg,
	i_aend,
	i_bboundary,
	i_bsubofs,
	i_bsub_up_order,
	i_bsub_lo_order,
	i_aboundary,
	i_mboundaries,
	i_mofs_bsubsteps,
	i_global_linears,
	i_bgrid_step,
	i_global_bshufs,
	i_bstrides_frac,
	i_bstrides_shamt,
	i_global_ashufs,
	i_astrides_frac,
	i_astrides_shamt,
	i_id_begs,
	i_id_ends,
	`rdyack_port(alu_dat),
	i_alu_dat,
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
localparam DBW = TauCfg::DATA_BW;
localparam DIM = TauCfg::DIM;
localparam VDIM = TauCfg::VDIM;
localparam N_OCFG = TauCfg::N_OCFG;
localparam VSIZE = TauCfg::VSIZE;
localparam CSIZE = TauCfg::CACHE_SIZE;
localparam SS_BW = TauCfg::STRIDE_BW;
localparam SF_BW = TauCfg::STRIDE_FRAC_BW;
// derived
localparam OCFG_BW = $clog2(N_OCFG+1);
localparam DIM_BW = $clog2(DIM);
localparam CV_BW = $clog2(VSIZE);
localparam CCV_BW = $clog2(CV_BW+1);

//======================================
// I/O
//======================================
`clk_input;
`rdyack_input(bofs);
input [WBW-1:0]     i_bofs [VDIM];
input [WBW-1:0]     i_abeg [VDIM];
input [WBW-1:0]     i_aend [VDIM];
input [WBW-1:0]     i_bboundary      [VDIM];
input [CV_BW-1:0]   i_bsubofs [VSIZE][VDIM];
input [CCV_BW-1:0]  i_bsub_up_order  [VDIM];
input [CCV_BW-1:0]  i_bsub_lo_order  [VDIM];
input [WBW-1:0]     i_aboundary      [VDIM];
input [GBW-1:0]     i_mboundaries    [N_OCFG][DIM];
input [GBW-1:0]     i_mofs_bsubsteps [N_OCFG][CV_BW];
input [GBW-1:0]     i_global_linears [N_OCFG];
input [WBW-1:0]     i_bgrid_step     [VDIM];
input [DIM_BW-1:0]  i_global_bshufs  [N_OCFG][VDIM];
input [SF_BW-1:0]   i_bstrides_frac  [N_OCFG][VDIM];
input [SS_BW-1:0]   i_bstrides_shamt [N_OCFG][VDIM];
input [DIM_BW-1:0]  i_global_ashufs  [N_OCFG][VDIM];
input [SF_BW-1:0]   i_astrides_frac  [N_OCFG][VDIM];
input [SS_BW-1:0]   i_astrides_shamt [N_OCFG][VDIM];
input [OCFG_BW-1:0] i_id_begs [VDIM+1];
input [OCFG_BW-1:0] i_id_ends [VDIM+1];
`rdyack_input(alu_dat);
input [DBW-1:0] i_alu_dat [VSIZE];
`rdyack_output(dramw);
output [GBW-1:0]   o_dramwa;
output [DBW-1:0]   o_dramwd [CSIZE];
output [CSIZE-1:0] o_dramw_mask;

//======================================
// Internal
//======================================
`rdyack_logic(warp_write_addrval);
logic [GBW-1:0]   warp_write_addr [VSIZE];
logic [VSIZE-1:0] warp_write_valid;

//======================================
// Submodule
//======================================
AccumWarpLooper#(.N_CFG(N_OCFG), .ABW(GBW), .STENCIL(0), .USE_LOFS(0)) u_awl(
	`clk_connect,
	`rdyack_connect(abofs, bofs),
	.i_bofs(i_bofs),
	.i_abeg(i_abeg),
	.i_aend(i_aend),
`ifdef SD
	.i_syst_type(),
`endif
	.i_linears(i_global_linears),
	.i_bboundary(i_bboundary),
	.i_bsubofs(i_bsubofs),
	.i_bsub_up_order(i_bsub_up_order),
	.i_bsub_lo_order(i_bsub_lo_order),
	.i_aboundary(i_aboundary),
	.i_bgrid_step(i_bgrid_step),
	.i_global_bshufs(i_global_bshufs),
	.i_bstrides_frac(i_bstrides_frac),
	.i_bstrides_shamt(i_bstrides_shamt),
	.i_global_ashufs(i_global_ashufs),
	.i_astrides_frac(i_astrides_frac),
	.i_astrides_shamt(i_astrides_shamt),
	.i_mofs_bsubsteps(i_mofs_bsubsteps),
	.i_mboundaries(i_mboundaries),
	.i_id_begs(i_id_begs),
	.i_id_ends(i_id_ends),
	// only for i_stencil == 1 & STENCIL is enabled
	.i_stencil(),
	.i_stencil_begs(),
	.i_stencil_ends(),
	.i_stencil_lut(),
`ifdef SD
	.i_systolic_skip(),
`endif
	`rdyack_connect(addrval, warp_write_addrval),
	.o_id(),
	.o_address(warp_write_addr),
	.o_valid(warp_write_valid),
	.o_retire()
);
DramWriteCollector u_dwc(
	`clk_connect,
	`rdyack_connect(addrval, warp_write_addrval),
	.i_address(warp_write_addr),
	.i_valid(warp_write_valid),
	`rdyack_connect(alu_dat, alu_dat),
	.i_alu_dat(i_alu_dat),
	`rdyack_connect(dramw, dramw),
	.o_dramwa(o_dramwa),
	.o_dramwd(o_dramwd),
	.o_dramw_mask(o_dramw_mask)
);

endmodule
