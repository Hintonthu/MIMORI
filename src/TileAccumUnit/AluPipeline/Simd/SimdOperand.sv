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

module SimdOperand(
	`clk_port,
	// input
	`rdyack_port(inst),
	i_insts,
	i_consts,
	i_bofs,
	i_aofs,
	i_pc,
	i_wid,
	i_reg_per_warp,
	// decoded, to alu stage
	`rdyack_port(op),
	o_opcode,
	o_shamt,
	o_bofs,
	o_aofs,
	o_const_a,
	o_const_b,
	o_const_c,
	o_a,
	o_b,
	o_c,
	o_to_reg,
	o_to_dram,
	o_to_temp,
	o_reg_waddr,
	// control SRAM
	o_reg_re,
	o_reg_raddr
);

//======================================
// Parameter
//======================================
localparam WBW = TauCfg::WORK_BW;
localparam DIM = TauCfg::DIM;
localparam N_INST = TauCfg::N_INST;
localparam ISA_BW = TauCfg::ISA_BW;
localparam DBW = TauCfg::DATA_BW;
localparam TDBW = TauCfg::TMP_DATA_BW;
localparam NWORD = TauCfg::SRAM_NWORD;
localparam MAX_WARP = TauCfg::MAX_WARP;
localparam REG_ADDR = TauCfg::WARP_REG_ADDR_SPACE;
localparam CONST_LUT = TauCfg::CONST_LUT;
// derived
localparam REG_ABW = $clog2(REG_ADDR);
localparam SRAM_ABW = $clog2(NWORD);
localparam INST_BW = $clog2(N_INST+1);
localparam WID_BW = $clog2(MAX_WARP);

//======================================
// I/O
//======================================
`clk_input;
`rdyack_input(inst);
input [ISA_BW-1:0]  i_insts [N_INST];
input [TDBW-1:0]    i_consts [CONST_LUT];
input [WBW-1:0]     i_bofs [DIM];
input [WBW-1:0]     i_aofs [DIM];
input [INST_BW-1:0] i_pc;
input [WID_BW-1:0]  i_wid;
input [REG_ABW-1:0] i_reg_per_warp;
`rdyack_output(op);
output logic [2:0]          o_opcode;
output logic [4:0]          o_shamt;
output logic [WBW-1:0]      o_bofs [DIM];
output logic [WBW-1:0]      o_aofs [DIM];
output logic [TDBW-1:0]     o_const_a;
output logic [TDBW-1:0]     o_const_b;
output logic [TDBW-1:0]     o_const_c;
output logic [2:0]          o_a;
output logic [2:0]          o_b;
output logic [2:0]          o_c;
output logic                o_to_reg;
output logic [1:0]          o_to_dram;
output logic                o_to_temp;
output logic [SRAM_ABW-1:0] o_reg_waddr;
// The two signals are not bundled with op
output logic                o_reg_re;
output logic [SRAM_ABW-1:0] o_reg_raddr;

function [7:0] SrcOpSpace;
	input [4:0] src;
	casez (src)
		5'b0????: SrcOpSpace = {3'b0        , 5'h01}; // direct const [0]
		5'b1000?: SrcOpSpace = {2'd1, src[0], 5'h02}; // read pipeline [23]
		5'b1001?: SrcOpSpace = {2'd2, src[0], 5'h04}; // temp delay [45]
		5'b101??: SrcOpSpace = {3'b0        , 5'h08}; // lut [0]
		5'b11???: SrcOpSpace = {3'd1        , 5'h10}; // register [1]
	endcase
endfunction

function [TDBW-1:0] SetConstantOp;
	input [4:0] src;
	input direct_const;
	input lut_const;
	input [TDBW-1:0] prev;
	input [TDBW-1:0] i_consts [CONST_LUT];
	// TODO: bitwidth lint error
	unique case (1'b1)
		direct_const: SetConstantOp = src[3:0];
		lut_const:    SetConstantOp = i_consts[src[1:0]];
		default:      SetConstantOp = prev;
	endcase
endfunction

//======================================
// Internal
//======================================
logic [ISA_BW-1:0] inst;
logic [2:0] a_w;
logic [2:0] b_w;
logic [2:0] c_w;
logic [4:0] a_rspace;
logic [4:0] b_rspace;
logic [4:0] c_rspace;
logic [TDBW-1:0] const_a_w;
logic [TDBW-1:0] const_b_w;
logic [TDBW-1:0] const_c_w;
logic [REG_ABW-1:0] warp_addr; // relative register address of this warp
logic [SRAM_ABW-1:0] reg_offset; // address  of register 0 of this warp
logic [SRAM_ABW-1:0] reg_waddr_w;

//======================================
// Submodule
//======================================
Forward u_fwd(
	`clk_connect,
	`rdyack_connect(src, inst),
	`rdyack_connect(dst, op)
);

//======================================
// Combinational
//======================================
assign inst = i_insts[i_pc];
assign reg_offset = i_wid * i_reg_per_warp; // fuck off the nLint bitwidth check
always_comb begin
	{a_w, a_rspace} = SrcOpSpace(inst[14-:5]);
	{b_w, b_rspace} = SrcOpSpace(inst[ 9-:5]);
	{c_w, c_rspace} = SrcOpSpace(inst[ 4-:5]);
	if (inst_ack) begin
		const_a_w = SetConstantOp(inst[14-:5], a_rspace[0], a_rspace[3], o_const_a, i_consts);
		const_b_w = SetConstantOp(inst[ 9-:5], b_rspace[0], b_rspace[3], o_const_b, i_consts);
		const_c_w = SetConstantOp(inst[ 4-:5], c_rspace[0], c_rspace[3], o_const_c, i_consts);
		o_reg_re = a_rspace[4] | b_rspace[4] | c_rspace[4];
	end else begin
		const_a_w = o_const_a;
		const_b_w = o_const_b;
		const_c_w = o_const_c;
		o_reg_re = 1'b0;
	end
	warp_addr = '0;
	if (a_rspace[4]) warp_addr = warp_addr | inst[12-:3];
	if (b_rspace[4]) warp_addr = warp_addr | inst[ 7-:3];
	if (c_rspace[4]) warp_addr = warp_addr | inst[ 2-:3];
	o_reg_raddr = reg_offset + warp_addr; // fuck off the nLint bitwidth check
	reg_waddr_w = reg_offset + inst[17-:3]; // fuck off the nLint bitwidth check
end

//======================================
// Sequential
//======================================
`ff_rst
	// bypass
	o_opcode <= '0;
	o_shamt <= '0;
	for (int i = 0; i < DIM; i++) begin
		o_bofs[i] <= '0;
		o_aofs[i] <= '0;
	end
	o_to_reg <= 1'b0;
	o_to_dram <= 2'b11;
	o_to_temp <= 1'b0;
	// decoded
	o_const_a <= '0;
	o_const_b <= '0;
	o_const_c <= '0;
	o_a <= '0;
	o_b <= '0;
	o_c <= '0;
	o_reg_waddr <= '0;
`ff_cg(inst_ack)
	// bypass
	o_opcode <= inst[29-:3];
	o_shamt <= inst[26-:5];
	o_bofs <= i_bofs;
	o_aofs <= i_aofs;
	o_to_reg <= inst[21];
	o_to_dram <= inst[20:19];
	o_to_temp <= inst[18];
	// decoded
	o_const_a <= const_a_w;
	o_const_b <= const_b_w;
	o_const_c <= const_c_w;
	o_a <= a_w;
	o_b <= b_w;
	o_c <= c_w;
	o_reg_waddr <= reg_waddr_w;
`ff_end

endmodule
