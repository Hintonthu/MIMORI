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
`include "SFifo_include.sv"

`define IMPL IMPL_REG

module SFifo_test;

logic i_clk, i_rst, dst_canack;
`rdyack_logic(dst);
`Pos(rst_out, i_rst)
`PosIf(ck_ev, i_clk, i_rst)
`WithFinish

always #1 i_clk = ~i_clk;
initial begin
	$fsdbDumpfile("SFifo.fsdb");
	$fsdbDumpvars(0, SFifo_test, "+mda");
	i_clk = 0;
	i_rst = 1;
	#1 $NicotbInit();
	#11 i_rst = 0;
	#10 i_rst = 1;
	#20000 $display("Timeout");
	$NicotbFinal();
	$finish;
end

assign dst_ack = dst_rdy && dst_canack;
SFifo#(.`IMPL(1), .NDATA(16), .BW(16)) dut(
	`clk_connect,
	`rdyack_connect(dst, dst)
);

endmodule
