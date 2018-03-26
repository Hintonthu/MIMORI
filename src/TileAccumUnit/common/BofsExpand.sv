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

module BofsExpand(
	i_bofs,
	i_bboundary,
	i_bsubofs,
	i_bsub_lo_order,
	o_valid,
	o_vector_bofs
);

//======================================
// Parameter
//======================================
localparam WBW = TauCfg::WORK_BW;
localparam VDIM = TauCfg::VDIM;
localparam VSIZE = TauCfg::VSIZE;
// derived
localparam CV_BW = $clog2(VSIZE);
localparam CCV_BW = $clog2(CV_BW+1);
localparam [WBW-CV_BW-1:0] BLK_PAD_ZERO = 0;

//======================================
// I/O
//======================================
input [WBW-1:0]     i_bofs  [VDIM];
input [WBW-1:0]     i_bboundary      [VDIM];
input [CV_BW-1:0]   i_bsubofs [VSIZE][VDIM];
input [CCV_BW-1:0]  i_bsub_lo_order  [VDIM];
output logic [VSIZE-1:0] o_valid;
output logic [WBW-1:0] o_vector_bofs [VSIZE][VDIM];

//======================================
// Combinational
//======================================
always_comb begin
	for (int i = 0; i < VSIZE; i++) begin
		o_valid[i] = 1'b1;
		for (int j = 0; j < VDIM; j++) begin
			o_vector_bofs[i][j] =
				i_bofs[j] |
				{BLK_PAD_ZERO, i_bsubofs[i][j]} << i_bsub_lo_order[j];
			o_valid[i] = o_valid[i] && i_bboundary[j] > o_vector_bofs[i][j];
		end
	end
end

endmodule
