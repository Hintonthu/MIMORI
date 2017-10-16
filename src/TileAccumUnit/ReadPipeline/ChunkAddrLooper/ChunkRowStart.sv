// Copyright 2016
// Yu Sheng Lin

// This file is part of Ocean.

// MIMORI is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// MIMORI is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with Ocean.  If not, see <http://www.gnu.org/licenses/>.

import TauCfg::*;

module ChunkRowStart(
	`clk_port,
	`rdyack_port(mofs),
	i_mofs,
	i_mpad,
	i_mbound,
	i_mlast,
	i_maddr,
	`rdyack_port(row),
	o_row_linear,
	o_row_islast,
	o_row_pad
);

//======================================
// Parameter
//======================================
parameter LBW = TauCfg::LOCAL_ADDR_BW0;
localparam GBW = TauCfg::GLOBAL_ADDR_BW;
localparam DIM = TauCfg::DIM;
localparam VSIZE = TauCfg::VECTOR_SIZE;
// derived
localparam V_BW = $clog2(VSIZE);
localparam DBW = $clog2(DIM);
// Workaround
logic [GBW-1:0] ROW_ZERO [DIM-1] = '{default:0};

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
`rdyack_output(row);
output logic [GBW-1:0]  o_row_linear;
output logic            o_row_islast;
output logic [V_BW-1:0] o_row_pad;

//======================================
// Internal
//======================================
`rdyack_logic(init_dst);
`dval_logic(init);
logic [GBW-1:0] mlast_cut [DIM-1];
logic [DIM-2:0] add_flag;
logic [DIM-2:0] reset_flag;
logic [GBW-1:0] cur_r   [DIM-1];
logic [GBW-1:0] cur_nxt [DIM-1];
logic [GBW-1:0] cur_w   [DIM-1];
logic [GBW-1:0]  row_unclamp [DIM-1];
logic [GBW-1:0]  row_clamp   [DIM-1];
logic [DIM-1:0]  routing_2d [1];
logic [V_BW-1:0] row_pad_2d [1];
logic [GBW-1:0]  mstride [DIM-1];

//======================================
// Submodule
//======================================
OneCycleInit u_init(
	`clk_connect,
	`rdyack_connect(src, mofs),
	`rdyack_connect(dst, init_dst),
	`dval_connect(init, init)
);
NDCounterAddFlag#(GBW, DIM-1) u_flag(
	.i_cur(cur_r),
	.i_end(mlast_cut),
	.i_carry(1'b1),
	.o_reset_counter(reset_flag),
	.o_add_counter(add_flag),
	.o_done(o_row_islast)
);
NDCounterAddSelect#(GBW,DIM-1,0,0,0) u_sel(
	.i_augend(cur_r),
	.o_sum(cur_nxt),
	.i_start(ROW_ZERO),
	.i_step(mstride),
	.i_frac(),
	.i_shamt(),
	.i_reset_counter(reset_flag),
	.i_add_counter(add_flag)
);
OrCrossBar#(V_BW,DIM,1) u_selpad(
	.i_data(i_mpad),
	.i_routing(routing_2d),
	.o_data(row_pad_2d),
	.o_mask()
);
AcceptIf u_acc_if_last(
	.cond(o_row_islast),
	`rdyack_connect(src, init_dst),
	`rdyack_connect(dst, row)
);

//======================================
// Combinational
//======================================
assign routing_2d[0] = {add_flag, o_row_islast};
assign o_row_pad = row_pad_2d[0];
always_comb begin
	for (int i = 0; i < DIM-2; i++) begin
		mstride[i] = i_mbound[i+1] + i_mbound[i+2] + 'b1;
		mlast_cut[i] = i_mlast[i];
	end
	mstride[DIM-2] = i_mbound[DIM-1] + 'b1;
	mlast_cut[DIM-2] = i_mlast[DIM-2];
end

always_comb begin
	o_row_linear = i_maddr;
	for (int i = 0; i < DIM-1; i++) begin
		row_unclamp[i] = cur_r[i] + i_mofs[i];
		unique case (1'b1)
			row_unclamp[i][GBW-1]:                            row_clamp[i] = '0; // sign bit (negative)
			($signed(row_unclamp[i]) > $signed(i_mbound[i])): row_clamp[i] = i_mbound[i];
			default:                                          row_clamp[i] = row_unclamp[i];
		endcase
		o_row_linear = o_row_linear + row_clamp[i];
	end
end

always_comb begin
	casez ({init_dval,row_ack})
		2'b1?: begin cur_w = ROW_ZERO; end
		2'b01: begin cur_w = cur_nxt;  end
		2'b00: begin cur_w = cur_r;    end
	endcase
end

//======================================
// Sequential
//======================================
`ff_rst
	cur_r <= ROW_ZERO;
`ff_cg(init_dval || row_ack)
	cur_r <= cur_w;
`ff_end

endmodule
