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

module AccumWarpLooperMemofsStage(
	`clk_port,
	`rdyack_port(src),
	i_id,
	i_bofs,
	i_aofs,
	i_retire,
	i_islast,
	i_global_bshuf,
	i_global_ashuf,
	i_bstride_frac,
	i_bstride_shamt,
	i_astride_frac,
	i_astride_shamt,
	i_linear,
	i_mboundary,
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
parameter N_CFG = TauCfg::N_ICFG;
parameter ABW = TauCfg::GLOBAL_ADDR_BW;
localparam WBW = TauCfg::WORK_BW;
localparam VDIM = TauCfg::VDIM;
localparam DIM = TauCfg::DIM;
localparam VSIZE = TauCfg::VSIZE;
localparam SS_BW = TauCfg::STRIDE_BW;
localparam SF_BW = TauCfg::STRIDE_FRAC_BW;
// derived
localparam NCFG_BW = $clog2(N_CFG+1);
localparam CV_BW = $clog2(VSIZE);
localparam CCV_BW = $clog2(CV_BW+1);
localparam DIM_BW = $clog2(DIM);

//======================================
// I/O
//======================================
`clk_input;
`rdyack_input(src);
input [NCFG_BW-1:0] i_id;
input [WBW-1:0]     i_bofs [VDIM];
input [WBW-1:0]     i_aofs [VDIM];
input               i_retire;
input               i_islast;
input [DIM_BW-1:0]  i_global_bshuf    [VDIM];
input [DIM_BW-1:0]  i_global_ashuf    [VDIM];
input [SF_BW-1:0]   i_bstride_frac    [VDIM];
input [SS_BW-1:0]   i_bstride_shamt   [VDIM];
input [SF_BW-1:0]   i_astride_frac    [VDIM];
input [SS_BW-1:0]   i_astride_shamt   [VDIM];
input [ABW-1:0]     i_linear;
input [ABW-1:0]     i_mboundary [DIM];
`rdyack_output(dst);
output logic [NCFG_BW-1:0] o_id;
output logic [ABW-1:0]     o_linear;
output logic [WBW-1:0]     o_bofs [VDIM];
output logic               o_retire;
output logic               o_islast;

//======================================
// Internal
//======================================
logic [WBW-1:0] bofs_stride [VDIM];
logic [WBW-1:0] aofs_stride [VDIM];
`rdyack_logic(s0);
logic [WBW-1:0]     s0_mofs_nd_r  [DIM];
logic [ABW-1:0]     s0_mofs_nd_rz [DIM];
logic [WBW-1:0]     s0_mofs_nd_w  [DIM];
logic [ABW-1:0]     s0_mult_r [DIM-1];
logic [ABW-1:0]     s0_linear_r;
logic [NCFG_BW-1:0] s0_id_r;
logic               s0_islast_r;
logic [WBW-1:0]     s0_bofs_r [VDIM];
logic               s0_retire_r;
logic [ABW-1:0]     o_linear_w;

//======================================
// Combinational
//======================================
always_comb for (int i = 0; i < VDIM; i++) begin
	bofs_stride[i] = (i_bofs[i] * i_bstride_frac[i]) << i_bstride_shamt[i];
	aofs_stride[i] = (i_aofs[i] * i_astride_frac[i]) << i_astride_shamt[i];
end

always_comb for (int i = 0; i < DIM; i++) begin
	// lint error for bit width mismatch
	s0_mofs_nd_rz[i] = s0_mofs_nd_r[i];
end

always_comb begin
	o_linear_w = '0;
	for (int i = 0; i < DIM-1; i++) begin
		o_linear_w = o_linear_w + s0_mofs_nd_rz[i] * s0_mult_r[i];
	end
	o_linear_w = o_linear_w + s0_linear_r + s0_mofs_nd_rz[DIM-1];
end

//======================================
// Submodule
//======================================
Forward u_fwd0(
	`clk_connect,
	`rdyack_connect(src, src),
	`rdyack_connect(dst, s0)
);
Forward u_fwd1(
	`clk_connect,
	`rdyack_connect(src, s0),
	`rdyack_connect(dst, dst)
);
NDShufAccum#(.BW(WBW), .DIM_IN(VDIM), .DIM_OUT(DIM), .ZERO_AUG(1)) u_saccum(
	.i_augend(),
	.o_sum(s0_mofs_nd_w),
	.i_addend1(bofs_stride),
	.i_addend2(aofs_stride),
	.i_shuf1(i_global_bshuf),
	.i_shuf2(i_global_ashuf)
);

//======================================
// Sequential
//======================================
`ff_rst
	for (int i = 0; i < DIM-1; i++) begin
		s0_mult_r[i] <= '0;
	end
	for (int i = 0; i < VDIM; i++) begin
		s0_bofs_r[i] <= '0;
	end
	for (int i = 0; i < DIM; i++) begin
		s0_mofs_nd_r[i] <= '0;
	end
	s0_linear_r <= '0;
	s0_id_r <= '0;
	s0_islast_r <= 1'b0;
	s0_retire_r <= 1'b0;
`ff_cg(src_ack)
	for (int i = 0; i < DIM-1; i++) begin
		s0_mult_r[i] <= i_mboundary[i+1];
	end
	s0_mofs_nd_r <= s0_mofs_nd_w;
	s0_bofs_r <= i_bofs;
	s0_linear_r <= i_linear;
	s0_id_r <= i_id;
	s0_islast_r <= i_islast;
	s0_retire_r <= i_retire;
`ff_end

`ff_rst
	for (int i = 0; i < VDIM; i++) begin
		o_bofs[i] <= '0;
	end
	o_linear <= '0;
	o_id <= '0;
	o_islast <= 1'b0;
	o_retire <= 1'b0;
`ff_cg(s0_ack)
	o_linear <= o_linear_w;
	o_id <= s0_id_r;
	o_islast <= s0_islast_r;
	o_bofs <= s0_bofs_r;
	o_retire <= s0_retire_r;
`ff_end

endmodule
