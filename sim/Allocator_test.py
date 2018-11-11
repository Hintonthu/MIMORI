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

from nicotb import *
from nicotb.utils import Scoreboard, BusGetter, Stacker
from nicotb.primitives import Semaphore
from nicotb.protocol import OneWire, TwoWire
from itertools import repeat
from UmiModel import UmiModel, npi, npd, newaxis
from Response import Response

def main():
	VSIZE = 32
	sizes_hi = npi.array([5, 1, 10])
	sizes = sizes_hi * VSIZE
	N_TEST = 200
	N_CFG = sizes.shape[0]
	LBW = 11
	LMASK = (1<<LBW)-1
	HALF = 1<<(LBW-1)
	# bus
	(
		alloc_rdy, alloc_ack,
		linear_rdy, linear_ack,
		alloced_rdy, alloced_ack,
		we_dval,
		free_dval,
	) = CreateBuses((
		(("alloc_rdy",),),
		(("alloc_ack",),),
		(("linear_rdy",),),
		(("linear_canack",),),
		(("allocated_rdy",),),
		(("allocated_canack",),),
		(("dut","we_dval"),),
		(("dut","free_dval"),),
	))
	size_bus, alloc_bus, linear_bus, alloced_bus, we_bus, free_bus = CreateBuses((
		(("dut", "i_sizes", (N_CFG,)),),
		(
			("dut", "i_beg_id",),
			(None , "i_end_id",),
		),
		(("dut", "o_linear",),),
		tuple(),
		tuple(),
		(("dut", "i_free_id",),),
	))
	size_bus.value = sizes_hi
	size_bus.Write()
	# compute answer
	ids0 = npd.random.randint(N_CFG+1, size=N_TEST)
	ids1 = npd.random.randint(N_CFG+1, size=N_TEST)
	rgs = npd.vstack((npd.fmin(ids0, ids1), npd.fmax(ids0, ids1))).T
	rgs = rgs[ids0 != ids1]
	flat_ids = UmiModel._FlatRangeNorep(rgs)
	linears, base_addr = list(), 0
	for rg in rgs:
		linear = npi.cumsum(sizes[range(rg[0], rg[1])])
		linear = npd.roll(linear, 1)
		linear[0] = 0
		linear = (linear + base_addr) & LMASK
		linears.append(linear)
		base_addr = HALF if base_addr == 0 else 0
	linears = npd.concatenate(linears)
	N_ANS = linears.size
	# init
	sem = Semaphore(0)
	space = (1<<LBW) // VSIZE
	allocated = 0
	valid_data = 0
	alc_ptr = 0
	ado_ptr = 0
	free_ptr = 0
	# testbench
	scb = Scoreboard("Allocator")
	test = scb.GetTest("test")
	yield rst_out_ev
	yield ck_ev
	lc = Stacker(N_ANS, callbacks=[test.Get])
	bg = BusGetter(callbacks=[lc.Get])
	# allocate a range
	def AllocateRange(d):
		nonlocal space, allocated
		sz_rg = sizes_hi[d.i_beg_id[0]:d.i_end_id[0]]
		space -= npd.sum(sz_rg)
		allocated += d.i_end_id[0] - d.i_beg_id[0]
		assert space >= 0
	a_master = TwoWire.Master(
		alloc_rdy, alloc_ack, alloc_bus, ck_ev,
		callbacks=[AllocateRange]
	)
	# something is allocated
	def AllocateOut(d):
		nonlocal allocated, alc_ptr
		allocated -= 1
		for i in range(sizes_hi[flat_ids[alc_ptr]]):
			w_resp.Append(we_bus)
		alc_ptr += 1
	alloced_slave = TwoWire.Slave(
		alloced_rdy, alloced_ack, alloced_bus, ck_ev,
		callbacks=[AllocateOut]
	)
	# a write is done
	def GetData(d):
		nonlocal valid_data
		valid_data += 1
	w_master = OneWire.Master(
		we_dval, we_bus, ck_ev,
		callbacks=[GetData],
		A=1, B=2
	)
	# output address
	def AddressOut(d):
		nonlocal valid_data, ado_ptr
		idx = flat_ids[ado_ptr]
		valid_data -= sizes_hi[idx]
		assert valid_data >= 0
		f_resp.Append((idx,))
		ado_ptr += 1
		bg.Get(d)
	l_slave = TwoWire.Slave(
		linear_rdy, linear_ack, linear_bus, ck_ev,
		callbacks=[AddressOut]
	)
	# free
	def Free(d):
		nonlocal space, free_ptr
		sem.ReleaseNB()
		space += sizes_hi[flat_ids[free_ptr]]
		free_ptr += 1
	f_master = OneWire.Master(free_dval, free_bus, ck_ev, callbacks=[Free])

	w_resp = Response(w_master.SendIter, ck_ev, B=2)
	f_resp = Response(f_master.SendIter, ck_ev, B=50)
	test.Expect((linears[:,newaxis],))

	# start simulation
	data_bus = a_master.values
	def TheIter(ids):
		for ID in ids:
			data_bus.i_beg_id[0] = ID[0]
			data_bus.i_end_id[0] = ID[1]
			yield data_bus
	yield from a_master.SendIter(TheIter(rgs))
	yield from sem.Acquire(N_ANS)

	for i in range(5):
		yield ck_ev
	assert ado_ptr == N_ANS
	assert alc_ptr == N_ANS
	assert free_ptr == N_ANS
	assert space*VSIZE == (1<<LBW)
	assert lc.is_clean
	FinishSim()

rst_out_ev, ck_ev = CreateEvents(["rst_out", "ck_ev"])
RegisterCoroutines([
	main(),
])
