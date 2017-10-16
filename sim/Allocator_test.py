# Copyright 2016 Yu Sheng Lin

# This file is part of Ocean.

# MIMORI is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# MIMORI is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with Ocean.  If not, see <http://www.gnu.org/licenses/>.

from nicotb import *
from nicotb.utils import Scoreboard, Stacker
from nicotb.primitives import Semaphore
from nicotb.protocol import OneWire, TwoWire
from itertools import repeat
from UmiModel import UmiModel, default_sample_conf, npi, npd, newaxis
from Response import Response

def main():
	cfg = default_sample_conf
	sizes = npi.array([10, 300, 1000])
	N_CFG = sizes.shape[0]
	# bus
	sem = Semaphore(0)
	lbw_bus, const_bus, cap_bus = CreateBuses((
		(("dut", "LBW"),),
		(
			("dut", "blkdone_dval"),
			(None , "i_sizes", (N_CFG,)),
		),
		(("dut", "capacity_r"),),
	))
	(
		alloc_rdy, alloc_ack,
		linear_rdy, linear_ack,
		free_dval,
	) = CreateBuses((
		(("alloc_rdy",),),
		(("alloc_ack",),),
		(("linear_rdy",),),
		(("linear_canack",),),
		(("dut","free_dval"),),
	))
	lbw_bus.Read()
	BW = lbw_bus.value[0]
	alloc_bus, linear_bus, free_bus = CreateBuses((
		(("dut", "i_alloc_id",),),
		(
			("dut", "o_linear",),
			("dut", "o_linear_id",),
		),
		(("dut", "i_free_id",),),
	))
	# get configs
	N_TEST = 100
	ids = npd.random.randint(N_CFG, size=N_TEST)
	linears = npi.cumsum(sizes[ids]) & ((1<<BW)-1)
	linears = npd.roll(linears, 1)
	linears[0] = 0
	# init
	const_bus.values[0][0] = 0
	npd.copyto(const_bus.values[1], sizes)
	const_bus.Write()
	scb = Scoreboard()
	test = scb.GetTest("test")
	yield rst_out_ev
	yield ck_ev
	f_master = OneWire.Master(free_dval, free_bus, ck_ev, callbacks=[lambda x: sem.ReleaseNB()])
	resp = Response(f_master.SendIter, ck_ev, B=10)
	lc = Stacker(N_TEST, [test.Get])
	a_master = TwoWire.Master(alloc_rdy, alloc_ack, alloc_bus, ck_ev)
	a_slave = TwoWire.Slave(
		linear_rdy, linear_ack, linear_bus, ck_ev,
		callbacks=[lc.Get, lambda d: resp.Append((d.values[1].copy(),))]
	)
	test.Expect((linears[:,newaxis], ids[:,newaxis]))

	# start simulation
	data_bus = a_master.values
	def TheIter():
		for ID in ids:
			data_bus.i_alloc_id = ID
			yield data_bus
	yield from a_master.SendIter(((i,) for i in ids))

	yield from sem.Acquire(N_TEST)
	for i in range(5):
		yield ck_ev
	assert lc.is_clean
	cap_bus.Read()
	assert cap_bus.value[0] == (1<<BW)
	FinishSim()

rst_out_ev, ck_ev = CreateEvents(["rst_out", "ck_ev"])
RegisterCoroutines([
	main(),
])
