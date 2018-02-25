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

module AccumWarpLooperIndexStage(
	`clk_port,
	`rdyack_port(src),
	i_bofs,
	i_aofs,
	i_alofs,
	i_islast,
	i_id_beg,
	i_id_end,
	i_id_ret,
	i_bgrid_step,
	i_bsub_up_order,
	i_bsub_lo_order,
	`rdyack_port(dst),
	o_id,
	o_warpid,
	o_bofs,
	o_aofs,
	o_blofs,
	o_alofs,
	o_retire,
	o_islast
);

//======================================
// Parameter
//======================================
parameter N_CFG = TauCfg::N_ICFG;
localparam WBW = TauCfg::WORK_BW;
localparam VDIM = TauCfg::VDIM;
localparam VSIZE = TauCfg::VSIZE;
localparam MAX_WARP = TauCfg::MAX_WARP;
// derived
localparam NCFG_BW = $clog2(N_CFG+1);
localparam CV_BW = $clog2(VSIZE);
localparam CCV_BW = $clog2(CV_BW+1);
localparam WID_BW = $clog2(MAX_WARP);

//======================================
// I/O
//======================================
`clk_input;
`rdyack_input(src);
input [WBW-1:0]     i_bofs  [VDIM];
input [WBW-1:0]     i_aofs  [VDIM];
input [WBW-1:0]     i_alofs [VDIM];
input               i_islast;
input [NCFG_BW-1:0] i_id_beg;
input [NCFG_BW-1:0] i_id_end;
input [NCFG_BW-1:0] i_id_ret;
input [WBW-1:0]     i_bgrid_step    [VDIM];
input [CCV_BW-1:0]  i_bsub_up_order [VDIM];
input [CCV_BW-1:0]  i_bsub_lo_order [VDIM];
`rdyack_output(dst);
output logic [NCFG_BW-1:0] o_id;
output logic [WID_BW-1:0]  o_warpid;
output logic [WBW-1:0]     o_bofs [VDIM];
output logic [WBW-1:0]     o_aofs [VDIM];
output logic [WBW-1:0]     o_blofs [VDIM];
output logic [WBW-1:0]     o_alofs [VDIM];
output logic               o_retire;
output logic               o_islast;

//======================================
// Internal
//======================================
`rdyack_logic(s0_dst);
`rdyack_logic(s0_dst_delay);
`dval_logic(s0_init);
logic               s0_islast_aofs_r;
logic               s0_islast_id;
logic               s0_islast_bofs;
logic               s0_islast_bofs_id;
logic [NCFG_BW-1:0] s0_id_beg_r;
logic [NCFG_BW-1:0] s0_id_end_r;
logic [NCFG_BW-1:0] s0_id_ret_r;
logic [WID_BW-1:0]  s0_warpid_w;
logic [WBW-1:0]     s0_bofs_beg_r [VDIM];
logic [WBW-1:0]     s0_bofs_end_r [VDIM];
logic [WBW-1:0]     s0_bofs_r     [VDIM];
logic [WBW-1:0]     s0_bofs_nxt   [VDIM];
logic [WBW-1:0]     s0_blofs_r    [VDIM];
logic [WBW-1:0]     s0_blofs_nxt  [VDIM];
logic [CCV_BW-1:0]  s0_bsub_up_order [VDIM];
logic [CCV_BW-1:0]  s0_bsub_lo_order [VDIM];
logic [NCFG_BW-1:0] o_id1;
logic [NCFG_BW-1:0] o_id_w;
logic [WID_BW-1:0]  o_warpid_w;

//======================================
// Combinational
//======================================
assign s0_islast_bofs_id = s0_islast_bofs && s0_islast_id;
assign o_islast = s0_islast_bofs_id && s0_islast_aofs_r;
assign o_retire = s0_islast_bofs && o_id < s0_id_ret_r;
always_comb begin
	o_id1 = o_id + 'b1;
	s0_islast_id = o_id1 == s0_id_end_r;
end

always_comb begin
	casez({src_ack, dst_ack, s0_islast_id})
		3'b1??: begin
			o_id_w = i_id_beg;
			o_warpid_w = '0;
		end
		3'b010: begin
			o_id_w = o_id1;
			o_warpid_w = o_warpid;
		end
		3'b011: begin
			o_id_w = s0_id_beg_r;
			o_warpid_w = o_warpid + 'b1;
		end
		3'b00?: begin
			o_id_w = o_id;
			o_warpid_w = o_warpid;
		end
	endcase
end

function [WBW-1:0] Vshuf;
	// Ex: ABCDE
	// u=2, l=3 --> AB00CDE
	// u=1, l=0 --> ABCDE0
	input [WBW-1:0]    bofs;
	input [CCV_BW-1:0] up_order;
	input [CCV_BW-1:0] lo_order;
	logic [WBW-1:0] lm;
	lm = '1 << lo_order;
	Vshuf = (bofs&~lm) | ((bofs&lm)<<up_order);
endfunction

always_comb for (int i = 0; i < VDIM; i++) begin
	o_bofs[i] = Vshuf(s0_bofs_r[i], s0_bsub_up_order[i], s0_bsub_lo_order[i]);
	o_blofs[i] = Vshuf(s0_blofs_r[i], s0_bsub_up_order[i], s0_bsub_lo_order[i]);
end

//======================================
// Submodule
//======================================
// TODO: should we remove this pipeline?
Forward u_s0(
	`clk_connect,
	`rdyack_connect(src, src),
	`rdyack_connect(dst, s0_dst)
);
OneCycleInit u_s0d(
	`clk_connect,
	`rdyack_connect(src, s0_dst),
	`rdyack_connect(dst, s0_dst_delay),
	`dval_connect(init, s0_init)
);
AcceptIf u_ac(
	.cond(s0_islast_bofs_id),
	`rdyack_connect(src, s0_dst_delay),
	`rdyack_connect(dst, dst)
);
NDAdder#(.BW(WBW), .DIM(VDIM), .FROM_ZERO(0), .UNIT_STRIDE(1)) u_adder(
	.i_restart(s0_init_dval),
	.i_cur(s0_bofs_r),
	.i_cur_noofs(s0_blofs_r),
	.i_beg(s0_bofs_beg_r),
	.i_stride(),
	.i_end(s0_bofs_end_r),
	.i_global_end(),
	.o_nxt(s0_bofs_nxt),
	.o_nxt_noofs(s0_blofs_nxt),
	.o_sel_beg(),
	.o_sel_end(),
	.o_sel_ret(),
	.o_carry(s0_islast_bofs)
);

//======================================
// Sequential
//======================================
`ff_rst
	s0_id_beg_r <= '0;
	s0_id_end_r <= '0;
	s0_id_ret_r <= '0;
	s0_islast_aofs_r <= 1'b0;
	for (int i = 0; i < VDIM; i++) begin
		o_aofs[i] <= '0;
		o_alofs[i] <= '0;
		s0_bofs_beg_r[i] <= '0;
		s0_bofs_end_r[i] <= '0;
		s0_bsub_up_order[i] <= '0;
		s0_bsub_lo_order[i] <= '0;
	end
`ff_cg(src_ack)
	s0_id_beg_r <= i_id_beg;
	s0_id_end_r <= i_id_end;
	s0_id_ret_r <= i_id_ret;
	s0_islast_aofs_r <= i_islast;
	o_aofs <= i_aofs;
	o_alofs <= i_alofs;
	for (int i = 0; i < VDIM; i++) begin
		s0_bofs_beg_r[i] <= i_bofs[i] >> i_bsub_up_order[i];
		s0_bofs_end_r[i] <= (i_bofs[i]+i_bgrid_step[i]) >> i_bsub_up_order[i];
	end
	s0_bsub_up_order <= i_bsub_up_order;
	s0_bsub_lo_order <= i_bsub_lo_order;
`ff_end

`ff_rst
	o_warpid <= '0;
	o_id <= '0;
`ff_cg(src_ack || dst_ack)
	o_warpid <= o_warpid_w;
	o_id <= o_id_w;
`ff_end

`ff_rst
	for (int i = 0; i < VDIM; i++) begin
		s0_bofs_r[i] <= '0;
		s0_blofs_r[i] <= '0;
	end
`ff_cg(s0_init_dval || dst_ack && s0_islast_id)
	s0_bofs_r <= s0_bofs_nxt;
	s0_blofs_r <= s0_blofs_nxt;
`ff_end

endmodule
