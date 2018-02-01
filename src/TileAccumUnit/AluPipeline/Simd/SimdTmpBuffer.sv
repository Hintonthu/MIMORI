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

import TauCfg::*;

module SimdTmpBuffer(
	`clk_port,
	i_we,
	i_wdata,
	o_rdatas
);

//======================================
// Parameter
//======================================
localparam VSIZE = TauCfg::VECTOR_SIZE;
localparam TDBW = TauCfg::TMP_DATA_BW;
localparam TBUF_SIZE = TauCfg::ALU_DELAY_BUF_SIZE;

//======================================
// I/O
//======================================
`clk_input;
input                   i_we;
input        [TDBW-1:0] i_wdata  [VSIZE];
output logic [TDBW-1:0] o_rdatas [TBUF_SIZE][VSIZE];

//======================================
// Sequential
//======================================
`ff_rst
	for (int i = 0; i < TBUF_SIZE; i++) begin
		for (int j = 0; j < VSIZE; j++) begin
			o_rdatas[i][j] <= '0;
		end
	end
`ff_cg(i_we)
	for (int j = 0; j < VSIZE; j++) begin
		o_rdatas[0][j] <= i_wdata[j];
	end
	for (int i = 1; i < TBUF_SIZE; i++) begin
		for (int j = 0; j < VSIZE; j++) begin
			o_rdatas[i][j] <= o_rdatas[i-1][j];
		end
	end
`ff_end

endmodule
