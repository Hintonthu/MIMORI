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


module LinearCollector(
	`clk_port,
	`rdyack_port(range),
	i_bofs,
	i_abeg,
	i_aend,
	i_beg,
	i_end,
	`rdyack_port(src_linear),
	i_linear,
	`rdyack_port(dst_linears),
	o_bofs,
	o_abeg,
	o_aend,
	o_linears
);
//======================================
// Parameter
//======================================
parameter LBW = TauCfg::LOCAL_ADDR_BW0;
localparam WBW = TauCfg::WORK_BW;
localparam N_ICFG = TauCfg::N_ICFG;
// derived
localparam ICFG_BW = $clog2(N_ICFG+1);

`clk_input;
`rdyack_input(range);
input [WBW-1:0]     i_bofs [VDIM];
input [WBW-1:0]     i_abeg [VDIM];
input [WBW-1:0]     i_aend [VDIM];
input [ICFG_BW-1:0] i_beg;
input [ICFG_BW-1:0] i_end;
`rdyack_input(src_linear);
input [LBW-1:0] i_linear;
`rdyack_output(dst_linears);
output logic [WBW-1:0] o_bofs    [VDIM];
output logic [WBW-1:0] o_abeg    [VDIM];
output logic [WBW-1:0] o_aend    [VDIM];
output logic [LBW-1:0] o_linears [N_ICFG];

//======================================
// Internal
//======================================
`rdyack_logic(brd);
`rdyack_logic(collect);
logic [ICFG_BW-1:0] end_r;
logic [ICFG_BW-1:0] cur_idx_r;
logic [ICFG_BW-1:0] cur_idx1;
logic [ICFG_BW-1:0] cur_idx_w;
logic islast_idx;

//======================================
// Combinational
//======================================
always_comb begin
	cur_idx1 = cur_idx_r + 'b1;
	cur_idx_w = range_ack ? i_beg : cur_idx1;
	islast_idx = cur_idx1 == end_r;
	src_linear_ack = src_linear_rdy && collect_rdy;
	collect_ack = islast_idx && src_linear_ack;
end

//======================================
// Submodule
//======================================
ForwardSlow u_fwd(
	`clk_connect,
	`rdyack_connect(src, range),
	`rdyack_connect(dst, brd)
);
BroadcastInorder#(2) u_brd(
	`clk_connect,
	`rdyack_connect(src, brd),
	.dst_rdys({dst_linears_rdy,collect_rdy}),
	.dst_acks({dst_linears_ack,collect_ack})
);

//======================================
// Sequential
//======================================
`ff_rst
	end_r <= '0;
	for (int i = 0; i < VDIM; i++) begin
		o_bofs[i] <= '0;
		o_abeg[i] <= '0;
		o_aend[i] <= '0;
	end
`ff_cg(range_ack)
	end_r <= i_end;
	o_bofs <= i_bofs;
	o_abeg <= i_abeg;
	o_aend <= i_aend;
`ff_end

`ff_rst
	cur_idx_r <= '0;
`ff_cg(range_ack || src_linear_ack)
	cur_idx_r <= cur_idx_w;
`ff_end

genvar gi;
generate for (gi = 0; gi < N_ICFG; gi++) begin: collect_linear
always_ff @(posedge i_clk or negedge i_rst) begin
	if (!i_rst) begin
		o_linears[gi] <= '0;
	end else if (src_linear_ack && (gi == cur_idx_r)) begin
		o_linears[gi] <= i_linear;
	end
end
end endgenerate

endmodule
