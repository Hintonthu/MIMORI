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

`include "TileAccumUnit/ReadPipeline/RemapCache/BankedSram.sv"
`include "TileAccumUnit/ReadPipeline/RemapCache/BankSramReadIf.sv"

module RemapCache(
	`clk_port,
	i_xor_srcs,
	i_xor_swaps,
	`rdyack_port(ra),
	i_rid,
	i_raddr,
	i_retire,
`ifdef SD
	i_syst_type,
`endif
`ifdef VERI_TOP_RemapCache
	`rdyack2_port(rd),
`else
	`rdyack_port(rd),
`endif
`ifdef SD
	o_syst_type,
`endif
	o_rdata,
	`dval_port(free),
`ifdef SD
	o_false_alloc,
`endif
	o_free_id,
	`dval_port(wad),
	i_whiaddr,
	i_wdata
);

//======================================
// Parameter
//======================================
parameter LBW = TauCfg::LOCAL_ADDR_BW0;
localparam DBW = TauCfg::DATA_BW;
localparam N_ICFG = TauCfg::N_ICFG;
localparam VSIZE = TauCfg::VSIZE;
localparam XOR_BW = TauCfg::XOR_BW;
// derived
localparam ICFG_BW = $clog2(N_ICFG+1);
localparam CV_BW = $clog2(VSIZE);
localparam CCV_BW = $clog2(CV_BW+1);
localparam HBW = LBW-CV_BW;
localparam NDATA = 1<<HBW;

//======================================
// I/O
//======================================
`clk_input;
input [XOR_BW-1:0] i_xor_srcs [N_ICFG][CV_BW];
input [CCV_BW-1:0] i_xor_swaps [N_ICFG];
`rdyack_input(ra);
input [ICFG_BW-1:0] i_rid;
input [LBW-1:0]     i_raddr [VSIZE];
input               i_retire;
`ifdef SD
input [STO_BW-1:0]  i_syst_type;
`endif
`ifdef VERI_TOP_RemapCache
`rdyack2_output(rd);
`else
`rdyack_output(rd);
`endif
`ifdef SD
output [STO_BW-1:0] o_syst_type;
`endif
output [DBW-1:0] o_rdata [VSIZE];
`dval_output(free);
`ifdef SD
output               o_false_alloc;
`endif
output [ICFG_BW-1:0] o_free_id;
`dval_input(wad);
input [HBW-1:0]     i_whiaddr;
input [DBW-1:0]     i_wdata [VSIZE];

//======================================
// Internal
//======================================
logic [VSIZE-1:0] sram_re;
logic [HBW-1:0] sram_ra [VSIZE];
logic [DBW-1:0] sram_rd [VSIZE];
logic [XOR_BW-1:0] xor_rsrc [CV_BW];

//======================================
// Combinational
//======================================
always_comb for (int i = 0; i < CV_BW; i++) begin
	xor_rsrc[i] = i_xor_srcs[i_rid][i];
end

//======================================
// Submodules
//======================================
BankedSram#(.ABW(HBW)) u_sram_banks(
	`clk_connect,
	`dval_connect(wad, wad),
	.i_whiaddr(i_whiaddr),
	.i_wdata(i_wdata),
	.i_re(sram_re),
	.i_ra(sram_ra),
	.o_rd(sram_rd)
);
BankSramReadIf #(
	.BW(DBW),
	.NDATA(NDATA),
	.NBANK(VSIZE),
	.ID_BW(ICFG_BW)
) u_rif (
	`clk_connect,
	`rdyack_connect(addrin, ra),
	.i_xor_src(xor_rsrc),
	.i_xor_swap(i_xor_swaps[i_rid]),
	.i_id(i_rid),
	.i_raddr(i_raddr),
	.i_retire(i_retire),
`ifdef SD
	.i_syst_type(i_syst_type),
`endif
	`rdyack_connect(dout, rd),
`ifdef SD
	.o_syst_type(o_syst_type),
`endif
	.o_rdata(o_rdata),
	`dval_connect(free, free),
`ifdef SD
	.o_false_alloc(o_false_alloc),
`endif
	.o_free_id(o_free_id),
	.o_sram_re(sram_re),
	.o_sram_raddr(sram_ra),
	.i_sram_rdata(sram_rd)
);


endmodule
