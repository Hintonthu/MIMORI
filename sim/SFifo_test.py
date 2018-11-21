# Copyright 2018 Yu Sheng Lin

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
from nicotb.protocol import TwoWire
from nicotb.primitives import Lock
import numpy as np

def main():
	seed = np.random.randint(10000)
	print(f"Seed for this run is {seed}")
	np.random.seed(seed)
	N = 250
	# will test probability range(1, MATRIX+1)/MATRIX for both src and test
	MATRIX = 3
	scb = Scoreboard("Fifo")
	test = scb.GetTest("test")
	lk = Lock(locked=True)
	st = Stacker(N, callbacks=[test.Get, lambda dummy: lk.Release()])
	bg = BusGetter(callbacks=[st.Get])
	master = TwoWire.Master(srdy, sack, idata, ck_ev, B=MATRIX)
	slave = TwoWire.Slave(drdy, dack, odata, ck_ev, callbacks=[bg.Get], B=MATRIX)
	yield rst_out_ev
	yield ck_ev
	i_data = idata.value
	def It():
		for i in range(N):
			i_data[0] = i
			yield i_data

	golden = np.arange(N)[:,np.newaxis]
	for prob_m in range(1, MATRIX+1):
		for prob_s in range(1, MATRIX+1):
			test.Expect((golden,))
			print(f"Test probability master {prob_s}/{MATRIX} and slave {prob_m}/{MATRIX}...")
			master.A = prob_m
			slave.A = prob_s
			yield from master.SendIter(It())
			# wait until get data and lock it again
			yield lk.acquire
			print("Done")
			for i in range(100):
				yield ck_ev

	assert st.is_clean
	FinishSim()

(
	srdy, sack, idata,
	drdy, dack, odata,
) = CreateBuses([
	(("dut", "src_rdy"),),
	(("dut", "src_ack"),),
	(("dut", "i_data"),),
	((   "", "dst_rdy"),),
	((   "", "dst_canack"),),
	(("dut", "o_data"),),
])
rst_out_ev, ck_ev = CreateEvents(["rst_out", "ck_ev"])
RegisterCoroutines([
	main(),
])
