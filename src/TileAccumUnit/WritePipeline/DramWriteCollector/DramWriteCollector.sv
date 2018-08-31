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

`include "common/define.sv"
`include "common/TauCfg.sv"
`include "TileAccumUnit/WritePipeline/DramWriteCollector/DramWriteCollectorAddrDecode.sv"
`include "TileAccumUnit/WritePipeline/DramWriteCollector/DramWriteCollectorOutput.sv"

module DramWriteCollector(
	`clk_port,
	`rdyack_port(addrval),
	i_address,
	i_valid,
	`rdyack_port(alu_dat),
	i_alu_dat,
`ifdef VERI_TOP_DramWriteCollector
	`rdyack2_port(dramw),
`else
	`rdyack_port(dramw),
`endif
	o_dramwa,
	o_dramwd,
	o_dramw_mask
);

//======================================
// Parameter
//======================================
localparam GBW = TauCfg::GLOBAL_ADDR_BW;
localparam DBW = TauCfg::DATA_BW;
localparam VSIZE = TauCfg::VSIZE;
localparam CSIZE = TauCfg::CACHE_SIZE;

//======================================
// I/O
//======================================
`clk_input;
`rdyack_input(addrval);
input [GBW-1:0]   i_address [VSIZE];
input [VSIZE-1:0] i_valid;
`rdyack_input(alu_dat);
input [DBW-1:0] i_alu_dat [VSIZE];
`ifdef VERI_TOP_DramWriteCollector
`rdyack2_output(dramw);
`else
`rdyack_output(dramw);
`endif
output logic [GBW-1:0]   o_dramwa;
output logic [DBW-1:0]   o_dramwd [CSIZE];
output logic [CSIZE-1:0] o_dramw_mask;

//======================================
// Internal
//======================================
`rdyack_logic(dec);
`rdyack_logic(d2u);
logic [GBW-1:0]   d2u_addr;
logic [VSIZE-1:0] d2u_dec [CSIZE];
logic             d2u_islast;

//======================================
// Submodule
//======================================
DramWriteCollectorAddrDecode u_decode(
	`clk_connect,
	`rdyack_connect(addrval, addrval),
	.i_address(i_address),
	.i_valid(i_valid),
	`rdyack_connect(dec, d2u),
	.o_addr(d2u_addr),
	.o_dec(d2u_dec),
	.o_islast(d2u_islast)
);
DramWriteCollectorOutput u_output(
	`clk_connect,
	`rdyack_connect(dec, d2u),
	.i_addr(d2u_addr),
	.i_dec(d2u_dec),
	.i_islast(d2u_islast),
	`rdyack_connect(alu_dat, alu_dat),
	.i_alu_dat(i_alu_dat),
	`rdyack_connect(dramw, dramw),
	.o_dramwa(o_dramwa),
	.o_dramwd(o_dramwd),
	.o_dramw_mask(o_dramw_mask)
);

endmodule
