// Copyright
// Yu Sheng Lin, 2016-2018
// Yen Hsi Wang, 2017

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
`include "common/SFifo.sv"
`include "TileAccumUnit/ReadPipeline/ChunkAddrLooper/ChunkRowStart.sv"
`include "TileAccumUnit/ReadPipeline/ChunkAddrLooper/ChunkRow.sv"

module ChunkAddrLooper(
	`clk_port,
	`rdyack_port(mofs),
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
	o_cmd_type, // 0,1,2
	o_cmd_islast,
	o_cmd_addr,
	o_cmd_addrofs,
	o_cmd_len
);

//======================================
// Parameter
//======================================
parameter LBW = TauCfg::LOCAL_ADDR_BW0;
localparam GBW = TauCfg::GLOBAL_ADDR_BW;
localparam DIM = TauCfg::DIM;
localparam CSIZE = TauCfg::CACHE_SIZE;
localparam VSIZE = TauCfg::VSIZE;
// derived
localparam V_BW = $clog2(VSIZE);
localparam C_BW = $clog2(CSIZE);
localparam V_BW1 = $clog2(VSIZE+1);
localparam DBW = $clog2(DIM);

//======================================
// I/O
//======================================
`clk_input;
`rdyack_input(mofs);
input [GBW-1:0]  i_mofs    [DIM];
input [V_BW-1:0] i_mpad    [DIM];
input [GBW-1:0]  i_mbound  [DIM];
input [GBW-1:0]  i_mlast   [DIM];
input [GBW-1:0]  i_maddr;
input            i_wrap;
`ifdef VERI_TOP_ChunkAddrLooper
`rdyack2_output(cmd);
`else
`rdyack_output(cmd);
`endif
output logic [1:0]       o_cmd_type;
output logic             o_cmd_islast;
output logic [GBW-1:0]   o_cmd_addr;
output logic [C_BW-1:0]  o_cmd_addrofs;
output logic [V_BW1-1:0] o_cmd_len;

//======================================
// Internal
//======================================
`rdyack_logic(wait_fin);
`rdyack_logic(s0_src);
`rdyack_logic(s01);
`rdyack_logic(s12);
`rdyack_logic(s23);
`rdyack_logic(s34);
`rdyack_logic(s4_dst);
logic [GBW-1:0]  s01_linear;
logic            s01_rowlast;
logic [V_BW-1:0] s01_pad;
logic            s01_rvalid;
logic [0:0]      s1_load_nxt;
logic [1:0]      s1_load_new;
logic [GBW-1:0]  s12_linear  [2];
logic            s12_rowlast [2];
logic [V_BW-1:0] s12_pad     [2];
logic            s12_rvalid  [2];
logic [1:0]       s23_cmd_type;
logic             s23_cmd_blklast;
logic [GBW-1:0]   s23_cmd_addr;
logic [C_BW-1:0]  s23_cmd_addrofs;
logic [V_BW1-1:0] s23_cmd_len;
logic             s34_cmd_blklast;
logic [1:0]       s34_cmd_type;
logic             s34_cmd_slast;
logic [GBW-1:0]   s34_cmd_addr;
logic [C_BW-1:0]  s34_cmd_addrofs;
logic [V_BW1-1:0] s34_cmd_len;
logic             cmd_blklast;
logic             s4_dst_pass;

//======================================
// Submodule
//======================================
Broadcast#(2) u_brd0(
	`clk_connect,
	`rdyack_connect(src, mofs),
	.acked(),
	.dst_rdys({wait_fin_rdy,s0_src_rdy}),
	.dst_acks({wait_fin_ack,s0_src_ack})
);
ChunkRowStart u_s0_row_start(
	`clk_connect,
	`rdyack_connect(mofs, s0_src),
	.i_mofs(i_mofs),
	.i_mpad(i_mpad),
	.i_mbound(i_mbound),
	.i_mlast(i_mlast),
	.i_maddr(i_maddr),
	.i_wrap(i_wrap),
	`rdyack_connect(row, s01),
	.o_row_linear(s01_linear),
	.o_row_islast(s01_rowlast),
	.o_row_pad(s01_pad),
	.o_row_valid(s01_rvalid)
);
SFifoCtrl#(2) u_s1(
	`clk_connect,
	`rdyack_connect(src, s01),
	`rdyack_connect(dst, s12),
	.o_load_nxt(s1_load_nxt),
	.o_load_new(s1_load_new)
);
ChunkRow u_s2_row(
	`clk_connect,
	`rdyack_connect(row, s12),
	.i_row_linear(s12_linear[0]),
	.i_row_islast(s12_rowlast[0]),
	.i_row_pad(s12_pad[0]),
	.i_row_valid(s12_rvalid[0]),
	.i_l(i_mofs[DIM-1]),
	.i_n(i_mlast[DIM-1]),
	.i_bound(i_mbound[DIM-1]),
	.i_wrap(i_wrap),
	`rdyack_connect(cmd, s23),
	.o_cmd_type(s23_cmd_type),
	.o_cmd_islast(s23_cmd_blklast),
	.o_cmd_addr(s23_cmd_addr),
	.o_cmd_addrofs(s23_cmd_addrofs),
	.o_cmd_len(s23_cmd_len)
);
Forward u_s3(
	`clk_connect,
	`rdyack_connect(src, s23),
	`rdyack_connect(dst, s34)
);
Forward u_s4(
	`clk_connect,
	`rdyack_connect(src, s34),
	`rdyack_connect(dst, s4_dst)
);
ForwardIf u_fwd_if_cmd(
	.cond(s4_dst_pass),
	`rdyack_connect(src, s4_dst),
	`rdyack_connect(dst, cmd)
);

//======================================
// Combinational
//======================================
assign o_cmd_islast = cmd_blklast || s34_cmd_addr != o_cmd_addr; // last address or last command of block
assign s4_dst_pass = s34_rdy || cmd_blklast;
assign wait_fin_ack = cmd_blklast && cmd_ack;

//======================================
// Sequential
//======================================
`ff_rst
	s12_linear[0] <= '0;
	s12_rowlast[0] <= 1'b0;
	s12_pad[0] <= '0;
	s12_rvalid[0] <= 1'b0;
`ff_cg(s1_load_nxt[0] || s1_load_new[0])
	s12_linear[0] <= s1_load_new[0] ? s01_linear : s12_linear[1];
	s12_rowlast[0] <= s1_load_new[0] ? s01_rowlast : s12_rowlast[1];
	s12_pad[0] <= s1_load_new[0] ? s01_pad : s12_pad[1];
	s12_rvalid[0] <= s1_load_new[0] ? s01_rvalid : s12_rvalid[1];
`ff_end

`ff_rst
	s12_linear[1] <= '0;
	s12_rowlast[1] <= 1'b0;
	s12_pad[1] <= '0;
	s12_rvalid[1] <= 1'b0;
`ff_cg(s1_load_new[1])
	s12_linear[1] <= s01_linear;
	s12_rowlast[1] <= s01_rowlast;
	s12_pad[1] <= s01_pad;
	s12_rvalid[1] <= s01_rvalid;
`ff_end

`ff_rst
	s34_cmd_blklast <= 1'b0;
	s34_cmd_type <= 2'b0;
	s34_cmd_addr <= '0;
	s34_cmd_addrofs <= '0;
	s34_cmd_len <= '0;
`ff_cg(s23_ack)
	s34_cmd_blklast <= s23_cmd_blklast;
	s34_cmd_type <= s23_cmd_type;
	s34_cmd_addr <= s23_cmd_addr;
	s34_cmd_addrofs <= s23_cmd_addrofs;
	s34_cmd_len <= s23_cmd_len;
`ff_end

`ff_rst
	o_cmd_type <= 2'b0;
	o_cmd_addr <= '0;
	o_cmd_addrofs <= '0;
	o_cmd_len <= '0;
	cmd_blklast <= 1'b0;
`ff_cg(s34_ack)
	o_cmd_type <= s34_cmd_type;
	o_cmd_addr <= s34_cmd_addr;
	o_cmd_addrofs <= s34_cmd_addrofs;
	o_cmd_len <= s34_cmd_len;
	cmd_blklast <= s34_cmd_blklast;
`ff_end

endmodule
