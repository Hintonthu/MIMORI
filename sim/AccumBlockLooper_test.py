# Copyright 2016-2017 Yu Sheng Lin

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
from nicotb.utils import Scoreboard, Stacker
from nicotb.protocol import TwoWire
from itertools import repeat
from UmiModel import UmiModel, default_sample_conf, npi, npd, newaxis

def main():
	scb = Scoreboard("AccumBlockLooper")
	test_i0 = scb.GetTest("test_i0")
	test_i1 = scb.GetTest("test_i1")
	test_o = scb.GetTest("test_o")
	test_alu = scb.GetTest("test_alu")
	st_i0 = Stacker(0, [test_i0.Get])
	st_i1 = Stacker(0, [test_i1.Get])
	st_o = Stacker(0, [test_o.Get])
	st_alu = Stacker(0, [test_alu.Get])
	master = TwoWire.Master(s_rdy_bus, s_ack_bus, s_bus, ck_ev)
	i_data = master.values
	slave_i0 = TwoWire.Slave(i0_rdy_bus, i0_ack_bus, i0_bus, ck_ev, callbacks=[st_i0.Get])
	slave_i1 = TwoWire.Slave(i1_rdy_bus, i1_ack_bus, i1_bus, ck_ev, callbacks=[st_i1.Get])
	slave_o = TwoWire.Slave(o_rdy_bus, o_ack_bus, o_bus, ck_ev, callbacks=[st_o.Get])
	slave_alu = TwoWire.Slave(alu_rdy_bus, alu_ack_bus, alu_bus, ck_ev, callbacks=[st_alu.Get])
	yield rst_out_ev
	yield ck_ev

	(
		n_bofs, bofs,
	) = cfg.CreateBlockTransaction()
	(
		n_i0, bofs_i0, abeg_i0, aend_i0, abeg_id_i0, aend_id_i0,
		n_i1, bofs_i1, abeg_i1, aend_i1, abeg_id_i1, aend_id_i1,
		n_o, bofs_o, abeg_o, aend_o, abeg_id_o, aend_id_o,
		n_alu, bofs_alu, abeg_alu, aend_alu, abeg_id_alu, aend_id_alu,
	) = cfg.CreateAccumBlockTransaction(bofs[0])

	# start simulation
	npd.copyto(i_data[ 0], bofs[0]                )
	npd.copyto(i_data[ 1], cfg.acfg['local'][0]   )
	npd.copyto(i_data[ 2], cfg.acfg['end'][0]     )
	npd.copyto(i_data[ 3], cfg.acfg['boundary'][0])
	npd.copyto(i_data[ 4], cfg.n_i0[0]  )
	npd.copyto(i_data[ 5], cfg.n_i0[1]  )
	npd.copyto(i_data[ 6], cfg.n_i1[0]  )
	npd.copyto(i_data[ 7], cfg.n_i1[1]  )
	npd.copyto(i_data[ 8], cfg.n_o[0]   )
	npd.copyto(i_data[ 9], cfg.n_o[1]   )
	npd.copyto(i_data[10], cfg.n_inst[0])
	npd.copyto(i_data[11], cfg.n_inst[1])
	test_i0.Expect((bofs_i0, abeg_i0, aend_i0))
	test_i1.Expect((bofs_i1, abeg_i1, aend_i1))
	test_o.Expect((bofs_o, abeg_o, aend_o))
	test_alu.Expect((bofs_alu, abeg_alu, aend_alu))
	st_i0.Resize(n_i0)
	st_i1.Resize(n_i1)
	st_o.Resize(n_o)
	st_alu.Resize(n_alu)
	yield from master.Send(i_data)

	for i in range(300):
		yield ck_ev
	assert st_i0.is_clean
	assert st_i1.is_clean
	assert st_o.is_clean
	assert st_alu.is_clean
	FinishSim()

cfg = default_sample_conf
VDIM = cfg.VDIM
(
	s_rdy_bus, s_ack_bus,
	i0_rdy_bus, i0_ack_bus,
	i1_rdy_bus, i1_ack_bus,
	o_rdy_bus, o_ack_bus,
	alu_rdy_bus, alu_ack_bus,
	s_bus,
	i0_bus,
	i1_bus,
	o_bus,
	alu_bus,
) = CreateBuses([
	(("", "src_rdy"),),
	(("", "src_ack"),),
	(("", "dst_i0_rdy"),),
	(("", "dst_i0_canack"),),
	(("", "dst_i1_rdy"),),
	(("", "dst_i1_canack"),),
	(("", "dst_o_rdy"),),
	(("", "dst_o_canack"),),
	(("", "dst_alu_rdy"),),
	(("", "dst_alu_canack"),),
	(
		("dut","i_bofs"       , (VDIM,)),
		(None ,"i_agrid_step" , (VDIM,)),
		(None ,"i_agrid_end"  , (VDIM,)),
		(None ,"i_aboundary"  , (VDIM,)),
		(None ,"i_i0_id_begs" , (VDIM+1,)),
		(None ,"i_i0_id_ends" , (VDIM+1,)),
		(None ,"i_i1_id_begs" , (VDIM+1,)),
		(None ,"i_i1_id_ends" , (VDIM+1,)),
		(None ,"i_o_id_begs"  , (VDIM+1,)),
		(None ,"i_o_id_ends"  , (VDIM+1,)),
		(None ,"i_inst_id_begs", (VDIM+1,)),
		(None ,"i_inst_id_ends", (VDIM+1,)),
	),
	(
		("dut", "o_i0_bofs", (VDIM,)),
		(None , "o_i0_aofs_beg", (VDIM,)),
		(None , "o_i0_aofs_end", (VDIM,)),
	),
	(
		("dut", "o_i1_bofs", (VDIM,)),
		(None , "o_i1_aofs_beg", (VDIM,)),
		(None , "o_i1_aofs_end", (VDIM,)),
	),
	(
		("dut", "o_o_bofs", (VDIM,)),
		(None , "o_o_aofs_beg", (VDIM,)),
		(None , "o_o_aofs_end", (VDIM,)),
	),
	(
		("dut", "o_alu_bofs", (VDIM,)),
		(None , "o_alu_aofs_beg", (VDIM,)),
		(None , "o_alu_aofs_end", (VDIM,)),
	),
])
rst_out_ev, ck_ev = CreateEvents(["rst_out", "ck_ev"])
RegisterCoroutines([
	main(),
])
