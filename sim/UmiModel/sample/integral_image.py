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
n_o = ([0,0,0,0,0,0,0], [1,1,1,1,1,1,1])
n_inst = ([0,1,1,1,1,1,1], [2,2,2,2,2,2,2])
insts = npd.array([
	# OOOSSSSSRDDTWWWAAAAABBBBBCCCCC
	0b000000000111000000000000000000, # 0 (push)
	0b001000000001000100101000000000, # T0+I0 (push, DRAM>>0)
], dtype=npd.uint32)
p = npd.empty(1, UmiModel.PCFG_DTYPE)
a = npd.empty(1, UmiModel.ACFG_DTYPE)
um_i0 = npd.empty(1, UmiModel.UMCFG_DTYPE)
um_i1 = npd.empty(0, UmiModel.UMCFG_DTYPE)
um_o = npd.empty(1, UmiModel.UMCFG_DTYPE)

p['total'] = [1,1,1,1,1,100]
p['local'] = [1,1,1,1,1,32]
p['vsize'] = [1,1,1,1,1,32]
p['vshuf'] = [1,1,1,1,1,1]
p['syst0_skip'] = 0
p['syst0_axis'] = -1
p['syst1_skip'] = 0
p['syst1_axis'] = -1
a['total'] = [1,1,1,1,1,100]
a['local'] = [1,1,1,1,1,32]
um_i0['mwrap'].fill(UmiModel.MEM_WRAP)
um_i0['mlinear'] = [0]
um_i0['ustart'] = [[0,0,0,0,0,0,0,0,0,0,0,0],]
um_i0['ustride'] = [[0,0,0,0,0,1,0,0,0,0,0,1],]
um_i0['udim'] = [[0,0,0,0,0,3,0,0,0,0,0,2],]
um_i0['lmwidth'] = [[1,1,32,32],]
um_i0['lmalign'] = [[1024,1024,1024,32],]
um_i0['mwidth'] = [[1,1,100,100],]
um_o['mwrap'].fill(UmiModel.MEM_WRAP)
um_o['mlinear'] = [300000]
um_o['ustart'] = [[0,0,0,0,0,0,0,0,0,0,0,0],]
um_o['ustride'] = [[0,0,0,0,0,1,0,0,0,0,0,1],]
um_o['udim'] = [[0,0,0,0,0,2,0,0,0,0,0,3],]
um_o['mwidth'] = [[1,1,100,100],]

cfg = UmiModel(p, a, um_i0, um_i1, um_o, insts, n_i0, n_i1, n_o, n_inst)
def VerfFunc(CSIZE):
	# init
	# img = npd.random.randint(10, size=10000, dtype=i16)
	img = npd.ones(10000, dtype=i16)
	result = npd.zeros(10000, dtype=i16)
	img_2d = npd.reshape(img, (100,100))
	result_2d = npd.reshape(result, (100,100))
	yield MemorySpace([
		(     0, img   ),
		(300000, result),
	], CSIZE)
	# check
	golden = npd.cumsum(img_2d, axis=1, dtype=i16).T
	check_res = result_2d != golden
	fail = npd.any(check_res)
	if fail:
		npd.savetxt("intimg_i.txt", result_2d[:100,:100], "%d")
		npd.savetxt("intimg_o.txt", golden[:100,:100], "%d")
		assert not fail
	assert not npd.any(check_res)
	print("IntImg(1D) test result successes")
