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
`include "common/Controllers.sv"

module SystolicSwitch(
	`clk_port,
	`rdyack_port(from_rp),
	// +-----------------------------+------------------+------------------+
	// | type = 0 | type = 1         | type = 2         | type = 3         |
	// |   ALU    |       ALU        |       ALU        |       ALU        |
	// |    ^     |        ^         |        ^         |        ^         |
	// |    |     |        |         |        |         |        |         |
	// |  Switch  | 0 <- Switch -> 1 | 0 -> Switch -> 1 | 0 <- Switch <- 1 |
	// |    ^     |        ^         |        ^         |        ^         |
	// |    |     |        |         |        |         |        |         |
	// |   RP     |       RP         |       RP         |       RP         |
	// +-----------------------------+------------------+------------------+
	// |  Data from RP               | Data from 0      | Data from 1      |
	// +-----------------------------+------------------+------------------+
	// NOTE: 0 is never output from AccumBlockLooper_sd.sv. 0 is detected in
	// ReadPipeline
	i_syst_type,
	rp_data,
	`rdyack_port(src0),
	s0_data,
	`rdyack_port(src1),
	s1_data,
	`rdyack_port(dst0),
	`rdyack_port(dst1),
	`rdyack_port(to_alu),
	// the output ports are shared
	o_data
);

//======================================
// Parameter
//======================================
localparam DBW = TauCfg::DATA_BW;
localparam VSIZE = TauCfg::VSIZE;

//======================================
// I/O
//======================================
`clk_input;
`rdyack_input(from_rp);
input [1:0] i_syst_type;
input [DBW-1:0] rp_data [VSIZE];
`rdyack_logic(i0_alu_sramrd);
`rdyack_input(src0);
input [DBW-1:0] s1_data [VSIZE];
`rdyack_input(src1);
input [DBW-1:0] s0_data [VSIZE];
`rdyack_output(dst0);
`rdyack_output(dst1);
`rdyack_output(to_alu);
output logic [DBW-1:0] o_data [VSIZE];

//======================================
// Internal
//======================================
`rdyack_logic(src);
`rdyack_logic(dst0_brd);
`rdyack_logic(dst1_brd);
`rdyack_logic(alu_brd);
logic ign_d0, ign_d1;

//======================================
// Combinational
//======================================
assign o_data = i_syst_type[1] ? (i_syst_type[0] ? s1_data : s0_data) : rp_data;
always_comb begin
	ign_d0 = i_syst_type == 2'd0 || i_syst_type == 2'd3;
	ign_d1 = i_syst_type == 2'd0 || i_syst_type == 2'd2;
end

always_comb begin
	if (from_rp_rdy) begin
		case (i_syst_type)
			2'd0, 2'd1: begin
				src_rdy = 1'b1;
				src0_ack = 1'b0;
				src1_ack = 1'b0;
				from_rp_ack = src_ack;
			end
			2'd2: begin
				src_rdy = src0_rdy;
				src0_ack = src_ack;
				src1_ack = 1'b0;
				from_rp_ack = src_ack;
			end
			2'd3: begin
				src_rdy = src1_rdy;
				src0_ack = 1'b0;
				src1_ack = src_ack;
				from_rp_ack = src_ack;
			end
		endcase
	end else begin
		src_rdy = 1'b0;
		src0_ack = 1'b0;
		src1_ack = 1'b0;
		from_rp_ack = 1'b0;
	end
end

//======================================
// Submodule
//======================================
Broadcast#(3) u_brd(
	`clk_connect,
	`rdyack_connect(src, src),
	.acked(),
	.dst_rdys({dst0_brd_rdy, dst1_brd_rdy, to_alu_rdy}),
	.dst_acks({dst0_brd_ack, dst1_brd_ack, to_alu_ack})
);
IgnoreIf#(1) u_ign_d0(
	.cond(ign_d0),
	`rdyack_connect(src, dst0_brd),
	`rdyack_connect(dst, dst0),
	.skipped()
);
IgnoreIf#(1) u_ign_d1(
	.cond(ign_d1),
	`rdyack_connect(src, dst1_brd),
	`rdyack_connect(dst, dst1),
	.skipped()
);

endmodule
