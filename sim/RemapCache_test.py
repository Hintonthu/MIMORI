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
from nicotb.protocol import OneWire, TwoWire
from itertools import repeat
from UmiModel import npi, npd, newaxis

def main():
	scb = Scoreboard("RemapCache")
	test = scb.GetTest(f"test{RMC_CONF}")
	st = Stacker(0, [lambda mat: npd.savetxt("rmc_got.txt", mat[0], fmt="%d"), test.Get])
	wad_master = OneWire.Master(wad_dval_bus, wad_bus, ck_ev)
	ra_master = TwoWire.Master(ra_rdy_bus, ra_ack_bus, ra_bus, ck_ev)
	rd_slave = TwoWire.Slave(rd_rdy_bus, rd_ack_bus, rd_bus, ck_ev, callbacks=[st.Get])
	wad_data = wad_master.values
	ra_data = ra_master.values
	yield rst_out_ev

	# start simulation
	cfg_bus.values.i_xor_masks[0] = BMASK
	npd.copyto(cfg_bus.values.i_xor_schemes, XOR_SRC)
	cfg_bus.values.i_xor_configs[0] = BROT
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

	NTEST = N_VEC*VSIZE-sum(STRIDES)-1
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
SBXB = (
	# (1) normal
	([3,2,12,8,16], 0, 0, 0),
	# (2) broadcast
	([3,0,12,8,16], 0, 0, 0),
	# (3) shuffle
	([12,24,48,1,2], 0, 0, 2),
	# (4) shuffle+broadcast
	([12,8,16,3,0], 0, 0, 2),
	# (5) xor
	([4,8,16,32,64], 0b11000, [-1,-1,-1,0,1], 2),
	# (6) xor+shuffle
	([16,32,64,2,4], 0b00110, [-1,0,1,-1,-1], 0b010_01_0_01),
)
try:
	from os import environ
	RMC_CONF = int(environ["RMC_CONF"])
except:
	RMC_CONF = 0

STRIDES, BMASK, XOR_SRC, BROT = SBXB[RMC_CONF]
N_VEC = 10
STEP = [0]
LS = len(STRIDES)
for i in range(LS):
	STEP = STEP + [j+STRIDES[i] for j in STEP]
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
		("dut", "i_xor_masks"  , (1,)),
		(None , "i_xor_schemes", (1,CV_BW)),
		(None , "i_xor_configs", (1,)),
	),
])
rst_out_ev, ck_ev = CreateEvents(["rst_out", "ck_ev"])
RegisterCoroutines([
	main(),
])
