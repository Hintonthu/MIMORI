#!/usr/bin/env python
# Copyright 2016-2018 Yu Sheng Lin

# This file is part of MIMORI.

# MIMORI is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# MIMORI is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with MIMORI.  If not, see <http://www.gnu.org/licenses/>.

from .. import UmiModel, npi, npd, newaxis, i16
from ..UmiModel import MemorySpace

n_inst = ([0,2,2,2,2,2,2], [3,3,3,3,3,3,5])
insts = npd.array([
	# OOOSSSSSRDDTWWWAAAAABBBBBCCCCC
	0b000000001110000000000000000000, # R0 = 0
	0b000000000110000000000000000000, # nop
	0b011000001110000110001000010001, # R0 = R0+abs(I0-I1)
	0b000000000110000000000000000000, # nop
	0b000000000000000110000000000000, # DRAM = R0
], dtype=npd.uint32)
p = npd.empty(1, UmiModel.PCFG_DTYPE)
a = npd.empty(1, UmiModel.ACFG_DTYPE)
um_i0 = npd.empty(1, UmiModel.UMCFG_DTYPE)
um_i1 = npd.empty(1, UmiModel.UMCFG_DTYPE)
um_o = npd.empty(1, UmiModel.UMCFG_DTYPE)

p['total'] = [1,1,4,4,8,8] ## 4x4 block & 8x8 search range
p['local'] = [1,1,1,2,4,8]
p['vsize'] = [1,1,1,1,4,8]
p['vshuf'] = [1,1,1,1,1,1]
p['syst0_skip'] = 0
p['syst0_axis'] = -1
p['syst1_skip'] = 0b1
p['syst1_axis'] = 4
a['total'] = [1,1,1,1,8,8]
a['local'] = [1,1,1,1,8,8]
um_i0['mwrap'].fill(UmiModel.MEM_WRAP)
um_i0['mlinear'] = [0]
um_i0['ustart'] = [[0,0,0,0,0,0,0,0,4,4,-4,-4],]
um_i0['ustride'] = [[0,0,0,0,1,1,0,0,8,8,1,1],]
um_i0['udim'] = [[0,0,0,0,2,3,0,0,2,3,2,3],]
um_i0['lmalign'] = [[288,288,288,24],]
um_i0['mwidth'] = [[1,1,50,50],]
um_i1['mlinear'] = [100000]
um_i1['ustart'] = [[0,0,0,0,0,0,0,0,0,0,0,0],]
um_i1['ustride'] = [[0,0,0,0,1,1,0,0,8,8,0,0],]
um_i1['udim'] = [[0,0,0,0,2,3,0,0,2,3,0,0],]
um_i1['lmalign'] = [[128,128,128,16],]
um_i1['mwidth'] = [[1,1,32,32],]
um_o['mwrap'].fill(UmiModel.MEM_WRAP)
um_o['mlinear'] = [300000]
um_o['ustart'] = [[0,0,0,0,0,0,0,0,0,0,0,0],]
um_o['ustride'] = [[0,0,0,0,0,0,0,0,1,1,1,1],]
um_o['udim'] = [[0,0,0,0,0,0,0,0,0,1,2,3],]
um_o['mwidth'] = [[4,4,8,8],]

cfg = UmiModel(p, a, um_i0, um_i1, um_o, insts, n_inst)
def VerfFunc(CSIZE):
	# init
	prev_flat = npd.random.randint(0, 128, 50*50, i16)
	cur_flat = npd.random.randint(0, 128, 32*32, i16)
	diff_flat = npd.zeros(4*4*8*8, dtype=i16)
	prev = npd.reshape(prev_flat, (50,50))
	cur = npd.reshape(cur_flat, (32,32))
	diff = npd.reshape(diff_flat, (4*4,8*8))
	diff_gold = npd.empty_like(diff)
	for y in range(4):
		for x in range(4):
			by = y*8
			bx = x*8
			for dy in range(8):
				for dx in range(8):
					bdy = by+dy
					bdx = bx+dx
					diff_gold[y*4+x,dy*8+dx] = npd.sum(npd.abs(
						cur[by:by+8,bx:bx+8] - prev[bdy:bdy+8,bdx:bdx+8]
					))
	yield MemorySpace([
		(     0, prev_flat),
		(100000, cur_flat),
		(300000, diff_flat),
	], CSIZE)
	# check
	npd.savetxt("me_result.txt", diff, fmt="%d")
	npd.savetxt("me_gold.txt", diff_gold, fmt="%d")
	assert npd.all(diff == diff_gold)
	print("Motion estimation test result successes")
