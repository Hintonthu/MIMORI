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

module WritePipeline(
	`clk_port,
	`rdyack_port(bofs),
	i_bofs,
	i_aofs,
	i_alast,
	i_bboundary,
	i_bsubofs,
	i_bsub_up_order,
	i_bsub_lo_order,
	i_aboundary,
	i_global_boundaries,
	i_global_bsubsteps,
	i_global_linears,
	i_bstrides_frac,
	i_bstrides_shamt,
	i_astrides_frac,
	i_astrides_shamt,
	i_id_begs,
	i_id_ends,
	`rdyack_port(alu_dat),
	i_alu_dat,
	`dval_port(blkdone),
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
localparam N_OCFG = TauCfg::N_OCFG;
localparam AF_BW = TauCfg::AOFS_FRAC_BW;
localparam AS_BW = TauCfg::AOFS_SHAMT_BW;
localparam VSIZE = TauCfg::VECTOR_SIZE;
localparam CSIZE = TauCfg::CACHE_SIZE;
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
input [GBW-1:0]     i_mofs_starts    [N_OCFG][1];
input [GBW-1:0]     i_mofs_bsteps    [N_OCFG][DIM];
input [GBW-1:0]     i_mofs_bsubsteps [N_OCFG][CV_BW];
input [GBW-1:0]     i_mofs_asteps    [N_OCFG][DIM];
input [OCFG_BW-1:0] i_id_begs [DIM+1];
input [OCFG_BW-1:0] i_id_ends [DIM+1];
`rdyack_input(alu_dat);
input [DBW-1:0] i_alu_dat [VSIZE];
`dval_input(blkdone);
`rdyack_output(dramw);
output [GBW-1:0]   o_dramwa;
output [DBW-1:0]   o_dramwd [CSIZE];
output [CSIZE-1:0] o_dramw_mask;

//======================================
// Internal
//======================================
`rdyack_logic(al_src);
`rdyack_logic(wait_fin);
`rdyack_logic(acc_warp_abofs);
logic [WBW-1:0]     acc_warp_bofs  [DIM];
logic [WBW-1:0]     acc_warp_aofs  [DIM];
logic [WBW-1:0]     acc_warp_alast [DIM];
`rdyack_logic(acc_warp_mofs);
logic [GBW-1:0]     acc_warp_mofs [1];
logic [OCFG_BW-1:0] acc_warp_id;
`rdyack_logic(warp_write_addrval);
logic [GBW-1:0]   warp_write_addr [VSIZE];
logic [VSIZE-1:0] warp_write_valid;

//======================================
// Combinational
//======================================
assign wait_fin_ack = blkdone_dval;

//======================================
// Submodule
//======================================
Broadcast#(2) u_broadcast_accum(
	`clk_connect,
	`rdyack_connect(src, bofs),
	.acked(),
	.dst_rdys({wait_fin_rdy,al_src_rdy}),
	.dst_acks({wait_fin_ack,al_src_ack})
);
WarpLooper #(.N_CFG(N_OCFG), .ABW(GBW), .STENCIL(0)) u_awl(
	`clk_connect,
	`rdyack_connect(abofs, acc_warp_abofs),
	.i_bofs(acc_warp_bofs),
	.i_aofs(acc_warp_aofs),
	.i_alast(acc_warp_alast),
	.i_bboundary(i_bboundary),
	.i_blocal_last(i_blocal_last),
	.i_bsubofs(i_bsubofs),
	.i_bsub_up_order(i_bsub_up_order),
	.i_bsub_lo_order(i_bsub_lo_order),
	.i_aboundary(i_aboundary),
	.i_mofs_bsteps(i_mofs_bsteps),
	.i_mofs_bsubsteps(i_mofs_bsubsteps),
	.i_mofs_asteps(i_mofs_asteps),
	.i_id_begs(i_id_begs),
	.i_id_ends(i_id_ends),
	.i_stencil(),
	.i_stencil_begs(),
	.i_stencil_ends(),
	.i_stencil_lut(),
	`rdyack_connect(mofs, acc_warp_mofs),
	.i_mofs(acc_warp_mofs[0]), // [0] for unpacked array of size 1
	.i_id(acc_warp_id),
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
