// Copyright 2016-2018
// Yu Sheng Lin
// Yan Hsi Wang

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
	i_local_xor_masks,
	i_local_xor_schemes,
	i_local_xor_configs,
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
	`dval_port(blkdone),
	`rdyack_port(dramra),
	o_dramra,
	`rdyack_port(dramrd),
	i_dramrd,
	`rdyack_port(sramrd),
	o_sramrd
);

//======================================
// Parameter
//======================================
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
localparam LBUF_SIZE = 3;
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
input [CV_BW-1:0]   i_local_xor_masks    [N_ICFG];
input [CCV_BW-1:0]  i_local_xor_schemes  [N_ICFG][CV_BW];
input [XOR_BW-1:0]  i_local_xor_configs  [N_ICFG];
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
`dval_input(blkdone);
`rdyack_output(dramra);
output [GBW-1:0] o_dramra;
`rdyack_input(dramrd);
input [DBW-1:0] i_dramrd [CSIZE];
`rdyack_output(sramrd);
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
logic [GBW-1:0]     ch_cmd_mofs [DIM];
logic [ICFG_BW-1:0] ch_cmd_mid;
`rdyack_logic(ch_addr_mofs_dst);  // pipeline
`rdyack_logic(ch_addr_mofs_dst2); // if alloc counter > 0
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
`dval_logic(writer_rmc);
logic [ICFG_BW-1:0]   writer_rmc_wid;
logic [LBW-CV_BW-1:0] writer_rmc_whiaddr;
logic [DBW-1:0]       writer_rmc_wdata [VSIZE];
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

//======================================
// Submodule
//======================================
Broadcast#(2) u_broadcast_input(
	`clk_connect,
	`rdyack_connect(src, bofs),
	.acked(),
	.dst_rdys({brd0_lc_rdy,brd0_ch_rdy}),
	.dst_acks({brd0_lc_ack,brd0_ch_ack})
);
Broadcast#(3) u_broadcast_mofs(
	`clk_connect,
	`rdyack_connect(src, ch_mofs_masked),
	.acked(),
	.dst_rdys({ch_alloc_mofs_src_rdy,ch_cmd_mofs_src_rdy,ch_addr_mofs_src_rdy}),
	.dst_acks({ch_alloc_mofs_src_ack,ch_cmd_mofs_src_ack,ch_addr_mofs_src_ack})
);
Forward u_fwd_alloc(
	`clk_connect,
	`rdyack_connect(src, ch_alloc_mofs_src),
	`rdyack_connect(dst, ch_alloc_mofs_dst)
);
Forward u_fwd_cmd(
	`clk_connect,
	`rdyack_connect(src, ch_cmd_mofs_src),
	`rdyack_connect(dst, ch_cmd_mofs_dst)
);
Forward u_fwd_addr(
	`clk_connect,
	`rdyack_connect(src, ch_addr_mofs_src),
	`rdyack_connect(dst, ch_addr_mofs_dst)
);
ChunkHead u_chunk_head(
	`clk_connect,
	`rdyack_connect(i_abofs, brd0_ch),
	.i_bofs(i_bofs),
	.i_aofs(i_abeg),
	.i_beg(i_beg),
	.i_end(i_end),
	.i_global_mofs(i_global_mofs),
	.i_global_bshufs(i_global_bshufs),
	.i_bstrides_frac(i_bstrides_frac),
	.i_bstrides_shamt(i_bstrides_shamt),
	.i_global_ashufs(i_global_ashufs),
	.i_astrides_frac(i_astrides_frac),
	.i_astrides_shamt(i_astrides_shamt),
	`rdyack_connect(o_mofs, ch_mofs),
	.o_mofs(ch_mofs),
	.o_id(ch_mid)
);
LinearCollector#(.LBW(LBW)) u_linear_col(
	`clk_connect,
	`rdyack_connect(range, brd0_lc),
	.i_bofs(i_bofs),
	.i_abeg(i_abeg),
	.i_aend(i_aend),
	.i_beg(i_beg),
	.i_end(i_end),
	`rdyack_connect(src_linear, writer_warp_linear_fifo_out),
	.i_linear(writer_warp_linear[0]),
	`rdyack_connect(dst_linears, lc_warp),
	.o_bofs(lc_bofs),
	.o_abeg(lc_abeg),
	.o_aend(lc_aend),
	.o_linears(lc_warp_linears)
);
AccumWarpLooper #(.N_CFG(N_ICFG), .ABW(LBW), .STENCIL(1), .USE_LOFS(1)) u_awl(
	`clk_connect,
	`rdyack_connect(abofs, lc_warp),
	.i_bofs(lc_bofs),
	.i_abeg(lc_abeg),
	.i_aend(lc_aend),
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
	`rdyack_connect(addrval, warp_rmc_addrval),
	.o_id(warp_rmc_id),
	.o_address(warp_rmc_addr),
	.o_valid(),
	.o_retire(warp_rmc_retire)
);
Allocator#(.LBW(LBW)) u_alloc(
	`clk_connect,
	.i_sizes(i_local_sizes),
	`rdyack_connect(alloc, ch_alloc_mofs_dst2),
	.i_alloc_id(ch_alloc_mid),
	`rdyack_connect(linear, alloc_writer_linear),
	.o_linear(alloc_writer_linear),
	.o_linear_id(alloc_writer_linear_id),
	`dval_connect(free, rmc_alloc_free_id),
	.i_free_id(rmc_alloc_free_id),
	`dval_connect(blkdone, blkdone)
);
SramWriteCollector#(.LBW(LBW)) u_swc(
	`clk_connect,
	`rdyack_connect(alloc_linear, alloc_writer_linear),
	.i_linear(alloc_writer_linear),
	.i_linear_id(alloc_writer_linear_id),
	.i_size(i_local_sizes[alloc_writer_linear_id]),
	.i_padv(i_pad_value[alloc_writer_linear_id]),
	`rdyack_connect(cmd, cal_writer_cmd),
	.i_cmd_type(cal_writer_type),
	.i_cmd_islast(cal_writer_islast),
	.i_cmd_addrofs(cal_writer_addrofs),
	.i_cmd_len(cal_writer_len),
	`rdyack_connect(dramrd, dramrd),
	.i_dramrd(i_dramrd),
	`rdyack_connect(done_linear, writer_warp_linear_fifo_in),
	.o_linear(writer_linear),
	.o_linear_id(),
	`dval_connect(w, writer_rmc),
	.o_id(writer_rmc_wid),
	.o_hiaddr(writer_rmc_whiaddr),
	.o_data(writer_rmc_wdata)
);
RemapCache#(.LBW(LBW)) u_rmc(
	`clk_connect,
	.i_xor_masks(i_local_xor_masks),
	.i_xor_schemes(i_local_xor_schemes),
	.i_xor_configs(i_local_xor_configs),
	`rdyack_connect(ra, warp_rmc_addrval),
	.i_rid(warp_rmc_id),
	.i_raddr(warp_rmc_addr),
	.i_retire(warp_rmc_retire),
	`rdyack_connect(rd, sramrd),
	.o_rdata(o_sramrd),
	`dval_connect(free, rmc_alloc_free_id),
	.o_free_id(rmc_alloc_free_id),
	`dval_connect(wad, writer_rmc),
	.i_wid(writer_rmc_wid),
	.i_whiaddr(writer_rmc_whiaddr),
	.i_wdata(writer_rmc_wdata)
);
ChunkAddrLooper#(.LBW(LBW)) u_cal_addr(
	`clk_connect,
	`rdyack_connect(mofs, ch_addr_mofs_dst2),
	.i_mofs(ch_addr_mofs),
	.i_mpad(i_local_pads[ch_cmd_mid]),
	.i_mbound(i_global_mboundaries[ch_cmd_mid]),
	.i_mlast(i_global_cboundaries[ch_cmd_mid]),
	.i_maddr(i_global_linears[ch_cmd_mid]),
	.i_wrap(i_wrap[ch_cmd_mid]),
	`rdyack_connect(cmd, cal_addr),
	.o_cmd_type(),
	.o_cmd_islast(cal_addr_islast),
	.o_cmd_addr(o_dramra),
	.o_cmd_addrofs(),
	.o_cmd_len()
);
ChunkAddrLooper#(.LBW(LBW)) u_cal_cmd(
	`clk_connect,
	`rdyack_connect(mofs, ch_cmd_mofs_dst),
	.i_mofs(ch_cmd_mofs),
	.i_mpad(i_local_pads[ch_addr_mid]),
	.i_mbound(i_global_mboundaries[ch_addr_mid]),
	.i_mlast(i_global_cboundaries[ch_addr_mid]),
	.i_maddr(i_global_linears[ch_addr_mid]),
	.i_wrap(i_wrap[ch_addr_mid]),
	`rdyack_connect(cmd, cal_writer_cmd),
	.o_cmd_type(cal_writer_type),
	.o_cmd_islast(cal_writer_islast),
	.o_cmd_addr(),
	.o_cmd_addrofs(cal_writer_addrofs),
	.o_cmd_len(cal_writer_len)
);
SFifoCtrl#(LBUF_SIZE) u_sfifo_ctrl_linear(
	`clk_connect,
	`rdyack_connect(src, writer_warp_linear_fifo_in),
	`rdyack_connect(dst, writer_warp_linear_fifo_out),
	.o_load_nxt(linear_load_nxt),
	.o_load_new(linear_load_new)
);
Semaphore#(LBUF_SIZE) u_sem_linear(
	`clk_connect,
	.i_inc(ch_mofs_ack),
	.i_dec(writer_warp_linear_fifo_out_ack),
	.o_full(linear_full),
	.o_empty()
);
Semaphore#(ALLOC_CNT) u_sem_alloc(
	`clk_connect,
	.i_inc(ch_alloc_mofs_dst_ack),
	.i_dec(ch_addr_mofs_dst_ack),
	.o_full(alloc_full),
	.o_empty(alloc_empty)
);
IgnoreIf#(0) u_ign_if_not_last_addr(
	.cond(cal_addr_islast),
	`rdyack_connect(src, cal_addr),
	`rdyack_connect(dst, dramra)
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
//======================================
// Combinational
//======================================
always_comb for (int i = 0; i < N_ICFG; i++) begin
	i_local_sizes[i] = i_local_mboundaries[i][0];
end

always_comb for (int i = 0; i < DIM; i++) begin
	ch_mofs_sext[i] = $signed(ch_mofs[i]);
end

//======================================
// Sequential
//======================================
`ff_rst
	ch_alloc_mid <= '0;
`ff_cg(ch_alloc_mofs_src_ack)
	ch_alloc_mid <= ch_mid;
`ff_end

`ff_rst
	for (int i = 0; i < DIM; i++) begin
		ch_cmd_mofs[i] <= '0;
	end
	ch_cmd_mid <= '0;
`ff_cg(ch_cmd_mofs_src_ack)
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
`ff_cg(ch_addr_mofs_src_ack)
	for (int i = 0; i < DIM-1; i++) begin
		ch_addr_mofs[i] <= ch_mofs_sext[i] * i_global_mboundaries[ch_mid][i+1];
	end
	ch_addr_mofs[DIM-1] <= ch_mofs_sext[DIM-1];
	ch_addr_mid <= ch_mid;
`ff_end

genvar gi;
generate for (gi = 0; gi < LBUF_SIZE-1; gi++) begin: warp_linear_fifo
always_ff @(posedge i_clk or negedge i_rst) begin
	if (!i_rst) begin
		writer_warp_linear[gi] <= '0;
	end else if (linear_load_nxt[gi] || linear_load_new[gi]) begin
		writer_warp_linear[gi] <= linear_load_new[gi] ? writer_linear : writer_warp_linear[gi+1];
	end
end
end endgenerate

`ff_rst
	writer_warp_linear[LBUF_SIZE-1] <= '0;
`ff_cg(linear_load_new[LBUF_SIZE-1])
	writer_warp_linear[LBUF_SIZE-1] <= writer_linear;
`ff_end

endmodule
