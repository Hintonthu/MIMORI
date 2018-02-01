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
	testa = scb.GetTest("testa")
	testm = scb.GetTest("testm")
	sta = Stacker(0, [testa.Get])
	stm = Stacker(0, [testm.Get])
	master = TwoWire.Master(s_rdy_bus, s_ack_bus, s_bus, ck_ev)
	i_data = master.values
	slavea = TwoWire.Slave(a_rdy_bus, a_ack_bus, a_bus, ck_ev, callbacks=[sta.Get])
	slavem = TwoWire.Slave(m_rdy_bus, m_ack_bus, m_bus, ck_ev, callbacks=[stm.Get])
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
	if SUM_ALL:
		# we are testing output pipeline
		diff_id = a_range_o[:,0] != a_range_o[:,1]
		n_trim = npd.count_nonzero(diff_id)
		beg_trim = a_range_o[diff_id,0]
		end_trim = a_range_o[diff_id,1]
		fid = UmiModel._FlatRangeNorep(a_range_o)
	else:
		# we are testing input pipeline
		diff_id = a_range_i0[:,0] != a_range_i0[:,1]
		n_trim = npd.count_nonzero(diff_id)
		beg_trim = a_range_i0[diff_id,0]
		end_trim = a_range_i0[diff_id,1]
		fid = UmiModel._FlatRangeNorep(a_range_i0)
	aofs_trim = abofs[diff_id]
	bofs_trim = npd.broadcast_to(bofs[0], (n_trim, DIM))

	# start simulation
	npd.copyto(i_data[0], bofs[0]                  )
	npd.copyto(i_data[1], cfg.acfg["local_sig"][0] )
	npd.copyto(i_data[2], cfg.acfg["local_exp"][0] )
	npd.copyto(i_data[3], cfg.acfg["last"][0]      )
	npd.copyto(i_data[4], cfg.acfg["local"][0]-1   )
	npd.copyto(i_data[5], cfg.acfg["boundary"][0]-1)
	if SUM_ALL:
		# we are testing output pipeline
		npd.copyto(i_data[6], cfg.n_o[0])
		npd.copyto(i_data[7], cfg.n_o[1])
	else:
		# we are testing input pipeline
		npd.copyto(i_data[6], cfg.n_i0[0])
		npd.copyto(i_data[7], cfg.n_i0[1])

	testa.Expect((aofs_trim, bofs_trim))
	testm.Expect((fid[:, newaxis],))
	sta.Resize(aofs_trim.shape[0])
	stm.Resize(fid.shape[0])
	yield from master.Send(i_data)

	for i in range(300):
		yield ck_ev
	assert sta.is_clean
	assert stm.is_clean
	FinishSim()

cfg = default_sample_conf
params = CreateBus((
	("dut", "SUM_ALL"),
	(None , "DIM",),
	(None , "ODIM",),
))
params.Read()
SUM_ALL = params.values[0][0]
DIM     = params.values[1][0]
ODIM    = params.values[2][0]
N_CFG   = cfg.n_o[1][-1] if SUM_ALL else cfg.n_i0[1][-1]
(
	s_rdy_bus, s_ack_bus,
	a_rdy_bus, a_ack_bus,
	m_rdy_bus, m_ack_bus,
	s_bus, a_bus, m_bus
) = CreateBuses([
	(("", "s_rdy"),),
	(("", "s_ack"),),
	(("", "da_rdy"),),
	(("", "da_canack"),),
	(("", "dm_rdy"),),
	(("", "dm_canack"),),
	(
		("dut","i_bofs"       , (DIM,)),
		(None ,"i_agrid_frac" , (DIM,)),
		(None ,"i_agrid_shamt", (DIM,)),
		(None ,"i_agrid_last" , (DIM,)),
		(None ,"i_alocal_last", (DIM,)),
		(None ,"i_aboundary"  , (DIM,)),
		#(None ,"i_mofs_starts", (N_CFG,DIM,)),
		#(None ,"i_mofs_asteps", (N_CFG,DIM,)),
		#(None ,"i_mofs_ashufs", (N_CFG,DIM,)),
		(None ,"i_id_begs"    , (DIM+1,)),
		(None ,"i_id_ends"    , (DIM+1,)),
	),
	(
		("dut", "o_aofs", (DIM,)),
		#(None , "o_alast", (DIM,)),
		(None , "o_bofs", (DIM,)),
	),
	(
		#("dut", "o_mofs", (ODIM,)),
		("dut", "o_id"),
	),
])
rst_out_ev, ck_ev = CreateEvents(["rst_out", "ck_ev"])
RegisterCoroutines([
	main(),
])
