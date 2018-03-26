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
from nicotb.protocol import OneWire, TwoWire
from Response import Response
from UmiModel import UmiModel, default_sample_conf, npi, npd, newaxis

def main():
	n_golden, bofs = cfg.CreateBlockTransaction()
	scb = Scoreboard("ParallelBlockLooper")
	test_b = scb.GetTest("bofs")
	st_b = Stacker(n_golden, [test_b.Get])
	master = TwoWire.Master(rdy_bus_s, ack_bus_s, bus_s, ck_ev)
	master_bdone = OneWire.Master(dval_bus, tuple(), ck_ev)
	resp = Response(master_bdone.SendIter, ck_ev, B=100)
	i_data = master.values
	slave_b = TwoWire.Slave(rdy_bus_b, ack_bus_b, bus_b, ck_ev, callbacks=[st_b.Get, lambda x: resp.Append(tuple())])
	yield rst_out_ev
	yield ck_ev

	# start simulation
	npd.copyto(i_data[0], cfg.pcfg['local'][0])
	npd.copyto(i_data[1], cfg.pcfg['end'][0])

	test_b.Expect((bofs,))
	yield from master.Send(i_data)

	for i in range(30):
		yield ck_ev
	assert st_b.is_clean
	FinishSim()

cfg = default_sample_conf
VDIM = cfg.VDIM
(
	rdy_bus_s, ack_bus_s,
	rdy_bus_b, ack_bus_b,
	dval_bus,
) = CreateBuses([
	(("dut", "src_rdy"),),
	(("dut", "src_ack"),),
	(("bofs_rdy"),),
	(("bofs_canack"),),
	(("dut", "blkdone_dval"),),
])
bus_s, bus_b = CreateBuses([
	(
		("dut", "i_bgrid_step", (VDIM,)),
		(None , "i_bgrid_end" , (VDIM,)),
	),
	(("dut", "o_bofs", (VDIM,)),),
])
rst_out_ev, ck_ev = CreateEvents(["rst_out", "ck_ev"])
RegisterCoroutines([
	main(),
])
