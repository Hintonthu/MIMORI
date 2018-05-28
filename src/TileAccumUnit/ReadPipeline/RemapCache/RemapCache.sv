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

`include "common/SRAM.sv"
`include "TileAccumUnit/ReadPipeline/RemapCache/BankSramReadIf.sv"
`include "TileAccumUnit/ReadPipeline/RemapCache/BankSramWriteButterflyIf.sv"

module RemapCache(
	`clk_port,
	i_xor_masks,
	i_xor_schemes,
	i_xor_configs,
	`rdyack_port(ra),
	i_rid,
	i_raddr,
	i_retire,
`ifdef SD
	i_syst_type,
`endif
	`rdyack_port(rd),
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
	i_wid,
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
input [CV_BW-1:0]   i_xor_masks   [N_ICFG];
input [CCV_BW-1:0]  i_xor_schemes [N_ICFG][CV_BW];
input [XOR_BW-1:0]  i_xor_configs [N_ICFG];
`rdyack_input(ra);
input [ICFG_BW-1:0] i_rid;
input [LBW-1:0]     i_raddr [VSIZE];
input               i_retire;
`ifdef SD
input [STO_BW-1:0]  i_syst_type;
`endif
`rdyack_output(rd);
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
input [ICFG_BW-1:0] i_wid;
input [HBW-1:0]     i_whiaddr;
input [DBW-1:0]     i_wdata [VSIZE];

//======================================
// Internal
//======================================
logic [VSIZE-1:0] sram_re;
logic [HBW-1:0] sram_ra [VSIZE];
logic [DBW-1:0] sram_rd [VSIZE];
logic [DBW-1:0] sram_wd [VSIZE];

//======================================
// Submodules
//======================================
BankSramReadIf #(
	.BW(DBW),
	.NDATA(NDATA),
	.NBANK(VSIZE),
	.ID_BW(ICFG_BW)
) u_rif (
	`clk_connect,
	`rdyack_connect(addrin, ra),
	.i_xor_mask(i_xor_masks[i_rid]),
	.i_xor_scheme(i_xor_schemes[i_rid]),
	.i_xor_config(i_xor_configs[i_rid]),
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

BankSramButterflyWriteIf #(
	.BW(DBW),
	.NDATA(NDATA),
	.NBANK(VSIZE)
) u_wif (
	.i_xor_mask(i_xor_masks[i_wid]),
	.i_xor_scheme(i_xor_schemes[i_wid]),
	.i_xor_config(i_xor_configs[i_wid]),
	.i_hiaddr(i_whiaddr),
	.i_data(i_wdata),
	.o_data(sram_wd)
);

genvar gi;
generate for (gi = 0; gi < VSIZE; gi++) begin: sram
SRAMTwoPort #(.BW(DBW), .NDATA(NDATA)) u_dp_sram(
	.i_clk(i_clk),
	.i_we(wad_dval),
	.i_re(sram_re[gi]),
	.i_waddr(i_whiaddr),
	.i_wdata(sram_wd[gi]),
	.i_raddr(sram_ra[gi]),
	.o_rdata(sram_rd[gi])
);
end endgenerate

endmodule
