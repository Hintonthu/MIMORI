`ifndef __SFIFO__
`define __SFIFO__
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
`include "common/Controllers.sv"
`include "common/SRAM.sv"

////////////////////////////////////////////////////
// 1. Use SFifoCtrl + SFifoRegND to create an ND-fifo.
//    (0D: one bit)
// 2. Use SFifo (1D only) for configuring reg/single/two-port
////////////////////////////////////////////////////

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

module SFifoReg0D(
	`clk_port,
	i_load_nxt,
	i_load_new,
	i_data,
	o_data
);
parameter NDATA = 2;
`clk_input;
input  logic [NDATA-2:0] i_load_nxt;
input  logic [NDATA-1:0] i_load_new;
input  logic i_data;
output logic o_data;

logic [NDATA-1:0] data_r;
assign o_data = data_r[0];
genvar gi;
for (gi = 0; gi < NDATA-1; gi++) begin: fifo_storage
	always_ff @(posedge i_clk or negedge i_rst) begin
		if (!i_rst) begin
			data_r[gi] <= '0;
		end else if (i_load_nxt[gi] || i_load_new[gi]) begin
			data_r[gi] <= i_load_new[gi] ? i_data : data_r[gi+1];
		end
	end
end

`ff_rst
	data_r[NDATA-1] <= '0;
`ff_cg(i_load_new[NDATA-1])
	data_r[NDATA-1] <= i_data;
`ff_end
endmodule

module SFifoReg1D(
	`clk_port,
	i_load_nxt,
	i_load_new,
	i_data,
	o_data
);
parameter BW = 8;
parameter NDATA = 2;
`clk_input;
input  logic [NDATA-2:0] i_load_nxt;
input  logic [NDATA-1:0] i_load_new;
input  logic [BW-1:0] i_data;
output logic [BW-1:0] o_data;

logic [BW-1:0] data_r [NDATA];
assign o_data = data_r[0];
genvar gi;
for (gi = 0; gi < NDATA-1; gi++) begin: fifo_storage
	always_ff @(posedge i_clk or negedge i_rst) begin
		if (!i_rst) begin
			data_r[gi] <= '0;
		end else if (i_load_nxt[gi] || i_load_new[gi]) begin
			data_r[gi] <= i_load_new[gi] ? i_data : data_r[gi+1];
		end
	end
end

`ff_rst
	data_r[NDATA-1] <= '0;
`ff_cg(i_load_new[NDATA-1])
	data_r[NDATA-1] <= i_data;
`ff_end
endmodule

module SFifoReg2D(
	`clk_port,
	i_load_nxt,
	i_load_new,
	i_data,
	o_data
);
parameter BW = 8;
parameter NDATA = 2;
parameter D0 = 2;
`clk_input;
input  logic [NDATA-2:0] i_load_nxt;
input  logic [NDATA-1:0] i_load_new;
input  logic [BW-1:0] i_data [D0];
output logic [BW-1:0] o_data [D0];

logic [BW-1:0] data_r [NDATA][D0];
assign o_data = data_r[0];
genvar gi;
for (gi = 0; gi < NDATA-1; gi++) begin: fifo_storage
	always_ff @(posedge i_clk or negedge i_rst) begin
		if (!i_rst) begin
			for (int i = 0; i < D0; i++) begin
				data_r[gi][i] <= '0;
			end
		end else if (i_load_nxt[gi] || i_load_new[gi]) begin
			for (int i = 0; i < D0; i++) begin
				data_r[gi][i] <= i_load_new[gi] ? i_data[i] : data_r[gi+1][i];
			end
		end
	end
end

`ff_rst
	for (int i = 0; i < D0; i++) begin
		data_r[NDATA-1][i] <= '0;
	end
`ff_cg(i_load_new[NDATA-1])
	for (int i = 0; i < D0; i++) begin
		data_r[NDATA-1][i] <= i_data[i];
	end
`ff_end
endmodule

module SFifoReg3D(
	`clk_port,
	i_load_nxt,
	i_load_new,
	i_data,
	o_data
);
parameter BW = 8;
parameter NDATA = 2;
parameter D0 = 2;
parameter D1 = 2;
`clk_input;
input  logic [NDATA-2:0] i_load_nxt;
input  logic [NDATA-1:0] i_load_new;
input  logic [BW-1:0] i_data [D0][D1];
output logic [BW-1:0] o_data [D0][D1];

logic [BW-1:0] data_r [NDATA][D0][D1];
assign o_data = data_r[0];
genvar gi;
for (gi = 0; gi < NDATA-1; gi++) begin: fifo_storage
	always_ff @(posedge i_clk or negedge i_rst) begin
		if (!i_rst) begin
			for (int i = 0; i < D0; i++) begin
				for (int j = 0; j < D1; j++) begin
					data_r[gi][i][j] <= '0;
				end
			end
		end else if (i_load_nxt[gi] || i_load_new[gi]) begin
			for (int i = 0; i < D0; i++) begin
				for (int j = 0; j < D1; j++) begin
					data_r[gi][i][j] <= i_load_new[gi] ? i_data[i][j] : data_r[gi+1][i][j];
				end
			end
		end
	end
end

`ff_rst
	for (int i = 0; i < D0; i++) begin
		for (int j = 0; j < D1; j++) begin
			data_r[NDATA-1][i][j] <= '0;
		end
	end
`ff_cg(i_load_new[NDATA-1])
	for (int i = 0; i < D0; i++) begin
		for (int j = 0; j < D1; j++) begin
			data_r[NDATA-1][i][j] <= i_data[i][j];
		end
	end
`ff_end
endmodule

module SFifo(
	`clk_port,
	`rdyack_port(src),
	i_data,
`ifdef VERI_TOP_SFifo
	`rdyack2_port(dst),
`else
	`rdyack_port(dst),
`endif
	o_data
);
// 0: register
// 1: TP sram
// 2: SP sram (The actual NDATA is chosen as the smallest odd > NDATA)
parameter IMPL = 2;
parameter NDATA = 4;
parameter BW = 8;
localparam CL_N = $clog2(NDATA);

task ErrorFifo;
begin
	$display("FIFO (%m) configuration (%dx%db; implement %d) wrong!", NDATA, BW, IMPL);
	$finish();
end
endtask

`clk_input;
`rdyack_input(src);
input [BW-1:0] i_data;
`ifdef VERI_TOP_SFifo
`rdyack2_output(dst);
`else
`rdyack_output(dst);
`endif
output logic [BW-1:0] o_data;
genvar gi;

generate if (NDATA < 2 || IMPL < 0 || IMPL > 2) begin: error_fifo
	initial ErrorFifo;
end else if (IMPL == 0) begin: fifo_reg
	logic [NDATA-2:0] load_nxt;
	logic [NDATA-1:0] load_new;
	SFifoCtrl u_ctrl(
		`clk_connect,
		`rdyack_connect(src, src),
		`rdyack_connect(dst, dst),
		.o_load_nxt(load_nxt),
		.o_load_new(load_new)
	);
	SFifoReg1D u_reg(
		`clk_connect,
		.i_load_nxt(load_nxt),
		.i_load_new(load_new),
		.i_data(i_data),
		.o_data(o_data)
	);
end else if (IMPL == 1) begin: fifo_2p
	logic dst_rdy_w, sfull, sempty, re;
	logic [CL_N-1:0]  ra_r, wa_r;
	assign src_ack = src_rdy && !sfull;
	// rdy -> if ack and empty, then stop; if ack but not empty, then read next;
	// !rdy -> if not empty, then read and change to ready.
	assign re = (dst_ack || !dst_rdy) && !sempty;
	assign dst_rdy_w = dst_rdy ? !(dst_ack && sempty) : !sempty;
	// if we -> n+1; if re -> n-1 (aka. right after read, not after data taken)
	Semaphore#(NDATA) u_sem(
		`clk_connect,
		.i_inc(src_ack),
		.i_dec(re),
		.o_full(sfull),
		.o_empty(sempty),
		.o_will_empty(),
		.o_will_full(),
		.o_n()
	);
	SRAMTwoPort#(BW,NDATA) u_sram(
		.i_clk(i_clk),
		.i_we(src_ack),
		.i_re(re),
		.i_waddr(wa_r),
		.i_wdata(i_data),
		.i_raddr(ra_r),
		.o_rdata(o_data)
	);
	`ff_rst
		ra_r <= '0;
	`ff_cg(re)
		ra_r <= (ra_r == NDATA-1) ? 'b0 : ra_r + 'b1;
	`ff_end

	`ff_rst
		wa_r <= '0;
	`ff_cg(src_ack)
		wa_r <= (wa_r == NDATA-1) ? 'b0 : wa_r + 'b1;
	`ff_end

	`ff_rst
		dst_rdy <= 1'b0;
	`ff_nocg
		dst_rdy <= dst_rdy_w;
	`ff_end
end else if (IMPL == 2) begin: fifo_1p
	// Operation
	// Datum in the buffer (single) is always written to SRAM,
	// unless there is no data in the SRAM.
	localparam NDATA2 = NDATA/2;
	`rdyack_logic(fifo); // similar to `rdyack_logic(src) in TP implementation
	logic single_rdy_r, single_rdy_w, fifo_canack;
	logic dst_rdy_w, sfull, sempty, fempty, re, ce;
	logic [BW-1:0] single_data_r;
	logic [CL_N-2:0]  ra_r, wa_r, rwa_r;
	logic [BW*2-1:0] o_data_double;
	logic o_use_lower, o_load_next, o_position, o_flush_r, o_flush_w;
	always_comb begin
		o_use_lower = o_flush_r || !o_position;
		o_data = o_use_lower ? o_data_double[(BW-1)-:BW] : o_data_double[(BW*2-1)-:BW];
	end
	always_comb begin
		o_load_next = o_flush_r || o_position;
		if (dst_rdy) begin
			dst_rdy_w = !(dst_ack && sempty && o_load_next);
			re = dst_ack && !sempty && o_load_next;
		end else begin
			dst_rdy_w = !sempty;
			re = !sempty;
		end
	end
	always_comb begin
		fempty = sempty && !dst_rdy;
		if (fempty) begin: MaybeFlushSingleData
			// set flush bit?
			o_flush_w = single_rdy_r && !src_rdy;
			// always send single -> fifo
			fifo_rdy = single_rdy_r;
		end else begin: NeverFlushSingleData
			// clear flush bit?
			o_flush_w = o_flush_r && !dst_ack;
			// send to fifo only when both
			fifo_rdy = single_rdy_r && src_rdy;
		end
		fifo_canack = !(sfull || re);
		fifo_ack = fifo_rdy && fifo_canack;
		single_rdy_w = single_rdy_r ? !fifo_ack : src_rdy;
		src_ack = src_rdy && (!single_rdy_r || fifo_canack);
	end
	always_comb begin
		ce = re | fifo_ack;
		rwa_r = fifo_ack ? wa_r : ra_r;
	end
	Semaphore#(NDATA2) u_sem(
		`clk_connect,
		.i_inc(fifo_ack),
		.i_dec(re),
		.o_full(sfull),
		.o_empty(sempty),
		.o_will_empty(),
		.o_will_full(),
		.o_n()
	);
	SRAMOnePort#(BW*2,NDATA2) u_sram(
		.i_clk(i_clk),
		.i_ce(ce),
		.i_r0w1(fifo_ack),
		.i_rwaddr(rwa_r),
		// new, old (normal)
		// X, old (flushed)
		.i_wdata({i_data, single_data_r}),
		.o_rdata(o_data_double)
	);
	`ff_rst
		ra_r <= '0;
	`ff_cg(re)
		ra_r <= (ra_r == NDATA2-1) ? 'b0 : ra_r + 'b1;
	`ff_end

	`ff_rst
		wa_r <= '0;
	`ff_cg(fifo_ack)
		wa_r <= (wa_r == NDATA2-1) ? 'b0 : wa_r + 'b1;
	`ff_end

	`ff_rst
		single_data_r <= '0;
	`ff_cg(src_ack && !single_rdy_r)
		single_data_r <= i_data;
	`ff_end

	`ff_rst
		o_position <= 1'b0;
	`ff_cg(!o_flush_r && dst_ack)
		o_position <= !o_position;
	`ff_end

	`ff_rst
		o_flush_r <= 1'b0;
	`ff_nocg
		o_flush_r <= o_flush_w;
	`ff_end

	`ff_rst
		dst_rdy <= 1'b0;
		single_rdy_r <= 1'b0;
	`ff_nocg
		dst_rdy <= dst_rdy_w;
		single_rdy_r <= single_rdy_w;
	`ff_end

end endgenerate

endmodule

`endif
