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

n_i0 = ([0,0,0,0,0,0,0], [1,1,1,1,1,1,1])
n_i1 = ([0,0,0,0,0,0,0], [0,0,0,0,0,0,0])
n_o = ([0,0,0,0,0,0,0], [0,0,0,0,0,0,1])
n_inst = ([0,0,0,0,0,0,0], [0,0,0,0,0,0,6])
insts = npd.array([
	# OOOSSSSSRDDTWWWAAAAABBBBBCCCCC
	0b000000000111000000001000000000, # y1 (push)
	0b001000000111000000001001010000, # t0-y2 (push)
	0b100000001110000000001001010010, # R0 = 0+t0*t0
	0b000000000111000000001000000000, # x1 (push)
	0b001000000111000000001001010000, # t0-x2 (push)
	0b100000000000000110001001010010, # DRAM = R0+t0*t0 (DRAM)
], dtype=npd.uint32)
p = npd.empty(1, UmiModel.PCFG_DTYPE)
a = npd.empty(1, UmiModel.ACFG_DTYPE)
um_i0 = npd.empty(1, UmiModel.UMCFG_DTYPE)
um_i1 = npd.empty(0, UmiModel.UMCFG_DTYPE)
um_o = npd.empty(1, UmiModel.UMCFG_DTYPE)

H_grad, W_grad = 32, 64
p['total'] = [1,1,1,1,H_grad-2,W_grad-2]
p['local'] = [1,1,1,1,16,32]
p['vsize'] = [1,1,1,1,1,32]
p['vshuf'] = [1,1,1,1,1,1]
p['syst0_skip'] = 0
p['syst0_axis'] = -1
p['syst1_skip'] = 0
p['syst1_axis'] = -1
a['total'] = [1,1,1,1,3,3]
a['local'] = [1,1,1,1,3,3]
um_i0['mwrap'].fill(UmiModel.MEM_WRAP)
um_i0['mlinear'] = [10000]
um_i0['ustart'] = [[0,0,0,0,-1,-1,0,0,0,0,1,1],]
um_i0['ustride'] = [[0,0,0,0,1,1,0,0,0,0,1,1],]
um_i0['udim'] = [[0,0,0,0,2,3,0,0,0,0,2,3],]
um_i0['lmwidth'] = [[1,1,18,34],]
um_i0['lmalign'] = [[640,640,640,34],]
um_i0['mwidth'] = [[1,1,H_grad,W_grad],]
um_o['mwrap'].fill(UmiModel.MEM_WRAP)
um_o['mlinear'] = [300000]
um_o['ustart'] = [[0,0,0,0,0,0,0,0,0,0,0,0],]
um_o['ustride'] = [[0,0,0,0,0,0,0,0,0,0,1,1],]
um_o['udim'] = [[0,0,0,0,0,0,0,0,0,0,2,3],]
um_o['mwidth'] = [[1,1,H_grad,W_grad],]

cfg = UmiModel(p, a, um_i0, um_i1, um_o, insts, n_i0, n_i1, n_o, n_inst)
cfg.add_lut("stencil0", [1,69,34,36])
def VerfFunc(CSIZE):
	# init
	img_flat = npi.arange(W_grad*H_grad, dtype=i16)
	# img_flat = npd.random.randint(10, size=W_grad*H_grad, dtype=i16)
	gradm_flat = npd.zeros(W_grad*H_grad, i16)
	img = npd.reshape(img_flat, (H_grad,W_grad))
	gradm = npd.reshape(gradm_flat, (H_grad,W_grad))
	gradm_gold = npd.square(img[1:-1,2:]-img[1:-1,:-2]) + npd.square(img[2:,1:-1]-img[:-2,1:-1])
	yield MemorySpace([
		(10000, img_flat),
		(300000, gradm_flat),
	], CSIZE)
	# check
	npd.savetxt("grad_img.txt", img, fmt="%4d")
	npd.savetxt("grad_result.txt", gradm[:H_grad-2,:W_grad-2], fmt="%4d")
	npd.savetxt("grad_gold.txt", gradm_gold, fmt="%4d")
	assert npd.all(gradm_gold == gradm[:H_grad-2,:W_grad-2])
	gradm[:H_grad-2,:W_grad-2] = 0
	assert not npd.any(gradm)
	print("Gradient test result successes") 
