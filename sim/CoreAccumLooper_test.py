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
from itertools import repeat
from UmiModel import UmiModel, default_sample_conf, npi, npd, newaxis

def main():
	(
		n_bofs, bofs,
		mofs_i0, mofs_i1, mofs_o
	) = cfg.CreateBlockTransaction()
	(
		n_abofs, abofs, alast,
		a_range_i0, a_range_i1, a_range_o,
		abmofs_i0, abmofs_i1, abmofs_o
	) = cfg.CreateAccumBlockTransaction(mofs_i0[0], mofs_i1[0], mofs_o[0])
	col0 = Stacker(n_abofs, [test0.Get])
	col1 = Stacker(n_abofs, [test1.Get])
	cola = Stacker(n_abofs, [testa.Get])
	master = TwoWire.Master(src_rdy, src_ack, src_bus, ck_ev)
	data_bus = master.values
	slave0 = TwoWire.Slave(i0_rdy, i0_ack, i0_bus, ck_ev, callbacks=[col0.Get])
	slave1 = TwoWire.Slave(i1_rdy, i1_ack, i1_bus, ck_ev, callbacks=[col1.Get])
	slavea = TwoWire.Slave(a_rdy, a_ack, a_bus, ck_ev, callbacks=[cola.Get])
	slaved = OneWire.Slave(done_dval, tuple(), ck_ev, callbacks=[lambda x: testdone.Get(tuple())])

	# start simulation
	cfg_bus = CreateBus((("dut", "AF_BW"),))
	cfg_bus.Read()
	assert not npd.any(cfg.acfg["local_exp"] >> (cfg_bus.value[0]+1))
	npd.copyto(data_bus[0], bofs[0])
	npd.copyto(data_bus[1], cfg.acfg["local_sig"][0])
	npd.copyto(data_bus[2], cfg.acfg["local_exp"][0])
	npd.copyto(data_bus[3], cfg.acfg["last"][0])
	npd.copyto(data_bus[4], cfg.acfg["boundary"][0]-1)
	npd.copyto(data_bus[5], cfg.acfg["local"][0]-1)
	baa = tuple(npd.broadcast_arrays(bofs[0],abofs,alast))
	test0.Expect(baa)
	test1.Expect(baa)
	testa.Expect(baa)
	testdone.Expect(tuple())
	yield from master.Send(data_bus)

	for i in range(10):
		yield ck_ev
	assert col0.is_clean
	assert col1.is_clean
	assert cola.is_clean
	FinishSim()

rst_out_ev, ck_ev = CreateEvents(["rst_out", "ck_ev"])
cfg = default_sample_conf
DIM = cfg.DIM
scb = Scoreboard()
test0 = scb.GetTest("i0")
test1 = scb.GetTest("i1")
testa = scb.GetTest("alu")
testdone = scb.GetTest("done")
(
	src_rdy, src_ack,
	i0_rdy, i0_ack,
	i1_rdy, i1_ack,
	a_rdy, a_ack,
	done_dval
) = CreateBuses([
	(("dut", "src_rdy"),),
	(("dut", "src_ack"),),
	(("i0_rdy"),),
	(("i0_canack"),),
	(("i1_rdy"),),
	(("i1_canack"),),
	(("alu_rdy"),),
	(("alu_canack"),),
	(("dut", "blkdone_dval"),),
])
src_bus, i0_bus, i1_bus, a_bus = CreateBuses([
	(
		("dut", "i_bofs", (DIM,)),
		(None , "i_agrid_frac", (DIM,)),
		(None , "i_agrid_shamt", (DIM,)),
		(None , "i_agrid_last", (DIM,)),
		(None , "i_aboundary", (DIM,)),
		(None , "i_alocal_last", (DIM,)),
	),
	(
		("dut", "o_i0_bofs", (DIM,)),
		(None , "o_i0_aofs", (DIM,)),
		(None , "o_i0_alast", (DIM,)),
	),
	(
		("dut", "o_i1_bofs", (DIM,)),
		(None , "o_i1_aofs", (DIM,)),
		(None , "o_i1_alast", (DIM,)),
	),
	(
		("dut", "o_alu_bofs", (DIM,)),
		(None , "o_alu_aofs", (DIM,)),
		(None , "o_alu_alast", (DIM,)),
	),
])
RegisterCoroutines([
	main(),
])
