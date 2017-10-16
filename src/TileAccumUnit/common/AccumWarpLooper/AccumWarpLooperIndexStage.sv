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
import Default::*;

module AccumWarpLooperIndexStage(
	`clk_port,
	`rdyack_port(src),
	i_bofs,
	i_aofs,
	i_a_reset_flag,
	i_a_add_flag,
	i_islast,
	i_id_beg,
	i_id_end,
	i_id_ret,
	i_blocal_last,
	i_bsub_up_order,
	i_bsub_lo_order,
	`rdyack_port(dst),
	o_a_reset_flag,
	o_a_add_flag,
	o_bu_reset_flag,
	o_bu_add_flag,
	o_bl_reset_flag,
	o_bl_add_flag,
	o_id,
	o_warpid,
	o_bofs,
	o_aofs,
	o_retire,
	o_islast
);

//======================================
// Parameter
//======================================
parameter N_CFG = Default::N_CFG;
localparam WBW = TauCfg::WORK_BW;
localparam DIM = TauCfg::DIM;
localparam VSIZE = TauCfg::VECTOR_SIZE;
localparam MAX_WARP = TauCfg::MAX_WARP;
// derived
localparam NCFG_BW = $clog2(N_CFG+1);
localparam CV_BW = $clog2(VSIZE);
localparam CCV_BW = $clog2(CV_BW+1);
localparam WID_BW = $clog2(MAX_WARP);
// Workaround
localparam [WBW-CV_BW-1:0] LOWER_PAD_ZERO = 0;
logic [WBW-1:0]   ND_WZERO  [DIM] = '{default:0};
logic [CV_BW-1:0] ND_CVZERO [DIM] = '{default:0};

//======================================
// I/O
//======================================
`clk_input;
`rdyack_input(src);
input [WBW-1:0]     i_bofs [DIM];
input [WBW-1:0]     i_aofs [DIM];
input [DIM-1:0]     i_a_reset_flag;
input [DIM-1:0]     i_a_add_flag;
input               i_islast;
input [NCFG_BW-1:0] i_id_beg;
input [NCFG_BW-1:0] i_id_end;
input [NCFG_BW-1:0] i_id_ret;
input [WBW-1:0]     i_blocal_last    [DIM];
input [CCV_BW  :0]  i_bsub_up_order  [DIM];
input [CCV_BW-1:0]  i_bsub_lo_order  [DIM];
`rdyack_output(dst);
output logic [DIM-1:0]     o_a_reset_flag;
output logic [DIM-1:0]     o_a_add_flag;
output logic [DIM-1:0]     o_bu_reset_flag;
output logic [DIM-1:0]     o_bu_add_flag;
output logic [DIM-1:0]     o_bl_reset_flag;
output logic [DIM-1:0]     o_bl_add_flag;
output logic [NCFG_BW-1:0] o_id;
output logic [WID_BW-1:0]  o_warpid;
output logic [WBW-1:0]     o_bofs [DIM];
output logic [WBW-1:0]     o_aofs [DIM];
output logic               o_retire;
output logic               o_islast;

//======================================
// Internal
//======================================
`rdyack_logic(dst_raw);
logic [DIM-1:0]   a_reset_flag_w;
logic [DIM-1:0]   a_add_flag_w;
logic [WBW-1:0]   upperofs_nxt  [DIM];
logic [WBW-1:0]   upperofs_r    [DIM];
logic [WBW-1:0]   upperofs_w    [DIM];
logic [DIM-1:0]   upper_reset_flag_nxt;
logic [DIM-1:0]   upper_reset_flag_w;
logic [DIM-1:0]   upper_add_flag_nxt;
logic [DIM-1:0]   upper_add_flag_w;
logic             is_last_upperofs;
logic [CV_BW-1:0] lowerofs_nxt  [DIM];
logic [CV_BW-1:0] lowerofs_r    [DIM];
logic [CV_BW-1:0] lowerofs_w    [DIM];
logic [CV_BW  :0] lower_end_inv [DIM];
logic [CV_BW-1:0] lower_end     [DIM];
logic [DIM-1:0]   lower_reset_flag_nxt;
logic [DIM-1:0]   lower_reset_flag_w;
logic [DIM-1:0]   lower_add_flag_nxt;
logic [DIM-1:0]   lower_add_flag_w;
logic             is_last_lowerofs;
logic [NCFG_BW-1:0] id_beg_r;
logic [NCFG_BW-1:0] id_end_r;
logic [NCFG_BW-1:0] id_ret_r;
logic [NCFG_BW-1:0] id1;
logic [NCFG_BW-1:0] id_w;
logic [WID_BW-1:0]  warpid_w;
logic               is_lastid;
logic               islast_prev_r;
logic [WBW-1:0]     bofs_w [DIM];

//======================================
// Combinational
//======================================
assign dst_rdy = dst_raw_rdy;
assign dst_raw_ack = dst_ack && is_last_upperofs && is_lastid;
assign o_islast = is_last_upperofs && is_lastid && islast_prev_r;
assign o_retire = is_last_upperofs && o_id < id_ret_r;

always_comb for (int i = 0; i < DIM; i++) begin
	lower_end_inv[i] = '1 << i_bsub_lo_order[i];
	lower_end[i] = ~lower_end_inv[i][CV_BW-1:0];
	bofs_w[i] = i_bofs[i] + ({LOWER_PAD_ZERO, lowerofs_w[i]} | upperofs_w[i]);
end

always_comb begin
	id1 = o_id + 'b1;
	is_lastid = id1 == id_end_r;
end

always_comb begin
	casez({src_ack, dst_ack, is_lastid})
		3'b1??: begin
			id_w = i_id_beg;
		end
		3'b010: begin
			id_w = id1;
		end
		3'b011: begin
			id_w = id_beg_r;
		end
		3'b00?: begin
			id_w = o_id;
		end
	endcase
end

always_comb begin
	casez({src_ack, dst_ack && is_lastid})
		2'b1?: begin
			upper_reset_flag_w = '1;
			upper_add_flag_w = 'b0;
			lower_reset_flag_w = '1;
			lower_add_flag_w = 'b0;
			for (int i = 0; i < DIM; i++) begin
				upperofs_w[i] = '0;
				lowerofs_w[i] = '0;
			end
			warpid_w = '0;
		end
		2'b01: begin
			upper_reset_flag_w = upper_reset_flag_nxt;
			upper_add_flag_w = upper_add_flag_nxt;
			lower_reset_flag_w = lower_reset_flag_nxt;
			lower_add_flag_w = lower_add_flag_nxt;
			lowerofs_w = lowerofs_nxt;
			upperofs_w = upperofs_nxt;
			warpid_w = o_warpid + 'b1;
		end
		2'b00: begin
			upper_reset_flag_w = o_bu_reset_flag;
			upper_add_flag_w = o_bu_add_flag;
			lower_reset_flag_w = o_bl_reset_flag;
			lower_add_flag_w = o_bl_add_flag;
			lowerofs_w = lowerofs_r;
			upperofs_w = upperofs_r;
			warpid_w = o_warpid;
		end
	endcase
end

always_comb begin
	casez({src_ack, dst_ack})
		2'b1?: begin
			a_reset_flag_w = i_a_reset_flag;
			a_add_flag_w = i_a_add_flag;
		end
		2'b01: begin
			a_reset_flag_w = '0;
			a_add_flag_w = '0;
		end
		2'b00: begin
			a_reset_flag_w = o_a_reset_flag;
			a_add_flag_w = o_a_add_flag;
		end
	endcase
end

//======================================
// Submodule
//======================================
Forward u_fwd(
	`clk_connect,
	`rdyack_connect(src, src),
	`rdyack_connect(dst, dst_raw)
);
NDCounterAddFlag#(.BW(WBW), .DIM(DIM)) u_upperofs_flag(
	.i_cur(upperofs_r),
	.i_end(i_blocal_last),
	.i_carry(is_last_lowerofs),
	.o_reset_counter(upper_reset_flag_nxt),
	.o_add_counter(upper_add_flag_nxt),
	.o_done(is_last_upperofs)
);
NDCounterAddFlag#(.BW(CV_BW), .DIM(DIM)) u_lowerofs_flag(
	.i_cur(lowerofs_r),
	.i_end(lower_end),
	.i_carry(1'b1),
	.o_reset_counter(lower_reset_flag_nxt),
	.o_add_counter(lower_add_flag_nxt),
	.o_done(is_last_lowerofs)
);
NDCounterAddSelect#(
	.BW(WBW),
	.DIM(DIM),
	.FRAC_BW(0),
	.SHAMT_BW(CCV_BW+1),
	.UNIT_STEP(1)
) u_upperofs_sel(
	.i_augend(upperofs_r),
	.o_sum(upperofs_nxt),
	.i_start(ND_WZERO),
	.i_step(),
	.i_frac(),
	.i_shamt(i_bsub_up_order),
	.i_reset_counter(upper_reset_flag_w),
	.i_add_counter(upper_add_flag_w)
);
NDCounterAddSelect#(
	.BW(CV_BW),
	.DIM(DIM),
	.FRAC_BW(0),
	.SHAMT_BW(0),
	.UNIT_STEP(1)
) u_lowerofs_sel(
	.i_augend(lowerofs_r),
	.o_sum(lowerofs_nxt),
	.i_start(ND_CVZERO),
	.i_step(),
	.i_frac(),
	.i_shamt(),
	.i_reset_counter(lower_reset_flag_w),
	.i_add_counter(lower_add_flag_w)
);

//======================================
// Sequential
//======================================
`ff_rst
	id_beg_r <= '0;
	id_end_r <= '0;
	id_ret_r <= '0;
	islast_prev_r <= 1'b0;
`ff_cg(src_ack)
	id_beg_r <= i_id_beg;
	id_end_r <= i_id_end;
	id_ret_r <= i_id_ret;
	islast_prev_r <= i_islast;
`ff_end

`ff_rst
	o_a_reset_flag <= '0;
	o_a_add_flag <= '0;
	o_bu_reset_flag <= '0;
	o_bu_add_flag <= '0;
	o_bl_reset_flag <= '0;
	o_bl_add_flag <= '0;
	o_id <= '0;
	for (int i = 0; i < DIM; i++) begin
		o_bofs[i] <= '0;
		upperofs_r[i] <= '0;
		lowerofs_r[i] <= '0;
	end
	o_warpid <= '0;
`ff_cg(src_ack || dst_ack)
	o_a_reset_flag <= a_reset_flag_w;
	o_a_add_flag <= a_add_flag_w;
	o_bu_reset_flag <= upper_reset_flag_w;
	o_bu_add_flag <= upper_add_flag_w;
	o_bl_reset_flag <= lower_reset_flag_w;
	o_bl_add_flag <= lower_add_flag_w;
	o_id <= id_w;
	o_bofs <= bofs_w;
	upperofs_r <= upperofs_w;
	lowerofs_r <= lowerofs_w;
	o_warpid <= warpid_w;
`ff_end

`ff_rst
	for (int i = 0; i < DIM; i++) begin
		o_aofs[i] <= '0;
	end
`ff_cg(src_ack)
	o_aofs <= i_aofs;
`ff_end

endmodule
