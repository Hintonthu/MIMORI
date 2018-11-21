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
	typedef enum int {BEHAVIOUR, SYNOPSYS32, TSMC28} GenerateMode;
	typedef enum int {UNDEF, OLD, NEW} ConcurrentRW;
	parameter GenerateMode GEN_MODE = `SRAM_GEN_MODE;
	parameter ConcurrentRW CON_RW = `SRAM_CON_RW;
endpackage

module SRAMTwoPort(
	i_clk,
	i_rst,
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
input i_rst;
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

genvar gi;
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
		CannotInitializeSramModule u_wrong();
		initial ErrorSram;
	end
end else begin: fail
	CannotInitializeSramModule u_wrong();
	initial ErrorSram;
end endgenerate

endmodule

module SRAMOnePort(
	i_clk,
	i_rst,
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
input i_rst;
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

genvar gi;
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
end else if (SramCfg::GEN_MODE == SramCfg::TSMC28) begin: tsmc28
	if (BW == 16 && NDATA == 64) begin: syn_16x64
		TS1N28LPB64X16M4SR u_sram(
			.CLK(i_clk), .CEB(i_ce), .WEB(i_r0w1),
			.RSTB(i_rst), .SCLK(1'b0), .SDIN(), .SDOUT(),
			.A5(i_rwaddr[5]),.A4(i_rwaddr[4]),.A3(i_rwaddr[3]),.A2(i_rwaddr[2]),.A1(i_rwaddr[1]),.A0(i_rwaddr[0]),
			.D15(i_wdata[15]),.D14(i_wdata[14]),.D13(i_wdata[13]),.D12(i_wdata[12]),.D11(i_wdata[11]),.D10(i_wdata[10]),.D9(i_wdata[9]),.D8(i_wdata[8]),.D7(i_wdata[7]),.D6(i_wdata[6]),.D5(i_wdata[5]),.D4(i_wdata[4]),.D3(i_wdata[3]),.D2(i_wdata[2]),.D1(i_wdata[1]),.D0(i_wdata[0]),
			.Q15(o_rdata[15]),.Q14(o_rdata[14]),.Q13(o_rdata[13]),.Q12(o_rdata[12]),.Q11(o_rdata[11]),.Q10(o_rdata[10]),.Q9(o_rdata[9]),.Q8(o_rdata[8]),.Q7(o_rdata[7]),.Q6(o_rdata[6]),.Q5(o_rdata[5]),.Q4(o_rdata[4]),.Q3(o_rdata[3]),.Q2(o_rdata[2]),.Q1(o_rdata[1]),.Q0(o_rdata[0])
		);
	end else if (BW == 16 && NDATA == 128) begin: syn_16x128
		TS1N28LPB128X16M4SR u_sram(
			.CLK(i_clk), .CEB(i_ce), .WEB(i_r0w1),
			.RSTB(i_rst), .SCLK(1'b0), .SDIN(), .SDOUT(),
			.A6(i_rwaddr[6]),.A5(i_rwaddr[5]),.A4(i_rwaddr[4]),.A3(i_rwaddr[3]),.A2(i_rwaddr[2]),.A1(i_rwaddr[1]),.A0(i_rwaddr[0]),
			.D15(i_wdata[15]),.D14(i_wdata[14]),.D13(i_wdata[13]),.D12(i_wdata[12]),.D11(i_wdata[11]),.D10(i_wdata[10]),.D9(i_wdata[9]),.D8(i_wdata[8]),.D7(i_wdata[7]),.D6(i_wdata[6]),.D5(i_wdata[5]),.D4(i_wdata[4]),.D3(i_wdata[3]),.D2(i_wdata[2]),.D1(i_wdata[1]),.D0(i_wdata[0]),
			.Q15(o_rdata[15]),.Q14(o_rdata[14]),.Q13(o_rdata[13]),.Q12(o_rdata[12]),.Q11(o_rdata[11]),.Q10(o_rdata[10]),.Q9(o_rdata[9]),.Q8(o_rdata[8]),.Q7(o_rdata[7]),.Q6(o_rdata[6]),.Q5(o_rdata[5]),.Q4(o_rdata[4]),.Q3(o_rdata[3]),.Q2(o_rdata[2]),.Q1(o_rdata[1]),.Q0(o_rdata[0])
		);
	end else if (BW == 1280 && NDATA == 32) begin: syn_1280x32
		for (gi = 0; gi < 1152; gi += 144) begin: srams
			TS1N28LPB32X144M4SR u_sram(
				.CLK(i_clk), .CEB(i_ce), .WEB(i_r0w1),
				.RSTB(i_rst), .SCLK(1'b0), .SDIN(), .SDOUT(),
				.A4(i_rwaddr[4]),.A3(i_rwaddr[3]),.A2(i_rwaddr[2]),.A1(i_rwaddr[1]),.A0(i_rwaddr[0]),
				.D143(i_wdata[gi+143]),.D142(i_wdata[gi+142]),.D141(i_wdata[gi+141]),.D140(i_wdata[gi+140]),.D139(i_wdata[gi+139]),.D138(i_wdata[gi+138]),.D137(i_wdata[gi+137]),.D136(i_wdata[gi+136]),.D135(i_wdata[gi+135]),.D134(i_wdata[gi+134]),.D133(i_wdata[gi+133]),.D132(i_wdata[gi+132]),.D131(i_wdata[gi+131]),.D130(i_wdata[gi+130]),.D129(i_wdata[gi+129]),.D128(i_wdata[gi+128]),.D127(i_wdata[gi+127]),.D126(i_wdata[gi+126]),.D125(i_wdata[gi+125]),.D124(i_wdata[gi+124]),.D123(i_wdata[gi+123]),.D122(i_wdata[gi+122]),.D121(i_wdata[gi+121]),.D120(i_wdata[gi+120]),.D119(i_wdata[gi+119]),.D118(i_wdata[gi+118]),.D117(i_wdata[gi+117]),.D116(i_wdata[gi+116]),.D115(i_wdata[gi+115]),.D114(i_wdata[gi+114]),.D113(i_wdata[gi+113]),.D112(i_wdata[gi+112]),.D111(i_wdata[gi+111]),.D110(i_wdata[gi+110]),.D109(i_wdata[gi+109]),.D108(i_wdata[gi+108]),.D107(i_wdata[gi+107]),.D106(i_wdata[gi+106]),.D105(i_wdata[gi+105]),.D104(i_wdata[gi+104]),.D103(i_wdata[gi+103]),.D102(i_wdata[gi+102]),.D101(i_wdata[gi+101]),.D100(i_wdata[gi+100]),.D99(i_wdata[gi+99]),.D98(i_wdata[gi+98]),.D97(i_wdata[gi+97]),.D96(i_wdata[gi+96]),.D95(i_wdata[gi+95]),.D94(i_wdata[gi+94]),.D93(i_wdata[gi+93]),.D92(i_wdata[gi+92]),.D91(i_wdata[gi+91]),.D90(i_wdata[gi+90]),.D89(i_wdata[gi+89]),.D88(i_wdata[gi+88]),.D87(i_wdata[gi+87]),.D86(i_wdata[gi+86]),.D85(i_wdata[gi+85]),.D84(i_wdata[gi+84]),.D83(i_wdata[gi+83]),.D82(i_wdata[gi+82]),.D81(i_wdata[gi+81]),.D80(i_wdata[gi+80]),.D79(i_wdata[gi+79]),.D78(i_wdata[gi+78]),.D77(i_wdata[gi+77]),.D76(i_wdata[gi+76]),.D75(i_wdata[gi+75]),.D74(i_wdata[gi+74]),.D73(i_wdata[gi+73]),.D72(i_wdata[gi+72]),.D71(i_wdata[gi+71]),.D70(i_wdata[gi+70]),.D69(i_wdata[gi+69]),.D68(i_wdata[gi+68]),.D67(i_wdata[gi+67]),.D66(i_wdata[gi+66]),.D65(i_wdata[gi+65]),.D64(i_wdata[gi+64]),.D63(i_wdata[gi+63]),.D62(i_wdata[gi+62]),.D61(i_wdata[gi+61]),.D60(i_wdata[gi+60]),.D59(i_wdata[gi+59]),.D58(i_wdata[gi+58]),.D57(i_wdata[gi+57]),.D56(i_wdata[gi+56]),.D55(i_wdata[gi+55]),.D54(i_wdata[gi+54]),.D53(i_wdata[gi+53]),.D52(i_wdata[gi+52]),.D51(i_wdata[gi+51]),.D50(i_wdata[gi+50]),.D49(i_wdata[gi+49]),.D48(i_wdata[gi+48]),.D47(i_wdata[gi+47]),.D46(i_wdata[gi+46]),.D45(i_wdata[gi+45]),.D44(i_wdata[gi+44]),.D43(i_wdata[gi+43]),.D42(i_wdata[gi+42]),.D41(i_wdata[gi+41]),.D40(i_wdata[gi+40]),.D39(i_wdata[gi+39]),.D38(i_wdata[gi+38]),.D37(i_wdata[gi+37]),.D36(i_wdata[gi+36]),.D35(i_wdata[gi+35]),.D34(i_wdata[gi+34]),.D33(i_wdata[gi+33]),.D32(i_wdata[gi+32]),.D31(i_wdata[gi+31]),.D30(i_wdata[gi+30]),.D29(i_wdata[gi+29]),.D28(i_wdata[gi+28]),.D27(i_wdata[gi+27]),.D26(i_wdata[gi+26]),.D25(i_wdata[gi+25]),.D24(i_wdata[gi+24]),.D23(i_wdata[gi+23]),.D22(i_wdata[gi+22]),.D21(i_wdata[gi+21]),.D20(i_wdata[gi+20]),.D19(i_wdata[gi+19]),.D18(i_wdata[gi+18]),.D17(i_wdata[gi+17]),.D16(i_wdata[gi+16]),.D15(i_wdata[gi+15]),.D14(i_wdata[gi+14]),.D13(i_wdata[gi+13]),.D12(i_wdata[gi+12]),.D11(i_wdata[gi+11]),.D10(i_wdata[gi+10]),.D9(i_wdata[gi+9]),.D8(i_wdata[gi+8]),.D7(i_wdata[gi+7]),.D6(i_wdata[gi+6]),.D5(i_wdata[gi+5]),.D4(i_wdata[gi+4]),.D3(i_wdata[gi+3]),.D2(i_wdata[gi+2]),.D1(i_wdata[gi+1]),.D0(i_wdata[gi+0]),
				.Q143(o_rdata[gi+143]),.Q142(o_rdata[gi+142]),.Q141(o_rdata[gi+141]),.Q140(o_rdata[gi+140]),.Q139(o_rdata[gi+139]),.Q138(o_rdata[gi+138]),.Q137(o_rdata[gi+137]),.Q136(o_rdata[gi+136]),.Q135(o_rdata[gi+135]),.Q134(o_rdata[gi+134]),.Q133(o_rdata[gi+133]),.Q132(o_rdata[gi+132]),.Q131(o_rdata[gi+131]),.Q130(o_rdata[gi+130]),.Q129(o_rdata[gi+129]),.Q128(o_rdata[gi+128]),.Q127(o_rdata[gi+127]),.Q126(o_rdata[gi+126]),.Q125(o_rdata[gi+125]),.Q124(o_rdata[gi+124]),.Q123(o_rdata[gi+123]),.Q122(o_rdata[gi+122]),.Q121(o_rdata[gi+121]),.Q120(o_rdata[gi+120]),.Q119(o_rdata[gi+119]),.Q118(o_rdata[gi+118]),.Q117(o_rdata[gi+117]),.Q116(o_rdata[gi+116]),.Q115(o_rdata[gi+115]),.Q114(o_rdata[gi+114]),.Q113(o_rdata[gi+113]),.Q112(o_rdata[gi+112]),.Q111(o_rdata[gi+111]),.Q110(o_rdata[gi+110]),.Q109(o_rdata[gi+109]),.Q108(o_rdata[gi+108]),.Q107(o_rdata[gi+107]),.Q106(o_rdata[gi+106]),.Q105(o_rdata[gi+105]),.Q104(o_rdata[gi+104]),.Q103(o_rdata[gi+103]),.Q102(o_rdata[gi+102]),.Q101(o_rdata[gi+101]),.Q100(o_rdata[gi+100]),.Q99(o_rdata[gi+99]),.Q98(o_rdata[gi+98]),.Q97(o_rdata[gi+97]),.Q96(o_rdata[gi+96]),.Q95(o_rdata[gi+95]),.Q94(o_rdata[gi+94]),.Q93(o_rdata[gi+93]),.Q92(o_rdata[gi+92]),.Q91(o_rdata[gi+91]),.Q90(o_rdata[gi+90]),.Q89(o_rdata[gi+89]),.Q88(o_rdata[gi+88]),.Q87(o_rdata[gi+87]),.Q86(o_rdata[gi+86]),.Q85(o_rdata[gi+85]),.Q84(o_rdata[gi+84]),.Q83(o_rdata[gi+83]),.Q82(o_rdata[gi+82]),.Q81(o_rdata[gi+81]),.Q80(o_rdata[gi+80]),.Q79(o_rdata[gi+79]),.Q78(o_rdata[gi+78]),.Q77(o_rdata[gi+77]),.Q76(o_rdata[gi+76]),.Q75(o_rdata[gi+75]),.Q74(o_rdata[gi+74]),.Q73(o_rdata[gi+73]),.Q72(o_rdata[gi+72]),.Q71(o_rdata[gi+71]),.Q70(o_rdata[gi+70]),.Q69(o_rdata[gi+69]),.Q68(o_rdata[gi+68]),.Q67(o_rdata[gi+67]),.Q66(o_rdata[gi+66]),.Q65(o_rdata[gi+65]),.Q64(o_rdata[gi+64]),.Q63(o_rdata[gi+63]),.Q62(o_rdata[gi+62]),.Q61(o_rdata[gi+61]),.Q60(o_rdata[gi+60]),.Q59(o_rdata[gi+59]),.Q58(o_rdata[gi+58]),.Q57(o_rdata[gi+57]),.Q56(o_rdata[gi+56]),.Q55(o_rdata[gi+55]),.Q54(o_rdata[gi+54]),.Q53(o_rdata[gi+53]),.Q52(o_rdata[gi+52]),.Q51(o_rdata[gi+51]),.Q50(o_rdata[gi+50]),.Q49(o_rdata[gi+49]),.Q48(o_rdata[gi+48]),.Q47(o_rdata[gi+47]),.Q46(o_rdata[gi+46]),.Q45(o_rdata[gi+45]),.Q44(o_rdata[gi+44]),.Q43(o_rdata[gi+43]),.Q42(o_rdata[gi+42]),.Q41(o_rdata[gi+41]),.Q40(o_rdata[gi+40]),.Q39(o_rdata[gi+39]),.Q38(o_rdata[gi+38]),.Q37(o_rdata[gi+37]),.Q36(o_rdata[gi+36]),.Q35(o_rdata[gi+35]),.Q34(o_rdata[gi+34]),.Q33(o_rdata[gi+33]),.Q32(o_rdata[gi+32]),.Q31(o_rdata[gi+31]),.Q30(o_rdata[gi+30]),.Q29(o_rdata[gi+29]),.Q28(o_rdata[gi+28]),.Q27(o_rdata[gi+27]),.Q26(o_rdata[gi+26]),.Q25(o_rdata[gi+25]),.Q24(o_rdata[gi+24]),.Q23(o_rdata[gi+23]),.Q22(o_rdata[gi+22]),.Q21(o_rdata[gi+21]),.Q20(o_rdata[gi+20]),.Q19(o_rdata[gi+19]),.Q18(o_rdata[gi+18]),.Q17(o_rdata[gi+17]),.Q16(o_rdata[gi+16]),.Q15(o_rdata[gi+15]),.Q14(o_rdata[gi+14]),.Q13(o_rdata[gi+13]),.Q12(o_rdata[gi+12]),.Q11(o_rdata[gi+11]),.Q10(o_rdata[gi+10]),.Q9(o_rdata[gi+9]),.Q8(o_rdata[gi+8]),.Q7(o_rdata[gi+7]),.Q6(o_rdata[gi+6]),.Q5(o_rdata[gi+5]),.Q4(o_rdata[gi+4]),.Q3(o_rdata[gi+3]),.Q2(o_rdata[gi+2]),.Q1(o_rdata[gi+1]),.Q0(o_rdata[gi+0])
			);
		end
		TS1N28LPB32X128M4SR u_sram(
			.CLK(i_clk), .CEB(i_ce), .WEB(i_r0w1),
			.RSTB(i_rst), .SCLK(1'b0), .SDIN(), .SDOUT(),
			.A4(i_rwaddr[4]),.A3(i_rwaddr[3]),.A2(i_rwaddr[2]),.A1(i_rwaddr[1]),.A0(i_rwaddr[0]),
			.D127(i_wdata[1152+127]),.D126(i_wdata[1152+126]),.D125(i_wdata[1152+125]),.D124(i_wdata[1152+124]),.D123(i_wdata[1152+123]),.D122(i_wdata[1152+122]),.D121(i_wdata[1152+121]),.D120(i_wdata[1152+120]),.D119(i_wdata[1152+119]),.D118(i_wdata[1152+118]),.D117(i_wdata[1152+117]),.D116(i_wdata[1152+116]),.D115(i_wdata[1152+115]),.D114(i_wdata[1152+114]),.D113(i_wdata[1152+113]),.D112(i_wdata[1152+112]),.D111(i_wdata[1152+111]),.D110(i_wdata[1152+110]),.D109(i_wdata[1152+109]),.D108(i_wdata[1152+108]),.D107(i_wdata[1152+107]),.D106(i_wdata[1152+106]),.D105(i_wdata[1152+105]),.D104(i_wdata[1152+104]),.D103(i_wdata[1152+103]),.D102(i_wdata[1152+102]),.D101(i_wdata[1152+101]),.D100(i_wdata[1152+100]),.D99(i_wdata[1152+99]),.D98(i_wdata[1152+98]),.D97(i_wdata[1152+97]),.D96(i_wdata[1152+96]),.D95(i_wdata[1152+95]),.D94(i_wdata[1152+94]),.D93(i_wdata[1152+93]),.D92(i_wdata[1152+92]),.D91(i_wdata[1152+91]),.D90(i_wdata[1152+90]),.D89(i_wdata[1152+89]),.D88(i_wdata[1152+88]),.D87(i_wdata[1152+87]),.D86(i_wdata[1152+86]),.D85(i_wdata[1152+85]),.D84(i_wdata[1152+84]),.D83(i_wdata[1152+83]),.D82(i_wdata[1152+82]),.D81(i_wdata[1152+81]),.D80(i_wdata[1152+80]),.D79(i_wdata[1152+79]),.D78(i_wdata[1152+78]),.D77(i_wdata[1152+77]),.D76(i_wdata[1152+76]),.D75(i_wdata[1152+75]),.D74(i_wdata[1152+74]),.D73(i_wdata[1152+73]),.D72(i_wdata[1152+72]),.D71(i_wdata[1152+71]),.D70(i_wdata[1152+70]),.D69(i_wdata[1152+69]),.D68(i_wdata[1152+68]),.D67(i_wdata[1152+67]),.D66(i_wdata[1152+66]),.D65(i_wdata[1152+65]),.D64(i_wdata[1152+64]),.D63(i_wdata[1152+63]),.D62(i_wdata[1152+62]),.D61(i_wdata[1152+61]),.D60(i_wdata[1152+60]),.D59(i_wdata[1152+59]),.D58(i_wdata[1152+58]),.D57(i_wdata[1152+57]),.D56(i_wdata[1152+56]),.D55(i_wdata[1152+55]),.D54(i_wdata[1152+54]),.D53(i_wdata[1152+53]),.D52(i_wdata[1152+52]),.D51(i_wdata[1152+51]),.D50(i_wdata[1152+50]),.D49(i_wdata[1152+49]),.D48(i_wdata[1152+48]),.D47(i_wdata[1152+47]),.D46(i_wdata[1152+46]),.D45(i_wdata[1152+45]),.D44(i_wdata[1152+44]),.D43(i_wdata[1152+43]),.D42(i_wdata[1152+42]),.D41(i_wdata[1152+41]),.D40(i_wdata[1152+40]),.D39(i_wdata[1152+39]),.D38(i_wdata[1152+38]),.D37(i_wdata[1152+37]),.D36(i_wdata[1152+36]),.D35(i_wdata[1152+35]),.D34(i_wdata[1152+34]),.D33(i_wdata[1152+33]),.D32(i_wdata[1152+32]),.D31(i_wdata[1152+31]),.D30(i_wdata[1152+30]),.D29(i_wdata[1152+29]),.D28(i_wdata[1152+28]),.D27(i_wdata[1152+27]),.D26(i_wdata[1152+26]),.D25(i_wdata[1152+25]),.D24(i_wdata[1152+24]),.D23(i_wdata[1152+23]),.D22(i_wdata[1152+22]),.D21(i_wdata[1152+21]),.D20(i_wdata[1152+20]),.D19(i_wdata[1152+19]),.D18(i_wdata[1152+18]),.D17(i_wdata[1152+17]),.D16(i_wdata[1152+16]),.D15(i_wdata[1152+15]),.D14(i_wdata[1152+14]),.D13(i_wdata[1152+13]),.D12(i_wdata[1152+12]),.D11(i_wdata[1152+11]),.D10(i_wdata[1152+10]),.D9(i_wdata[1152+9]),.D8(i_wdata[1152+8]),.D7(i_wdata[1152+7]),.D6(i_wdata[1152+6]),.D5(i_wdata[1152+5]),.D4(i_wdata[1152+4]),.D3(i_wdata[1152+3]),.D2(i_wdata[1152+2]),.D1(i_wdata[1152+1]),.D0(i_wdata[1152+0]),
			.Q127(o_rdata[1152+127]),.Q126(o_rdata[1152+126]),.Q125(o_rdata[1152+125]),.Q124(o_rdata[1152+124]),.Q123(o_rdata[1152+123]),.Q122(o_rdata[1152+122]),.Q121(o_rdata[1152+121]),.Q120(o_rdata[1152+120]),.Q119(o_rdata[1152+119]),.Q118(o_rdata[1152+118]),.Q117(o_rdata[1152+117]),.Q116(o_rdata[1152+116]),.Q115(o_rdata[1152+115]),.Q114(o_rdata[1152+114]),.Q113(o_rdata[1152+113]),.Q112(o_rdata[1152+112]),.Q111(o_rdata[1152+111]),.Q110(o_rdata[1152+110]),.Q109(o_rdata[1152+109]),.Q108(o_rdata[1152+108]),.Q107(o_rdata[1152+107]),.Q106(o_rdata[1152+106]),.Q105(o_rdata[1152+105]),.Q104(o_rdata[1152+104]),.Q103(o_rdata[1152+103]),.Q102(o_rdata[1152+102]),.Q101(o_rdata[1152+101]),.Q100(o_rdata[1152+100]),.Q99(o_rdata[1152+99]),.Q98(o_rdata[1152+98]),.Q97(o_rdata[1152+97]),.Q96(o_rdata[1152+96]),.Q95(o_rdata[1152+95]),.Q94(o_rdata[1152+94]),.Q93(o_rdata[1152+93]),.Q92(o_rdata[1152+92]),.Q91(o_rdata[1152+91]),.Q90(o_rdata[1152+90]),.Q89(o_rdata[1152+89]),.Q88(o_rdata[1152+88]),.Q87(o_rdata[1152+87]),.Q86(o_rdata[1152+86]),.Q85(o_rdata[1152+85]),.Q84(o_rdata[1152+84]),.Q83(o_rdata[1152+83]),.Q82(o_rdata[1152+82]),.Q81(o_rdata[1152+81]),.Q80(o_rdata[1152+80]),.Q79(o_rdata[1152+79]),.Q78(o_rdata[1152+78]),.Q77(o_rdata[1152+77]),.Q76(o_rdata[1152+76]),.Q75(o_rdata[1152+75]),.Q74(o_rdata[1152+74]),.Q73(o_rdata[1152+73]),.Q72(o_rdata[1152+72]),.Q71(o_rdata[1152+71]),.Q70(o_rdata[1152+70]),.Q69(o_rdata[1152+69]),.Q68(o_rdata[1152+68]),.Q67(o_rdata[1152+67]),.Q66(o_rdata[1152+66]),.Q65(o_rdata[1152+65]),.Q64(o_rdata[1152+64]),.Q63(o_rdata[1152+63]),.Q62(o_rdata[1152+62]),.Q61(o_rdata[1152+61]),.Q60(o_rdata[1152+60]),.Q59(o_rdata[1152+59]),.Q58(o_rdata[1152+58]),.Q57(o_rdata[1152+57]),.Q56(o_rdata[1152+56]),.Q55(o_rdata[1152+55]),.Q54(o_rdata[1152+54]),.Q53(o_rdata[1152+53]),.Q52(o_rdata[1152+52]),.Q51(o_rdata[1152+51]),.Q50(o_rdata[1152+50]),.Q49(o_rdata[1152+49]),.Q48(o_rdata[1152+48]),.Q47(o_rdata[1152+47]),.Q46(o_rdata[1152+46]),.Q45(o_rdata[1152+45]),.Q44(o_rdata[1152+44]),.Q43(o_rdata[1152+43]),.Q42(o_rdata[1152+42]),.Q41(o_rdata[1152+41]),.Q40(o_rdata[1152+40]),.Q39(o_rdata[1152+39]),.Q38(o_rdata[1152+38]),.Q37(o_rdata[1152+37]),.Q36(o_rdata[1152+36]),.Q35(o_rdata[1152+35]),.Q34(o_rdata[1152+34]),.Q33(o_rdata[1152+33]),.Q32(o_rdata[1152+32]),.Q31(o_rdata[1152+31]),.Q30(o_rdata[1152+30]),.Q29(o_rdata[1152+29]),.Q28(o_rdata[1152+28]),.Q27(o_rdata[1152+27]),.Q26(o_rdata[1152+26]),.Q25(o_rdata[1152+25]),.Q24(o_rdata[1152+24]),.Q23(o_rdata[1152+23]),.Q22(o_rdata[1152+22]),.Q21(o_rdata[1152+21]),.Q20(o_rdata[1152+20]),.Q19(o_rdata[1152+19]),.Q18(o_rdata[1152+18]),.Q17(o_rdata[1152+17]),.Q16(o_rdata[1152+16]),.Q15(o_rdata[1152+15]),.Q14(o_rdata[1152+14]),.Q13(o_rdata[1152+13]),.Q12(o_rdata[1152+12]),.Q11(o_rdata[1152+11]),.Q10(o_rdata[1152+10]),.Q9(o_rdata[1152+9]),.Q8(o_rdata[1152+8]),.Q7(o_rdata[1152+7]),.Q6(o_rdata[1152+6]),.Q5(o_rdata[1152+5]),.Q4(o_rdata[1152+4]),.Q3(o_rdata[1152+3]),.Q2(o_rdata[1152+2]),.Q1(o_rdata[1152+1]),.Q0(o_rdata[1152+0])
		);
	end else begin: syn_fail
		CannotInitializeSramModule u_wrong();
		initial ErrorSram;
	end
end else begin: fail
	CannotInitializeSramModule u_wrong();
	initial ErrorSram;
end endgenerate

endmodule
`endif
