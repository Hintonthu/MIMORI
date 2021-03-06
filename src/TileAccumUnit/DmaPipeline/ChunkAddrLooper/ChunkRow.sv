// Copyright 2016-2018
// Yu Sheng Lin

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


module ChunkRow(
	`clk_port,
	`rdyack_port(row),
	i_row_linear,
	i_row_islast,
	i_row_pad,
	i_row_valid,
	i_l,
	i_n,
	i_bound,
	i_wrap,
	`rdyack_port(cmd),
	o_cmd_type, // 0,1,2
	o_cmd_islast,
	o_cmd_addr,
	o_cmd_addrofs,
	o_cmd_len
);

//======================================
// Parameter
//======================================
localparam GBW = TauCfg::GLOBAL_ADDR_BW;
localparam CSIZE = TauCfg::CACHE_SIZE;
localparam VSIZE = TauCfg::VSIZE;
// derived
localparam V_BW = $clog2(VSIZE);
localparam C_BW = $clog2(CSIZE);
localparam V_BW1 = $clog2(VSIZE+1);

//======================================
// I/O
//======================================
`clk_input;
`rdyack_input(row);
input [GBW-1:0]  i_row_linear;
input            i_row_islast;
input [V_BW-1:0] i_row_pad;
input            i_row_valid;
input [GBW-1:0]  i_l;
input [GBW-1:0]  i_n;
input [GBW-1:0]  i_bound;
input            i_wrap;
`rdyack_output(cmd);
output logic [1:0]       o_cmd_type;
output logic             o_cmd_islast;
output logic [GBW-1:0]   o_cmd_addr;
output logic [C_BW-1:0]  o_cmd_addrofs;
output logic [V_BW1-1:0] o_cmd_len;

//======================================
// Internal
//======================================
`rdyack_logic(init_dst);
`dval_logic(init);
logic           invalid_line;
logic [GBW-1:0] br;
logic [GBW-1:0] l;
logic [GBW-1:0] r;
logic [GBW-1:0] b0;
logic [GBW-1:0] b1;
logic [GBW-1:0] b_curstage;
logic [GBW-1:0] cur_r;
logic [GBW-1:0] cur_align;
logic [GBW-1:0] cur_step;
logic [GBW-1:0] cur_bounded; // The actually issued address
logic [GBW-1:0] cur_nxt;
logic [GBW-1:0] cur_w;
logic [GBW-1:0] len;
logic has_lborder;
logic has_center;
logic has_rborder;
logic has_pad;
logic align_exceed;
logic step_exceed;
logic reach_boundary;
logic advance_state;
logic       work_fin;
// [0~3]:
// 0: ~0 (pad boundary); has_lborder
// 1: 0~br; has_center
// 2: br~ (pad boundary); has_rborder
// 3: pad garbage; has_pad
logic [3:0] work_done_r;
logic [3:0] work_done_w;
logic [3:0] work_todo;
logic [4:0] work_sel; // [4] = no more work
logic [3:0] work_selected_r;
logic [3:0] work_selected_w;

//======================================
// Submodule
//======================================
LoopController#(.DONE_IF(1), .HOLD_SRC(1)) u_loop(
	`clk_connect,
	`rdyack_connect(src, row),
	`rdyack_connect(dst, cmd),
	.loop_done_cond(work_fin),
	.reg_cg(),
	.loop_reset(init_dval),
	.loop_is_last(),
	.loop_is_repeat()
);
FindFromLsb#(4,1) u_fsm(
	.i(work_todo),
	.prefix(),
	.detect(work_sel)
);

//======================================
// Combinational
//======================================
//    i_row_linear   br    (absolute address)
//         0        i_l    (relative)
//         |--valid--|
//    |------wanted------|
//    l                  r (absolute)
assign invalid_line = !(i_row_valid || i_wrap); // this line is all padding?
assign work_todo = {has_pad, has_rborder, has_center, has_lborder} & ~work_done_r;
assign o_cmd_addr = cur_bounded >> C_BW << C_BW; // split address by cache line
assign o_cmd_addrofs = cur_bounded[C_BW-1:0]; // split address by cache line
// Choose static work condition
always_comb begin
	// if this is not a valid row, then all values is left (b0~b1)
	br = i_row_linear + i_bound;
	// bl = i_row_linear;
	l = i_row_linear + i_l; // i_l can be l.t. 0
	r = l + i_n; // r can be l.t. 0
	has_lborder = i_l[GBW-1] || invalid_line; // l negative?
	if ($signed(r) < $signed(i_row_linear) || invalid_line) begin
		// right bound < 0, meaning all row < 0, so the right bound of this part (b0) is r
		// We pretend that an invalid line is this case
		has_center = 1'b0;
		b0 = r;
	end else begin
		// The right bound of this part (b0) is i_row_linear
		has_center = $signed(i_l) < $signed(i_bound);
		b0 = i_row_linear;
	end
	// This is much simpler, whether the right bound protrude?
	// Set the right bound of this part (b1) accordingly
	if ($signed(r) <= $signed(br) || invalid_line) begin
		has_rborder = 1'b0;
		b1 = r;
	end else begin
		has_rborder = 1'b1;
		b1 = br;
	end
	// b2 = r;
	has_pad = i_row_pad != '0;
end

always_comb begin
	unique case (1'b1)
		work_selected_r[0]: begin
			b_curstage = b0;
			cur_bounded = i_row_linear; // issue boundary
			o_cmd_type = i_wrap ? 'd1 : 'd2;
		end
		work_selected_r[1]: begin
			b_curstage = b1;
			cur_bounded = cur_r; // issue real address
			o_cmd_type = 'd0;
		end
		work_selected_r[2]: begin
			// Equiv: b_curstage = b2
			b_curstage = r;
			cur_bounded = i_row_linear + i_bound - 'b1; // issue boundary
			o_cmd_type = i_wrap ? 'd1 : 'd2;
		end
		default: begin
			b_curstage = r; // don't care
			cur_bounded = cur_r;
			o_cmd_type = 'd2;
		end
	endcase
	// Advance the address
	// (1) should not exceed next cache line
	// if exceed border, then advance state
	cur_align = ((cur_r >> C_BW) + 'b1) << C_BW;
	align_exceed = $signed(cur_align) >= $signed(b_curstage);
	// (2) should not exceed max issue length (VSIZE)
	// if exceed border, then advance state
	cur_step = cur_r+VSIZE;
	step_exceed = $signed(cur_r+VSIZE) >= $signed(b_curstage);
	// (3) should not exceed boundary
	// This is (2+3)
	cur_nxt = step_exceed ? b_curstage : cur_step;
	if (work_selected_r[1]) begin
		// The center/valid part, (1) is considered as well
		cur_w = $signed(cur_nxt) > $signed(cur_align) ? cur_align : cur_nxt;
		reach_boundary = align_exceed && step_exceed;
	end else if (init_dval) begin
		// Init: start from l
		cur_w = l;
		reach_boundary = 1'b0;
	end else begin
		// The center/valid part, only (2+3)
		cur_w = cur_nxt;
		reach_boundary = step_exceed;
	end
	// Compute command length
	len = cur_w - cur_r;
	o_cmd_len = work_selected_r[3] ? {1'b0, i_row_pad} : len[V_BW1-1:0];
	// Pad garbage is always done in in 1 command
	advance_state = work_selected_r[3] || reach_boundary;
	work_fin = advance_state && work_sel[4];
	o_cmd_islast = work_fin && i_row_islast;
	// keep track of the work done
	casez ({init_dval,cmd_ack,advance_state,work_sel[4]})
		4'b1???: begin
			work_done_w = work_sel[3:0];
			work_selected_w = work_sel[3:0];
		end
		4'b0110: begin
			work_done_w = work_done_r | work_sel[3:0];
			work_selected_w = work_sel[3:0];
		end
		4'b0111: begin
			work_done_w = '0;
			work_selected_w = '0;
		end
		4'b010?,
		4'b00??: begin
			work_done_w = work_done_r;
			work_selected_w = work_selected_r;
		end
	endcase
end

//======================================
// Sequential
//======================================
`ff_rst
	work_done_r <= '0;
	work_selected_r <= '0;
`ff_cg(init_dval || cmd_ack && advance_state)
	work_done_r <= work_done_w;
	work_selected_r <= work_selected_w;
`ff_end

`ff_rst
	cur_r <= '0;
`ff_cg(init_dval || cmd_ack)
	cur_r <= work_selected_w[3] ? cur_bounded : cur_w;
`ff_end

endmodule
