`ifndef __CONTROLLERS__
`define __CONTROLLERS__
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

module Forward(
	`clk_port,
	`rdyack_port(src),
	`rdyack_port(dst)
);
//======================================
// I/O
//======================================
`clk_input;
`rdyack_input(src);
`rdyack_output(dst);

//======================================
// Internal
//======================================
logic dst_rdy_w;

//======================================
// Combinational
//======================================
assign dst_rdy_w = src_rdy || (dst_rdy && !dst_ack);
assign src_ack = src_rdy && (!dst_rdy || dst_ack);

//======================================
// Sequential
//======================================
`ff_rst
	dst_rdy <= 1'b0;
`ff_nocg
	dst_rdy <= dst_rdy_w;
`ff_end

endmodule

module ForwardMulti(
	`clk_port,
	`rdyack_port(src),
	`rdyack_port(dst),
	acks
);

parameter NDATA = 2;

`clk_input;
`rdyack_input(src);
`rdyack_output(dst);
output logic [NDATA-1:0] acks;

logic can_ack;
logic [NDATA-1:0] rdy_r;
logic [NDATA-1:0] rdy_w;

always_comb begin
	dst_rdy = rdy_r[0];
	can_ack = !dst_rdy || dst_ack;
	src_ack = src_rdy && can_ack;
	if (can_ack) begin
		acks = {src_rdy, rdy_r[NDATA-1:1]};
		rdy_w = acks;
	end else begin
		acks = '0;
		rdy_w = rdy_r;
	end
end

always_ff @(posedge i_clk or negedge i_rst) begin
	if (!i_rst) begin
		rdy_r <= '0;
	end else if (can_ack) begin
		rdy_r <= rdy_w;
	end
end

endmodule

module ForwardSlow(
	`clk_port,
	`rdyack_port(src),
	`rdyack_port(dst)
);

//======================================
// I/O
//======================================
`clk_input;
`rdyack_input(src);
`rdyack_output(dst);

//======================================
// Internal
//======================================
logic dst_rdy_w;

//======================================
// Combinational
//======================================
assign dst_rdy_w = dst_rdy ? !dst_ack : src_rdy;
assign src_ack = !dst_rdy && src_rdy;

//======================================
// Sequential
//======================================
`ff_rst
	dst_rdy <= 1'b0;
`ff_nocg
	dst_rdy <= dst_rdy_w;
`ff_end

endmodule

module ForwardIf(
	cond,
	`rdyack_port(src),
	`rdyack_port(dst)
);
parameter COND_ = 1;
input cond;
`rdyack_input(src);
`rdyack_output(dst);
assign dst_rdy = src_rdy && (cond == (COND_&1));
assign src_ack = dst_ack;
endmodule

module AcceptIf(
	cond,
	`rdyack_port(src),
	`rdyack_port(dst)
);
parameter COND_ = 1;
input cond;
`rdyack_input(src);
`rdyack_output(dst);
assign dst_rdy = src_rdy;
assign src_ack = dst_ack && (cond == (COND_&1));
endmodule

module IgnoreIf(
	cond,
	`rdyack_port(src),
	`rdyack_port(dst),
	skipped
);
parameter COND_ = 1;
input cond;
`rdyack_input(src);
`rdyack_output(dst);
output skipped;
logic cond2;
assign cond2 = cond == (COND_&1);
assign dst_rdy = src_rdy && !cond2;
assign skipped = src_rdy && cond2;
assign src_ack = dst_ack || skipped;
endmodule

module OneCycleInit(
	`clk_port,
	`rdyack_port(src),
	`rdyack_port(dst),
	`dval_port(init)
);

//======================================
// I/O
//======================================
`clk_input;
`rdyack_input(src);
`rdyack_output(dst);
`dval_output(init);

//======================================
// Internal
//======================================
logic dst_rdy_w;

//======================================
// Combinational
//======================================
assign dst_rdy_w = dst_rdy ? !dst_ack : src_rdy;
assign src_ack = dst_ack;
assign init_dval = src_rdy && !dst_rdy;

//======================================
// Sequential
//======================================
`ff_rst
	dst_rdy <= 1'b0;
`ff_nocg
	dst_rdy <= dst_rdy_w;
`ff_end

endmodule

module Broadcast(
	`clk_port,
	`rdyack_port(src),
	acked,
	dst_rdys,
	dst_acks
);

//======================================
// Parameter
//======================================
parameter N = 2;

//======================================
// I/O
//======================================
`clk_input;
`rdyack_input(src);
output logic [N-1:0] acked;
output logic [N-1:0] dst_rdys;
input        [N-1:0] dst_acks;

//======================================
// Internal
//======================================
logic [N-1:0] acked_w;
logic [N-1:0] acked_nxt;

//======================================
// Combinational
//======================================
assign dst_rdys = src_rdy ? ~acked : '0;
assign acked_nxt = acked | dst_acks;
assign src_ack = &acked_nxt;
assign acked_w = src_ack ? '0 : acked_nxt;

//======================================
// Sequential
//======================================
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

//======================================
// Parameter
//======================================
parameter N = 2;

//======================================
// I/O
//======================================
`clk_input;
`rdyack_input(src);
output logic [N-1:0] dst_rdys;
input        [N-1:0] dst_acks;

//======================================
// Internal
//======================================
logic [N-1:0] dst_rdys_r;
logic [N-1:0] dst_rdys_w;

//======================================
// Combinational
//======================================
assign dst_rdys = src_rdy ? dst_rdys_r : '0;
always_comb begin
	src_ack = dst_acks[N-1];
	priority case ({src_ack, dst_acks[N-2:0]})
		2'b00: dst_rdys_w = dst_rdys_r;
		2'b10: dst_rdys_w = 'b1;
		2'b01: dst_rdys_w = dst_rdys_r<<1;
	endcase
end

//======================================
// Sequential
//======================================
`ff_rst
	dst_rdys_r <= 'b1;
`ff_nocg
	dst_rdys_r <= dst_rdys_w;
`ff_end

endmodule

module SFifoCtrl(
	`clk_port,
	`rdyack_port(src),
	`rdyack_port(dst),
	o_load_nxt,
	o_load_new
);

parameter NDATA = 2;

`clk_input;
`rdyack_input(src);
`rdyack_output(dst);
output logic [NDATA-2:0] o_load_nxt;
output logic [NDATA-1:0] o_load_new;

logic [NDATA-1:0] rdy_r;
logic [NDATA-1:0] rdy_w;
logic [NDATA  :0] is_last;

//======================================
// Combinational
//======================================
assign dst_rdy = rdy_r[0];
assign is_last = {rdy_r, 1'b1} & {1'b1, ~rdy_r};
assign src_ack = src_rdy & !is_last[NDATA];

always_comb begin
	o_load_nxt = dst_ack ? rdy_r[NDATA-1:1] : '0;
	case ({src_ack,dst_ack})
		2'b00: begin
			rdy_w = rdy_r;
			o_load_new = '0;
		end
		2'b01: begin
			rdy_w = rdy_r >> 1;
			o_load_new = '0;
		end
		2'b10: begin
			rdy_w = (rdy_r << 1) | 'b1;
			o_load_new = is_last[NDATA-1:0];
		end
		2'b11: begin
			rdy_w = rdy_r;
			o_load_new = is_last[NDATA:1];
		end
	endcase
end

//======================================
// Sequential
//======================================
always_ff @(posedge i_clk or negedge i_rst) begin
	if (!i_rst) begin
		rdy_r <= '0;
	end else if (src_ack^dst_ack) begin
		rdy_r <= rdy_w;
	end
end

endmodule

module Semaphore(
	`clk_port,
	i_inc,
	i_dec,
	o_full,
	o_empty
);

//======================================
// Parameter
//======================================
parameter N_MAX = 63;
// derived
localparam BW = $clog2(N_MAX+1);

//======================================
// I/O
//======================================
`clk_input;
input i_inc;
input i_dec;
output logic o_full;
output logic o_empty;

//======================================
// Internal
//======================================
logic [BW-1:0] pending_r;
logic [BW-1:0] pending_w;

//======================================
// Combinational
//======================================
assign o_full = pending_r == N_MAX;
assign o_empty = pending_r == '0;
always_comb begin
	case ({i_inc,i_dec})
		2'b10:        pending_w = pending_r + 'b1;
		2'b01:        pending_w = pending_r - 'b1;
		2'b11, 2'b00: pending_w = pending_r;
	endcase
end

//======================================
// Sequential
//======================================
`ff_rst
	pending_r <= '0;
`ff_cg(i_inc ^ i_dec)
	pending_r <= pending_w;
`ff_end

endmodule
`endif
