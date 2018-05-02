// Copyright (C) 2017-2018, Yu Sheng Lin, johnjohnlys@media.ee.ntu.edu.tw

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
`timescale 1ns/1ps
`include "common/define.sv"
`ifdef GATE_LEVEL
`include "Top_mc_syn_include.sv"
`else
`include "Top_mc_include.sv"
`endif
`timescale 1ns/1ps
import TauCfg::*;

`define CLK 10
`define HCLK 5
`define INPUT_DELAY 2

module Top_mc_test;

localparam GBW = GLOBAL_ADDR_BW;
localparam DBW = DATA_BW;
localparam CSIZE = CACHE_SIZE;

`ifdef GATE_LEVEL
localparam GATE_LEVEL = 1;
initial begin
	// u_top.i_i0_stencil = 0;
	// u_top.i_i1_stencil = 0;
	// u_top.i_reg_per_warp = 0;
	for (int i = 0; i < VDIM; i++) begin
		u_top.i_bgrid_step[i] = 0;
		u_top.i_bgrid_end[i] = 0;
		u_top.i_bboundary[i] = 0;
		u_top.i_bsub_up_order[i] = 0;
		u_top.i_bsub_lo_order[i] = 0;
		u_top.i_agrid_step[i] = 0;
		u_top.i_agrid_end[i] = 0;
		u_top.i_aboundary[i] = 0;
	end
	for (int i = 0; i < VDIM+1; i++) begin
		u_top.i_i0_id_begs[i] = 0;
		u_top.i_i0_id_ends[i] = 0;
		u_top.i_i1_id_begs[i] = 0;
		u_top.i_i1_id_ends[i] = 0;
		u_top.i_o_id_begs[i] = 0;
		u_top.i_o_id_ends[i] = 0;
		u_top.i_inst_id_begs[i] = 0;
		u_top.i_inst_id_ends[i] = 0;
	end
	for (int i = 0; i < N_ICFG; i++) begin
		u_top.i_i0_local_xor_masks[i] = 0;
		u_top.i_i0_local_bit_swaps[i] = 0;
		u_top.i_i0_global_linears[i] = 0;
		u_top.i_i0_stencil_begs[i] = 0;
		u_top.i_i0_stencil_ends[i] = 0;
		u_top.i_i1_local_xor_masks[i] = 0;
		u_top.i_i1_local_bit_swaps[i] = 0;
		u_top.i_i1_global_linears[i] = 0;
		u_top.i_i1_stencil_begs[i] = 0;
		u_top.i_i1_stencil_ends[i] = 0;
		for (int j = 0; j < DIM; j++) begin
			u_top.i_i0_local_boundaries[i][j] = 0;
			u_top.i_i0_local_pads[i][j] = 0;
			u_top.i_i0_global_starts[i][j] = 0;
			u_top.i_i0_global_cboundaries[i][j] = 0;
			u_top.i_i0_global_boundaries[i][j] = 0;
			u_top.i_i1_local_boundaries[i][j] = 0;
			u_top.i_i1_local_pads[i][j] = 0;
			u_top.i_i1_global_starts[i][j] = 0;
			u_top.i_i1_global_cboundaries[i][j] = 0;
			u_top.i_i1_global_boundaries[i][j] = 0;
		end
		for (int j = 0; j < VDIM; j++) begin
			u_top.i_i0_global_bshufs[i][j] = 0;
			u_top.i_i0_global_ashufs[i][j] = 0;
			u_top.i_i0_bstrides_frac[i][j] = 0;
			u_top.i_i0_bstrides_shamt[i][j] = 0;
			u_top.i_i0_astrides_frac[i][j] = 0;
			u_top.i_i0_astrides_shamt[i][j] = 0;
			u_top.i_i1_global_bshufs[i][j] = 0;
			u_top.i_i1_global_ashufs[i][j] = 0;
			u_top.i_i1_bstrides_frac[i][j] = 0;
			u_top.i_i1_bstrides_shamt[i][j] = 0;
			u_top.i_i1_astrides_frac[i][j] = 0;
			u_top.i_i1_astrides_shamt[i][j] = 0;
		end
		for (int j = 0; j < CV_BW; j++) begin
			u_top.i_i0_local_xor_schemes[i][j] = 0;
			u_top.i_i0_local_bsubsteps[i][j] = 0;
			u_top.i_i1_local_xor_schemes[i][j] = 0;
			u_top.i_i1_local_bsubsteps[i][j] = 0;
		end
	end
	for (int i = 0; i < N_OCFG; i++) begin
		u_top.i_o_global_linears[i] = 0;
		for (int j = 0; j < VDIM; j++) begin
			u_top.i_o_global_bshufs[i][j] = 0;
			u_top.i_o_bstrides_frac[i][j] = 0;
			u_top.i_o_bstrides_shamt[i][j] = 0;
			u_top.i_o_global_ashufs[i][j] = 0;
			u_top.i_o_astrides_frac[i][j] = 0;
			u_top.i_o_astrides_shamt[i][j] = 0;
		end
		for (int j = 0; j < DIM; j++) begin
			u_top.i_o_global_boundaries[i][j] = 0;
		end
		for (int j = 0; j < CV_BW; j++) begin
			u_top.i_o_global_bsubsteps[i][j] = 0;
		end
	end
	for (int i = 0; i < VSIZE; i++) begin
		for (int j = 0; j < VDIM; j++) begin
			u_top.i_bsubofs[i][j] = 0;
		end
	end
	for (int i = 0; i < VSIZE; i++) begin
		u_top.i_i0_stencil_lut[i] = 0;
		u_top.i_i1_stencil_lut[i] = 0;
	end
	for (int i = 0; i < N_INST; i++) begin
		u_top.i_insts[i] = 0;
	end
	for (int i = 0; i < CONST_LUT; i++) begin
		u_top.i_consts[i] = 0;
	end
	for (int i = 0; i < CONST_TEX_LUT; i++) begin
		u_top.i_const_texs[i] = 0;
	end
	for (int i = 0; i < N_TAU; i++) begin
		for (int j = 0; j < CACHE_SIZE; j++) begin
			u_top.i_dramrds[i][j] = 0;
		end
	end
end
`else
localparam GATE_LEVEL = 0;
`endif
logic i_clk, i_rst;
logic ra0_canack;
logic ra1_canack;
logic ra2_canack;
logic ra3_canack;
logic w0_canack;
logic w1_canack;
logic w2_canack;
logic w3_canack;
`rdyack_logic(cfg);
`rdyack_logic(w0);
`rdyack_logic(w1);
`rdyack_logic(w2);
`rdyack_logic(w3);
`rdyack_logic(ra0);
`rdyack_logic(ra1);
`rdyack_logic(ra2);
`rdyack_logic(ra3);
`rdyack_logic(rd0);
`rdyack_logic(rd1);
`rdyack_logic(rd2);
`rdyack_logic(rd3);
logic [GBW-1:0] o_dramras [N_TAU];
logic [DBW-1:0] i_dramrds [N_TAU][CSIZE];
logic [GBW-1:0] o_dramwas [N_TAU];
logic [DBW-1:0] o_dramwds [N_TAU][CSIZE];
logic [CSIZE-1:0] o_dramw_masks [N_TAU];
logic [GBW-1:0] o_dramra0;
logic [GBW-1:0] o_dramra1;
logic [GBW-1:0] o_dramra2;
logic [GBW-1:0] o_dramra3;
logic [DBW-1:0] i_dramrd0 [CSIZE];
logic [DBW-1:0] i_dramrd1 [CSIZE];
logic [DBW-1:0] i_dramrd2 [CSIZE];
logic [DBW-1:0] i_dramrd3 [CSIZE];
logic [GBW-1:0] o_dramwa0;
logic [GBW-1:0] o_dramwa1;
logic [GBW-1:0] o_dramwa2;
logic [GBW-1:0] o_dramwa3;
logic [DBW-1:0] o_dramwd0 [CSIZE];
logic [DBW-1:0] o_dramwd1 [CSIZE];
logic [DBW-1:0] o_dramwd2 [CSIZE];
logic [DBW-1:0] o_dramwd3 [CSIZE];
logic [CSIZE-1:0] o_dramw_mask0;
logic [CSIZE-1:0] o_dramw_mask1;
logic [CSIZE-1:0] o_dramw_mask2;
logic [CSIZE-1:0] o_dramw_mask3;
`Pos(rst_out, i_rst)
`ifdef GATE_LEVEL
`PosIfDelayed(ck_ev, i_clk, i_rst, `INPUT_DELAY)
`else
`PosIf(ck_ev, i_clk, i_rst)
`endif
`WithFinish

always #`HCLK i_clk = ~i_clk;
initial begin
`ifdef GATE_LEVEL
	$fsdbDumpfile("Top_mc_syn.fsdb");
	$sdf_annotate(`SDF , u_top.u_top);
	$fsdbDumpvars(0, u_top.u_top, "+mda");
`else
	$fsdbDumpfile("Top_mc.fsdb");
	$fsdbDumpvars(0, Top_mc_test, "+mda");
`endif
	i_clk = 0;
	i_rst = 1;
	rd0_rdy = 0;
	rd1_rdy = 0;
	rd2_rdy = 0;
	rd3_rdy = 0;
	#0.1 $NicotbInit();
	#(`CLK*2) i_rst = 0;
	#(`CLK*2) i_rst = 1;
	#(`CLK*100000) $display("Timeout");
	$NicotbFinal();
	$finish;
end

assign ra0_ack = ra0_canack && ra0_rdy;
assign ra1_ack = ra1_canack && ra1_rdy;
assign ra2_ack = ra2_canack && ra2_rdy;
assign ra3_ack = ra3_canack && ra3_rdy;
assign w0_ack = w0_canack && w0_rdy;
assign w1_ack = w1_canack && w1_rdy;
assign w2_ack = w2_canack && w2_rdy;
assign w3_ack = w3_canack && w3_rdy;
assign o_dramra0 = o_dramras[0];
assign o_dramra1 = o_dramras[1];
assign o_dramra2 = o_dramras[2];
assign o_dramra3 = o_dramras[3];
assign i_dramrds[0] = i_dramrd0;
assign i_dramrds[1] = i_dramrd1;
assign i_dramrds[2] = i_dramrd2;
assign i_dramrds[3] = i_dramrd3;
assign o_dramwa0 = o_dramwas[0];
assign o_dramwa1 = o_dramwas[1];
assign o_dramwa2 = o_dramwas[2];
assign o_dramwa3 = o_dramwas[3];
assign o_dramwd0 = o_dramwds[0];
assign o_dramwd1 = o_dramwds[1];
assign o_dramwd2 = o_dramwds[2];
assign o_dramwd3 = o_dramwds[3];
assign o_dramw_mask0 = o_dramw_masks[0];
assign o_dramw_mask1 = o_dramw_masks[1];
assign o_dramw_mask2 = o_dramw_masks[2];
assign o_dramw_mask3 = o_dramw_masks[3];
`ifdef GATE_LEVEL
TopGateWrap
`else
Top_mc
`endif
u_top(
	`clk_connect,
	`rdyack_connect(src, cfg),
	.dramra_rdys({ra3_rdy,ra2_rdy,ra1_rdy,ra0_rdy}),
	.dramra_acks({ra3_ack,ra2_ack,ra1_ack,ra0_ack}),
	.o_dramras(o_dramras),
	.dramrd_rdys({rd3_rdy,rd2_rdy,rd1_rdy,rd0_rdy}),
	.dramrd_acks({rd3_ack,rd2_ack,rd1_ack,rd0_ack}),
	.i_dramrds(i_dramrds),
	.dramw_rdys({w3_rdy,w2_rdy,w1_rdy,w0_rdy}),
	.dramw_acks({w3_ack,w2_ack,w1_ack,w0_ack}),
	.o_dramwas(o_dramwas),
	.o_dramwds(o_dramwds),
	.o_dramw_masks(o_dramw_masks)
);

endmodule
