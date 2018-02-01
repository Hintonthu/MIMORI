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

module BankSramButterflyWriteIf(
	i_xor_mask,
	i_xor_scheme,
	i_hiaddr,
	i_data,
	o_data
);

//======================================
// Parameter
//======================================
parameter BW = 8;
parameter NDATA = 32;
parameter NBANK = 16;
parameter XOR_BW = 4;
localparam CLOG2_NDATA = $clog2(NDATA);
localparam CLOG2_NBANK = $clog2(NBANK);
localparam CLOG2_XOR_BW = $clog2(XOR_BW);

//======================================
// I/O
//======================================
input [CLOG2_NBANK-1:0]  i_xor_mask;
input [CLOG2_XOR_BW-1:0] i_xor_scheme [CLOG2_NBANK];
input [CLOG2_NDATA-1:0] i_hiaddr;
input        [BW-1:0] i_data [NBANK];
output logic [BW-1:0] o_data [NBANK];

//======================================
// Internal
//======================================
logic [CLOG2_NBANK-1:0] butterfly;
logic [CLOG2_NBANK-1:0] butterfly_masked;
logic [BW-1:0] bf [CLOG2_NBANK+1][NBANK];

//======================================
// Combinational
//======================================
always_comb begin
	for (int i = 0; i < CLOG2_NBANK; ++i) begin
		butterfly[i] = i_hiaddr[i_xor_scheme[i]];
	end
	butterfly_masked = i_xor_mask & butterfly;
end

always_comb begin
	bf[0] = i_data;
	for (int i = 0; i < CLOG2_NBANK; ++i) begin
		for (int j = 0; j < NBANK; ++j) begin
			bf[i+1][j] = butterfly_masked[i] ? bf[i][j^(1<<i)] : bf[i][j];
		end
	end
	o_data = bf[CLOG2_NBANK];
end

endmodule
