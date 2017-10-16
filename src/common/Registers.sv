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

module Registers(
	i_clk,
	i_rst,
	i_we,
	i_waddr,
	i_wdata,
	i_raddr,
	o_rdata
);

parameter BW = 8;
parameter NDATA = 16;
localparam CLOG2_NDATA = $clog2(NDATA);

input i_clk;
input i_rst;
input i_we;
input        [CLOG2_NDATA-1:0] i_waddr;
input        [BW-1:0]          i_wdata;
input        [CLOG2_NDATA-1:0] i_raddr;
output logic [BW-1:0]          o_rdata;

logic [BW-1:0] data_r [NDATA];

assign o_rdata = data_r[i_raddr];

always_ff @(posedge i_clk or negedge i_rst) begin
	for (int i = 0; i < NDATA; i++) begin
		if (!i_rst) begin
			data_r[i] <= '0;
		end else if (i_we && i == i_waddr) begin
			data_r[i] <= i_wdata;
		end
	end
end

endmodule

module Registers2D(
	i_clk,
	i_rst,
	i_we,
	i_waddr,
	i_wdata,
	i_raddr,
	o_rdata
);

parameter BW = 8;
parameter D1 = 8;
parameter NDATA = 16;
localparam CLOG2_NDATA = $clog2(NDATA);

input i_clk;
input i_rst;
input i_we;
input        [CLOG2_NDATA-1:0] i_waddr;
input        [BW-1:0]          i_wdata[D1];
input        [CLOG2_NDATA-1:0] i_raddr;
output logic [BW-1:0]          o_rdata[D1];

reg [BW-1:0] data_r [NDATA][D1];

assign o_rdata = data_r[i_raddr];

always_ff @(posedge i_clk or negedge i_rst) begin
	for (int i = 0; i < NDATA; i++) begin
		for (int j = 0; j < D1; j++) begin
			if (!i_rst) begin
				data_r[i][j] <= '0;
			end else if (i_we && i == i_waddr) begin
				data_r[i][j] <= i_wdata[j];
			end
		end
	end
end

endmodule
