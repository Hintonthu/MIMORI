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
from nicotb.protocol import TwoWire
from itertools import repeat
from UmiModel import UmiModel, default_sample_conf, default_verf_func, npi, npd, newaxis
from collections import deque
from ctypes import *

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
		self.w.SetToX()
		self.ra_ack.Write()
		self.rd_rdy.Write()
		self.rd.Write()
		self.w_rdy.Write()
		self.w.Write()
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
					c_r.value = self.ra.value[0]
					self.ra.Read()
					self.q.append(self.mspace.Read(self.ra.value))
				if c_has_w.value:
					c_w.value = self.w.value[0]
					self.w.Read()
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
	cfg_master = TwoWire.Master(cfg_rdy_bus, cfg_ack_bus, cfg_bus, ck_ev)
	yield rst_out_ev
	resp_chan = DramRespChan(
		ra_rdy_bus, ra_ack_bus, ra_bus,
		rd_rdy_bus, rd_ack_bus, rd_bus,
		w_rdy_bus, w_ack_bus, w_bus,
		ck_ev, ms,
		# Simulation configuration: 1600MHz/200MHz
		8.0,
	)

	i_data = cfg_master.values
	VL_IDX = slice(None), 1 << npi.arange(CV_BW)
	npd.copyto(i_data[0], cfg.pcfg["local_sig"][0])
	npd.copyto(i_data[1], cfg.pcfg["local_exp"][0])
	npd.copyto(i_data[2], cfg.pcfg["last"][0])
	npd.copyto(i_data[3], cfg.pcfg["boundary"][0])
	npd.copyto(i_data[4], cfg.pcfg["local"][0]-(1<<(cfg.pcfg["lg_vshuf"][0]+cfg.pcfg["lg_vsize"][0])))
	npd.copyto(i_data[5], cfg.v_nd >> cfg.pcfg["lg_vshuf"][0])
	npd.copyto(i_data[6], cfg.pcfg["lg_vshuf"][0]+cfg.pcfg["lg_vsize"][0])
	npd.copyto(i_data[7], cfg.pcfg["lg_vshuf"][0])
	npd.copyto(i_data[8], cfg.acfg["local_sig"][0])
	npd.copyto(i_data[9], cfg.acfg["local_exp"][0])
	npd.copyto(i_data[10], cfg.acfg["last"][0])
	npd.copyto(i_data[11], cfg.acfg["boundary"][0]-1)
	npd.copyto(i_data[12], cfg.acfg["local"][0]-1)
	npd.copyto(i_data[13], npd.bitwise_or.reduce(cfg.umcfg_i0["xor_dst"], axis=1))
	npd.copyto(i_data[14], cfg.umcfg_i0["xor_scheme"])
	npd.copyto(i_data[15], cfg.umcfg_i0["xor_swap"])
	npd.copyto(i_data[16], cfg.umcfg_i0["lustride"][:,DIM:])
	npd.copyto(i_data[17], cfg.umcfg_i0["vlinear"][VL_IDX])
	npd.copyto(i_data[18], cfg.umcfg_i0["lustride"][:,:DIM])
	npd.copyto(i_data[19], cfg.umcfg_i0["lmsize"])
	npd.copyto(i_data[20], cfg.umcfg_i0["lmpad"])
	npd.copyto(i_data[21], cfg.umcfg_i0["ustride"][:,DIM:])
	npd.copyto(i_data[22], cfg.umcfg_i0["ustride"][:,:DIM])
	npd.copyto(i_data[23], cfg.umcfg_i0["mstart"])
	npd.copyto(i_data[24], cfg.umcfg_i0["mlinear"])
	npd.copyto(i_data[25], (cfg.umcfg_i0["lmwidth"]-1)*cfg.umcfg_i0["mmultiplier"])
	npd.copyto(i_data[26], cfg.umcfg_i0["mboundary"]-cfg.umcfg_i0["mmultiplier"])
	npd.copyto(i_data[27], cfg.umcfg_i0["udim"][:,DIM:])
	npd.copyto(i_data[28], cfg.umcfg_i0["udim"][:,:DIM])
	npd.copyto(i_data[29], cfg.n_i0[0])
	npd.copyto(i_data[30], cfg.n_i0[1])
	# TODO (begin)
	npd.copyto(i_data[31], 1 if N_SLUT0 != 0 else 0)
	npd.copyto(i_data[32], 0)
	npd.copyto(i_data[33], 0)
	if N_I0CFG != 0:
		i_data[33][0] = N_SLUT0
	npd.copyto(i_data[34], slut0)
	# TODO (end)
	npd.copyto(i_data[35], npd.bitwise_or.reduce(cfg.umcfg_i1["xor_dst"], axis=1))
	npd.copyto(i_data[36], cfg.umcfg_i1["xor_scheme"])
	npd.copyto(i_data[37], cfg.umcfg_i1["xor_swap"])
	npd.copyto(i_data[38], cfg.umcfg_i1["lustride"][:,DIM:])
	npd.copyto(i_data[39], cfg.umcfg_i1["vlinear"][VL_IDX])
	npd.copyto(i_data[40], cfg.umcfg_i1["lustride"][:,:DIM])
	npd.copyto(i_data[41], cfg.umcfg_i1["lmsize"])
	npd.copyto(i_data[42], cfg.umcfg_i1["lmpad"])
	npd.copyto(i_data[43], cfg.umcfg_i1["ustride"][:,DIM:])
	npd.copyto(i_data[44], cfg.umcfg_i1["ustride"][:,:DIM])
	npd.copyto(i_data[45], cfg.umcfg_i1["mstart"])
	npd.copyto(i_data[46], cfg.umcfg_i1["mlinear"])
	npd.copyto(i_data[47], (cfg.umcfg_i1["lmwidth"]-1)*cfg.umcfg_i1["mmultiplier"])
	npd.copyto(i_data[48], cfg.umcfg_i1["mboundary"]-cfg.umcfg_i1["mmultiplier"])
	npd.copyto(i_data[49], cfg.umcfg_i1["udim"][:,DIM:])
	npd.copyto(i_data[50], cfg.umcfg_i1["udim"][:,:DIM])
	npd.copyto(i_data[51], cfg.n_i1[0])
	npd.copyto(i_data[52], cfg.n_i1[1])
	# TODO (begin)
	npd.copyto(i_data[53], 1 if N_SLUT1 != 0 else 0)
	npd.copyto(i_data[54], 0)
	npd.copyto(i_data[55], 0)
	if N_I1CFG != 0:
		i_data[55][0] = N_SLUT1
	npd.copyto(i_data[56], slut1)
	# TODO (end)
	npd.copyto(i_data[57], cfg.umcfg_o["ustride"][:,DIM:])
	npd.copyto(i_data[58], cfg.umcfg_o["vlinear"][VL_IDX])
	npd.copyto(i_data[59], cfg.umcfg_o["ustride"][:,:DIM])
	npd.copyto(i_data[60], cfg.umcfg_o["mlinear"][:,newaxis])
	npd.copyto(i_data[61], cfg.n_o[0])
	npd.copyto(i_data[62], cfg.n_o[1])
	npd.copyto(i_data[63], cfg.n_inst[0])
	npd.copyto(i_data[64], cfg.n_inst[1])
	npd.copyto(i_data[65], cfg.insts)
	npd.copyto(i_data[66], clut)
	npd.copyto(i_data[67], tlut)
	npd.copyto(i_data[68], cfg.n_reg)
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
N_I0CFG = cfg.n_i0[1][-1]
N_I1CFG = cfg.n_i1[1][-1]
N_OCFG = cfg.n_o[1][-1]
N_INST = cfg.n_inst[1][-1]
N_CLUT, clut = cfg.luts["const"]
N_TLUT, tlut = cfg.luts["texture"]
N_SLUT0, slut0 = cfg.luts["stencil0"]
N_SLUT1, slut1 = cfg.luts["stencil1"]
(
	w_rdy_bus, w_ack_bus,
	ra_rdy_bus, ra_ack_bus,
	rd_rdy_bus, rd_ack_bus,
	cfg_rdy_bus, cfg_ack_bus,
) = CreateBuses([
	(("w_rdy",),),
	(("w_canack",),),
	(("ra_rdy",),),
	(("ra_canack",),),
	(("rd_rdy",),),
	(("rd_ack",),),
	(("cfg_rdy",),),
	(("cfg_ack",),),
])
w_bus, ra_bus, rd_bus, cfg_bus = CreateBuses([
	(
		("u_top", "o_dramwa"),
		(None   , "o_dramwd", (CSIZE,)),
		(None   , "o_dramw_mask"),
	),
	(("u_top", "o_dramra"),),
	(("u_top", "i_dramrd", (CSIZE,)),),
	(
		("u_top", "i_bgrid_frac"             , (DIM,)),
		(None   , "i_bgrid_shamt"            , (DIM,)),
		(None   , "i_bgrid_last"             , (DIM,)),
		(None   , "i_bboundary"              , (DIM,)),
		(None   , "i_blocal_last"            , (DIM,)),
		(None   , "i_bsubofs"                , (VSIZE,DIM,)),
		(None   , "i_bsub_up_order"          , (DIM,)),
		(None   , "i_bsub_lo_order"          , (DIM,)),
		(None   , "i_agrid_frac"             , (DIM,)),
		(None   , "i_agrid_shamt"            , (DIM,)),
		(None   , "i_agrid_last"             , (DIM,)),
		(None   , "i_aboundary"              , (DIM,)),
		(None   , "i_alocal_last"            , (DIM,)),
		(None   , "i_i0_local_xor_masks"     , (N_I0CFG,)),
		(None   , "i_i0_local_xor_schemes"   , (N_I0CFG,CV_BW,)),
		(None   , "i_i0_local_bit_swaps"     , (N_I0CFG,)),
		(None   , "i_i0_local_mofs_bsteps"   , (N_I0CFG,DIM,)),
		(None   , "i_i0_local_mofs_bsubsteps", (N_I0CFG,CV_BW,)),
		(None   , "i_i0_local_mofs_asteps"   , (N_I0CFG,DIM,)),
		(None   , "i_i0_local_sizes"         , (N_I0CFG,)),
		(None   , "i_i0_local_pads"          , (N_I0CFG,DIM,)),
		(None   , "i_i0_global_mofs_bsteps"  , (N_I0CFG,DIM,)),
		(None   , "i_i0_global_mofs_asteps"  , (N_I0CFG,DIM,)),
		(None   , "i_i0_global_mofs_starts"  , (N_I0CFG,DIM,)),
		(None   , "i_i0_global_mofs_linears" , (N_I0CFG,)),
		(None   , "i_i0_global_cboundaries"  , (N_I0CFG,DIM,)),
		(None   , "i_i0_global_mboundaries"  , (N_I0CFG,DIM,)),
		(None   , "i_i0_global_mofs_bshufs"  , (N_I0CFG,DIM,)),
		(None   , "i_i0_global_mofs_ashufs"  , (N_I0CFG,DIM,)),
		(None   , "i_i0_id_begs"             , (DIM+1,)),
		(None   , "i_i0_id_ends"             , (DIM+1,)),
		(None   , "i_i0_stencil"),
		(None   , "i_i0_stencil_begs"        , (N_I0CFG,)),
		(None   , "i_i0_stencil_ends"        , (N_I0CFG,)),
		(None   , "i_i0_stencil_lut"         , (N_SLUT0,)),
		(None   , "i_i1_local_xor_masks"     , (N_I1CFG,)),
		(None   , "i_i1_local_xor_schemes"   , (N_I1CFG,CV_BW,)),
		(None   , "i_i1_local_bit_swaps"     , (N_I1CFG,)),
		(None   , "i_i1_local_mofs_bsteps"   , (N_I1CFG,DIM,)),
		(None   , "i_i1_local_mofs_bsubsteps", (N_I1CFG,CV_BW,)),
		(None   , "i_i1_local_mofs_asteps"   , (N_I1CFG,DIM,)),
		(None   , "i_i1_local_sizes"         , (N_I1CFG,)),
		(None   , "i_i1_local_pads"          , (N_I1CFG,DIM,)),
		(None   , "i_i1_global_mofs_bsteps"  , (N_I1CFG,DIM,)),
		(None   , "i_i1_global_mofs_asteps"  , (N_I1CFG,DIM,)),
		(None   , "i_i1_global_mofs_starts"  , (N_I1CFG,DIM,)),
		(None   , "i_i1_global_mofs_linears" , (N_I1CFG,)),
		(None   , "i_i1_global_cboundaries"  , (N_I1CFG,DIM,)),
		(None   , "i_i1_global_mboundaries"  , (N_I1CFG,DIM,)),
		(None   , "i_i1_global_mofs_bshufs"  , (N_I1CFG,DIM,)),
		(None   , "i_i1_global_mofs_ashufs"  , (N_I1CFG,DIM,)),
		(None   , "i_i1_id_begs"             , (DIM+1,)),
		(None   , "i_i1_id_ends"             , (DIM+1,)),
		(None   , "i_i1_stencil"),
		(None   , "i_i1_stencil_begs"        , (N_I1CFG,)),
		(None   , "i_i1_stencil_ends"        , (N_I1CFG,)),
		(None   , "i_i1_stencil_lut"         , (N_SLUT1,)),
		(None   , "i_o_global_mofs_bsteps"   , (N_OCFG,DIM,)),
		(None   , "i_o_global_mofs_bsubsteps", (N_OCFG,CV_BW,)),
		(None   , "i_o_global_mofs_asteps"   , (N_OCFG,DIM,)),
		(None   , "i_o_global_mofs_linears"  , (N_OCFG,1,)),
		(None   , "i_o_id_begs"              , (DIM+1,)),
		(None   , "i_o_id_ends"              , (DIM+1,)),
		(None   , "i_inst_id_begs"           , (DIM+1,)),
		(None   , "i_inst_id_ends"           , (DIM+1,)),
		(None   , "i_insts"                  , (N_INST,)),
		(None   , "i_consts"                 , (N_CLUT,)),
		(None   , "i_const_texs"             , (N_TLUT,)),
		(None   , "i_reg_per_warp"),
	),
])
rst_out_ev, ck_ev = CreateEvents(["rst_out", "ck_ev"])
npd.random.seed(12345)
RegisterCoroutines([
	main(),
])
