// Copyright 2017-2018
// Yu Sheng Lin

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

module ChunkRowStart(
	`clk_port,
	`rdyack_port(mofs),
	i_mofs,
	i_mpad,
	i_mbound,
	i_mlast,
	i_maddr,
	i_wrap,
	`rdyack_port(row),
	o_row_linear,
	o_row_islast,
	o_row_pad,
	o_row_valid
);

//======================================
// Parameter
//======================================
parameter LBW = TauCfg::LOCAL_ADDR_BW0;
localparam GBW = TauCfg::GLOBAL_ADDR_BW;
localparam DIM = TauCfg::DIM;
localparam VSIZE = TauCfg::VSIZE;
// derived
localparam V_BW = $clog2(VSIZE);
localparam DBW = $clog2(DIM);

//======================================
// I/O
//======================================
`clk_input;
`rdyack_input(mofs);
input [GBW-1:0]  i_mofs    [DIM];
input [V_BW-1:0] i_mpad    [DIM];
input [GBW-1:0]  i_mbound  [DIM];
input [GBW-1:0]  i_mlast   [DIM];
input [GBW-1:0]  i_maddr;
input            i_wrap;
`rdyack_output(row);
output logic [GBW-1:0]  o_row_linear;
output logic            o_row_islast;
output logic [V_BW-1:0] o_row_pad;
output logic            o_row_valid;

//======================================
// Internal
//======================================
logic [GBW-1:0] i_row_end    [DIM-1];
logic [GBW-1:0] i_row_stride [DIM-1];
logic [GBW-1:0]  o_cur_row [DIM-1];
logic [GBW-1:0]  o_row_unclamp [DIM-1];
logic [GBW-1:0]  o_row_clamp   [DIM-1];
logic [DIM-1:0]  o_routing_rev;
logic [DIM-1:0]  o_routing_2d [1];
logic [V_BW-1:0] o_row_pad_2d [1];
logic [DIM-2:0]  o_row_valid_all;

//======================================
// Submodule
//======================================
OffsetStage#(.BW(GBW), .DIM(DIM-1), .FROM_ZERO(1), .UNIT_STRIDE(0)) u_ostage(
	`clk_connect,
	`rdyack_connect(src, mofs),
	.i_ofs_beg(),
	.i_ofs_end(i_row_end),
	.i_ofs_gend(i_row_end),
	.i_stride(i_row_stride),
	`rdyack_connect(dst, row),
	.o_ofs(o_cur_row),
	.o_lofs(),
	.o_sel_beg(),
	.o_sel_end(o_routing_rev),
	.o_sel_ret(),
	.o_islast(o_row_islast)
);
OrCrossBar#(V_BW,DIM,1) u_ostage_selpad(
	.i_data(i_mpad),
	.i_routing(o_routing_2d),
	.o_data(o_row_pad_2d),
	.o_mask()
);

//======================================
// Combinational
//======================================
// reshape
assign o_row_pad = o_row_pad_2d[0];
always_comb begin
	for (int i = 0; i < DIM-1; i++) begin
		i_row_stride[i] = i_mbound[i+1];
		i_row_end[i] = i_mlast[i];
	end
end
always_comb begin
	for (int i = 0; i < DIM; i++) begin
		o_routing_2d[0][i] = o_routing_rev[DIM-1-i];
	end
end

always_comb begin
	o_row_linear = i_maddr;
	for (int i = 0; i < DIM-1; i++) begin
		o_row_unclamp[i] = o_cur_row[i] + i_mofs[i];
		unique case (1'b1)
			o_row_unclamp[i][GBW-1]: begin: neg_value
				o_row_clamp[i] = '0;
				o_row_valid_all[i] = 1'b0;
			end
			($signed(o_row_unclamp[i]) >= $signed(i_mbound[i])): begin: over_run
				o_row_clamp[i] = i_mbound[i]-i_mbound[i+1];
				o_row_valid_all[i] = 1'b0;
			end
			default: begin: normal_mode
				o_row_clamp[i] = o_row_unclamp[i];
				o_row_valid_all[i] = 1'b1;
			end
		endcase
		o_row_linear = o_row_linear + o_row_clamp[i];
	end
	o_row_valid = i_wrap || (&o_row_valid_all);
end

endmodule
