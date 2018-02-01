// Copyright 2016 Yu Sheng Lin

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

import TauCfg::*;

module Alu(
	`clk_port,
	`rdyack_port(op),
	i_bsubofs,
	i_bsub_lo_order,
	i_const_texs,
	i_opcode,
	i_shamt,
	i_bofs,
	i_aofs,
	i_const_a,
	i_const_b,
	i_const_c,
	i_a,
	i_b,
	i_c,
	i_to_reg,
	i_to_dram,
	i_to_temp,
	i_reg_waddr,
	i_rdata,
	i_tbuf_rdatas,
	`dval_port(reg_we),
	o_reg_waddr,
	o_wdata,
	`dval_port(tbuf_we),
	o_tbuf_wdata,
	`rdyack_port(sramrd0),
	i_sramrd0,
	`rdyack_port(sramrd1),
	i_sramrd1,
	`rdyack_port(dramwd),
	o_dramwd,
	`dval_port(inst_commit)
);

//======================================
// Parameter
//======================================
localparam WBW = TauCfg::WORK_BW;
localparam DIM = TauCfg::DIM;
localparam ISA_BW = TauCfg::ISA_BW;
localparam DBW = TauCfg::DATA_BW;
localparam TDBW = TauCfg::TMP_DATA_BW;
localparam VSIZE = TauCfg::VECTOR_SIZE;
localparam NWORD = TauCfg::SRAM_NWORD;
localparam MAX_WARP = TauCfg::MAX_WARP;
localparam REG_ADDR = TauCfg::WARP_REG_ADDR_SPACE;
localparam CONST_LUT = TauCfg::CONST_LUT;
localparam CONST_TEX_LUT = TauCfg::CONST_TEX_LUT;
localparam TBUF_SIZE = TauCfg::ALU_DELAY_BUF_SIZE;
// derived
localparam REG_ABW = $clog2(REG_ADDR);
localparam SRAM_ABW = $clog2(NWORD);
localparam FLAT_BW = TDBW*VSIZE;
localparam CV_BW = $clog2(VSIZE);
localparam CCV_BW = $clog2(CV_BW+1);
typedef logic signed [TDBW-1:0] ResultType [VSIZE];

//======================================
// I/O
//======================================
`clk_input;
`rdyack_input(op);
input [CV_BW-1:0]    i_bsubofs [VSIZE][DIM];
input [CCV_BW-1:0]   i_bsub_lo_order  [DIM];
input [TDBW-1:0]     i_const_texs [CONST_TEX_LUT];
input [2:0]          i_opcode;
input [4:0]          i_shamt;
input [WBW-1:0]      i_bofs [DIM];
input [WBW-1:0]      i_aofs [DIM];
input [TDBW-1:0]     i_const_a;
input [TDBW-1:0]     i_const_b;
input [TDBW-1:0]     i_const_c;
input [2:0]          i_a;
input [2:0]          i_b;
input [2:0]          i_c;
input                i_to_reg;
input [1:0]          i_to_dram;
input                i_to_temp;
input [SRAM_ABW-1:0] i_reg_waddr;
input [TDBW-1:0]     i_rdata [VSIZE];
input [TDBW-1:0]     i_tbuf_rdatas [TBUF_SIZE][VSIZE];
`dval_output(reg_we);
output logic [SRAM_ABW-1:0] o_reg_waddr;
output logic [TDBW-1:0]     o_wdata [VSIZE];
`dval_output(tbuf_we);
output logic [TDBW-1:0]     o_tbuf_wdata [VSIZE];
`rdyack_input(sramrd0);
input [DBW-1:0] i_sramrd0 [VSIZE];
`rdyack_input(sramrd1);
input [DBW-1:0] i_sramrd1 [VSIZE];
`rdyack_output(dramwd);
output [DBW-1:0] o_dramwd [VSIZE];
`dval_output(inst_commit);

//======================================
// Internal
//======================================
logic to_dram;
logic data_ready;
logic req_rd0_a;
logic req_rd0_b;
logic req_rd0_c;
logic req_rd0;
logic req_rd1_a;
logic req_rd1_b;
logic req_rd1_c;
logic req_rd1;
logic signed [TDBW-1:0] sel_a [VSIZE];
logic signed [TDBW-1:0] sel_b [VSIZE];
logic signed [TDBW-1:0] sel_c [VSIZE];
logic signed [TDBW-1:0] result [VSIZE];
logic [WBW-1:0] bofsz [DIM];
logic [WBW-1:0] vector_blockofs [VSIZE][DIM];

//======================================
// Combinational
//======================================
assign inst_commit_dval = op_ack;
assign to_dram = i_to_dram != 2'b11;
assign o_reg_waddr = i_reg_waddr;
always_comb begin
	req_rd0_a = i_a == 'd2;
	req_rd0_b = i_b == 'd2;
	req_rd0_c = i_c == 'd2;
	req_rd1_a = i_a == 'd3;
	req_rd1_b = i_b == 'd3;
	req_rd1_c = i_c == 'd3;
	req_rd0 = req_rd0_a || req_rd0_b || req_rd0_c;
	req_rd1 = req_rd1_a || req_rd1_b || req_rd1_c;
	data_ready = op_rdy && !(req_rd0 && !sramrd0_rdy) && !(req_rd1 && !sramrd1_rdy);
	dramwd_rdy = data_ready && to_dram;
	op_ack = dramwd_ack || data_ready && !to_dram;
	reg_we_dval = op_ack && i_to_reg;
	tbuf_we_dval = op_ack && i_to_temp;
	sramrd0_ack = op_ack && req_rd0 && sramrd0_rdy;
	sramrd1_ack = op_ack && req_rd1 && sramrd1_rdy;
end

function ResultType SelectOp;
	input [2:0]      idx;
	input [TDBW-1:0] const_value;
	input [TDBW-1:0] rdata [VSIZE];
	input [DBW-1:0]  srd0 [VSIZE];
	input [DBW-1:0]  srd1 [VSIZE];
	input [TDBW-1:0] tbuf [TBUF_SIZE][VSIZE];
	priority case (idx)
		3'd0: for (int i = 0; i < VSIZE; i++) begin
			SelectOp[i] = const_value;
		end
		3'd1: for (int i = 0; i < VSIZE; i++) begin
			SelectOp[i] = rdata[i];
		end
		3'd2: for (int i = 0; i < VSIZE; i++) begin
			SelectOp[i] = $signed(srd0[i]);
		end
		3'd3: for (int i = 0; i < VSIZE; i++) begin
			SelectOp[i] = $signed(srd1[i]);
		end
		3'd4: for (int i = 0; i < VSIZE; i++) begin
			SelectOp[i] = tbuf[0][i];
		end
		3'd5: for (int i = 0; i < VSIZE; i++) begin
			SelectOp[i] = tbuf[1][i];
		end
	endcase
endfunction

`define DefineAluBodyBegin(name) \
function ResultType name;\
	input signed [TDBW-1:0] src_op_a [VSIZE];\
	input signed [TDBW-1:0] src_op_b [VSIZE];\
	input signed [TDBW-1:0] src_op_c [VSIZE];\
	input [4:0] i_shamt;\
	input i_en;
`define DefineAluComputeBegin \
	if (i_en) begin \
		for (int i = 0; i < VSIZE; i++) begin
`define DefineAluComputeBodyEnd(name) \
		end \
	end else begin \
		for (int i = 0; i < VSIZE; i++) begin \
			name[i] = '0;\
		end \
	end \
endfunction

`DefineAluBodyBegin(AluOpAdd)
`DefineAluComputeBegin
	AluOpAdd[i] = src_op_a[i]+(src_op_b[i]+src_op_c[i])>>i_shamt;
`DefineAluComputeBodyEnd(AluOpAdd)

`DefineAluBodyBegin(AluOpSub)
`DefineAluComputeBegin
	AluOpSub[i] = src_op_a[i]+(src_op_b[i]-src_op_c[i])>>i_shamt;
`DefineAluComputeBodyEnd(AluOpSub)

`DefineAluBodyBegin(AluOp2Norm)
	logic signed [DBW-1:0] diff [VSIZE];
	logic signed [2*DBW-1:0] mul [VSIZE];
`DefineAluComputeBegin
	diff[i] = src_op_b[i][DBW-1:0] - src_op_c[i][DBW-1:0];
	mul[i] = (diff[i] * diff[i]) >> i_shamt;
	AluOp2Norm[i] = src_op_a[i] + mul[i][TDBW-1:0];
`DefineAluComputeBodyEnd(AluOp2Norm)

`DefineAluBodyBegin(AluOp1Norm)
	logic signed [TDBW-1:0] diff1 [VSIZE];
	logic signed [TDBW-1:0] diff2 [VSIZE];
`DefineAluComputeBegin
	diff1[i] = src_op_b[i]-src_op_c[i];
	diff2[i] = src_op_c[i]-src_op_b[i];
	AluOp1Norm[i] = src_op_a[i] + (diff1[i] > 'sb0 ? diff1[i] : diff2[i])>>i_shamt;
`DefineAluComputeBodyEnd(AluOp1Norm)

`DefineAluBodyBegin(AluOpMac)
	logic signed [2*DBW-1:0] mul [VSIZE];
`DefineAluComputeBegin
	mul[i] = (src_op_b[i][DBW-1:0]*src_op_c[i][DBW-1:0]) >> i_shamt;
	AluOpMac[i] = src_op_a[i] + mul[i][TDBW-1:0];
`DefineAluComputeBodyEnd(AluOpMac)

function ResultType AluIdx;
	input [WBW-1:0] i_aofs [DIM];
	input [WBW-1:0] i_bofs [VSIZE][DIM];
	input [4:0] i_shamt;
	for (int i = 0; i < VSIZE; i++) begin
		AluIdx[i] = i_shamt[2] ? i_bofs[i][i_shamt[1:0]] : i_aofs[i_shamt[1:0]];
	end
endfunction

always_comb sel_a = SelectOp(i_a, i_const_a, i_rdata, i_sramrd0, i_sramrd1, i_tbuf_rdatas);
always_comb sel_b = SelectOp(i_b, i_const_b, i_rdata, i_sramrd0, i_sramrd1, i_tbuf_rdatas);
always_comb sel_c = SelectOp(i_c, i_const_c, i_rdata, i_sramrd0, i_sramrd1, i_tbuf_rdatas);
always_comb for (int i = 0; i < DIM; i++) begin
	bofsz[i] = (i_opcode == 3'b111 && i_shamt[4:2] == 3'b001)  ? i_bofs[i] : '0;
end
always_comb begin
	priority case (i_opcode)
		3'b000: result = AluOpAdd(sel_a, sel_b, sel_c, i_shamt, i_opcode == 3'b000);
		3'b001: result = AluOpSub(sel_a, sel_b, sel_c, i_shamt, i_opcode == 3'b001);
		3'b010: result = AluOp2Norm(sel_a, sel_b, sel_c, i_shamt, i_opcode == 3'b010);
		3'b011: result = AluOp1Norm(sel_a, sel_b, sel_c, i_shamt, i_opcode == 3'b011);
		3'b100: result = AluOpMac(sel_a, sel_b, sel_c, i_shamt, i_opcode == 3'b100);
		// 3'b101: result = AluOpNull();
		// 3'b110: result = AluOpNull();
		3'b111: result = AluIdx(i_aofs, vector_blockofs, i_shamt);
	endcase
	for (int i = 0; i < VSIZE; i++) begin
		o_dramwd[i]  = result[i] >> (2*i_to_dram); // fuck off the nLint bit width check
		o_wdata[i] = result[i];
		o_tbuf_wdata[i] = result[i];
	end
end

//======================================
// Submodule
//======================================
BofsExpand u_bexp(
	.i_bofs(bofsz),
	.i_bboundary(),
	.i_bsubofs(i_bsubofs),
	.i_bsub_lo_order(i_bsub_lo_order),
	.o_vector_bofs(vector_blockofs),
	.o_valid()
);

endmodule
