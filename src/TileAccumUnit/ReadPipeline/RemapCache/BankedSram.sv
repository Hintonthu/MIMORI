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

`include "common/SRAM.sv"

module BankedSram(
	`clk_port,
	`dval_port(wad),
	i_whiaddr,
	i_wdata,
	i_re,
	i_ra,
	o_rd
);

//======================================
// Parameter
//======================================
parameter ABW = 1;
localparam DBW = TauCfg::DATA_BW;
localparam VSIZE = TauCfg::VSIZE;
localparam NDATA = 1<<(ABW-1);

`clk_input;
`dval_input(wad);
input        [ABW-1:0]   i_whiaddr;
input        [DBW-1:0]   i_wdata [VSIZE];
input        [VSIZE-1:0] i_re;
input        [ABW-1:0]   i_ra [VSIZE];
output logic [DBW-1:0]   o_rd [VSIZE];

//======================================
// Internal
//======================================
logic             we [2];
logic [VSIZE-1:0] re [2];
logic [VSIZE-1:0] ce [2];
logic [DBW-1:0]   rd [2][VSIZE];
logic [VSIZE-1:0] rd_mux;
logic [ABW-2:0]   rwa [2][VSIZE];
genvar gi;

always_comb for (int i = 0; i < VSIZE; i++) begin
	o_rd[i] = rd[rd_mux[i]][i];
end

always_comb begin
	for (int i = 0; i < VSIZE; i++) begin
		re[0][i] = i_re && !i_ra[i][ABW-1];
		re[1][i] = i_re &&  i_ra[i][ABW-1];
	end
	we[0] = wad_dval && !i_whiaddr[ABW-1];
	we[1] = wad_dval &&  i_whiaddr[ABW-1];
	ce[0] = re[0] | {VSIZE{we[0]}};
	ce[1] = re[1] | {VSIZE{we[1]}};
	for (int i = 0; i < VSIZE; i++) begin
		rwa[0][i] = we[0] ? i_whiaddr[ABW-2:0] : i_ra[i][ABW-2:0];
		rwa[1][i] = we[1] ? i_whiaddr[ABW-2:0] : i_ra[i][ABW-2:0];
	end
end

generate for (gi = 0; gi < VSIZE; gi++) begin: rd_mux_block
`ff_rst
	rd_mux[gi] <= 1'b0;
`ff_cg(i_re[gi])
	rd_mux[gi] <= i_ra[gi][ABW-1];
`ff_end
end endgenerate

//======================================
// Submodules
//======================================
generate for (gi = 0; gi < VSIZE; gi++) begin: sram
SRAMOnePort #(.BW(DBW), .NDATA(NDATA)) u_sp_sram0(
	.i_clk(i_clk),
	.i_rst(i_rst),
	.i_ce(ce[0][gi]),
	.i_r0w1(we[0]),
	.i_rwaddr(rwa[0][gi]),
	.i_wdata(i_wdata[gi]),
	.o_rdata(rd[0][gi])
);
SRAMOnePort #(.BW(DBW), .NDATA(NDATA)) u_sp_sram1(
	.i_clk(i_clk),
	.i_rst(i_rst),
	.i_ce(ce[1][gi]),
	.i_r0w1(we[1]),
	.i_rwaddr(rwa[1][gi]),
	.i_wdata(i_wdata[gi]),
	.o_rdata(rd[1][gi])
);
end endgenerate

endmodule
