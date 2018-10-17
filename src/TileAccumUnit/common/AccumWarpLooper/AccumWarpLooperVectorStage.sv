// Copyright 2016,2018 Yu Sheng Lin

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
`include "TileAccumUnit/common/BofsExpand.sv"

module AccumWarpLooperVectorStage(
	`clk_port,
	`rdyack_port(src),
`ifdef SD
	i_syst_type,
`endif
	i_id,
	i_linear,
	i_bofs,
	i_retire,
	i_islast,
	i_bboundary,
	i_bsubofs,
	i_bsub_lo_order,
	i_mofs_bsubsteps,
`ifdef SD
	i_systolic_skip,
`endif
	`rdyack_port(dst),
	o_id,
	o_address,
	o_valid,
	o_retire,
	`dval_port(fin)
);

//======================================
// Parameter
//======================================
import TauCfg::*;
parameter N_CFG = TauCfg::N_ICFG;
parameter ABW = TauCfg::GLOBAL_ADDR_BW;
parameter SYST = 1;
localparam WBW = TauCfg::WORK_BW;
localparam VDIM = TauCfg::VDIM;
localparam VSIZE = TauCfg::VSIZE;
// derived
localparam NCFG_BW = $clog2(N_CFG+1);
localparam CV_BW = $clog2(VSIZE);
localparam CCV_BW = $clog2(CV_BW+1);

//======================================
// I/O
//======================================
`clk_input;
`rdyack_input(src);
`ifdef SD
input [STO_BW-1:0]  i_syst_type;
`endif
input [NCFG_BW-1:0] i_id;
input [ABW-1:0]     i_linear;
input [WBW-1:0]     i_bofs  [VDIM];
input               i_retire;
input               i_islast;
input [WBW-1:0]     i_bboundary      [VDIM];
input [CV_BW-1:0]   i_bsubofs [VSIZE][VDIM];
input [CCV_BW-1:0]  i_bsub_lo_order  [VDIM];
input [ABW-1:0]     i_mofs_bsubsteps [N_CFG][CV_BW];
`ifdef SD
input [N_CFG-1:0]   i_systolic_skip;
`endif
`rdyack_output(dst);
output logic [NCFG_BW-1:0] o_id;
output logic [ABW-1:0]     o_address [VSIZE];
output logic [VSIZE-1:0]   o_valid;
output logic               o_retire;
`dval_output(fin);

//======================================
// Internal
//======================================
logic [ABW-1:0] address_w [VSIZE];
logic [VSIZE-1:0] valid_w;
logic [ABW-1:0] mofs_bsubstep [CV_BW];
logic islast_r;
logic [WBW-1:0] vector_blockofs [VSIZE][VDIM];
logic syst_skip;

//======================================
// Submodule
//======================================
Forward u_fwd(
	`clk_connect,
	`rdyack_connect(src, src),
	`rdyack_connect(dst, dst)
);
BofsExpand u_bexp(
	.i_bofs(i_bofs),
	.i_bboundary(i_bboundary),
	.i_bsubofs(i_bsubofs),
	.i_bsub_lo_order(i_bsub_lo_order),
	.o_vector_bofs(vector_blockofs),
	.o_valid(valid_w)
);

//======================================
// Combinational
//======================================
always_comb for (int i = 0; i < CV_BW; i++) begin
	mofs_bsubstep[i] = i_mofs_bsubsteps[i_id][i];
end
`ifdef SD
assign syst_skip = i_systolic_skip[i_id] && `IS_FROM_SIDE(i_syst_type);
`endif
assign fin_dval = dst_ack && islast_r;
always_comb begin
	for (int i = 0; i < VSIZE; i++) begin
		address_w[i] = '0;
		for (int j = 0; j < CV_BW; j++) begin
			if (((i>>j)&1) != 0) begin
				address_w[i] = address_w[i] + mofs_bsubstep[j];
			end
		end
		address_w[i] = address_w[i] + i_linear;
	end
end

//======================================
// Sqeuential
//======================================
`ff_rst
	o_id <= '0;
	o_valid <= '0;
	o_retire <= 1'b0;
	islast_r <= 1'b0;
`ff_cg(src_ack)
	o_id <= i_id;
	o_valid <= valid_w;
	o_retire <= i_retire;
	islast_r <= i_islast;
`ff_end

`ff_rst
	for (int i = 0; i < VSIZE; i++) begin
		o_address[i] <= '0;
	end
`ifdef SD
`ff_cg(src_ack && (SYST == 0 || !syst_skip))
`else
`ff_cg(src_ack)
`endif
	o_address <= address_w;
`ff_end

endmodule
