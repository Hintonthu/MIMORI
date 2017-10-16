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

module DramWriteCollectorAddrDecode(
	`clk_port,
	`rdyack_port(addrval),
	i_address,
	i_valid,
	`rdyack_port(dec),
	o_addr,
	o_dec,
	o_islast
);

//======================================
// Parameter
//======================================
localparam GBW = TauCfg::GLOBAL_ADDR_BW;
localparam VSIZE = TauCfg::VECTOR_SIZE;
localparam CSIZE = TauCfg::CACHE_SIZE;
// derived
localparam C_BW = $clog2(CSIZE);
localparam V_BW = $clog2(VSIZE);
localparam SLICE_BW = C_BW > V_BW ? V_BW : C_BW;

//======================================
// I/O
//======================================
`clk_input;
`rdyack_input(addrval);
input [GBW-1:0]   i_address [VSIZE];
input [VSIZE-1:0] i_valid;
`rdyack_output(dec);
output logic [GBW-1:0]   o_addr;
output logic [VSIZE-1:0] o_dec [CSIZE];
output logic             o_islast;

//======================================
// Internal
//======================================
logic [GBW-1:0]   addr_full [1]; // 1 for interface of u_selectaddr
logic [VSIZE-1:0] not_served;
logic [VSIZE-1:0] served_r;
logic [VSIZE-1:0] served_w;
logic [VSIZE-1:0] served_nxt;
logic [VSIZE-1:0] selected [1]; // 1 for interface of u_selectaddr
logic [VSIZE-1:0] serve_now;
logic nothing_to_serve;

//======================================
// Combinational
//======================================
assign not_served = i_valid & ~served_r;
assign dec_rdy = addrval_rdy;
assign o_addr = addr_full[0]>>C_BW<<C_BW;
always_comb begin
	if (nothing_to_serve) begin
		serve_now = '0;
	end else begin
		for (int i = 0; i < VSIZE; i++) begin
			serve_now[i] = (o_addr>>C_BW) == (i_address[i]>>C_BW) && i_valid[i];
		end
	end
	served_nxt = served_r | serve_now;
	o_islast = ~|(i_valid & ~served_nxt);
	addrval_ack = o_islast && dec_ack;
	casez ({dec_ack, o_islast})
		2'b0?: served_w = served_r;
		2'b10: served_w = served_nxt;
		2'b11: served_w = '0;
	endcase
	for (int i = 0; i < CSIZE; i++) begin
		for (int j = 0; j < VSIZE; j++) begin
			o_dec[i][j] = serve_now[j] && i_address[j][SLICE_BW-1:0] == i;
		end
	end
end

//======================================
// Submodule
//======================================
FindFromLsb#(VSIZE, 1) u_selector(
	.i(not_served),
	.prefix(),
	.detect({nothing_to_serve, selected[0]})
);
OrCrossBar#(GBW, VSIZE, 1) u_seladdr(
	.i_data(i_address),
	.i_routing(selected),
	.o_data(addr_full),
	.o_mask()
);

//======================================
// Sequential
//======================================
`ff_rst
	served_r <= '0;
`ff_cg(dec_ack)
	served_r <= served_w;
`ff_end

endmodule
