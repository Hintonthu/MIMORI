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
// along with Ocean.  If not, see <http://www.gnu.org/licenses/>.
`timescale 1ns/1ns
`include "Top_include.sv"

module Top_test;

logic i_clk, i_rst;
logic ra_canack;
logic w_canack;
`rdyack_logic(cfg);
`rdyack_logic(w);
`rdyack_logic(ra);
`rdyack_logic(rd);
`Pos(rst_out, i_rst)
`PosIf(ck_ev, i_clk, i_rst)
`WithFinish

always #1 i_clk = ~i_clk;
initial begin
	$fsdbDumpfile("Top.fsdb");
	$fsdbDumpvars(5, Top_test.u_top, "+mda");
	i_clk = 0;
	i_rst = 1;
	rd_rdy = 0;
	#1 $NicotbInit();
	#11 i_rst = 0;
	#10 i_rst = 1;
	#1000000 $display("Timeout");
	$NicotbFinal();
	$finish;
end

assign ra_ack = ra_canack && ra_rdy;
assign w_ack = w_canack && w_rdy;
Top u_top(
	`clk_connect,
	`rdyack_connect(src, cfg),
	`rdyack_connect(dramra, ra),
	`rdyack_connect(dramrd, rd),
	`rdyack_connect(dramw, w)
);

endmodule
