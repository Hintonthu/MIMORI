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

n_i0 = ([0,0,0,0,0,0,0], [1,1,1,1,1,1,1])
n_i1 = ([0,0,0,0,0,0,0], [0,0,0,0,0,0,0])
n_o = ([0,0,0,0,0,0,0], [0,0,0,0,0,0,1])
n_inst = ([0,0,0,0,0,0,0], [1,1,1,1,1,1,1])
insts = npd.array([
	# OOOSSSSSRDDTWWWAAAAABBBBBCCCCC
	0b000000000000000000001000000000, # DRAM = I0+0 (DRAM)
], dtype=npd.uint32)
p = npd.empty(1, UmiModel.PCFG_DTYPE)
a = npd.empty(1, UmiModel.ACFG_DTYPE)
um_i0 = npd.empty(1, UmiModel.UMCFG_DTYPE)
um_i1 = npd.empty(0, UmiModel.UMCFG_DTYPE)
um_o = npd.empty(1, UmiModel.UMCFG_DTYPE)

H_ds, W_ds = 33, 121
H_ds4, W_ds4 = (H_ds+3)//4, (W_ds+3)//4
p['total'] = [1,1,1,1,H_ds4,W_ds4]
p['local'] = [1,1,1,1,4,32]
p['vsize'] = [1,1,1,1,1,32]
p['vshuf'] = [1,1,1,1,1,1]
p['syst0_skip'] = 0
p['syst0_axis'] = -1
p['syst1_skip'] = 0
p['syst1_axis'] = -1
a['total'] = [1,1,1,1,1,1]
a['local'] = [1,1,1,1,1,1]
um_i0['mwrap'].fill(UmiModel.MEM_WRAP)
um_i0['mlinear'] = [10000]
um_i0['ustart'] = [[0,0,0,0,0,0,0,0,0,0,0,0],]
um_i0['ustride'] = [[0,0,0,0,0,0,0,0,0,0,1,4],]
um_i0['udim'] = [[0,0,0,0,0,0,0,0,0,0,1,3],]
um_i0['lmwidth'] = [[1,4,1,125],]
um_i0['lmalign'] = [[512,512,125,125],]
um_i0['mwidth'] = [[1,H_ds4,4,W_ds],]
um_o['mwrap'].fill(UmiModel.MEM_WRAP)
um_o['mlinear'] = [300000]
um_o['ustart'] = [[0,0,0,0,0,0,0,0,0,0,0,0],]
um_o['ustride'] = [[0,0,0,0,0,0,0,0,0,0,1,1],]
um_o['udim'] = [[0,0,0,0,0,0,0,0,0,0,2,3],]
um_o['mwidth'] = [[1,1,H_ds4,W_ds4],]

cfg = UmiModel(p, a, um_i0, um_i1, um_o, insts, n_i0, n_i1, n_o, n_inst)
def VerfFunc(CSIZE):
	# init
	hi_flat = npd.random.randint(10, size=10000, dtype=i16)
	lo_flat = npd.zeros(2000, i16)
	hi = npd.reshape(hi_flat[:H_ds*W_ds], (H_ds,W_ds))
	lo = npd.reshape(lo_flat[:H_ds4*W_ds4], (H_ds4,W_ds4))
	yield MemorySpace([
		(10000, hi_flat),
		(300000, lo_flat),
	], CSIZE)
	npd.savetxt("hi.txt", hi, "%d")
	npd.savetxt("lo_gold.txt", hi[::4,::4], "%d")
	npd.savetxt("lo.txt", lo, "%d")
	# check
	assert npd.all(lo == hi[::4,::4])
	print("Downsample test result successes")
