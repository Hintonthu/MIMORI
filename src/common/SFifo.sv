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
for (gi = 0; gi < NDATA-1; gi++) begin: fifo_storage
	always_ff @(posedge i_clk or negedge i_rst) begin
		if (!i_rst) begin
			data_r[gi] <= '0;
		end else if (load_nxt[gi] || load_new[gi]) begin
			data_r[gi] <= load_new[gi] ? i_data : data_r[gi+1];
		end
	end
end

`ff_rst
	data_r[NDATA-1] <= '0;
`ff_cg(load_new[NDATA-1])
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
for (gi = 0; gi < NDATA-1; gi++) begin: fifo_storage
	always_ff @(posedge i_clk or negedge i_rst) begin
		if (!i_rst) begin
			data_r[gi] <= '0;
		end else if (load_nxt[gi] || load_new[gi]) begin
			data_r[gi] <= load_new[gi] ? i_data : data_r[gi+1];
		end
	end
end

`ff_rst
	data_r[NDATA-1] <= '0;
`ff_cg(load_new[NDATA-1])
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
for (gi = 0; gi < NDATA-1; gi++) begin: fifo_storage
	always_ff @(posedge i_clk or negedge i_rst) begin
		if (!i_rst) begin
			for (int i = 0; i < D0; i++) begin
				data_r[gi][i] <= '0;
			end
		end else if (load_nxt[gi] || load_new[gi]) begin
			for (int i = 0; i < D0; i++) begin
				data_r[gi][i] <= load_new[gi][i] ? i_data[i] : data_r[gi+1][i];
			end
		end
	end
end

`ff_rst
	for (int i = 0; i < D0; i++) begin
		data_r[gi][i] <= '0;
	end
`ff_cg(load_new[NDATA-1])
	for (int i = 0; i < D0; i++) begin
		data_r[gi][i] <= i_data[i];
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
for (gi = 0; gi < NDATA-1; gi++) begin: fifo_storage
	always_ff @(posedge i_clk or negedge i_rst) begin
		if (!i_rst) begin
			for (int i = 0; i < D0; i++) begin
				for (int j = 0; j < D1; j++) begin
					data_r[gi][i][j] <= '0;
				end
			end
		end else if (load_nxt[gi] || load_new[gi]) begin
			for (int i = 0; i < D0; i++) begin
				for (int j = 0; j < D1; j++) begin
					data_r[gi][i][j] <= load_new[gi][i][j] ? i_data[i][j] : data_r[gi+1][i][j];
				end
			end
		end
	end
end

`ff_rst
	for (int i = 0; i < D0; i++) begin
		for (int j = 0; j < D1; j++) begin
			data_r[gi][i][j] <= '0;
		end
	end
`ff_cg(load_new[NDATA-1])
	for (int i = 0; i < D0; i++) begin
		for (int j = 0; j < D1; j++) begin
			data_r[gi][i][j] <= i_data[i][j];
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
parameter IMPL = 0;
parameter NDATA = 2;
parameter BW = 8;
localparam CL_N = $clog2(NDATA);
localparam CL_N1 = $clog2(NDATA+1);

task ErrorFifo;
begin
	$display("FIFO (%m) configuration (%dx%db) wrong!", NDATA, BW);
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

generate if (IMPL == 0 && NDATA >= 2) begin: fifo_reg
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
		.o_load_nxt(load_nxt),
		.o_load_new(load_new)
		.i_data(i_data),
		.o_data(o_data)
	);
end else if (IMPL == 1 && NDATA >= 2) begin: fifo_2p
	logic dst_rdy_w, sfull, sempty, re;
	logic [CL_N-1:0]  ra_r, ra_w, wa_r, wa_w;
	assign src_ack = src_rdy && !sfull;
	// rdy -> if ack and empty, then stop; if ack but not empty, then read next;
	// !rdy -> if not empty, then read and change to ready.
	assign re = (dst_ack || !dst_rdy) && !sempty;
	assign dst_rdy_w = dst_rdy ? !(dst_ack && sempty) : !sempty;
	// if we -> n+1; if re -> n-1
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
end else begin: syn_fail
	initial ErrorFifo;
end endgenerate

endmodule

`endif
