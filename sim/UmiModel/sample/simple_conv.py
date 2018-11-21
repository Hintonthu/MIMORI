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

from os import environ
from .. import UmiModel, npi, npd, newaxis, i16
from ..UmiModel import MemorySpace

n_inst = ([0,2,2,2,2,2,2], [3,3,3,3,3,3,4])
insts = npd.array([
	# OOOSSSSSRDDTWWWAAAAABBBBBCCCCC
	0b000000001110000000010000000000, # R0 = 1
	0b000000000110000000000000000000, # nop
	0b100000001111000110001000010001, # R0 = R0+I0*I1 (push)
	0b000000000000000100100000000000, # DRAM = T0
], dtype=npd.uint32)
p = npd.empty(1, UmiModel.PCFG_DTYPE)
a = npd.empty(1, UmiModel.ACFG_DTYPE)
um_i0 = npd.empty(1, UmiModel.UMCFG_DTYPE)
um_i1 = npd.empty(1, UmiModel.UMCFG_DTYPE)
um_o = npd.empty(1, UmiModel.UMCFG_DTYPE)
H, W = 40, 30

try:
	PAD = int(environ["PAD_VALUE"])
except:
	PAD = None
p['total'] = [1,1,1,1,H,W]
p['local'] = [1,1,1,1,16,16]
p['vsize'] = [1,1,1,1,4,8]
p['vshuf'] = [1,1,1,1,4,1]
p['dual_axis'] = 5
p['syst0_skip'] = 0
p['syst0_axis'] = -1
# This comment disables systolic sharing
# p['syst1_skip'] = 0
# p['syst1_axis'] = -1
p['syst1_skip'] = 0b1
p['syst1_axis'] = 5
a['total'] = [1,1,1,1,3,3]
a['local'] = [1,1,1,1,2,2]
um_i0['mwrap'].fill(UmiModel.MEM_WRAP if PAD is None else UmiModel.MEM_PAD)
um_i0['mlinear'] = [0]
um_i0['ustart'] = [[0,0,0,0,-1,-1,0,0,0,0,0,0],]
um_i0['ustride'] = [[0,0,0,0,1,1,0,0,0,0,1,1],]
um_i0['udim'] = [[0,0,0,0,2,3,0,0,0,0,2,3],]
um_i0['lmalign'] = [[306,306,306,18],]
um_i0['mwidth'] = [[1,1,100,301],]
um_i0['pad_value'] = 0 if PAD is None else PAD

um_i1['mwrap'].fill(UmiModel.MEM_WRAP)
um_i1['mlinear'] = [100000]
um_i1['ustart'] = [[0,0,0,0,0,0,0,0,0,0,0,0],]
um_i1['ustride'] = [[0,0,0,0,1,1,0,0,0,0,0,0],]
um_i1['udim'] = [[0,0,0,0,2,3,0,0,0,0,0,0],]
um_i1['lmalign'] = [[4,4,4,2],]
um_i1['mwidth'] = [[1,1,3,3],]

um_o['mwrap'].fill(UmiModel.MEM_WRAP)
um_o['mlinear'] = [300000]
um_o['ustart'] = [[0,0,0,0,0,0,0,0,0,0,0,0],]
um_o['ustride'] = [[0,0,0,0,0,0,0,0,0,0,1,1],]
um_o['udim'] = [[0,0,0,0,0,0,0,0,0,0,2,3],]
um_o['mwidth'] = [[1,1,1000,1000],]

cfg = UmiModel(p, a, um_i0, um_i1, um_o, insts, n_inst)
def VerfFunc(CSIZE):
	# init
	img = npd.random.randint(10, size=30100, dtype=i16)
	# conv = npd.arange(16, dtype=i16)
	conv = npd.ones(16, dtype=i16)
	result = npd.zeros(1000000, dtype=i16)
	img_2d = npd.reshape(img[:30100], (100,301))
	conv_2d = npd.reshape(conv[:9], (3,3))
	result_2d = npd.reshape(result, (1000,1000))
	gold_2d = npd.zeros((H,W), dtype=i16)
	yield MemorySpace([
		(     0, img   ),
		(100000, conv  ),
		(300000, result),
	], CSIZE)
	# check
	for y in range(H):
		for x in range(W):
			yy, xx = npd.ogrid[y-1:y+2, x-1:x+2]
			yyy = npd.fmax(yy, 0)
			xxx = npd.fmax(xx, 0)
			wind = img_2d[yyy,xxx]
			if not PAD is None:
				wind[npd.logical_or(yyy != yy, xxx != xx)] = PAD
			gold_2d[y,x] = (1 + npd.sum(wind * conv_2d, dtype=i16))
	npd.savetxt("img.txt",    img_2d[:H,:W], "%d")
	npd.savetxt("ans.txt",   gold_2d[:H,:W], "%d")
	npd.savetxt("res.txt", result_2d[:H,:W], "%d")
	for y in range(H):
		for x in range(W):
			gold = gold_2d[y,x]
			got = result_2d[y,x]
			assert gold == got, f"Error at pixel {y} {x}, {got} != {gold}"
	result_2d[:H,:W] = 0
	assert npd.all(result_2d == 0)
	print("SimpConv test result successes")
