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

W, H, C, K = 128, 96, 2, 3
assert K%2 == 1
K2 = K//2
Kl, Kr = -K2, K2+1
n_inst = ([0,0,0,0,0,2,2], [3,3,4,4,4,4,4])
insts = npd.array([
	# OOOSSSSSRDDTWWWAAAAABBBBBCCCCC
	0b000000001110000000000000000000, # R0 = 0
	0b000000000110000000000000000000, # nop
	0b100000001111000110001000010001, # R0 = R0+I0*I1 (push)
	0b000000000000000100100000000000, # DRAM = T0
], dtype=npd.uint32)
p = npd.empty(1, UmiModel.PCFG_DTYPE)
a = npd.empty(1, UmiModel.ACFG_DTYPE)
um_i0 = npd.empty(1, UmiModel.UMCFG_DTYPE)
um_i1 = npd.empty(1, UmiModel.UMCFG_DTYPE)
um_o = npd.empty(1, UmiModel.UMCFG_DTYPE)

try:
	PAD = int(environ["PAD_VALUE"])
except:
	PAD = None
p['total'] = [1,1,1,1,C,W]
p['local'] = [1,1,1,1,2,32]
p['vsize'] = [1,1,1,1,1,32]
p['vshuf'] = [1,1,1,1,1,1]
p['syst0_skip'] = 0
p['syst0_axis'] = -1
p['syst1_skip'] = 0b1
p['syst1_axis'] = 5
a['total'] = [1,1,1,H,3,3]
a['local'] = [1,1,1,12,3,3]
um_i0['mwrap'].fill(UmiModel.MEM_WRAP if PAD is None else UmiModel.MEM_PAD)
um_i0['mlinear'] = [0]
um_i0['ustart'] = [[0,0,0,-1,0,0,0,0,0,0,0,-1],]
um_i0['ustride'] = [[0,0,0,1,1,1,0,0,0,0,1,1],]
um_i0['udim'] = [[0,0,0,2,2,3,0,0,0,0,1,3],]
um_i0['lmalign'] = [[952,952,476,34],]
um_i0['mwidth'] = [[1,C,H,W],]
um_i0['pad_value'] = 0 if PAD is None else PAD

um_i1['mwrap'].fill(UmiModel.MEM_WRAP)
um_i1['mlinear'] = [1000000]
um_i1['ustart'] = [[0,0,0,0,0,0,0,0,0,0,0,0],]
um_i1['ustride'] = [[0,0,0,0,1,1,0,0,0,0,1,0],]
um_i1['udim'] = [[0,0,0,0,2,3,0,0,0,0,1,0],]
um_i1['lmalign'] = [[18,18,9,3],]
um_i1['mwidth'] = [[1,C,K,K],]

um_o['mwrap'].fill(UmiModel.MEM_WRAP)
um_o['mlinear'] = [2000000]
um_o['ustart'] = [[0,0,0,0,0,0,0,0,0,0,0,0],]
um_o['ustride'] = [[0,0,0,1,0,0,0,0,0,0,1,1],]
um_o['udim'] = [[0,0,0,2,0,0,0,0,0,0,1,3],]
um_o['mwidth'] = [[1,C,H,W],]

cfg = UmiModel(p, a, um_i0, um_i1, um_o, insts, n_inst)
def VerfFunc(CSIZE):
	ALIGN = lambda x: ((x-1)//CSIZE+1)*CSIZE
	ISZ = W*H*C
	KSZ = K*K*C
	OSZ = W*H*C
	# init
	img = npd.random.randint(10, size=ALIGN(ISZ), dtype=i16)
	conv = npd.random.randint(10, size=ALIGN(KSZ), dtype=i16)
	result = npd.zeros(ALIGN(OSZ), dtype=i16)
	img_3d = npd.reshape(img[:ISZ], (C,H,W))
	conv_3d = npd.reshape(conv[:KSZ], (C,K,K))
	result_3d = npd.reshape(result[:OSZ], (C,H,W))
	gold_3d = npd.zeros_like(result_3d, dtype=i16)
	yield MemorySpace([
		(      0, img   ),
		(1000000, conv  ),
		(2000000, result),
	], CSIZE)
	# check
	for c in range(C):
		for y in range(H):
			for x in range(W):
				yy, xx = npd.ogrid[y+Kl:y+Kr, x+Kl:x+Kr]
				yyy = npd.clip(yy, 0, H-1)
				xxx = npd.clip(xx, 0, W-1)
				wind = img_3d[c,yyy,xxx]
				if not PAD is None:
					wind[npd.logical_or(yyy != yy, xxx != xx)] = PAD
				gold_3d[c,y,x] = npd.sum(wind * conv_3d[c], dtype=i16)
	npd.savetxt("img_dwc.txt", npd.reshape(   img_3d, (-1,W)), "%d")
	npd.savetxt("ans_dwc.txt", npd.reshape(  gold_3d, (-1,W)), "%d")
	npd.savetxt("res_dwc.txt", npd.reshape(result_3d, (-1,W)), "%d")
	for c in range(C):
		for y in range(H):
			for x in range(W):
				gold = gold_3d[c,y,x]
				got = result_3d[c,y,x]
				assert gold == got, f"Error at pixel {c} {y} {x}, {got} != {gold}"
	print("DW Convolution test result successes")
