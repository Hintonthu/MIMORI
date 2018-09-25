// Copyright 2016, 2018 Yu Sheng Lin

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
`include "common/TauCfg.sv"
`include "common/Controllers.sv"
`include "common/SFifo.sv"

// This module keeps info about
// 1. Next write after (increment high address after each write)
// 2. Space left (release after done)
// 3. Allocated address (emit them when we have write all of them)
module Allocator(
	`clk_port,
	i_sizes,
	// Used to allocate space
	`rdyack_port(alloc),
	i_alloc_id,
`ifdef SD
	i_false_alloc,
`endif
	// Used to emit address to address collector (FIFO'ed)
`ifdef VERI_TOP_Allocator
	`rdyack2_port(linear),
`else
	`rdyack_port(linear),
`endif
	o_linear,
`ifdef SD
	o_false_alloc,
`endif
	// Used to notify DMA something are allocated
	`rdyack_port(allocated),
	// Indicate SRAM is written, used to mark FIFO ready
	`dval_port(re),
	// Used to free
	`dval_port(free),
	i_free_id,
`ifdef SD
	i_false_free,
`endif
	`dval_port(blkdone)
`ifdef VERI_TOP_Allocator
	, lbw, capacity
`endif
);

//======================================
// Parameter
//======================================
parameter LBW = TauCfg::LOCAL_ADDR_BW0;
localparam N_ICFG = TauCfg::N_ICFG;
localparam [LBW:0] VSIZE = TauCfg::VSIZE;
localparam LBUF_SIZE = 5;
// derived
localparam ICFG_BW = $clog2(N_ICFG+1);
localparam [LBW:0] CAPACITY = 1<<LBW;

//======================================
// I/O
//======================================
`clk_input;
input [LBW:0] i_sizes [N_ICFG];
`rdyack_input(alloc);
input [ICFG_BW-1:0] i_alloc_id;
`ifdef SD
input               i_false_alloc;
`endif
`ifdef VERI_TOP_Allocator
`rdyack2_output(linear);
`else
`rdyack_output(linear);
`endif
output logic [LBW-1:0]     o_linear;
`ifdef SD
output logic               o_false_alloc;
`endif
`rdyack_output(allocated);
`dval_input(re);
`dval_input(free);
input [ICFG_BW-1:0] i_free_id;
`ifdef SD
input               i_false_free;
`endif
`dval_input(blkdone);
`ifdef VERI_TOP_Allocator
output logic [31:0]  lbw;
output logic [LBW:0] capacity;
`endif

//======================================
// Internal
//======================================
`rdyack_logic(fifo_in);
`rdyack_logic(fifo_out);
logic has_space;
logic can_alloc;
logic filling;
logic [LBUF_SIZE-2:0] o_linears_load_nxt;
logic [LBUF_SIZE-1:0] o_linears_load_new;
logic [LBW-1:0]       o_linears [LBUF_SIZE];
logic [LBW:0]         o_linear_sizes [LBUF_SIZE];
logic [LBW:0]         o_linear_size;
logic [LBUF_SIZE-1:0] o_false_allocs;
logic [LBW-1:0] cur_r;
logic [LBW-1:0] cur_w;
logic [LBW:0] capacity_r;
logic [LBW:0] capacity_w;
logic [LBW:0] valid_num_r;
logic [LBW:0] valid_num_w;
logic [LBW:0] asize;
logic [LBW:0] fsize;

//======================================
// Submodule
//======================================
Semaphore#(LBUF_SIZE) u_sem_linear(
	`clk_connect,
	.i_inc(alloc_ack),
	.i_dec(allocated_ack),
	.o_full(linear_full),
	.o_empty(linear_empty),
	.o_will_full(),
	.o_will_empty(),
	.o_n()
);
PauseIf#(0) u_pause_until_alloc(
	.cond(can_alloc),
	`rdyack_connect(src, alloc),
	`rdyack_connect(dst, fifo_in)
);
SFifoCtrl#(LBUF_SIZE) u_sfifo_ctrl_linear(
	`clk_connect,
	`rdyack_connect(src, fifo_in),
	`rdyack_connect(dst, fifo_out),
	.o_load_nxt(o_linears_load_nxt),
	.o_load_new(o_linears_load_new)
);
PauseIf#(0) u_pause_output_when_filling(
	.cond(filling),
	`rdyack_connect(src, fifo_out),
	`rdyack_connect(dst, linear)
);

//======================================
// Combinational
//======================================
`ifdef SD
assign asize = i_false_alloc ? '0 : i_sizes[i_alloc_id];
assign fsize = i_false_free  ? '0 : i_sizes[i_free_id];
assign o_false_alloc = o_false_allocs[0];
`else
assign asize = i_sizes[i_alloc_id];
assign fsize = i_sizes[i_free_id];
`endif
assign o_linear = o_linears[0];
assign o_linear_size = o_linear_sizes[0];
always_comb begin
	has_space = capacity_r >= asize;
	can_alloc = has_space && !linear_full;
	allocated_rdy = !linear_empty;
	filling = 
`ifdef SD
		!o_false_alloc &&
`endif
		valid_num_r >= o_linear_size;
	cur_w = blkdone_dval ? '0 : cur_r + asize[LBW-1:0];
end

always_comb begin
	case({alloc_ack,free_dval})
		2'b00: capacity_w = capacity_r;
		2'b01: capacity_w = capacity_r         + fsize;
		2'b10: capacity_w = capacity_r - asize;
		2'b11: capacity_w = capacity_r - asize + fsize;
	endcase
end

always_comb begin
	case({linear_ack,re_dval})
		2'b00: valid_num_w = valid_num_r;
		2'b01: valid_num_w = valid_num_r                 + VSIZE;
		2'b10: valid_num_w = valid_num_r - o_linear_size;
		2'b11: valid_num_w = valid_num_r - o_linear_size + VSIZE;
	endcase
end

//======================================
// Sequential
//======================================

`ff_rst
	capacity_r <= CAPACITY;
`ff_cg(alloc_ack||free_dval)
	capacity_r <= capacity_w;
`ff_end

`ff_rst
	valid_num_r <= '0;
`ff_cg(linear_ack||re_dval)
	valid_num_r <= valid_num_w;
`ff_end

`ff_rst
	cur_r <= '0;
`ff_cg(alloc_ack)
	cur_r <= cur_w;
`ff_end

genvar gi;
generate for (gi = 0; gi < LBUF_SIZE-1; gi++) begin: warp_linear_fifo
always_ff @(posedge i_clk or negedge i_rst) begin
	if (!i_rst) begin
		o_linears[gi] <= '0;
		o_linear_sizes[gi] <= '0;
`ifdef SD
		o_false_allocs[gi] <= 1'b0;
`endif
	end else if (o_linears_load_nxt[gi] || o_linears_load_new[gi]) begin
		if (o_linears_load_new[gi]) begin
			o_linears[gi] <= cur_r;
			o_linear_sizes[gi] <= asize;
`ifdef SD
			o_false_allocs[gi] <= i_false_alloc;
`endif
		end else begin
			o_linears[gi] <= o_linears[gi+1];
			o_linear_sizes[gi] <= o_linear_sizes[gi+1];
`ifdef SD
			o_false_allocs[gi] <= o_false_allocs[gi+1];
`endif
		end
	end
end
end endgenerate

`ff_rst
	o_linears[LBUF_SIZE-1] <= '0;
	o_linear_sizes[LBUF_SIZE-1] <= '0;
`ifdef SD
	o_linear_sizes[LBUF_SIZE-1] <= '0;
`endif
`ff_cg(o_linears_load_new[LBUF_SIZE-1])
	o_linears[LBUF_SIZE-1] <= cur_r;
	o_linear_sizes[LBUF_SIZE-1] <= asize;
`ifdef SD
	o_false_allocs[LBUF_SIZE-1] <= i_false_alloc;
`endif
`ff_end

`ifdef VERI_TOP_Allocator
assign lbw = LBW;
assign capacity = capacity_r;
`endif

endmodule
