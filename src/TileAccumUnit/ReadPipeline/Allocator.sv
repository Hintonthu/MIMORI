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
	i_beg_id,
	i_end_id,
`ifdef SD
	i_syst_type,
	i_systolic_skip,
`endif
	// Used to emit address to address collector (FIFO'ed)
`ifdef VERI_TOP_Allocator
	`rdyack2_port(linear),
`else
	`rdyack_port(linear),
`endif
	o_linear,
	// Used to notify DMA something are allocated
	`rdyack_port(allocated),
	// Indicate SRAM is written, used to mark FIFO ready
	`dval_port(we),
	// Used to free
	`dval_port(free),
	i_free_id
`ifdef SD
	, i_false_free
`endif
);

//======================================
// Parameter
//======================================
parameter LBW = TauCfg::LOCAL_ADDR_BW0;
localparam DIM = TauCfg::DIM;
localparam N_ICFG = TauCfg::N_ICFG;
localparam [LBW:0] VSIZE = TauCfg::VSIZE;
localparam LBUF_SIZE = 5;
`ifdef SD
localparam STO_BW = TauCfg::STO_BW;
`endif
// derived
localparam CV_BW = $clog2(VSIZE);
localparam ICFG_BW = $clog2(N_ICFG+1);
localparam HBW = LBW-CV_BW;
localparam [HBW:0] CAPACITY = 1<<HBW;

//======================================
// I/O
//======================================
`clk_input;
input [HBW:0] i_sizes [N_ICFG];
`rdyack_input(alloc);
input [ICFG_BW-1:0] i_beg_id;
input [ICFG_BW-1:0] i_end_id;
`ifdef SD
input [STO_BW-1:0]  i_syst_type;
input [N_ICFG-1:0]  i_systolic_skip;
`endif
`ifdef VERI_TOP_Allocator
`rdyack2_output(linear);
`else
`rdyack_output(linear);
`endif
output logic [LBW-1:0]     o_linear;
`rdyack_output(allocated);
`dval_input(we);
`dval_input(free);
input [ICFG_BW-1:0] i_free_id;
`ifdef SD
input               i_false_free;
`endif

//======================================
// Allocate multiple linears
//======================================
`rdyack_logic(cnt);
logic cnt_done;
logic cnt_cg;
logic cnt_init;
logic cnt_false_alloc;
logic [ICFG_BW-1:0] cnt_id_r;
logic [ICFG_BW-1:0] cnt_id_w;
logic [ICFG_BW-1:0] cnt_id_1;
logic [HBW:0]       cnt_size;
logic [HBW-1:0] cur_r;
logic [HBW-1:0] cur_w;

`ifdef SD
always_comb begin
	cnt_false_alloc = i_systolic_skip[cnt_id_r] && `IS_FROM_SIDE(i_syst_type);
	cnt_size = cnt_false_alloc ? '0 : i_sizes[cnt_id_r];
end
`else
assign cnt_size = i_sizes[cnt_id_r];
`endif

LoopController#(.DONE_IF(1), .HOLD_SRC(1)) u_cnt_alloc_id(
	`clk_connect,
	`rdyack_connect(src, alloc),
	`rdyack_connect(dst, cnt),
	.loop_done_cond(cnt_done),
	.reg_cg(cnt_cg),
	.loop_reset(cnt_init),
	.loop_is_last(),
	.loop_is_repeat()
);

always_comb begin
	cnt_id_1 = cnt_id_r + 'b1;
	cnt_id_w = cnt_init ? i_beg_id : cnt_id_1;
	cnt_done = cnt_id_1 == i_end_id;
end

`ff_rst
	cnt_id_r <= '0;
`ff_cg(cnt_cg)
	cnt_id_r <= cnt_id_w;
`ff_end

`ff_rst
	cur_r <= '0;
`ff_cg(cnt_ack)
	cur_r <= cur_r + cnt_size[HBW-1:0];
`ff_end

//======================================
// Add data to FIFO
//======================================
// If FIFO is not full
`rdyack_logic(fifo_in);
`rdyack_logic(fifo_out);
logic linear_full;
logic linear_empty;
logic has_space;
logic can_alloc;
logic [HBW:0] capacity_r; // defined later
logic [HBW:0] capacity_w;
always_comb begin
	has_space = capacity_r >= cnt_size;
	can_alloc = has_space && !linear_full;
end
Semaphore#(LBUF_SIZE) u_sem_linear(
	`clk_connect,
	.i_inc(cnt_ack),
	.i_dec(allocated_ack),
	.o_full(linear_full),
	.o_empty(linear_empty),
	.o_will_full(),
	.o_will_empty(),
	.o_n()
);
PauseIf#(0) u_pause_until_alloc(
	.cond(can_alloc),
	`rdyack_connect(src, cnt),
	`rdyack_connect(dst, fifo_in)
);

//======================================
// FIFO
//======================================
logic [LBUF_SIZE-2:0] o_linears_load_nxt;
logic [LBUF_SIZE-1:0] o_linears_load_new;
logic [HBW-1:0]       o_linear_hi;
logic [HBW:0]         o_linear_size;
logic filled;
SFifoCtrl#(LBUF_SIZE) u_sfifo_ctrl_linear(
	`clk_connect,
	`rdyack_connect(src, fifo_in),
	`rdyack_connect(dst, fifo_out),
	.o_load_nxt(o_linears_load_nxt),
	.o_load_new(o_linears_load_new)
);
SFifoReg1D#(.BW(HBW), .NDATA(LBUF_SIZE)) u_sfifo_linear(
	`clk_connect,
	.i_load_nxt(o_linears_load_nxt),
	.i_load_new(o_linears_load_new),
	.i_data(cur_r),
	.o_data(o_linear_hi)
);
typedef logic [CV_BW-1:0] CV_BW_T;
assign o_linear = {o_linear_hi, CV_BW_T'(0)};
SFifoReg1D#(.BW(HBW+1), .NDATA(LBUF_SIZE)) u_sfifo_linear_size(
	`clk_connect,
	.i_load_nxt(o_linears_load_nxt),
	.i_load_new(o_linears_load_new),
	.i_data(cnt_size),
	.o_data(o_linear_size)
);
`ifdef SD
SFifoReg0D#(.NDATA(LBUF_SIZE)) u_sfifo_false_alloc(
	`clk_connect,
	.i_load_nxt(o_linears_load_nxt),
	.i_load_new(o_linears_load_new),
	.i_data(cnt_false_alloc),
	.o_data(o_false_alloc)
);
`endif
// If FIFO head is not ready
PauseIf#(0) u_pause_output_until_filled(
	.cond(filled),
	`rdyack_connect(src, fifo_out),
	`rdyack_connect(dst, linear)
);

//======================================
// Global counters (manage resource)
//======================================
logic [HBW:0] fsize;
logic [HBW:0] valid_num_r;
logic [HBW:0] valid_num_w;
`ifdef SD
assign fsize = i_false_free ? '0 : i_sizes[i_free_id];
`else
assign fsize = i_sizes[i_free_id];
`endif
always_comb begin
	// Tell DMA to work is there are something in FIFO
	allocated_rdy = !linear_empty;
	filled =
`ifdef SD
		o_false_alloc ||
`endif
		valid_num_r >= o_linear_size;
end

// Capacity
always_comb begin
	case({cnt_ack,free_dval})
		2'b00: capacity_w = capacity_r;
		2'b01: capacity_w = capacity_r            + fsize;
		2'b10: capacity_w = capacity_r - cnt_size;
		2'b11: capacity_w = capacity_r - cnt_size + fsize;
	endcase
end

// How many did we fill?
always_comb begin
	case({linear_ack,we_dval})
		2'b00: valid_num_w = valid_num_r;
		2'b01: valid_num_w = valid_num_r                 + 'b1;
		2'b10: valid_num_w = valid_num_r - o_linear_size;
		2'b11: valid_num_w = valid_num_r - o_linear_size + 'b1;
	endcase
end

`ff_rst
	capacity_r <= CAPACITY;
`ff_cg(cnt_ack||free_dval)
	capacity_r <= capacity_w;
`ff_end

`ff_rst
	valid_num_r <= '0;
`ff_cg(linear_ack||we_dval)
	valid_num_r <= valid_num_w;
`ff_end

endmodule
