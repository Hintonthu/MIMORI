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
`include "common/Controllers.sv"

module BankSramReadIf(
	`clk_port,
	`rdyack_port(addrin),
	i_xor_mask,
	i_xor_scheme,
	i_xor_config,
	i_id,
	i_raddr,
	i_retire,
`ifdef SD
	i_syst_type,
`endif
	`rdyack_port(dout),
`ifdef SD
	o_syst_type,
`endif
	o_rdata,
	`dval_port(free),
`ifdef SD
	o_false_alloc,
`endif
	o_free_id,
	// SRAM
	o_sram_re,
	o_sram_raddr,
	i_sram_rdata
);

//======================================
// Parameter
//======================================
parameter BW = 8;
parameter NDATA = 32;
parameter NBANK = 16;
parameter ID_BW = 2;
parameter XOR_BW = TauCfg::XOR_BW;
localparam CLOG2_NDATA = $clog2(NDATA);
localparam CLOG2_NBANK = $clog2(NBANK);
localparam CCLOG2_NBANK = $clog2(CLOG2_NBANK+1);
localparam ABW = CLOG2_NDATA+CLOG2_NBANK;
localparam BANK_MASK = NBANK-1;
localparam NBANK2 = NBANK/2;

//======================================
// I/O
//======================================
input i_clk;
input i_rst;
`rdyack_input(addrin);
input [CLOG2_NBANK-1:0]  i_xor_mask;
input [CCLOG2_NBANK-1:0] i_xor_scheme [CLOG2_NBANK];
input [XOR_BW-1:0]       i_xor_config;
input [ID_BW-1:0]        i_id;
input [ABW-1:0]          i_raddr [NBANK];
input                    i_retire;
`ifdef SD
input [1:0]              i_syst_type;
`endif
`rdyack_output(dout);
`ifdef SD
output logic [1:0]    o_syst_type;
`endif
output logic [BW-1:0] o_rdata [NBANK];
`dval_output(free);
`ifdef SD
output logic             o_false_alloc;
`endif
output logic [ID_BW-1:0] o_free_id;
output logic [NBANK-1:0]       o_sram_re;
output logic [CLOG2_NDATA-1:0] o_sram_raddr [NBANK];
input        [BW         -1:0] i_sram_rdata [NBANK];

//======================================
// Internal
//======================================
logic [CLOG2_NBANK-1:0] i_bf_loaddr_rot [NBANK];
logic [CLOG2_NDATA-1:0] i_bf_hiaddr [CLOG2_NBANK+1][NBANK];
logic [CLOG2_NBANK-1:0] i_bf_loaddr [CLOG2_NBANK+1][NBANK];
logic [NBANK-1:0] i_ren [CLOG2_NBANK+1];
logic [NBANK-1:0] i_bf [CLOG2_NBANK];
`rdyack_logic(s1);
logic [NBANK-1:0] s1_bf [CLOG2_NBANK];
logic [BW-1:0]    s1_bf_data [CLOG2_NBANK+1][NBANK];
logic [ID_BW-1:0] s1_free_id;
logic             s1_retire;
logic dout_retire;

//======================================
// Combinational
//======================================
`include "TileAccumUnit/ReadPipeline/RemapCache/rmc_common_include.sv"
`include "TileAccumUnit/ReadPipeline/RemapCache/codegen/RemapCacheLowRotate5.sv"
assign free_dval = dout_retire && dout_ack;
assign o_sram_re = addrin_ack ? i_ren[0] : '0;
`ifdef SD
logic [1:0] s1_syst_type;
assign o_false_alloc = o_syst_type[1];
`endif

// I give up. Let the code generator do it.
generate if (CLOG2_NBANK == 5) begin: rmc_read_5
	always_comb begin
		for (int i = 0; i < NBANK; ++i) begin
			i_bf_loaddr_rot[i] = RemapCacheLowRotate5(i_raddr[i][CLOG2_NBANK-1:0], i_xor_config);
		end
	end
end else begin: rmc_read_error
	initial begin
		$display("Only support 32-way SIMD now.");
		$finish;
	end
end endgenerate

always_comb begin
	for (int i = 0; i < NBANK; ++i) begin
		i_bf_hiaddr[CLOG2_NBANK][i] = i_raddr[i][ABW-1:CLOG2_NBANK];
		i_bf_loaddr[CLOG2_NBANK][i] =
			XMask(i_bf_hiaddr[CLOG2_NBANK][i], i_xor_mask, i_xor_scheme) ^
			i_bf_loaddr_rot[i];
	end
	// Butterfly (MSB -> LSB)
	i_ren[CLOG2_NBANK] = '1;
	for (int i = CLOG2_NBANK-1, m = 1<<i; i >= 0; --i, m >>= 1) begin
		for (int j = 0; j < NBANK; ++j) begin
			 i_bf[i][j] = i_bf_loaddr[i+1][j][CLOG2_NBANK-1] ^ ((j>>i)&1);
		end
		for (int j = 0; j < NBANK; ++j) begin
			i_ren[i][j] =
				~i_bf[i][j  ] && i_ren[i+1][j  ] ||
				 i_bf[i][j^m] && i_ren[i+1][j^m];
			i_bf_hiaddr[i][j] =
				(~i_bf[i][j  ] ? i_bf_hiaddr[i+1][j  ] : '0) |
				( i_bf[i][j^m] ? i_bf_hiaddr[i+1][j^m] : '0);
			i_bf_loaddr[i][j] = (
				(~i_bf[i][j  ] ? i_bf_loaddr[i+1][j  ] : '0) |
				( i_bf[i][j^m] ? i_bf_loaddr[i+1][j^m] : '0)
			) << 1;
		end
	end
	o_sram_raddr = i_bf_hiaddr[0];
end

always_comb begin
	// Butterfly (LSB -> MSB)
	s1_bf_data[0] = i_sram_rdata;
	for (int i = 0, m = 1; i < CLOG2_NBANK; ++i, m <<= 1) begin
		for (int j = 0; j < NBANK; ++j) begin
			s1_bf_data[i+1][j] = s1_bf[i][j] ? s1_bf_data[i][j^m] : s1_bf_data[i][j];
		end
	end
end

//======================================
// Submodules
//======================================
Forward u_fwd_addr(
	`clk_connect,
	`rdyack_connect(src, addrin),
	`rdyack_connect(dst, s1)
);
Forward u_fwd_dat(
	`clk_connect,
	`rdyack_connect(src, s1),
	`rdyack_connect(dst, dout)
);

//======================================
// Sequential
//======================================
`ff_rst
	for (int i = 0; i < CLOG2_NBANK; i++) begin
		s1_bf[i] <= '0;
	end
	s1_free_id <= '0;
	s1_retire <= 1'b0;
`ifdef SD
	s1_syst_type <= 2'b0;
`endif
`ff_cg(addrin_ack)
	s1_bf <= i_bf;
	s1_free_id <= i_id;
	s1_retire <= i_retire;
`ifdef SD
	s1_syst_type <= i_syst_type;
`endif
`ff_end

`ff_rst
	dout_retire <= 1'b0;
	for (int i = 0; i < NBANK; i++) begin
		o_rdata[i] <= '0;
	end
	o_free_id <= '0;
`ifdef SD
	o_syst_type <= 2'b0;
`endif
`ff_cg(s1_ack)
	dout_retire <= s1_retire;
	o_rdata <= s1_bf_data[CLOG2_NBANK];
	o_free_id <= s1_free_id;
`ifdef SD
	o_syst_type <= s1_syst_type;
`endif
`ff_end

endmodule
