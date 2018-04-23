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

module DramArbiter(
	`clk_port,
	`rdyack_port(i0_dramra),
	i_i0_dramra,
	`rdyack_port(i0_dramrd),
	o_i0_dramrd,
	`rdyack_port(i1_dramra),
	i_i1_dramra,
	`rdyack_port(i1_dramrd),
	o_i1_dramrd,
	`rdyack_port(dramra),
	o_dramra,
	`rdyack_port(dramrd),
	i_dramrd
);

//======================================
// Parameter
//======================================
localparam GBW = TauCfg::GLOBAL_ADDR_BW;
localparam DBW = TauCfg::DATA_BW;
localparam CSIZE = TauCfg::CACHE_SIZE;
localparam FSIZE = TauCfg::ARB_FIFO_SIZE;
// derived
localparam CFSIZE = $clog2(FSIZE+1);

//======================================
// I/O
//======================================
`clk_input;
`rdyack_input(i0_dramra);
input [GBW-1:0] i_i0_dramra;
`rdyack_output(i0_dramrd);
output logic [DBW-1:0] o_i0_dramrd [CSIZE];
`rdyack_input(i1_dramra);
input [GBW-1:0] i_i1_dramra;
`rdyack_output(i1_dramrd);
output logic [DBW-1:0] o_i1_dramrd [CSIZE];
`rdyack_output(dramra);
output logic [GBW-1:0] o_dramra;
`rdyack_input(dramrd);
input [DBW-1:0] i_dramrd [CSIZE];

//======================================
// Internal
//======================================
logic arb_r;
logic arb_w;
logic sel;
logic [FSIZE-1:0] where_r;
logic [FSIZE-1:0] where_nxt;
logic [FSIZE-1:0] where_w;
logic [CFSIZE-1:0] n_r;
logic [CFSIZE-1:0] n_w;
logic is_full;

//======================================
// Combinational
//======================================
assign is_full = n_r == FSIZE;
assign dramra_rdy = (i0_dramra_rdy || i1_dramra_rdy) && !is_full;
assign dramrd_ack = i0_dramrd_ack || i1_dramrd_ack;
assign sel = arb_r ? i1_dramra_rdy : !i0_dramra_rdy;
assign arb_w = dramra_ack ? !sel : arb_r;
assign i0_dramra_ack = dramra_ack && !sel;
assign i1_dramra_ack = dramra_ack && sel;
assign where_nxt = where_r | ((dramra_ack && sel) ? ({{(FSIZE-1){1'b0}}, 1'b1} << n_r) : '0);
assign where_w = dramrd_ack ? where_nxt>>1 : where_nxt;
assign o_dramra = sel ? i_i1_dramra : i_i0_dramra;
assign o_i0_dramrd = i_dramrd;
assign o_i1_dramrd = i_dramrd;
assign i0_dramrd_rdy = dramrd_rdy && !where_r[0];
assign i1_dramrd_rdy = dramrd_rdy && where_r[0];
always_comb casez ({dramrd_ack,dramra_ack})
	2'b00, 2'b11: n_w = n_r;
	2'b01       : n_w = n_r + 'b1;
	2'b10       : n_w = n_r - 'b1;
endcase

//======================================
// Sequential
//======================================
`ff_rst
	arb_r <= 1'b0;
`ff_cg(dramra_ack)
	arb_r <= arb_w;
`ff_end

`ff_rst
	where_r <= '0;
`ff_cg(dramra_ack || dramrd_ack)
	where_r <= where_w;
`ff_end

`ff_rst
	n_r <= '0;
`ff_cg(dramra_ack ^ dramrd_ack)
	n_r <= n_w;
`ff_end

endmodule
