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
from . import npi, npd, newaxis, i16
import bisect

class MemorySpace(object):
	def __init__(self, mranges, n):
		mranges.sort(key=lambda x: x[0])
		self.keys = [x[0] for x in mranges]
		self.values = [x[1] for x in mranges]
		self.n = n

	def FindRange(self, a):
		idx = bisect.bisect_right(self.keys, a)-1
		return a-self.keys[idx], self.values[idx]

	def WriteScalarMask(self, a, d, m):
		m = npd.bitwise_and(m[0]>>npi.arange(self.n), 1) != 0
		aa, mem = self.FindRange(a[0])
		mem[aa:aa+self.n][m] = d[m]

	def Write(self, a, d, m):
		aa, mem = self.FindRange(a[0])
		mem[aa:aa+self.n][m] = d[m]

	def Read(self, a):
		aa, mem = self.FindRange(a[0])
		return mem[aa:aa+self.n]

def ExtractUFloat(i, frac_bw):
	i = int(i)
	if i < 0:
		raise ValueError("i({}) must be non-negative.".format(i))
	elif i == 0:
		return 0, 0
	expo = 0
	while (i&1) == 0:
		i >>= 1
		expo += 1
	if (i>>frac_bw) != 0:
		raise ValueError("Fraction part is too long.")
	return expo, i

def SkipInteger(i):
	return (1, 0) if i == 0 else (0, i-1)

def Clog2(i, exact=False):
	ii = i
	i -= 1
	ret = 0
	while i != 0:
		ret += 1
		i >>= 1
	assert not exact or (1<<ret) == ii
	return ret

def TrailingZeros(i):
	ret = 0
	while (i&1) == 0:
		ret += 1
		i >>= 1
	return ret

class UmiModel(object):
	MEM_PAD, MEM_WRAP = range(2)
	N_TAU = 4
	VSIZE = 32
	DIM = 4
	VDIM = 6
	BW = 16
	ABW = 32
	LBW0 = 11
	LBW1 = 10
	STRIDE_SIG_BW = 8
	STRIDE_EXP_BW = 3
	LG_VSIZE = Clog2(VSIZE, True)
	LLG_VSIZE = Clog2(LG_VSIZE+1)
	LG_DIM = Clog2(DIM)
	LG_VDIM = Clog2(VDIM)
	DRAM_ALIGN = 8
	DRAM_ALIGN_MASK = DRAM_ALIGN-1
	VSIZE_MASK = VSIZE-1
	# please check define.sv
	limits = {
		"const": 4,
		"texture": 4,
		"stencil0": 31,
		"stencil1": 31,
	}

	@staticmethod
	def ToIntTypes(l, n):
		assert len(l) == len(n)
		return [(i, npd.int32, j) for i, j in zip(l, n)]

	@staticmethod
	def ListAppendAccum(l, appme):
		for i in appme:
			l.append(l[-1] + i)

	PCFG_DTYPE = ToIntTypes.__func__([
		'total', 'local', 'vsize', 'vshuf', # user filled
		'end', 'lg_vsize', 'lg_vshuf',
		'syst0_skip', 'syst0_axis',
		'syst1_skip', 'syst1_axis',
	], [VDIM,VDIM,VDIM,VDIM,VDIM,VDIM,VDIM,1,1,1,1])
	ACFG_DTYPE = ToIntTypes.__func__([
		'total', 'local', # user filled
		'end'
	], [VDIM,VDIM,VDIM])
	UMCFG_DTYPE = ToIntTypes.__func__([
		'mwidth', 'mlinear', 'ustart', 'ustride', 'udim', 'lmwidth', 'lmalign',
		'mwrap', 'pad_value', # user filled
		'ustride_frac', 'ustride_shamt', # derived from ustride
		'mboundary', # derived from mwitdth
		'mboundary_lmwidth', # derived from mboundary and lmdiwth
		'mstart', # precomuted offsets
		'lmpad', 'lmsize', # derived from lmwidth, lmalign
		'vlinear', # precomputed vector addresses local/global for I/O
		'xor_src', 'xor_swap', # XOR scheme: TODO document
		'local_adr', # Internal status
	], [
		DIM,1,2*VDIM,2*VDIM,2*VDIM,DIM,DIM,
		1,1,
		2*VDIM,2*VDIM,
		DIM,
		DIM,
		DIM,
		DIM,1,
		VSIZE,
		LG_VSIZE,1,
		N_TAU,
	])
	# cmd_type 0: fill addr[ofs:ofs+len] to SRAM
	# cmd_type 1: repeat addr[ofs] len times to SRAM
	# cmd_type 2: repeat padding value of len times to SRAM
	# in either case, len <= VSIZE
	DRAM_RD_TXDTYPE = ToIntTypes.__func__(
		['cmd_type', 'islast', 'addr', 'ofs', 'len'],
		[1,1,1,1,1]
	)
	DIM_O = npi.ones(DIM)
	DIM_Z = npi.zeros(DIM)
	VDIM_O = npi.ones(VDIM)
	VDIM_Z = npi.zeros(VDIM)

	@staticmethod
	def _CalMemBound(width):
		return npd.fliplr(npi.cumprod(npd.fliplr(width), axis=1))

	@staticmethod
	def _SelRangeIdx(curs, step, end):
		fv = npd.zeros(curs.shape[0], dtype=npd.bool)
		l = UmiModel.VDIM-npd.argmin(
			npd.column_stack((npd.fliplr(curs == 0), fv)),
			axis=1
		)
		r = npd.argmin(
			npd.column_stack((npd.fliplr(curs+step == end), fv)),
			axis=1
		)
		return l, r

	@staticmethod
	def _SelRangeSel(l, r, n):
		return npd.column_stack((n[0][l], n[1][r]))

	@staticmethod
	def _CvtRange(n):
		return (
			npi.array(n[0]),
			npi.array(n[1]),
		)

	@staticmethod
	def _SelRetireIdx(curs, step, end):
		tv = npd.ones(curs.shape[0], dtype=npd.bool)
		return npd.argmax(
			npd.column_stack((curs+step != end, tv)),
			axis=1
		)

	@staticmethod
	def _SelRetireSel(idx, n):
		nn = npd.roll(n[0], -1)
		nn[-1] = n[1][-1]
		return nn[idx]

	@staticmethod
	def _FlatRangeNorep(rg):
		return npd.concatenate([
			npi.arange(rg[i,0], rg[i,1]) for i in range(rg.shape[0])
		])

	@staticmethod
	def _CalStride(um, is_local):
		mul = npd.copy(um['lmalign'] if is_local else um['mboundary'])
		mul = npd.roll(mul, -1, axis=1)
		mul[:,-1] = 1
		idx = npi.arange(um.shape[0])[:, newaxis]
		return (
			  mul[idx, um['udim'][:,UmiModel.VDIM:]]
			* um['ustride'][:,UmiModel.VDIM:]
		)

	@staticmethod
	def _CalXor(strides, xor_src, xor_swap):
		s = npd.empty_like(strides)
		n = s.size
		for i in range(n):
			st = strides[i]
			if st != 0:
				s[i] = TrailingZeros(strides[i])
		min_element = npd.argmin(s)
		xor_swap[0] = min_element
		ind = npd.roll(npi.arange(n), min_element)
		xor_src[:] = -1
		for i in range(n):
			dst = ind[i]
			src = s[i]
			if strides[i] != 0 and src != dst:
				assert xor_src[dst] == -1, "Cannot create a suitable scheme"
				xor_src[dst] = src

	@staticmethod
	def _CountBlockRoutine(ref_local, ref_end=None):
		"""
			Input:
				ref_local & ref_last = (d,)
			Output:
				n_ref(int)
				ref_ofs = (n_ref, d)
		"""
		d = ref_local.shape[0]
		idx_end = ref_local if ref_end is None else ref_end//ref_local
		ref_ofs = npi.indices(idx_end)
		ref_ofs = npd.reshape(ref_ofs, (d,-1)).T
		if not ref_end is None:
			ref_ofs *= ref_local
		n_ref = ref_ofs.shape[0]
		return n_ref, ref_ofs

	@staticmethod
	def _InitUmcfg(umcfg, n, v_nd, is_local, xor_fallback):
		# layout of umcfg
		#   aaaapppp
		n_total = n[1][-1]
		assert n_total == umcfg.shape[0]
		# Calaulate memory shape cumsum (multiplier, boundary)
		umcfg['mboundary'] = UmiModel._CalMemBound(umcfg['mwidth'])
		if is_local:
			umcfg['lmsize'] = umcfg['lmalign'][:,0]
			# Calaulate pad of local memory
			pad = npd.copy(umcfg['lmalign'])
			pad[:,:-1] -= umcfg['lmwidth'][:,:-1] * umcfg['lmalign'][:,1:]
			pad[:,-1] -= umcfg['lmwidth'][:,-1]
			umcfg['lmpad'] = npd.fliplr(npi.cumsum(npd.fliplr(pad), axis=1))
			umcfg['mboundary_lmwidth'] = umcfg['lmwidth']
			umcfg['mboundary_lmwidth'][:,:-1] *= umcfg['mboundary'][:,1:]
		# Calculate vector related
		if is_local:
			umcfg['vlinear'] = npd.dot(UmiModel._CalStride(umcfg, True), v_nd)
			# if true, then use the value provided by users
			if not xor_fallback:
				idx = npi.ones(UmiModel.LG_VSIZE) << npi.arange(UmiModel.LG_VSIZE)
				for i in range(n_total):
					# use i:i+1 to pass by reference
					UmiModel._CalXor(umcfg['vlinear'][i,idx], umcfg['xor_src'][i,:], umcfg['xor_swap'][i:i+1])
		else:
			umcfg['vlinear'] = npd.dot(UmiModel._CalStride(umcfg, False), v_nd)
		for i in range(n_total):
			for j in range(UmiModel.VDIM*2):
				s, f = ExtractUFloat(umcfg['ustride'][i,j], UmiModel.STRIDE_EXP_BW)
				assert s < (1<<UmiModel.STRIDE_EXP_BW), "Stride too large"
				umcfg['ustride_frac'][i,j] = f
				umcfg['ustride_shamt'][i,j] = s
		ums = umcfg['mstart']
		ums.fill(0)
		idx = npi.arange(n_total)
		for i in range(UmiModel.VDIM):
			ums[idx,umcfg['udim'][:,              i]] += umcfg['ustart'][:,              i]
			ums[idx,umcfg['udim'][:,UmiModel.VDIM+i]] += umcfg['ustart'][:,UmiModel.VDIM+i]
		return umcfg

	@staticmethod
	def _InitApcfg(pcfg, acfg):
		# Init
		VDIM = UmiModel.VDIM
		# Convert some values
		pcfg['end'] = ((pcfg['total']-1)//pcfg['local']+1)*pcfg['local']
		acfg['end'] = ((acfg['total']-1)//acfg['local']+1)*acfg['local']
		hi_nd_stride = pcfg['vsize']*pcfg['vshuf']
		assert not npd.any(pcfg['local'] % hi_nd_stride)
		# Convert some more complex values
		# Since a field of structured array of shape (1,) is [[x,x,x,x]], so [0] is required
		pl = pcfg['local'][0]
		pv = pcfg['vsize'][0]
		pf = pcfg['vshuf'][0]
		plv = pcfg['lg_vsize'][0]
		plf = pcfg['lg_vshuf'][0]
		for i in range(UmiModel.VDIM):
			plv[i] = Clog2(pv[i], True)
			plf[i] = Clog2(pf[i], True)
		v_nd = npi.indices(pv).reshape((VDIM, -1)).T << plf
		warp_nd = npi.indices(pl >> plv).reshape((VDIM, -1)).T
		warp_nd = (warp_nd >> plf << (plv+plf)) + npd.bitwise_and(warp_nd, (1<<plf)-1)
		return pcfg, acfg, warp_nd, v_nd

	@staticmethod
	def _BA2M(bofs, aofs, stride_idx, um, is_local):
		VDIM = UmiModel.VDIM
		n_result = stride_idx.size
		idx = npi.arange(n_result)
		mofs = npi.zeros((n_result, UmiModel.DIM))
		def ShufAccum(ofs, st, sh):
			str_ofs = ofs * st[stride_idx]
			for i in range(VDIM):
				mofs[idx,sh[stride_idx,i]] += str_ofs[:,i]
		ShufAccum(bofs, um['ustride'][:,VDIM:], um['udim'][:,VDIM:])
		ShufAccum(aofs, um['ustride'][:,:VDIM], um['udim'][:,:VDIM])
		mbound = um['lmalign'] if is_local else um['mboundary']
		mofs[:,:-1] *= mbound[:,1:]
		return mofs

	def __init__(self, pcfg, acfg, umcfg_i0, umcfg_i1, umcfg_o, insts, n_i0, n_i1, n_o, n_inst, xor_fallback=False):
		# convert to internal format
		# v_nd_shuf, v_nd = head of warp, warp sub idx
		self.pcfg, self.acfg, self.warp_nd, self.v_nd = UmiModel._InitApcfg(pcfg, acfg)
		self.sram_cur = [0, 0]
		self.n_i0 = self._CvtRange(n_i0)
		self.n_i1 = self._CvtRange(n_i1)
		v_ndT = self.v_nd.T
		self.umcfg_i0 = self._InitUmcfg(umcfg_i0, n_i0, v_ndT, is_local=True, xor_fallback=xor_fallback)
		self.umcfg_i1 = self._InitUmcfg(umcfg_i1, n_i1, v_ndT, is_local=True, xor_fallback=xor_fallback)
		self.n_o = self._CvtRange(n_o)
		self.umcfg_o = self._InitUmcfg(umcfg_o, n_o, v_ndT, is_local=False, xor_fallback=True) # True is not used
		self.n_inst = self._CvtRange(n_inst)
		self.insts = insts
		self.n_reg = 1
		self.luts = dict.fromkeys(UmiModel.limits.keys(), (0, npi.empty((1,))))

	def add_lut(self, name, a):
		limit = UmiModel.limits[name]
		a = npi.array(a)
		l = a.shape[0]
		assert len(a.shape) == 1 and l <= limit
		self.luts[name] = (l, a)

	def AllocSram(self, which, beg, end, tau=0):
		if which:
			linear = self.umcfg_i1['local_adr'][tau,:]
			msz = self.umcfg_i1['lmsize']
			bw = UmiModel.LBW1
		else:
			linear = self.umcfg_i0['local_adr'][tau,:]
			msz = self.umcfg_i0['lmsize']
			bw = UmiModel.LBW0
		MASK = (1<<bw)-1
		base = self.sram_cur[which]
		new_addr = npi.cumsum(npd.insert(msz[beg:end], 0, base)) & MASK
		linear[beg:end] = new_addr[:-1]
		self.sram_cur[which] = new_addr[-1]

	#################
	# Hardware model
	#################

	def CreateBlockTransaction(self):
		return self._CountBlockRoutine(self.pcfg['local'][0], self.pcfg['end'][0])

	def CreateAccumBlockTransaction(self, bofs):
		glb_alocal = self.acfg['local'][0]
		glb_aend = self.acfg['end'][0]
		n_aofs, aofs_beg = self._CountBlockRoutine(glb_alocal, glb_aend)
		aofs_end = npd.fmin(self.acfg['local']+aofs_beg, self.acfg['total'])
		l, r = UmiModel._SelRangeIdx(aofs_beg, glb_alocal, glb_aend)
		a_range_i0  = UmiModel._SelRangeSel(l, r, self.n_i0)
		a_range_i1  = UmiModel._SelRangeSel(l, r, self.n_i1)
		a_range_o   = UmiModel._SelRangeSel(l, r, self.n_o)
		a_range_alu = UmiModel._SelRangeSel(l, r, self.n_inst)
		a_range_dma = npd.reshape(npd.hstack((a_range_i0, a_range_i1)), (-1,2))
		aofs_beg2 = npd.repeat(aofs_beg, 2, 0)
		aofs_end2 = npd.repeat(aofs_end, 2, 0)
		def Extract(a_range, a_beg, a_end, dma=False):
			diff_id = a_range[:,0] != a_range[:,1]
			n_trim = npd.count_nonzero(diff_id)
			bofs_trim = npd.broadcast_to(bofs, (n_trim, self.VDIM))
			aofs_beg_trim = a_beg[diff_id]
			aofs_end_trim = a_end[diff_id]
			beg_trim = a_range[diff_id,0]
			end_trim = a_range[diff_id,1]
			dma_which = None
			if dma:
				zero_one = npd.bitwise_and(npi.arange(a_range.shape[0]), 1)
				dma_which = zero_one[diff_id]
			return n_trim, bofs_trim, aofs_beg_trim, aofs_end_trim, beg_trim, end_trim, dma_which
		return (
			Extract(a_range_i0, aofs_beg, aofs_end),
			Extract(a_range_i1, aofs_beg, aofs_end),
			Extract(a_range_dma, aofs_beg2, aofs_end2, True),
			Extract(a_range_o, aofs_beg, aofs_end),
			Extract(a_range_alu, aofs_beg, aofs_end),
		)

	def CreateAccumTransaction(self, abeg, aend):
		adiff = aend-abeg
		n_aofs, alofs = self._CountBlockRoutine(adiff)
		agofs = alofs + abeg
		# indices
		rt_i = self._SelRetireIdx(alofs, 1, adiff) # 1 will be broadcasted
		rg_li, rg_ri = self._SelRangeIdx(agofs, 1, self.acfg['total']) # 1 will be broadcasted
		return (
			n_aofs, agofs, alofs,
			rt_i, rg_li, rg_ri
		)

	def CreateAccumWarpTransaction(self, agofs, alofs, rt_i, rg_li, rg_ri, n):
		def FlatRange(rg):
			n_warp = self.warp_nd.shape[0]
			accum_idx = npd.concatenate([
				npi.full(n_warp*(rg[i,1]-rg[i,0]), i) for i in range(rg.shape[0])
			])
			warp_idx = npd.concatenate([
				npd.repeat(npi.arange(n_warp), rg[i,1]-rg[i,0]) for i in range(rg.shape[0])
			])
			rg_flat = npd.concatenate([
				npd.tile(npi.arange(rg[i,0], rg[i,1]), n_warp) for i in range(rg.shape[0])
			])
			return accum_idx, warp_idx, rg_flat
		def FlatIndex(li, ri, rt_i, n):
			rg = self._SelRangeSel(li, ri, n)
			accum_idx, warp_idx, rg_flat = FlatRange(rg)
			if rt_i is None:
				return rg, accum_idx, warp_idx, rg_flat
			else:
				last_warp = self.warp_nd.shape[0] - 1
				rt = self._SelRetireSel(rt_i, n)
				rt_flat = npd.logical_and(rt[accum_idx] > rg_flat, warp_idx == last_warp)
				return rg, accum_idx, warp_idx, rg_flat, rt_flat
		return FlatIndex(rg_li, rg_ri, rt_i, n)[1:]

	def CreateBofsValidTransaction(self, bofs, warp_idx):
		# v_nd -> (VSIZE, DIM)
		# bofs -> (DIM)
		# self... -> (n_flat, DIM)
		blofs = self.warp_nd[warp_idx, newaxis, :] + self.v_nd
		bgofs = bofs + blofs
		valid = npd.all(bgofs < self.pcfg['total'], axis=2)
		return bgofs, blofs, valid

	def CreateChunkHead(self, bofs, aofs, beg, end, um):
		rg = npi.arange(beg, end)
		shape = (end-beg, UmiModel.VDIM)
		bofs, aofs = npd.broadcast_to(bofs, shape), npd.broadcast_to(aofs, shape)
		return self._BA2M(bofs, aofs, rg, um, False) + um['mstart'][rg]

	def CreateVectorAddressTransaction(self, bofs, aofs, rg_flat, linear, um, is_local):
		adr = npi.sum(self._BA2M(bofs, aofs, rg_flat, um, is_local), axis=1) + linear[rg_flat]
		return adr[:, newaxis] + um['vlinear'][rg_flat]

	def CreateDramReadTransaction(self, mem_start, um, idx):
		DM = self.DRAM_ALIGN_MASK
		lmw = um['lmwidth'][idx]
		lma = um['lmpad'][idx]
		mbo = um['mboundary'][idx]
		mli = um['mlinear'][idx]
		wrap = um['mwrap'][idx]
		row_start = npi.indices(lmw[:-1]).reshape((self.DIM-1,-1)).T * mbo[1:] + mem_start[:-1]
		row_start_clip = npd.clip(row_start, 0, mbo[:-1] - mbo[1:])
		row_valid = npd.all(row_start == row_start_clip, axis=1)
		fv = npd.zeros(row_start.shape[0], dtype=npd.bool)
		row_pad_idx = self.DIM-1-npd.argmin(
			npd.column_stack((npd.fliplr(row_start == row_start[-1]), fv)),
			axis=1
		)
		row_pad = lma[row_pad_idx]
		req = list()
		for line in range(row_start.shape[0]):
			n = lmw[-1]
			p = row_pad[line]
			bl = npi.sum(row_start_clip[line])+mli
			br = bl + mbo[-1]
			l = bl + mem_start[-1]
			r = l + n
			b0 = min((r, bl))
			b1 = min((r, br))
			b2 = r
			if row_valid[line] or wrap == UmiModel.MEM_WRAP:
				while l < b0:
					nxt = min((b0, l+self.VSIZE))
					curlen = nxt-l
					req.append((1, 0, bl&~DM, bl&DM, curlen))
					l = nxt
				while l < b1:
					nxt = min((b1, (l|DM)+1, l+self.VSIZE))
					curlen = nxt-l
					req.append((0, 0, l&~DM, l&DM, curlen))
					l = nxt
				while l < b2:
					nxt = min((b2, l+self.VSIZE))
					curlen = nxt-l
					req.append((1, 0, (br-1)&~DM, (br-1)&DM, curlen))
					l = nxt
			else:
				while l < b2:
					nxt = min((b2, l+self.VSIZE))
					curlen = nxt-l
					req.append((2, 0, bl&~DM, bl&DM, curlen))
					l = nxt
			if p != 0:
				req.append((2, 0, req[-1][2], req[-1][3], p))
		ret = npd.array(req, dtype=self.DRAM_RD_TXDTYPE)
		ret['islast'][:-1] = ret['addr'][:-1] != ret['addr'][1:]
		ret['islast'][-1] = 1
		return ret

	def CreateDramWriteTransaction(self, valid, addr):
		dram_addr = list()
		dram_wmask = list()
		for i in range(valid.shape[0]):
			v = npd.copy(valid[i])
			a = addr[i]
			while True:
				first = npd.argmax(v)
				if not v[first]:
					break
				cur = a[first] & ~self.DRAM_ALIGN_MASK
				sel = npd.logical_and(cur == (a & ~self.DRAM_ALIGN_MASK), v)
				sel_bank = (a & self.DRAM_ALIGN_MASK)[sel]
				wmask = npd.zeros(self.DRAM_ALIGN, dtype=npd.bool)
				wmask[sel_bank] = True
				v[sel] = False
				dram_addr.append(cur)
				dram_wmask.append(wmask)
		return npi.array(dram_addr), npd.vstack(dram_wmask)
