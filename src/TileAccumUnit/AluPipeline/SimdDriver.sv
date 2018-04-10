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
`include "common/ND.sv"
`include "common/Controllers.sv"
`include "TileAccumUnit/common/AccumWarpLooper/AccumWarpLooperIndexStage.sv"

module SimdDriver(
	`clk_port,
	`rdyack_port(abofs),
	i_bofs,
	i_aofs_beg,
	i_aofs_end,
	i_bgrid_step,
	i_bsub_up_order,
	i_bsub_lo_order,
	i_aboundary,
	i_inst_id_begs,
	i_inst_id_ends,
	`rdyack_port(inst),
	o_bofs,
	o_aofs,
	o_pc,
	o_warpid,
	`dval_port(inst_commit)
);

//======================================
// Parameter
//======================================
localparam N_INST = TauCfg::N_INST;
localparam WBW = TauCfg::WORK_BW;
localparam VDIM = TauCfg::VDIM;
localparam VSIZE = TauCfg::VSIZE;
localparam N_PENDING = TauCfg::MAX_PENDING_INST;
localparam MAX_WARP = TauCfg::MAX_WARP;
// derived
localparam INST_BW = $clog2(N_INST+1);
localparam CV_BW = $clog2(VSIZE);
localparam CCV_BW = $clog2(CV_BW+1);
localparam WID_BW = $clog2(MAX_WARP);

//======================================
// I/O
//======================================
`clk_input;
`rdyack_input(abofs);
input [WBW-1:0]     i_bofs          [VDIM];
input [WBW-1:0]     i_aofs_beg      [VDIM];
input [WBW-1:0]     i_aofs_end      [VDIM];
input [WBW-1:0]     i_bgrid_step    [VDIM];
input [CCV_BW-1:0]  i_bsub_up_order [VDIM];
input [CCV_BW-1:0]  i_bsub_lo_order [VDIM];
input [WBW-1:0]     i_aboundary     [VDIM];
input [INST_BW-1:0] i_inst_id_begs [VDIM+1];
input [INST_BW-1:0] i_inst_id_ends [VDIM+1];
`rdyack_output(inst);
output [WBW-1:0]     o_bofs [VDIM];
output [WBW-1:0]     o_aofs [VDIM];
output [INST_BW-1:0] o_pc;
output [WID_BW-1:0]  o_warpid;
`dval_input(inst_commit);

//======================================
// Internal
//======================================
`rdyack_logic(brd1);
`rdyack_logic(wait_fin);
`rdyack_logic(wait_last);
`rdyack_logic(s0_src);
`rdyack_logic(s0_dst);
`rdyack_logic(s1_src);
`rdyack_logic(s1_dst);
logic [WBW-1:0] s01_aofs [VDIM];
logic [VDIM:0] s01_sel_beg;
logic [VDIM:0] s01_sel_end;
logic [INST_BW-1:0] s01_id_beg;
logic [INST_BW-1:0] s01_id_end;
logic s01_islast;
logic s01_bypass;
logic s01_skipped;
logic s1_islast;
logic inst_full;
logic inst_empty;

//======================================
// Combinational
//======================================
assign s01_bypass = s01_id_beg == s01_id_end;
assign wait_last_ack = wait_last_rdy && (s01_islast && s01_skipped || s1_islast && s1_dst_ack);
assign wait_fin_ack = wait_fin_rdy && inst_empty;

//======================================
// Submodule
//======================================
BroadcastInorder#(2) u_brd0(
	`clk_connect,
	`rdyack_connect(src, abofs),
	.dst_rdys({wait_fin_rdy, brd1_rdy}),
	.dst_acks({wait_fin_ack, brd1_ack})
);
Broadcast#(2) u_brd1(
	`clk_connect,
	`rdyack_connect(src, brd1),
	.dst_rdys({wait_last_rdy, s0_src_rdy}),
	.dst_acks({wait_last_ack, s0_src_ack})
);
OffsetStage#(.BW(WBW), .DIM(VDIM), .FROM_ZERO(0), .UNIT_STRIDE(1)) u_s0_ofs(
	`clk_connect,
	`rdyack_connect(src, s0_src),
	.i_ofs_beg(i_aofs_beg),
	.i_ofs_end(i_aofs_end),
	.i_ofs_gend(i_aboundary),
	.i_stride(),
	`rdyack_connect(dst, s0_dst),
	.o_ofs(s01_aofs),
	.o_lofs(),
	.o_sel_beg(s01_sel_beg),
	.o_sel_end(s01_sel_end),
	.o_sel_ret(),
	.o_islast(s01_islast)
);
IdSelect#(.BW(INST_BW), .DIM(VDIM), .RETIRE(0)) u_s0_sel_beg(
	.i_sel(s01_sel_beg),
	.i_begs(i_inst_id_begs),
	.i_ends(),
	.o_dat(s01_id_beg)
);
IdSelect#(.BW(INST_BW), .DIM(VDIM), .RETIRE(0)) u_s0_sel_end(
	.i_sel(s01_sel_end),
	.i_begs(i_inst_id_ends),
	.i_ends(),
	.o_dat(s01_id_end)
);
AccumWarpLooperIndexStage#(.N_CFG(N_INST)) u_s1_idx(
	`clk_connect,
	`rdyack_connect(src, s1_src),
	.i_bofs(i_bofs),
	.i_aofs(s01_aofs),
	.i_islast(s01_islast),
	.i_id_beg(s01_id_beg),
	.i_id_end(s01_id_end),
	.i_id_ret(),
	.i_bgrid_step(i_bgrid_step),
	.i_bsub_up_order(i_bsub_up_order),
	.i_bsub_lo_order(i_bsub_lo_order),
	`rdyack_connect(dst, s1_dst),
	.o_id(o_pc),
	.o_warpid(o_warpid),
	.o_bofs(o_bofs),
	.o_aofs(o_aofs),
	.o_blofs(),
	.o_alofs(),
	.o_retire(),
	.o_islast(s1_islast)
);
Semaphore#(N_PENDING) u_sem_inst(
	`clk_connect,
	.i_inc(inst_ack),
	.i_dec(inst_commit_dval),
	.o_full(inst_full),
	.o_empty(inst_empty)
);
IgnoreIf#(1) u_ign_if_noinst(
	.cond(s01_bypass),
	`rdyack_connect(src, s0_dst),
	`rdyack_connect(dst, s1_src),
	.skipped(s01_skipped)
);
ForwardIf#(0) u_issue_inst_if(
	.cond(inst_full),
	`rdyack_connect(src, s1_dst),
	`rdyack_connect(dst, inst)
);

endmodule
