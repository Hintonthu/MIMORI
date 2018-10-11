// Copyright 2018 Yu Sheng Lin

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
`include "common/TauCfg.sv"
`include "common/Controllers.sv"
`include "TileAccumUnit/DmaPipeline/ChunkHead.sv"
`include "TileAccumUnit/DmaPipeline/ChunkAddrLooper/ChunkAddrLooper.sv"
`include "TileAccumUnit/DmaPipeline/SramWriteCollector.sv"
`include "TileAccumUnit/DmaPipeline/BankSramWriteButterflyIf.sv"

module DmaPipeline(
	`clk_port,
	`rdyack_port(bofs),
	i_which, // 0 or 1
	i_bofs,
	i_abeg,
	i_beg,
	i_end,
`ifdef SD
	i_syst_type,
`endif
	i_i0_global_linears,
	i_i0_global_mofs,
	i_i0_global_mboundaries,
	i_i0_global_cboundaries,
	i_i0_global_bshufs,
	i_i0_bstrides_frac,
	i_i0_bstrides_shamt,
	i_i0_global_ashufs,
	i_i0_astrides_frac,
	i_i0_astrides_shamt,
	i_i0_local_xor_srcs,
	i_i0_local_xor_swaps,
	i_i0_local_pads,
	i_i0_local_mboundaries,
	i_i0_wraps,
	i_i0_pad_values,
`ifdef SD
	i_i0_systolic_skip,
`endif
	i_i1_global_linears,
	i_i1_global_mofs,
	i_i1_global_mboundaries,
	i_i1_global_cboundaries,
	i_i1_global_bshufs,
	i_i1_bstrides_frac,
	i_i1_bstrides_shamt,
	i_i1_global_ashufs,
	i_i1_astrides_frac,
	i_i1_astrides_shamt,
	i_i1_local_xor_srcs,
	i_i1_local_xor_swaps,
	i_i1_local_pads,
	i_i1_local_mboundaries,
	i_i1_wraps,
	i_i1_pad_values,
`ifdef SD
	i_i1_systolic_skip,
`endif
	// We shall start fill data to ReadPipeline 0/1
	`rdyack_port(rp_en0),
	`rdyack_port(rp_en1),
	// Write to SRAM
	`dval_port(rmc_write0),
	`dval_port(rmc_write1),
	o_rmc_whiaddr0,
	o_rmc_whiaddr1,
	o_rmc_wdata,
	// DRAM interface
	`rdyack_port(dramra),
	o_dramra,
	`rdyack_port(dramrd),
	i_dramrd
);
//======================================
// Parameter
//======================================
import TauCfg::*;
localparam LBW0 = TauCfg::LOCAL_ADDR_BW0;
localparam LBW1 = TauCfg::LOCAL_ADDR_BW1;
localparam MAX_LBW = TauCfg::MAX_LOCAL_ADDR_BW;
localparam WBW = TauCfg::WORK_BW;
localparam GBW = TauCfg::GLOBAL_ADDR_BW;
localparam DBW = TauCfg::DATA_BW;
localparam N_ICFG = TauCfg::N_ICFG;
localparam DIM = TauCfg::DIM;
localparam VDIM = TauCfg::VDIM;
localparam SS_BW = TauCfg::STRIDE_BW;
localparam SF_BW = TauCfg::STRIDE_FRAC_BW;
localparam VSIZE = TauCfg::VSIZE;
localparam CSIZE = TauCfg::CACHE_SIZE;
localparam XOR_BW = TauCfg::XOR_BW;
// derived from global
localparam ICFG_BW = TauCfg::ICFG_BW;
localparam CV_BW = TauCfg::CV_BW;
localparam CCV_BW = TauCfg::CCV_BW;
localparam CX_BW = TauCfg::CX_BW;
localparam DIM_BW = TauCfg::DIM_BW;
// derived
localparam HBW = MAX_LBW-CV_BW;
localparam CC_BW = $clog2(CSIZE);
localparam CV_BW1 = $clog2(VSIZE+1);

//======================================
// I/O
//======================================
`clk_input;
`rdyack_input(bofs);
input               i_which;
input [WBW-1:0]     i_bofs [VDIM];
input [WBW-1:0]     i_abeg [VDIM];
input [ICFG_BW-1:0] i_beg;
input [ICFG_BW-1:0] i_end;
`ifdef SD
input [STO_BW-1:0]  i_syst_type;
`endif
input [GBW-1:0]     i_i0_global_linears     [N_ICFG];
input [WBW-1:0]     i_i0_global_mofs        [N_ICFG][DIM];
input [GBW-1:0]     i_i0_global_mboundaries [N_ICFG][DIM];
input [GBW-1:0]     i_i0_global_cboundaries [N_ICFG][DIM];
input [DIM_BW-1:0]  i_i0_global_bshufs      [N_ICFG][VDIM];
input [SF_BW-1:0]   i_i0_bstrides_frac      [N_ICFG][VDIM];
input [SS_BW-1:0]   i_i0_bstrides_shamt     [N_ICFG][VDIM];
input [DIM_BW-1:0]  i_i0_global_ashufs      [N_ICFG][VDIM];
input [SF_BW-1:0]   i_i0_astrides_frac      [N_ICFG][VDIM];
input [SS_BW-1:0]   i_i0_astrides_shamt     [N_ICFG][VDIM];
input [XOR_BW-1:0]  i_i0_local_xor_srcs     [N_ICFG][CV_BW];
input [CCV_BW-1:0]  i_i0_local_xor_swaps    [N_ICFG];
input [CV_BW-1:0]   i_i0_local_pads         [N_ICFG][DIM];
input [LBW0:0]      i_i0_local_mboundaries  [N_ICFG][DIM];
input [N_ICFG-1:0]  i_i0_wraps;
input [DBW-1:0]     i_i0_pad_values [N_ICFG];
`ifdef SD
input [N_ICFG-1:0]  i_i0_systolic_skip;
`endif
input [GBW-1:0]     i_i1_global_linears     [N_ICFG];
input [WBW-1:0]     i_i1_global_mofs        [N_ICFG][DIM];
input [GBW-1:0]     i_i1_global_mboundaries [N_ICFG][DIM];
input [GBW-1:0]     i_i1_global_cboundaries [N_ICFG][DIM];
input [DIM_BW-1:0]  i_i1_global_bshufs      [N_ICFG][VDIM];
input [SF_BW-1:0]   i_i1_bstrides_frac      [N_ICFG][VDIM];
input [SS_BW-1:0]   i_i1_bstrides_shamt     [N_ICFG][VDIM];
input [DIM_BW-1:0]  i_i1_global_ashufs      [N_ICFG][VDIM];
input [SF_BW-1:0]   i_i1_astrides_frac      [N_ICFG][VDIM];
input [SS_BW-1:0]   i_i1_astrides_shamt     [N_ICFG][VDIM];
input [XOR_BW-1:0]  i_i1_local_xor_srcs     [N_ICFG][CV_BW];
input [CCV_BW-1:0]  i_i1_local_xor_swaps    [N_ICFG];
input [CV_BW-1:0]   i_i1_local_pads         [N_ICFG][DIM];
input [LBW1:0]      i_i1_local_mboundaries  [N_ICFG][DIM];
input [N_ICFG-1:0]  i_i1_wraps;
input [DBW-1:0]     i_i1_pad_values [N_ICFG];
`ifdef SD
input [N_ICFG-1:0]  i_i1_systolic_skip;
`endif
`rdyack_input(rp_en0);
`rdyack_input(rp_en1);
`dval_output(rmc_write0);
`dval_output(rmc_write1);
output [LBW0-CV_BW-1:0] o_rmc_whiaddr0;
output [LBW1-CV_BW-1:0] o_rmc_whiaddr1;
output [DBW-1:0]        o_rmc_wdata [VSIZE];
`rdyack_output(dramra);
output [GBW-1:0] o_dramra;
`rdyack_input(dramrd);
input [DBW-1:0] i_dramrd [CSIZE];

//============================================================================
// Use src to generate memory offset
//============================================================================
`ifdef SD
`rdyack_logic(ch_mofs0);
logic i_systolic_skip;
`endif
`rdyack_logic(ch_mofs1);

// Select necessary input according to "which"
logic [WBW-1:0]     i_global_mofs        [N_ICFG][DIM];
logic [DIM_BW-1:0]  i_global_bshufs      [N_ICFG][VDIM];
logic [SF_BW-1:0]   i_bstrides_frac      [N_ICFG][VDIM];
logic [SS_BW-1:0]   i_bstrides_shamt     [N_ICFG][VDIM];
logic [DIM_BW-1:0]  i_global_ashufs      [N_ICFG][VDIM];
logic [SF_BW-1:0]   i_astrides_frac      [N_ICFG][VDIM];
logic [SS_BW-1:0]   i_astrides_shamt     [N_ICFG][VDIM];
always_comb begin
	if (i_which) begin
		i_global_mofs    = i_i1_global_mofs;
		i_global_bshufs  = i_i1_global_bshufs;
		i_bstrides_frac  = i_i1_bstrides_frac;
		i_bstrides_shamt = i_i1_bstrides_shamt;
		i_global_ashufs  = i_i1_global_ashufs;
		i_astrides_frac  = i_i1_astrides_frac;
		i_astrides_shamt = i_i1_astrides_shamt;
`ifdef SD
		i_systolic_skip  = i_i1_systolic_skip;
`endif
	end else begin
		i_global_mofs    = i_i0_global_mofs;
		i_global_bshufs  = i_i0_global_bshufs;
		i_bstrides_frac  = i_i0_bstrides_frac;
		i_bstrides_shamt = i_i0_bstrides_shamt;
		i_global_ashufs  = i_i0_global_ashufs;
		i_astrides_frac  = i_i0_astrides_frac;
		i_astrides_shamt = i_i0_astrides_shamt;
`ifdef SD
		i_systolic_skip  = i_i0_systolic_skip;
`endif
	end
end

logic               ch_which;
logic [WBW-1:0]     ch_mofs [DIM];
logic [ICFG_BW-1:0] ch_mid;
ChunkHead u_chunk_head(
	`clk_connect,
	`rdyack_connect(i_abofs, bofs),
	.i_which(i_which),
	.i_bofs(i_bofs),
	.i_aofs(i_abeg),
	.i_beg(i_beg),
	.i_end(i_end),
`ifdef SD
	.i_syst_type(i_syst_type),
`endif
	.i_global_mofs(i_global_mofs),
	.i_global_bshufs(i_global_bshufs),
	.i_bstrides_frac(i_bstrides_frac),
	.i_bstrides_shamt(i_bstrides_shamt),
	.i_global_ashufs(i_global_ashufs),
	.i_astrides_frac(i_astrides_frac),
	.i_astrides_shamt(i_astrides_shamt),
`ifdef SD
	.i_systolic_skip(i_systolic_skip),
	`rdyack_connect(o_mofs, ch_mofs0),
`else
	`rdyack_connect(o_mofs, ch_mofs1),
`endif
	.o_which(ch_which),
	.o_mofs(ch_mofs),
	.o_id(ch_mid)
`ifdef SD
	,
	.o_skip(ch_skip)
`endif
);
// Delete some transaction in systolic mode
`ifdef SD
DeleteIf#(1) u_ign_ch_cmd(
	.cond(ch_skip),
	`rdyack_connect(src, ch_mofs0),
	`rdyack_connect(dst, ch_mofs1),
	.skipped()
);
`endif
// Now we have ch_mofs1 as output

//============================================================================
// Broadcast to two ChunkAddrLooper's and SramWriteCollector
//============================================================================
// Enable only if ReadPipeline is requesting
`rdyack_logic(ch_mofs2);
`rdyack_logic(ch_cmd0);
`rdyack_logic(ch_addr0);
`rdyack_logic(ch_alloc0);
always_comb begin
	ch_mofs2_rdy = ch_mofs1_rdy && (ch_which ? rp_en1_rdy : rp_en0_rdy);
	rp_en0_ack = ch_mofs2_ack && !ch_which;
	rp_en1_ack = ch_mofs2_ack &&  ch_which;
	ch_mofs1_ack = ch_mofs2_ack;
end
Broadcast#(3) u_broadcast_ch(
	`clk_connect,
	`rdyack_connect(src, ch_mofs2),
	.dst_rdys({ch_alloc0_rdy,ch_cmd0_rdy,ch_addr0_rdy}),
	.dst_acks({ch_alloc0_ack,ch_cmd0_ack,ch_addr0_ack})
);

//============================================================================
// Pipeline
//============================================================================
`rdyack_logic(ch_cmd1);
`rdyack_logic(ch_addr1);
`rdyack_logic(ch_alloc1);
Forward u_fwd_cmd(
	`clk_connect,
	`rdyack_connect(src, ch_cmd0),
	`rdyack_connect(dst, ch_cmd1)
);
Forward u_fwd_addr(
	`clk_connect,
	`rdyack_connect(src, ch_addr0),
	`rdyack_connect(dst, ch_addr1)
);
Forward u_fwd_alloc(
	`clk_connect,
	`rdyack_connect(src, ch_alloc0),
	`rdyack_connect(dst, ch_alloc1)
);

// Sign extension
logic [GBW-1:0] ch_mofs_sext [DIM];
always_comb for (int i = 0; i < DIM; i++) begin
	ch_mofs_sext[i] = $signed(ch_mofs[i]);
end

// Select multiplier
logic [GBW-1:0] ch_global_mboundary [DIM];
always_comb begin
	if (ch_which) begin
		ch_global_mboundary = i_i1_global_mboundaries[ch_mid];
	end else begin
		ch_global_mboundary = i_i0_global_mboundaries[ch_mid];
	end
end

logic               ch_cmd_which;
logic [GBW-1:0]     ch_cmd_mofs [DIM];
logic [ICFG_BW-1:0] ch_cmd_mid;
`ff_rst
	ch_cmd_which <= 1'b0;
	for (int i = 0; i < DIM; i++) begin
		ch_cmd_mofs[i] <= '0;
	end
	ch_cmd_mid <= '0;
`ff_cg(ch_cmd0_ack)
	ch_cmd_which <= ch_which;
	for (int i = 0; i < DIM-1; i++) begin
		ch_cmd_mofs[i] <= ch_mofs_sext[i] * ch_global_mboundary[i+1];
	end
	ch_cmd_mofs[DIM-1] <= ch_mofs_sext[DIM-1];
	ch_cmd_mid <= ch_mid;
`ff_end

logic               ch_addr_which;
logic [GBW-1:0]     ch_addr_mofs [DIM];
logic [ICFG_BW-1:0] ch_addr_mid;
`ff_rst
	ch_addr_which <= 1'b0;
	for (int i = 0; i < DIM; i++) begin
		ch_addr_mofs[i] <= '0;
	end
	ch_addr_mid <= '0;
`ff_cg(ch_addr0_ack)
	ch_addr_which <= ch_which;
	for (int i = 0; i < DIM-1; i++) begin
		ch_addr_mofs[i] <= ch_mofs_sext[i] * ch_global_mboundary[i+1];
	end
	ch_addr_mofs[DIM-1] <= ch_mofs_sext[DIM-1];
	ch_addr_mid <= ch_mid;
`ff_end

logic               ch_alloc_which;
logic [ICFG_BW-1:0] ch_alloc_mid;
`ff_rst
	ch_alloc_which <= '0;
	ch_alloc_mid <= '0;
`ff_cg(ch_alloc0_ack)
	ch_alloc_which <= ch_which;
	ch_alloc_mid <= ch_mid;
`ff_end

//======================================================
// Broadcasted (To DRAM)
//======================================================
logic [GBW-1:0]     ch_addr_global_linear;
logic               ch_addr_wrap;
logic [CV_BW-1:0]   ch_addr_local_pad [DIM];
logic [GBW-1:0]     ch_addr_global_mboundary [DIM];
logic [GBW-1:0]     ch_addr_global_cboundary [DIM];
always_comb begin
	if (ch_addr_which) begin
		ch_addr_global_linear    = i_i1_global_linears[ch_addr_mid];
		ch_addr_wrap             = i_i1_wraps[ch_addr_mid];
	end else begin
		ch_addr_global_linear    = i_i0_global_linears[ch_addr_mid];
		ch_addr_wrap             = i_i0_wraps[ch_addr_mid];
	end
end

always_comb for (int i = 0; i < DIM; i++) begin
	if (ch_addr_which) begin
		ch_addr_local_pad[i]        = i_i1_local_pads[ch_addr_mid][i];
		ch_addr_global_mboundary[i] = i_i1_global_mboundaries[ch_addr_mid][i];
		ch_addr_global_cboundary[i] = i_i1_global_cboundaries[ch_addr_mid][i];
	end else begin
		ch_addr_local_pad[i]        = i_i0_local_pads[ch_addr_mid][i];
		ch_addr_global_mboundary[i] = i_i0_global_mboundaries[ch_addr_mid][i];
		ch_addr_global_cboundary[i] = i_i0_global_cboundaries[ch_addr_mid][i];
	end
end

`rdyack_logic(cal_addr);
logic cal_addr_islast;
ChunkAddrLooper u_cal_addr(
	`clk_connect,
	`rdyack_connect(mofs, ch_addr1),
	.i_which(),
	.i_mofs(ch_addr_mofs),
	.i_mpad(ch_addr_local_pad),
	.i_mbound(ch_addr_global_mboundary),
	.i_mlast(ch_addr_global_cboundary),
	.i_maddr(ch_addr_global_linear),
	.i_wrap(ch_addr_wrap),
	`rdyack_connect(cmd, cal_addr),
	.o_which(),
	.o_cmd_type(),
	.o_cmd_islast(cal_addr_islast),
	.o_cmd_addr(o_dramra),
	.o_cmd_addrofs(),
	.o_cmd_len()
);
DeleteIf#(0) u_ign_if_not_last_addr(
	.cond(cal_addr_islast),
	`rdyack_connect(src, cal_addr),
	`rdyack_connect(dst, dramra),
	.deleted()
);

//======================================================
// Broadcasted (Get data from DRAM and write)
//======================================================
logic [GBW-1:0]     ch_cmd_global_linear;
logic               ch_cmd_wrap;
logic [CV_BW-1:0]   ch_cmd_local_pad [DIM];
logic [GBW-1:0]     ch_cmd_global_mboundary [DIM];
logic [GBW-1:0]     ch_cmd_global_cboundary [DIM];
always_comb begin
	if (ch_cmd_which) begin
		ch_cmd_global_linear = i_i1_global_linears[ch_cmd_mid];
		ch_cmd_wrap          = i_i1_wraps[ch_cmd_mid];
	end else begin
		ch_cmd_global_linear = i_i0_global_linears[ch_cmd_mid];
		ch_cmd_wrap          = i_i0_wraps[ch_cmd_mid];
	end
end

always_comb for (int i = 0; i < DIM; i++) begin
	if (ch_cmd_which) begin
		ch_cmd_local_pad[i]        = i_i1_local_pads[ch_cmd_mid][i];
		ch_cmd_global_mboundary[i] = i_i1_global_mboundaries[ch_cmd_mid][i];
		ch_cmd_global_cboundary[i] = i_i1_global_cboundaries[ch_cmd_mid][i];
	end else begin
		ch_cmd_local_pad[i]        = i_i0_local_pads[ch_cmd_mid][i];
		ch_cmd_global_mboundary[i] = i_i0_global_mboundaries[ch_cmd_mid][i];
		ch_cmd_global_cboundary[i] = i_i0_global_cboundaries[ch_cmd_mid][i];
	end
end

`rdyack_logic(cal_swc);
logic              cmd_swc_which;
logic [1:0]        cmd_swc_type;
logic              cmd_swc_islast;
logic [CC_BW-1:0]  cmd_swc_addrofs;
logic [CV_BW1-1:0] cmd_swc_len;
ChunkAddrLooper u_cal_cmd(
	`clk_connect,
	`rdyack_connect(mofs, ch_cmd1),
	.i_which(ch_cmd_which),
	.i_mofs(ch_cmd_mofs),
	.i_mpad(ch_cmd_local_pad),
	.i_mbound(ch_cmd_global_mboundary),
	.i_mlast(ch_cmd_global_cboundary),
	.i_maddr(ch_cmd_global_linear),
	.i_wrap(ch_cmd_wrap),
	`rdyack_connect(cmd, cal_swc),
	.o_which(cmd_swc_which),
	.o_cmd_type(cmd_swc_type),
	.o_cmd_islast(cmd_swc_islast),
	.o_cmd_addr(),
	.o_cmd_addrofs(cmd_swc_addrofs),
	.o_cmd_len(cmd_swc_len)
);
//======================================================
// Broadcasted (Allocate information)
//======================================================
// SramWriteCollector
logic [DBW-1:0]     ch_alloc_pad_value;
logic [MAX_LBW:0]   ch_alloc_size;
logic [ICFG_BW-1:0] rmc_wif_id;
always_comb begin
	if (ch_alloc_which) begin
		ch_alloc_size      = i_i1_local_mboundaries[ch_alloc_mid][0];
		ch_alloc_pad_value = i_i1_pad_values[ch_alloc_mid];
	end else begin
		ch_alloc_size      = i_i0_local_mboundaries[ch_alloc_mid][0];
		ch_alloc_pad_value = i_i0_pad_values[ch_alloc_mid];
	end
end
logic [DBW-1:0] o_rmc_wdata0 [VSIZE];
SramWriteCollector u_swc(
	`clk_connect,
	`rdyack_connect(alloc, ch_alloc1),
	.i_id(ch_alloc_mid),
	.i_size(ch_alloc_size),
	.i_padv(ch_alloc_pad_value),
	`rdyack_connect(cmd, cal_swc),
	.i_which(cmd_swc_which),
	.i_cmd_type(cmd_swc_type),
	.i_cmd_islast(cmd_swc_islast),
	.i_cmd_addrofs(cmd_swc_addrofs),
	.i_cmd_len(cmd_swc_len),
	`rdyack_connect(dramrd, dramrd),
	.i_dramrd(i_dramrd),
	`dval_connect(w0, rmc_write0),
	`dval_connect(w1, rmc_write1),
	.o_id(rmc_wif_id),
	.o_hiaddr0(o_rmc_whiaddr0),
	.o_hiaddr1(o_rmc_whiaddr1),
	.o_data(o_rmc_wdata0)
);
// BankSramButterflyWriteIf
logic [XOR_BW-1:0] rmc_xor_wsrc [CV_BW];
logic [CCV_BW-1:0] rmc_xor_wswap;
logic [HBW-1:0]    rmc_whiaddr;
always_comb begin
	/*
	  systemverilog 2012 equivelent (it doesn't work)
	  unique0 if (rmc_write1_dval) begin
	  end else if (rmc_write0_dval) begin
	*/
	if (rmc_write1_dval) begin
		rmc_xor_wsrc    = i_i1_local_xor_srcs[rmc_wif_id];
		rmc_xor_wswap   = i_i1_local_xor_swaps[rmc_wif_id];
		rmc_whiaddr     = o_rmc_whiaddr1;
	end else begin
		rmc_xor_wsrc    = i_i0_local_xor_srcs[rmc_wif_id];
		rmc_xor_wswap   = i_i0_local_xor_swaps[rmc_wif_id];
		rmc_whiaddr     = o_rmc_whiaddr0;
	end
end
BankSramButterflyWriteIf u_wif(
	.i_xor_src(rmc_xor_wsrc),
	.i_xor_swap(rmc_xor_wswap),
	.i_hiaddr(rmc_whiaddr),
	.i_data(o_rmc_wdata0),
	.o_data(o_rmc_wdata)
);

endmodule
