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
`include "Top_syn_include.sv"
`else
`include "Top_include.sv"
`endif
`timescale 1ns/1ps
import TauCfg::*;

`define CLK 10
`define HCLK 5
`define INPUT_DELAY 2

module Top_test;
localparam GBW = GLOBAL_ADDR_BW;
localparam DBW = DATA_BW;
localparam CSIZE = CACHE_SIZE;
`ifdef SC
localparam SIM_MODE = 0;
localparam N_TAU_X = 0;
localparam N_TAU_Y = 0;
localparam N_TAU = 1;
`endif
`ifdef MC
localparam SIM_MODE = 1;
localparam N_TAU_X = 0;
localparam N_TAU_Y = 0;
localparam N_TAU = N_TAU;
`endif
`ifdef SD
localparam SIM_MODE = 2;
localparam N_TAU_X = N_TAU_X;
localparam N_TAU_Y = N_TAU_Y;
localparam N_TAU = N_TAU_X * N_TAU_Y;
`endif

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
`rdyack_logic(cfg);
logic [N_TAU-1:0] rd_rdy, rd_ack, w_rdy, w_ack, w_canack, ra_rdy, ra_ack, ra_canack;
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
	$fsdbDumpfile("Top_syn.fsdb");
	$sdf_annotate(`SDF , u_top.u_top);
	$fsdbDumpvars(0, Top_test, "+mda");
`else
`ifdef SC
	$fsdbDumpfile("Top.fsdb");
`endif
`ifdef MC
	$fsdbDumpfile("Top_mc.fsdb");
`endif
`ifdef SD
	$fsdbDumpfile("Top_sd.fsdb");
`endif
	$fsdbDumpvars(0, Top_test, "+mda");
`endif
	i_clk = 0;
	i_rst = 1;
	rd_rdy = 0;
	#0.1 $NicotbInit();
	#(`CLK*2) i_rst = 0;
	#(`CLK*2) i_rst = 1;
	#(`CLK*10000) $display("Timeout");
	$NicotbFinal();
	$finish;
end

assign w_ack = w_canack & w_rdy;
assign ra_ack = ra_canack & ra_rdy;
`ifdef GATE_LEVEL
TopGateWrap
`else
Top
`endif
u_top(
	`clk_connect,
	`rdyack_connect(src, cfg),
	.dramra_rdy(ra_rdy),
	.dramra_ack(ra_ack),
	.dramrd_rdy(rd_rdy),
	.dramrd_ack(rd_ack),
	.dramw_rdy(w_rdy),
	.dramw_ack(w_ack)
);

endmodule
