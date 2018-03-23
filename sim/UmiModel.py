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

from __future__ import print_function, division
from functools import partial
# default numpy and i32 version numpy
from numpy import newaxis
import numpy as npd
import bisect
i16 = npd.int16
class npi(object): pass

wrapped = [
	'ones', 'zeros', 'empty', 'full', 'array',
	'cumsum', 'cumprod', 'sum', 'prod', 'arange', 'indices',
]
for f in wrapped:
	setattr(npi, f, partial(getattr(npd, f), dtype=npd.int32))

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

class UmiModel(object):
	MEM_PAD, MEM_WRAP = range(2)
	VSIZE = 32
	DIM = 4
	VDIM = 6
	BW = 24
	ABW = 32
	LBW = 10
	STRIDE_SIG_BW = 8
	STRIDE_EXP_BW = 3
	LG_VSIZE = Clog2(VSIZE, True)
	LLG_VSIZE = Clog2(LG_VSIZE+1)
	LG_DIM = Clog2(DIM)
	LG_VDIM = Clog2(VDIM)
	DRAM_ALIGN = 8
	DRAM_ALIGN_MASK = DRAM_ALIGN-1
	VSIZE_MASK = VSIZE-1
	LBW_MASK = (1<<LBW)-1
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
		'end', 'lg_vsize', 'lg_vshuf'
	], [VDIM,VDIM,VDIM,VDIM,VDIM,VDIM,VDIM])
	ACFG_DTYPE = ToIntTypes.__func__([
		'total', 'local', # user filled
		'end'
	], [VDIM,VDIM,VDIM])
	UMCFG_DTYPE = ToIntTypes.__func__([
		'mwidth', 'mlinear', 'ustart', 'ustride', 'udim', 'lmwidth', 'lmalign', 'xor_scheme', # user filled
		'mwrap', 'pad_value', # user filled NOTE: padding not implemented
		'ustride_frac', 'ustride_shamt', # derived from ustride
		'mboundary', # derived from mwitdth
		'mboundary_lmwidth', # derived from mboundary and lmdiwth
		'mstart', # precomuted offsets
		'lmpad', 'lmsize', # derived from lmwidth, lmalign
		'vlinear', # precomputed vector addresses local/global for I/O
		'xor_src', 'xor_dst', 'xor_swap', # XOR scheme: TODO document
	], [
		DIM,1,2*VDIM,2*VDIM,2*VDIM,DIM,DIM,LG_VSIZE,
		DIM,1,
		2*VDIM,2*VDIM,
		DIM,
		DIM,
		DIM,
		DIM,1,
		VSIZE,
		LG_VSIZE,LG_VSIZE,1,
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

	def _CalStride(self, um, is_local):
		mul = npd.copy(um['lmalign'] if is_local else um['mboundary'])
		mul = npd.roll(mul, -1, axis=1)
		mul[:,-1] = 1
		idx = npi.arange(um.shape[0])[:, newaxis]
		return (
			  mul[idx, um['udim'][:,UmiModel.VDIM:]]
			* um['ustride'][:,UmiModel.VDIM:]
		)

	@staticmethod
	def _XorPosToSrc(pos):
		return (1 << npd.fmax(0, pos+1)) >> 1 << UmiModel.LG_VSIZE

	@staticmethod
	def _XorPosToDst(pos):
		b = 1 << npi.arange(pos.shape[1])
		b = b[newaxis, :]
		b[pos < 0] = 0
		return b

	@staticmethod
	def _XorPosToSwap(strides):
		ret = npi.zeros(strides.shape[0])
		hi = 1 << npi.arange(UmiModel.LG_VSIZE)
		hi = hi[newaxis,:]
		lo = hi-1
		for i in range(UmiModel.LG_VSIZE):
			has_match = npd.bitwise_and(hi, strides) != 0
			no_extra_match = npd.bitwise_and(lo, strides) == 0
			exact_match = npd.logical_and(has_match, no_extra_match)
			ret[npd.any(exact_match, axis=1)] = i
			hi = npd.roll(hi, 1, axis=1)
			lo = npd.roll(lo, 1, axis=1)
		return ret

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

	def _ValidateXorScheme(self, umcfg):
		# which bit do you flip?
		st = umcfg['vlinear'][:,(1<<npi.arange(self.LG_VSIZE))]
		xors = st & (st^(st-1))
		or_xors = npd.bitwise_xor.reduce(xors, axis=1)
		# check
		lo_dst = npd.bitwise_or.reduce(umcfg['xor_dst'], axis=1)
		hi_src = npd.bitwise_or.reduce(umcfg['xor_src'], axis=1)
		masked_xors = (or_xors & ~hi_src)
		assert npd.all(or_xors == npd.sum(xors))
		assert npd.all((or_xors & lo_dst) == 0)
		assert npd.all((masked_xors & self.VSIZE_MASK) == masked_xors)

	def _InitUmcfg(self, umcfg, n, is_local):
		# layout of umcfg
		#   aaaapppp
		n_total = n[1][-1]
		assert n_total == umcfg.shape[0]
		# Calaulate memory shape cumsum (multiplier, boundary)
		umcfg['mboundary'] = self._CalMemBound(umcfg['mwidth'])
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
			umcfg['vlinear'] = npd.dot(self._CalStride(umcfg, True), self.v_nd.T)
			umcfg['xor_dst'] = self._XorPosToDst(umcfg['xor_scheme'])
			umcfg['xor_src'] = self._XorPosToSrc(umcfg['xor_scheme'])
			umcfg['xor_swap'] = self._XorPosToSwap(umcfg['vlinear'][:,(1<<npi.arange(self.LG_VSIZE))])
			self._ValidateXorScheme(umcfg)
		else:
			umcfg['vlinear'] = npd.dot(self._CalStride(umcfg, False), self.v_nd.T)
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

	def _InitApcfg(self, pcfg, acfg):
		# Init
		VDIM = self.VDIM
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
		for i in range(self.VDIM):
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

	def __init__(self, pcfg, acfg, umcfg_i0, umcfg_i1, umcfg_o, insts, n_i0, n_i1, n_o, n_inst):
		# convert to internal format
		# v_nd_shuf, v_nd = head of warp, warp sub idx
		self.pcfg, self.acfg, self.warp_nd, self.v_nd = self._InitApcfg(pcfg, acfg)
		self.sram_cur = [0, 0]
		self.n_i0 = self._CvtRange(n_i0)
		self.n_i1 = self._CvtRange(n_i1)
		self.sram_linear = [
			npi.empty(self.n_i0[1][-1]),
			npi.empty(self.n_i1[1][-1]),
		]
		self.umcfg_i0 = self._InitUmcfg(umcfg_i0, n_i0, is_local=True)
		self.umcfg_i1 = self._InitUmcfg(umcfg_i1, n_i1, is_local=True)
		self.n_o = self._CvtRange(n_o)
		self.umcfg_o = self._InitUmcfg(umcfg_o, n_o, is_local=False)
		self.n_inst = self._CvtRange(n_inst)
		self.insts = insts
		self.n_reg = 1
		self.luts = dict.fromkeys(UmiModel.limits.keys(), (0, npi.empty((1,))))

	def add_lut(self, name, a):
		limit = UmiModel.limits[name]
		a = npi.array(a)
		l = a.size
		assert len(a.shape) == 1 and l <= limit
		self.luts[name] = (l, a)

	def AllocSram(self, which, beg, end):
		linear = self.sram_linear[which]
		um = self.umcfg_i0['lmsize'] if which == 0 else self.umcfg_i1['lmsize']
		new_addr = npi.cumsum(npd.insert(um[beg:end], 0, self.sram_cur[which])) & UmiModel.LBW_MASK
		linear[beg:end] = new_addr[:-1]
		self.sram_cur[which] = new_addr[-1]
		return linear

	"""
		Important functions
	"""
	def CreateBlockTransaction(self):
		return self._CountBlockRoutine(self.pcfg['local'][0], self.pcfg['end'][0])

	def CreateAccumBlockTransaction(self, bofs):
		glb_alocal = self.acfg['local'][0]
		glb_aend = self.acfg['end'][0]
		n_aofs, aofs_beg = self._CountBlockRoutine(glb_alocal, glb_aend)
		aofs_end = npd.fmin(self.acfg['local']+aofs_beg, self.acfg['total'])
		l, r = UmiModel._SelRangeIdx(aofs_beg, glb_alocal, glb_aend)
		def Extract(nums):
			a_range = UmiModel._SelRangeSel(l, r, nums)
			diff_id = a_range[:,0] != a_range[:,1]
			n_trim = npd.count_nonzero(diff_id)
			bofs_trim = npd.broadcast_to(bofs, (n_trim, self.VDIM))
			aofs_beg_trim = aofs_beg[diff_id]
			aofs_end_trim = aofs_end[diff_id]
			beg_trim = a_range[diff_id,0]
			end_trim = a_range[diff_id,1]
			return n_trim, bofs_trim, aofs_beg_trim, aofs_end_trim, beg_trim, end_trim
		return (
			Extract(self.n_i0) +
			Extract(self.n_i1) +
			Extract(self.n_o) +
			Extract(self.n_inst)
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
		return self._BA2M(bofs, aofs, rg, um, False)

	def CreateVectorAddressTransaction(self, bofs, aofs, rg_flat, linear, um, is_local):
		adr = npi.sum(self._BA2M(bofs, aofs, rg_flat, um, is_local), axis=1) + linear[rg_flat]
		return adr[:, newaxis] + um['vlinear'][rg_flat]

	def CreateDramReadTransaction(self, mem_start, um, idx):
		DM = self.DRAM_ALIGN_MASK
		lmw = um['lmwidth'][idx]
		lma = um['lmpad'][idx]
		mbo = um['mboundary'][idx]
		mli = um['mlinear'][idx]
		row_start = npi.indices(lmw[:-1]).reshape((self.DIM-1,-1)).T * mbo[1:] + mem_start[:-1]
		row_start_clip = npd.clip(row_start, 0, mbo[:-1] - mbo[1:])
		row_valid = npd.all(row_start == row_start_clip, axis=1)
		fv = npd.zeros(row_start.shape[0], dtype=npd.bool)
		row_pad_idx = self.DIM-1-npd.argmin(
			npd.column_stack((npd.fliplr(row_start == row_start[-1]), fv)),
			axis=1
		)
		row_pad = lma[row_pad_idx]
		# extend mode (only support this now)
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

sample_conf = list()
verf_func = list()

##########
## TEST 0
##########
n_i0 = ([0,0,0,0,0,0,0], [1,1,1,1,1,1,1])
n_i1 = ([0,0,0,0,0,0,0], [1,1,1,1,1,1,1])
n_o = ([0,0,0,0,0,0,0], [0,0,0,0,0,0,1])
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

p['total'] = [1,1,1,1,20,10]
p['local'] = [1,1,1,1,16,8]
p['vsize'] = [1,1,1,1,4,8]
p['vshuf'] = [1,1,1,1,4,1]
a['total'] = [1,1,1,1,3,3]
a['local'] = [1,1,1,1,2,2]
um_i0['mwrap'].fill(UmiModel.MEM_WRAP)
um_i0['mlinear'] = [0]
um_i0['ustart'] = [[0,0,0,0,-1,-1,0,0,0,0,0,0],]
um_i0['ustride'] = [[0,0,0,0,1,1,0,0,0,0,1,1],]
um_i0['udim'] = [[0,0,0,0,2,3,0,0,0,0,2,3],]
um_i0['lmwidth'] = [[1,1,17,9],]
um_i0['lmalign'] = [[192,192,192,10],]
um_i0['mwidth'] = [[1,1,100,301],]
um_i0['xor_scheme'] = -1

um_i1['mwrap'].fill(UmiModel.MEM_WRAP)
um_i1['mlinear'] = [100000]
um_i1['ustart'] = [[0,0,0,0,0,0,0,0,0,0,0,0],]
um_i1['ustride'] = [[0,0,0,0,1,1,0,0,0,0,0,0],]
um_i1['udim'] = [[0,0,0,0,2,3,0,0,0,0,0,0],]
um_i1['lmwidth'] = [[1,1,2,2],]
um_i1['lmalign'] = [[32,32,32,2],]
um_i1['mwidth'] = [[1,1,3,3],]
um_i1['xor_scheme'] = -1

um_o['mwrap'].fill(UmiModel.MEM_WRAP)
um_o['mlinear'] = [300000]
um_o['ustart'] = [[0,0,0,0,0,0,0,0,0,0,0,0],]
um_o['ustride'] = [[0,0,0,0,0,0,0,0,0,0,1,1],]
um_o['udim'] = [[0,0,0,0,0,0,0,0,0,0,2,3],]
um_o['mwidth'] = [[1,1,1000,1000],]

cfg0 = UmiModel(p, a, um_i0, um_i1, um_o, insts, n_i0, n_i1, n_o, n_inst)
def VerfFunc0(CSIZE):
	# init
	img = npd.random.randint(10, size=30100, dtype=i16)
	conv = npd.arange(16, dtype=i16)
	result = npd.zeros(1000000, dtype=i16)
	img_2d = npd.reshape(img[:30100], (100,301))
	conv_2d = npd.reshape(conv[:9], (3,3))
	result_2d = npd.reshape(result, (1000,1000))
	gold_2d = npd.zeros((20,10), dtype=i16)
	yield MemorySpace([
		(     0, img   ),
		(100000, conv  ),
		(300000, result),
	], CSIZE)
	# check
	for y in range(20):
		for x in range(10):
			yy, xx = npd.ogrid[y-1:y+2, x-1:x+2]
			yy = npd.fmax(yy, 0)
			xx = npd.fmax(xx, 0)
			wind = img_2d[yy,xx]
			gold_2d[y,x] = (1 + npd.sum(wind * conv_2d, dtype=i16))
	npd.savetxt("ans.txt",   gold_2d[:20,:10], "%d")
	npd.savetxt("res.txt", result_2d[:20,:10], "%d")
	for y in range(20):
		for x in range(10):
			gold = gold_2d[y,x]
			got = result_2d[y,x]
			assert gold == got, f"Error at pixel {y} {x}, {got} != {gold}, {wind}/{conv_2d}/{img_2d}"
	result_2d[:20,:10] = 0
	assert npd.all(result_2d == 0)
	print("SimpConv test result successes")

sample_conf.append(cfg0)
verf_func.append(VerfFunc0)

##########
## TEST 1
##########
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
um_i0['xor_scheme'] = [[0,1,2,3,4],]
um_o['mwrap'].fill(UmiModel.MEM_WRAP)
um_o['mlinear'] = [300000]
um_o['ustart'] = [[0,0,0,0,0,0,0,0,0,0,0,0],]
um_o['ustride'] = [[0,0,0,0,0,1,0,0,0,0,0,1],]
um_o['udim'] = [[0,0,0,0,0,2,0,0,0,0,0,3],]
um_o['mwidth'] = [[1,1,100,100],]

cfg1 = UmiModel(p, a, um_i0, um_i1, um_o, insts, n_i0, n_i1, n_o, n_inst)
def VerfFunc1(CSIZE):
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
	check_res = result_2d != npd.cumsum(img_2d, axis=1, dtype=i16).T
	assert not npd.any(check_res)
	print("IntImg(1D) test result successes")

sample_conf.append(cfg1)
verf_func.append(VerfFunc1)

##########
## TEST 2
##########
n_i0 = ([0,0,0,0,0,0,0], [1,1,1,1,1,1,1])
n_i1 = ([0,0,0,0,0,0,0], [1,1,1,1,1,1,1])
n_o = ([0,0,0,0,0,0,0], [0,0,0,0,0,0,1])
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
um_i0['xor_scheme'] = -1
um_i1['mlinear'] = [100000]
um_i1['ustart'] = [[0,0,0,0,0,0,0,0,0,0,0,0],]
um_i1['ustride'] = [[0,0,0,0,0,1,0,0,0,0,0,1],]
um_i1['udim'] = [[0,0,0,0,0,2,0,0,0,0,0,3],]
um_i1['lmwidth'] = [[1,1,16,32],]
um_i1['lmalign'] = [[512,512,512,32],]
um_i1['mwidth'] = [[1,1,64,64],]
um_i1['xor_scheme'] = -1
um_o['mwrap'].fill(UmiModel.MEM_WRAP)
um_o['mlinear'] = [300000]
um_o['ustart'] = [[0,0,0,0,0,0,0,0,0,0,0,0],]
um_o['ustride'] = [[0,0,0,0,0,0,0,0,0,0,1,1],]
um_o['udim'] = [[0,0,0,0,0,0,0,0,0,0,2,3],]
um_o['mwidth'] = [[1,1,128,64],]

cfg2 = UmiModel(p, a, um_i0, um_i1, um_o, insts, n_i0, n_i1, n_o, n_inst)
def VerfFunc2(CSIZE):
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

sample_conf.append(cfg2)
verf_func.append(VerfFunc2)

##########
## TEST 3
##########
n_i0 = ([0,0,0,0,0,0,0], [1,1,1,1,1,1,1])
n_i1 = ([0,0,0,0,0,0,0], [1,1,1,1,1,1,1])
n_o = ([0,0,0,0,0,0,0], [0,0,0,0,0,0,1])
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
p['local'] = [1,1,1,1,8,8]
p['vsize'] = [1,1,1,1,4,8]
p['vshuf'] = [1,1,1,1,2,1]
a['total'] = [1,1,1,1,8,8]
a['local'] = [1,1,1,1,8,8]
um_i0['mwrap'].fill(UmiModel.MEM_WRAP)
um_i0['mlinear'] = [0]
um_i0['ustart'] = [[0,0,0,0,0,0,0,0,4,4,-4,-4],]
um_i0['ustride'] = [[0,0,0,0,1,1,0,0,8,8,1,1],]
um_i0['udim'] = [[0,0,0,0,2,3,0,0,2,3,2,3],]
um_i0['lmwidth'] = [[1,1,15,15],]
um_i0['lmalign'] = [[256,256,256,16],]
um_i0['mwidth'] = [[1,1,50,50],]
um_i0['xor_scheme'] = [[-1,-1,-1,0,1],]
um_i1['mlinear'] = [100000]
um_i1['ustart'] = [[0,0,0,0,0,0,0,0,0,0,0,0],]
um_i1['ustride'] = [[0,0,0,0,1,1,0,0,8,8,0,0],]
um_i1['udim'] = [[0,0,0,0,2,3,0,0,2,3,0,0],]
um_i1['lmwidth'] = [[1,1,8,8],]
um_i1['lmalign'] = [[64,64,64,8],]
um_i1['mwidth'] = [[1,1,32,32],]
um_i1['xor_scheme'] = -1
um_o['mwrap'].fill(UmiModel.MEM_WRAP)
um_o['mlinear'] = [300000]
um_o['ustart'] = [[0,0,0,0,0,0,0,0,0,0,0,0],]
um_o['ustride'] = [[0,0,0,0,0,0,0,0,1,1,1,1],]
um_o['udim'] = [[0,0,0,0,0,0,0,0,0,1,2,3],]
um_o['mwidth'] = [[4,4,8,8],]

cfg3 = UmiModel(p, a, um_i0, um_i1, um_o, insts, n_i0, n_i1, n_o, n_inst)
def VerfFunc3(CSIZE):
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

sample_conf.append(cfg3)
verf_func.append(VerfFunc3)

##########
## TEST 4
##########
n_i0 = ([0,0,0,0,0,0,0], [0,0,0,0,0,0,0])
n_i1 = ([0,0,0,0,0,0,0], [0,0,0,0,0,0,0])
n_o = ([0,0,0,0,0,0,0], [0,0,0,0,0,0,1])
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
a['total'] = [1,1,1,1,1,1]
a['local'] = [1,1,1,1,1,1]
um_o['mwrap'].fill(UmiModel.MEM_WRAP)
um_o['mlinear'] = [300000]
um_o['ustart'] = [[0,0,0,0,0,0,0,0,0,0,0,0],]
um_o['ustride'] = [[0,0,0,0,0,0,0,0,0,0,1,1],]
um_o['udim'] = [[0,0,0,0,0,0,0,0,0,0,2,3],]
um_o['mwidth'] = [[1,1,60,30],]

cfg4 = UmiModel(p, a, um_i0, um_i1, um_o, insts, n_i0, n_i1, n_o, n_inst)
cfg4.add_lut("const", [100])
def VerfFunc4(CSIZE):
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

sample_conf.append(cfg4)
verf_func.append(VerfFunc4)

##########
## TEST 5
##########
n_i0 = ([0,0,0,0,0,0,0], [1,1,1,1,1,1,1])
n_i1 = ([0,0,0,0,0,0,0], [0,0,0,0,0,0,0])
n_o = ([0,0,0,0,0,0,0], [0,0,0,0,0,0,1])
n_inst = ([0,0,0,0,0,0,0], [0,0,0,0,0,0,4])
insts = npd.array([
	# OOOSSSSSRDDTWWWAAAAABBBBBCCCCC
	0b000000000111000000001000000000, # y1 (push)
	0b010000000111000000001000010010, # 0+(t0-y2)^2 (push)
	0b000000000111000000001000000000, # x1 (push)
	0b010000000000000100111000010010, # DRAM = t1+(t0-x2)^2 (DRAM)
], dtype=npd.uint32)
p = npd.empty(1, UmiModel.PCFG_DTYPE)
a = npd.empty(1, UmiModel.ACFG_DTYPE)
um_i0 = npd.empty(1, UmiModel.UMCFG_DTYPE)
um_i1 = npd.empty(0, UmiModel.UMCFG_DTYPE)
um_o = npd.empty(1, UmiModel.UMCFG_DTYPE)

p['total'] = [1,1,1,1,126,126]
p['local'] = [1,1,1,1,16,32]
p['vsize'] = [1,1,1,1,1,32]
p['vshuf'] = [1,1,1,1,1,1]
a['total'] = [1,1,1,1,3,3]
a['local'] = [1,1,1,1,3,3]
um_i0['mwrap'].fill(UmiModel.MEM_WRAP)
um_i0['mlinear'] = [10000]
um_i0['ustart'] = [[0,0,0,0,-1,-1,0,0,0,0,1,1],]
um_i0['ustride'] = [[0,0,0,0,1,1,0,0,0,0,1,1],]
um_i0['udim'] = [[0,0,0,0,2,3,0,0,0,0,2,3],]
um_i0['lmwidth'] = [[1,1,18,34],]
um_i0['lmalign'] = [[640,640,640,34],]
um_i0['mwidth'] = [[1,1,128,128],]
um_i0['xor_scheme'] = -1
um_o['mwrap'].fill(UmiModel.MEM_WRAP)
um_o['mlinear'] = [300000]
um_o['ustart'] = [[0,0,0,0,0,0,0,0,0,0,0,0],]
um_o['ustride'] = [[0,0,0,0,0,0,0,0,0,0,1,1],]
um_o['udim'] = [[0,0,0,0,0,0,0,0,0,0,2,3],]
um_o['mwidth'] = [[1,1,128,128],]

cfg5 = UmiModel(p, a, um_i0, um_i1, um_o, insts, n_i0, n_i1, n_o, n_inst)
cfg5.add_lut("stencil0", [1,69,34,36])
def VerfFunc5(CSIZE):
	# init
	img_flat = npd.random.randint(10, size=128*128, dtype=i16)
	gradm_flat = npd.zeros(128*128, i16)
	img = npd.reshape(img_flat, (128,128))
	gradm = npd.reshape(gradm_flat, (128,128))
	gradm_gold = npd.square(img[1:-1,2:]-img[1:-1,:-2]) + npd.square(img[2:,1:-1]-img[:-2,1:-1])
	yield MemorySpace([
		(10000, img_flat),
		(300000, gradm_flat),
	], CSIZE)
	# check
	npd.savetxt("grad_img.txt", img, fmt="%d")
	npd.savetxt("grad_result.txt", gradm, fmt="%d")
	npd.savetxt("grad_gold.txt", gradm_gold, fmt="%d")
	assert npd.all(gradm_gold == gradm[:126,:126])
	gradm[:126,:126] = 0
	assert not npd.any(gradm)
	print("Gradient test result successes")

sample_conf.append(cfg5)
verf_func.append(VerfFunc5)

try:
	from os import environ
	WHAT = int(environ["TEST_CFG"])
except:
	WHAT = 0
default_sample_conf = sample_conf[WHAT]
default_verf_func = verf_func[WHAT]
