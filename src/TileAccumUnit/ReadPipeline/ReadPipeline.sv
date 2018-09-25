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
`include "TileAccumUnit/ReadPipeline/ChunkAddrLooper/ChunkAddrLooper.sv"
`include "TileAccumUnit/ReadPipeline/ChunkHead.sv"
`include "TileAccumUnit/ReadPipeline/LinearCollector.sv"
`include "TileAccumUnit/ReadPipeline/RemapCache/RemapCache.sv"
`include "TileAccumUnit/ReadPipeline/SramWriteCollector.sv"

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
	i_global_linears,
	i_global_mofs,
	i_global_mboundaries,
	i_global_cboundaries,
	i_global_bshufs,
	i_bstrides_frac,
	i_bstrides_shamt,
	i_global_ashufs,
	i_astrides_frac,
	i_astrides_shamt,
	i_local_xor_srcs,
	i_local_xor_swaps,
	i_local_pads,
	i_local_bsubsteps,
	i_local_mboundaries,
	i_wrap,
	i_pad_value,
	i_id_begs,
	i_id_ends,
	i_stencil,
	i_stencil_begs,
	i_stencil_ends,
	i_stencil_lut,
`ifdef SD
	i_systolic_skip,
`endif
	`dval_port(blkdone),
	// Write to SRAM
	`dval_port(rmc_write),
	i_rmc_whiaddr,
	i_rmc_write_wdata,
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
input [GBW-1:0]     i_global_linears     [N_ICFG];
input [WBW-1:0]     i_global_mofs        [N_ICFG][DIM];
input [GBW-1:0]     i_global_mboundaries [N_ICFG][DIM];
input [GBW-1:0]     i_global_cboundaries [N_ICFG][DIM];
input [DIM_BW-1:0]  i_global_bshufs      [N_ICFG][VDIM];
input [SF_BW-1:0]   i_bstrides_frac      [N_ICFG][VDIM];
input [SS_BW-1:0]   i_bstrides_shamt     [N_ICFG][VDIM];
input [DIM_BW-1:0]  i_global_ashufs      [N_ICFG][VDIM];
input [SF_BW-1:0]   i_astrides_frac      [N_ICFG][VDIM];
input [SS_BW-1:0]   i_astrides_shamt     [N_ICFG][VDIM];
input [XOR_BW-1:0]  i_local_xor_srcs     [N_ICFG][CV_BW];
input [CCV_BW-1:0]  i_local_xor_swaps    [N_ICFG];
input [CV_BW-1:0]   i_local_pads         [N_ICFG][DIM];
input [LBW-1:0]     i_local_bsubsteps    [N_ICFG][CV_BW];
input [LBW-1:0]     i_local_mboundaries  [N_ICFG][DIM];
input [N_ICFG-1:0]  i_wrap;
input [DBW-1:0]     i_pad_value [N_ICFG];
input [ICFG_BW-1:0] i_id_begs [VDIM+1];
input [ICFG_BW-1:0] i_id_ends [VDIM+1];
input               i_stencil;
input [ST_BW-1:0]   i_stencil_begs [N_ICFG];
input [ST_BW-1:0]   i_stencil_ends [N_ICFG];
input [LBW-1:0]     i_stencil_lut [STSIZE];
`ifdef SD
input [N_ICFG-1:0]  i_systolic_skip;
`endif
`dval_input(blkdone);
`rdyack_output(dramra);
output [GBW-1:0] o_dramra;
`rdyack_input(dramrd);
input [DBW-1:0] i_dramrd [CSIZE];
`rdyack_output(sramrd);
`ifdef SD
output [STO_BW-1:0] o_syst_type;
`endif
output [DBW-1:0] o_sramrd [VSIZE];

//======================================
// Internal
//======================================
logic [LBW:0] i_local_sizes [N_ICFG];
`rdyack_logic(brd0_lc);
`rdyack_logic(brd0_ch);
`rdyack_logic(ch_mofs);
`rdyack_logic(ch_mofs_masked);    // -> cmd, addr, alloc
`rdyack_logic(cal_writer_cmd);
`dval_logic(rmc_alloc_free_id);
logic [WBW-1:0]     ch_mofs      [DIM];
logic [GBW-1:0]     ch_mofs_sext [DIM];
logic [ICFG_BW-1:0] ch_mid;
`rdyack_logic(ch_alloc_mofs_src); // broadcast
`rdyack_logic(ch_cmd_mofs_src);   // broadcast
`rdyack_logic(ch_addr_mofs_src);  // broadcast
`rdyack_logic(ch_alloc_mofs_dst); // pipeline
`rdyack_logic(ch_alloc_mofs_dst2);// if alloc counter < MAX
logic [ICFG_BW-1:0] ch_alloc_mid;
`rdyack_logic(ch_cmd_mofs_dst);   // pipeline
logic [CV_BW-1:0]   ch_cmd_local_pad [DIM];
logic [GBW-1:0]     ch_cmd_global_mboundary [DIM];
logic [GBW-1:0]     ch_cmd_global_cboundary [DIM];
logic [GBW-1:0]     ch_cmd_mofs [DIM];
logic [ICFG_BW-1:0] ch_cmd_mid;
`rdyack_logic(ch_addr_mofs_dst);  // pipeline
`rdyack_logic(ch_addr_mofs_dst2); // if alloc counter > 0
logic [CV_BW-1:0]   ch_addr_local_pad [DIM];
logic [GBW-1:0]     ch_addr_global_mboundary [DIM];
logic [GBW-1:0]     ch_addr_global_cboundary [DIM];
logic [GBW-1:0]     ch_addr_mofs [DIM];
logic [ICFG_BW-1:0] ch_addr_mid;
`rdyack_logic(cal_cmd);
`rdyack_logic(cal_addr);
logic cal_addr_islast;
`rdyack_logic(alloc_writer_linear);
logic [LBW-1:0]     alloc_writer_linear;
logic [ICFG_BW-1:0] alloc_writer_linear_id;
`rdyack_logic(rmc_alloc_free_id);
logic [ICFG_BW-1:0] rmc_alloc_free_id;
`rdyack_logic(writer_warp_linear_fifo_in);
`rdyack_logic(writer_warp_linear_fifo_out);
logic [LBW-1:0]     writer_linear;
logic [LBW-1:0]     writer_warp_linear [LBUF_SIZE];
logic [LBUF_SIZE-2:0] linear_load_nxt;
logic [LBUF_SIZE-1:0] linear_load_new;
logic alloc_empty;
logic alloc_full;
logic linear_full;
`rdyack_logic(warp_rmc_addrval);
logic [ICFG_BW-1:0] warp_rmc_id;
logic [LBW-1:0]     warp_rmc_addr [VSIZE];
logic               warp_rmc_retire;
`rdyack_logic(cal_writer);
logic [1:0]        cal_writer_type;
logic              cal_writer_islast;
logic [CC_BW-1:0]  cal_writer_addrofs;
logic [CV_BW1-1:0] cal_writer_len;
`rdyack_logic(lc_warp);
logic [WBW-1:0] lc_bofs         [VDIM];
logic [WBW-1:0] lc_abeg         [VDIM];
logic [WBW-1:0] lc_aend         [VDIM];
logic [LBW-1:0] lc_warp_linears [N_ICFG];
`dval_logic(rmc_write);
logic [ICFG_BW-1:0]   rmc_write_wid;
logic [LBW-CV_BW-1:0] rmc_write_whiaddr;
logic [DBW-1:0]       rmc_write_wdata [VSIZE];
`ifdef SD
logic               ch_skip;
`rdyack_logic(ch_cmd_mofs_src2);  // broadcast
`rdyack_logic(ch_addr_mofs_src2); // broadcast
logic               ch_alloc_false_alloc;
logic               rmc_alloc_false_alloc;
logic [STO_BW-1:0]  warp_rmc_syst_type;
logic [STO_BW-1:0]  lc_syst_type;
`endif

//======================================
// Submodule
//======================================
Forward u_fwd_alloc(
	`clk_connect,
	`rdyack_connect(src, ch_alloc_mofs_src),
	`rdyack_connect(dst, ch_alloc_mofs_dst)
);
LinearCollector#(.LBW(LBW)) u_linear_col(
	`clk_connect,
	`rdyack_connect(range, brd0_lc),
	.i_bofs(i_bofs),
	.i_abeg(i_abeg),
	.i_aend(i_aend),
	.i_beg(i_beg),
	.i_end(i_end),
`ifdef SD
	.i_syst_type(i_syst_type),
`endif
	`rdyack_connect(src_linear, writer_warp_linear_fifo_out),
	.i_linear(writer_warp_linear[0]),
	`rdyack_connect(dst_linears, lc_warp),
	.o_bofs(lc_bofs),
	.o_abeg(lc_abeg),
	.o_aend(lc_aend),
`ifdef SD
	.o_syst_type(lc_syst_type),
`endif
	.o_linears(lc_warp_linears)
);
// TODO: this works without large modification, but for low power, AG can be turned off
AccumWarpLooper #(.N_CFG(N_ICFG), .ABW(LBW), .STENCIL(1), .USE_LOFS(1)) u_awl(
	`clk_connect,
	`rdyack_connect(abofs, lc_warp),
	.i_bofs(lc_bofs),
	.i_abeg(lc_abeg),
	.i_aend(lc_aend),
`ifdef SD
	.i_syst_type(lc_syst_type),
`endif
	.i_linears(lc_warp_linears),
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
	.i_mboundaries(i_local_mboundaries),
	.i_id_begs(i_id_begs),
	.i_id_ends(i_id_ends),
	.i_stencil(i_stencil),
	.i_stencil_begs(i_stencil_begs),
	.i_stencil_ends(i_stencil_ends),
	.i_stencil_lut(i_stencil_lut),
`ifdef SD
	.i_systolic_skip(i_systolic_skip),
`endif
	`rdyack_connect(addrval, warp_rmc_addrval),
	.o_id(warp_rmc_id),
	.o_address(warp_rmc_addr),
	.o_valid(),
	.o_retire(warp_rmc_retire)
`ifdef SD
	,
	.o_syst_type(warp_rmc_syst_type)
`endif
);
Allocator#(.LBW(LBW)) u_alloc(
	`clk_connect,
	.i_sizes(i_local_sizes),
	`rdyack_connect(alloc, ch_alloc_mofs_dst2),
	.i_alloc_id(ch_alloc_mid),
`ifdef SD
	.i_false_alloc(ch_alloc_false_alloc),
`endif
	`rdyack_connect(linear, alloc_writer_linear),
	.o_linear(alloc_writer_linear),
	.o_linear_id(alloc_writer_linear_id),
`ifdef SD
	.o_false_alloc(alloc_writer_false_alloc),
`endif
	`dval_connect(free, rmc_alloc_free_id),
	.i_free_id(rmc_alloc_free_id),
`ifdef SD
	.i_false_free(rmc_alloc_false_alloc),
`endif
	`dval_connect(blkdone, blkdone)
);
// TODO: See AccumWarpLooper
RemapCache#(.LBW(LBW)) u_rmc(
	`clk_connect,
	.i_xor_srcs(i_local_xor_srcs),
	.i_xor_swaps(i_local_xor_swaps),
	`rdyack_connect(ra, warp_rmc_addrval),
	.i_rid(warp_rmc_id),
	.i_raddr(warp_rmc_addr),
	.i_retire(warp_rmc_retire),
`ifdef SD
	.i_syst_type(warp_rmc_syst_type),
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
	`dval_connect(wad, rmc_write),
	.i_whiaddr(rmc_write_whiaddr),
	.i_wdata(rmc_write_wdata)
);
Semaphore#(LBUF_SIZE) u_sem_linear(
	`clk_connect,
	.i_inc(ch_mofs_ack),
	.i_dec(writer_warp_linear_fifo_out_ack),
	.o_full(linear_full),
	.o_empty(),
	.o_will_full(),
	.o_will_empty(),
	.o_n()
);
IgnoreIf#(0) u_ign_if_not_last_addr(
	.cond(cal_addr_islast),
	`rdyack_connect(src, cal_addr),
	`rdyack_connect(dst, dramra),
	.skipped()
);
/*
Semaphore#(ALLOC_CNT) u_sem_alloc(
	`clk_connect,
	.i_inc(ch_alloc_mofs_dst_ack),
	.i_dec(ch_addr_mofs_dst_ack),
	.o_full(alloc_full),
	.o_empty(alloc_empty),
	.o_will_full(),
	.o_will_empty(),
	.o_n()
);
ForwardIf#(0) u_fwd_if_linear_not_full(
	.cond(linear_full),
	`rdyack_connect(src, ch_mofs),
	`rdyack_connect(dst, ch_mofs_masked)
);
ForwardIf#(0) u_fwd_if_can_allocate(
	.cond(alloc_full),
	`rdyack_connect(src, ch_alloc_mofs_dst),
	`rdyack_connect(dst, ch_alloc_mofs_dst2)
);
ForwardIf#(0) u_fwd_if_allocated(
	.cond(alloc_empty),
	`rdyack_connect(src, ch_addr_mofs_dst),
	`rdyack_connect(dst, ch_addr_mofs_dst2)
);
*/
//======================================
// Combinational
//======================================
always_comb for (int i = 0; i < N_ICFG; i++) begin
	i_local_sizes[i] = i_local_mboundaries[i][0];
end

always_comb for (int i = 0; i < DIM; i++) begin
	ch_mofs_sext[i] = $signed(ch_mofs[i]);
	ch_cmd_local_pad[i] = i_local_pads[ch_cmd_mid][i];
	ch_cmd_global_mboundary[i] = i_global_mboundaries[ch_cmd_mid][i];
	ch_cmd_global_cboundary[i] = i_global_cboundaries[ch_cmd_mid][i];
	ch_addr_local_pad[i] = i_local_pads[ch_addr_mid][i];
	ch_addr_global_mboundary[i] = i_global_mboundaries[ch_addr_mid][i];
	ch_addr_global_cboundary[i] = i_global_cboundaries[ch_addr_mid][i];
end


//======================================
// Sequential
//======================================
`ff_rst
	ch_alloc_mid <= '0;
`ifdef SD
	ch_alloc_false_alloc <= 1'b0;
`endif
`ff_cg(ch_alloc_mofs_src_ack)
	ch_alloc_mid <= ch_mid;
`ifdef SD
	ch_alloc_false_alloc <= ch_skip;
`endif
`ff_end

`ff_rst
	for (int i = 0; i < DIM; i++) begin
		ch_cmd_mofs[i] <= '0;
	end
	ch_cmd_mid <= '0;
`ifdef SD
`ff_cg(ch_cmd_mofs_src2_ack)
`else
`ff_cg(ch_cmd_mofs_src_ack)
`endif
	for (int i = 0; i < DIM-1; i++) begin
		ch_cmd_mofs[i] <= ch_mofs_sext[i] * i_global_mboundaries[ch_mid][i+1];
	end
	ch_cmd_mofs[DIM-1] <= ch_mofs_sext[DIM-1];
	ch_cmd_mid <= ch_mid;
`ff_end

`ff_rst
	for (int i = 0; i < DIM; i++) begin
		ch_addr_mofs[i] <= '0;
	end
	ch_addr_mid <= '0;
`ifdef SD
`ff_cg(ch_addr_mofs_src2_ack)
`else
`ff_cg(ch_addr_mofs_src_ack)
`endif
	for (int i = 0; i < DIM-1; i++) begin
		ch_addr_mofs[i] <= ch_mofs_sext[i] * i_global_mboundaries[ch_mid][i+1];
	end
	ch_addr_mofs[DIM-1] <= ch_mofs_sext[DIM-1];
	ch_addr_mid <= ch_mid;
`ff_end

endmodule
