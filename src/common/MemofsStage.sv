// Copyright 2016 Yu Sheng Lin

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

module MemofsStage(
	`clk_port,
	`rdyack_port(src),
	i_bofs_frac,
	i_bofs_shamt,
	i_mofs_starts,
	i_mofs_steps,
	i_mofs_shufs,
	i_reset_flag,
	i_add_flag,
	i_islast,
	i_id,
	`rdyack_port(dst),
	o_mofs,
	o_id,
	`dval_port(islast)
);
//======================================
// Parameter
//======================================
parameter N_CFG = TauCfg::N_ICFG;
parameter FRAC_BW = TauCfg::BOFS_FRAC_BW;
parameter SHAMT_BW = TauCfg::BOFS_SHAMT_BW;
parameter SUM_ALL = 0;
localparam GBW = TauCfg::GLOBAL_ADDR_BW;
localparam DIM = TauCfg::DIM;
// derived
localparam CFG_BW = $clog2(N_CFG+1);
localparam DIM_BW = $clog2(DIM);
localparam SDIM = SUM_ALL ? 1 : DIM;
logic [GBW-1:0] ND_AZERO [DIM] = '{default: 0};

//======================================
// I/O
//======================================
`clk_input;
`rdyack_input(src);
input [FRAC_BW-1:0]  i_bofs_frac          [DIM];
input [SHAMT_BW-1:0] i_bofs_shamt         [DIM];
input [GBW-1:0]      i_mofs_steps  [N_CFG][DIM];
input [GBW-1:0]      i_mofs_starts [N_CFG][SDIM];
input [DIM_BW-1:0]   i_mofs_shufs  [N_CFG][DIM];
input [DIM-1:0]      i_reset_flag;
input [DIM-1:0]      i_add_flag;
input                i_islast;
input [CFG_BW-1:0]   i_id;
`rdyack_output(dst);
output logic [GBW-1:0]    o_mofs [SDIM];
output logic [CFG_BW-1:0] o_id;
`dval_output(islast);

//======================================
// Internal
//======================================
logic islast_r;
logic [GBW-1:0] mofs_raw_r [DIM];
logic [GBW-1:0] mofs_raw_w [DIM];
logic [GBW-1:0] mofs_w [SDIM];

//======================================
// Submodule
//======================================
Forward u_fwd(
	`clk_connect,
	`rdyack_connect(src, src),
	`rdyack_connect(dst, dst)
);
NDCounterAddSelect#(
	.BW(GBW),
	.DIM(DIM),
	.FRAC_BW(FRAC_BW),
	.SHAMT_BW(SHAMT_BW),
	.UNIT_STEP(0)
) u_mofs_raw_sel(
	.i_augend(mofs_raw_r),
	.o_sum(mofs_raw_w),
	.i_start(ND_AZERO),
	.i_step(i_mofs_steps[i_id]),
	.i_frac(i_bofs_frac),
	.i_shamt(i_bofs_shamt),
	.i_reset_counter(i_reset_flag),
	.i_add_counter(i_add_flag)
);
Registers2D#(.BW(GBW), .D1(DIM), .NDATA(N_CFG)) u_mofs_raw_reg(
	.i_clk(i_clk),
	.i_rst(i_rst),
	.i_we(src_ack),
	.i_waddr(i_id),
	.i_wdata(mofs_raw_w),
	.i_raddr(i_id),
	.o_rdata(mofs_raw_r)
);
NDShufAccum #(.BW(GBW), .DIM(DIM), .SUM_ALL(SUM_ALL)) u_shuf(
	.i_augend(i_mofs_starts[i_id]),
	.o_sum(mofs_w),
	.i_addend(mofs_raw_w),
	.i_shuf(i_mofs_shufs[i_id])
);

//======================================
// Combinational
//======================================
assign islast_dval = islast_r && dst_ack;

//======================================
// Sequential
//======================================
`ff_rst
	for (int i = 0; i < SDIM; i++) begin
		o_mofs[i] <= '0;
	end
	o_id <= '0;
	islast_r <= 1'b0;
`ff_cg(src_ack)
	o_mofs <= mofs_w;
	o_id <= i_id;
	islast_r <= i_islast;
`ff_end

endmodule
