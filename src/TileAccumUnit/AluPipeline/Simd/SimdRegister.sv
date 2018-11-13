// Copyright 2018 Yu Sheng Lin

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
`include "common/SRAM.sv"

module SimdRegister(
	`clk_port,
	i_we,
	i_re,
	i_waddr,
	i_wdata,
	i_raddr,
	o_rdata
);
//======================================
// Parameter
//======================================
localparam NWORD = TauCfg::SRAM_NWORD;
localparam TDBW = TauCfg::TMP_DATA_BW;
localparam VSIZE = TauCfg::VSIZE;
localparam FLAT_BW = TDBW*VSIZE;
localparam SRAM_ABW = $clog2(NWORD);

//======================================
// I/O
//======================================
`clk_input;
input                       i_we;
input                       i_re;
input        [SRAM_ABW-1:0] i_waddr;
input        [FLAT_BW-1:0]  i_wdata;
input        [SRAM_ABW-1:0] i_raddr;
output logic [FLAT_BW-1:0]  o_rdata;

//======================================
// Convert input signal to SRAM
// s.t. re/we do not appear in the same cycle
// Since they aren't asserted for two continuous cycles
//======================================
logic sram_rwarp_hi;
logic sram_wwarp_hi;
logic sram_we_simple; // signal not negociate with re
logic sram_rw_conflict;
logic sram_we;
logic sram_re;
logic sram_ce;
logic [SRAM_ABW-1:0]  sram_rwaddr;
logic [2*FLAT_BW-1:0] sram_wdata;
logic [2*FLAT_BW-1:0] sram_rdata;
logic [FLAT_BW-1:0]   sram_wbuf_hi;
logic [FLAT_BW-1:0]   sram_wbuf_lo;
// signal delayed because of conflict
logic [SRAM_ABW-1:0]  sram_waddr_delay;
logic                 sram_we_delay;

// Flip the high warp flag
`ff_rst
	sram_rwarp_hi <= 1'b0;
`ff_cg(i_re)
	sram_rwarp_hi <= !sram_rwarp_hi;
`ff_end

`ff_rst
	sram_wwarp_hi <= 1'b0;
`ff_cg(i_we)
	sram_wwarp_hi <= !sram_wwarp_hi;
`ff_end

//======================================
// The 2x wide SRAM
//======================================
// Signal converion
always_comb begin
	sram_re = i_re && !sram_rwarp_hi;
	sram_we_simple = i_we && sram_wwarp_hi;
	sram_rw_conflict = sram_re && sram_we_simple;
	sram_we = sram_we_delay | (sram_we_simple && ~sram_re);
	sram_wdata = {(sram_we_delay ? sram_wbuf_hi : i_wdata), sram_wbuf_lo};
	sram_ce = sram_re | sram_we;
	if (sram_re) begin
		sram_rwaddr = i_raddr;
	end else if (sram_we_delay) begin
		sram_rwaddr = sram_waddr_delay;
	end else begin
		sram_rwaddr = i_waddr;
	end
end

always_comb begin
	// since data is delayed, so this if/else is inverted
	o_rdata = sram_rwarp_hi ? sram_rdata[FLAT_BW-1 -: FLAT_BW] : sram_rdata[2*FLAT_BW-1 -: FLAT_BW];
end

// Handle write
`ff_rst
	sram_we_delay <= 1'b0;
`ff_nocg
	sram_we_delay <= sram_rw_conflict;
`ff_end

`ff_rst
	sram_waddr_delay <= '0;
`ff_cg(sram_rw_conflict)
	sram_waddr_delay <= i_waddr;
`ff_end

// Buffer the first warp
`ff_rst
	sram_wbuf_lo <= '0;
`ff_cg(i_we && !sram_wwarp_hi)
	sram_wbuf_lo <= i_wdata;
`ff_end

// Buffer the second warp
`ff_rst
	sram_wbuf_hi <= '0;
`ff_cg(sram_rw_conflict)
	sram_wbuf_hi <= i_wdata;
`ff_end

SRAMOnePort#(FLAT_BW*2, NWORD) u_sram(
	.i_clk(i_clk),
	.i_ce(sram_ce),
	.i_r0w1(sram_we),
	.i_rwaddr(sram_rwaddr),
	// first warp is low warp
	.i_wdata(sram_wdata),
	.o_rdata(sram_rdata)
);

endmodule
