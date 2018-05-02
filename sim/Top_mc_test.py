# Copyright 2017-2018 Yu Sheng Lin

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
from nicotb.protocol import TwoWire
from itertools import repeat
from UmiModel import UmiModel, default_sample_conf, default_verf_func, npi, npd, newaxis
from collections import deque
from ctypes import *
from Response import Response

class DramRespChan(object):
	def __init__(
		self,
		ra_rdy_bus, ra_ack_bus, ra_bus,
		rd_rdy_bus, rd_ack_bus, rd_bus,
		w_rdy_bus, w_ack_bus, w_bus,
		ck_ev, mspace,
		# dram freq / clk freq
		dram_speed,
	):
		self.sending = list()
		self.pending = list()
		self.ra_rdy = ra_rdy_bus
		self.ra_ack = ra_ack_bus
		self.ra = ra_bus
		self.rd_rdy = rd_rdy_bus
		self.rd_ack = rd_ack_bus
		self.rd = rd_bus
		self.w_rdy = w_rdy_bus
		self.w_ack = w_ack_bus
		self.w = w_bus
		self.ck_ev = ck_ev
		self.mspace = mspace
		self.q = deque()
		self.ra_ack.Write()
		self.rd_rdy.Write()
		self.rd.Write()
		self.w_rdy.Write()
		self.dram_counter = 0.
		self.dram_speed_inc = 1 / dram_speed
		Fork(self.MainLoop())

	def MainLoop(self):
		ramu = CDLL("ramulator_wrap.so")
		c_RamuTick = ramu.RamulatorTick
		self.c_RamuReport = ramu.RamulatorReport
		c_r = c_long()
		c_w = c_long()
		c_has_r = c_bool()
		c_has_w = c_bool()
		c_resp_got = c_bool()
		c_r_full = c_bool()
		c_w_full = c_bool()
		c_has_resp = c_bool()
		c_r_full_ptr = byref(c_r_full)
		c_w_full_ptr = byref(c_w_full)
		c_has_resp_ptr = byref(c_has_resp)
		while True:
			if self.dram_counter >= 1.:
				self.dram_counter -= 1.
				yield self.ck_ev
				self.rd_ack.Read()
				self.ra_rdy.Read()
				self.w_rdy.Read()
				c_has_r.value = not self.ra_rdy.x[0] and self.ra_rdy.value[0] and self.ra_ack.value[0]
				c_has_w.value = not self.w_rdy.x[0] and self.w_rdy.value[0] and self.w_ack.value[0]
				c_resp_got.value = self.rd_rdy.value[0] and self.rd_ack.value[0]
				if c_has_r.value:
					self.ra.Read()
					self.ra.value[0] &= CSIZE_MASK
					c_r.value = self.ra.value[0]
					self.q.append(self.mspace.Read(self.ra.value))
				if c_has_w.value:
					self.w.Read()
					self.w.value[0] &= CSIZE_MASK
					c_w.value = self.w.value[0]
					self.mspace.WriteScalarMask(*self.w.values)
				c_RamuTick(
					c_has_r, c_has_w, c_resp_got, c_r, c_w,
					c_r_full_ptr, c_w_full_ptr, c_has_resp_ptr
				)
				update_resp = not self.rd_rdy.value[0] or self.rd_ack.value[0]
				self.ra_ack.value[0] = not c_r_full.value
				self.w_ack.value[0] = not c_w_full.value
				self.rd_rdy.value[0] = c_has_resp.value
				if update_resp and self.rd_rdy.value[0]:
					self.rd.value = self.q.popleft()
					self.rd.Write()
				self.ra_ack.Write()
				self.w_ack.Write()
				self.rd_rdy.Write()
			else:
				c_has_r.value = 0
				c_has_w.value = 0
				c_resp_got.value = 0
				c_r.value = 0
				c_w.value = 0
				c_RamuTick(
					c_has_r, c_has_w, c_resp_got, c_r, c_w,
					c_r_full_ptr, c_w_full_ptr, c_has_resp_ptr
				)
			self.dram_counter += self.dram_speed_inc

def main():
	# init
	ms = next(verf_func_gen)
	cfg_master = TwoWire.Master(cfg_rdy_bus, cfg_ack_bus, cfg_bus, ck_ev, strict=strict)
	yield rst_out_ev
	yield ck_ev
	yield ck_ev
	yield ck_ev
	slave_ras, slave_ws, master_rds, resps = [list() for _ in range(4)]

	def WriteHandle(x):
		x.value[0] &= CSIZE_MASK
		ms.WriteScalarMask(*x.values)
	for i in range(N_TAU):
		slave_w = TwoWire.Slave(
			w_rdy_buss[i], w_ack_buss[i], w_buss[i], ck_ev,
			callbacks=[WriteHandle],
			A=1, B=2
		)
		master_rd = TwoWire.Master(
			rd_rdy_buss[i], rd_ack_buss[i], rd_buss[i],
			ck_ev, strict=strict
		)
		resp = Response(master_rd.SendIter, ck_ev, B=10)
		def ReadHandle(x, resp=resp):
			x.value[0] &= CSIZE_MASK
			resp.Append((ms.Read(x.value),))
		slave_ra = TwoWire.Slave(
			ra_rdy_buss[i], ra_ack_buss[i], ra_buss[i], ck_ev,
			callbacks=[ReadHandle],
			A=1, B=2
		)
		slave_ras.append(slave_ra)
		slave_ws.append(slave_w)
		master_rds.append(master_rd)
		resps.append(resp)
	"""
	resp_chan = DramRespChan(
		ra_rdy_bus, ra_ack_bus, ra_bus,
		rd_rdy_bus, rd_ack_bus, rd_bus,
		w_rdy_bus, w_ack_bus, w_bus,
		ck_ev, ms,
		# Simulation configuration: 1600MHz/200MHz
		8.0,
	)
	"""

	i_data = cfg_master.values
	CompressWrap = lambda x: npd.bitwise_or.reduce((x == UmiModel.MEM_WRAP).astype('i2') << npi.arange(x.shape[0]))
	VL_IDX = slice(None), 1 << npi.arange(CV_BW)
	npd.copyto(i_data.i_bgrid_step,    cfg.pcfg['local'][0])
	npd.copyto(i_data.i_bgrid_end,     cfg.pcfg['end'][0])
	npd.copyto(i_data.i_bboundary,     cfg.pcfg['total'][0])
	npd.copyto(i_data.i_bsubofs,       cfg.v_nd >> cfg.pcfg['lg_vshuf'][0])
	npd.copyto(i_data.i_bsub_up_order, cfg.pcfg['lg_vsize'][0])
	npd.copyto(i_data.i_bsub_lo_order, cfg.pcfg['lg_vshuf'][0])
	npd.copyto(i_data.i_agrid_step,    cfg.acfg['local'][0])
	npd.copyto(i_data.i_agrid_end,     cfg.acfg['end'][0])
	npd.copyto(i_data.i_aboundary,     cfg.acfg['total'][0])
	npd.copyto(i_data.i_i0_local_xor_masks,    cfg.umcfg_i0['xor_mask'])
	npd.copyto(i_data.i_i0_local_xor_schemes,  cfg.umcfg_i0['xor_src'])
	npd.copyto(i_data.i_i0_local_xor_configs,  cfg.umcfg_i0['xor_config'])
	npd.copyto(i_data.i_i0_local_boundaries,   cfg.umcfg_i0['lmalign'])
	npd.copyto(i_data.i_i0_local_bsubsteps,    cfg.umcfg_i0['vlinear'][VL_IDX])
	npd.copyto(i_data.i_i0_local_pads,         cfg.umcfg_i0['lmpad'])
	npd.copyto(i_data.i_i0_global_starts,      cfg.umcfg_i0['mstart'])
	npd.copyto(i_data.i_i0_global_linears,     cfg.umcfg_i0['mlinear'])
	npd.copyto(i_data.i_i0_global_cboundaries, cfg.umcfg_i0['mboundary_lmwidth'])
	npd.copyto(i_data.i_i0_global_boundaries,  cfg.umcfg_i0['mboundary'])
	npd.copyto(i_data.i_i0_global_bshufs,      cfg.umcfg_i0['udim'][:,VDIM:])
	npd.copyto(i_data.i_i0_global_ashufs,      cfg.umcfg_i0['udim'][:,:VDIM])
	npd.copyto(i_data.i_i0_bstrides_frac,      cfg.umcfg_i0['ustride_frac' ][:,VDIM:])
	npd.copyto(i_data.i_i0_bstrides_shamt,     cfg.umcfg_i0['ustride_shamt'][:,VDIM:])
	npd.copyto(i_data.i_i0_astrides_frac,      cfg.umcfg_i0['ustride_frac' ][:,:VDIM])
	npd.copyto(i_data.i_i0_astrides_shamt,     cfg.umcfg_i0['ustride_shamt'][:,:VDIM])
	npd.copyto(i_data.i_i0_wrap,               CompressWrap(cfg.umcfg_i0['mwrap']))
	npd.copyto(i_data.i_i0_pad_value,          cfg.umcfg_i0['pad_value'])
	npd.copyto(i_data.i_i0_id_begs,            cfg.n_i0[0])
	npd.copyto(i_data.i_i0_id_ends,            cfg.n_i0[1])
	# TODO (begin)
	i_data.i_i0_stencil[0] = int(N_SLUT0 != 0)
	npd.copyto(i_data.i_i0_stencil_begs, 0)
	npd.copyto(i_data.i_i0_stencil_ends, 0)
	if N_I0CFG != 0:
		i_data.i_i0_stencil_ends[0] = N_SLUT0
	npd.copyto(i_data.i_i0_stencil_lut, slut0)
	# TODO (end)
	npd.copyto(i_data.i_i1_local_xor_masks,    cfg.umcfg_i1['xor_mask'])
	npd.copyto(i_data.i_i1_local_xor_schemes,  cfg.umcfg_i1['xor_src'])
	npd.copyto(i_data.i_i1_local_xor_configs,  cfg.umcfg_i1['xor_config'])
	npd.copyto(i_data.i_i1_local_boundaries,   cfg.umcfg_i1['lmalign'])
	npd.copyto(i_data.i_i1_local_bsubsteps,    cfg.umcfg_i1['vlinear'][VL_IDX])
	npd.copyto(i_data.i_i1_local_pads,         cfg.umcfg_i1['lmpad'])
	npd.copyto(i_data.i_i1_global_starts,      cfg.umcfg_i1['mstart'])
	npd.copyto(i_data.i_i1_global_linears,     cfg.umcfg_i1['mlinear'])
	npd.copyto(i_data.i_i1_global_cboundaries, cfg.umcfg_i1['mboundary_lmwidth'])
	npd.copyto(i_data.i_i1_global_boundaries,  cfg.umcfg_i1['mboundary'])
	npd.copyto(i_data.i_i1_global_bshufs,      cfg.umcfg_i1['udim'][:,VDIM:])
	npd.copyto(i_data.i_i1_global_ashufs,      cfg.umcfg_i1['udim'][:,:VDIM])
	npd.copyto(i_data.i_i1_bstrides_frac,      cfg.umcfg_i1['ustride_frac' ][:,VDIM:])
	npd.copyto(i_data.i_i1_bstrides_shamt,     cfg.umcfg_i1['ustride_shamt'][:,VDIM:])
	npd.copyto(i_data.i_i1_astrides_frac,      cfg.umcfg_i1['ustride_frac' ][:,:VDIM])
	npd.copyto(i_data.i_i1_astrides_shamt,     cfg.umcfg_i1['ustride_shamt'][:,:VDIM])
	npd.copyto(i_data.i_i1_wrap,               CompressWrap(cfg.umcfg_i1['mwrap']))
	npd.copyto(i_data.i_i1_pad_value,          cfg.umcfg_i1['pad_value'])
	npd.copyto(i_data.i_i1_id_begs,            cfg.n_i1[0])
	npd.copyto(i_data.i_i1_id_ends,            cfg.n_i1[1])
	# TODO (begin)
	i_data.i_i1_stencil[0] = int(N_SLUT1 != 0)
	npd.copyto(i_data.i_i1_stencil_begs, 0)
	npd.copyto(i_data.i_i1_stencil_ends, 0)
	if N_I1CFG != 0:
		i_data.i_i1_stencil_ends[0] = N_SLUT1
	npd.copyto(i_data.i_i1_stencil_lut, slut1)
	# TODO (end)
	npd.copyto(i_data.i_o_global_boundaries, cfg.umcfg_o['mboundary'])
	npd.copyto(i_data.i_o_global_bsubsteps,  cfg.umcfg_o['vlinear'][VL_IDX])
	npd.copyto(i_data.i_o_global_linears,    cfg.umcfg_o['mlinear'])
	npd.copyto(i_data.i_o_global_bshufs,     cfg.umcfg_o['udim'][:,VDIM:])
	npd.copyto(i_data.i_o_bstrides_frac,     cfg.umcfg_o['ustride_frac' ][:,VDIM:])
	npd.copyto(i_data.i_o_bstrides_shamt,    cfg.umcfg_o['ustride_shamt'][:,VDIM:])
	npd.copyto(i_data.i_o_global_ashufs,     cfg.umcfg_o['udim'][:,:VDIM])
	npd.copyto(i_data.i_o_astrides_frac,     cfg.umcfg_o['ustride_frac' ][:,:VDIM])
	npd.copyto(i_data.i_o_astrides_shamt,    cfg.umcfg_o['ustride_shamt'][:,:VDIM])
	npd.copyto(i_data.i_o_id_begs,           cfg.n_o[0])
	npd.copyto(i_data.i_o_id_ends,           cfg.n_o[1])
	npd.copyto(i_data.i_inst_id_begs, cfg.n_inst[0])
	npd.copyto(i_data.i_inst_id_ends, cfg.n_inst[1])
	npd.copyto(i_data.i_insts,        cfg.insts)
	npd.copyto(i_data.i_consts,       clut)
	npd.copyto(i_data.i_const_texs,   tlut)
	npd.copyto(i_data.i_reg_per_warp, cfg.n_reg)
	yield from cfg_master.Send(i_data)

	for i in range(300):
		yield ck_ev
	# check
	try:
		next(verf_func_gen)
	except StopIteration:
		pass
	resp_chan.c_RamuReport()
	FinishSim()

cfg = default_sample_conf
CSIZE = cfg.DRAM_ALIGN
CSIZE_MASK = ~(CSIZE-1)
verf_func_gen = default_verf_func(CSIZE)
VSIZE = cfg.VSIZE
CV_BW = cfg.LG_VSIZE
DIM = cfg.DIM
VDIM = cfg.VDIM
N_TAU = 4
N_I0CFG = cfg.n_i0[1][-1]
N_I1CFG = cfg.n_i1[1][-1]
N_OCFG = cfg.n_o[1][-1]
N_INST = cfg.n_inst[1][-1]
N_CLUT, clut = cfg.luts["const"]
N_TLUT, tlut = cfg.luts["texture"]
N_SLUT0, slut0 = cfg.luts["stencil0"]
N_SLUT1, slut1 = cfg.luts["stencil1"]
sim_cfg = CreateBus(("GATE_LEVEL",))
sim_cfg.Read()
strict = False if sim_cfg.GATE_LEVEL.value[0] else True
(
	w_rdy_buss, w_ack_buss, w_buss,
	ra_rdy_buss, ra_ack_buss, ra_buss,
	rd_rdy_buss, rd_ack_buss, rd_buss,
) = [list() for _ in range(9)]
for i in range(N_TAU):
	(
		w_bus, ra_bus, rd_bus,
		w_rdy_bus, w_ack_bus,
		ra_rdy_bus, ra_ack_bus,
		rd_rdy_bus, rd_ack_bus,
	) = CreateBuses([
		(
			(""  , f"o_dramwa{i}",),
			(None, f"o_dramwd{i}", (CSIZE,)),
			(None, f"o_dramw_mask{i}",),
		),
		((f"o_dramra{i}",),),
		(("", f"i_dramrd{i}", (CSIZE,)),),
		((f"w{i}_rdy",),),
		((f"w{i}_canack",),),
		((f"ra{i}_rdy",),),
		((f"ra{i}_canack",),),
		((f"rd{i}_rdy",),),
		((f"rd{i}_ack",),),
	])
	w_rdy_buss.append(w_rdy_bus)
	w_ack_buss.append(w_ack_bus)
	w_buss.append(w_bus)
	ra_rdy_buss.append(ra_rdy_bus)
	ra_ack_buss.append(ra_ack_bus)
	ra_buss.append(ra_bus)
	rd_rdy_buss.append(rd_rdy_bus)
	rd_ack_buss.append(rd_ack_bus)
	rd_buss.append(rd_bus)
cfg_bus, cfg_rdy_bus, cfg_ack_bus, = CreateBuses([
	(
		("u_top", "i_bgrid_step"             , (VDIM,)),
		(None   , "i_bgrid_end"              , (VDIM,)),
		(None   , "i_bboundary"              , (VDIM,)),
		(None   , "i_bsubofs"                , (VSIZE,VDIM,)),
		(None   , "i_bsub_up_order"          , (VDIM,)),
		(None   , "i_bsub_lo_order"          , (VDIM,)),
		(None   , "i_agrid_step"             , (VDIM,)),
		(None   , "i_agrid_end"              , (VDIM,)),
		(None   , "i_aboundary"              , (VDIM,)),
		(None   , "i_i0_local_xor_masks"     , (N_I0CFG,)),
		(None   , "i_i0_local_xor_schemes"   , (N_I0CFG,CV_BW,)),
		(None   , "i_i0_local_xor_configs"   , (N_I0CFG,)),
		(None   , "i_i0_local_boundaries"    , (N_I0CFG, DIM,)),
		(None   , "i_i0_local_bsubsteps"     , (N_I0CFG, CV_BW,)),
		(None   , "i_i0_local_pads"          , (N_I0CFG, DIM,)),
		(None   , "i_i0_global_starts"       , (N_I0CFG, DIM,)),
		(None   , "i_i0_global_linears"      , (N_I0CFG,)),
		(None   , "i_i0_global_cboundaries"  , (N_I0CFG, DIM,)),
		(None   , "i_i0_global_boundaries"   , (N_I0CFG, DIM,)),
		(None   , "i_i0_global_bshufs"       , (N_I0CFG, VDIM,)),
		(None   , "i_i0_global_ashufs"       , (N_I0CFG, VDIM,)),
		(None   , "i_i0_bstrides_frac"       , (N_I0CFG, VDIM,)),
		(None   , "i_i0_bstrides_shamt"      , (N_I0CFG, VDIM,)),
		(None   , "i_i0_astrides_frac"       , (N_I0CFG, VDIM,)),
		(None   , "i_i0_astrides_shamt"      , (N_I0CFG, VDIM,)),
		(None   , "i_i0_wrap"                , (N_I0CFG,)),
		(None   , "i_i0_pad_value"           , (N_I0CFG,)),
		(None   , "i_i0_id_begs"             , (VDIM+1,)),
		(None   , "i_i0_id_ends"             , (VDIM+1,)),
		(None   , "i_i0_stencil"),
		(None   , "i_i0_stencil_begs"        , (N_I0CFG,)),
		(None   , "i_i0_stencil_ends"        , (N_I0CFG,)),
		(None   , "i_i0_stencil_lut"         , (N_SLUT0,)),
		(None   , "i_i1_local_xor_masks"     , (N_I1CFG,)),
		(None   , "i_i1_local_xor_schemes"   , (N_I1CFG,CV_BW,)),
		(None   , "i_i1_local_xor_configs"   , (N_I1CFG,)),
		(None   , "i_i1_local_boundaries"    , (N_I1CFG, DIM,)),
		(None   , "i_i1_local_bsubsteps"     , (N_I1CFG, CV_BW,)),
		(None   , "i_i1_local_pads"          , (N_I1CFG, DIM,)),
		(None   , "i_i1_global_starts"       , (N_I1CFG, DIM,)),
		(None   , "i_i1_global_linears"      , (N_I1CFG,)),
		(None   , "i_i1_global_cboundaries"  , (N_I1CFG, DIM,)),
		(None   , "i_i1_global_boundaries"   , (N_I1CFG, DIM,)),
		(None   , "i_i1_global_bshufs"       , (N_I1CFG, VDIM,)),
		(None   , "i_i1_global_ashufs"       , (N_I1CFG, VDIM,)),
		(None   , "i_i1_bstrides_frac"       , (N_I1CFG, VDIM,)),
		(None   , "i_i1_bstrides_shamt"      , (N_I1CFG, VDIM,)),
		(None   , "i_i1_astrides_frac"       , (N_I1CFG, VDIM,)),
		(None   , "i_i1_astrides_shamt"      , (N_I1CFG, VDIM,)),
		(None   , "i_i1_wrap"                , (N_I1CFG,)),
		(None   , "i_i1_pad_value"           , (N_I1CFG,)),
		(None   , "i_i1_id_begs"             , (VDIM+1,)),
		(None   , "i_i1_id_ends"             , (VDIM+1,)),
		(None   , "i_i1_stencil"),
		(None   , "i_i1_stencil_begs"        , (N_I1CFG,)),
		(None   , "i_i1_stencil_ends"        , (N_I1CFG,)),
		(None   , "i_i1_stencil_lut"         , (N_SLUT1,)),
		(None   , "i_o_global_boundaries"    , (N_OCFG, DIM,)),
		(None   , "i_o_global_bsubsteps"     , (N_OCFG, CV_BW,)),
		(None   , "i_o_global_linears"       , (N_OCFG,)),
		(None   , "i_o_global_bshufs"        , (N_OCFG, VDIM,)),
		(None   , "i_o_bstrides_frac"        , (N_OCFG, VDIM,)),
		(None   , "i_o_bstrides_shamt"       , (N_OCFG, VDIM,)),
		(None   , "i_o_global_ashufs"        , (N_OCFG, VDIM,)),
		(None   , "i_o_astrides_frac"        , (N_OCFG, VDIM,)),
		(None   , "i_o_astrides_shamt"       , (N_OCFG, VDIM,)),
		(None   , "i_o_id_begs"              , (VDIM+1,)),
		(None   , "i_o_id_ends"              , (VDIM+1,)),
		(None   , "i_inst_id_begs"           , (VDIM+1,)),
		(None   , "i_inst_id_ends"           , (VDIM+1,)),
		(None   , "i_insts"                  , (N_INST,)),
		(None   , "i_consts"                 , (N_CLUT,)),
		(None   , "i_const_texs"             , (N_TLUT,)),
		(None   , "i_reg_per_warp"),
	),
	(("cfg_rdy",),),
	(("cfg_ack",),),
])
rst_out_ev, ck_ev = CreateEvents(["rst_out", "ck_ev"])
npd.random.seed(12345)
RegisterCoroutines([
	main(),
])
