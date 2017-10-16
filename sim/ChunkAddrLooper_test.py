# Copyright
# Yu Sheng Lin, 2016-2017
# Yen Hsi Wang, 2017

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
from nicotb.protocol import TwoWire
from itertools import repeat
from UmiModel import UmiModel, default_sample_conf, npi, npd, newaxis
from os import getenv

def main():
	scb = Scoreboard()
	test = scb.GetTest("test")
	st = Stacker(0, [test.Get])
	n_bofs, bofs, mofs_i0, mofs_i1, mofs_o = cfg.CreateBlockTransaction()
	master = TwoWire.Master(mrdy_bus, mack_bus, mofs_bus, ck_ev)
	i_data = master.values
	slave = TwoWire.Slave(crdy_bus, cack_bus, cmd_bus, ck_ev, callbacks=[st.Get])
	yield rst_out_ev

	# start simulation
	TEST0 = not getenv("TEST0") is None
	print(f"Testing {0 if TEST0 else 1}...")
	TEST_UMCFG = cfg.umcfg_i0 if TEST0 else cfg.umcfg_i1
	for i in range(n_bofs):
		(
			n_abofs, abofs, alast,
			a_range_i0, a_range_i1, a_range_o,
			abmofs_i0, abmofs_i1, abmofs_o
		) = cfg.CreateAccumBlockTransaction(mofs_i0[i], mofs_i1[i], mofs_o[i])
		for j in range(n_abofs):
			TEST_ABMOFS = abmofs_i0[j,0] if TEST0 else abmofs_i1[j,0]
			ans = cfg.CreateDramReadTransaction(TEST_ABMOFS, TEST_UMCFG, 0)
			st.Resize(ans.shape[0])
			npd.copyto(i_data[0], TEST_ABMOFS)
			npd.copyto(i_data[1], TEST_UMCFG["lmpad"][0])
			npd.copyto(i_data[2], TEST_UMCFG["mboundary"][0]-TEST_UMCFG["mmultiplier"][0])
			npd.copyto(i_data[3], (TEST_UMCFG["lmwidth"][0]-1)*TEST_UMCFG["mmultiplier"][0])
			i_data[4][0] = TEST_UMCFG["mlinear"][0]
			test.Expect(tuple(
				ans[k][:,newaxis] for k in ("cmd_type","islast","addr","ofs","len")
			))
			yield from master.Send(i_data)
			for i in range(100):
				yield ck_ev

	for i in range(300):
		yield ck_ev
	assert st.is_clean
	FinishSim()

cfg = default_sample_conf

mrdy_bus, mack_bus, crdy_bus, cack_bus, mofs_bus, cmd_bus = CreateBuses([
	(("mofs_rdy"),),
	(("mofs_ack"),),
	(("cmd_rdy"),),
	(("cmd_canack"),),
	(
		("dut", "i_mofs"  , (cfg.DIM,)),
		(None , "i_mpad"  , (cfg.DIM,)),
		(None , "i_mbound", (cfg.DIM,)),
		(None , "i_mlast" , (cfg.DIM,)),
		(None , "i_maddr"),
	),
	(
		("dut", "o_cmd_type"),
		("o_cmd_islast",),
		("o_cmd_addr",),
		("o_cmd_addrofs",),
		("o_cmd_len",),
	),
])
rst_out_ev, ck_ev = CreateEvents(["rst_out", "ck_ev"])
RegisterCoroutines([
	main(),
])
