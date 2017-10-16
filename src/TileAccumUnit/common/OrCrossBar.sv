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

module OrCrossBar(
	i_data,
	i_routing,
	o_data,
	o_mask
);

//======================================
// Parameter
//======================================
parameter BW = 16;
parameter N_SRC = 16;
parameter N_DST = 8;
parameter TR = 0;

//======================================
// I/O
//======================================
input        [BW-1:0]    i_data    [N_SRC];
input        [N_SRC-1:0] i_routing [N_DST];
output logic [BW-1:0]    o_data    [N_DST];
output logic [N_DST-1:0] o_mask;

//======================================
// Combinational
//======================================
always_comb begin
	for (int i = 0; i < N_DST; i++) begin
		o_data[i] = '0;
		o_mask[i] = |i_routing[i];
		for (int j = 0; j < N_SRC; j++) begin
			if (TR ? i_routing[j][i] : i_routing[i][j]) begin
				o_data[i] = o_data[i] | i_data[j];
			end
		end
	end
end

endmodule
