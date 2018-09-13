`ifndef __CONTROLLERS__
`define __CONTROLLERS__
// Copyright 2016,2018 Yu Sheng Lin

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

module Forward(
	`clk_port,
	`rdyack_port(src),
	`rdyack_port(dst)
);
parameter bit SLOW = 0;
`clk_input;
`rdyack_input(src);
`rdyack_output(dst);
logic dst_rdy_w;
always_comb begin
	dst_rdy_w = (src_rdy && !(SLOW && dst_rdy)) || (dst_rdy && !dst_ack);
	src_ack = (!dst_rdy || (!SLOW && dst_ack)) && src_rdy;
end
`ff_rst
	dst_rdy <= 1'b0;
`ff_nocg
	dst_rdy <= dst_rdy_w;
`ff_end
endmodule

module PauseIf(
	cond,
	`rdyack_port(src),
	`rdyack_port(dst)
);
parameter bit COND_ = 1;
input cond;
`rdyack_input(src);
`rdyack_output(dst);
assign dst_rdy = src_rdy && (cond != COND_);
assign src_ack = dst_ack;
endmodule

module RepeatIf(
	cond,
	`rdyack_port(src),
	`rdyack_port(dst),
	repeated
);
parameter bit COND_ = 1;
input cond;
`rdyack_input(src);
`rdyack_output(dst);
output logic repeated;
logic rep;
always_comb begin
	rep = cond == COND_;
	dst_rdy = src_rdy;
	src_ack = dst_ack && !rep;
	repeated = dst_ack && rep;
end
endmodule

module DeleteIf(
	cond,
	`rdyack_port(src),
	`rdyack_port(dst),
	deleted
);
parameter COND_ = 1;
input cond;
`rdyack_input(src);
`rdyack_output(dst);
output logic deleted;
logic del;
always_comb begin
	del = cond == COND_;
	dst_rdy = src_rdy && !del;
	deleted = src_rdy && del;
	src_ack = dst_ack || deleted;
end
endmodule

module Broadcast(
	`clk_port,
	`rdyack_port(src),
	dst_rdys,
	dst_acks
);
parameter N = 2;
`clk_input;
`rdyack_input(src);
output logic [N-1:0] dst_rdys;
input        [N-1:0] dst_acks;
logic [N-1:0] acked;
logic [N-1:0] acked_w;
logic [N-1:0] acked_nxt;
assign dst_rdys = src_rdy ? ~acked : '0;
assign acked_nxt = acked | dst_acks;
assign src_ack = &acked_nxt;
assign acked_w = src_ack ? '0 : acked_nxt;
`ff_rst
	acked <= '0;
`ff_nocg
	acked <= acked_w;
`ff_end
endmodule

module BroadcastInorder(
	`clk_port,
	`rdyack_port(src),
	dst_rdys,
	dst_acks
);
parameter N = 2;
`clk_input;
`rdyack_input(src);
output logic [N-1:0] dst_rdys;
input        [N-1:0] dst_acks;
logic sent;
logic [N-1:0] dst_rdys_r;
logic [N-1:0] dst_rdys_w;
assign dst_rdys = src_rdy ? dst_rdys_r : '0;
always_comb begin
	src_ack = dst_acks[N-1];
	sent = |dst_acks;
	dst_rdys_w = {dst_rdys_r[N-2:0], dst_rdys_r[N-1]};
end
`ff_rst
	dst_rdys_r <= 'b1;
`ff_cg(sent)
	dst_rdys_r <= dst_rdys_w;
`ff_end
endmodule

module LoopController(
	`clk_port,
	`rdyack_port(src),
	`rdyack_port(dst),
	loop_done_cond,
	reg_cg,
	loop_reset,
	loop_is_last,
	loop_is_repeat
);
parameter bit DONE_IF = 1;
parameter bit HOLD_SRC = 1;
`clk_input;
`rdyack_input(src);
`rdyack_output(dst);
input  logic loop_done_cond;
output logic reg_cg;
output logic loop_reset;
output logic loop_is_last;
output logic loop_is_repeat;
`rdyack_logic(loop);
assign reg_cg = loop_reset || loop_is_repeat;
assign loop_is_last = loop_ack;
generate if (HOLD_SRC) begin: HoldSourceDataDuringLoop
	BroadcastInorder#(2) u_brd(
		`clk_connect,
		`rdyack_connect(src, src),
		.dst_rdys({loop_rdy,loop_reset}),
		.dst_acks({loop_ack,loop_reset})
	);
end else begin: AcceptSourceDataBeforeLoop
	Forward u_fwd(
		`clk_connect,
		`rdyack_connect(src, src),
		`rdyack_connect(dst, loop)
	);
	assign loop_reset = src_ack;
end endgenerate
RepeatIf#(~DONE_IF) u_rep(
	.cond(loop_done_cond),
	`rdyack_connect(src, loop),
	`rdyack_connect(dst, dst),
	.repeated(loop_is_repeat)
);
endmodule

module Semaphore(
	`clk_port,
	i_inc,
	i_dec,
	o_full,
	o_empty,
	o_will_full,
	o_will_empty,
	o_n
);
parameter N_MAX = 63;
localparam BW = $clog2(N_MAX+1);
`clk_input;
input i_inc;
input i_dec;
output logic o_full;
output logic o_empty;
output logic o_will_full;
output logic o_will_empty;
output logic [BW-1:0] o_n;
logic [BW-1:0] o_n_w;
assign o_full = o_n == N_MAX;
assign o_empty = o_n == '0;
assign o_will_full = o_n_w == N_MAX;
assign o_will_empty = o_n_w == '0;
always_comb begin
	case ({i_inc,i_dec})
		2'b10:        o_n_w = o_n + 'b1;
		2'b01:        o_n_w = o_n - 'b1;
		2'b11, 2'b00: o_n_w = o_n;
	endcase
end
`ff_rst
	o_n <= '0;
`ff_cg(i_inc ^ i_dec)
	o_n <= o_n_w;
`ff_end
endmodule

module FlowControl(
	`clk_port,
	`rdyack_port(src),
	`rdyack_port(dst),
	`dval_port(fin),
	`rdyack_port(wait_all)
);
parameter N_MAX = 63;
`clk_input;
`rdyack_input(src);
`rdyack_output(dst);
`dval_input(fin);
`rdyack_input(wait_all);
logic sfull, sempty;
Semaphore#(N_MAX) u_sem(
	`clk_connect,
	.i_inc(dst_ack),
	.i_dec(fin_dval),
	.o_full(sfull),
	.o_empty(sempty),
	.o_will_full(),
	.o_will_empty(),
	.o_n()
);
PauseIf#(1) u_pause_full(
	.cond(sfull),
	`rdyack_connect(src, src),
	`rdyack_connect(dst, dst)
);
assign wait_all_ack = wait_all_rdy & sempty;
endmodule

`endif
