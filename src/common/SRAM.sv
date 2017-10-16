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

import SramCfg::*;

module SRAMDualPort(
	i_clk,
	i_we,
	i_re,
	i_waddr,
	i_wdata,
	i_raddr,
	o_rdata
);

parameter BW = 8;
parameter NDATA = 16;
localparam CLOG2_NDATA = $clog2(NDATA);

input i_clk;
input i_we;
input i_re;
input        [CLOG2_NDATA-1:0] i_waddr;
input        [BW-1:0]          i_wdata;
input        [CLOG2_NDATA-1:0] i_raddr;
output logic [BW-1:0]          o_rdata;

generate if (SramCfg::GEN_MODE == SramCfg::BEHAVIOUR) begin: sim_mode
	logic [BW-1:0] data_r [NDATA];
	always @(posedge i_clk) begin
		if (i_we) begin
			data_r[i_waddr] <= i_wdata;
		end
		if (i_re) begin
			if (!i_we || i_waddr != i_raddr) begin
				o_rdata <= data_r[i_raddr];
			end else begin
				case (SramCfg::CON_RW)
					SramCfg::UNDEF: begin o_rdata <= 'x; end
					SramCfg::OLD:   begin o_rdata <= data_r[i_raddr]; end
					SramCfg::NEW:   begin o_rdata <= i_wdata; end
				endcase
			end
		end
	end
end else begin: fail
	initial begin
		$display("SRAM configuration (%d) wrong!", SramCfg::GEN_MODE);
		$abort();
	end
end endgenerate

endmodule
