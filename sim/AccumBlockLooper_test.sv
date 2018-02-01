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
`include "AccumBlockLooper_include.sv"

module AccumBlockLooper_test;

logic i_clk, i_rst, da_canack, dm_canack;
`rdyack_logic(s);
`rdyack_logic(da);
`rdyack_logic(dm);
`Pos(rst_out, i_rst)
`PosIf(ck_ev, i_clk, i_rst)
`WithFinish

always #1 i_clk = ~i_clk;
initial begin
	$fsdbDumpfile("AccumBlockLooper.fsdb");
	$fsdbDumpvars(0, AccumBlockLooper_test, "+mda");
	i_clk = 0;
	i_rst = 1;
	#1 $NicotbInit();
	#11 i_rst = 0;
	#10 i_rst = 1;
	#10000 $display("Timeout");
	$NicotbFinal();
	$finish;
end

assign da_ack = da_rdy && da_canack;
assign dm_ack = dm_rdy && dm_canack;
AccumBlockLooper#(.SUM_ALL(`SA)) dut(
	`clk_connect,
	`rdyack_connect(src_bofs, s),
	`rdyack_connect(dst_abofs, da),
	`rdyack_connect(dst_mofs, dm)
);

endmodule
