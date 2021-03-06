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
from nicotb.protocol import OneWire, TwoWire
from itertools import repeat
from UmiModel import UmiModel, default_sample_conf, npi, npd, newaxis
from Response import Response

def main():
	yield rst_out_ev
	n_bofs, bofs = cfg.CreateBlockTransaction()
	(
		n_alu, bofs_alu, abeg_alu, aend_alu, abeg_id_alu, aend_id_alu, dummy
	) = cfg.CreateAccumBlockTransaction(bofs[0])[-1]
	master = TwoWire.Master(src_rdy, src_ack, src_bus, ck_ev)
	inst_commit = OneWire.Master(inst_commit_dval, tuple(), ck_ev)
	resp = Response(inst_commit.SendIter, ck_ev)
	slave = TwoWire.Slave(inst_rdy, inst_ack, inst_bus, ck_ev, callbacks=[bg.Get, lambda _:resp.Append(tuple())])
	data_bus = master.values

	# start simulation
	for i in range(n_alu):
		# Expect?
		(
			n_aofs_alu, agofs_alu, alofs_alu,
			rt_i_alu, rg_li_alu, rg_ri_alu
		) = cfg.CreateAccumTransaction(abeg_alu[i], aend_alu[i])
		accum_alu, warpid_alu, rg_flat_alu = cfg.CreateAccumWarpTransaction(
			abeg_alu[i], aend_alu[i],
			None, rg_li_alu, rg_ri_alu,
			cfg.n_inst
		)
		bofs_alu, blofs_alu, valid_alu = cfg.CreateBofsValidTransaction(bofs[0], warpid_alu)
		# /2 since in hardware, we use two warps (2x, 2x+1) to form a large warp x
		warpid_alu >>= 1
		npd.copyto(data_bus.i_bofs         , bofs[0])
		npd.copyto(data_bus.i_aofs_beg     , abeg_alu[i])
		npd.copyto(data_bus.i_aofs_end     , aend_alu[i])
		npd.copyto(data_bus.i_dual_axis    , cfg.pcfg['dual_axis'])
		npd.copyto(data_bus.i_dual_order   , cfg.pcfg['dual_order'])
		npd.copyto(data_bus.i_bgrid_step   , cfg.pcfg["local"][0])
		npd.copyto(data_bus.i_bsub_up_order, cfg.pcfg["lg_vsize_2x"][0])
		npd.copyto(data_bus.i_bsub_lo_order, cfg.pcfg["lg_vshuf"][0])
		npd.copyto(data_bus.i_aboundary    , cfg.acfg["total"][0])
		npd.copyto(data_bus.i_inst_id_begs , cfg.n_inst[0])
		npd.copyto(data_bus.i_inst_id_ends , cfg.n_inst[1])
		col.Resize(rg_flat_alu.size)
		tst.Expect((bofs_alu[:,0,:],agofs_alu[accum_alu],rg_flat_alu[:,newaxis],warpid_alu[:,newaxis]))
		yield from master.Send(data_bus)
		yield ck_ev

	for i in range(10):
		yield ck_ev
	assert col.is_clean
	FinishSim()

cfg = default_sample_conf
VDIM = cfg.VDIM
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
		("dut", "i_bofs", (VDIM,)),
		(None , "i_aofs_beg", (VDIM,)),
		(None , "i_aofs_end", (VDIM,)),
		(None , "i_dual_axis"),
		(None , "i_dual_order"),
		(None , "i_bgrid_step", (VDIM,)),
		(None , "i_bsub_up_order", (VDIM,)),
		(None , "i_bsub_lo_order", (VDIM,)),
		(None , "i_aboundary", (VDIM,)),
		(None , "i_inst_id_begs", (VDIM+1,)),
		(None , "i_inst_id_ends", (VDIM+1,)),
	),
	(
		("dut", "o_bofs", (VDIM,)),
		(None , "o_aofs", (VDIM,)),
		(None , "o_pc"),
		(None , "o_warpid"),
	),
])
scb = Scoreboard("SimdDriver")
tst = scb.GetTest("test", 10)
col = Stacker(callbacks=[tst.Get])
bg = BusGetter(callbacks=[col.Get])
RegisterCoroutines([
	main(),
])
