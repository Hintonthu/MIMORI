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

`include "common/TauCfg.sv"
`include "common/define.sv"
`include "common/Controllers.sv"
`include "common/OffsetStage.sv"
`include "common/ND.sv"

module AccumBlockLooperOutputController(
	`clk_port,
	`rdyack_port(src),
	`rdyack_port(dst),
	reg_cg,
	begs,
	ends,
	sel_beg,
	sel_end,
	selected_beg,
	selected_end,
	skipped
);

//======================================
// Parameter
//======================================
import TauCfg::*;
parameter BW = 1;
localparam VDIM = TauCfg::VDIM;

//======================================
// I/O
//======================================
`clk_input;
`rdyack_input(src);
`rdyack_output(dst);
output logic reg_cg;
input [BW-1:0] begs [VDIM+1];
input [BW-1:0] ends [VDIM+1];
input [VDIM:0] sel_end;
input [VDIM:0] sel_beg;
output logic [BW-1:0] selected_beg;
output logic [BW-1:0] selected_end;
output logic skipped;

//======================================
// Internal
//======================================
`rdyack_logic(src0);
logic eq;

//======================================
// Combinational
//======================================
assign eq = selected_beg == selected_end;
assign reg_cg = src0_ack;

//======================================
// Submodule
//======================================
DeleteIf#(1) u_del(
	.cond(eq),
	`rdyack_connect(src, src),
	`rdyack_connect(dst, src0),
	.deleted(skipped)
);
Forward#(.SLOW(1)) u_fwd(
	`clk_connect,
	`rdyack_connect(src, src0),
	`rdyack_connect(dst, dst)
);
IdSelect#(.BW(BW), .DIM(VDIM), .RETIRE(0)) u_s0_sel_beg(
	.i_sel(sel_beg),
	.i_begs(begs),
	.i_ends(),
	.o_dat(selected_beg)
);
IdSelect#(.BW(BW), .DIM(VDIM), .RETIRE(0)) u_s0_sel_end(
	.i_sel(sel_end),
	.i_begs(ends),
	.i_ends(),
	.o_dat(selected_end)
);
endmodule

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
	// ReadPipeline 0
`ifdef VERI_TOP_AccumBlockLooper
	`rdyack2_port(i0_abofs),
`else
	`rdyack_port(i0_abofs),
`endif
	o_i0_bofs,
	o_i0_aofs_beg,
	o_i0_aofs_end,
	o_i0_beg,
	o_i0_end,
`ifdef SD
	o_i0_syst_type, // See SystolicSwitch.sv
`endif
	// ReadPipeline 1
`ifdef VERI_TOP_AccumBlockLooper
	`rdyack2_port(i1_abofs),
`else
	`rdyack_port(i1_abofs),
`endif
	o_i1_bofs,
	o_i1_aofs_beg,
	o_i1_aofs_end,
	o_i1_beg,
	o_i1_end,
`ifdef SD
	o_i1_syst_type,
`endif
	// DMA
`ifdef VERI_TOP_AccumBlockLooper
	`rdyack2_port(dma_abofs),
`else
	`rdyack_port(dma_abofs),
`endif
	o_dma_which, // 0 or 1
	o_dma_bofs,
	o_dma_aofs,
	o_dma_beg,
	o_dma_end,
`ifdef SD
	o_dma_syst_type,
`endif
	// WritePipeline
`ifdef VERI_TOP_AccumBlockLooper
	`rdyack2_port(o_abofs),
`else
	`rdyack_port(o_abofs),
`endif
	o_o_bofs,
	o_o_aofs_beg,
	o_o_aofs_end,
	o_o_beg,
	o_o_end,
	// AluPipeline
`ifdef VERI_TOP_AccumBlockLooper
	`rdyack2_port(alu_abofs),
`else
	`rdyack_port(alu_abofs),
`endif
	o_alu_bofs,
	o_alu_aofs_beg,
	o_alu_aofs_end,
	`dval_port(blkdone)
);

//======================================
// Parameter
//======================================
import TauCfg::*;
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
`ifdef VERI_TOP_AccumBlockLooper
`rdyack2_output(i0_abofs);
`else
`rdyack_output(i0_abofs);
`endif
output logic [WBW-1:0]     o_i0_bofs     [VDIM];
output logic [WBW-1:0]     o_i0_aofs_beg [VDIM];
output logic [WBW-1:0]     o_i0_aofs_end [VDIM];
output logic [ICFG_BW-1:0] o_i0_beg;
output logic [ICFG_BW-1:0] o_i0_end;
`ifdef SD
output logic [STO_BW-1:0]  o_i0_syst_type;
`endif
`ifdef VERI_TOP_AccumBlockLooper
`rdyack2_output(i1_abofs);
`else
`rdyack_output(i1_abofs);
`endif
output logic [WBW-1:0]     o_i1_bofs     [VDIM];
output logic [WBW-1:0]     o_i1_aofs_beg [VDIM];
output logic [WBW-1:0]     o_i1_aofs_end [VDIM];
output logic [ICFG_BW-1:0] o_i1_beg;
output logic [ICFG_BW-1:0] o_i1_end;
`ifdef SD
output logic [STO_BW-1:0]  o_i1_syst_type;
`endif
`ifdef VERI_TOP_AccumBlockLooper
`rdyack2_output(dma_abofs);
`else
`rdyack_output(dma_abofs);
`endif
output logic               o_dma_which;
output logic [WBW-1:0]     o_dma_bofs [VDIM];
output logic [WBW-1:0]     o_dma_aofs [VDIM];
output logic [ICFG_BW-1:0] o_dma_beg;
output logic [ICFG_BW-1:0] o_dma_end;
`ifdef SD
output logic [STO_BW-1:0]  o_dma_syst_type;
`endif
`ifdef VERI_TOP_AccumBlockLooper
`rdyack2_output(o_abofs);
`else
`rdyack_output(o_abofs);
`endif
output logic [WBW-1:0]     o_o_bofs     [VDIM];
output logic [WBW-1:0]     o_o_aofs_beg [VDIM];
output logic [WBW-1:0]     o_o_aofs_end [VDIM];
output logic [OCFG_BW-1:0] o_o_beg;
output logic [OCFG_BW-1:0] o_o_end;
`ifdef VERI_TOP_AccumBlockLooper
`rdyack2_output(alu_abofs);
`else
`rdyack_output(alu_abofs);
`endif
output logic [WBW-1:0] o_alu_bofs     [VDIM];
output logic [WBW-1:0] o_alu_aofs_beg [VDIM];
output logic [WBW-1:0] o_alu_aofs_end [VDIM];
`dval_output(blkdone);

//======================================
// Internal
//======================================
`rdyack_logic(s0_dst);
`dval_logic(ofs_init); // Used only in systolic mode
logic [WBW-1:0] s0_aofs_beg [VDIM];
logic [WBW-1:0] s0_aofs_end_tmp [VDIM];
logic [WBW-1:0] s0_aofs_end     [VDIM];
logic s0_skip_alu;
logic s0_last_block;
logic [VDIM:0] s0_sel_end;
logic [VDIM:0] s0_sel_beg;
logic [ICFG_BW-1:0] s0_i0_beg;
logic [ICFG_BW-1:0] s0_i0_end;
logic [ICFG_BW-1:0] s0_i1_beg;
logic [ICFG_BW-1:0] s0_i1_end;
logic [OCFG_BW-1:0] s0_o_beg;
logic [OCFG_BW-1:0] s0_o_end;
logic s1_alu_last_block_r;
`ifdef SD
logic i_i0_rmost, i_i0_lmost, i_i1_lmost, i_i1_rmost;
logic [CN_TAU_X:0] i_i0_systolic_gsize2;
logic [CN_TAU_X:0] i0_systolic_cnt_r;
logic [CN_TAU_X:0] i0_systolic_cnt_w;
logic [CN_TAU_Y:0] i_i1_systolic_gsize2;
logic [CN_TAU_Y:0] i1_systolic_cnt_r;
logic [CN_TAU_Y:0] i1_systolic_cnt_w;
logic [STO_BW-1:0] o_i0_syst_type_w;
logic [STO_BW-1:0] o_i1_syst_type_w;
`endif

//======================================
// Combinational
//======================================
assign blkdone_dval = s0_skip_alu || alu_abofs_ack && s1_alu_last_block_r;
`ifdef SD
assign o_dma_which_w = !o_dma_which;
always_comb begin
	i_i0_systolic_gsize2 = (i_i0_systolic_gsize << 1) - 'b1;
	i_i1_systolic_gsize2 = (i_i1_systolic_gsize << 1) - 'b1;
	i_i0_lmost = i_i0_systolic_idx == '0;
	i_i0_rmost = (i_i0_systolic_idx+'b1) == i_i0_systolic_gsize;
	i_i1_lmost = i_i1_systolic_idx == '0;
	i_i1_rmost = (i_i1_systolic_idx+'b1) == i_i1_systolic_gsize;
end

// dma0_systolic_cnt_w
// dma0_systolic_cnt_r
// dma1_systolic_cnt_w
// dma1_systolic_cnt_r
// dma0_syst_type_w
// dma1_syst_type_w

always_comb begin
	i0_systolic_cnt_w = ofs_init_dval || (i0_systolic_cnt_r == i_i0_systolic_gsize2) ? 'b0 : (i0_systolic_cnt_r + 'b1);
	i1_systolic_cnt_w = ofs_init_dval || (i1_systolic_cnt_r == i_i1_systolic_gsize2) ? 'b0 : (i1_systolic_cnt_r + 'b1);
	dma0_systolic_cnt_w = ofs_init_dval || (dma0_systolic_cnt_r == i_i0_systolic_gsize2) ? 'b0 : (dma0_systolic_cnt_r + 'b1);
	dma1_systolic_cnt_w = ofs_init_dval || (dma1_systolic_cnt_r == i_i1_systolic_gsize2) ? 'b0 : (dma1_systolic_cnt_r + 'b1);
`define DetectSystolicType(target,cur,idx,bound,lmost,rmost)\
	unique if (cur == idx || cur == bound - idx) begin\
		target = `FROM_SELF | (rmost ? `TO_EMPTY : `TO_RIGHT) | (lmost ? `TO_EMPTY : `TO_LEFT);\
	end else if (cur < idx || cur > bound - idx) begin\
		target = `FROM_LEFT | (rmost ? `TO_EMPTY : `TO_RIGHT);\
	end else begin\
		target = `FROM_RIGHT | (lmost ? `TO_EMPTY : `TO_LEFT);\
	end
	// bit mismatch lint error here
	`DetectSystolicType(o_i0_syst_type_w, i0_systolic_cnt_r, i_i0_systolic_idx, i_i0_systolic_gsize2, i_i0_lmost, i_i0_rmost);
	`DetectSystolicType(o_i1_syst_type_w, i1_systolic_cnt_r, i_i1_systolic_idx, i_i1_systolic_gsize2, i_i1_lmost, i_i1_rmost);
	`DetectSystolicType(dma0_syst_type_w, dma0_systolic_cnt_r, i_i0_systolic_idx, i_i0_systolic_gsize2, i_i0_lmost, i_i0_rmost);
	`DetectSystolicType(dma1_syst_type_w, dma1_systolic_cnt_r, i_i1_systolic_idx, i_i1_systolic_gsize2, i_i1_lmost, i_i1_rmost);
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
	.dst_rdys({i0_src_rdy, i1_src_rdy, dma_src_rdy, o_src_rdy, alu_src_rdy}),
	.dst_acks({i0_src_ack, i1_src_ack, dma_src_ack, o_src_ack, alu_src_ack})
);
AccumBlockLooperOutputController#(ICFG_BW) u_oc_i0(
	`clk_connect,
	`rdyack_connect(src, i0_src),
	`rdyack_connect(dst, i0_abofs),
	.reg_cg(i0_cg),
	.begs(i_i0_id_begs),
	.ends(i_i0_id_ends),
	.sel_beg(s0_sel_beg),
	.sel_end(s0_sel_end),
	.selected_beg(s0_i0_beg),
	.selected_end(s0_i0_end),
	.skipped()
);
// Select them
// i_dma_id_begs
// i_dma_id_ends
// s0_dma_beg
// s0_dma_end
AccumBlockLooperOutputController#(ICFG_BW) u_oc_i1(
	`clk_connect,
	`rdyack_connect(src, i1_src),
	`rdyack_connect(dst, dma_abofs_0),
	.reg_cg(i1_cg),
	.begs(i_i1_id_begs),
	.ends(i_i1_id_ends),
	.sel_beg(s0_sel_beg),
	.sel_end(s0_sel_end),
	.selected_beg(s0_i1_beg),
	.selected_end(s0_i1_end),
	.skipped()
);
RepeatIf#(0) u_repeat_dma(
	.cond(o_dma_which),
	`rdyack_port(src, dma_abofs0),
	`rdyack_port(dst, dma_abofs),
	.repeated()
);
AccumBlockLooperOutputController#(ICFG_BW) u_oc_dma(
	`clk_connect,
	`rdyack_connect(src, dma_src),
	`rdyack_connect(dst, dma_abofs),
	.reg_cg(dma_cg),
	.begs(i_dma_id_begs),
	.ends(i_dma_id_ends),
	.sel_beg(s0_sel_beg),
	.sel_end(s0_sel_end),
	.selected_beg(s0_dma_beg),
	.selected_end(s0_dma_end),
	.skipped()
);
AccumBlockLooperOutputController#(OCFG_BW) u_oc_o(
	`clk_connect,
	`rdyack_connect(src, o_src),
	`rdyack_connect(dst, o_abofs),
	.reg_cg(o_cg),
	.begs(i_o_id_begs),
	.ends(i_o_id_ends),
	.sel_beg(s0_sel_beg),
	.sel_end(s0_sel_end),
	.selected_beg(s0_o_beg),
	.selected_end(s0_o_end),
	.skipped()
);
AccumBlockLooperOutputController#(INST_BW) u_oc_alu(
	`clk_connect,
	`rdyack_connect(src, alu_src),
	`rdyack_connect(dst, alu_abofs),
	.reg_cg(alu_cg),
	.begs(i_inst_id_begs),
	.ends(i_inst_id_ends),
	.sel_beg(s0_sel_beg),
	.sel_end(s0_sel_end),
	.selected_beg(),
	.selected_end(),
	.skipped(s0_skip_alu)
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
	o_i0_syst_type <= '0;
`endif
`ff_cg(i0_cg)
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
	o_i1_syst_type <= '0;
`endif
`ff_cg(i1_cg)
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
		o_dma_bofs[i] <= '0;
		o_dma_aofs[i] <= '0;
	end
	o_dma_beg <= '0;
	o_dma_end <= '0;
`ff_cg(dma_cg)
	o_dma_bofs <= i_bofs;
	o_dma_aofs <= s0_aofs_beg;
	o_dma_beg <= s0_i1_beg;
	o_dma_end <= s0_i1_end;
`ff_end

`ifdef SD
`ff_rst
	o_dma_which <= 1'b0;
`ff_cg(dma_abofs_ack)
	o_dma_which <= o_dma_which_w;
`ff_end

`ff_rst
	o_dma_syst_type <= '0;
`ff_cg(dma_cg || dma_repeated)
	o_dma_syst_type <= o_dma_syst_type_w[o_dma_which_w];
`ff_end
`endif

`ff_rst
	for (int i = 0; i < VDIM; i++) begin
		o_o_bofs[i] <= '0;
		o_o_aofs_beg[i] <= '0;
		o_o_aofs_end[i] <= '0;
	end
	o_o_beg <= '0;
	o_o_end <= '0;
`ff_cg(o_cg)
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
`ff_cg(alu_cg)
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
