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

`include "common/define.sv"
`include "TileAccumUnit/AluPipeline/Simd/Alu.sv"
`include "TileAccumUnit/AluPipeline/Simd/SimdTmpBuffer.sv"
`include "TileAccumUnit/AluPipeline/Simd/SimdOperand.sv"

module Simd(
	`clk_port,
	`rdyack_port(inst),
	i_insts,
	i_consts,
	i_const_texs,
	i_bofs,
	i_bsubofs,
	i_bsub_lo_order,
	i_aofs,
	i_pc,
	i_wid,
	i_reg_per_warp,
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
localparam VDIM = TauCfg::VDIM;
localparam ISA_BW = TauCfg::ISA_BW;
localparam DBW = TauCfg::DATA_BW;
localparam TDBW = TauCfg::TMP_DATA_BW;
localparam VSIZE = TauCfg::VSIZE;
localparam NWORD = TauCfg::SRAM_NWORD;
localparam MAX_WARP = TauCfg::MAX_WARP;
localparam REG_ADDR = TauCfg::WARP_REG_ADDR_SPACE;
localparam CONST_LUT = TauCfg::CONST_LUT;
localparam CONST_TEX_LUT = TauCfg::CONST_TEX_LUT;
localparam N_INST = TauCfg::N_INST;
localparam TBUF_SIZE = TauCfg::ALU_DELAY_BUF_SIZE;
// derived
localparam INST_BW = $clog2(N_INST+1);
localparam CV_BW = $clog2(VSIZE);
localparam CCV_BW = $clog2(CV_BW+1);
localparam WID_BW = $clog2(MAX_WARP);
localparam REG_ABW = $clog2(REG_ADDR);
localparam SRAM_ABW = $clog2(NWORD);
localparam FLAT_BW = TDBW*VSIZE;

//======================================
// I/O
//======================================
`clk_input;
`rdyack_input(inst);
input [ISA_BW-1:0]  i_insts [N_INST];
input [TDBW-1:0]    i_consts [CONST_LUT];
input [TDBW-1:0]    i_const_texs [CONST_TEX_LUT];
input [WBW-1:0]     i_bofs [VDIM];
input [CV_BW-1:0]   i_bsubofs [VSIZE][VDIM];
input [CCV_BW-1:0]  i_bsub_lo_order  [VDIM];
input [WBW-1:0]     i_aofs [VDIM];
input [INST_BW-1:0] i_pc;
input [WID_BW-1:0]  i_wid;
input [REG_ABW-1:0] i_reg_per_warp;
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
`rdyack_logic(op_alu);
// op -> reg
logic                op_reg_re;
logic [SRAM_ABW-1:0] op_reg_raddr;
// alu <-> reg
`dval_logic(alu_reg_we);
logic [SRAM_ABW-1:0] alu_reg_waddr;
logic [TDBW-1:0]     alu_reg_wdata [VSIZE];
logic [FLAT_BW-1:0]  alu_reg_wdata_flat;
// alu <-> tbuf
`dval_logic(alu_tbuf_we);
// shared with alu_reg_wdata (this makes DC happier)
// logic [TDBW-1:0] alu_tbuf_wdata [VSIZE];
logic [TDBW-1:0] tbuf_alu_rdatas [TBUF_SIZE][VSIZE];
// op -> alu
logic [2:0]          op_alu_opcode;
logic [4:0]          op_alu_shamt;
logic [WBW-1:0]      op_alu_bofs [VDIM];
logic [WBW-1:0]      op_alu_aofs [VDIM];
logic [TDBW-1:0]     op_alu_const_a;
logic [TDBW-1:0]     op_alu_const_b;
logic [TDBW-1:0]     op_alu_const_c;
logic [2:0]          op_alu_a;
logic [2:0]          op_alu_b;
logic [2:0]          op_alu_c;
logic                op_alu_to_reg;
logic [1:0]          op_alu_to_dram;
logic                op_alu_to_temp;
logic [SRAM_ABW-1:0] op_alu_waddr;
logic [TDBW-1:0]     reg_alu_rdata [VSIZE];
logic [FLAT_BW-1:0]  reg_alu_rdata_flat;

//======================================
// Submodule
//======================================
SimdOperand u_op(
	`clk_connect,
	`rdyack_connect(inst, inst),
	.i_insts(i_insts),
	.i_consts(i_consts),
	.i_bofs(i_bofs),
	.i_aofs(i_aofs),
	.i_pc(i_pc),
	.i_wid(i_wid),
	.i_reg_per_warp(i_reg_per_warp),
	`rdyack_connect(op, op_alu),
	.o_opcode(op_alu_opcode),
	.o_shamt(op_alu_shamt),
	.o_bofs(op_alu_bofs),
	.o_aofs(op_alu_aofs),
	.o_const_a(op_alu_const_a),
	.o_const_b(op_alu_const_b),
	.o_const_c(op_alu_const_c),
	.o_a(op_alu_a),
	.o_b(op_alu_b),
	.o_c(op_alu_c),
	.o_to_reg(op_alu_to_reg),
	.o_to_dram(op_alu_to_dram),
	.o_to_temp(op_alu_to_temp),
	.o_reg_waddr(op_alu_waddr),
	.o_reg_re(op_reg_re),
	.o_reg_raddr(op_reg_raddr)
);

Alu u_alu(
	`clk_connect,
	`rdyack_connect(op, op_alu),
	.i_bsubofs(i_bsubofs),
	.i_bsub_lo_order(i_bsub_lo_order),
	.i_const_texs(i_const_texs),
	.i_opcode(op_alu_opcode),
	.i_shamt(op_alu_shamt),
	.i_bofs(op_alu_bofs),
	.i_aofs(op_alu_aofs),
	.i_const_a(op_alu_const_a),
	.i_const_b(op_alu_const_b),
	.i_const_c(op_alu_const_c),
	.i_a(op_alu_a),
	.i_b(op_alu_b),
	.i_c(op_alu_c),
	.i_to_reg(op_alu_to_reg),
	.i_to_dram(op_alu_to_dram),
	.i_to_temp(op_alu_to_temp),
	.i_reg_waddr(op_alu_waddr),
	.i_rdata(reg_alu_rdata),
	.i_tbuf_rdatas(tbuf_alu_rdatas),
	`dval_connect(reg_we, alu_reg_we),
	.o_reg_waddr(alu_reg_waddr),
	.o_wdata(alu_reg_wdata),
	`dval_connect(tbuf_we, alu_tbuf_we),
	// shared with alu_reg_wdata (this makes DC happier)
	// .o_tbuf_wdata(alu_tbuf_wdata),
	`rdyack_connect(sramrd0, sramrd0),
	.i_sramrd0(i_sramrd0),
	`rdyack_connect(sramrd1, sramrd1),
	.i_sramrd1(i_sramrd1),
	`rdyack_connect(dramwd, dramwd),
	.o_dramwd(o_dramwd),
	`dval_connect(inst_commit, inst_commit)
);

SRAMTwoPort#(.BW(FLAT_BW), .NDATA(NWORD)) u_register(
	.i_clk(i_clk),
	.i_we(alu_reg_we_dval),
	.i_re(op_reg_re),
	.i_waddr(alu_reg_waddr),
	.i_wdata(alu_reg_wdata_flat),
	.i_raddr(op_reg_raddr),
	.o_rdata(reg_alu_rdata_flat)
);

SimdTmpBuffer u_tbuf(
	`clk_connect,
	.i_we(alu_tbuf_we_dval),
	// shared with alu_reg_wdata (this makes DC happier)
	// .i_wdata(alu_tbuf_wdata),
	.i_wdata(alu_reg_wdata),
	.o_rdatas(tbuf_alu_rdatas)
);

//======================================
// Combinational
//======================================
always_comb begin
	for (int i = 0, j = TDBW-1; i < VSIZE; i++, j += TDBW) begin
		reg_alu_rdata[i] = reg_alu_rdata_flat[j-:TDBW];
		alu_reg_wdata_flat[j-:TDBW] = alu_reg_wdata[i];
	end
end

endmodule
