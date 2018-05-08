`ifndef __SRAM__
`define __SRAM__
// Copyright 2016-2018 Yu Sheng Lin

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

`ifndef SRAM_GEN_MODE
`define SRAM_GEN_MODE BEHAVIOUR
`endif
`ifndef SRAM_CON_RW
`define SRAM_CON_RW UNDEF
`endif
package SramCfg;
	typedef enum int {BEHAVIOUR, SYNOPSYS32} GenerateMode;
	typedef enum int {UNDEF, OLD, NEW} ConcurrentRW;
	parameter GenerateMode GEN_MODE = `SRAM_GEN_MODE;
	parameter ConcurrentRW CON_RW = `SRAM_CON_RW;
endpackage

module SRAMTwoPort(
	i_clk,
	i_we,
	i_re,
	i_waddr,
	i_wdata,
	i_raddr,
	o_rdata
);

parameter BW = 8;
parameter NDATA = 16;
localparam CLOG2_NDATA = $clog2(NDATA);

input i_clk;
input i_we;
input i_re;
input        [CLOG2_NDATA-1:0] i_waddr;
input        [BW-1:0]          i_wdata;
input        [CLOG2_NDATA-1:0] i_raddr;
output logic [BW-1:0]          o_rdata;

task ErrorSram;
begin
	$display("SRAM configuration (%d, %dx%db) wrong!", SramCfg::GEN_MODE, NDATA, BW);
	$finish();
end
endtask

generate if (SramCfg::GEN_MODE == SramCfg::BEHAVIOUR) begin: sim_mode
	logic [BW-1:0] data_r [NDATA];
	always @(posedge i_clk) begin
		if (i_we) begin
			data_r[i_waddr] <= i_wdata;
		end
		if (i_re) begin
			if (!i_we || i_waddr != i_raddr) begin
				o_rdata <= data_r[i_raddr];
			end else begin
				case (SramCfg::CON_RW)
					SramCfg::UNDEF: begin o_rdata <= 'x; end
					SramCfg::OLD:   begin o_rdata <= data_r[i_raddr]; end
					SramCfg::NEW:   begin o_rdata <= i_wdata; end
				endcase
			end
		end
	end
end else if (SramCfg::GEN_MODE == SramCfg::SYNOPSYS32) begin: synopsys32
	// A1,A2,CE1,CE2,WEB1,WEB2,OEB1,OEB2,CSB1,CSB2,I1,I2,O1,O2
	// 1 for R, 2 for W
	logic i_we_inv, i_re_inv;
	assign i_we_inv = ~i_we;
	assign i_re_inv = ~i_re;
	if (BW == 16 && NDATA == 32) begin: syn_16x32
		SRAM2RW32x16 s00(.A1(i_raddr),.A2(i_waddr),.CE1(i_clk),.CE2(i_clk),.WEB1(1'b1),.WEB2(1'b0),.OEB1(1'b0),.OEB2(1'b1),.CSB1(i_re_inv),.CSB2(i_we_inv),.I1(),.I2(i_wdata),.O1(o_rdata),.O2());
	end else if (BW == 16 && NDATA == 64) begin: syn_16x64
		SRAM2RW64x16 s00(.A1(i_raddr),.A2(i_waddr),.CE1(i_clk),.CE2(i_clk),.WEB1(1'b1),.WEB2(1'b0),.OEB1(1'b0),.OEB2(1'b1),.CSB1(i_re_inv),.CSB2(i_we_inv),.I1(),.I2(i_wdata),.O1(o_rdata),.O2());
	end else if (BW == 640 && NDATA == 64) begin: syn_512x64
		SRAM2RW64x32 s00(.A1(i_raddr),.A2(i_waddr),.CE1(i_clk),.CE2(i_clk),.WEB1(1'b1),.WEB2(1'b0),.OEB1(1'b0),.OEB2(1'b1),.CSB1(i_re_inv),.CSB2(i_we_inv),.I1(),.I2(i_wdata[ 31:  0]),.O1(o_rdata[ 31:  0]),.O2());
		SRAM2RW64x32 s01(.A1(i_raddr),.A2(i_waddr),.CE1(i_clk),.CE2(i_clk),.WEB1(1'b1),.WEB2(1'b0),.OEB1(1'b0),.OEB2(1'b1),.CSB1(i_re_inv),.CSB2(i_we_inv),.I1(),.I2(i_wdata[ 63: 32]),.O1(o_rdata[ 63: 32]),.O2());
		SRAM2RW64x32 s02(.A1(i_raddr),.A2(i_waddr),.CE1(i_clk),.CE2(i_clk),.WEB1(1'b1),.WEB2(1'b0),.OEB1(1'b0),.OEB2(1'b1),.CSB1(i_re_inv),.CSB2(i_we_inv),.I1(),.I2(i_wdata[ 95: 64]),.O1(o_rdata[ 95: 64]),.O2());
		SRAM2RW64x32 s03(.A1(i_raddr),.A2(i_waddr),.CE1(i_clk),.CE2(i_clk),.WEB1(1'b1),.WEB2(1'b0),.OEB1(1'b0),.OEB2(1'b1),.CSB1(i_re_inv),.CSB2(i_we_inv),.I1(),.I2(i_wdata[127: 96]),.O1(o_rdata[127: 96]),.O2());
		SRAM2RW64x32 s04(.A1(i_raddr),.A2(i_waddr),.CE1(i_clk),.CE2(i_clk),.WEB1(1'b1),.WEB2(1'b0),.OEB1(1'b0),.OEB2(1'b1),.CSB1(i_re_inv),.CSB2(i_we_inv),.I1(),.I2(i_wdata[159:128]),.O1(o_rdata[159:128]),.O2());
		SRAM2RW64x32 s05(.A1(i_raddr),.A2(i_waddr),.CE1(i_clk),.CE2(i_clk),.WEB1(1'b1),.WEB2(1'b0),.OEB1(1'b0),.OEB2(1'b1),.CSB1(i_re_inv),.CSB2(i_we_inv),.I1(),.I2(i_wdata[191:160]),.O1(o_rdata[191:160]),.O2());
		SRAM2RW64x32 s06(.A1(i_raddr),.A2(i_waddr),.CE1(i_clk),.CE2(i_clk),.WEB1(1'b1),.WEB2(1'b0),.OEB1(1'b0),.OEB2(1'b1),.CSB1(i_re_inv),.CSB2(i_we_inv),.I1(),.I2(i_wdata[223:192]),.O1(o_rdata[223:192]),.O2());
		SRAM2RW64x32 s07(.A1(i_raddr),.A2(i_waddr),.CE1(i_clk),.CE2(i_clk),.WEB1(1'b1),.WEB2(1'b0),.OEB1(1'b0),.OEB2(1'b1),.CSB1(i_re_inv),.CSB2(i_we_inv),.I1(),.I2(i_wdata[255:224]),.O1(o_rdata[255:224]),.O2());
		SRAM2RW64x32 s08(.A1(i_raddr),.A2(i_waddr),.CE1(i_clk),.CE2(i_clk),.WEB1(1'b1),.WEB2(1'b0),.OEB1(1'b0),.OEB2(1'b1),.CSB1(i_re_inv),.CSB2(i_we_inv),.I1(),.I2(i_wdata[287:256]),.O1(o_rdata[287:256]),.O2());
		SRAM2RW64x32 s09(.A1(i_raddr),.A2(i_waddr),.CE1(i_clk),.CE2(i_clk),.WEB1(1'b1),.WEB2(1'b0),.OEB1(1'b0),.OEB2(1'b1),.CSB1(i_re_inv),.CSB2(i_we_inv),.I1(),.I2(i_wdata[319:288]),.O1(o_rdata[319:288]),.O2());
		SRAM2RW64x32 s10(.A1(i_raddr),.A2(i_waddr),.CE1(i_clk),.CE2(i_clk),.WEB1(1'b1),.WEB2(1'b0),.OEB1(1'b0),.OEB2(1'b1),.CSB1(i_re_inv),.CSB2(i_we_inv),.I1(),.I2(i_wdata[351:320]),.O1(o_rdata[351:320]),.O2());
		SRAM2RW64x32 s11(.A1(i_raddr),.A2(i_waddr),.CE1(i_clk),.CE2(i_clk),.WEB1(1'b1),.WEB2(1'b0),.OEB1(1'b0),.OEB2(1'b1),.CSB1(i_re_inv),.CSB2(i_we_inv),.I1(),.I2(i_wdata[383:352]),.O1(o_rdata[383:352]),.O2());
		SRAM2RW64x32 s12(.A1(i_raddr),.A2(i_waddr),.CE1(i_clk),.CE2(i_clk),.WEB1(1'b1),.WEB2(1'b0),.OEB1(1'b0),.OEB2(1'b1),.CSB1(i_re_inv),.CSB2(i_we_inv),.I1(),.I2(i_wdata[415:384]),.O1(o_rdata[415:384]),.O2());
		SRAM2RW64x32 s13(.A1(i_raddr),.A2(i_waddr),.CE1(i_clk),.CE2(i_clk),.WEB1(1'b1),.WEB2(1'b0),.OEB1(1'b0),.OEB2(1'b1),.CSB1(i_re_inv),.CSB2(i_we_inv),.I1(),.I2(i_wdata[447:416]),.O1(o_rdata[447:416]),.O2());
		SRAM2RW64x32 s14(.A1(i_raddr),.A2(i_waddr),.CE1(i_clk),.CE2(i_clk),.WEB1(1'b1),.WEB2(1'b0),.OEB1(1'b0),.OEB2(1'b1),.CSB1(i_re_inv),.CSB2(i_we_inv),.I1(),.I2(i_wdata[479:448]),.O1(o_rdata[479:448]),.O2());
		SRAM2RW64x32 s15(.A1(i_raddr),.A2(i_waddr),.CE1(i_clk),.CE2(i_clk),.WEB1(1'b1),.WEB2(1'b0),.OEB1(1'b0),.OEB2(1'b1),.CSB1(i_re_inv),.CSB2(i_we_inv),.I1(),.I2(i_wdata[511:480]),.O1(o_rdata[511:480]),.O2());
		SRAM2RW64x32 s16(.A1(i_raddr),.A2(i_waddr),.CE1(i_clk),.CE2(i_clk),.WEB1(1'b1),.WEB2(1'b0),.OEB1(1'b0),.OEB2(1'b1),.CSB1(i_re_inv),.CSB2(i_we_inv),.I1(),.I2(i_wdata[543:512]),.O1(o_rdata[543:512]),.O2());
		SRAM2RW64x32 s17(.A1(i_raddr),.A2(i_waddr),.CE1(i_clk),.CE2(i_clk),.WEB1(1'b1),.WEB2(1'b0),.OEB1(1'b0),.OEB2(1'b1),.CSB1(i_re_inv),.CSB2(i_we_inv),.I1(),.I2(i_wdata[575:544]),.O1(o_rdata[575:544]),.O2());
		SRAM2RW64x32 s18(.A1(i_raddr),.A2(i_waddr),.CE1(i_clk),.CE2(i_clk),.WEB1(1'b1),.WEB2(1'b0),.OEB1(1'b0),.OEB2(1'b1),.CSB1(i_re_inv),.CSB2(i_we_inv),.I1(),.I2(i_wdata[607:576]),.O1(o_rdata[607:576]),.O2());
		SRAM2RW64x32 s19(.A1(i_raddr),.A2(i_waddr),.CE1(i_clk),.CE2(i_clk),.WEB1(1'b1),.WEB2(1'b0),.OEB1(1'b0),.OEB2(1'b1),.CSB1(i_re_inv),.CSB2(i_we_inv),.I1(),.I2(i_wdata[639:608]),.O1(o_rdata[639:608]),.O2());
	end else begin: syn_fail
		initial ErrorSram;
	end
end else begin: fail
	initial ErrorSram;
end endgenerate

endmodule

module SRAMOnePort(
	i_clk,
	i_ce,
	i_r0w1, // r = 0, w = 1
	i_rwaddr,
	i_wdata,
	o_rdata
);

parameter BW = 8;
parameter NDATA = 16;
localparam CLOG2_NDATA = $clog2(NDATA);

input i_clk;
input i_ce;
input i_r0w1;
input        [CLOG2_NDATA-1:0] i_rwaddr;
input        [BW-1:0]          i_wdata;
output logic [BW-1:0]          o_rdata;

task ErrorSram;
begin
	$display("SRAM configuration (%d, %dx%db) wrong!", SramCfg::GEN_MODE, NDATA, BW);
	$finish();
end
endtask

generate if (SramCfg::GEN_MODE == SramCfg::BEHAVIOUR) begin: sim_mode
	logic [BW-1:0] data_r [NDATA];
	always @(posedge i_clk) begin
		if (i_ce) begin
			if (i_r0w1) begin
				data_r[i_rwaddr] <= i_wdata;
			end else begin
				o_rdata <= data_r[i_rwaddr];
			end
		end
	end
end else begin: fail
	initial ErrorSram;
end endgenerate

endmodule
`endif
