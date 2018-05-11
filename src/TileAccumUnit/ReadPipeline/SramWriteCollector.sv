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


module SramWriteCollector(
	`clk_port,
	`rdyack_port(alloc_linear),
	i_linear,
	i_linear_id,
	i_size,
	i_skip,
	i_padv,
	`rdyack_port(cmd),
	i_cmd_type,
	i_cmd_islast,
	i_cmd_addrofs,
	i_cmd_len,
	`rdyack_port(dramrd),
	i_dramrd,
	`rdyack_port(done_linear),
	o_linear,
	o_linear_id,
	`dval_port(w),
	o_id,
	o_hiaddr,
	o_data
);

//======================================
// Parameter
//======================================
parameter LBW = TauCfg::LOCAL_ADDR_BW0;
localparam DBW = TauCfg::DATA_BW;
localparam N_ICFG = TauCfg::N_ICFG;
localparam VSIZE = TauCfg::VSIZE;
localparam CSIZE = TauCfg::CACHE_SIZE;
localparam XOR_BW = TauCfg::XOR_BW;
// derived
localparam ICFG_BW = $clog2(N_ICFG+1);
localparam CV_BW = $clog2(VSIZE);
localparam CV_BW1 = $clog2(VSIZE+1);
localparam CC_BW = $clog2(CSIZE);
localparam CX_BW = $clog2(XOR_BW);
localparam [LBW-CV_BW1-1:0] LV_PAD_ZERO = 0;
localparam [LBW-CV_BW1  :0] L1V_PAD_ZERO = 0;
localparam CV_DIFF_BW = CSIZE>VSIZE ? CSIZE-VSIZE : 1;
localparam READ_DIFF_BW = VSIZE>CSIZE ? (VSIZE-CSIZE)*DBW : 1;
localparam [CV_DIFF_BW-1:0] CV_PAD_ZERO = 0;
localparam [READ_DIFF_BW-1:0] READ_PAD_ZERO = 0;
//======================================
// I/O
//======================================
`clk_input;
`rdyack_input(alloc_linear);
input [LBW-1:0]     i_linear;
input [ICFG_BW-1:0] i_linear_id;
input [LBW:0]       i_size;
input               i_skip;
input [DBW-1:0]     i_padv;
`rdyack_input(cmd);
input [1:0]        i_cmd_type;
input              i_cmd_islast;
input [CC_BW-1:0]  i_cmd_addrofs;
input [CV_BW1-1:0] i_cmd_len;
`rdyack_input(dramrd);
input [DBW-1:0] i_dramrd [CSIZE];
`rdyack_output(done_linear);
output logic [LBW-1:0]     o_linear;
output logic [ICFG_BW-1:0] o_linear_id;
`dval_output(w);
output logic [ICFG_BW-1:0]   o_id;
output logic [LBW-CV_BW-1:0] o_hiaddr;
output logic [DBW-1:0]       o_data [VSIZE];

//======================================
// Internal
//======================================
typedef enum {FREE = 0, RUN, COMMIT, FSM_N} Fsm;
logic [FSM_N-1:0] fsm_r;
logic [FSM_N-1:0] fsm_w;
logic [CSIZE*DBW-1:0] data_1d;
logic [CSIZE*DBW-1:0] data_1d_shiftr;
logic [VSIZE*DBW-1:0] data_1d_shiftl;
logic [DBW-1:0] data_w [VSIZE];
logic [LBW-1:0] cur_r;
logic [LBW-1:0] cur_w;
logic [CV_BW1-1:0] cmd_handled_r;
logic [CV_BW1-1:0] cmd_handled_w;
logic [CV_BW1-1:0] buf_left;
logic [CV_BW1-1:0] cmd_left;
logic [CV_BW1-1:0] advance_ptr;
logic cmd_eq_buf;
logic cmd_gt_buf;
logic cmd_ge_buf;
logic cmd_le_buf;
logic require_dram;
logic enable_buf_write;
logic collected;
logic [LBW:0] filled_r;
logic [LBW:0] filled_nxt;
logic [LBW:0] filled_w;
logic         fill_done;
logic [LBW:0] size_r;
logic [DBW-1:0] padv_r;
logic [VSIZE-1:0] wmask;

//======================================
// Combinational
//======================================
assign done_linear_rdy = fsm_r[COMMIT];
assign wmask = (~('1<<i_cmd_len)) << cur_r[CV_BW-1:0];
assign o_linear_id = o_id;
always_comb begin
	fsm_w = '0;
	collected = 1'b0;
	alloc_linear_ack = 1'b0;
	enable_buf_write = 1'b0;
	cmd_ack = 1'b0;
	dramrd_ack = 1'b0;
	filled_w = filled_r;
	filled_nxt = filled_r + {L1V_PAD_ZERO, advance_ptr};
	fill_done = filled_nxt == size_r;
	cur_w = cur_r;
	cmd_handled_w = cmd_handled_r;
	unique case(1'b1)
		fsm_r[FREE]: begin
			if (alloc_linear_rdy) begin
				alloc_linear_ack = 1'b1;
				cur_w = i_linear;
				filled_w = '0;
				if (i_skip) begin
					fsm_w[COMMIT] = 1'b1;
				end else begin
					fsm_w[RUN] = 1'b1;
				end
			end else begin
				fsm_w[FREE] = 1'b1;
			end
		end
		fsm_r[RUN]: begin
			enable_buf_write = cmd_rdy && (!require_dram || dramrd_rdy);
			if (enable_buf_write) begin
				collected = cmd_ge_buf;
				cur_w = cur_r + {LV_PAD_ZERO, advance_ptr};
				cmd_ack = cmd_rdy && cmd_le_buf;
				cmd_handled_w = cmd_ack ? '0 : cmd_handled_r + advance_ptr;
				dramrd_ack = dramrd_rdy && cmd_ack && i_cmd_islast;
				if (fill_done) begin
					filled_w = '0;
					fsm_w[COMMIT] = 1'b1;
				end else begin
					filled_w = filled_nxt;
					fsm_w[RUN] = 1'b1;
				end
			end else begin
				fsm_w[RUN] = 1'b1;
			end
		end
		fsm_r[COMMIT]: begin
			if (done_linear_ack) begin
				fsm_w[FREE] = 1'b1;
			end else begin
				fsm_w[COMMIT] = 1'b1;
			end
		end
	endcase
end

always_comb begin
	buf_left = VSIZE-{1'b0,cur_r[CV_BW-1:0]};
	cmd_left = i_cmd_len - cmd_handled_r;
	cmd_eq_buf = cmd_left == buf_left;
	cmd_gt_buf = cmd_left > buf_left;
	cmd_ge_buf = cmd_eq_buf || cmd_gt_buf;
	cmd_le_buf = cmd_eq_buf || !cmd_gt_buf;
	advance_ptr = cmd_gt_buf ? buf_left : cmd_left;
	require_dram = i_cmd_islast || i_cmd_type != 'd2;
end

always_comb begin
	for (int i = 0; i < CSIZE; i++) begin
		data_1d[(i+1)*DBW-1 -: DBW] = i_dramrd[i];
	end
	if (VSIZE > CSIZE) begin
		data_1d_shiftr = data_1d >> (
			(i_cmd_addrofs+cmd_handled_r[CC_BW-1:0])*DBW
		);
		data_1d_shiftl = {READ_PAD_ZERO, data_1d_shiftr} << (cur_r[CV_BW-1:0]*DBW);
	end else begin
		data_1d_shiftr = data_1d >> (
			(i_cmd_addrofs+{CV_PAD_ZERO, cmd_handled_r})*DBW
		);
		data_1d_shiftl = data_1d_shiftr[VSIZE*DBW-1:0] << (cur_r[CV_BW-1:0]*DBW);
	end
	case (i_cmd_type)
		2'd0: for (int i = 0; i < VSIZE; i++) begin
			data_w[i] = data_1d_shiftl[(i+1)*DBW-1 -: DBW];
		end
		2'd1: for (int i = 0; i < VSIZE; i++) begin
			data_w[i] = data_1d_shiftr[DBW-1:0];
		end
		default: for (int i = 0; i < VSIZE; i++) begin
			data_w[i] = padv_r;
		end
	endcase
end

//======================================
// Sequential
//======================================
`ff_rst
	o_linear <= '0;
	o_id <= '0;
	size_r <= '0;
	padv_r <= '0;
`ff_cg(alloc_linear_ack)
	o_linear <= i_linear;
	o_id <= i_linear_id;
	size_r <= i_size;
	padv_r <= i_padv;
`ff_end

`ff_rst
	filled_r <= '0;
	cur_r <= '0;
	cmd_handled_r <= '0;
`ff_cg(alloc_linear_ack || enable_buf_write)
	filled_r <= filled_w;
	cur_r <= cur_w;
	cmd_handled_r <= cmd_handled_w;
`ff_end

`ff_rst
	o_hiaddr <= '0;
`ff_cg(enable_buf_write)
	o_hiaddr <= cur_r[LBW-1:CV_BW];
`ff_end

genvar gi;
generate for (gi = 0; gi < VSIZE; gi++) begin: linear_collect
always_ff @(posedge i_clk or negedge i_rst) begin
	if (!i_rst) begin
		o_data[gi] <= '0;
	end else if (enable_buf_write && wmask[gi]) begin
		o_data[gi] <= data_w[gi];
	end
end
end endgenerate

`ff_rst
	fsm_r <= 'b1 << FREE;
	w_dval <= 1'b0;
`ff_nocg
	fsm_r <= fsm_w;
	w_dval <= collected;
`ff_end

endmodule
