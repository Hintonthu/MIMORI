// Copyright 2016 Yu Sheng Lin

// This file is part of Ocean.

// MIMORI is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// MIMORI is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with Ocean.  If not, see <http://www.gnu.org/licenses/>.

import TauCfg::*;

module TauCollector(
	`clk_port,
	i_i0_id_end,
	i_i1_id_end,
	i_o_id_end,
	`rdyack_port(bofs),
	i_bofs,
	`rdyack_port(i0_mofs),
	i_i0_mofs,
	`rdyack_port(i1_mofs),
	i_i1_mofs,
	`rdyack_port(o_mofs),
	i_o_mofs,
	`rdyack_port(core),
	o_core_bofs,
	`rdyack_port(i0_bofs),
	o_i0_bofs,
	o_i0_mofss,
	`rdyack_port(i1_bofs),
	o_i1_bofs,
	o_i1_mofss,
	`rdyack_port(o_bofs),
	o_o_bofs,
	o_o_mofss
);

//======================================
// Parameter
//======================================
localparam WBW = TauCfg::WORK_BW;
localparam GBW = TauCfg::GLOBAL_ADDR_BW;
localparam DIM = TauCfg::DIM;
localparam N_ICFG = TauCfg::N_ICFG;
localparam N_OCFG = TauCfg::N_OCFG;
// derived
localparam ICFG_BW = $clog2(N_ICFG+1);
localparam OCFG_BW = $clog2(N_OCFG+1);
localparam DIM_BW = $clog2(DIM);

//======================================
// I/O
//======================================
`clk_input;
input [ICFG_BW-1:0] i_i0_id_end;
input [ICFG_BW-1:0] i_i1_id_end;
input [OCFG_BW-1:0] i_o_id_end;
`rdyack_input(bofs);
input [WBW-1:0] i_bofs [DIM];
`rdyack_input(i0_mofs);
input [GBW-1:0] i_i0_mofs [DIM];
`rdyack_input(i1_mofs);
input [GBW-1:0] i_i1_mofs [DIM];
`rdyack_input(o_mofs);
input [GBW-1:0] i_o_mofs [1];
`rdyack_output(core);
output logic [WBW-1:0] o_core_bofs [DIM];
`rdyack_output(i0_bofs);
output logic [WBW-1:0] o_i0_bofs  [DIM];
output logic [GBW-1:0] o_i0_mofss [N_ICFG][DIM];
`rdyack_output(i1_bofs);
output logic [WBW-1:0] o_i1_bofs  [DIM];
output logic [GBW-1:0] o_i1_mofss [N_ICFG][DIM];
`rdyack_output(o_bofs);
output logic [WBW-1:0] o_o_bofs  [DIM];
output logic [GBW-1:0] o_o_mofss [N_OCFG][1];

//======================================
// Internal
//======================================
`rdyack_logic(fwd_out);
`rdyack_logic(i0_raw);
`rdyack_logic(i1_raw);
`rdyack_logic(o_raw);
logic [WBW-1:0] core_bofs_w [DIM];
logic [GBW-1:0] i0_mofss_w [N_ICFG][DIM];
logic [GBW-1:0] i1_mofss_w [N_ICFG][DIM];
logic [GBW-1:0] o_mofss_w [N_OCFG][1];
logic [N_ICFG-1:0] i0_id_r;
logic [N_ICFG-1:0] i0_id_w;
logic [N_ICFG-1:0] i1_id_r;
logic [N_ICFG-1:0] i1_id_w;
logic [N_OCFG-1:0] o_id_r;
logic [N_OCFG-1:0] o_id_w;
logic i0_z;
logic i1_z;
logic o_z;
logic i0_islast;
logic i1_islast;
logic o_islast;

//======================================
// Submodule
//======================================
Forward u_fwd(
	`clk_connect,
	`rdyack_connect(src, bofs),
	`rdyack_connect(dst, fwd_out)
);
Broadcast#(4) u_brd(
	`clk_connect,
	`rdyack_connect(src, fwd_out),
	.acked(),
	.dst_rdys({core_rdy,i0_raw_rdy,i1_raw_rdy,o_raw_rdy}),
	.dst_acks({core_ack,i0_raw_ack,i1_raw_ack,o_raw_ack})
);

//======================================
// Combinational
//======================================
always_comb begin
	i0_z = i_i0_id_end == '0;
	i0_islast = i0_id_r == i_i0_id_end;
	o_i0_bofs = o_core_bofs;
	i0_raw_ack = i0_raw_rdy && i0_z || i0_bofs_ack;
	i0_bofs_rdy = i0_raw_rdy && !i0_z && i0_islast;
	i0_mofs_ack = i0_mofs_rdy && !i0_islast;
	casez ({bofs_ack, i0_mofs_ack})
		2'b1?: i0_id_w = '0;
		2'b01: i0_id_w = i0_id_r + 'b1;
		2'b00: i0_id_w = i0_id_r;
	endcase
end

always_comb begin
	i1_z = i_i1_id_end == '0;
	i1_islast = i1_id_r == i_i1_id_end;
	o_i1_bofs = o_core_bofs;
	i1_raw_ack = i1_raw_rdy && i1_z || i1_bofs_ack;
	i1_bofs_rdy = i1_raw_rdy && !i1_z && i1_islast;
	i1_mofs_ack = i1_mofs_rdy && !i1_islast;
	casez ({bofs_ack, i1_mofs_ack})
		2'b1?: i1_id_w = '0;
		2'b01: i1_id_w = i1_id_r + 'b1;
		2'b00: i1_id_w = i1_id_r;
	endcase
end

always_comb begin
	o_z = i_o_id_end == '0;
	o_islast = o_id_r == i_o_id_end;
	o_o_bofs = o_core_bofs;
	o_raw_ack = o_raw_rdy && o_z || o_bofs_ack;
	o_bofs_rdy = o_raw_rdy && !o_z && o_islast;
	o_mofs_ack = o_mofs_rdy && !o_islast;
	casez ({bofs_ack, o_mofs_ack})
		2'b1?: o_id_w = '0;
		2'b01: o_id_w = o_id_r + 'b1;
		2'b00: o_id_w = o_id_r;
	endcase
end

//======================================
// Sequential
//======================================
always_ff @(posedge i_clk or negedge i_rst) for (int i = 0; i < N_ICFG; i++) begin
	for (int j = 0; j < DIM; j++) begin
		if (!i_rst) begin
				o_i0_mofss[i][j] <= '0;
		end else if (i0_mofs_ack && i == i0_id_r) begin
			o_i0_mofss[i][j] <= i_i0_mofs[j];
		end
	end
end

always_ff @(posedge i_clk or negedge i_rst) for (int i = 0; i < N_ICFG; i++) begin
	for (int j = 0; j < DIM; j++) begin
		if (!i_rst) begin
			o_i1_mofss[i][j] <= '0;
		end else if (i1_mofs_ack && i == i1_id_r) begin
			o_i1_mofss[i][j] <= i_i1_mofs[j];
		end
	end
end

always_ff @(posedge i_clk or negedge i_rst) for (int i = 0; i < N_OCFG; i++) begin
	if (!i_rst) begin
		o_o_mofss[i][0] <= '0;
	end else if (o_mofs_ack && i == o_id_r) begin
		o_o_mofss[i][0] <= i_o_mofs[0];
	end
end

`ff_rst
	for (int i = 0; i < DIM; i++) begin
		o_core_bofs[i] <= '0;
	end
`ff_cg(bofs_ack)
	o_core_bofs <= i_bofs;
`ff_end

`ff_rst
	i0_id_r <= '0;
`ff_cg(bofs_ack || i0_mofs_ack)
	i0_id_r <= i0_id_w;
`ff_end

`ff_rst
	i1_id_r <= '0;
`ff_cg(bofs_ack || i1_mofs_ack)
	i1_id_r <= i1_id_w;
`ff_end

`ff_rst
	o_id_r <= '0;
`ff_cg(bofs_ack || o_mofs_ack)
	o_id_r <= o_id_w;
`ff_end

endmodule
