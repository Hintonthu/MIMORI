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
from nicotb.protocol import TwoWire
from itertools import repeat
from UmiModel import UmiModel, default_sample_conf, npi, npd, newaxis

def main():
	yield rst_out_ev
	master = TwoWire.Master(bofs_rdy, bofs_ack, bofs_bus, ck_ev)
	master_linear = TwoWire.Master(mofs_rdy, mofs_ack, mofs_bus, ck_ev)
	slave = TwoWire.Slave(av_rdy, av_ack, av_bus, ck_ev, callbacks=[dc.Get])
	linear_bus = master_linear.values
	data_bus = master.values

	# simulation
	(
		n_bofs, bofs,
		mofs_i0, mofs_i1, mofs_o
	) = cfg.CreateBlockTransaction()
	for i in range(n_bofs):
		(
			n_abofs, abofs, alast,
			a_range_i0, a_range_i1, a_range_o,
			abmofs_i0, abmofs_i1, abmofs_o
		) = cfg.CreateAccumBlockTransaction(mofs_i0[i], mofs_i1[i], mofs_o[i])
		sram_a0 = 0
		sram_a1 = 0
		for j in range(n_abofs):
			# SRAM address
			sl_i0 = slice(a_range_i0[j,0], a_range_i0[j,1])
			sl_i1 = slice(a_range_i1[j,0], a_range_i1[j,1])
			sl_o = slice(a_range_o[j,0], a_range_o[j,1])
			sram_a0, lmofs_i0 = cfg.AllocSram(sram_a0, cfg.umcfg_i0["lmsize"][sl_i0])
			sram_a1, lmofs_i1 = cfg.AllocSram(sram_a1, cfg.umcfg_i1["lmsize"][sl_i1])
			for k in range(a_range_i0[j,1] - a_range_i0[j,0]):
				npd.copyto(linear_bus[0], a_range_i0[j,0] + k)
				npd.copyto(linear_bus[1], lmofs_i0[k])
				yield from master_linear.Send(linear_bus)

			(
				n_aofs, agofs,
				accum_i0, accum_i1, accum_o, accum_inst,
				warp_i0, warp_i1, warp_o, warp_inst,
				rg_flat_i0, rg_flat_i1, rg_flat_o, rg_flat_inst,
				rt_flat_i0, rt_flat_i1, rt_flat_o,
				amofs_i0, amofs_i1, amofs_o
			) = cfg.CreateAccumTransaction(
				alast[j] if ST_MODE else abofs[j], alast[j],
				abmofs_i0[j,sl_i0], abmofs_i1[j,sl_i1], abmofs_o[j,sl_o],
				a_range_i0[j], a_range_i1[j], a_range_o[j],
				lmofs_i0, lmofs_i1
			)
			bofs_i0, valid_i0 = cfg.CreateBofsValidTransaction(bofs[i], warp_i0)
			a_i0, a_i1, a_o = cfg.CreateVectorAddressTransaction(
				bofs[i],
				rg_flat_i0, rg_flat_i1, rg_flat_o,
				amofs_i0, amofs_i1, amofs_o
			)
			valid_i0_packed = npd.bitwise_or.reduce(valid_i0 << npi.arange(VSIZE)[newaxis,:], axis=1)

			# Send source
			npd.copyto(data_bus[ 0], bofs[j])
			npd.copyto(data_bus[ 1], abofs[j])
			npd.copyto(data_bus[ 2], alast[j])
			npd.copyto(data_bus[ 3], cfg.pcfg["boundary"][0])
			npd.copyto(data_bus[ 4], cfg.pcfg["local"][0]-(1<<(cfg.pcfg["lg_vshuf"][0]+cfg.pcfg["lg_vsize"][0])))
			npd.copyto(data_bus[ 5], cfg.v_nd >> cfg.pcfg["lg_vshuf"][0])
			npd.copyto(data_bus[ 6], cfg.pcfg["lg_vshuf"][0]+cfg.pcfg["lg_vsize"][0])
			npd.copyto(data_bus[ 7], cfg.pcfg["lg_vshuf"][0])
			npd.copyto(data_bus[ 8], cfg.acfg["boundary"][0])
			npd.copyto(data_bus[ 9], cfg.umcfg_i0["lustride"][:,DIM:])
			npd.copyto(data_bus[10], cfg.umcfg_i0["vlinear"][:,1<<npi.arange(CV_BW)])
			npd.copyto(data_bus[11], cfg.umcfg_i0["lustride"][:,:DIM])
			npd.copyto(data_bus[12], cfg.n_i0[0][i])
			npd.copyto(data_bus[13], cfg.n_i0[1][i])
			if ST_MODE:
				dc.Resize(a_i0.shape[0]*2)
				npd.copyto(data_bus[14], 1)
				npd.copyto(data_bus[15], 0)
				npd.copyto(data_bus[16], 2)
				data_bus[17][:2] = [0,1]
				tst.Expect((
					npd.repeat(rg_flat_i0[:,newaxis], 2, axis=0),
					(a_i0[:,newaxis,:]+data_bus[17][:2][:,newaxis]).reshape(-1, VSIZE),
					npd.repeat(valid_i0_packed[:,newaxis], 2, axis=0),
					# abcde --> 0a0b0c0d
					npd.column_stack((npd.zeros_like(rt_flat_i0), rt_flat_i0)).reshape(-1, 1),
				))
			else:
				dc.Resize(a_i0.shape[0])
				npd.copyto(data_bus[14], 0)
				tst.Expect((rg_flat_i0[:,newaxis], a_i0, valid_i0_packed[:,newaxis], rt_flat_i0[:,newaxis]))
			yield from master.Send(data_bus)
			for i in range(30):
				yield ck_ev
			assert dc.is_clean
			FinishSim()

try:
	from os import environ
	ST_MODE = bool(environ["STENCIL"])
except:
	ST_MODE = False
cfg = default_sample_conf
VSIZE = cfg.VSIZE
DIM = cfg.DIM
CV_BW = cfg.LG_VSIZE
N_CFG = cfg.n_i0[1][-1]
N_SLUT = cfg.N_SLUT
scb = Scoreboard()
tst = scb.GetTest("test")
dc = Stacker(0, callbacks=[tst.Get])
rst_out_ev, ck_ev = CreateEvents(["rst_out", "ck_ev"])
(
	bofs_rdy, bofs_ack,
	mofs_rdy, mofs_ack,
	av_rdy, av_ack
) = CreateBuses([
	(("bofs_rdy",),),
	(("bofs_ack",),),
	(("mofs_rdy",),),
	(("mofs_ack",),),
	(("av_rdy",),),
	(("av_canack",),),
])
bofs_bus, mofs_bus, av_bus = CreateBuses([
	(
		("dut", "i_bofs", (DIM,)),
		(None , "i_aofs", (DIM,)),
		(None , "i_alast", (DIM,)),
		(None , "i_bboundary", (DIM,)),
		(None , "i_blocal_last", (DIM,)),
		(None , "i_bsubofs", (VSIZE,DIM,)),
		(None , "i_bsub_up_order", (DIM,)),
		(None , "i_bsub_lo_order", (DIM,)),
		(None , "i_aboundary", (DIM,)),
		(None , "i_mofs_bsteps", (N_CFG,DIM,)),
		(None , "i_mofs_bsubsteps", (N_CFG,CV_BW,)),
		(None , "i_mofs_asteps", (N_CFG,DIM,)),
		(None , "i_id_begs", (DIM+1,)),
		(None , "i_id_ends", (DIM+1,)),
		(None , "i_stencil"),
		(None , "i_stencil_begs", (N_CFG,)),
		(None , "i_stencil_ends", (N_CFG,)),
		(None , "i_stencil_lut", (N_SLUT,)),
	),
	(
		("dut", "i_mofs"),
		(None , "i_id"),
	),
	(
		("dut", "o_id"),
		(None , "o_address", (VSIZE,)),
		(None , "o_valid"),
		(None , "o_retire"),
	),
])
RegisterCoroutines([
	main(),
])
