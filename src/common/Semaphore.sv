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

module Semaphore(
	`clk_port,
	i_inc,
	i_dec,
	o_full,
	o_empty
);

//======================================
// Parameter
//======================================
parameter N_MAX = 63;
// derived
localparam BW = $clog2(N_MAX+1);

//======================================
// I/O
//======================================
`clk_input;
input i_inc;
input i_dec;
output logic o_full;
output logic o_empty;

//======================================
// Internal
//======================================
logic [BW-1:0] pending_r;
logic [BW-1:0] pending_w;

//======================================
// Combinational
//======================================
assign o_full = pending_r == N_MAX;
assign o_empty = pending_r == '0;
always_comb begin
	case ({i_inc,i_dec})
		2'b10:        pending_w = pending_r + 'b1;
		2'b01:        pending_w = pending_r - 'b1;
		2'b11, 2'b00: pending_w = pending_r;
	endcase
end

//======================================
// Sequential
//======================================
`ff_rst
	pending_r <= '0;
`ff_cg(i_inc ^ i_dec)
	pending_r <= pending_w;
`ff_end

endmodule
