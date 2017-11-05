// Copyright 2016
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

import TauCfg::*;

module ReadPipeline(
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
	i_local_xor_masks,
	i_local_xor_schemes,
	i_local_bit_swaps,
	i_local_boundaries,
	i_local_bsubsteps,
	i_local_pads,
	i_global_starts,
	i_global_linears,
	i_global_cboundaries,
	i_global_boundaries,
	i_global_bshufs,
	i_global_ashufs,
	i_bstrides_frac,
	i_bstrides_shamt,
	i_astrides_frac,
	i_astrides_shamt,
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
localparam AF_BW = TauCfg::AOFS_FRAC_BW;
localparam AS_BW = TauCfg::AOFS_SHAMT_BW;
localparam VSIZE = TauCfg::VECTOR_SIZE;
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
input [WBW-1:0]     i_aofs           [VDIM];
input [WBW-1:0]     i_alast          [VDIM];
input [WBW-1:0]     i_bboundary      [VDIM];
input [CV_BW-1:0]   i_bsubofs [VSIZE][VDIM];
input [CCV_BW  :0]  i_bsub_up_order  [VDIM];
input [CCV_BW-1:0]  i_bsub_lo_order  [VDIM];
input [WBW-1:0]     i_aboundary      [VDIM];
input [CV_BW-1:0]   i_local_xor_masks    [N_ICFG];
input [CX_BW-1:0]   i_local_xor_schemes  [N_ICFG][CV_BW];
input [CCV_BW-1:0]  i_local_bit_swaps    [N_ICFG];
input [LBW-1:0]     i_local_boundaries   [N_ICFG][DIM];
input [LBW-1:0]     i_local_bsubsteps    [N_ICFG][CV_BW];
input [CV_BW-1:0]   i_local_pads         [N_ICFG][DIM];
input [GBW-1:0]     i_global_starts      [N_ICFG][DIM];
input [GBW-1:0]     i_global_linears     [N_ICFG][DIM];
input [GBW-1:0]     i_global_cboundaries [N_ICFG][DIM];
input [GBW-1:0]     i_global_boundaries  [N_ICFG][DIM];
input [DIM_BW-1:0]  i_global_mofs_bshufs [N_ICFG][DIM];
input [DIM_BW-1:0]  i_global_mofs_ashufs [N_ICFG][DIM];
input [SF_BW-1:0]   i_bstrides_frac  [N_ICFG][VDIM]
input [SS_BW-1:0]   i_bstrides_shamt [N_ICFG][VDIM]
input [SF_BW-1:0]   i_astrides_frac  [N_ICFG][VDIM]
input [SS_BW-1:0]   i_astrides_shamt [N_ICFG][VDIM]
input [ICFG_BW-1:0] i_id_begs [DIM+1];
input [ICFG_BW-1:0] i_id_ends [DIM+1];
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
`rdyack_logic(al_src);
`rdyack_logic(wait_fin);
`rdyack_logic(acc_abofs);
`rdyack_logic(acc_mofs);
`rdyack_logic(acc_mofs_masked);    // -> cmd, addr, alloc
`rdyack_logic(cal_writer_cmd);
`dval_logic(rmc_alloc_free_id);
logic [GBW-1:0]     acc_mofs [DIM];
logic [ICFG_BW-1:0] acc_mid;
`rdyack_logic(acc_alloc_mofs_src); // broadcast
`rdyack_logic(acc_cmd_mofs_src);   // broadcast
`rdyack_logic(acc_addr_mofs_src);  // broadcast
`rdyack_logic(acc_alloc_mofs_dst); // pipeline
`rdyack_logic(acc_alloc_mofs_dst2);// if alloc counter < MAX
logic [ICFG_BW-1:0] acc_alloc_mid;
`rdyack_logic(acc_cmd_mofs_dst);   // pipeline
logic [GBW-1:0]     acc_cmd_mofs [DIM];
logic [ICFG_BW-1:0] acc_cmd_mid;
`rdyack_logic(acc_addr_mofs_dst);  // pipeline
`rdyack_logic(acc_addr_mofs_dst2); // if alloc counter > 0
logic [GBW-1:0]     acc_addr_mofs [DIM];
logic [ICFG_BW-1:0] acc_addr_mid;
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
logic [ICFG_BW-1:0] writer_id;
logic [LBW-1:0]     writer_warp_linear [LBUF_SIZE];
logic [ICFG_BW-1:0] writer_warp_id [LBUF_SIZE];
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
`rdyack_logic(cmdaddr);
logic [1:0]        cal_writer_type;
logic              cal_writer_islast;
logic [CC_BW-1:0]  cal_writer_addrofs;
logic [CV_BW1-1:0] cal_writer_len;

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
Broadcast#(3) u_broadcast_mofs(
	`clk_connect,
	`rdyack_connect(src, acc_mofs_masked),
	.acked(),
	.dst_rdys({acc_alloc_mofs_src_rdy,acc_cmd_mofs_src_rdy,acc_addr_mofs_src_rdy}),
	.dst_acks({acc_alloc_mofs_src_ack,acc_cmd_mofs_src_ack,acc_addr_mofs_src_ack})
);
Forward u_fwd_alloc(
	`clk_connect,
	`rdyack_connect(src, acc_alloc_mofs_src),
	`rdyack_connect(dst, acc_alloc_mofs_dst)
);
Forward u_fwd_cmd(
	`clk_connect,
	`rdyack_connect(src, acc_cmd_mofs_src),
	`rdyack_connect(dst, acc_cmd_mofs_dst)
);
Forward u_fwd_addr(
	`clk_connect,
	`rdyack_connect(src, acc_addr_mofs_src),
	`rdyack_connect(dst, acc_addr_mofs_dst)
);
WarpLooper #(.N_CFG(N_ICFG), .ABW(LBW), .STENCIL(1)) u_awl(
	`clk_connect,
	`rdyack_connect(abofs, warp_abofs),
	.i_bofs(i_warp_bofs),
	.i_aofs(i_warp_aofs),
	.i_alast(i_warp_alast),
	.i_linears(writer_warp_linear[0]),
	.i_bboundary(),
	.i_bsubofs(i_bsubofs),
	.i_bsub_up_order(i_bsub_up_order),
	.i_bsub_lo_order(i_bsub_lo_order),
	.i_aboundary(i_aboundary),
	.i_mofs_bsubsteps(i_local_mofs_bsubsteps),
	.i_bstrides_frac(i_bstrides_frac),
	.i_bstrides_shamt(i_bstrides_shamt),
	.i_astrides_frac(i_astrides_frac),
	.i_astrides_shamt(i_astrides_shamt),
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
	`rdyack_connect(alloc, acc_alloc_mofs_dst2),
	.i_alloc_id(acc_alloc_mid),
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
	.i_sizes(i_local_sizes),
	`rdyack_connect(cmd, cal_writer_cmd),
	.i_cmd_type(cal_writer_type),
	.i_cmd_islast(cal_writer_islast),
	.i_cmd_addrofs(cal_writer_addrofs),
	.i_cmd_len(cal_writer_len),
	`rdyack_connect(dramrd, dramrd),
	.i_dramrd(i_dramrd),
	`rdyack_connect(done_linear, writer_warp_linear_fifo_in),
	.o_linear(writer_linear),
	.o_linear_id(writer_id),
	`dval_connect(w, writer_rmc),
	.o_id(writer_rmc_wid),
	.o_hiaddr(writer_rmc_whiaddr),
	.o_data(writer_rmc_wdata)
);
RemapCache#(.LBW(LBW)) u_rmc(
	`clk_connect,
	.i_xor_masks(i_local_xor_masks),
	.i_xor_schemes(i_local_xor_schemes),
	.i_bit_swaps(i_local_bit_swaps),
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
	`rdyack_connect(mofs, acc_addr_mofs_dst2),
	.i_mofs(acc_addr_mofs),
	.i_mpad(i_local_pads[acc_cmd_mid]),
	.i_mbound(i_global_mboundaries[acc_cmd_mid]),
	.i_mlast(i_global_cboundaries[acc_cmd_mid]),
	.i_maddr(i_global_mofs_linears[acc_cmd_mid]),
	`rdyack_connect(cmd, cal_addr),
	.o_cmd_type(),
	.o_cmd_islast(cal_addr_islast),
	.o_cmd_addr(o_dramra),
	.o_cmd_addrofs(),
	.o_cmd_len()
);
ChunkAddrLooper#(.LBW(LBW)) u_cal_cmd(
	`clk_connect,
	`rdyack_connect(mofs, acc_cmd_mofs_dst),
	.i_mofs(acc_cmd_mofs),
	.i_mpad(i_local_pads[acc_addr_mid]),
	.i_mbound(i_global_mboundaries[acc_addr_mid]),
	.i_mlast(i_global_cboundaries[acc_addr_mid]),
	.i_maddr(i_global_mofs_linears[acc_addr_mid]),
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
	.i_inc(acc_mofs_ack),
	.i_dec(writer_warp_linear_fifo_out_ack),
	.o_full(linear_full),
	.o_empty()
);
Semaphore#(ALLOC_CNT) u_sem_alloc(
	`clk_connect,
	.i_inc(acc_alloc_mofs_dst_ack),
	.i_dec(acc_addr_mofs_dst_ack),
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
	`rdyack_connect(src, acc_mofs),
	`rdyack_connect(dst, acc_mofs_masked)
);
ForwardIf#(0) u_fwd_if_can_allocate(
	.cond(alloc_full),
	`rdyack_connect(src, acc_alloc_mofs_dst),
	`rdyack_connect(dst, acc_alloc_mofs_dst2)
);
ForwardIf#(0) u_fwd_if_allocated(
	.cond(alloc_empty),
	`rdyack_connect(src, acc_addr_mofs_dst),
	`rdyack_connect(dst, acc_addr_mofs_dst2)
);

//======================================
// Combinational
//======================================
assign acc_abofs_ack = acc_abofs_rdy;
assign wait_fin_ack = blkdone_dval;

//======================================
// Sequential
//======================================
`ff_rst
	acc_alloc_mid <= '0;
`ff_cg(acc_alloc_mofs_src_ack)
	acc_alloc_mid <= acc_mid;
`ff_end

`ff_rst
	for (int i = 0; i < DIM; i++) begin
		acc_cmd_mofs[i] <= '0;
	end
	acc_cmd_mid <= '0;
`ff_cg(acc_cmd_mofs_src_ack)
	acc_cmd_mofs <= acc_mofs;
	acc_cmd_mid <= acc_mid;
`ff_end

`ff_rst
	for (int i = 0; i < DIM; i++) begin
		acc_addr_mofs[i] <= '0;
	end
	acc_addr_mid <= '0;
`ff_cg(acc_addr_mofs_src_ack)
	acc_addr_mofs <= acc_mofs;
	acc_addr_mid <= '0;
`ff_end

always_ff @(posedge i_clk or negedge i_rst) for (int i = 0; i < LBUF_SIZE-1; i++) begin
	if (!i_rst) begin
		writer_warp_linear[i] <= '0;
		writer_warp_id[i] <= '0;
	end else if (linear_load_nxt[i] || linear_load_new[i]) begin
		writer_warp_linear[i] <= linear_load_new[i] ? writer_linear : writer_warp_linear[i+1];
		writer_warp_id[i] <= linear_load_new[i] ? writer_id : writer_warp_id[i+1];
	end
end

`ff_rst
	writer_warp_linear[LBUF_SIZE-1] <= '0;
	writer_warp_id[LBUF_SIZE-1] <= '0;
`ff_cg(linear_load_new[LBUF_SIZE-1])
	writer_warp_linear[LBUF_SIZE-1] <= writer_linear;
	writer_warp_id[LBUF_SIZE-1] <= writer_id;
`ff_end

endmodule
