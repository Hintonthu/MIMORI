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

function [CLOG2_NBANK-1:0] XMask;
	input [CLOG2_NDATA-1:0]  i_hiaddr;
	input [CLOG2_NBANK-1:0]  i_xor_mask;
	input [CCLOG2_NBANK-1:0] i_xor_scheme [CLOG2_NBANK];
	logic [CLOG2_NBANK-1:0]  xor_selected;
	for (int i = 0; i < CLOG2_NBANK; i++) begin
		xor_selected[i] = i_hiaddr[i_xor_scheme[i]];
	end
	XMask = xor_selected & i_xor_mask;
endfunction
