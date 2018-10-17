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

module ParallelBlockLooper_mc(
	`clk_port,
	`rdyack_port(src),
	i_bgrid_step,
	i_bgrid_end,
	bofs_rdys,
`ifdef VERI_TOP_ParallelBlockLooper_mc
	dst3_rdy,dst2_rdy,dst1_rdy,dst0_rdy,
	dst3_canack,dst2_canack,dst1_canack,dst0_canack,
	dst3_bofs,dst2_bofs,dst1_bofs,dst0_bofs,
	done3,done2,done1,done0,
`else
	bofs_acks,
`endif
	o_bofss,
`ifdef VERI_TOP_ParallelBlockLooper_mc
	done3,done2,done1,done0
`else
	blkdone_dvals
`endif
);
//======================================
// Parameter
//======================================
localparam WBW = TauCfg::WORK_BW;
localparam VDIM = TauCfg::VDIM;
localparam N_PENDING = TauCfg::MAX_PENDING_BLOCK;
localparam N_TAU = TauCfg::N_TAU;
localparam CN_TAU = $clog2(N_TAU);

//======================================
// I/O
//======================================
`clk_input;
`rdyack_input(src);
input [WBW-1:0] i_bgrid_step [VDIM];
input [WBW-1:0] i_bgrid_end  [VDIM];
output logic [N_TAU-1:0] bofs_rdys;
`ifdef VERI_TOP_ParallelBlockLooper_mc
logic        [N_TAU-1:0] bofs_acks;
`else
input        [N_TAU-1:0] bofs_acks;
`endif
output logic [WBW-1:0]   o_bofss [N_TAU][VDIM];
`ifdef VERI_TOP_ParallelBlockLooper_mc
logic [N_TAU-1:0] blkdone_dvals;
`else
input [N_TAU-1:0] blkdone_dvals;
`endif

`ifdef VERI_TOP_ParallelBlockLooper_mc
output logic dst3_rdy,dst2_rdy,dst1_rdy,dst0_rdy;
input logic dst3_canack,dst2_canack,dst1_canack,dst0_canack;
output logic [WBW-1:0] dst3_bofs[VDIM],dst2_bofs[VDIM],dst1_bofs[VDIM],dst0_bofs[VDIM];
input logic done3,done2,done1,done0;
assign {dst3_rdy,dst2_rdy,dst1_rdy,dst0_rdy} = bofs_rdys;
assign bofs_acks = {dst3_canack,dst2_canack,dst1_canack,dst0_canack} & bofs_rdys;
assign blkdone_dvals = {done3,done2,done1,done0};
always_comb for (int i = 0; i < VDIM; i++) begin
	dst3_bofs[i] = o_bofss[3][i];
	dst2_bofs[i] = o_bofss[2][i];
	dst1_bofs[i] = o_bofss[1][i];
	dst0_bofs[i] = o_bofss[0][i];
end
`endif

//======================================
// Internal
//======================================
`rdyack_logic(s0_src);
`rdyack_logic(s0_dst);
`rdyack_logic(wait_fin);
logic [N_TAU-1:0] s0_dst_rdys;
logic [N_TAU-1:0] s0_dst_acks;
logic [WBW-1:0]   s0_dst_bofs [VDIM];
logic [N_TAU-1:0] s1_rdys;
logic [N_TAU-1:0] s1_acks;
logic [CN_TAU-1:0] select_shamt_r;
logic [CN_TAU-1:0] select_shamt_w;
logic [  N_TAU-1:0] can_send;
logic [2*N_TAU-1:0] can_send_rot;
logic [  N_TAU  :0] select_send_rot;
logic [2*N_TAU-1:0] select_send;
logic [N_TAU-1:0] block_fulls;
logic [N_TAU-1:0] block_emptys;

//======================================
// Combinational
//======================================
assign wait_fin_ack = wait_fin_rdy && (&block_emptys) && !(|bofs_rdys);

always_comb begin
	if (select_shamt_r == N_TAU-1) begin
		select_shamt_w = '0;
	end else begin
		select_shamt_w = select_shamt_r + 'b1;
	end
end

always_comb begin
	// Use higher half
	can_send_rot = {2{can_send}} << select_shamt_r;
	// Use lower half
	select_send = {2{select_send_rot[N_TAU:1]}} >> select_shamt_r;
end

always_comb begin
	s0_dst_rdys = {N_TAU{s0_dst_rdy}} & select_send[N_TAU-1:0];
	s0_dst_ack = |s0_dst_acks;
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
FindFromMsb#(N_TAU,1) u_arbiter(
	.i(can_send_rot[2*N_TAU-1:N_TAU]),
	.prefix(),
	.detect(select_send_rot)
);
genvar i;
generate for (i = 0; i < N_TAU; i++) begin: ctrl
	assign can_send[i] = !s1_rdys[i];
	Forward u_fwd(
		`clk_connect,
		.src_rdy(s0_dst_rdys[i]),
		.src_ack(s0_dst_acks[i]),
		.dst_rdy(s1_rdys[i]),
		.dst_ack(s1_acks[i])
	);
	PauseIf#(1) u_pause_if_full(
		.cond(block_fulls[i]),
		.src_rdy(s1_rdys[i]),
		.src_ack(s1_acks[i]),
		.dst_rdy(bofs_rdys[i]),
		.dst_ack(bofs_acks[i])
	);
	Semaphore#(N_PENDING) u_sem_done(
		`clk_connect,
		.i_inc(bofs_acks[i]),
		.i_dec(blkdone_dvals[i]),
		.o_full(block_fulls[i]),
		.o_empty(block_emptys[i]),
		.o_will_full(),
		.o_will_empty(),
		.o_n()
	);
	`ff_rst
		for (int j = 0; j < VDIM; j++) begin
			o_bofss[i][j] <= '0;
		end
	`ff_cg(s0_dst_acks[i])
		o_bofss[i] <= s0_dst_bofs;
	`ff_end
end endgenerate

`ff_rst
	select_shamt_r <= '0;
`ff_cg(s0_dst_ack)
	select_shamt_r <= select_shamt_w;
`ff_end

endmodule
