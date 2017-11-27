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

module ChunkHead(
	`clk_port,
	`rdyack_port(i_abofs),
	i_bofs,
	i_aofs,
	i_beg,
	i_end,
	i_global_mofs,
	i_global_bshufs,
	i_bstrides_frac,
	i_bstrides_shamt,
	i_global_ashufs,
	i_astrides_frac,
	i_astrides_shamt,
	`rdyack_port(o_mofs),
	o_mofs,
	o_id
);
//======================================
// Parameter
//======================================
localparam GBW = TauCfg::GLOBAL_ADDR_BW;
localparam WBW = TauCfg::WORK_BW;
localparam N_ICFG = TauCfg::N_ICFG;
localparam VDIM = TauCfg::VDIM;
localparam DIM = TauCfg::DIM;
localparam SS_BW = TauCfg::STRIDE_BW;
localparam SF_BW = TauCfg::STRIDE_FRAC_BW;
// derived
localparam ICFG_BW = $clog2(N_ICFG+1);
localparam DIM_BW = $clog2(DIM);
localparam VDIM_BW = $clog2(VDIM);

`clk_input;
`rdyack_input(i_abofs);
input [WBW-1:0]     i_bofs [VDIM];
input [WBW-1:0]     i_aofs [VDIM];
input [ICFG_BW-1:0] i_beg;
input [ICFG_BW-1:0] i_end;
input [GBW-1:0]     i_global_mofs    [N_ICFG][DIM];
input [VDIM_BW-1:0] i_global_bshufs  [N_ICFG][VDIM];
input [SF_BW-1:0]   i_bstrides_frac  [N_ICFG][VDIM];
input [SS_BW-1:0]   i_bstrides_shamt [N_ICFG][VDIM];
input [VDIM_BW-1:0] i_global_ashufs  [N_ICFG][VDIM];
input [SF_BW-1:0]   i_astrides_frac  [N_ICFG][VDIM];
input [SS_BW-1:0]   i_astrides_shamt [N_ICFG][VDIM];
`rdyack_output(o_mofs);
output logic [GBW-1:0]     o_mofs   [DIM];
output logic [ICFG_BW-1:0] o_id;

//======================================
// Internal
//======================================
`dval_logic(i_init);
logic [WBW-1:0]     i_bofs_stride [VDIM];
logic [WBW-1:0]     i_aofs_stride [VDIM];
logic [ICFG_BW-1:0] i_cur_id_r;
logic [ICFG_BW-1:0] i_cur_id1;
logic [ICFG_BW-1:0] i_cur_id_w;
logic i_islast_id;
`rdyack_logic(o_mofs_raw);
logic [GBW-1:0]     o_mofs_w [DIM];

//======================================
// Combinational
//======================================
assign i_cur_id1 = i_cur_id_r + 'b1;
assign i_cur_id_w = i_init_dval ? i_beg : i_cur_id1;
assign i_islast_id = i_cur_id1 == i_end;
always_comb for (int i = 0; i < VDIM; i++) begin
	i_bofs_stride[i] = (i_bofs[i] * i_bstrides_frac[i_cur_id_r][i]) << i_bstrides_shamt[i_cur_id_r][i];
	i_aofs_stride[i] = (i_aofs[i] * i_astrides_frac[i_cur_id_r][i]) << i_astrides_shamt[i_cur_id_r][i];
end

//======================================
// Submodule
//======================================
OneCycleInit u_istage(
	`clk_connect,
	`rdyack_connect(src, i_abofs),
	`rdyack_connect(dst, i_abofs_delay),
	`dval_connect(init, i_init)
);
Forward u_fwd_ostage(
	`clk_connect,
	`rdyack_connect(src, i_abofs_delay),
	`rdyack_connect(dst, o_mofs_raw)
);
AcceptIf#(1) u_oacc(
	.cond(i_islast_id),
	`rdyack_connect(src, o_mofs_raw),
	`rdyack_connect(dst, o_mofs)
);
NDShufAccum#(.BW(WBW), .DIM_IN(VDIM), .DIM_OUT(DIM), .ZERO_AUG(1)) u_saccum(
	.i_augend(i_global_mofs),
	.o_sum(o_mofs_w),
	.i_addend1(i_bofs_stride),
	.i_addend2(i_aofs_stride),
	.i_shuf1(i_global_bshufs[i_cur_id_r]),
	.i_shuf2(i_global_ashufs[i_cur_id_r])
);

//======================================
// Sequential
//======================================
`ff_rst
	i_cur_id_r <= '0;
`ff_cg(i_init_dval || o_mofs_ack)
	i_cur_id_r <= i_cur_id_w;
`ff_end

`ff_rst
	o_id <= '0;
	for (int i = 0; i < DIM; i++) begin
		o_mofs[i] <= '0;
	end
`ff_cg(o_mofs_ack)
	o_id <= i_cur_id_r;
	o_mofs <= o_mofs_w;
`ff_end

endmodule
