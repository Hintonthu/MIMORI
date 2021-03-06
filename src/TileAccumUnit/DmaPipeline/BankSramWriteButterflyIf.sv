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
localparam BW = TauCfg::DATA_BW;
localparam NBANK = TauCfg::VSIZE;
localparam XOR_BW = TauCfg::XOR_BW;
// derived from global
localparam CLOG2_NDATA = TauCfg::MAX_LOCAL_ADDR_BW - TauCfg::CV_BW;
localparam CB_BW = TauCfg::CV_BW;
localparam CCB_BW = TauCfg::CCV_BW;
// derived
localparam BANK_MASK = NBANK-1;
localparam XOR_ADDR_BW = 1<<XOR_BW;
localparam NDATA = 1 << CLOG2_NDATA;

//======================================
// I/O
//======================================
input [XOR_BW-1:0]      i_xor_src [CB_BW];
input [CCB_BW-1:0]      i_xor_swap;
input [CLOG2_NDATA-1:0] i_hiaddr;
input        [BW-1:0] i_data [NBANK];
output logic [BW-1:0] o_data [NBANK];

//======================================
// Internal
//======================================
logic [BW-1:0] i_bf [CB_BW+CCB_BW+1][NBANK];
// We can address at most these bits
// logic [XOR_ADDR_BW-1:0] i_addrs [NBANK];
logic [CB_BW-1:0] i_addr_flag_h;
logic [CB_BW-1:0] i_addr_flag_l;
logic [CB_BW-1:0] i_addr_xsel_hi;
logic [CB_BW-1:0] i_addrs_xsel [NBANK];

//======================================
// Combinational
//======================================
always_comb begin
	// if src == -1, use 0
	// elif src > CB_BW, use i_hiaddr
	// else use bank ID
	for (int i = 0; i < CB_BW; ++i) begin
		i_addr_flag_h[i] = &i_xor_src[i]; // -1
		i_addr_flag_l[i] = i_xor_src[i] < CB_BW;
		i_addr_xsel_hi[i] = !(i_addr_flag_h[i] || i_addr_flag_l[i]) && i_hiaddr[i_xor_src[i]-CB_BW];
	end
	for (int i = 0; i < CB_BW; ++i) begin
		for (int j = 0; j < NBANK; ++j) begin
			i_addrs_xsel[j][i] = i_addr_xsel_hi[i] | (((j >> i_xor_src[i]) & 1) != 0);
		end
	end
end

always_comb begin
	for (int i = 0; i < NBANK; ++i) begin
		i_bf[0][i] = i_data[i];
	end
	// Butterfly (LSB -> MSB)
	for (int i = 0; i < CB_BW; ++i) begin
		for (int j = 0; j < NBANK; ++j) begin
			i_bf[i+1][j] = i_addrs_xsel[j][i] ? i_bf[i][j^(1<<i)] : i_bf[i][j];
		end
	end
	// Omega (LSB -> MSB)
	for (int i = 0; i < CCB_BW; ++i) begin
		for (int j = 0; j < NBANK; ++j) begin
			i_bf[i+CB_BW+1][j] = (
				i_xor_swap[i] ?
				i_bf[CB_BW+i][((j|(j<<CB_BW))>>(1<<i))&BANK_MASK] :
				i_bf[CB_BW+i][j]
			);
		end
	end
	for (int i = 0; i < NBANK; ++i) begin
		o_data[i] = i_bf[CB_BW+CCB_BW][i];
	end
end

endmodule
