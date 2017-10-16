// Copyright 2016 Yu Sheng Lin

// This file is part of Ocean.

// MIMORI is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// MIMORI is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with Ocean.  If not, see <http://www.gnu.org/licenses/>.

import TauCfg::*;

module IndexStage(
	`clk_port,
	`rdyack_port(src),
	i_reset_flag,
	i_add_flag,
	i_id_beg,
	i_id_end,
	i_islast,
	`rdyack_port(dst),
	o_reset_flag,
	o_add_flag,
	o_id,
	o_islast
);

//======================================
// Parameter
//======================================
parameter N_CFG = 10;
parameter BLOCK_MODE = 0;
localparam DIM = TauCfg::DIM;
// derived
localparam CFG_BW = $clog2(N_CFG+1);

//======================================
// I/O
//======================================
`clk_input;
`rdyack_input(src);
input [DIM-1:0]    i_reset_flag;
input [DIM-1:0]    i_add_flag;
input [CFG_BW-1:0] i_id_beg;
input [CFG_BW-1:0] i_id_end;
input              i_islast;
`rdyack_output(dst);
output logic [DIM-1:0]    o_reset_flag;
output logic [DIM-1:0]    o_add_flag;
output logic [CFG_BW-1:0] o_id;
output logic              o_islast;

//======================================
// Internal
//======================================
`rdyack_logic(dst_raw);
logic [CFG_BW-1:0] id_beg_r;
logic [CFG_BW-1:0] id_beg_w;
logic [CFG_BW-1:0] id_end_r;
logic [CFG_BW-1:0] id_end_w;
logic [CFG_BW-1:0] id1;
logic [CFG_BW-1:0] id_w;
logic              lastid;
logic [DIM-1:0] reset_flag_w;
logic [DIM-1:0] add_flag_w;
logic islast_r;

//======================================
// Submodule
//======================================
Forward u_fwd(
	`clk_connect,
	`rdyack_connect(src, src),
	`rdyack_connect(dst, dst_raw)
);

//======================================
// Combinational
//======================================
assign dst_rdy = dst_raw_rdy;
assign dst_raw_ack = dst_ack && lastid;
assign o_islast = lastid && islast_r;
always_comb begin
	id1 = o_id + 'b1;
	lastid = id1 == (BLOCK_MODE ? i_id_end : id_end_r);
	casez({src_ack, dst_ack})
		2'b1?: begin
			reset_flag_w = i_reset_flag;
			add_flag_w = i_add_flag;
			id_w = BLOCK_MODE ? '0 : i_id_beg;
			id_beg_w = BLOCK_MODE ? '0 : i_id_beg;
			id_end_w = i_id_end;
		end
		2'b01: begin
			reset_flag_w = o_reset_flag;
			add_flag_w = o_add_flag;
			id_w = id1;
			id_beg_w = id_beg_r;
			id_end_w = id_end_r;
		end
		2'b00: begin
			reset_flag_w = o_reset_flag;
			add_flag_w = o_add_flag;
			id_w = o_id;
			id_beg_w = id_beg_r;
			id_end_w = id_end_r;
		end
	endcase
end

//======================================
// Sequential
//======================================
`ff_rst
	o_reset_flag <= '0;
	o_add_flag <= '0;
	o_id <= '0;
	id_beg_r <= '0;
	id_end_r <= '0;
	islast_r <= 1'b0;
`ff_cg(src_ack || dst_ack)
	o_reset_flag <= reset_flag_w;
	o_add_flag <= add_flag_w;
	o_id <= id_w;
	id_beg_r <= id_beg_w;
	id_end_r <= id_end_w;
	islast_r <= i_islast;
`ff_end

endmodule
