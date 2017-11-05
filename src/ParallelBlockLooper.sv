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

import TauCfg::*;

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
`rdyack_logic(fin_seq);
`rdyack_logic(send_last);
`rdyack_logic(wait_fin);
logic block_full;
logic block_empty;
logic last_block;
logic [WBW-1:0] bofs_nxt [VDIM];

//======================================
// Combinational
//======================================
assign send_last_ack = s0_dst_ack;
assign wait_fin_ack = wait_fin_rdy && block_empty;

//======================================
// Submodule
//======================================
Broadcast#(2) u_brd_0(
	`clk_connect,
	`rdyack_connect(src, src),
	.acked(),
	.dst_rdys({fin_seq_rdy, s0_src_rdy}),
	.dst_acks({fin_seq_ack, s0_src_ack})
);
BroadcastInorder#(2) u_brd_1(
	`clk_connect,
	`rdyack_connect(src, fin_seq),
	.dst_rdys({wait_fin_rdy, send_last_rdy}),
	.dst_acks({wait_fin_ack, send_last_ack})
);
Forward u_s0(
	`clk_connect,
	`rdyack_connect(src, s0_src),
	`rdyack_connect(dst, s0_dst)
);
AcceptIf#(1) u_acc_if_last(
	.cond(last_block),
	`rdyack_connect(src, s0_dst),
	`rdyack_connect(dst, s0_iflast)
);
ForwardIf#(0) u_fwd_if_not_full(
	.cond(block_full),
	`rdyack_connect(src, s0_iflast),
	`rdyack_connect(dst, bofs)
);
Semaphore#(N_PENDING) u_sem_done(
	`clk_connect,
	.i_inc(bofs_ack),
	.i_dec(blkdone_dval),
	.o_full(block_full),
	.o_empty(block_empty)
);
NDAdder#(.BW(WBW), .DIM(VDIM), .FROM_ZERO(1), .UNIT_STRIDE(0)) u_adder(
	.i_restart(s0_src_ack),
	.i_cur(o_bofs),
	.i_cur_noofs(),
	.i_beg(),
	.i_stride(i_bgrid_step),
	.i_end(i_bgrid_end),
	.i_global_end(),
	.o_nxt(bofs_nxt),
	.o_nxt_noofs(),
	.o_sel_beg(),
	.o_sel_end(),
	.o_sel_ret(),
	.o_carry(last_block)
);

//======================================
// Sequential
//======================================
`ff_rst
	for (int i = 0; i < VDIM; i++) begin
		o_bofs[i] <= '0;
	end
`ff_cg(src_ack || s0_iflast_ack)
	o_bofs <= bofs_nxt;
`ff_end

endmodule
