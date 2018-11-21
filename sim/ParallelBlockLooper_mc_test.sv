// Copyright (C) 2018, Yu Sheng Lin, johnjohnlys@media.ee.ntu.edu.tw

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
`timescale 1ns/1ns
`include "common/define.sv"
`include "ParallelBlockLooper_mc_include.sv"
import TauCfg::*;

module ParallelBlockLooper_mc_test;

logic i_clk, i_rst;
`rdyack_logic(bofs);
`Pos(rst_out, i_rst)
`PosIf(ck_ev, i_clk, i_rst)
`WithFinish

logic dst0_canack;
logic dst1_canack;
logic dst2_canack;
logic dst3_canack;
`rdyack_logic(dst0);
`rdyack_logic(dst1);
`rdyack_logic(dst2);
`rdyack_logic(dst3);
logic done0;
logic done1;
logic done2;
logic done3;
logic [WORK_BW-1:0] dst0_bofs [VDIM];
logic [WORK_BW-1:0] dst1_bofs [VDIM];
logic [WORK_BW-1:0] dst2_bofs [VDIM];
logic [WORK_BW-1:0] dst3_bofs [VDIM];
logic [WORK_BW-1:0] dst_bofss [4][VDIM];

always #1 i_clk = ~i_clk;
assign dst0_bofs = dst_bofss[0];
assign dst1_bofs = dst_bofss[1];
assign dst2_bofs = dst_bofss[2];
assign dst3_bofs = dst_bofss[3];
initial begin
	$fsdbDumpfile("ParallelBlockLooper_mc.fsdb");
	$fsdbDumpvars(0, ParallelBlockLooper_mc_test, "+mda");
	i_clk = 0;
	i_rst = 1;
	#1 `NicotbInit;
	#11 i_rst = 0;
	#10 i_rst = 1;
	#10000 $display("Timeout");
	`NicotbFinal;
	$finish;
end

assign dst3_ack = dst3_rdy && dst3_canack;
assign dst2_ack = dst2_rdy && dst2_canack;
assign dst1_ack = dst1_rdy && dst1_canack;
assign dst0_ack = dst0_rdy && dst0_canack;
ParallelBlockLooper_mc dut(
	`clk_connect,
	`rdyack_connect(src, bofs),
	.bofs_rdys({dst3_rdy,dst2_rdy,dst1_rdy,dst0_rdy}),
	.bofs_acks({dst3_ack,dst2_ack,dst1_ack,dst0_ack}),
	.o_bofss(dst_bofss),
	.blkdone_dvals({done3,done2,done1,done0})
);

endmodule
