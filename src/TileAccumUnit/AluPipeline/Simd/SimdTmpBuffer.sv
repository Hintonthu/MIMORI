// Copyright 2016,2018 Yu Sheng Lin

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

module SimdTmpBuffer(
	`clk_port,
	i_we,
	i_wdata,
	o_rdatas
);

//======================================
// Parameter
//======================================
localparam VSIZE = TauCfg::VSIZE;
localparam TDBW = TauCfg::TMP_DATA_BW;
localparam TBUF_SIZE = TauCfg::ALU_DELAY_BUF_SIZE;

//======================================
// I/O
//======================================
`clk_input;
input                   i_we;
input        [TDBW-1:0] i_wdata  [VSIZE];
output logic [TDBW-1:0] o_rdatas [TBUF_SIZE][2][VSIZE];

//======================================
// Sequential
//======================================
logic warp_hi;
`ff_rst
	warp_hi <= 1'b0;
`ff_cg(i_we)
	warp_hi <= !warp_hi;
`ff_end

`ff_rst
	for (int j = 0; j < VSIZE; j++) begin
		o_rdatas[0][0][j] <= '0;
	end
`ff_cg(i_we && !warp_hi)
	for (int j = 0; j < VSIZE; j++) begin
		o_rdatas[0][0][j] <= i_wdata[j];
	end
`ff_end

`ff_rst
	for (int j = 0; j < VSIZE; j++) begin
		o_rdatas[0][1][j] <= '0;
	end
`ff_cg(i_we && warp_hi)
	for (int j = 0; j < VSIZE; j++) begin
		o_rdatas[0][1][j] <= i_wdata[j];
	end
`ff_end

`ff_rst
	for (int i = 1; i < TBUF_SIZE; i++) begin
		for (int w = 0; w < 2; w++) begin
			for (int j = 0; j < VSIZE; j++) begin
				o_rdatas[i][w][j] <= '0;
			end
		end
	end
`ff_cg(i_we && !warp_hi)
	for (int i = 1; i < TBUF_SIZE; i++) begin
		for (int w = 0; w < 2; w++) begin
			for (int j = 0; j < VSIZE; j++) begin
				o_rdatas[i][w][j] <= o_rdatas[i-1][w][j];
			end
		end
	end
`ff_end

endmodule
