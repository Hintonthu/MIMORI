// Copyright (C) 2017, Yu Sheng Lin, johnjohnlys@media.ee.ntu.edu.tw

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
`include "BlockMemoryLooper_include.sv"

module BlockMemoryLooper_test;

logic i_clk, i_rst, bofs_canack, i0_mofs_canack, i1_mofs_canack, o_mofs_canack;
`rdyack_logic(bofs);
`rdyack_logic(i0_mofs);
`rdyack_logic(i1_mofs);
`rdyack_logic(o_mofs);
`Pos(rst_out, i_rst)
`PosIf(ck_ev, i_clk, i_rst)
`WithFinish

always #1 i_clk = ~i_clk;
initial begin
	$fsdbDumpfile("BlockMemoryLooper.fsdb");
	$fsdbDumpvars(0, BlockMemoryLooper_test, "+mda");
	i_clk = 0;
	i_rst = 1;
	#1 $NicotbInit();
	#11 i_rst = 0;
	#10 i_rst = 1;
	#10000 $display("Timeout");
	$NicotbFinal();
	$finish;
end

assign bofs_ack = bofs_rdy && bofs_canack;
assign i0_mofs_ack = i0_mofs_rdy && i0_mofs_canack;
assign i1_mofs_ack = i1_mofs_rdy && i1_mofs_canack;
assign o_mofs_ack = o_mofs_rdy && o_mofs_canack;
BlockMemoryLooper dut(
	`clk_connect,
	`rdyack_connect(bofs, bofs),
	`rdyack_connect(i0_mofs, i0_mofs),
	`rdyack_connect(i1_mofs, i1_mofs),
	`rdyack_connect(o_mofs, o_mofs)
);

endmodule
