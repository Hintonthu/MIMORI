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
	scb = Scoreboard()
	test = scb.GetTest("test")
	st = Stacker(0, [test.Get])
	master_a = TwoWire.Master(a_rdy_bus, a_ack_bus, a_bus, ck_ev)
	master_d = TwoWire.Master(d_rdy_bus, d_ack_bus, d_bus, ck_ev)
	slave = TwoWire.Slave(w_rdy_bus, w_ack_bus, w_bus, ck_ev, callbacks=[st.Get])
	yield rst_out_ev

	# global
	master_ad = master_a.values
	master_dd = master_d.values

	# simulation
	(
		n_bofs, bofs,
		mofs_i0, mofs_i1, mofs_o
	) = conf.CreateBlockTransaction()
	for i in range(n_bofs):
		(
			n_abofs, abofs, alast,
			a_range_i0, a_range_i1, a_range_o,
			abmofs_i0, abmofs_i1, abmofs_o
		) = conf.CreateAccumBlockTransaction(mofs_i0[i], mofs_i1[i], mofs_o[i])
		sram_a0 = 0
		sram_a1 = 0
		for j in range(n_abofs):
			# SRAM address
			sl_i0 = slice(a_range_i0[j,0], a_range_i0[j,1])
			sl_i1 = slice(a_range_i1[j,0], a_range_i1[j,1])
			sl_o = slice(a_range_o[j,0], a_range_o[j,1])
			sram_a0, lmofs_i0 = conf.AllocSram(sram_a0, conf.umcfg_i0["lmsize"][sl_i0])
			sram_a1, lmofs_i1 = conf.AllocSram(sram_a1, conf.umcfg_i1["lmsize"][sl_i1])

			# Expect?
			(
				n_aofs, agofs,
				accum_i0, accum_i1, accum_o, accum_inst,
				warp_i0, warp_i1, warp_o, warp_inst,
				rg_flat_i0, rg_flat_i1, rg_flat_o, rg_flat_inst,
				rt_flat_i0, rt_flat_i1, rt_flat_o,
				amofs_i0, amofs_i1, amofs_o
			) = conf.CreateAccumTransaction(
				abofs[j], alast[j],
				abmofs_i0[j,sl_i0], abmofs_i1[j,sl_i1], abmofs_o[j,sl_o],
				a_range_i0[j], a_range_i1[j], a_range_o[j],
				lmofs_i0, lmofs_i1
			)
			bofs_o, valid_o = conf.CreateBofsValidTransaction(bofs[i], warp_o)
			a_i0, a_i1, a_o = conf.CreateVectorAddressTransaction(
				bofs[i],
				rg_flat_i0, rg_flat_i1, rg_flat_o,
				amofs_i0, amofs_i1, amofs_o
			)
			valid_o_packed = npd.bitwise_or.reduce(valid_o << npi.arange(conf.VSIZE)[newaxis,:], axis=1).astype("u4")

			# output part
			if a_o.size:
				da, dm = conf.CreateDramWriteTransaction(valid_o, a_o)
				dm_packed = npd.bitwise_or.reduce(dm << npi.arange(conf.DRAM_ALIGN)[newaxis,:], axis=1)
				st.Resize(da.shape[0])
				test.Expect((da[:,newaxis], dm_packed[:,newaxis]))
				# Send
				def iter_a():
					for k in range(a_o.shape[0]):
						npd.copyto(master_ad[0], a_o[k])
						master_ad[1][0] = valid_o_packed[k]
						yield master_ad
				Fork(master_d.SendIter(repeat(tuple(), da.shape[0])))
				yield from master_a.SendIter(iter_a())

		for i in range(100):
			yield ck_ev

	for i in range(100):
		yield ck_ev
	assert st.is_clean
	FinishSim()

conf = default_sample_conf
(
	d_rdy_bus, d_ack_bus,
	a_rdy_bus, a_ack_bus,
	w_rdy_bus, w_ack_bus,
	d_bus, a_bus, w_bus
) = CreateBuses([
	(("dut" , "addrval_rdy"),),
	(("dut" , "addrval_ack"),),
	(("dut" , "alu_dat_rdy"),),
	(("dut" , "alu_dat_ack"),),
	((""    , "w_rdy"),),
	((""    , "w_canack"),),
	tuple(),
	(
		("dut", "i_address", (conf.VSIZE,)),
		(None , "i_valid"),
	),
	(
		("dut", "o_dramwa"),
		(None , "o_dramw_mask"),
	),
])
rst_out_ev, ck_ev = CreateEvents(["rst_out", "ck_ev"])
RegisterCoroutines([
	main(),
])
