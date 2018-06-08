// Copyright 2018 Yu Sheng Lin

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

`include "common/define.sv"
`include "common/TauCfg.sv"
`include "common/Controllers.sv"
`include "common/OffsetStage.sv"
`include "common/BitOperation.sv"

module ParallelBlockLooper_sd(
	`clk_port,
	`rdyack_port(src),
	i_bgrid_step,
	i_bgrid_end,
	i_bboundary,
	i_i0_systolic_axis,
	i_i1_systolic_axis,
	bofs_rdys,
	bofs_acks,
	o_bofss,
	// Ex: gsize = 4, idx = 1
	// Counter:            0123321001233210
	// Systolic hold data? 0100001001000010 (counter == idx)
	// (For now idx is constant)
	// TODO: We should use a more smart scheduler
	o_i0_systolic_gsize,
	o_i0_systolic_idx,
	o_i1_systolic_gsize,
	o_i1_systolic_idx,
	blkdone_dvals
);

//======================================
// Parameter
//======================================
localparam WBW = TauCfg::WORK_BW;
localparam VDIM = TauCfg::VDIM;
localparam VDIM_BW1 = $clog2(VDIM+1);
localparam N_ICFG = TauCfg::N_ICFG;
localparam N_PENDING = TauCfg::MAX_PENDING_BLOCK;
localparam N_TAU_X = TauCfg::N_TAU_X;
localparam N_TAU_Y = TauCfg::N_TAU_Y;
localparam N_TAU = N_TAU_X * N_TAU_Y;
// derived
localparam CN_TAU_X = $clog2(N_TAU_X);
localparam CN_TAU_Y = $clog2(N_TAU_Y);
localparam CN_TAU_X1 = $clog2(N_TAU_X+1);
localparam CN_TAU_Y1 = $clog2(N_TAU_Y+1);

//======================================
// I/O
//======================================
`clk_input;
`rdyack_input(src);
input [WBW-1:0]      i_bgrid_step [VDIM];
input [WBW-1:0]      i_bgrid_end  [VDIM];
input [WBW-1:0]      i_bboundary  [VDIM];
input [VDIM_BW1-1:0] i_i0_systolic_axis;
input [VDIM_BW1-1:0] i_i1_systolic_axis;
output logic             bofs_rdys     [N_TAU_X][N_TAU_Y];
input                    bofs_acks     [N_TAU_X][N_TAU_Y];
output logic [WBW-1:0]       o_bofss             [N_TAU_X][N_TAU_Y][VDIM];
output logic [CN_TAU_X1-1:0] o_i0_systolic_gsize [N_TAU_X][N_TAU_Y];
output logic [CN_TAU_Y -1:0] o_i0_systolic_idx   [N_TAU_X][N_TAU_Y];
output logic [CN_TAU_X1-1:0] o_i1_systolic_gsize [N_TAU_X][N_TAU_Y];
output logic [CN_TAU_Y -1:0] o_i1_systolic_idx   [N_TAU_X][N_TAU_Y];
input [N_TAU-1:0] blkdone_dvals;

//======================================
// Internal
//======================================
`rdyack_logic(s0_src);
`rdyack_logic(s0_dst);
`rdyack_logic(wait_fin);
logic [WBW-1:0]             s0_dst_bofs [VDIM];
logic [WBW-1:0]             s0_dst_bofss   [N_TAU_X][N_TAU_Y][VDIM];
logic [VDIM-1:0]            s0_valid_conds [N_TAU_X][N_TAU_Y];
logic                       s0_valid_cond  [N_TAU_X][N_TAU_Y];
logic [N_TAU_X-1:0]         s0_valid_condx; // again, x = i0, y = i1
logic [N_TAU_Y-1:0]         s0_valid_condy;
logic [N_TAU_X  :0]         s0_valid_condx1;
logic [N_TAU_Y  :0]         s0_valid_condy1;
logic [CN_TAU_X1-1:0]       s0_i0_systolic_gsize;
logic [CN_TAU_X1-1:0]       s0_i1_systolic_gsize;
logic                       s0_valid_rdys  [N_TAU_X][N_TAU_Y];
logic                       s0_valid_acks  [N_TAU_X][N_TAU_Y];
logic [N_TAU_X*N_TAU_Y-1:0] s0_dst_rdys;
logic [N_TAU_X*N_TAU_Y-1:0] s0_dst_acks;
logic s1_rdys [N_TAU_X][N_TAU_Y];
logic s1_acks [N_TAU_X][N_TAU_Y];
logic block_fulls   [N_TAU_X][N_TAU_Y];
logic block_emptys  [N_TAU_X][N_TAU_Y];
logic [N_TAU_X*N_TAU_Y-1:0] block_emptysxy;
logic [N_TAU_X*N_TAU_Y-1:0] bofs_rdysxy;

//======================================
// Combinational
//======================================
always_comb begin
	for (int i = 0; i < N_TAU_X; i++) begin
		for (int j = 0; j < N_TAU_Y; j++) begin
			block_emptysxy[i*N_TAU_Y+j] = block_emptys[i][j];
			bofs_rdysxy[i*N_TAU_Y+j] = bofs_rdys[i][j];
		end
	end
	wait_fin_ack = wait_fin_rdy && (&block_emptysxy) && !(|bofs_rdysxy);
end

always_comb begin
	for (int i = 0; i < N_TAU_X; i++) begin
		for (int j = 0; j < N_TAU_Y; j++) begin
			for (int k = 0; k < VDIM; k++) begin
				priority if (k == i_i0_systolic_axis) begin
					s0_dst_bofss[i][j][k] = s0_dst_bofs[k] * N_TAU_X + i * i_bgrid_step[k];
				end else if (k == i_i1_systolic_axis) begin
					s0_dst_bofss[i][j][k] = s0_dst_bofs[k] * N_TAU_Y + j * i_bgrid_step[k];
				end else begin
					s0_dst_bofss[i][j][k] = s0_dst_bofs[k];
				end
				s0_valid_conds[i][j][k] = s0_dst_bofss[i][j][k] < i_bboundary[k];
			end
			o_i0_systolic_idx[i][j] = i;
			o_i1_systolic_idx[i][j] = j;
			s0_valid_cond[i][j] = &s0_valid_conds[i][j];
		end
	end
end

always_comb begin
	// pack the signals
	for (int i = 0; i < N_TAU_X; i++) begin
		s0_valid_condx[i] = s0_valid_cond[i][0];
	end
	for (int i = 0; i < N_TAU_Y; i++) begin
		s0_valid_condy[i] = s0_valid_cond[0][i];
	end
	s0_valid_condx1 = {s0_valid_condx, 1'b1} & {1'b1, ~s0_valid_condx};
	s0_valid_condy1 = {s0_valid_condy, 1'b1} & {1'b1, ~s0_valid_condy};
end

//======================================
// Submodule
//======================================
BroadcastInorder#(2) u_brd(
	`clk_connect,
	`rdyack_connect(src, src),
	.dst_rdys({wait_fin_rdy, s0_src_rdy}),
	.dst_acks({wait_fin_ack, s0_src_ack})
);
OffsetStage#(.BW(WBW), .DIM(VDIM), .FROM_ZERO(1), .UNIT_STRIDE(0)) u_s0(
	`clk_connect,
	`rdyack_connect(src, s0_src),
	.i_ofs_beg(),
	.i_ofs_end(i_bgrid_end),
	.i_ofs_gend(),
	.i_stride(i_bgrid_step),
	`rdyack_connect(dst, s0_dst),
	.o_ofs(s0_dst_bofs),
	.o_lofs(),
	.o_sel_beg(),
	.o_sel_end(),
	.o_sel_ret(),
	.o_islast(),
	.init_dval()
);
Broadcast#(N_TAU_X*N_TAU_Y) u_brd_bofs(
	`clk_connect,
	`rdyack_connect(src, s0_dst),
	.acked(),
	.dst_rdys(s0_dst_rdys),
	.dst_acks(s0_dst_acks)
);
Onehot2Binary#(N_TAU_X+1) u_oh_x(s0_valid_condx1, s0_i0_systolic_gsize);
Onehot2Binary#(N_TAU_Y+1) u_oh_y(s0_valid_condy1, s0_i1_systolic_gsize);

genvar gi, gj;
generate for (gi = 0; gi < N_TAU_X; gi++) begin: ctrlx
	for (gj = 0; gj < N_TAU_Y; gj++) begin: ctrly
		IgnoreIf#(0) u_ign_invalid_block(
			.cond(s0_valid_cond[gi][gj]),
			.src_rdy(s0_dst_rdys[gi*N_TAU_Y+gj]),
			.src_ack(s0_dst_acks[gi*N_TAU_Y+gj]),
			.dst_rdy(s0_valid_rdys[gi][gj]),
			.dst_ack(s0_valid_acks[gi][gj]),
			.skipped()
		);
		Forward u_fwd(
			`clk_connect,
			.src_rdy(s0_valid_rdys[gi][gj]),
			.src_ack(s0_valid_acks[gi][gj]),
			.dst_rdy(s1_rdys[gi][gj]),
			.dst_ack(s1_acks[gi][gj])
		);
		ForwardIf#(0) u_fwd_if_not_full(
			.cond(block_fulls[gi][gj]),
			.src_rdy(s1_rdys[gi][gj]),
			.src_ack(s1_acks[gi][gj]),
			.dst_rdy(bofs_rdys[gi][gj]),
			.dst_ack(bofs_acks[gi][gj])
		);
		Semaphore#(N_PENDING) u_sem_done(
			`clk_connect,
			.i_inc(bofs_acks[gi][gj]),
			.i_dec(blkdone_dvals[gi*N_TAU_Y+gj]),
			.o_full(block_fulls[gi][gj]),
			.o_empty(block_emptys[gi][gj]),
			.o_will_full(),
			.o_will_empty(),
			.o_n()
		);
		`ff_rst
			for (int k = 0; k < VDIM; k++) begin
				o_bofss[gi][gj][k] <= '0;
			end
			o_i0_systolic_gsize[gi][gj] <= '0;
			o_i1_systolic_gsize[gi][gj] <= '0;
		`ff_cg(s0_valid_acks[gi][gj])
			o_bofss[gi][gj] <= s0_dst_bofss[gi][gj];
			o_i0_systolic_gsize[gi][gj] <= s0_i0_systolic_gsize;
			o_i1_systolic_gsize[gi][gj] <= s0_i1_systolic_gsize;
		`ff_end
	end
end endgenerate

endmodule
