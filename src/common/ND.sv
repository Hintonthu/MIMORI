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

module NDCounterAddFlag(
	i_cur,
	i_end,
	i_carry,
	o_reset_counter,
	o_add_counter,
	o_done
);

parameter BW = 8;
parameter DIM = 2;
localparam TOTAL_BW = BW*DIM;

input        [BW-1:0] i_cur [DIM];
input        [BW-1:0] i_end [DIM];
input                 i_carry    ;
output logic [DIM-1:0] o_reset_counter;
output logic [DIM-1:0] o_add_counter;
output logic           o_done;

logic [DIM-1:0] equal;
logic [DIM-1:0] reset_counter;
logic [DIM-1:0] reset_counter_inv;
logic [DIM-1:0] add_counter;
logic           done;

always_comb begin
	for (int i = 0; i < DIM; i++) begin
		equal[i] = i_cur[i] == i_end[i];
	end
end

FindFromMsb#(DIM, 0) u_ff(equal, reset_counter_inv, {add_counter,done});
assign reset_counter = ~reset_counter_inv;
always_comb begin
	if (i_carry) begin
		o_add_counter = add_counter;
		o_reset_counter = reset_counter;
		o_done = done;
	end else begin
		o_add_counter = '0;
		o_reset_counter = '0;
		o_done = 1'b0;
	end
end

endmodule

module NDCounterAddSelect(
	i_augend,
	o_sum,
	i_start,
	i_step,
	i_frac,
	i_shamt,
	i_reset_counter,
	i_add_counter
);

parameter BW = 32;
parameter DIM = 4;
parameter FRAC_BW = 2;
parameter SHAMT_BW = 4;
parameter UNIT_STEP = 0; // bool, i_step=(1,1, ...) if true
localparam FBW = FRAC_BW == 0 ? 1 : FRAC_BW;
localparam SBW = SHAMT_BW == 0 ? 1 : SHAMT_BW;
localparam MBW = BW+FRAC_BW;
localparam [FRAC_BW-1:0] PAD_ZERO = 0;
localparam [BW-1:0] PAD_ONE = 1;
// Workaround
logic [BW-1:0] ND_ZERO [DIM] = '{DIM{0}};
logic [BW-1:0] ND_ONE [DIM] = '{DIM{1}};

input        [ BW-1:0] i_augend [DIM];
output logic [ BW-1:0] o_sum    [DIM];
input        [ BW-1:0] i_start  [DIM];
input        [ BW-1:0] i_step   [DIM];
input        [FBW-1:0] i_frac   [DIM];
input        [SBW-1:0] i_shamt  [DIM];
input        [DIM-1:0] i_reset_counter;
input        [DIM-1:0] i_add_counter;

logic [MBW-1:0] sum_raw     [DIM];
logic [MBW-1:0] sum_shifted [DIM];

generate case ({FRAC_BW == 0, UNIT_STEP != 0})
	2'b00: begin: all_enable
		always_comb begin
			for (int i = 0; i < DIM; i++) begin
				sum_raw[i] = {PAD_ZERO, i_step[i]} * {PAD_ONE, i_frac[i]};
			end
		end
	end
	2'b01: begin: frac_only
		always_comb begin
			for (int i = 0; i < DIM; i++) begin
				sum_raw[i] = {PAD_ONE, i_frac[i]};
			end
		end
	end
	2'b10: begin: no_frac
		assign sum_raw = i_step;
	end
	2'b11: begin: one
		assign sum_raw = ND_ONE;
	end
endcase endgenerate

generate if (SHAMT_BW == 0) begin
	assign sum_shifted = sum_raw;
end else begin
	always_comb begin
		for (int i = 0; i < DIM; i++) begin
			sum_shifted[i] = sum_raw[i] << i_shamt[i];
		end
	end
end endgenerate

always_comb begin
	for (int i = 0; i < DIM; i++) begin
		if (i_reset_counter[i]) begin
			o_sum[i] = i_start[i];
		end else if (i_add_counter[i]) begin
			o_sum[i] = i_augend[i] + sum_shifted[i][MBW-1-:BW];
		end else begin
			o_sum[i] = i_augend[i];
		end
	end
end

endmodule

module NDShufAccum(
	i_augend,
	o_sum,
	i_addend,
	i_shuf
);

parameter BW = 8;
parameter DIM = 2;
parameter SUM_ALL = 0;
localparam SDIM = SUM_ALL ? 1 : DIM;
localparam CLOG2_DIM = $clog2(DIM);

input        [BW-1:0] i_augend [SDIM];
output logic [BW-1:0] o_sum    [SDIM];
input        [BW-1:0] i_addend [DIM];
input        [CLOG2_DIM-1:0] i_shuf [DIM];

generate if (SUM_ALL) begin: sum_all_mode
	always_comb begin
		o_sum[0] = i_augend[0];
		for (int i = 0; i < DIM; i++) begin
			o_sum[0] = o_sum[0] + i_addend[i];
		end
	end
end else begin: sum_shuf_mode
	always_comb begin
		for (int i = 0; i < DIM; i++) begin
			o_sum[i] = i_augend[i];
			for (int j = 0; j < DIM; j++) begin
				o_sum[i] = o_sum[i] + ((i == i_shuf[j]) ? i_addend[j] : '0);
			end
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

parameter BW = 8;
parameter DIM = 2;
parameter RETIRE = 0;

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
