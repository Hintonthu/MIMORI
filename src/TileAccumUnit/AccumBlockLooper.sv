// Copyright 2016, 2018 Yu Sheng Lin

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

`include "common/define.sv"
`include "common/ND.sv"

module AccumBlockLooper(
	`clk_port,
	`rdyack_port(src),
	i_bofs,
`ifdef SD
	i_i0_systolic_gsize,
	i_i0_systolic_idx,
	i_i1_systolic_gsize,
	i_i1_systolic_idx,
`endif
	i_agrid_step,
	i_agrid_end,
	i_aboundary,
	i_i0_id_begs,
	i_i0_id_ends,
	i_i1_id_begs,
	i_i1_id_ends,
	i_o_id_begs,
	i_o_id_ends,
	i_inst_id_begs,
	i_inst_id_ends,
	`rdyack_port(i0_abofs),
	o_i0_bofs,
	o_i0_aofs_beg,
	o_i0_aofs_end,
	o_i0_beg,
	o_i0_end,
`ifdef SD
	o_i0_syst_type, // See SystolicSwitch.sv
`endif
	`rdyack_port(i1_abofs),
	o_i1_bofs,
	o_i1_aofs_beg,
	o_i1_aofs_end,
	o_i1_beg,
	o_i1_end,
`ifdef SD
	o_i1_syst_type,
`endif
	`rdyack_port(o_abofs),
	o_o_bofs,
	o_o_aofs_beg,
	o_o_aofs_end,
	o_o_beg,
	o_o_end,
	`rdyack_port(alu_abofs),
	o_alu_bofs,
	o_alu_aofs_beg,
	o_alu_aofs_end,
	`dval_port(blkdone)
);

//======================================
// Parameter
//======================================
localparam WBW = TauCfg::WORK_BW;
localparam VDIM = TauCfg::VDIM;
localparam N_ICFG = TauCfg::N_ICFG;
localparam N_OCFG = TauCfg::N_OCFG;
localparam N_INST = TauCfg::N_INST;
// derived
localparam ICFG_BW = $clog2(N_ICFG+1);
localparam OCFG_BW = $clog2(N_OCFG+1);
localparam INST_BW = $clog2(N_INST+1);
`ifdef SD
localparam N_TAU_X = TauCfg::N_TAU_X;
localparam N_TAU_Y = TauCfg::N_TAU_Y;
localparam CN_TAU_X = $clog2(N_TAU_X);
localparam CN_TAU_Y = $clog2(N_TAU_Y);
localparam CN_TAU_X1 = $clog2(N_TAU_X+1);
localparam CN_TAU_Y1 = $clog2(N_TAU_Y+1);
`endif

//======================================
// I/O
//======================================
`clk_input;
`rdyack_input(src);
input [WBW-1:0] i_bofs        [VDIM];
input [WBW-1:0] i_agrid_step  [VDIM];
`ifdef SD
input [CN_TAU_X1-1:0] i_i0_systolic_gsize;
input [CN_TAU_Y -1:0] i_i0_systolic_idx;
input [CN_TAU_X1-1:0] i_i1_systolic_gsize;
input [CN_TAU_Y -1:0] i_i1_systolic_idx;
`endif
input [WBW-1:0] i_agrid_end   [VDIM];
input [WBW-1:0] i_aboundary   [VDIM];
input [ICFG_BW-1:0] i_i0_id_begs [VDIM+1];
input [ICFG_BW-1:0] i_i0_id_ends [VDIM+1];
input [ICFG_BW-1:0] i_i1_id_begs [VDIM+1];
input [ICFG_BW-1:0] i_i1_id_ends [VDIM+1];
input [OCFG_BW-1:0] i_o_id_begs [VDIM+1];
input [OCFG_BW-1:0] i_o_id_ends [VDIM+1];
input [INST_BW-1:0] i_inst_id_begs [VDIM+1];
input [INST_BW-1:0] i_inst_id_ends [VDIM+1];
`rdyack_output(i0_abofs);
output logic [WBW-1:0]     o_i0_bofs     [VDIM];
output logic [WBW-1:0]     o_i0_aofs_beg [VDIM];
output logic [WBW-1:0]     o_i0_aofs_end [VDIM];
output logic [ICFG_BW-1:0] o_i0_beg;
output logic [ICFG_BW-1:0] o_i0_end;
`ifdef SD
output logic [1:0]         o_i0_syst_type;
`endif
`rdyack_output(i1_abofs);
output logic [WBW-1:0]     o_i1_bofs     [VDIM];
output logic [WBW-1:0]     o_i1_aofs_beg [VDIM];
output logic [WBW-1:0]     o_i1_aofs_end [VDIM];
output logic [ICFG_BW-1:0] o_i1_beg;
output logic [ICFG_BW-1:0] o_i1_end;
`ifdef SD
output logic [1:0]         o_i1_syst_type;
`endif
`rdyack_output(o_abofs);
output logic [WBW-1:0]     o_o_bofs     [VDIM];
output logic [WBW-1:0]     o_o_aofs_beg [VDIM];
output logic [WBW-1:0]     o_o_aofs_end [VDIM];
output logic [OCFG_BW-1:0] o_o_beg;
output logic [OCFG_BW-1:0] o_o_end;
`rdyack_output(alu_abofs);
output logic [WBW-1:0] o_alu_bofs     [VDIM];
output logic [WBW-1:0] o_alu_aofs_beg [VDIM];
output logic [WBW-1:0] o_alu_aofs_end [VDIM];
`dval_output(blkdone);

//======================================
// Internal
//======================================
`rdyack_logic(s0_dst);
`rdyack_logic(i0_src);
`rdyack_logic(i1_src);
`rdyack_logic(o_src);
`rdyack_logic(alu_src);
`rdyack_logic(i0_abofs_src);
`rdyack_logic(i1_abofs_src);
`rdyack_logic(o_abofs_src);
`rdyack_logic(alu_abofs_src);
`dval_logic(ofs_init); // Used only in systolic mode
logic [WBW-1:0] s0_aofs_beg [VDIM];
logic [WBW-1:0] s0_aofs_end_tmp [VDIM];
logic [WBW-1:0] s0_aofs_end     [VDIM];
logic [VDIM:0] s0_sel_beg;
logic [VDIM:0] s0_sel_end;
logic [ICFG_BW-1:0] s0_i0_beg;
logic [ICFG_BW-1:0] s0_i0_end;
logic [ICFG_BW-1:0] s0_i1_beg;
logic [ICFG_BW-1:0] s0_i1_end;
logic [OCFG_BW-1:0] s0_o_beg;
logic [OCFG_BW-1:0] s0_o_end;
logic [INST_BW-1:0] s0_alu_beg;
logic [INST_BW-1:0] s0_alu_end;
logic s0_i0_eq;
logic s0_i1_eq;
logic s0_o_eq;
logic s0_alu_eq;
logic s0_skip_alu;
logic s0_last_block;
logic s1_alu_last_block_r;
`ifdef SD
logic [CN_TAU_X:0] i_i0_systolic_gsize2;
logic [CN_TAU_X:0] i0_systolic_cnt_r;
logic [CN_TAU_X:0] i0_systolic_cnt_w;
logic [CN_TAU_Y:0] i_i1_systolic_gsize2;
logic [CN_TAU_Y:0] i1_systolic_cnt_r;
logic [CN_TAU_Y:0] i1_systolic_cnt_w;
logic [1:0] o_i0_syst_type_w;
logic [1:0] o_i1_syst_type_w;
`endif

//======================================
// Combinational
//======================================
assign blkdone_dval = s0_skip_alu || alu_abofs_ack && s1_alu_last_block_r;
assign s0_i0_eq = s0_i0_beg == s0_i0_end;
assign s0_i1_eq = s0_i1_beg == s0_i1_end;
assign s0_o_eq = s0_o_beg == s0_o_end;
assign s0_alu_eq = s0_alu_beg == s0_alu_end;
`ifdef SD
assign i_i0_systolic_gsize2 = (i_i0_systolic_gsize << 1) - 'b1;
assign i_i1_systolic_gsize2 = (i_i1_systolic_gsize << 1) - 'b1;
always_comb begin
	i0_systolic_cnt_w = ofs_init_dval || (i0_systolic_cnt_r == i_i0_systolic_gsize2) ? 'b0 : (i0_systolic_cnt_r + 'b1);
	i1_systolic_cnt_w = ofs_init_dval || (i1_systolic_cnt_r == i_i1_systolic_gsize2) ? 'b0 : (i1_systolic_cnt_r + 'b1);
`define DetectSystolicType(target,cur,idx,bound)\
	unique if (cur == idx || cur == bound-idx) begin\
		target = 2'd1;\
	end else if (cur < idx || cur > bound-idx) begin\
		target = 2'd2;\
	end else begin\
		target = 2'd3;\
	end
	// bit mismatch lint error here
	`DetectSystolicType(o_i0_syst_type_w, i0_systolic_cnt_r, {1'b0,i_i0_systolic_idx}, i_i0_systolic_gsize2);
	`DetectSystolicType(o_i1_syst_type_w, i1_systolic_cnt_r, {1'b0,i_i1_systolic_idx}, i_i1_systolic_gsize2);
end
`endif

always_comb begin
	for (int i = 0; i < VDIM; i++) begin
		s0_aofs_end_tmp[i] = s0_aofs_beg[i] + i_agrid_step[i];
		s0_aofs_end[i] = s0_aofs_end_tmp[i] > i_aboundary[i] ? i_aboundary[i] : s0_aofs_end_tmp[i];
	end
end

//======================================
// Submodule
//======================================
OffsetStage #(.BW(WBW), .DIM(VDIM), .FROM_ZERO(1), .UNIT_STRIDE(0)) u_s0(
	`clk_connect,
	`rdyack_connect(src, src),
	.i_ofs_beg(),
	.i_ofs_end(i_agrid_end),
	.i_ofs_gend(),
	.i_stride(i_agrid_step),
	`rdyack_connect(dst, s0_dst),
	.o_ofs(s0_aofs_beg),
	.o_lofs(),
	.o_sel_beg(s0_sel_beg),
	.o_sel_end(),
	.o_sel_ret(s0_sel_end), /* .i_global_end == i_agrid_end, so sel_end == sel_ret */
	.o_islast(s0_last_block),
	`dval_connect(init, ofs_init)
);
Broadcast#(4) u_brd_0(
	`clk_connect,
	`rdyack_connect(src, s0_dst),
	.acked(),
	.dst_rdys({i0_src_rdy, i1_src_rdy, o_src_rdy, alu_src_rdy}),
	.dst_acks({i0_src_ack, i1_src_ack, o_src_ack, alu_src_ack})
);
IgnoreIf#(1) u_ign_i0(
	.cond(s0_i0_eq),
	`rdyack_connect(src, i0_src),
	`rdyack_connect(dst, i0_abofs_src),
	.skipped()
);
IgnoreIf#(1) u_ign_i1(
	.cond(s0_i1_eq),
	`rdyack_connect(src, i1_src),
	`rdyack_connect(dst, i1_abofs_src),
	.skipped()
);
IgnoreIf#(1) u_ign_o(
	.cond(s0_o_eq),
	`rdyack_connect(src, o_src),
	`rdyack_connect(dst, o_abofs_src),
	.skipped()
);
IgnoreIf#(1) u_ign_alu(
	.cond(s0_alu_eq),
	`rdyack_connect(src, alu_src),
	`rdyack_connect(dst, alu_abofs_src),
	.skipped(s0_skip_alu)
);
ForwardSlow u_fwd_i0(
	`clk_connect,
	`rdyack_connect(src, i0_abofs_src),
	`rdyack_connect(dst, i0_abofs)
);
ForwardSlow u_fwd_i1(
	`clk_connect,
	`rdyack_connect(src, i1_abofs_src),
	`rdyack_connect(dst, i1_abofs)
);
ForwardSlow u_fwd_o(
	`clk_connect,
	`rdyack_connect(src, o_abofs_src),
	`rdyack_connect(dst, o_abofs)
);
ForwardSlow u_fwd_alu(
	`clk_connect,
	`rdyack_connect(src, alu_abofs_src),
	`rdyack_connect(dst, alu_abofs)
);
IdSelect#(.BW(ICFG_BW), .DIM(VDIM), .RETIRE(0)) u_s0_sel_i0_beg(
	.i_sel(s0_sel_beg),
	.i_begs(i_i0_id_begs),
	.i_ends(),
	.o_dat(s0_i0_beg)
);
IdSelect#(.BW(ICFG_BW), .DIM(VDIM), .RETIRE(0)) u_s0_sel_i0_end(
	.i_sel(s0_sel_end),
	.i_begs(i_i0_id_ends),
	.i_ends(),
	.o_dat(s0_i0_end)
);
IdSelect#(.BW(ICFG_BW), .DIM(VDIM), .RETIRE(0)) u_s0_sel_i1_beg(
	.i_sel(s0_sel_beg),
	.i_begs(i_i1_id_begs),
	.i_ends(),
	.o_dat(s0_i1_beg)
);
IdSelect#(.BW(ICFG_BW), .DIM(VDIM), .RETIRE(0)) u_s0_sel_i1_end(
	.i_sel(s0_sel_end),
	.i_begs(i_i1_id_ends),
	.i_ends(),
	.o_dat(s0_i1_end)
);
IdSelect#(.BW(OCFG_BW), .DIM(VDIM), .RETIRE(0)) u_s0_sel_o_beg(
	.i_sel(s0_sel_beg),
	.i_begs(i_o_id_begs),
	.i_ends(),
	.o_dat(s0_o_beg)
);
IdSelect#(.BW(OCFG_BW), .DIM(VDIM), .RETIRE(0)) u_s0_sel_o_end(
	.i_sel(s0_sel_end),
	.i_begs(i_o_id_ends),
	.i_ends(),
	.o_dat(s0_o_end)
);
IdSelect#(.BW(INST_BW), .DIM(VDIM), .RETIRE(0)) u_s0_sel_alu_beg(
	.i_sel(s0_sel_beg),
	.i_begs(i_inst_id_begs),
	.i_ends(),
	.o_dat(s0_alu_beg)
);
IdSelect#(.BW(INST_BW), .DIM(VDIM), .RETIRE(0)) u_s0_sel_alu_end(
	.i_sel(s0_sel_end),
	.i_begs(i_inst_id_ends),
	.i_ends(),
	.o_dat(s0_alu_end)
);

//======================================
// Sequential
//======================================
`ff_rst
	for (int i = 0; i < VDIM; i++) begin
		o_i0_bofs[i] <= '0;
		o_i0_aofs_beg[i] <= '0;
		o_i0_aofs_end[i] <= '0;
	end
	o_i0_beg <= '0;
	o_i0_end <= '0;
`ifdef SD
	o_i0_syst_type <= 2'b0;
`endif
`ff_cg(i0_abofs_src_ack)
	o_i0_bofs <= i_bofs;
	o_i0_aofs_beg <= s0_aofs_beg;
	o_i0_aofs_end <= s0_aofs_end;
	o_i0_beg <= s0_i0_beg;
	o_i0_end <= s0_i0_end;
`ifdef SD
	o_i0_syst_type <= o_i0_syst_type_w;
`endif
`ff_end

`ff_rst
	for (int i = 0; i < VDIM; i++) begin
		o_i1_bofs[i] <= '0;
		o_i1_aofs_beg[i] <= '0;
		o_i1_aofs_end[i] <= '0;
	end
	o_i1_beg <= '0;
	o_i1_end <= '0;
`ifdef SD
	o_i1_syst_type <= 2'b0;
`endif
`ff_cg(i1_abofs_src_ack)
	o_i1_bofs <= i_bofs;
	o_i1_aofs_beg <= s0_aofs_beg;
	o_i1_aofs_end <= s0_aofs_end;
	o_i1_beg <= s0_i1_beg;
	o_i1_end <= s0_i1_end;
`ifdef SD
	o_i1_syst_type <= o_i1_syst_type_w;
`endif
`ff_end

`ff_rst
	for (int i = 0; i < VDIM; i++) begin
		o_o_bofs[i] <= '0;
		o_o_aofs_beg[i] <= '0;
		o_o_aofs_end[i] <= '0;
	end
	o_o_beg <= '0;
	o_o_end <= '0;
`ff_cg(o_abofs_src_ack)
	o_o_bofs <= i_bofs;
	o_o_aofs_beg <= s0_aofs_beg;
	o_o_aofs_end <= s0_aofs_end;
	o_o_beg <= s0_o_beg;
	o_o_end <= s0_o_end;
`ff_end

`ff_rst
	for (int i = 0; i < VDIM; i++) begin
		o_alu_bofs[i] <= '0;
		o_alu_aofs_beg[i] <= '0;
		o_alu_aofs_end[i] <= '0;
	end
	s1_alu_last_block_r <= 1'b0;
`ff_cg(alu_abofs_src_ack)
	o_alu_bofs <= i_bofs;
	o_alu_aofs_beg <= s0_aofs_beg;
	o_alu_aofs_end <= s0_aofs_end;
	s1_alu_last_block_r <= s0_last_block;
`ff_end

`ifdef SD
`ff_rst
	i0_systolic_cnt_r <= '0;
	i1_systolic_cnt_r <= '0;
`ff_cg(ofs_init_dval || s0_dst_ack)
	i0_systolic_cnt_r <= i0_systolic_cnt_w;
	i1_systolic_cnt_r <= i1_systolic_cnt_w;
`ff_end
`endif

endmodule
