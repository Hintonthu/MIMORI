# Copyright 2017-2018 Yu Sheng Lin

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
import bisect
from collections import deque
from ctypes import *
from nicotb import *
from nicotb.protocol import TwoWire
from Response import Response
from . import npi, npd, newaxis

class Ramu(object): pass
def InitDLL():
	from os import path
	dir_path = path.dirname(path.abspath(__file__))
	ramu = CDLL(dir_path + "/ramulator_wrap.so")
	c_long_p = POINTER(c_long)
	c_bool_p = POINTER(c_bool)
	ramu.RamulatorCreate.argtypes = (c_int,)
	ramu.RamulatorDestroy.argtypes = (c_int,)
	ramu.RamulatorTick.argtypes = (c_int, c_bool_p, c_bool_p, c_bool_p, c_long_p, c_long_p, c_bool_p, c_bool_p, c_bool_p)
	ramu.RamulatorReport.argtypes = (c_int,)
	Ramu.Create = ramu.RamulatorCreate
	Ramu.Destroy = ramu.RamulatorDestroy
	Ramu.Tick = ramu.RamulatorTick
	Ramu.Report = ramu.RamulatorReport
InitDLL()

class DramRespChan(object):
	def __init__(
		self,
		ra_rdy_bus, ra_ack_bus, ra_bus,
		rd_rdy_bus, rd_ack_bus, rd_bus,
		w_rdy_bus, w_ack_bus, w_bus,
		ck_ev, mspace,
		# dram freq / clk freq
		dram_speed,
		n_cores, csize
	):
		self.n_cores = n_cores
		self.sending = list()
		self.pending = list()
		self.ra_rdy = ra_rdy_bus
		self.ra_ack = ra_ack_bus
		self.ra = ra_bus
		self.rd_rdy = rd_rdy_bus
		self.rd_ack = rd_ack_bus
		self.rd = rd_bus
		self.w_rdy = w_rdy_bus
		self.w_ack = w_ack_bus
		self.w = w_bus
		self.ck_ev = ck_ev
		self.mspace = mspace
		self.cache_mask = ~(csize - 1)
		self.q = [deque() for _ in range(self.n_cores)]
		self.ra_ack.Write()
		self.rd_rdy.Write()
		self.rd.Write()
		self.w_ack.Write()
		self.dram_counter = 0.
		self.dram_speed_inc = 1 / dram_speed
		self.InitSim()
		Fork(self.MainLoop())

	def InitSim(self):
		self.ctx_idx = Ramu.Create(self.n_cores)

	def Report(self):
		Ramu.Report(self.ctx_idx)

	def MainLoop(self):
		c_longs = c_long * self.n_cores
		c_bools = c_bool * self.n_cores
		ZERO = (0,) * self.n_cores
		c_rs = c_longs()
		c_ws = c_longs()
		c_has_rs = c_bools()
		c_has_ws = c_bools()
		c_resp_gots = c_bools()
		c_r_fulls = c_bools()
		c_w_fulls = c_bools()
		c_has_resps = c_bools()
		while True:
			if self.dram_counter >= 1.:
				self.dram_counter -= 1.
				yield self.ck_ev
				self.rd_ack.Read()
				self.ra_rdy.Read()
				self.w_rdy.Read()
				if not self.ra_rdy.x[0] and (self.ra_rdy.value[0] or self.ra_ack.value[0]):
					self.ra.Read()
					self.ra.value &= self.cache_mask
				if not self.w_rdy.x[0] and (self.w_rdy.value[0] or self.w_ack.value[0]):
					self.w.Read()
					self.w.value &= self.cache_mask
				for i in range(self.n_cores):
					m = 1<<i
					c_has_rs[i] = not (self.ra_rdy.x[0] & m) and (self.ra_rdy.value[0] & m) and (self.ra_ack.value[0] & m)
					c_has_ws[i] = not (self.w_rdy.x[0] & m) and (self.w_rdy.value[0] & m) and (self.w_ack.value[0] & m)
					c_resp_gots[i] = (self.rd_rdy.value[0] & m) and (self.rd_ack.value[0] & m)
					# We use [i:i+1] instead of [i] for scalar. (for compability)
					if c_has_rs[i]:
						c_rs[i] = self.ra.value[i]
						self.q[i].append(self.mspace.Read(self.ra.value[i:i+1]))
					if c_has_ws[i]:
						c_ws[i] = self.w.value[i]
						self.mspace.WriteScalarMask(
							self.w.values.o_dramwas[i:i+1],
							self.w.values.o_dramwds[i],
							self.w.values.o_dramw_masks[i:i+1],
						)
				Ramu.Tick(
					self.ctx_idx,
					c_has_rs, c_has_ws, c_resp_gots, c_rs, c_ws,
					c_r_fulls, c_w_fulls, c_has_resps
				)
				any_update_resp = False
				for i in range(self.n_cores):
					m = 1<<i
					update_resp = not (self.rd_rdy.value[0] & m) or (self.rd_ack.value[0] & m)
					# Since I am not sure whether the bit inveted ~m works fine,
					# I OR the mask first and then XOR the mask if the condition is false.
					self.ra_ack.value[0] |= m
					self.w_ack.value[0] |= m
					self.rd_rdy.value[0] |= m
					if c_r_fulls[i]:
						self.ra_ack.value[0] ^= m
					if c_w_fulls[i]:
						self.w_ack.value[0] ^= m
					if not c_has_resps[i]:
						self.rd_rdy.value[0] ^= m
					if update_resp and (self.rd_rdy.value[0] & m):
						self.rd.value[i] = self.q[i].popleft()
						any_update_resp = True
				if any_update_resp:
					self.rd.Write()
				self.ra_ack.Write()
				self.w_ack.Write()
				self.rd_rdy.Write()
			else:
				c_has_rs[:] = ZERO
				c_has_ws[:] = ZERO
				c_resp_gots[:] = ZERO
				c_rs[:] = ZERO
				c_ws[:] = ZERO
				Ramu.Tick(
					self.ctx_idx,
					c_has_rs, c_has_ws, c_resp_gots, c_rs, c_ws,
					c_r_fulls, c_w_fulls, c_has_resps
				)
			self.dram_counter += self.dram_speed_inc

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

