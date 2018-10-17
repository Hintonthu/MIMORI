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
`include "common/TauCfg.sv"
`include "common/Controllers.sv"
import TauCfg::*;

module BankSramReadIf(
	`clk_port,
	`rdyack_port(addrin),
	i_xor_src,
	i_xor_swap,
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
localparam XOR_ADDR_BW = 1<<XOR_BW;
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
input [XOR_BW-1:0]       i_xor_src [CLOG2_NBANK];
input [CCLOG2_NBANK-1:0] i_xor_swap;
input [ID_BW-1:0]        i_id;
input [ABW-1:0]          i_raddr [NBANK];
input                    i_retire;
`ifdef SD
input [STO_BW-1:0]       i_syst_type;
`endif
`rdyack_output(dout);
`ifdef SD
output logic [STO_BW-1:0] o_syst_type;
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
logic [XOR_ADDR_BW-1:0] i_addrs_x [NBANK];
logic [CLOG2_NBANK-1:0] i_bf_loaddr_x [NBANK];
logic [CLOG2_NBANK*2-1:0] i_bf_loaddr_x2 [NBANK];
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
assign free_dval = dout_retire && dout_ack;
`ifdef SD
logic [STO_BW-1:0] s1_syst_type;
assign o_false_alloc = `IS_FROM_SIDE(o_syst_type);
assign o_sram_re = (`IS_FROM_SELF(i_syst_type) && addrin_ack) ? i_ren[0] : '0;
`else
assign o_sram_re = addrin_ack ? i_ren[0] : '0;
`endif

always_comb begin
	for (int i = 0; i < NBANK; ++i) begin
		i_addrs_x[i] = i_raddr[i];
		i_addrs_x[i] = (i_addrs_x[i] << 1) >> 1;
		i_bf_hiaddr[CLOG2_NBANK][i] = i_raddr[i][ABW-1:CLOG2_NBANK];
		for (int j = 0; j < CLOG2_NBANK; ++j) begin
			i_bf_loaddr_x[i][j] = i_raddr[i][j] ^ i_addrs_x[i][i_xor_src[j]];
		end
		i_bf_loaddr_x2[i] = {2{i_bf_loaddr_x[i]}} << i_xor_swap;
		i_bf_loaddr[CLOG2_NBANK][i] = i_bf_loaddr_x2[i][2*CLOG2_NBANK-1 -: CLOG2_NBANK];
	end
	// Butterfly (MSB -> LSB)
	// FIXME: a clean way to stuck at 1
	i_ren[CLOG2_NBANK] = '1;
	for (int i = CLOG2_NBANK-1; i >= 0; --i) begin
		for (int j = 0; j < NBANK; ++j) begin
			// [i+1] previous layer
			// [j] n-th element
			// [CLOG2_NBANK-1] bit-plane (target bit-plane is shifted up)
			i_bf[i][j] = i_bf_loaddr[i+1][j][CLOG2_NBANK-1] ^ 1'((j>>i)&1);
		end
		for (int j = 0; j < NBANK; ++j) begin
			i_ren[i][j] =
				~i_bf[i][j       ] && i_ren[i+1][j       ] ||
				 i_bf[i][j^(1<<i)] && i_ren[i+1][j^(1<<i)];
			i_bf_hiaddr[i][j] =
				(~i_bf[i][j       ] ? i_bf_hiaddr[i+1][j       ] : '0) |
				( i_bf[i][j^(1<<i)] ? i_bf_hiaddr[i+1][j^(1<<i)] : '0);
			i_bf_loaddr[i][j] = (
				(~i_bf[i][j       ] ? i_bf_loaddr[i+1][j       ] : '0) |
				( i_bf[i][j^(1<<i)] ? i_bf_loaddr[i+1][j^(1<<i)] : '0)
			) << 1;
		end
	end
	o_sram_raddr = i_bf_hiaddr[0];
end

always_comb begin
	// Butterfly (LSB -> MSB)
	s1_bf_data[0] = i_sram_rdata;
	for (int i = 0; i < CLOG2_NBANK; ++i) begin
		for (int j = 0; j < NBANK; ++j) begin
			s1_bf_data[i+1][j] = s1_bf[i][j] ? s1_bf_data[i][j^(1<<i)] : s1_bf_data[i][j];
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
	s1_free_id <= '0;
	s1_retire <= 1'b0;
`ff_cg(addrin_ack)
	s1_free_id <= i_id;
	s1_retire <= i_retire;
`ff_end

`ff_rst
	dout_retire <= 1'b0;
	o_free_id <= '0;
`ff_cg(s1_ack)
	dout_retire <= s1_retire;
	o_free_id <= s1_free_id;
`ff_end

// CG the data, and butterfly when the data is from side
`ff_rst
	for (int i = 0; i < CLOG2_NBANK; i++) begin
		s1_bf[i] <= '0;
	end
`ifdef SD
`ff_cg(addrin_ack && `IS_FROM_SELF(i_syst_type))
`else
`ff_cg(addrin_ack)
`endif
	s1_bf <= i_bf;
`ff_end

`ff_rst
	for (int i = 0; i < NBANK; i++) begin
		o_rdata[i] <= '0;
	end
`ifdef SD
`ff_cg(s1_ack && `IS_FROM_SELF(s1_syst_type))
`else
`ff_cg(s1_ack)
`endif
	o_rdata <= s1_bf_data[CLOG2_NBANK];
`ff_end

// Also pipeline the systolic type flag.
`ifdef SD
`ff_rst
	s1_syst_type <= '0;
`ff_cg(addrin_ack)
	s1_syst_type <= i_syst_type;
`ff_end

`ff_rst
	o_syst_type <= '0;
`ff_cg(s1_ack)
	o_syst_type <= s1_syst_type;
`ff_end
`endif

endmodule
