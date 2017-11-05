// Copyright 2016-2018 Yu Sheng Lin

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

module NDAdder(
	i_restart,
	i_cur,
	i_cur_noofs,
	i_beg,    // not used if FROM_ZERO = 1
	i_stride, // not used if UNIT_STRIDE = 1
	i_end,
	i_global_end,
	o_nxt,
	o_nxt_noofs,
	o_sel_beg,
	o_sel_end,
	o_sel_ret,
	o_carry
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
input           i_restart;
input  [BW-1:0] i_cur        [DIM];
input  [BW-1:0] i_cur_noofs  [DIM];
input  [BW-1:0] i_beg        [DIM];
input  [BW-1:0] i_stride     [DIM];
input  [BW-1:0] i_end        [DIM];
input  [BW-1:0] i_global_end [DIM];
output logic [BW-1:0] o_nxt       [DIM];
output logic [BW-1:0] o_nxt_noofs [DIM];
output [DIM:0]  o_sel_beg;
output [DIM:0]  o_sel_end;
output [DIM:0]  o_sel_ret;
output          o_carry;

//======================================
// Internal
//======================================
logic [BW-1:0] added [DIM];
logic [BW-1:0] added_noofs [DIM];
logic [DIM-1:0] l_islast;
logic [DIM-1:0] g_iszero;
logic [DIM-1:0] g_islast;
logic [DIM-1:0] cur_rst;
always_comb for (int i = 0; i < DIM; i++) begin
	if (UNIT_STRIDE) begin
		added[i] = i_cur[i] + 'b1;
		added_noofs[i] = i_cur_noofs[i] + 'b1;
	end else begin
		added[i] = i_cur[i] + i_stride[i];
		added_noofs[i] = i_cur_noofs[i] + i_stride[i];
	end
	g_iszero[      i] = added[i] == '0;
	g_islast[DIM-1-i] = added[i] == i_global_end[i];
	l_islast[DIM-1-i] = added[i] == i_end[i];
end

//======================================
// Submodule
//======================================
FindFromMsb#(DIM, 0) u_sel_beg(.i(g_iszero), .prefix(), .detect(o_sel_beg));
FindFromLsb#(DIM, 0) u_sel_end(.i(g_islast), .prefix(), .detect(o_sel_end));
FindFromLsb#(DIM, 0) u_sel_ret(.i(l_islast), .prefix(cur_rst), .detect(o_sel_ret));

//======================================
// Combinational
//======================================
assign o_carry = o_sel_ret[DIM];
always_comb for (int i = 0; i < DIM; i++) begin
	casez ({(i_restart|!cur_rst[DIM-1-i]), o_sel_ret[DIM-1-i]})
		2'b1?: begin
			o_nxt[i] = FROM_ZERO ? '0 : i_beg[i];
			o_nxt_noofs[i] = '0;
		end
		2'b01: begin
			o_nxt[i] = added[i];
			o_nxt_noofs[i] = added_noofs[i];
		end
		2'b00: begin
			o_nxt[i] = i_cur[i];
			o_nxt_noofs[i] = i_cur_noofs[i];
		end
	endcase
end

endmodule

module NDShufAccum(
	i_augend, // not used if ZERO_AUG = 1
	o_sum,
	i_addend,
	i_shuf // not used if DIM_OUT = 1
);
//======================================
// Parameter
//======================================
parameter BW = 8;
parameter DIM_IN = 2;
parameter DIM_OUT = 2;
parameter ZERO_AUG = 0;
localparam CLOG2_DIM_OUT = $clog2(DIM_OUT);

//======================================
// I/O
//======================================
input        [BW-1:0] i_augend [DIM_OUT];
output logic [BW-1:0] o_sum    [DIM_OUT];
input        [BW-1:0] i_addend [DIM_IN];
input        [CLOG2_DIM_OUT-1:0] i_shuf [DIM_IN];

//======================================
// Combinational
//======================================
generate if (DIM_OUT == 1) begin: sum_all_mode
	always_comb begin
		o_sum[0] = '0;
		for (int i = 0; i < DIM_IN; i++) begin
			o_sum[0] = o_sum[0] + i_addend[i];
		end
		o_sum[0] = o_sum[0] + (ZERO_AUG ? '0 : i_augend[0]);
	end
end else begin: sum_shuf_mode
	always_comb begin
		for (int i = 0; i < DIM_OUT; i++) begin
			o_sum[i] = '0;
			for (int j = 0; j < DIM_IN; j++) begin
				o_sum[i] = o_sum[i] + ((i == i_shuf[j]) ? i_addend[j] : '0);
			end
			o_sum[i] = o_sum[i] + (ZERO_AUG ? '0 : i_augend[i]);
		end
	end
end endgenerate

endmodule

module IdSelect(
	i_sel,
	i_begs,
	i_ends,
	o_dat
);
//======================================
// Parameter
//======================================
parameter BW = 8;
parameter DIM = 2;
parameter RETIRE = 0;

//======================================
// I/O
//======================================
input [DIM:0]  i_sel;
input [BW-1:0] i_begs [DIM+1];
input [BW-1:0] i_ends [DIM+1];
output logic [BW-1:0] o_dat;

always_comb begin
	if (RETIRE) begin
		o_dat = i_sel[DIM] ? i_ends[DIM] : '0;
		for (int i = 0; i < DIM; i++) begin
			if (i_sel[i]) begin
				o_dat = o_dat | i_begs[i+1];
			end
		end
	end else begin
		o_dat = '0;
		for (int i = 0; i <= DIM; i++) begin
			if (i_sel[i]) begin
				o_dat = o_dat | i_begs[i];
			end
		end
	end
end

endmodule
