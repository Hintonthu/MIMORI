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
from UmiModel import npi, npd, newaxis, UmiModel

def main():
	scb = Scoreboard("RemapCache")
	test = scb.GetTest(f"test{RMC_CONF}")
	st = Stacker(0, callbacks=[lambda mat: npd.savetxt("rmc_got.txt", mat[0], fmt="%d"), test.Get])
	bg = BusGetter(callbacks=[st.Get])
	wad_master = OneWire.Master(wad_dval_bus, wad_bus, ck_ev)
	ra_master = TwoWire.Master(ra_rdy_bus, ra_ack_bus, ra_bus, ck_ev)
	rd_slave = TwoWire.Slave(rd_rdy_bus, rd_ack_bus, rd_bus, ck_ev, callbacks=[bg.Get])
	wad_data = wad_master.values
	ra_data = ra_master.values
	yield rst_out_ev

	# start simulation
	npd.copyto(cfg_bus.values.i_xor_srcs[0], xsrc)
	cfg_bus.values.i_xor_swaps[0] = xswap
	cfg_bus.Write()
	yield ck_ev

	def IterWrite():
		for i in range(N_VEC):
			wad_data[0][0] = 0
			wad_data[1][0] = i
			npd.copyto(wad_data[2], npi.arange(i*VSIZE, (i+1)*VSIZE))
			yield wad_data
	yield from wad_master.SendIter(IterWrite())

	for i in range(10):
		yield ck_ev

	NTEST = N_VEC*VSIZE-npd.sum(stride, dtype=npd.int32)-1
	raddr = npi.arange(NTEST)[:, newaxis] + STEP
	st.Resize(NTEST)
	test.Expect((raddr,))
	def IterRead():
		for i in raddr:
			ra_data[0][0] = 0
			npd.copyto(ra_data[1], i)
			yield ra_data
	yield from ra_master.SendIter(IterRead())

	for i in range(100):
		yield ck_ev
	assert st.is_clean
	FinishSim()

VSIZE = 32
CV_BW = 5
STRIDES = [
	# (0) normal
	[3,2,12,8,16],
	# (1) broadcast
	[3,0,12,8,16],
	# (2) shuffle
	[12,24,48,1,2],
	# (3) shuffle+broadcast
	[12,8,16,3,0],
	# (4) xor
	[4,8,16,32,64],
	# (5) xor+shuffle
	[16,32,64,2,4],
]
try:
	from os import environ
	RMC_CONF = int(environ["RMC_CONF"])
except:
	RMC_CONF = 0

stride = npi.array(STRIDES[RMC_CONF])
xsrc = npi.empty(CV_BW)
xswap = npi.empty(1)
UmiModel._CalXor(stride, xsrc, xswap)
N_VEC = 10
STEP = [0]
for i in stride:
	STEP = STEP + [j+i for j in STEP]
STEP = npi.array(STEP)
(
	ra_rdy_bus, ra_ack_bus,
	rd_rdy_bus, rd_ack_bus,
	wad_dval_bus,
	ra_bus, rd_bus, wad_bus, cfg_bus
) = CreateBuses([
	((""   , "ra_rdy"),),
	((""   , "ra_ack"),),
	((""   , "rd_rdy"),),
	((""   , "rd_canack"),),
	(("dut", "wad_dval"),),
	(
		("dut","i_rid"),
		(None ,"i_raddr", (VSIZE,)),
	),
	(
		("dut", "o_rdata", (VSIZE,)),
	),
	(
		("dut", "i_wid"),
		(None , "i_whiaddr"),
		(None , "i_wdata", (VSIZE,)),
	),
	(
		("dut", "i_xor_srcs", (1,CV_BW)),
		(None , "i_xor_swaps"  , (1,)),
	),
])
rst_out_ev, ck_ev = CreateEvents(["rst_out", "ck_ev"])
RegisterCoroutines([
	main(),
])
