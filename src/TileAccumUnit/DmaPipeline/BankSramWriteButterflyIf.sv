// Copyright 2016-2018 Yu Sheng Lin

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
`include "TileAccumUnit/ReadPipeline/RemapCache/codegen/RemapCacheSwapUnit5.sv"

module BankSramButterflyWriteIf(
	i_xor_src,
	i_xor_swap,
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
parameter XOR_BW = TauCfg::XOR_BW;
localparam XOR_ADDR_BW = 1<<XOR_BW;
localparam CLOG2_NDATA = $clog2(NDATA);
localparam CLOG2_NBANK = $clog2(NBANK);
localparam CCLOG2_NBANK = $clog2(CLOG2_NBANK);
localparam BANK_MASK = NBANK-1;

//======================================
// I/O
//======================================
input [XOR_BW-1:0]       i_xor_src [CLOG2_NBANK];
input [CCLOG2_NBANK-1:0] i_xor_swap;
input [CLOG2_NDATA-1:0]  i_hiaddr;
input        [BW-1:0] i_data [NBANK];
output logic [BW-1:0] o_data [NBANK];

//======================================
// Internal
//======================================
logic [CLOG2_NBANK-1:0] i_flags;
logic [BW-1:0] i_bf [CLOG2_NBANK+CCLOG2_NBANK+1][NBANK];
// We can address at most these bits
logic [XOR_ADDR_BW-1:0] i_addrs [NBANK];

//======================================
// Combinational
//======================================
always_comb begin
	for (int i = 0; i < NBANK; ++i) begin
		// FIXME: lint bit width error
		// FIXME: stuck at 0
		i_addrs[i][CLOG2_NBANK-1:0] = i;
		i_addrs[i][XOR_ADDR_BW-2:CLOG2_NBANK] = i_hiaddr;
		i_addrs[i][XOR_ADDR_BW-1] = 1'b0;
	end
end

always_comb begin
	for (int i = 0; i < NBANK; ++i) begin
		i_bf[0][i] = i_data[i];
	end
	// Butterfly (LSB -> MSB)
	for (int i = 0; i < CLOG2_NBANK; ++i) begin
		for (int j = 0; j < NBANK; ++j) begin
			i_bf[i+1][j] = i_addrs[j][i_xor_src[i]] ? i_bf[i][j^(1<<i)] : i_bf[i][j];
		end
	end
	// Omega (LSB -> MSB)
	for (int i = 0; i < CCLOG2_NBANK; ++i) begin
		for (int j = 0; j < NBANK; ++j) begin
			i_bf[i+CLOG2_NBANK+1][j] = (
				i_xor_swap[i] ?
				i_bf[CLOG2_NBANK+i][((j|(j<<CLOG2_NBANK))>>(1<<i))&BANK_MASK] :
				i_bf[CLOG2_NBANK+i][j]
			);
		end
	end
	for (int i = 0; i < NBANK; ++i) begin
		o_data[i] = i_bf[CLOG2_NBANK+CCLOG2_NBANK][i];
	end
end

endmodule
