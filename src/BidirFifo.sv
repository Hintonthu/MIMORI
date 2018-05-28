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
`include "common/SFifo.sv"

module BidirFifo(
	`clk_port,
	// Note: two src rdy signals are not asserted at the same cycle.
	`rdyack_port(src0),
	s0_data,
	`rdyack_port(src1),
	s1_data,
	`rdyack_port(dst0),
	// d0_data and d1_data share the data port
	`rdyack_port(dst1),
	d01_data
);
//======================================
// Parameter
//======================================
localparam NDATA = TauCfg::VSIZE;
localparam BW = TauCfg::DATA_BW;
localparam TOTAL_BW = NDATA*BW;

//======================================
// I/O
//======================================
`clk_input;
`rdyack_input(src0);
input [BW-1:0] s0_data [NDATA];
`rdyack_input(src1);
input [BW-1:0] s1_data [NDATA];
`rdyack_output(dst0);
`rdyack_output(dst1);
output logic [BW-1:0] d01_data [NDATA];

//======================================
// Internal
//======================================
`rdyack_logic(src);
`rdyack_logic(dst);
logic [TOTAL_BW:0] s_data;
logic [TOTAL_BW:0] d_data;

//======================================
// Combinational
//======================================
always_comb begin
	src_rdy = src0_rdy || src1_rdy;
	src0_ack = src0_rdy && src_ack;
	src1_ack = src1_rdy && src_ack;
end

always_comb begin
	if (src0_rdy) begin
		s_data[TOTAL_BW] = 1'b0;
		for (int i = 0, j = TOTAL_BW-1; i < NDATA; i++, j -= BW) begin
			s_data[j-:BW] = s0_data[i];
		end
	end else begin
		s_data[TOTAL_BW] = 1'b1;
		for (int i = 0, j = TOTAL_BW-1; i < NDATA; i++, j -= BW) begin
			s_data[j-:BW] = s1_data[i];
		end
	end
end

always_comb begin
	dst0_rdy = !d_data[TOTAL_BW] && dst_rdy;
	dst1_rdy =  d_data[TOTAL_BW] && dst_rdy;
	dst_ack =  dst0_ack || dst1_ack;
	for (int i = 0, j = TOTAL_BW-1; i < NDATA; i++, j -= BW) begin
		d01_data[i] = d_data[j-:BW];
	end
end

//======================================
// Submodule
//======================================
SFifo#(.IMPL(1), .NDATA(TauCfg::SYSTOLIC_FIFO_DEPTH), .BW(1+TOTAL_BW)) u_fifo(
	`clk_connect,
	`rdyack_connect(src, src),
	.i_data(s_data),
	`rdyack_connect(dst, dst),
	.o_data(d_data)
);

endmodule
