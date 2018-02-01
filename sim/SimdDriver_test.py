# Copyright 2016 Yu Sheng Lin

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
from nicotb.protocol import OneWire, TwoWire
from itertools import repeat
from UmiModel import UmiModel, default_sample_conf, npi, npd, newaxis
from Response import Response

def main():
	yield rst_out_ev
	(
		n_bofs, bofs,
		mofs_i0, mofs_i1, mofs_o
	) = cfg.CreateBlockTransaction()
	(
		n_abofs, abofs, alast,
		a_range_i0, a_range_i1, a_range_o,
		abmofs_i0, abmofs_i1, abmofs_o
	) = cfg.CreateAccumBlockTransaction(mofs_i0[0], mofs_i1[0], mofs_o[0])
	master = TwoWire.Master(src_rdy, src_ack, src_bus, ck_ev)
	inst_commit = OneWire.Master(inst_commit_dval, tuple(), ck_ev)
	resp = Response(inst_commit.SendIter, ck_ev)
	slave = TwoWire.Slave(inst_rdy, inst_ack, inst_bus, ck_ev, callbacks=[col.Get, lambda _:resp.Append(tuple())])
	data_bus = master.values

	# start simulation
	sram_a0 = 0
	sram_a1 = 0
	for i in range(n_abofs):
		# Expect?
		sl_i0 = slice(a_range_i0[i,0], a_range_i0[i,1])
		sl_i1 = slice(a_range_i1[i,0], a_range_i1[i,1])
		sl_o = slice(a_range_o[i,0], a_range_o[i,1])
		sram_a0, lmofs_i0 = cfg.AllocSram(sram_a0, cfg.umcfg_i0["lmsize"][sl_i0])
		sram_a1, lmofs_i1 = cfg.AllocSram(sram_a1, cfg.umcfg_i1["lmsize"][sl_i1])
		(
			n_aofs, agofs,
			accum_i0, accum_i1, accum_o, accum_inst,
			warp_i0, warp_i1, warp_o, warp_inst,
			rg_flat_i0, rg_flat_i1, rg_flat_o, rg_flat_inst,
			rt_flat_i0, rt_flat_i1, rt_flat_o,
			amofs_i0, amofs_i1, amofs_o
		) = cfg.CreateAccumTransaction(
			abofs[i], alast[i],
			abmofs_i0[i,sl_i0], abmofs_i1[i,sl_i1], abmofs_o[i,sl_o],
			a_range_i0[i], a_range_i1[i], a_range_o[i],
			lmofs_i0, lmofs_i1
		)
		bofs_inst, valid_inst = cfg.CreateBofsValidTransaction(bofs[0], warp_inst)
		npd.copyto(data_bus[0], bofs[0])
		npd.copyto(data_bus[1], abofs[i])
		npd.copyto(data_bus[2], alast[i])
		npd.copyto(data_bus[3], cfg.pcfg["local"][0]-(1<<(cfg.pcfg["lg_vshuf"][0]+cfg.pcfg["lg_vsize"][0])))
		npd.copyto(data_bus[4], cfg.pcfg["lg_vshuf"][0]+cfg.pcfg["lg_vsize"][0])
		npd.copyto(data_bus[5], cfg.pcfg["lg_vshuf"][0])
		npd.copyto(data_bus[6], cfg.acfg["boundary"][0]-1)
		npd.copyto(data_bus[7], cfg.n_inst[0])
		npd.copyto(data_bus[8], cfg.n_inst[1])
		col.Resize(rg_flat_inst.size)
		tst.Expect((bofs_inst[:,0,:],agofs[accum_inst],rg_flat_inst[:,newaxis],warp_inst[:,newaxis]))
		yield from master.Send(data_bus)
		yield ck_ev

	for i in range(10):
		yield ck_ev
	assert col.is_clean
	FinishSim()

cfg = default_sample_conf
DIM = cfg.DIM
rst_out_ev, ck_ev = CreateEvents(["rst_out", "ck_ev"])
src_rdy, src_ack, inst_rdy, inst_ack, inst_commit_dval = CreateBuses([
	(("dut", "abofs_rdy"),),
	(("dut", "abofs_ack"),),
	(("inst_rdy"),),
	(("inst_canack"),),
	(("dut", "inst_commit_dval"),),
])
src_bus, inst_bus = CreateBuses([
	(
		("dut", "i_bofs", (DIM,)),
		(None , "i_aofs", (DIM,)),
		(None , "i_alast", (DIM,)),
		(None , "i_blocal_last", (DIM,)),
		(None , "i_bsub_up_order", (DIM,)),
		(None , "i_bsub_lo_order", (DIM,)),
		(None , "i_aboundary", (DIM,)),
		(None , "i_inst_id_begs", (DIM+1,)),
		(None , "i_inst_id_ends", (DIM+1,)),
	),
	(
		("dut", "o_bofs", (DIM,)),
		(None , "o_aofs", (DIM,)),
		(None , "o_pc"),
		(None , "o_warpid"),
	),
])
scb = Scoreboard()
tst = scb.GetTest("test", 10)
col = Stacker(callbacks=[tst.Get])
RegisterCoroutines([
	main(),
])
