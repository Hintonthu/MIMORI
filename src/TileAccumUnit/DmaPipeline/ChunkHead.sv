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


module ChunkHead(
	`clk_port,
	`rdyack_port(i_abofs),
	i_which,
	i_bofs,
	i_aofs,
	i_beg,
	i_end,
`ifdef SD
	i_syst_type,
`endif
	i_global_mofs,
	i_global_bshufs,
	i_bstrides_frac,
	i_bstrides_shamt,
	i_global_ashufs,
	i_astrides_frac,
	i_astrides_shamt,
`ifdef SD
	i_systolic_skip,
`endif
	`rdyack_port(o_mofs),
	o_which,
	o_mofs,
	o_id,
	o_islast_id
`ifdef SD
	,
	o_skip
`endif
);
//======================================
// Parameter
//======================================
import TauCfg::*;
localparam WBW = TauCfg::WORK_BW;
localparam N_ICFG = TauCfg::N_ICFG;
localparam VDIM = TauCfg::VDIM;
localparam DIM = TauCfg::DIM;
localparam SS_BW = TauCfg::STRIDE_BW;
localparam SF_BW = TauCfg::STRIDE_FRAC_BW;
// derived
localparam ICFG_BW = $clog2(N_ICFG+1);
localparam DIM_BW = $clog2(DIM);

`clk_input;
`rdyack_input(i_abofs);
input               i_which;
input [WBW-1:0]     i_bofs [VDIM];
input [WBW-1:0]     i_aofs [VDIM];
input [ICFG_BW-1:0] i_beg;
input [ICFG_BW-1:0] i_end;
`ifdef SD
input [STO_BW-1:0]  i_syst_type;
`endif
input [WBW-1:0]     i_global_mofs    [N_ICFG][DIM];
input [DIM_BW-1:0]  i_global_bshufs  [N_ICFG][VDIM];
input [SF_BW-1:0]   i_bstrides_frac  [N_ICFG][VDIM];
input [SS_BW-1:0]   i_bstrides_shamt [N_ICFG][VDIM];
input [DIM_BW-1:0]  i_global_ashufs  [N_ICFG][VDIM];
input [SF_BW-1:0]   i_astrides_frac  [N_ICFG][VDIM];
input [SS_BW-1:0]   i_astrides_shamt [N_ICFG][VDIM];
`ifdef SD
input [N_ICFG-1:0]  i_systolic_skip;
`endif
`rdyack_output(o_mofs);
output logic               o_which;
output logic [WBW-1:0]     o_mofs [DIM];
output logic [ICFG_BW-1:0] o_id;
output logic               o_islast_id;
`ifdef SD
output logic               o_skip;
`endif

//======================================
// Internal
//======================================
logic loop_init;
logic loop_cg;
logic [WBW-1:0]     i_bofs_stride [VDIM];
logic [WBW-1:0]     i_aofs_stride [VDIM];
logic [WBW-1:0]     global_mofs_w   [DIM];
logic [DIM_BW-1:0]  global_bshuf_w [VDIM];
logic [DIM_BW-1:0]  global_ashuf_w [VDIM];
logic [ICFG_BW-1:0] o_id1;
logic [ICFG_BW-1:0] o_id_w;
logic [WBW-1:0]     o_mofs_w [DIM];

//======================================
// Combinational
//======================================
assign o_id1 = o_id + 'b1;
assign o_id_w = loop_init ? i_beg : o_id1;
assign o_islast_id = o_id1 == i_end;
always_comb for (int i = 0; i < VDIM; i++) begin
	i_bofs_stride[i] = (i_bofs[i] * i_bstrides_frac[o_id_w][i]) << i_bstrides_shamt[o_id_w][i];
	i_aofs_stride[i] = (i_aofs[i] * i_astrides_frac[o_id_w][i]) << i_astrides_shamt[o_id_w][i];
	global_bshuf_w[i] = i_global_bshufs[o_id_w][i];
	global_ashuf_w[i] = i_global_ashufs[o_id_w][i];
end

always_comb for (int i = 0; i < DIM; i++) begin
	global_mofs_w[i] = i_global_mofs[o_id_w][i];
end

//======================================
// Submodule
//======================================
LoopController#(.DONE_IF(1), .HOLD_SRC(1)) u_lc(
	`clk_connect,
	`rdyack_connect(src, i_abofs),
	`rdyack_connect(dst, o_mofs),
	.loop_done_cond(o_islast_id),
	.reg_cg(loop_cg),
	.loop_reset(loop_init),
	.loop_is_last(),
	.loop_is_repeat()
);
NDShufAccum#(.BW(WBW), .DIM_IN(VDIM), .DIM_OUT(DIM), .ZERO_AUG(0)) u_saccum(
	.i_augend(global_mofs_w),
	.o_sum(o_mofs_w),
	.i_addend1(i_bofs_stride),
	.i_addend2(i_aofs_stride),
	.i_shuf1(global_bshuf_w),
	.i_shuf2(global_ashuf_w)
);

//======================================
// Sequential
//======================================
`ff_rst
	o_which <= 1'b0;
	o_id <= '0;
	for (int i = 0; i < DIM; i++) begin
		o_mofs[i] <= '0;
	end
`ifdef SD
	o_skip <= 1'b0;
`endif
`ff_cg(loop_cg)
	o_which <= i_which;
	o_id <= o_id_w;
	o_mofs <= o_mofs_w;
`ifdef SD
	o_skip <= i_systolic_skip[o_id_w] && `IS_FROM_SIDE(i_syst_type);
`endif
`ff_end

endmodule
