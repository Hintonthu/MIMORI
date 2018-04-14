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
	i_xor_mask,
	i_xor_scheme,
	i_xor_config,
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
localparam CLOG2_NDATA = $clog2(NDATA);
localparam CLOG2_NBANK = $clog2(NBANK);
localparam CCLOG2_NBANK = $clog2(CLOG2_NBANK);
localparam BANK_MASK = NBANK-1;

//======================================
// I/O
//======================================
input [CLOG2_NBANK-1:0]  i_xor_mask;
input [CCLOG2_NBANK-1:0] i_xor_scheme [CLOG2_NBANK];
input [XOR_BW-1:0]       i_xor_config;
input [CLOG2_NDATA-1:0]  i_hiaddr;
input        [BW-1:0] i_data [NBANK];
output logic [BW-1:0] o_data [NBANK];

//======================================
// Internal
//======================================
logic [CLOG2_NBANK-1:0] i_flags;

//======================================
// Combinational
//======================================
`include "TileAccumUnit/ReadPipeline/RemapCache/rmc_common_include.sv"
assign i_flags = XMask(i_hiaddr, i_xor_mask, i_xor_scheme);

//======================================
// Submodules
//======================================
// I give up. Let the code generator do it.
generate if (CLOG2_NBANK == 5) begin: rmc_write_5
	RemapCacheSwapUnit5#(BW) u_rmc_su(
		.i_data(i_data),
		.i_flags({i_flags, i_xor_config}),
		.o_data(o_data)
	);
end else begin: rmc_write_error
	initial begin
		$display("Only support 32-way SIMD now.");
		$finish;
	end
end endgenerate

endmodule
