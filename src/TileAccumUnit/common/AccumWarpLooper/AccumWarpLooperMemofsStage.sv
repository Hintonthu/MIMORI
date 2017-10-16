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

module AccumWarpLooperMemofsStage(
	`clk_port,
	`rdyack_port(src),
	i_a_reset_flag,
	i_a_add_flag,
	i_bu_reset_flag,
	i_bu_add_flag,
	i_bl_reset_flag,
	i_bl_add_flag,
	i_id,
	i_bofs,
	i_retire,
	i_islast,
	i_bsub_up_order,
	i_mofs_bsteps,
	i_mofs_asteps,
	`rdyack_port(dst),
	o_id,
	o_linear,
	o_bofs,
	o_retire,
	o_islast
);
//======================================
// Parameter
//======================================
parameter N_CFG = Default::N_CFG;
parameter ABW = Default::ABW;
localparam WBW = TauCfg::WORK_BW;
localparam DIM = TauCfg::DIM;
localparam VSIZE = TauCfg::VECTOR_SIZE;
// derived
localparam NCFG_BW = $clog2(N_CFG+1);
localparam CV_BW = $clog2(VSIZE);
localparam CCV_BW = $clog2(CV_BW+1);
// Workaround
logic [ABW-1:0] ND_AZERO [DIM] = '{default:0};

//======================================
// I/O
//======================================
`clk_input;
`rdyack_input(src);
input [DIM-1:0]     i_a_reset_flag;
input [DIM-1:0]     i_a_add_flag;
input [DIM-1:0]     i_bu_reset_flag;
input [DIM-1:0]     i_bu_add_flag;
input [DIM-1:0]     i_bl_reset_flag;
input [DIM-1:0]     i_bl_add_flag;
input [NCFG_BW-1:0] i_id;
input [WBW-1:0]     i_bofs [DIM];
input               i_retire;
input               i_islast;
input [CCV_BW:0]    i_bsub_up_order [DIM];
input [ABW-1:0]     i_mofs_bsteps   [N_CFG][DIM];
input [ABW-1:0]     i_mofs_asteps   [N_CFG][DIM];
`rdyack_output(dst);
output logic [NCFG_BW-1:0] o_id;
output logic [ABW-1:0]     o_linear;
output logic [WBW-1:0]     o_bofs [DIM];
output logic               o_retire;
output logic               o_islast;

//======================================
// Internal
//======================================
logic [ABW-1:0] mofs_raw_accum_r [DIM];
logic [ABW-1:0] mofs_raw_accum_w [DIM];
logic [ABW-1:0] mofs_raw_upper_r [DIM];
logic [ABW-1:0] mofs_raw_upper_w [DIM];
logic [ABW-1:0] mofs_raw_lower_r [DIM];
logic [ABW-1:0] mofs_raw_lower_w [DIM];
logic [ABW-1:0] linear_w;

//======================================
// Combinational
//======================================
always_comb begin
	linear_w = '0;
	for (int i = 0; i < DIM; i++) begin
		linear_w = linear_w
			+ mofs_raw_accum_w[i]
			+ mofs_raw_lower_w[i]
			+ mofs_raw_upper_w[i];
	end
end

//======================================
// Submodule
//======================================
Forward u_fwd(
	`clk_connect,
	`rdyack_connect(src, src),
	`rdyack_connect(dst, dst)
);
NDCounterAddSelect#(
	.BW(ABW),
	.DIM(DIM),
	.FRAC_BW(0),
	.SHAMT_BW(0),
	.UNIT_STEP(0)
) u_accumofs_sel(
	.i_augend(mofs_raw_accum_r),
	.o_sum(mofs_raw_accum_w),
	.i_start(ND_AZERO),
	.i_step(i_mofs_asteps[i_id]),
	.i_frac(),
	.i_shamt(),
	.i_reset_counter(i_a_reset_flag),
	.i_add_counter(i_a_add_flag)
);
NDCounterAddSelect#(
	.BW(ABW),
	.DIM(DIM),
	.FRAC_BW(0),
	.SHAMT_BW(CCV_BW+1),
	.UNIT_STEP(0)
) u_upperofs_sel(
	.i_augend(mofs_raw_upper_r),
	.o_sum(mofs_raw_upper_w),
	.i_start(ND_AZERO),
	.i_step(i_mofs_bsteps[i_id]),
	.i_frac(),
	.i_shamt(i_bsub_up_order),
	.i_reset_counter(i_bu_reset_flag),
	.i_add_counter(i_bu_add_flag)
);
NDCounterAddSelect#(
	.BW(ABW),
	.DIM(DIM),
	.FRAC_BW(0),
	.SHAMT_BW(0),
	.UNIT_STEP(0)
) u_lowerofs_sel(
	.i_augend(mofs_raw_lower_r),
	.o_sum(mofs_raw_lower_w),
	.i_start(ND_AZERO),
	.i_step(i_mofs_bsteps[i_id]),
	.i_frac(),
	.i_shamt(),
	.i_reset_counter(i_bl_reset_flag),
	.i_add_counter(i_bl_add_flag)
);
Registers2D#(.BW(ABW), .D1(DIM), .NDATA(N_CFG)) u_mofs_raw_reg_accum(
	.i_clk(i_clk),
	.i_rst(i_rst),
	.i_we(src_ack),
	.i_waddr(i_id),
	.i_wdata(mofs_raw_accum_w),
	.i_raddr(i_id),
	.o_rdata(mofs_raw_accum_r)
);
Registers2D#(.BW(ABW), .D1(DIM), .NDATA(N_CFG)) u_mofs_raw_reg_upper(
	.i_clk(i_clk),
	.i_rst(i_rst),
	.i_we(src_ack),
	.i_waddr(i_id),
	.i_wdata(mofs_raw_upper_w),
	.i_raddr(i_id),
	.o_rdata(mofs_raw_upper_r)
);
Registers2D#(.BW(ABW), .D1(DIM), .NDATA(N_CFG)) u_mofs_raw_reg_lower(
	.i_clk(i_clk),
	.i_rst(i_rst),
	.i_we(src_ack),
	.i_waddr(i_id),
	.i_wdata(mofs_raw_lower_w),
	.i_raddr(i_id),
	.o_rdata(mofs_raw_lower_r)
);

//======================================
// Sequential
//======================================
`ff_rst
	for (int i = 0; i < DIM; i++) begin
		o_bofs[i] <= '0;
	end
	o_linear <= '0;
	o_id <= '0;
	o_islast <= 1'b0;
	o_retire <= 1'b0;
`ff_cg(src_ack)
	o_linear <= linear_w;
	o_id <= i_id;
	o_islast <= i_islast;
	o_bofs <= i_bofs;
	o_retire <= i_retire;
`ff_end

endmodule
