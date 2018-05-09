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

module SFifo(
	`clk_port,
	`rdyack_port(src),
	i_data,
	`rdyack_port(dst),
	o_data
);

parameter IMPL_REG = 0;
parameter IMPL_TP = 0;
// Not supported yet
// parameter IMPL_TP2 = 0;
// parameter IMPL_SP = 0;
parameter NDATA = 2;
parameter BW = 8;
localparam CL_N = $clog2(NDATA);
localparam CL_N1 = $clog2(NDATA+1);

task ErrorFifo;
begin
	$display("FIFO configuration (%dx%db) wrong!", NDATA, BW);
	$finish();
end
endtask

`clk_input;
`rdyack_input(src);
input [BW-1:0] i_data;
`rdyack_output(dst);
output logic [BW-1:0] o_data;
genvar gi;

generate if (IMPL_REG && NDATA >= 2) begin: fifo_reg
	logic [NDATA-2:0] load_nxt;
	logic [NDATA-1:0] load_new;
	logic [BW-1:0] data_r [NDATA];
	assign o_data = data_r[0];
	SFifoCtrl u_ctrl(
		`clk_connect,
		`rdyack_connect(src, src),
		`rdyack_connect(dst, dst),
		.o_load_nxt(load_nxt),
		.o_load_new(load_new)
	);
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
end else if (IMPL_TP && NDATA >= 2) begin: fifo_2p
	logic dst_rdy_w, sfull, sempty;
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
