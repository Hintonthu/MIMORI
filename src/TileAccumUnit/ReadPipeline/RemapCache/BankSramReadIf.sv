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

module BankSramReadIf(
	`clk_port,
	`rdyack_port(addrin),
	i_xor_mask,
	i_xor_scheme,
	i_id,
	i_raddr,
	i_bit_swap,
	i_retire,
	`rdyack_port(dout),
	o_rdata,
	`dval_port(free),
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
parameter XOR_BW = 4;
parameter ID_BW = 2;
localparam CLOG2_NDATA = $clog2(NDATA);
localparam CLOG2_NBANK = $clog2(NBANK);
localparam CCLOG2_NBANK = $clog2(CLOG2_NBANK+1);
localparam ABW = CLOG2_NDATA+CLOG2_NBANK;
localparam CLOG2_XOR_BW = $clog2(XOR_BW);
localparam BANK_MASK = NBANK-1;
// Workaround
logic [CLOG2_NBANK-1:0] ZERO_LOW [NBANK] = '{default:0};
logic [BW-1:0] ZERO_DATA [NBANK] = '{default:0};

//======================================
// I/O
//======================================
input i_clk;
input i_rst;
`rdyack_input(addrin);
input [CLOG2_NBANK-1:0]      i_xor_mask;
input [CLOG2_XOR_BW-1:0]     i_xor_scheme [CLOG2_NBANK];
input [ID_BW-1:0]            i_id;
input [ABW-1:0]              i_raddr      [NBANK];
input [CCLOG2_NBANK-1:0]     i_bit_swap;
input                        i_retire;
`rdyack_output(dout);
output logic [BW-1:0] o_rdata [NBANK];
`dval_output(free);
output logic [ID_BW-1:0] o_free_id;
output logic [NBANK-1:0]       o_sram_re;
output logic [CLOG2_NDATA-1:0] o_sram_raddr [NBANK];
input        [BW         -1:0] i_sram_rdata [NBANK];

//======================================
// Internal
//======================================
logic s1_rdy_r;
logic s1_rdy_w;
logic [CLOG2_NBANK-1:0] butterfly [NBANK];
logic [CLOG2_NBANK-1:0] lower     [NBANK];
logic [CLOG2_NDATA-1:0] higher    [CLOG2_NBANK+1][NBANK];
logic [CCLOG2_NBANK-1:0] s1_bit_swap_r;
logic [CLOG2_NBANK-1:0] s1_lower_r [NBANK];
logic [NBANK-1:0] ren [CLOG2_NBANK+1];
logic [BW-1:0] rdata_w [CLOG2_NBANK+CCLOG2_NBANK+1][NBANK];
`rdyack_logic(s1);
logic          s1_retire;
logic          dout_retire;

//======================================
// Combinational
//======================================
assign free_dval = dout_retire && dout_ack;
assign o_sram_re = addrin_ack ? ren[0] : '0;
always_comb begin
	for (int i = 0; i < NBANK; ++i) begin
		for (int j = 0; j < CLOG2_NBANK; ++j) begin
			butterfly[i][j] = i_raddr[i][CLOG2_NBANK+i_xor_scheme[j]];
		end
		lower[i] = i_raddr[i][CLOG2_NBANK-1:0] ^ (i_xor_mask & butterfly[i]);
	end
end

always_comb begin
	for (int i = 0; i < NBANK; ++i) begin
		higher[CLOG2_NBANK][i] = i_raddr[i][ABW-1 -: CLOG2_NDATA];
	end
	ren[CLOG2_NBANK] = '1;
	for (int i = CLOG2_NBANK-1, m = 1<<i; i >= 0; --i, m >>= 1) begin
		for (int j = 0, mj = 0; j < NBANK; ++j, mj = (j>>i)&1) begin
			ren[i][j] =
				lower[j  ][i] == mj && ren[i+1][j  ] ||
				lower[j^m][i] == mj && ren[i+1][j^m];
			higher[i][j] =
				(lower[j  ][i] == mj ? higher[i+1][j  ] : '0) |
				(lower[j^m][i] == mj ? higher[i+1][j^m] : '0);
		end
	end
	o_sram_raddr = higher[0];
end

always_comb begin
	rdata_w[0] = i_sram_rdata;
	for (int i = 0, m = 1; i < CLOG2_NBANK; ++i, m <<= 1) begin
		for (int j = 0, mj = 0; j < NBANK; ++j, mj = (j>>i)&1) begin
			rdata_w[i+1][j] = s1_lower_r[j][i] == mj ? rdata_w[i][j] : rdata_w[i][j^m];
		end
	end
	for (int ofs = 0, i = CLOG2_NBANK, s = 1; ofs < CCLOG2_NBANK; ++ofs, ++i, s <<= 1) begin
		for (int j = 0; j < NBANK; ++j) begin
			rdata_w[i+1][j] =
				s1_bit_swap_r[ofs] ?
				rdata_w[i][((j<<s)|(j>>CLOG2_NBANK-s)) & BANK_MASK] :
				rdata_w[i][j];
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
	s1_lower_r <= ZERO_LOW;
	s1_bit_swap_r <= '0;
	o_free_id <= '0;
	s1_retire <= 1'b0;
`ff_cg(addrin_ack)
	s1_lower_r <= lower;
	s1_bit_swap_r <= i_bit_swap;
	o_free_id <= i_id;
	s1_retire <= i_retire;
`ff_end

`ff_rst
	o_rdata <= ZERO_DATA;
	dout_retire <= 1'b0;
`ff_cg(s1_ack)
	o_rdata <= rdata_w[CLOG2_NBANK+CCLOG2_NBANK];
	dout_retire <= s1_retire;
`ff_end

endmodule
