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
import Default::*;

module AccumWarpLooperVectorStage(
	`clk_port,
	`rdyack_port(src),
	i_id,
	i_linear1,
	i_linear2,
	i_bofs,
	i_retire,
	i_islast,
	i_bboundary,
	i_bsubofs,
	i_bsub_lo_order,
	i_mofs_bsubsteps,
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
parameter N_CFG = Default::N_CFG;
parameter ABW = Default::ABW;
localparam WBW = TauCfg::WORK_BW;
localparam DIM = TauCfg::DIM;
localparam VSIZE = TauCfg::VECTOR_SIZE;
// derived
localparam NCFG_BW = $clog2(N_CFG+1);
localparam CV_BW = $clog2(VSIZE);
localparam CCV_BW = $clog2(CV_BW+1);

//======================================
// I/O
//======================================
`clk_input;
`rdyack_input(src);
input [NCFG_BW-1:0] i_id;
input [ABW-1:0]     i_linear1;
input [ABW-1:0]     i_linear2;
input [WBW-1:0]     i_bofs  [DIM];
input               i_retire;
input               i_islast;
input [WBW-1:0]     i_bboundary      [DIM];
input [CV_BW-1:0]   i_bsubofs [VSIZE][DIM];
input [CCV_BW-1:0]  i_bsub_lo_order  [DIM];
input [ABW-1:0]     i_mofs_bsubsteps [N_CFG][CV_BW];
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
logic [WBW-1:0] vector_blockofs [VSIZE][DIM];

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
assign mofs_bsubstep = i_mofs_bsubsteps[i_id];
assign fin_dval = dst_ack && islast_r;
always_comb begin
	for (int i = 0; i < VSIZE; i++) begin
		address_w[i] = i_linear1 + i_linear2;
		for (int j = 0; j < CV_BW; j++) begin
			if (((i>>j)&1) != 0) begin
				address_w[i] = address_w[i] + mofs_bsubstep[j];
			end
		end
	end
end

//======================================
// Sqeuential
//======================================
`ff_rst
	o_id <= '0;
	for (int i = 0; i < VSIZE; i++) begin
		o_address[i] <= '0;
	end
	o_valid <= '0;
	o_retire <= 1'b0;
	islast_r <= 1'b0;
`ff_cg(src_ack)
	o_id <= i_id;
	o_address <= address_w;
	o_valid <= valid_w;
	o_retire <= i_retire;
	islast_r <= i_islast;
`ff_end

endmodule
