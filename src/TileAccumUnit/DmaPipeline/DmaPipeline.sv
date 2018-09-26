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

module DmaPipeline(
	`clk_port,
	`rdyack_port(bofs),
	i_which, // 0 or 1
	i_bofs,
	i_abeg,
	i_aend,
	i_beg,
	i_end,
`ifdef SD
	i_syst_type,
`endif
	i_bgrid_step,
	i_global_linears,
	i_global_mofs,
	i_global_mboundaries,
	i_global_cboundaries,
	i_global_bshufs,
	i_bstrides_frac,
	i_bstrides_shamt,
	i_global_ashufs,
	i_astrides_frac,
	i_astrides_shamt,
	i_local_pads,
	i_local_bsubsteps,
	i_local_mboundaries,
	i_wrap,
	i_pad_value,
	i_id_begs,
	i_id_ends,
`ifdef SD
	i_systolic_skip,
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

ChunkHead u_chunk_head(
	`clk_connect,
	`rdyack_connect(i_abofs, brd0_ch),
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
`endif
	`rdyack_connect(o_mofs, ch_mofs),
	.o_which(o_which),
	.o_mofs(ch_mofs),
	.o_id(ch_mid)
`ifdef SD
	,
	.o_skip(ch_skip)
`endif
);
`ifdef SD
Forward u_fwd_cmd(
	`clk_connect,
	`rdyack_connect(src, ch_cmd_mofs_src2),
	`rdyack_connect(dst, ch_cmd_mofs_dst)
);
Forward u_fwd_addr(
	`clk_connect,
	`rdyack_connect(src, ch_addr_mofs_src2),
	`rdyack_connect(dst, ch_addr_mofs_dst)
);
DeleteIf#(1) u_ign_ch_cmd(
	.cond(ch_skip),
	`rdyack_connect(src, ch_cmd_mofs_src),
	`rdyack_connect(dst, ch_cmd_mofs_src2),
	.skipped()
);
DeleteIf#(1) u_ign_ch_addr(
	.cond(ch_skip),
	`rdyack_connect(src, ch_addr_mofs_src),
	`rdyack_connect(dst, ch_addr_mofs_src2),
	.skipped()
);
`else
Forward u_fwd_cmd(
	`clk_connect,
	`rdyack_connect(src, ch_cmd_mofs_src),
	`rdyack_connect(dst, ch_cmd_mofs_dst)
);
Forward u_fwd_addr(
	`clk_connect,
	`rdyack_connect(src, ch_addr_mofs_src),
	`rdyack_connect(dst, ch_addr_mofs_dst)
);
`endif
ChunkAddrLooper#(.LBW(LBW)) u_cal_addr(
	`clk_connect,
	`rdyack_connect(mofs, ch_addr_mofs_dst2),
	.i_mofs(ch_addr_mofs),
	.i_mpad(ch_addr_local_pad),
	.i_mbound(ch_addr_global_mboundary),
	.i_mlast(ch_addr_global_cboundary),
	.i_maddr(i_global_linears[ch_addr_mid]),
	.i_wrap(i_wrap[ch_addr_mid]),
	`rdyack_connect(cmd, cal_addr),
	.o_cmd_type(),
	.o_cmd_islast(cal_addr_islast),
	.o_cmd_addr(o_dramra),
	.o_cmd_addrofs(),
	.o_cmd_len()
);
ChunkAddrLooper#(.LBW(LBW)) u_cal_cmd(
	`clk_connect,
	`rdyack_connect(mofs, ch_cmd_mofs_dst),
	.i_mofs(ch_cmd_mofs),
	.i_mpad(ch_cmd_local_pad),
	.i_mbound(ch_cmd_global_mboundary),
	.i_mlast(ch_cmd_global_cboundary),
	.i_maddr(i_global_linears[ch_cmd_mid]),
	.i_wrap(i_wrap[ch_cmd_mid]),
	`rdyack_connect(cmd, cal_writer_cmd),
	.o_cmd_type(cal_writer_type),
	.o_cmd_islast(cal_writer_islast),
	.o_cmd_addr(),
	.o_cmd_addrofs(cal_writer_addrofs),
	.o_cmd_len(cal_writer_len)
);
SramWriteCollector#(.LBW(LBW)) u_swc(
	`clk_connect,
	`rdyack_connect(alloc_linear, alloc_writer_linear),
	.i_linear(alloc_writer_linear),
	.i_linear_id(alloc_writer_linear_id),
	.i_size(i_local_sizes[alloc_writer_linear_id]),
`ifdef SD
	.i_skip(alloc_writer_false_alloc),
`endif
	.i_padv(i_pad_value[alloc_writer_linear_id]),
	`rdyack_connect(cmd, cal_writer_cmd),
	.i_cmd_type(cal_writer_type),
	.i_cmd_islast(cal_writer_islast),
	.i_cmd_addrofs(cal_writer_addrofs),
	.i_cmd_len(cal_writer_len),
	`rdyack_connect(dramrd, dramrd),
	.i_dramrd(i_dramrd),
	`rdyack_connect(done_linear, writer_warp_linear_fifo_in),
	.o_linear(writer_linear),
	.o_linear_id(),
	`dval_connect(w, writer_rmc),
	.o_id(writer_rmc_wid),
	.o_hiaddr(writer_rmc_whiaddr),
	.o_data(writer_rmc_wdata)
);

BankSramButterflyWriteIf #(
	.BW(DBW),
	.NDATA(NDATA),
	.NBANK(VSIZE)
) u_wif (
	.i_xor_src(xor_wsrc),
	.i_xor_swap(i_xor_swaps[i_wid]),
	.i_hiaddr(i_whiaddr),
	.i_data(i_wdata),
	.o_data(sram_wd)
);
`ifdef SD
Forward u_fwd_cmd(
	`clk_connect,
	`rdyack_connect(src, ch_cmd_mofs_src2),
	`rdyack_connect(dst, ch_cmd_mofs_dst)
);
Forward u_fwd_addr(
	`clk_connect,
	`rdyack_connect(src, ch_addr_mofs_src2),
	`rdyack_connect(dst, ch_addr_mofs_dst)
);
IgnoreIf#(1) u_ign_ch_cmd(
	.cond(ch_skip),
	`rdyack_connect(src, ch_cmd_mofs_src),
	`rdyack_connect(dst, ch_cmd_mofs_src2),
	.skipped()
);
IgnoreIf#(1) u_ign_ch_addr(
	.cond(ch_skip),
	`rdyack_connect(src, ch_addr_mofs_src),
	`rdyack_connect(dst, ch_addr_mofs_src2),
	.skipped()
);
`else
Forward u_fwd_cmd(
	`clk_connect,
	`rdyack_connect(src, ch_cmd_mofs_src),
	`rdyack_connect(dst, ch_cmd_mofs_dst)
);
Forward u_fwd_addr(
	`clk_connect,
	`rdyack_connect(src, ch_addr_mofs_src),
	`rdyack_connect(dst, ch_addr_mofs_dst)
);
`endif

module ChunkHead(
	`clk_port,
	`rdyack_port(i_abofs),
	i_which,
	i_bofs,
	i_aofs,
	i_beg,
	i_end,
`ifdef SD
	i_syst_type,
`endif
	i_global_mofs,
	i_global_bshufs,
	i_bstrides_frac,
	i_bstrides_shamt,
	i_global_ashufs,
	i_astrides_frac,
	i_astrides_shamt,
`ifdef SD
	i_systolic_skip,
`endif
	`rdyack_port(o_mofs),
	o_which,
	o_mofs,
	o_id
`ifdef SD
	,
	o_skip
`endif
);
ChunkAddrLooper u_chal_issue(
	`clk_port,
	`rdyack_port(mofs),
	i_which,
	i_mofs,
	i_mpad,
	i_mbound,
	i_mlast,
	i_maddr,
	i_wrap,
`ifdef VERI_TOP_ChunkAddrLooper
	`rdyack2_port(cmd),
`else
	`rdyack_port(cmd),
`endif
	o_which,
	o_cmd_type, // 0,1,2
	o_cmd_islast,
	o_cmd_addr,
	o_cmd_addrofs,
	o_cmd_len
);
ChunkAddrLooper u_chal_receive(
	`clk_port,
	`rdyack_port(mofs),
	i_which,
	i_mofs,
	i_mpad,
	i_mbound,
	i_mlast,
	i_maddr,
	i_wrap,
`ifdef VERI_TOP_ChunkAddrLooper
	`rdyack2_port(cmd),
`else
	`rdyack_port(cmd),
`endif
	o_which,
	o_cmd_type, // 0,1,2
	o_cmd_islast,
	o_cmd_addr,
	o_cmd_addrofs,
	o_cmd_len
);
SramWriteCollector u_swc(
	`clk_port,
	`rdyack_port(alloc),
	i_id,
	i_size,
`ifdef SD
	i_skip,
`endif
	i_padv,
	`rdyack_port(cmd),
	i_which,
	i_cmd_type,
	i_cmd_islast,
	i_cmd_addrofs,
	i_cmd_len,
	`rdyack_port(dramrd),
	i_dramrd,
	`dval_port(w0),
	`dval_port(w1),
	o_id,
	o_hiaddr0,
	o_hiaddr1,
	o_data
);
BankSramButterflyWriteIf u_wif(
	i_xor_src,
	i_xor_swap,
	i_hiaddr,
	i_data,
	o_data
);
DeleteIf#(0) u_ign_if_not_last_addr(
	.cond(cal_addr_islast),
	`rdyack_connect(src, cal_addr),
	`rdyack_connect(dst, dramra),
	.skipped()
);
endmodule
