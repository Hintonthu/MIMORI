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
	scb = Scoreboard("WriteCollector")
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
	n_bofs, bofs = conf.CreateBlockTransaction()
	for i in range(n_bofs):
		(
			n_o, bofs_o, abeg_o, aend_o, abeg_id_o, aend_id_o,
		) = conf.CreateAccumBlockTransaction(bofs[i])[12:18]
		for j in range(n_o):
			# Expect?
			(
				n_aofs_o, agofs_o, alofs_o,
				rt_i_o, rg_li_o, rg_ri_o
			) = conf.CreateAccumTransaction(abeg_o[j], aend_o[j])
			accum_idx_o, warpid_o, rg_flat_o, rt_flat_o = conf.CreateAccumWarpTransaction(
				abeg_o[j], aend_o[j],
				rt_i_o, rg_li_o, rg_ri_o,
				conf.n_o
			)
			bgofs_o, blofs_o, valid_o = conf.CreateBofsValidTransaction(bofs[i], warpid_o)
			addr_o = conf.CreateVectorAddressTransaction(
				bgofs_o[:,0,:], agofs_o[accum_idx_o],
				rg_flat_o, conf.umcfg_o['mlinear'], conf.umcfg_o, False
			)
			valid_o_packed = npd.bitwise_or.reduce(valid_o << npi.arange(VSIZE)[newaxis,:], axis=1).astype('u4')

			# output part
			if addr_o.size:
				da, dm = conf.CreateDramWriteTransaction(valid_o, addr_o)
				dm_packed = npd.bitwise_or.reduce(dm << npi.arange(conf.DRAM_ALIGN)[newaxis,:], axis=1)
				st.Resize(da.shape[0])
				test.Expect((da[:,newaxis], dm_packed[:,newaxis]))
				# Send
				def iter_a():
					for k in range(addr_o.shape[0]):
						npd.copyto(master_ad[0], addr_o[k])
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
VSIZE = conf.VSIZE
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
		("dut", "i_address", (VSIZE,)),
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
