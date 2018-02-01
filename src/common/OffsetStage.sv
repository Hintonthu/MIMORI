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

module OffsetStage(
	`clk_port,
	`rdyack_port(src),
	i_ofs_frac,
	i_ofs_shamt,
	i_ofs_local_start,
	i_ofs_local_last,
	i_ofs_global_last,
	`rdyack_port(dst),
	o_ofs,
	o_reset_flag,
	o_add_flag,
	// these are combinational out
	o_sel_beg,
	o_sel_end,
	o_sel_ret,
	o_islast
);

//======================================
// Parameter
//======================================
parameter FRAC_BW = TauCfg::BOFS_FRAC_BW;
parameter SHAMT_BW = TauCfg::BOFS_SHAMT_BW;
localparam WBW = TauCfg::WORK_BW;
localparam DIM = TauCfg::DIM;
localparam SAFE_FBW = FRAC_BW < 1 ? 1 : FRAC_BW;
localparam SAFE_SBW = SHAMT_BW < 1 ? 1 : SHAMT_BW;

//======================================
// I/O
//======================================
`clk_input;
`rdyack_input(src);
input [SAFE_FBW-1:0] i_ofs_frac        [DIM];
input [SAFE_SBW-1:0] i_ofs_shamt       [DIM];
input [WBW-1:0]      i_ofs_local_start [DIM];
input [WBW-1:0]      i_ofs_local_last  [DIM];
input [WBW-1:0]      i_ofs_global_last [DIM];
`rdyack_output(dst);
output logic [WBW-1:0]    o_ofs [DIM];
output logic [DIM-1:0]    o_reset_flag;
output logic [DIM-1:0]    o_add_flag;
output logic [DIM  :0]    o_sel_beg;
output logic [DIM  :0]    o_sel_end;
output logic [DIM  :0]    o_sel_ret;
output logic              o_islast;

//======================================
// Internal
//======================================
logic [WBW-1:0] blockofs_w   [DIM];
logic [DIM-1:0] reset_flag_nxt;
logic [DIM-1:0] reset_flag_w;
logic [DIM-1:0] add_flag_nxt;
logic [DIM-1:0] add_flag_w;
logic [DIM-1:0] l_islast;
logic [DIM-1:0] g_iszero;
logic [DIM-1:0] g_islast;
`rdyack_logic(dst_raw);
`dval_logic(init);

//======================================
// Submodule
//======================================
OneCycleInit u_delay(
	`clk_connect,
	`rdyack_connect(src, src),
	`rdyack_connect(dst, dst_raw),
	`dval_connect(init, init)
);
NDCounterAddFlag#(.BW(WBW), .DIM(DIM)) u_flag(
	.i_cur(o_ofs),
	.i_end(i_ofs_local_last),
	.i_carry(1'b1),
	.o_reset_counter(reset_flag_nxt),
	.o_add_counter(add_flag_nxt),
	.o_done(o_islast)
);
NDCounterAddSelect#(
	.BW(WBW),
	.DIM(DIM),
	.FRAC_BW(FRAC_BW),
	.SHAMT_BW(SHAMT_BW),
	.UNIT_STEP(1)
) u_sel(
	.i_augend(o_ofs),
	.o_sum(blockofs_w),
	.i_start(i_ofs_local_start),
	.i_step(),
	.i_frac(i_ofs_frac),
	.i_shamt(i_ofs_shamt),
	.i_reset_counter(reset_flag_w),
	.i_add_counter(add_flag_w)
);
FindFromMsb#(DIM, 0) u_find_beg(
	.i(g_iszero),
	.prefix(),
	.detect(o_sel_beg)
);
FindFromLsb#(DIM, 0) u_find_end(
	.i(g_islast),
	.prefix(),
	.detect(o_sel_end)
);
FindFromLsb#(DIM, 0) u_find_ret(
	.i(l_islast),
	.prefix(),
	.detect(o_sel_ret)
);
AcceptIf u_ac(
	.cond(o_islast),
	`rdyack_connect(src, dst_raw),
	`rdyack_connect(dst, dst)
);

//======================================
// Combinational
//======================================
always_comb begin
	casez({init_dval, dst_ack})
		2'b1?: begin
			reset_flag_w = '1;
			add_flag_w = '0;
		end
		2'b01: begin
			reset_flag_w = reset_flag_nxt;
			add_flag_w = add_flag_nxt;
		end
		2'b00: begin
			reset_flag_w = o_reset_flag;
			add_flag_w = o_add_flag;
		end
	endcase
end

always_comb begin
	for (int i = 0; i < DIM; i++) begin
		l_islast[DIM-1-i] = o_ofs[i] == i_ofs_local_last[i];
		g_iszero[      i] = o_ofs[i] == '0;
		g_islast[DIM-1-i] = o_ofs[i] == i_ofs_global_last[i];
	end
end

//======================================
// Sequential
//======================================
`ff_rst
	for (int i = 0; i < DIM; i++) begin
		o_ofs[i] <= '0;
	end
	o_reset_flag <= '0;
	o_add_flag <= '0;
`ff_cg(init_dval || dst_ack)
	o_ofs <= blockofs_w;
	o_reset_flag <= reset_flag_w;
	o_add_flag <= add_flag_w;
`ff_end

endmodule

