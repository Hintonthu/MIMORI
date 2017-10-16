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

module AccumBlockLooper(
	`clk_port,
	`rdyack_port(src_bofs),
	i_bofs,
	i_agrid_frac,
	i_agrid_shamt,
	i_agrid_last,
	i_alocal_last,
	i_aboundary,
	i_mofs_starts,
	i_mofs_asteps,
	i_mofs_ashufs,
	i_id_begs,
	i_id_ends,
	`rdyack_port(dst_abofs),
	o_bofs,
	o_aofs,
	o_alast,
	`rdyack_port(dst_mofs),
	o_mofs,
	o_id
);

//======================================
// Parameter
//======================================
parameter SUM_ALL = Default::SUM_ALL;
parameter N_CFG = Default::N_CFG;
localparam WBW = TauCfg::WORK_BW;
localparam GBW = TauCfg::GLOBAL_ADDR_BW;
localparam DIM = TauCfg::DIM;
localparam AF_BW = TauCfg::AOFS_FRAC_BW;
localparam AS_BW = TauCfg::AOFS_SHAMT_BW;
// derived
localparam NCFG_BW = $clog2(N_CFG+1);
localparam DIM_BW = $clog2(DIM);
localparam ODIM = SUM_ALL ? 1 : DIM;
// Workaround
logic [WBW-1:0] ND_WZERO [DIM] = '{default:0};

//======================================
// I/O
//======================================
`clk_input;
`rdyack_input(src_bofs);
input [WBW-1:0]     i_bofs        [DIM];
input [AF_BW-1:0]   i_agrid_frac  [DIM];
input [AS_BW-1:0]   i_agrid_shamt [DIM];
input [WBW-1:0]     i_agrid_last  [DIM];
input [WBW-1:0]     i_alocal_last [DIM];
input [WBW-1:0]     i_aboundary   [DIM];
input [GBW-1:0]     i_mofs_starts [N_CFG][ODIM];
input [GBW-1:0]     i_mofs_asteps [N_CFG][DIM];
input [DIM_BW-1:0]  i_mofs_ashufs [N_CFG][DIM];
input [NCFG_BW-1:0] i_id_begs [DIM+1];
input [NCFG_BW-1:0] i_id_ends [DIM+1];
`rdyack_output(dst_abofs);
output [WBW-1:0]     o_bofs  [DIM];
output [WBW-1:0]     o_aofs  [DIM];
output [WBW-1:0]     o_alast [DIM];
`rdyack_output(dst_mofs);
output [GBW-1:0]     o_mofs [ODIM];
output [NCFG_BW-1:0] o_id;

//======================================
// Internal
//======================================
`rdyack_logic(s0_src);
`rdyack_logic(s0_dst);
`rdyack_logic(s01_mask);
`rdyack_logic(s1_src);
`rdyack_logic(s12);
`rdyack_logic(mc_src);
`rdyack_logic(wait_fin);
`dval_logic(mc_islast);
logic               s01_bypass;
logic               s01_islast;
logic [NCFG_BW-1:0] s01_id_beg;
logic [NCFG_BW-1:0] s01_id_end;
logic [DIM-1:0]     s01_reset_flag;
logic [DIM-1:0]     s01_add_flag;
logic [DIM  :0]     s01_sel_beg;
logic [DIM  :0]     s01_sel_end;
logic [WBW-1:0]     alast_tmp [DIM];
logic               s12_islast;
logic [NCFG_BW-1:0] s12_id;
logic [DIM-1:0]     s12_reset_flag;
logic [DIM-1:0]     s12_add_flag;

//======================================
// Combinational
//======================================
assign o_bofs = i_bofs;
assign s01_bypass = s01_id_beg == s01_id_end;
assign s01_mask_rdy = s0_dst_rdy && !s01_bypass;
assign s0_dst_ack = s01_mask_ack || s0_dst_rdy && s01_bypass;
assign wait_fin_ack = mc_islast_dval || s0_dst_rdy && s01_bypass && s01_islast;
always_comb begin
	for (int i = 0; i < DIM; i++) begin
		alast_tmp[i] = o_aofs[i] + i_alocal_last[i];
		o_alast[i] = alast_tmp[i] > i_aboundary[i] ? i_aboundary[i] : alast_tmp[i];
	end
end

//======================================
// Submodule
//======================================
Broadcast#(2) u_brd0(
	`clk_connect,
	`rdyack_connect(src, src_bofs),
	.acked(),
	.dst_rdys({wait_fin_rdy,s0_src_rdy}),
	.dst_acks({wait_fin_ack,s0_src_ack})
);
Broadcast#(2) u_brd1(
	`clk_connect,
	`rdyack_connect(src, s01_mask),
	.acked(),
	.dst_rdys({s1_src_rdy,dst_abofs_rdy}),
	.dst_acks({s1_src_ack,dst_abofs_ack})
);
OffsetStage#(.FRAC_BW(AF_BW), .SHAMT_BW(AS_BW)) u_s0_bfc(
	`clk_connect,
	`rdyack_connect(src, s0_src),
	.i_ofs_frac(i_agrid_frac),
	.i_ofs_shamt(i_agrid_shamt),
	.i_ofs_local_start(ND_WZERO),
	.i_ofs_local_last(i_agrid_last),
	.i_ofs_global_last(i_agrid_last),
	`rdyack_connect(dst, s0_dst),
	.o_ofs(o_aofs),
	.o_reset_flag(s01_reset_flag),
	.o_add_flag(s01_add_flag),
	.o_sel_beg(s01_sel_beg),
	.o_sel_end(s01_sel_end),
	.o_sel_ret(),
	.o_islast(s01_islast)
);
IdSelect#(.BW(NCFG_BW), .DIM(DIM), .RETIRE(0)) u_s0_sel_beg(
	.i_sel(s01_sel_beg),
	.i_begs(i_id_begs),
	.i_ends(),
	.o_dat(s01_id_beg)
);
IdSelect#(.BW(NCFG_BW), .DIM(DIM), .RETIRE(0)) u_s0_sel_end(
	.i_sel(s01_sel_end),
	.i_begs(i_id_ends),
	.i_ends(),
	.o_dat(s01_id_end)
);
IndexStage#(.N_CFG(N_CFG), .BLOCK_MODE(0)) u_s1_idx_i0(
	`clk_connect,
	`rdyack_connect(src, s1_src),
	.i_reset_flag(s01_reset_flag),
	.i_add_flag(s01_add_flag),
	.i_id_beg(s01_id_beg),
	.i_id_end(s01_id_end),
	.i_islast(s01_islast),
	`rdyack_connect(dst, s12),
	.o_reset_flag(s12_reset_flag),
	.o_add_flag(s12_add_flag),
	.o_id(s12_id),
	.o_islast(s12_islast)
);
MemofsStage #(
	.N_CFG(N_CFG),
	.FRAC_BW(AF_BW),
	.SHAMT_BW(AS_BW),
	.SUM_ALL(SUM_ALL)
) u_s2_mofs (
	`clk_connect,
	`rdyack_connect(src, s12),
	.i_bofs_frac(i_agrid_frac),
	.i_bofs_shamt(i_agrid_shamt),
	.i_mofs_starts(i_mofs_starts),
	.i_mofs_steps(i_mofs_asteps),
	.i_mofs_shufs(i_mofs_ashufs),
	.i_reset_flag(s12_reset_flag),
	.i_add_flag(s12_add_flag),
	.i_islast(s12_islast),
	.i_id(s12_id),
	`rdyack_connect(dst, dst_mofs),
	.o_mofs(o_mofs),
	.o_id(o_id),
	`dval_connect(islast, mc_islast)
);

endmodule
