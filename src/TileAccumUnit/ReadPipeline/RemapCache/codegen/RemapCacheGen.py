# Copyright 2018 Yu Sheng Lin

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
import numpy as np

class Swapper(object):
	__slots__ = ['swap_idx']
	CFG = {
		5: [(5,1),(5,2),(2,1),(3,1),(3,2),(5,1),(5,2),(5,4)],
	}
	@staticmethod
	def Swap(arr, idx, swap):
		return arr[idx] if swap else arr

	def MagicSwap(self, arr, bitmask):
		for i in range(self.swap_idx.shape[0]):
			arr = self.Swap(arr, self.swap_idx[i], (bitmask>>i)&1)
		return arr

	def __init__(self, n):
		val = np.arange(1<<n, dtype='i4')
		idx = np.arange(n, dtype='i4')
		order2 = 1 << idx
		bm = np.bitwise_and(val >> idx[:,np.newaxis], 1)
		swap_idx = list()
		for bits, rot in self.CFG[n]:
			assert bits > rot and rot > 0
			bit_idx = np.concatenate((
				np.arange(n-bits, dtype='i4'),
				np.arange(n-rot, n, dtype='i4'),
				np.arange(n-bits, n-rot, dtype='i4'),
			))
			swap_idx.append(np.dot(order2, bm[bit_idx, :]))
		swap_idx.append(np.bitwise_xor(order2[:,np.newaxis], val))
		self.swap_idx = np.vstack(swap_idx)

class RmcGen(object):
	import jinja2 as jj
	env = jj.Environment(loader=jj.FileSystemLoader("."))
	tmpl_csu = env.get_template("RemapCacheSwapUnit.jinja2.sv")
	tmpl_atu = env.get_template("RemapCacheLowRotate.jinja2.sv")
	def __init__(self, lg_n):
		switches = Swapper(lg_n).swap_idx
		n = 1 << lg_n
		with open(f"RemapCacheSwapUnit{lg_n}.sv", 'w') as fp:
			s = RmcGen.tmpl_csu.render(
				lg_n=lg_n,
				sw=switches,
				sw_layer=switches.shape[0],
				n=n,
			)
			fp.write(s)
		with open(f"RemapCacheLowRotate{lg_n}.sv", 'w') as fp:
			cfg = Swapper.CFG[lg_n]
			s = RmcGen.tmpl_atu.render(
				cfg=cfg,
				sw_layer=len(cfg),
				lg_n=lg_n,
				n=n,
			)
			fp.write(s)

if __name__ == '__main__':
	RmcGen(5)
