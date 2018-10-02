// Copyright
// Yu Sheng Lin, 2016-2018
// Yan Hsi Wang, 2017

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
`include "common/Controllers.sv"
`include "TileAccumUnit/common/AccumWarpLooper/AccumWarpLooper.sv"
`include "TileAccumUnit/ReadPipeline/Allocator.sv"
`include "TileAccumUnit/ReadPipeline/LinearCollector.sv"
`include "TileAccumUnit/ReadPipeline/RemapCache/RemapCache.sv"

module ReadPipeline(
	`clk_port,
	`rdyack_port(bofs),
	i_bofs,
	i_abeg,
	i_aend,
	i_beg,
	i_end,
`ifdef SD
	i_syst_type,
`endif
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
	i_local_xor_srcs,
	i_local_xor_swaps,
	i_local_bsubsteps,
	i_local_mboundaries,
	i_id_begs,
	i_id_ends,
	i_stencil,
	i_stencil_begs,
	i_stencil_ends,
	i_stencil_lut,
`ifdef SD
	i_systolic_skip,
`endif
	// Tell DMA something to work
	`rdyack_port(rp_en),
	// DMA write to SRAM
	`dval_port(dma_write),
	i_dma_whiaddr,
	i_dma_wdata,
	// To systolic switch and ALU
	`rdyack_port(sramrd),
`ifdef SD
	o_syst_type,
`endif
	o_sramrd
);

//======================================
// Parameter
//======================================
import TauCfg::*;
parameter  LBW = TauCfg::LOCAL_ADDR_BW0;
localparam WBW = TauCfg::WORK_BW;
localparam GBW = TauCfg::GLOBAL_ADDR_BW;
localparam DBW = TauCfg::DATA_BW;
localparam N_ICFG = TauCfg::N_ICFG;
localparam DIM = TauCfg::DIM;
localparam VDIM = TauCfg::VDIM;
localparam SS_BW = TauCfg::STRIDE_BW;
localparam SF_BW = TauCfg::STRIDE_FRAC_BW;
localparam VSIZE = TauCfg::VSIZE;
localparam CSIZE = TauCfg::CACHE_SIZE;
localparam XOR_BW = TauCfg::XOR_BW;
localparam ALLOC_CNT = 15;
localparam STSIZE = TauCfg::STENCIL_SIZE;
// derived
localparam ICFG_BW = $clog2(N_ICFG+1);
localparam CV_BW = $clog2(VSIZE);
localparam CC_BW = $clog2(CSIZE);
localparam CV_BW1 = $clog2(VSIZE+1);
localparam CCV_BW = $clog2(CV_BW+1);
localparam CX_BW = $clog2(XOR_BW);
localparam DIM_BW = $clog2(DIM);
localparam HBW = LBW-CV_BW;
localparam ST_BW = $clog2(STSIZE+1);

//======================================
// I/O
//======================================
`clk_input;
`rdyack_input(bofs);
input [WBW-1:0]     i_bofs           [VDIM];
input [WBW-1:0]     i_abeg           [VDIM];
input [WBW-1:0]     i_aend           [VDIM];
input [ICFG_BW-1:0] i_beg;
input [ICFG_BW-1:0] i_end;
`ifdef SD
input [STO_BW-1:0]  i_syst_type;
`endif
input [CCV_BW-1:0]  i_bsub_up_order  [VDIM];
input [CCV_BW-1:0]  i_bsub_lo_order  [VDIM];
input [WBW-1:0]     i_aboundary      [VDIM];
input [WBW-1:0]     i_bgrid_step     [VDIM];
input [DIM_BW-1:0]  i_global_bshufs      [N_ICFG][VDIM];
input [SF_BW-1:0]   i_bstrides_frac      [N_ICFG][VDIM];
input [SS_BW-1:0]   i_bstrides_shamt     [N_ICFG][VDIM];
input [DIM_BW-1:0]  i_global_ashufs      [N_ICFG][VDIM];
input [SF_BW-1:0]   i_astrides_frac      [N_ICFG][VDIM];
input [SS_BW-1:0]   i_astrides_shamt     [N_ICFG][VDIM];
input [XOR_BW-1:0]  i_local_xor_srcs     [N_ICFG][CV_BW];
input [CCV_BW-1:0]  i_local_xor_swaps    [N_ICFG];
input [LBW-1:0]     i_local_bsubsteps    [N_ICFG][CV_BW];
input [LBW  :0]     i_local_mboundaries  [N_ICFG][DIM];
input [ICFG_BW-1:0] i_id_begs [VDIM+1];
input [ICFG_BW-1:0] i_id_ends [VDIM+1];
input               i_stencil;
input [ST_BW-1:0]   i_stencil_begs [N_ICFG];
input [ST_BW-1:0]   i_stencil_ends [N_ICFG];
input [LBW-1:0]     i_stencil_lut [STSIZE];
`ifdef SD
input [N_ICFG-1:0]  i_systolic_skip;
`endif
`rdyack_output(rp_en);
`dval_input(dma_write);
input [LBW-CV_BW-1:0] i_dma_whiaddr;
input [DBW-1:0]       i_dma_wdata [VSIZE];
`rdyack_output(sramrd);
`ifdef SD
output [STO_BW-1:0] o_syst_type;
`endif
output [DBW-1:0] o_sramrd [VSIZE];

//======================================
// Broadcast input
//======================================
// Allocate space and generate address
// LinearCollector stops after AccumWarpLooper, so we only wait this two
`rdyack_logic(brd_lc);
`rdyack_logic(brd_alloc);
Broadcast#(2) u_broadcast_input(
	`clk_connect,
	`rdyack_connect(src, bofs),
	.dst_rdys({brd_lc_rdy,brd_alloc_rdy}),
	.dst_acks({brd_lc_ack,brd_alloc_ack})
);

//======================================
// Allocate space, notify DMA,
// and send to LinearCollector upon ready
//======================================
logic [HBW:0] i_local_sizes [N_ICFG];
`rdyack_logic(alloc_lc);
logic [LBW-1:0] alloc_lc_linear;
`dval_logic(rmc_alloc_free_id);
logic [ICFG_BW-1:0] rmc_alloc_free_id;
`ifdef SD
logic               rmc_alloc_false_alloc;
logic [LBW-1:0] lc_awl_linears [N_ICFG];
`endif

logic [LBW-1:0] i_local_mboundaries2 [N_ICFG][DIM];
always_comb for (int i = 0; i < N_ICFG; i++) begin
	i_local_sizes[i] = i_local_mboundaries[i][0][LBW-:(HBW+1)];
	for (int j = 0; j < DIM; j++) begin
		i_local_mboundaries2[i][j] = i_local_mboundaries[i][j][LBW-1:0];
	end
end

Allocator#(.LBW(LBW)) u_alloc(
	`clk_connect,
	.i_sizes(i_local_sizes),
	`rdyack_connect(alloc, brd_alloc),
	.i_beg_id(i_beg),
	.i_end_id(i_end),
`ifdef SD
	.i_syst_type(i_syst_type),
	.i_systolic_skip(i_systolic_skip),
`endif
	`rdyack_connect(linear, alloc_lc),
	.o_linear(alloc_lc_linear),
	`rdyack_connect(allocated, rp_en),
	`dval_connect(we, dma_write),
	`dval_connect(free, rmc_alloc_free_id),
	.i_free_id(rmc_alloc_free_id)
`ifdef SD
	, .i_false_free(rmc_alloc_false_alloc)
`endif
);
//======================================
// Collect and launch AccumWarpLooper
//======================================
// Use input information to know what to collect
`rdyack_logic(lc_awl);
logic [WBW-1:0] lc_awl_bofs    [VDIM];
logic [WBW-1:0] lc_awl_abeg    [VDIM];
logic [WBW-1:0] lc_awl_aend    [VDIM];
logic [LBW-1:0] lc_awl_linears [N_ICFG];
`ifdef SD
logic [STO_BW-1:0]  lc_awl_syst_type;
`endif
LinearCollector#(.LBW(LBW)) u_linear_col(
	`clk_connect,
	`rdyack_connect(range, brd_lc),
	.i_bofs(i_bofs),
	.i_abeg(i_abeg),
	.i_aend(i_aend),
	.i_beg(i_beg),
	.i_end(i_end),
`ifdef SD
	.i_syst_type(i_syst_type),
`endif
	`rdyack_connect(src_linear, alloc_lc),
	.i_linear(alloc_lc_linear),
	`rdyack_connect(dst_linears, lc_awl),
	.o_bofs(lc_awl_bofs),
	.o_abeg(lc_awl_abeg),
	.o_aend(lc_awl_aend),
`ifdef SD
	.o_syst_type(lc_awl_syst_type),
`endif
	.o_linears(lc_awl_linears)
);
`rdyack_logic(awl_rmc_addrval);
logic [ICFG_BW-1:0] awl_rmc_id;
logic [LBW-1:0]     awl_rmc_addr [VSIZE];
logic               awl_rmc_retire;
`ifdef SD
logic [STO_BW-1:0]  awl_rmc_syst_type;
`endif
AccumWarpLooper #(.N_CFG(N_ICFG), .ABW(LBW), .STENCIL(1), .USE_LOFS(1)) u_awl(
	`clk_connect,
	`rdyack_connect(abofs, lc_awl),
	.i_bofs(lc_awl_bofs),
	.i_abeg(lc_awl_abeg),
	.i_aend(lc_awl_aend),
`ifdef SD
	.i_syst_type(lc_awl_syst_type),
`endif
	.i_linears(lc_awl_linears),
	.i_bboundary(),
	.i_bsubofs(),
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
	.i_mofs_bsubsteps(i_local_bsubsteps),
	.i_mboundaries(i_local_mboundaries2),
	.i_id_begs(i_id_begs),
	.i_id_ends(i_id_ends),
	.i_stencil(i_stencil),
	.i_stencil_begs(i_stencil_begs),
	.i_stencil_ends(i_stencil_ends),
	.i_stencil_lut(i_stencil_lut),
`ifdef SD
	.i_systolic_skip(i_systolic_skip),
`endif
	`rdyack_connect(addrval, awl_rmc_addrval),
	.o_id(awl_rmc_id),
	.o_address(awl_rmc_addr),
	.o_valid(),
	.o_retire(awl_rmc_retire)
`ifdef SD
	,
	.o_syst_type(awl_rmc_syst_type)
`endif
);

//======================================
// Buffer (accept data; addr -> data)
//======================================
RemapCache#(.LBW(LBW)) u_rmc(
	`clk_connect,
	.i_xor_srcs(i_local_xor_srcs),
	.i_xor_swaps(i_local_xor_swaps),
	`rdyack_connect(ra, awl_rmc_addrval),
	.i_rid(awl_rmc_id),
	.i_raddr(awl_rmc_addr),
	.i_retire(awl_rmc_retire),
`ifdef SD
	.i_syst_type(awl_rmc_syst_type),
`endif
	`rdyack_connect(rd, sramrd),
`ifdef SD
	.o_syst_type(o_syst_type),
`endif
	.o_rdata(o_sramrd),
	`dval_connect(free, rmc_alloc_free_id),
`ifdef SD
	.o_false_alloc(rmc_alloc_false_alloc),
`endif
	.o_free_id(rmc_alloc_free_id),
	`dval_connect(wad, dma_write),
	.i_whiaddr(i_dma_whiaddr),
	.i_wdata(i_dma_wdata)
);

endmodule
