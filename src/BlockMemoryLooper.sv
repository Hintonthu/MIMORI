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
import Default::*;

module BlockMemoryLooper(
	`clk_port,
	`rdyack_port(src),
	i_bgrid_frac,
	i_bgrid_shamt,
	i_bgrid_last,
	i_i0_mofs_starts,
	i_i0_mofs_steps,
	i_i0_mofs_shufs,
	i_i0_id_end,
	i_i1_mofs_starts,
	i_i1_mofs_steps,
	i_i1_mofs_shufs,
	i_i1_id_end,
	i_o_mofs_linears,
	i_o_mofs_steps,
	i_o_id_end,
	`rdyack_port(bofs),
	o_bofs,
	`rdyack_port(i0_mofs),
	o_i0_mofs,
	`rdyack_port(i1_mofs),
	o_i1_mofs,
	`rdyack_port(o_mofs),
	o_o_mofs,
	`dval_port(blkdone)
);

//======================================
// Parameter
//======================================
localparam WBW = TauCfg::WORK_BW;
localparam GBW = TauCfg::GLOBAL_ADDR_BW;
localparam DIM = TauCfg::DIM;
localparam N_ICFG = TauCfg::N_ICFG;
localparam N_OCFG = TauCfg::N_OCFG;
localparam BF_BW = TauCfg::BOFS_FRAC_BW;
localparam BS_BW = TauCfg::BOFS_SHAMT_BW;
localparam N_PENDING = Default::N_PENDING;
// derived
localparam ICFG_BW = $clog2(N_ICFG+1);
localparam OCFG_BW = $clog2(N_OCFG+1);
localparam DIM_BW = $clog2(DIM);
localparam PENDING_BW = $clog2(N_PENDING+1);
// Workaround
logic [WBW-1:0] ND_WZERO [DIM] = '{default:0};
logic [GBW-1:0] ND_AZERO [DIM] = '{default:0};

//======================================
// I/O
//======================================
`clk_input;
`rdyack_input(src);
input [BF_BW-1:0]   i_bgrid_frac       [DIM];
input [BS_BW-1:0]   i_bgrid_shamt      [DIM];
input [WBW-1:0]     i_bgrid_last       [DIM];
input [GBW-1:0]     i_i0_mofs_steps  [N_ICFG][DIM];
input [GBW-1:0]     i_i0_mofs_starts [N_ICFG][DIM];
input [DIM_BW-1:0]  i_i0_mofs_shufs  [N_ICFG][DIM];
input [ICFG_BW-1:0] i_i0_id_end;
input [GBW-1:0]     i_i1_mofs_steps  [N_ICFG][DIM];
input [GBW-1:0]     i_i1_mofs_starts [N_ICFG][DIM];
input [DIM_BW-1:0]  i_i1_mofs_shufs  [N_ICFG][DIM];
input [ICFG_BW-1:0] i_i1_id_end;
input [GBW-1:0]     i_o_mofs_steps   [N_OCFG][DIM];
input [GBW-1:0]     i_o_mofs_linears [N_OCFG][1];
input [OCFG_BW-1:0] i_o_id_end;
`rdyack_output(bofs);
output [WBW-1:0] o_bofs [DIM];
`rdyack_output(i0_mofs);
output [GBW-1:0] o_i0_mofs [DIM];
`rdyack_output(i1_mofs);
output [GBW-1:0] o_i1_mofs [DIM];
`rdyack_output(o_mofs);
output [GBW-1:0] o_o_mofs [1];
`dval_input(blkdone);

//======================================
// Internal
//======================================
`rdyack_logic(s0_src);
`rdyack_logic(s0_dst_raw);
`rdyack_logic(s0_dst);
`rdyack_logic(wait_fin);
`rdyack_logic(s01_i0);
`rdyack_logic(s01_i1);
`rdyack_logic(s01_o);
`rdyack_logic(s01_mask_i0);
`rdyack_logic(s01_mask_i1);
`rdyack_logic(s01_mask_o);
`rdyack_logic(s12_i0);
`rdyack_logic(s12_i1);
`rdyack_logic(s12_o);
logic [DIM-1:0]     s01_reset_flag;
logic [DIM-1:0]     s01_add_flag;
logic [DIM-1:0]     s12_i0_reset_flag;
logic [DIM-1:0]     s12_i0_add_flag;
logic [DIM-1:0]     s12_i1_reset_flag;
logic [DIM-1:0]     s12_i1_add_flag;
logic [DIM-1:0]     s12_o_reset_flag;
logic [DIM-1:0]     s12_o_add_flag;
logic               s12_islast;
logic [ICFG_BW-1:0] s12_i0_id;
logic [ICFG_BW-1:0] s12_i1_id;
logic [OCFG_BW-1:0] s12_o_id;
logic s01_islast;
logic s12_i0_islast;
logic s12_i1_islast;
logic s12_o_islast;
logic i0_z;
logic i1_z;
logic o_z;
logic [1:0] brd0_acked;
logic block_full;
logic block_empty;

//======================================
// Combinational
//======================================
assign i0_z = i_i0_id_end == '0;
assign i1_z = i_i1_id_end == '0;
assign o_z = i_o_id_end == '0;
assign wait_fin_ack = brd0_acked[0] && block_empty;

//======================================
// Submodule
//======================================
// src --> s0_src, wait_fin
Broadcast#(2) u_brd0(
	`clk_connect,
	`rdyack_connect(src, src),
	.acked(brd0_acked),
	.dst_rdys({wait_fin_rdy,s0_src_rdy}),
	.dst_acks({wait_fin_ack,s0_src_ack})
);
// s0_dst --broadcast-->
// 1) three s01_* --masked--> s01_mask_*
// 2) bofs
Broadcast#(4) u_brd1(
	`clk_connect,
	`rdyack_connect(src, s0_dst),
	.acked(),
	.dst_rdys({bofs_rdy,s01_i0_rdy,s01_i1_rdy,s01_o_rdy}),
	.dst_acks({bofs_ack,s01_i0_ack,s01_i1_ack,s01_o_ack})
);
ForwardIf#(0) u_fwd_if_not_full(
	.cond(block_full),
	`rdyack_connect(src, s0_dst_raw),
	`rdyack_connect(dst, s0_dst)
);
IgnoreIf u_ig_0(
	.cond(i0_z),
	`rdyack_connect(src, s01_i0),
	`rdyack_connect(dst, s01_mask_i0)
);
IgnoreIf u_ig_1(
	.cond(i1_z),
	`rdyack_connect(src, s01_i1),
	`rdyack_connect(dst, s01_mask_i1)
);
IgnoreIf u_ig_o(
	.cond(o_z),
	`rdyack_connect(src, s01_o),
	`rdyack_connect(dst, s01_mask_o)
);
OffsetStage#(.FRAC_BW(BF_BW), .SHAMT_BW(BS_BW)) u_ofs(
	`clk_connect,
	`rdyack_connect(src, s0_src),
	.i_ofs_frac(i_bgrid_frac),
	.i_ofs_shamt(i_bgrid_shamt),
	.i_ofs_local_start(ND_WZERO),
	.i_ofs_local_last(i_bgrid_last),
	.i_ofs_global_last(i_bgrid_last),
	`rdyack_connect(dst, s0_dst_raw),
	.o_ofs(o_bofs),
	.o_reset_flag(s01_reset_flag),
	.o_add_flag(s01_add_flag),
	.o_sel_beg(),
	.o_sel_end(),
	.o_sel_ret(),
	.o_islast(s01_islast)
);
IndexStage#(.N_CFG(N_ICFG), .BLOCK_MODE(1)) u_s1_idx_i0(
	`clk_connect,
	`rdyack_connect(src, s01_mask_i0),
	.i_reset_flag(s01_reset_flag),
	.i_add_flag(s01_add_flag),
	.i_id_beg(),
	.i_id_end(i_i0_id_end),
	.i_islast(s01_islast),
	`rdyack_connect(dst, s12_i0),
	.o_reset_flag(s12_i0_reset_flag),
	.o_add_flag(s12_i0_add_flag),
	.o_id(s12_i0_id),
	.o_islast(s12_i0_islast)
);
IndexStage#(.N_CFG(N_ICFG), .BLOCK_MODE(1)) u_s1_idx_i1(
	`clk_connect,
	`rdyack_connect(src, s01_mask_i1),
	.i_reset_flag(s01_reset_flag),
	.i_add_flag(s01_add_flag),
	.i_id_beg(),
	.i_id_end(i_i1_id_end),
	.i_islast(s01_islast),
	`rdyack_connect(dst, s12_i1),
	.o_reset_flag(s12_i1_reset_flag),
	.o_add_flag(s12_i1_add_flag),
	.o_id(s12_i1_id),
	.o_islast(s12_i1_islast)
);
IndexStage#(.N_CFG(N_OCFG), .BLOCK_MODE(1)) u_s1_idx_o(
	`clk_connect,
	`rdyack_connect(src, s01_mask_o),
	.i_reset_flag(s01_reset_flag),
	.i_add_flag(s01_add_flag),
	.i_id_beg(),
	.i_id_end(i_o_id_end),
	.i_islast(s01_islast),
	`rdyack_connect(dst, s12_o),
	.o_reset_flag(s12_o_reset_flag),
	.o_add_flag(s12_o_add_flag),
	.o_id(s12_o_id),
	.o_islast(s12_o_islast)
);
MemofsStage #(
	.N_CFG(N_ICFG),
	.FRAC_BW(BF_BW),
	.SHAMT_BW(BS_BW),
	.SUM_ALL(0)
) u_s2_mofs_i0 (
	`clk_connect,
	`rdyack_connect(src, s12_i0),
	.i_bofs_frac(i_bgrid_frac),
	.i_bofs_shamt(i_bgrid_shamt),
	.i_mofs_starts(i_i0_mofs_starts),
	.i_mofs_steps(i_i0_mofs_steps),
	.i_mofs_shufs(i_i0_mofs_shufs),
	.i_reset_flag(s12_i0_reset_flag),
	.i_add_flag(s12_i0_add_flag),
	.i_islast(s12_i0_islast),
	.i_id(s12_i0_id),
	`rdyack_connect(dst, i0_mofs),
	.o_mofs(o_i0_mofs),
	.o_id(),
	`dval_unconnect(islast)
);
MemofsStage #(
	.N_CFG(N_ICFG),
	.FRAC_BW(BF_BW),
	.SHAMT_BW(BS_BW),
	.SUM_ALL(0)
) u_s2_mofs_i1 (
	`clk_connect,
	`rdyack_connect(src, s12_i1),
	.i_bofs_frac(i_bgrid_frac),
	.i_bofs_shamt(i_bgrid_shamt),
	.i_mofs_starts(i_i1_mofs_starts),
	.i_mofs_steps(i_i1_mofs_steps),
	.i_mofs_shufs(i_i1_mofs_shufs),
	.i_reset_flag(s12_i1_reset_flag),
	.i_add_flag(s12_i1_add_flag),
	.i_islast(s12_i1_islast),
	.i_id(s12_i1_id),
	`rdyack_connect(dst, i1_mofs),
	.o_mofs(o_i1_mofs),
	.o_id(),
	`dval_unconnect(islast)
);
MemofsStage #(
	.N_CFG(N_OCFG),
	.FRAC_BW(BF_BW),
	.SHAMT_BW(BS_BW),
	.SUM_ALL(1)
) u_s2_mofs_o (
	`clk_connect,
	`rdyack_connect(src, s12_o),
	.i_bofs_frac(i_bgrid_frac),
	.i_bofs_shamt(i_bgrid_shamt),
	.i_mofs_starts(i_o_mofs_linears),
	.i_mofs_steps(i_o_mofs_steps),
	.i_mofs_shufs(),
	.i_reset_flag(s12_o_reset_flag),
	.i_add_flag(s12_o_add_flag),
	.i_islast(s12_o_islast),
	.i_id(s12_o_id),
	`rdyack_connect(dst, o_mofs),
	.o_mofs(o_o_mofs),
	.o_id(),
	`dval_unconnect(islast)
);
Semaphore#(N_PENDING) u_sem_done(
	`clk_connect,
	.i_inc(s0_dst_ack),
	.i_dec(blkdone_dval),
	.o_full(block_full),
	.o_empty(block_empty)
);

endmodule
