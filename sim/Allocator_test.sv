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
`include "Allocator_include.sv"

module Allocator_test;

logic i_clk, i_rst, linear_canack;
`rdyack_logic(alloc);
`rdyack_logic(linear);
`Pos(rst_out, i_rst)
`PosIf(ck_ev, i_clk, i_rst)
`WithFinish

always #1 i_clk = ~i_clk;
initial begin
	$fsdbDumpfile("Allocator.fsdb");
	$fsdbDumpvars(0, Allocator_test, "+mda");
	i_clk = 0;
	i_rst = 1;
	#1 $NicotbInit();
	#11 i_rst = 0;
	#10 i_rst = 1;
	#10000 $display("Timeout");
	$NicotbFinal();
	$finish;
end

assign linear_ack = linear_rdy && linear_canack;
Allocator dut(
	`clk_connect,
	`rdyack_connect(alloc, alloc),
	`rdyack_connect(linear, linear)
);

endmodule
