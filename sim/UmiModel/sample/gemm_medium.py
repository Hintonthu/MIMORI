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
	0b100000001110000110001000010001, # R0 = R0+I0*I1
	0b000000000110000000000000000000, # nop
	0b000000000000000110000000000000, # DRAM = R0
], dtype=npd.uint32)
p = npd.empty(1, UmiModel.PCFG_DTYPE)
a = npd.empty(1, UmiModel.ACFG_DTYPE)
um_i0 = npd.empty(1, UmiModel.UMCFG_DTYPE)
um_i1 = npd.empty(1, UmiModel.UMCFG_DTYPE)
um_o = npd.empty(1, UmiModel.UMCFG_DTYPE)

p['total'] = [1,1,1,1,128,64]
p['local'] = [1,1,1,1,64,32]
p['vsize'] = [1,1,1,1,1,32]
p['vshuf'] = [1,1,1,1,1,1]
p['syst0_skip'] = 0b1
p['syst0_axis'] = 5
p['syst1_skip'] = 0b1
p['syst1_axis'] = 4
a['total'] = [1,1,1,1,1,64]
a['local'] = [1,1,1,1,1,16]
um_i0['mwrap'].fill(UmiModel.MEM_WRAP)
um_i0['mlinear'] = [0]
um_i0['ustart'] = [[0,0,0,0,0,0,0,0,0,0,0,0],]
um_i0['ustride'] = [[0,0,0,0,0,1,0,0,0,0,1,0],]
um_i0['udim'] = [[0,0,0,0,0,3,0,0,0,0,2,0],]
um_i0['lmwidth'] = [[1,1,64,16],]
um_i0['lmalign'] = [[1024,1024,1024,16],]
um_i0['mwidth'] = [[1,1,128,64],]
um_i1['mlinear'] = [100000]
um_i1['ustart'] = [[0,0,0,0,0,0,0,0,0,0,0,0],]
um_i1['ustride'] = [[0,0,0,0,0,1,0,0,0,0,0,1],]
um_i1['udim'] = [[0,0,0,0,0,2,0,0,0,0,0,3],]
um_i1['lmwidth'] = [[1,1,16,32],]
um_i1['lmalign'] = [[512,512,512,32],]
um_i1['mwidth'] = [[1,1,64,64],]
um_o['mwrap'].fill(UmiModel.MEM_WRAP)
um_o['mlinear'] = [300000]
um_o['ustart'] = [[0,0,0,0,0,0,0,0,0,0,0,0],]
um_o['ustride'] = [[0,0,0,0,0,0,0,0,0,0,1,1],]
um_o['udim'] = [[0,0,0,0,0,0,0,0,0,0,2,3],]
um_o['mwidth'] = [[1,1,128,64],]

cfg = UmiModel(p, a, um_i0, um_i1, um_o, insts, n_inst)
def VerfFunc(CSIZE):
	# init
	A_flat = npd.random.randint(0, 3, 128*64, i16)
	B_flat = npd.random.randint(3, 6, 64*64, i16)
	C_flat = npd.zeros(128*64, dtype=i16)
	A = npd.reshape(A_flat, (128,64))
	B = npd.reshape(B_flat, (64,64))
	C = npd.reshape(C_flat, (128,64))
	C_gold = npd.dot(A, B)
	yield MemorySpace([
		(     0, A_flat),
		(100000, B_flat),
		(300000, C_flat),
	], CSIZE)
	# check
	assert npd.all(C == C_gold)
	print("MatMul test result successes")
