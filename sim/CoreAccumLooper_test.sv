// Copyright (C) 2017, Yu Sheng Lin, johnjohnlys@media.ee.ntu.edu.tw

// This file is part of Ocean.

// MIMORI is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// MIMORI is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with Ocean.  If not, see <http://www.gnu.org/licenses/>.
`timescale 1ns/1ns
`include "CoreAccumLooper_include.sv"

module CoreAccumLooper_test;

logic i_clk, i_rst, i0_canack, i1_canack, alu_canack;
`rdyack_logic(i0);
`rdyack_logic(i1);
`rdyack_logic(alu);
`Pos(rst_out, i_rst)
`PosIf(ck_ev, i_clk, i_rst)
`WithFinish

always #1 i_clk = ~i_clk;
initial begin
	$fsdbDumpfile("CoreAccumLooper.fsdb");
	$fsdbDumpvars(0, CoreAccumLooper_test, "+mda");
	i_clk = 0;
	i_rst = 1;
	#1 $NicotbInit();
	#11 i_rst = 0;
	#10 i_rst = 1;
	#10000 $display("Timeout");
	$NicotbFinal();
	$finish;
end

assign i0_ack = i0_rdy && i0_canack;
assign i1_ack = i1_rdy && i1_canack;
assign alu_ack = alu_rdy && alu_canack;
CoreAccumLooper dut(
	`clk_connect,
	`rdyack_connect(i0_abofs, i0),
	`rdyack_connect(i1_abofs, i1),
	`rdyack_connect(alu_abofs, alu)
);

endmodule
