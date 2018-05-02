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

from nicotb import *
from nicotb.utils import Scoreboard, BusGetter, Stacker
from nicotb.protocol import OneWire, TwoWire
from Response import Response
from UmiModel import UmiModel, default_sample_conf, npi, npd, newaxis
from collections import deque

def main():
	n_golden, bofs = cfg.CreateBlockTransaction()
	scb = Scoreboard("ParallelBlockLooper_mc")
	test_b = scb.GetTest("bofs")
	# master
	master = TwoWire.Master(rdy_bus_s, ack_bus_s, bus_s, ck_ev)
	i_data = master.values
	# slave
	ans = [deque() for _ in range(N_TAU)]
	bgs_b = list()
	masters_bdone = list()
	resps = list()
	slaves_b = list()
	for i in range(N_TAU):
		bg_b = BusGetter(copy=True, callbacks=[lambda x, i=i: ans[i].append(x)])
		master_bdone = OneWire.Master(dval_buss[i], tuple(), ck_ev)
		resp = Response(master_bdone.SendIter, ck_ev, B=100)
		slave_b = TwoWire.Slave(
			rdy_buss_b[i], ack_buss_b[i], buss_b[i], ck_ev,
			callbacks=[bg_b.Get, lambda x, resp=resp: resp.Append(tuple())],
			A=1, B=100
		)
		bgs_b.append(bg_b)
		masters_bdone.append(masters_bdone)
		resps.append(resp)
		slaves_b.append(slave_b)
	yield rst_out_ev
	yield ck_ev

	# start simulation
	npd.copyto(i_data[0], cfg.pcfg['local'][0])
	npd.copyto(i_data[1], cfg.pcfg['end'][0])

	yield from master.Send(i_data)

	for i in range(30):
		yield ck_ev

	for i in range(n_golden):
		b = bofs[i]
		popped = False
		for a in ans:
			if a and (a[0] == b).all():
				a.popleft()
				popped = True
			if popped:
				break
		assert popped, f"No correct bofs to match {b}"
	assert all(not a for a in ans), "Some extra bofs"
	FinishSim()

cfg = default_sample_conf
VDIM = cfg.VDIM
N_TAU = 4
rdy_buss_b = list()
ack_buss_b = list()
buss_b = list()
dval_buss = list()
for i in range(N_TAU):
	rdy_bus_b, ack_bus_b, bofs_b, dval_bus = CreateBuses([
		((f"dst{i}_rdy",),),
		((f"dst{i}_canack",),),
		(("", f"dst{i}_bofs", (VDIM,)),),
		((f"done{i}",),),
	])
	rdy_buss_b.append(rdy_bus_b)
	ack_buss_b.append(ack_bus_b)
	buss_b.append(bofs_b)
	dval_buss.append(dval_bus)
rdy_bus_s, ack_bus_s, bus_s = CreateBuses([
	(("dut", "src_rdy"),),
	(("dut", "src_ack"),),
	(
		("dut", "i_bgrid_step", (VDIM,)),
		(None , "i_bgrid_end" , (VDIM,)),
	),
])
rst_out_ev, ck_ev = CreateEvents(["rst_out", "ck_ev"])
RegisterCoroutines([
	main(),
])
