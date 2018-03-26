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
	i_ofs_beg,
	i_ofs_end,
	i_ofs_gend,
	i_stride,
	`rdyack_port(dst),
	o_ofs,
	o_lofs,
	o_sel_beg,
	o_sel_end,
	o_sel_ret,
	o_islast
);

//======================================
// Parameter
//======================================
parameter BW = 8;
parameter DIM = 2;
parameter FROM_ZERO = 0;
parameter UNIT_STRIDE = 0;

//======================================
// I/O
//======================================
`clk_input;
`rdyack_input(src);
input [BW-1:0] i_ofs_beg [DIM];
input [BW-1:0] i_ofs_end [DIM];
input [BW-1:0] i_ofs_gend [DIM];
input [BW-1:0] i_stride [DIM];
`rdyack_output(dst);
output logic [BW-1:0] o_ofs [DIM];
output logic [BW-1:0] o_lofs [DIM];
output logic [DIM :0] o_sel_beg;
output logic [DIM :0] o_sel_end;
output logic [DIM :0] o_sel_ret;
output logic          o_islast;

//======================================
// Internal
//======================================
logic [BW-1:0] ofs_nxt [DIM];
logic [BW-1:0] lofs_nxt [DIM];
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
NDAdder#(BW, DIM, FROM_ZERO, UNIT_STRIDE) u_adder(
	.i_restart(init_dval),
	.i_cur(o_ofs),
	.i_cur_noofs(o_lofs),
	.i_beg(i_ofs_beg),
	.i_stride(i_stride),
	.i_end(i_ofs_end),
	.i_global_end(i_ofs_gend),
	.o_nxt(ofs_nxt),
	.o_nxt_noofs(lofs_nxt),
	.o_sel_beg(o_sel_beg),
	.o_sel_end(o_sel_end),
	.o_sel_ret(o_sel_ret),
	.o_carry(o_islast)
);
AcceptIf u_ac(
	.cond(o_islast),
	`rdyack_connect(src, dst_raw),
	`rdyack_connect(dst, dst)
);

//======================================
// Sequential
//======================================
`ff_rst
	for (int i = 0; i < DIM; i++) begin
		o_ofs[i] <= '0;
		o_lofs[i] <= '0;
	end
`ff_cg(init_dval || dst_ack)
	o_ofs <= ofs_nxt;
	o_lofs <= lofs_nxt;
`ff_end

endmodule

