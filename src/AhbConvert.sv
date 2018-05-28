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

module AhbConvert(
	// AHB
	input HCLK,
	input HRESETn,
	input        HSEL,
	input [31:0] HADDR,
	input        HWRITE,
	input [ 1:0] HTRANS,
	input [ 2:0] HSIZE,
	input [ 2:0] HBURST,
	output logic        HREADY,
	output logic [ 1:0] HRESP,
	// converted
	output logic        o_we,
	output logic [29:0] o_waddr,
	output logic        o_re,
	output logic [29:0] o_raddr
);

logic valid_trans, valid_write, valid_read, conflict;

assign HRESP = '0;
always_comb begin
	o_raddr = HADDR[31:2];
	valid_trans = HSEL && HTRANS[1];
	valid_write = valid_trans && HWRITE;
	valid_read = valid_trans && !HWRITE;
	conflict = o_we && valid_read && (o_raddr == o_waddr);
	HREADY = !conflict;
	o_re = valid_read && !conflict;
end

always_ff @(posedge HCLK or negedge HRESETn) begin
	if (!HRESETn) begin
		o_we <= 1'b0;
	end else begin
		o_we <= valid_write && HREADY;
	end
end

always_ff @(posedge HCLK or negedge HRESETn) begin
	if (!HRESETn) begin
		o_waddr <= '0;
	end else if (valid_write) begin
		o_waddr <= HADDR[31:2];
	end
end

endmodule
