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
import Default::*;

module AccumWarpLooperCollector(
	`clk_port,
	`rdyack_port(src),
	i_linear,
	i_linear_id,
	linear_rdys,
	linear_acks,
	o_linears
);

//======================================
// Parameter
//======================================
parameter N_CFG = Default::N_CFG;
parameter ABW = Default::ABW;
// derived
localparam NCFG_BW = $clog2(N_CFG+1);

//======================================
// I/O
//======================================
`clk_input;
`rdyack_input(src);
input [ABW-1:0]     i_linear;
input [NCFG_BW-1:0] i_linear_id;
output logic [N_CFG-1:0] linear_rdys;
input        [N_CFG-1:0] linear_acks;
output       [ABW-1:0]   o_linears [N_CFG];

//======================================
// Internal
//======================================
logic [N_CFG-1:0] rdy_decode;
logic [N_CFG-1:0] linear_rdys_w;
logic [N_CFG-1:0] cg;

//======================================
// Combinational
//======================================
always_comb begin
	rdy_decode = 'b1<<i_linear_id;
	src_ack = src_rdy && |(rdy_decode & ~linear_rdys);
	linear_rdys_w = (src_rdy ? linear_rdys | rdy_decode : linear_rdys) & ~linear_acks;
	cg = linear_acks;
	if (src_ack) begin
		cg = cg | rdy_decode;
	end
end

//======================================
// Sqeuential
//======================================
always_ff @(posedge i_clk or negedge i_rst) for (int i = 0; i < N_CFG; i++) begin
	if (!i_rst) begin
		o_linears[i] <= '0;
	end else if (cg[i]) begin
		o_linears[i] <= i_linear;
	end
end

`ff_rst
	linear_rdys <= '0;
`ff_nocg
	linear_rdys <= linear_rdys_w;
`ff_end

endmodule
