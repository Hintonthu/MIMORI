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

logic i_clk, i_rst, dst_i0_canack, dst_i1_canack, dst_dma_canack, dst_o_canack, dst_alu_canack;
`rdyack_logic(src);
`rdyack_logic(dst_i0);
`rdyack_logic(dst_i1);
`rdyack_logic(dst_dma);
`rdyack_logic(dst_o);
`rdyack_logic(dst_alu);
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

assign dst_i0_ack = dst_i0_rdy && dst_i0_canack;
assign dst_i1_ack = dst_i1_rdy && dst_i1_canack;
assign dst_dma_ack = dst_dma_rdy && dst_dma_canack;
assign dst_o_ack = dst_o_rdy && dst_o_canack;
assign dst_alu_ack = dst_alu_rdy && dst_alu_canack;
AccumBlockLooper dut(
	`clk_connect,
	`rdyack_connect(src, src),
	`rdyack_connect(i0_abofs, dst_i0),
	`rdyack_connect(i1_abofs, dst_i1),
	`rdyack_connect(dma_abofs, dst_dma),
	`rdyack_connect(o_abofs, dst_o),
	`rdyack_connect(alu_abofs, dst_alu)
);

endmodule
