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

module AccumBlockLooper(
	`clk_port,
	`rdyack_port(src),
	i_bofs,
	i_agrid_step,
	i_agrid_end,
	i_aboundary,
	`rdyack_port(i0_abofs),
	o_i0_bofs,
	o_i0_aofs,
	o_i0_alast,
	o_i0_beg,
	o_i0_end,
	`rdyack_port(i1_abofs),
	o_i1_bofs,
	o_i1_aofs,
	o_i1_alast,
	o_i1_beg,
	o_i1_end,
	`rdyack_port(o_abofs),
	o_o_bofs,
	o_o_aofs,
	o_o_alast,
	o_o_beg,
	o_o_end,
	`rdyack_port(alu_abofs),
	o_alu_bofs,
	o_alu_aofs,
	o_alu_alast,
	`dval_port(blkdone)
);

//======================================
// Parameter
//======================================
localparam WBW = TauCfg::WORK_BW;
localparam VDIM = TauCfg::VDIM;
localparam N_ICFG = TauCfg::N_ICFG;
localparam N_INST = TauCfg::N_INST;
localparam AF_BW = TauCfg::AOFS_FRAC_BW;
localparam AS_BW = TauCfg::AOFS_SHAMT_BW;
// derived
localparam ICFG_BW = $clog2(N_ICFG+1);
localparam INST_BW = $clog2(N_INST+1);

//======================================
// I/O
//======================================
`clk_input;
`rdyack_input(src);
input [WBW-1:0]     i_bofs        [VDIM];
input [AF_BW-1:0]   i_agrid_step  [VDIM];
input [AS_BW-1:0]   i_agrid_end   [VDIM];
input [WBW-1:0]     i_aboundary   [VDIM];
`rdyack_output(i0_abofs);
output [WBW-1:0]     o_i0_bofs  [DIM];
output [WBW-1:0]     o_i0_aofs  [DIM];
output [WBW-1:0]     o_i0_alast [DIM];
output [ICFG_BW-1:0] o_i0_beg;
output [ICFG_BW-1:0] o_i0_end;
`rdyack_output(i1_abofs);
output [WBW-1:0]     o_i1_bofs  [DIM];
output [WBW-1:0]     o_i1_aofs  [DIM];
output [WBW-1:0]     o_i1_alast [DIM];
output [OCFG_BW-1:0] o_i1_beg;
output [OCFG_BW-1:0] o_i1_end;
`rdyack_output(o_abofs);
output [WBW-1:0]     o_o_bofs  [DIM];
output [WBW-1:0]     o_o_aofs  [DIM];
output [WBW-1:0]     o_o_alast [DIM];
output [OCFG_BW-1:0] o_o_beg;
output [OCFG_BW-1:0] o_o_end;
`rdyack_output(alu_abofs);
output [WBW-1:0] o_alu_bofs  [DIM];
output [WBW-1:0] o_alu_aofs  [DIM];
output [WBW-1:0] o_alu_alast [DIM];
`dval_output(blkdone);

//======================================
// Internal
//======================================
`rdyack_logic(bfc_dst);
logic [WBW-1:0] bfc_aofs      [DIM];
logic [WBW-1:0] bfc_alast_tmp [DIM];
logic [WBW-1:0] bfc_alast     [DIM];
logic           bfc_islast;

//======================================
// Combinational
//======================================
assign o_i0_bofs = i_bofs;
assign o_i1_bofs = i_bofs;
assign o_alu_bofs = i_bofs;
assign o_i0_aofs = bfc_aofs;
assign o_i1_aofs = bfc_aofs;
assign o_alu_aofs = bfc_aofs;
assign o_i0_alast = bfc_alast;
assign o_i1_alast = bfc_alast;
assign o_alu_alast = bfc_alast;
assign blkdone_dval = bfc_dst_ack && bfc_islast;
always_comb begin
	for (int i = 0; i < DIM; i++) begin
		bfc_alast_tmp[i] = bfc_aofs[i] + i_alocal_last[i];
		bfc_alast[i] = bfc_alast_tmp[i] > i_aboundary[i] ? i_aboundary[i] : bfc_alast_tmp[i];
	end
end

//======================================
// Submodule
//======================================
// BFC goes to *_ABOFS
Broadcast#(3) u_brd(
	`clk_connect,
	`rdyack_connect(src, bfc_dst),
	.acked(),
	.dst_rdys({alu_abofs_rdy,i1_abofs_rdy,i0_abofs_rdy}),
	.dst_acks({alu_abofs_ack,i1_abofs_ack,i0_abofs_ack})
);
OffsetStage#(.FRAC_BW(AF_BW), .SHAMT_BW(AS_BW)) u_bfc(
	`clk_connect,
	`rdyack_connect(src, src),
	.i_ofs_frac(i_agrid_frac),
	.i_ofs_shamt(i_agrid_shamt),
	.i_ofs_local_start(ND_WZERO),
	.i_ofs_local_last(i_agrid_last),
	.i_ofs_global_last(),
	`rdyack_connect(dst, bfc_dst),
	.o_ofs(bfc_aofs),
	.o_reset_flag(),
	.o_add_flag(),
	.o_sel_beg(),
	.o_sel_end(),
	.o_sel_ret(),
	.o_islast(bfc_islast)
);

endmodule
