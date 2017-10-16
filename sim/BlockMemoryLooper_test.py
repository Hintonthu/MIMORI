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
	n_golden, bofs, mofs_i0, mofs_i1, mofs_o = cfg.CreateBlockTransaction()
	scb = Scoreboard()
	test_b = scb.GetTest("bofs")
	test_0 = scb.GetTest("i0_mofs")
	test_1 = scb.GetTest("i1_mofs")
	test_o = scb.GetTest("o_mofs")
	st_b = Stacker(n_golden, [test_b.Get])
	st_0 = Stacker(n_golden * N_I0CFG, [test_0.Get])
	st_1 = Stacker(n_golden * N_I1CFG, [test_1.Get])
	st_o = Stacker(n_golden * N_OCFG, [test_o.Get])
	master = TwoWire.Master(rdy_bus_s, ack_bus_s, bus_s, ck_ev)
	master_bdone = OneWire.Master(dval_bus, tuple(), ck_ev)
	resp = Response(master_bdone.SendIter, ck_ev, B=100)
	i_data = master.values
	slave_b = TwoWire.Slave(rdy_bus_b, ack_bus_b, bus_b, ck_ev, callbacks=[st_b.Get, lambda x: resp.Append(tuple())])
	slave_0 = TwoWire.Slave(rdy_bus_0, ack_bus_0, bus_0, ck_ev, callbacks=[st_0.Get])
	slave_1 = TwoWire.Slave(rdy_bus_1, ack_bus_1, bus_1, ck_ev, callbacks=[st_1.Get])
	slave_o = TwoWire.Slave(rdy_bus_o, ack_bus_o, bus_o, ck_ev, callbacks=[st_o.Get])
	yield rst_out_ev

	# start simulation
	cfg_bus = CreateBus((("dut", "BF_BW"),))
	cfg_bus.Read()
	assert not npd.any(cfg.pcfg['local_exp'] >> (cfg_bus.value[0]+1))
	npd.copyto(i_data[0], cfg.pcfg['local_sig'][0])
	npd.copyto(i_data[1], cfg.pcfg['local_exp'][0])
	npd.copyto(i_data[2], cfg.pcfg['last'][0]     )
	npd.copyto(i_data[3][:N_I0CFG], cfg.umcfg_i0['ustride'][:,DIM:])
	npd.copyto(i_data[4][:N_I0CFG], cfg.umcfg_i0['mstart'])
	npd.copyto(i_data[5][:N_I0CFG], cfg.umcfg_i0['udim'][:,DIM:]   )
	npd.copyto(i_data[7][:N_I1CFG], cfg.umcfg_i1['ustride'][:,DIM:])
	npd.copyto(i_data[8][:N_I1CFG], cfg.umcfg_i1['mstart'])
	npd.copyto(i_data[9][:N_I1CFG], cfg.umcfg_i1['udim'][:,DIM:])
	npd.copyto(i_data[11][:N_OCFG], cfg.umcfg_o['ustride'][:,DIM:])
	npd.copyto(i_data[12][:N_OCFG], npi.sum(cfg.umcfg_o['mstart']) + cfg.umcfg_o['mlinear'])
	i_data[ 6][0] = N_I0CFG
	i_data[10][0] = N_I1CFG
	i_data[13][0] = N_OCFG

	test_b.Expect((bofs,))
	test_0.Expect((npd.reshape(mofs_i0, (-1, cfg.DIM)),))
	test_1.Expect((npd.reshape(mofs_i1, (-1, cfg.DIM)),))
	test_o.Expect((npd.reshape(mofs_o, (-1, 1)),))
	yield from master.Send(i_data)

	for i in range(30):
		yield ck_ev
	assert st_b.is_clean
	assert st_0.is_clean
	assert st_1.is_clean
	assert st_o.is_clean
	FinishSim()

cfg = default_sample_conf
N_I0CFG = cfg.n_i0[1][-1]
N_I1CFG = cfg.n_i1[1][-1]
N_OCFG = cfg.n_o[1][-1]
DIM    = cfg.DIM
(
	rdy_bus_s, ack_bus_s,
	rdy_bus_b, ack_bus_b,
	rdy_bus_0, ack_bus_0,
	rdy_bus_1, ack_bus_1,
	rdy_bus_o, ack_bus_o,
	dval_bus,
) = CreateBuses([
	(("dut", "src_rdy"),),
	(("dut", "src_ack"),),
	(("bofs_rdy"),),
	(("bofs_canack"),),
	(("i0_mofs_rdy"),),
	(("i0_mofs_canack"),),
	(("i1_mofs_rdy"),),
	(("i1_mofs_canack"),),
	(("o_mofs_rdy"),),
	(("o_mofs_canack"),),
	(("dut", "blkdone_dval"),),
])
bus_s, bus_b, bus_0, bus_1, bus_o = CreateBuses([
	(
		("dut", "i_bgrid_frac"    , (DIM,)),
		(None , "i_bgrid_shamt"   , (DIM,)),
		(None , "i_bgrid_last"    , (DIM,)),
		(None , "i_i0_mofs_steps" , (N_I0CFG,DIM)),
		(None , "i_i0_mofs_starts", (N_I0CFG,DIM)),
		(None , "i_i0_mofs_shufs" , (N_I0CFG,DIM)),
		(None , "i_i0_id_end"),
		(None , "i_i1_mofs_steps" , (N_I1CFG,DIM)),
		(None , "i_i1_mofs_starts", (N_I1CFG,DIM)),
		(None , "i_i1_mofs_shufs" , (N_I1CFG,DIM)),
		(None , "i_i1_id_end"),
		(None , "i_o_mofs_steps"  , (N_OCFG,DIM)),
		(None , "i_o_mofs_linears", (N_OCFG,1)),
		(None , "i_o_id_end"),
	),
	(("dut", "o_bofs", (DIM,)),),
	(("dut", "o_i0_mofs", (DIM,)),),
	(("dut", "o_i1_mofs", (DIM,)),),
	(("dut", "o_o_mofs", (1,)),),
])
rst_out_ev, ck_ev = CreateEvents(["rst_out", "ck_ev"])
RegisterCoroutines([
	main(),
])
