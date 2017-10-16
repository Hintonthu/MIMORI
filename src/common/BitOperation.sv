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

module Reverse(i, o);

parameter N = 10;
input [N-1:0] i;
output logic [N-1:0] o;
always_comb for (int j = 0; j < N; j++) begin
	o[i] = i[N-1-j];
end

endmodule

module FindFromLsb(i, prefix, detect);

parameter N = 10;
parameter ONE = 1;
localparam LG = $clog2(N);
input [N-1:0] i;
output logic [N-1:0] prefix;
output logic [N:0] detect;
always_comb begin
	prefix = ONE ? i : ~i;
	for (int j = 0; j < LG; j++) begin
		prefix = prefix | (prefix<<(1<<j));
	end
	detect = {1'b1, prefix} & {~prefix, 1'b1};
end

endmodule

module FindFromMsb(i, prefix, detect);

parameter N = 10;
parameter ONE = 1;
localparam LG = $clog2(N);
input [N-1:0] i;
output logic [N-1:0] prefix;
output logic [N:0] detect;
always_comb begin
	prefix = ONE ? i : ~i;
	for (int j = 0; j < LG; j++) begin
		prefix = prefix | (prefix>>(1<<j));
	end
	detect = {1'b1, ~prefix} & {prefix, 1'b1};
end

endmodule
