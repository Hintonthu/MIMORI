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

n_inst = ([0,0,0,0,0,0,0], [3,3,3,3,3,3,3])
insts = npd.array([
	# OOOSSSSSRDDTWWWAAAAABBBBBCCCCC
	0b111011010111000000000000000000, # pid[5] (push)
	0b111011000111000000000000000000, # pid[4] (push)
	0b100000000000000100111001010100, # DRAM = T1+T0*100
], dtype=npd.uint32)
p = npd.empty(1, UmiModel.PCFG_DTYPE)
a = npd.empty(1, UmiModel.ACFG_DTYPE)
um_i0 = npd.empty(0, UmiModel.UMCFG_DTYPE)
um_i1 = npd.empty(0, UmiModel.UMCFG_DTYPE)
um_o = npd.empty(1, UmiModel.UMCFG_DTYPE)
p['total'] = [1,1,1,1,60,30]
p['local'] = [1,1,1,1,8,16]
p['vsize'] = [1,1,1,1,2,16]
p['vshuf'] = [1,1,1,1,1,1]
p['syst0_skip'] = 0
p['syst0_axis'] = -1
p['syst1_skip'] = 0
p['syst1_axis'] = -1
a['total'] = [1,1,1,1,1,1]
a['local'] = [1,1,1,1,1,1]
um_o['mwrap'].fill(UmiModel.MEM_WRAP)
um_o['mlinear'] = [300000]
um_o['ustart'] = [[0,0,0,0,0,0,0,0,0,0,0,0],]
um_o['ustride'] = [[0,0,0,0,0,0,0,0,0,0,1,1],]
um_o['udim'] = [[0,0,0,0,0,0,0,0,0,0,2,3],]
um_o['mwidth'] = [[1,1,60,30],]

cfg = UmiModel(p, a, um_i0, um_i1, um_o, insts, n_inst)
cfg.add_lut("const", [100])
def VerfFunc(CSIZE):
	# init
	idx_flat = npd.zeros(60*30, i16)
	idx = npd.reshape(idx_flat, (60,30))
	y, x = npd.ogrid[0:60, 0:30]
	idx_gold = (y*100+x).astype(i16)
	yield MemorySpace([
		(300000, idx_flat),
	], CSIZE)
	# check
	npd.savetxt("idx.txt", idx, fmt="%d")
	print(idx)
	print(idx_gold)
	assert npd.all(idx == idx_gold)
	print("Index generation test result successes") 
