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
from nicotb.protocol import TwoWire
from itertools import repeat
from UmiModel import UmiModel, default_sample_conf, npi, npd, newaxis

def main():
	yield rst_out_ev
	master = TwoWire.Master(bofs_rdy, bofs_ack, bofs_bus, ck_ev)
	slave = TwoWire.Slave(av_rdy, av_ack, av_bus, ck_ev, callbacks=[bg.Get])
	data_bus = master.values

	# simulation
	n_bofs, bofs = cfg.CreateBlockTransaction()
	for i in range(n_bofs):
		(
			n_i0, bofs_i0, abeg_i0, aend_i0, abeg_id_i0, aend_id_i0, dummy
		) = cfg.CreateAccumBlockTransaction(bofs[i])[0]
		for j in range(n_i0):
			(
				n_aofs_i0, agofs_i0, alofs_i0,
				rt_i_i0, rg_li_i0, rg_ri_i0
			) = cfg.CreateAccumTransaction(abeg_i0[j], aend_i0[j])
			cfg.AllocSram(0, abeg_id_i0[j], aend_id_i0[j])
			linear_i0 = cfg.umcfg_i0['local_adr'][:,0]
			accum_idx_i0, warpid_i0, rg_flat_i0, rt_flat_i0 = cfg.CreateAccumWarpTransaction(
				abeg_i0[j], aend_i0[j],
				rt_i_i0, rg_li_i0, rg_ri_i0,
				cfg.n_i0
			)
			bgofs_i0, blofs_i0, valid_i0 = cfg.CreateBofsValidTransaction(bofs[i], warpid_i0)
			addr_i0 = cfg.CreateVectorAddressTransaction(
				blofs_i0[:,0,:], alofs_i0[accum_idx_i0],
				rg_flat_i0, linear_i0, cfg.umcfg_i0, True
			)
			valid_i0_packed = npd.bitwise_or.reduce(valid_i0 << npi.arange(VSIZE)[newaxis,:], axis=1)
			# Send source
			npd.copyto(data_bus.i_bofs          , bofs[i])
			npd.copyto(data_bus.i_dual_axis     , cfg.pcfg['dual_axis'])
			npd.copyto(data_bus.i_dual_order    , cfg.pcfg['dual_order'])
			npd.copyto(data_bus.i_abeg          , abeg_i0[j])
			npd.copyto(data_bus.i_aend          , aend_i0[j])
			npd.copyto(data_bus.i_linears       , linear_i0)
			npd.copyto(data_bus.i_bboundary     , cfg.pcfg["total"][0])
			npd.copyto(data_bus.i_bsubofs       , cfg.v_nd >> cfg.pcfg["lg_vshuf"][0])
			npd.copyto(data_bus.i_bsub_up_order , cfg.pcfg["lg_vsize_2x"][0])
			npd.copyto(data_bus.i_bsub_lo_order , cfg.pcfg["lg_vshuf"][0])
			npd.copyto(data_bus.i_aboundary     , cfg.acfg["total"][0])
			npd.copyto(data_bus.i_bgrid_step    , cfg.pcfg["local"][0])
			npd.copyto(data_bus.i_global_bshufs , cfg.umcfg_i0["udim"][:,VDIM:])
			npd.copyto(data_bus.i_bstrides_frac , cfg.umcfg_i0["ustride_frac"][:,VDIM:])
			npd.copyto(data_bus.i_bstrides_shamt, cfg.umcfg_i0["ustride_shamt"][:,VDIM:])
			npd.copyto(data_bus.i_global_ashufs , cfg.umcfg_i0["udim"][:,:VDIM])
			npd.copyto(data_bus.i_astrides_frac , cfg.umcfg_i0["ustride_frac"][:,:VDIM])
			npd.copyto(data_bus.i_astrides_shamt, cfg.umcfg_i0["ustride_shamt"][:,:VDIM])
			npd.copyto(data_bus.i_mofs_bsubsteps, cfg.umcfg_i0["vlinear"][:,1<<npi.arange(CV_BW)])
			npd.copyto(data_bus.i_mboundaries   , cfg.umcfg_i0["lmalign"][:,:DIM])
			npd.copyto(data_bus.i_id_begs       , cfg.n_i0[0][i])
			npd.copyto(data_bus.i_id_ends       , cfg.n_i0[1][i])
			if ST_MODE:
				dc.Resize(accum_idx_i0.shape[0]*2)
				npd.copyto(data_bus.i_stencil     , 1)
				npd.copyto(data_bus.i_stencil_begs, 0)
				npd.copyto(data_bus.i_stencil_ends, 2)
				data_bus.i_stencil_lut[:2] = [0,1]
				tst.Expect((
					npd.repeat(rg_flat_i0[:,newaxis], 2, axis=0),
					(accum_idx_i0[:,newaxis,:]+data_bus[17][:2][:,newaxis]).reshape(-1, VSIZE),
					npd.repeat(valid_i0_packed[:,newaxis], 2, axis=0),
					# abcde --> 0a0b0c0d
					npd.column_stack((npd.zeros_like(rt_flat_i0), rt_flat_i0)).reshape(-1, 1),
				))
			else:
				dc.Resize(accum_idx_i0.shape[0])
				npd.copyto(data_bus.i_stencil, 0)
				tst.Expect((rg_flat_i0[:,newaxis], addr_i0, valid_i0_packed[:,newaxis], rt_flat_i0[:,newaxis]))
			yield ck_ev
			yield from master.Send(data_bus)
			for ck in range(30):
				yield ck_ev
		assert dc.is_clean
		FinishSim()
		break

try:
	from os import environ
	ST_MODE = bool(environ["STENCIL"])
except:
	ST_MODE = False
assert not ST_MODE, "TODO"
cfg = default_sample_conf
VSIZE = cfg.VSIZE
VDIM = cfg.VDIM
DIM = cfg.DIM
CV_BW = cfg.LG_VSIZE
N_CFG = cfg.n_i0[1][-1]
N_SLUT = 2
scb = Scoreboard("AccumWarpLooper")
tst = scb.GetTest("test")
dc = Stacker(0, callbacks=[tst.Get])
bg = BusGetter(callbacks=[dc.Get])
rst_out_ev, ck_ev = CreateEvents(["rst_out", "ck_ev"])
(
	bofs_rdy, bofs_ack,
	av_rdy, av_ack
) = CreateBuses([
	(("bofs_rdy",),),
	(("bofs_ack",),),
	(("av_rdy",),),
	(("av_canack",),),
])
bofs_bus, av_bus = CreateBuses([
	(
		("dut", "i_bofs", (VDIM,)),
		(None , "i_dual_axis"),
		(None , "i_dual_order"),
		(None , "i_abeg", (VDIM,)),
		(None , "i_aend", (VDIM,)),
		(None , "i_linears", (N_CFG,)),
		(None , "i_bboundary", (VDIM,)),
		(None , "i_bsubofs", (VSIZE,VDIM,)),
		(None , "i_bsub_up_order", (VDIM,)),
		(None , "i_bsub_lo_order", (VDIM,)),
		(None , "i_aboundary", (VDIM,)),
		(None , "i_bgrid_step", (VDIM,)),
		(None , "i_global_bshufs", (N_CFG,VDIM,)),
		(None , "i_bstrides_frac", (N_CFG,VDIM,)),
		(None , "i_bstrides_shamt", (N_CFG,VDIM,)),
		(None , "i_global_ashufs", (N_CFG,VDIM,)),
		(None , "i_astrides_frac", (N_CFG,VDIM,)),
		(None , "i_astrides_shamt", (N_CFG,VDIM,)),
		(None , "i_mofs_bsubsteps", (N_CFG,CV_BW,)),
		(None , "i_mboundaries", (N_CFG,DIM,)),
		(None , "i_id_begs", (VDIM+1,)),
		(None , "i_id_ends", (VDIM+1,)),
		(None , "i_stencil"),
		(None , "i_stencil_begs", (N_CFG,)),
		(None , "i_stencil_ends", (N_CFG,)),
		(None , "i_stencil_lut", (N_SLUT,)),
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
