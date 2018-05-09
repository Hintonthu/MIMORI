// Copyright 2018 Yu Sheng Lin

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
`include "common/OffsetStage.sv"
`include "common/Controllers.sv"

module ParallelBlockLooper(
	`clk_port,
	`rdyack_port(src),
	i_bgrid_step,
	i_bgrid_end,
	`rdyack_port(bofs),
	o_bofs,
	`dval_port(blkdone)
);
//======================================
// Parameter
//======================================
localparam WBW = TauCfg::WORK_BW;
localparam VDIM = TauCfg::VDIM;
localparam N_PENDING = TauCfg::MAX_PENDING_BLOCK;

//======================================
// I/O
//======================================
`clk_input;
`rdyack_input(src);
input [WBW-1:0] i_bgrid_step [VDIM];
input [WBW-1:0] i_bgrid_end  [VDIM];
`rdyack_output(bofs);
output logic [WBW-1:0] o_bofs [VDIM];
`dval_input(blkdone);

//======================================
// Internal
//======================================
`rdyack_logic(s0_src);
`rdyack_logic(s0_dst);
`rdyack_logic(s0_iflast);
`rdyack_logic(wait_fin);
logic block_full;
logic block_empty;

//======================================
// Combinational
//======================================
assign wait_fin_ack = wait_fin_rdy && block_empty;

//======================================
// Submodule
//======================================
BroadcastInorder#(2) u_brd(
	`clk_connect,
	`rdyack_connect(src, src),
	.dst_rdys({wait_fin_rdy, s0_src_rdy}),
	.dst_acks({wait_fin_ack, s0_src_ack})
);
OffsetStage#(.BW(WBW), .DIM(VDIM), .FROM_ZERO(1), .UNIT_STRIDE(0)) u_s0(
	`clk_connect,
	`rdyack_connect(src, s0_src),
	.i_ofs_beg(),
	.i_ofs_end(i_bgrid_end),
	.i_ofs_gend(),
	.i_stride(i_bgrid_step),
	`rdyack_connect(dst, s0_dst),
	.o_ofs(o_bofs),
	.o_lofs(),
	.o_sel_beg(),
	.o_sel_end(),
	.o_sel_ret(),
	.o_islast()
);
ForwardIf#(0) u_fwd_if_not_full(
	.cond(block_full),
	`rdyack_connect(src, s0_dst),
	`rdyack_connect(dst, bofs)
);
Semaphore#(N_PENDING) u_sem_done(
	`clk_connect,
	.i_inc(bofs_ack),
	.i_dec(blkdone_dval),
	.o_full(block_full),
	.o_empty(block_empty),
	.o_will_full(),
	.o_will_empty(),
	.o_n()
);

endmodule
