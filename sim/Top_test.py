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
from collections import deque
from UmiModel import UmiModel, default_sample_conf, default_verf_func, npi, npd, newaxis
from UmiModel import DramRespChan

def main():
	# init
	ms = next(verf_func_gen)
	cfg_master = TwoWire.Master(cfg_rdy_bus, cfg_ack_bus, cfg_bus, ck_ev, strict=strict)
	yield rst_out_ev
	yield ck_ev
	yield ck_ev
	yield ck_ev
	resp_chan = DramRespChan(
		ra_rdy_bus, ra_ack_bus, ra_bus,
		rd_rdy_bus, rd_ack_bus, rd_bus,
		w_rdy_bus, w_ack_bus, w_bus,
		ck_ev, ms,
		# Simulation configuration: 1600MHz/200MHz
		8.0, N_TAU, CSIZE
	)

	i_data = cfg_master.values
	CompressWrap = lambda x: npd.bitwise_or.reduce((x == UmiModel.MEM_WRAP).astype('i2') << npi.arange(x.shape[0]))
	VL_IDX = slice(None), 1 << npi.arange(CV_BW)
	if SIM_MODE == 2:
		# We use the same 'step' and shrink 'end'.
		nblk = cfg.pcfg['end'][0]
		ss0 = cfg.pcfg['syst0_skip'][0]
		sx0 = cfg.pcfg['syst0_axis'][0]
		st0 = cfg.pcfg['local'][0,sx0]
		ss1 = cfg.pcfg['syst1_skip'][0]
		sx1 = cfg.pcfg['syst1_axis'][0]
		st1 = cfg.pcfg['local'][0,sx1]
		if sx0 != -1:
			nblk[sx0] = ((nblk[sx0]-1) // (st0*N_TAU_X) + 1) * st0
		if sx1 != -1:
			nblk[sx1] = ((nblk[sx1]-1) // (st1*N_TAU_Y) + 1) * st1
		npd.copyto(i_data.i_bgrid_end, nblk)
		i_data.i_i0_systolic_skip[0] = ss0
		i_data.i_i0_systolic_axis[0] = sx0
		i_data.i_i1_systolic_skip[0] = ss1
		i_data.i_i1_systolic_axis[0] = sx1
	else:
		npd.copyto(i_data.i_bgrid_end, cfg.pcfg['end'][0])
	npd.copyto(i_data.i_bgrid_step,    cfg.pcfg['local'][0])
	npd.copyto(i_data.i_bboundary,     cfg.pcfg['total'][0])
	npd.copyto(i_data.i_bsubofs,       cfg.v_nd >> cfg.pcfg['lg_vshuf'][0])
	npd.copyto(i_data.i_bsub_up_order, cfg.pcfg['lg_vsize'][0])
	npd.copyto(i_data.i_bsub_lo_order, cfg.pcfg['lg_vshuf'][0])
	npd.copyto(i_data.i_agrid_step,    cfg.acfg['local'][0])
	npd.copyto(i_data.i_agrid_end,     cfg.acfg['end'][0])
	npd.copyto(i_data.i_aboundary,     cfg.acfg['total'][0])
	npd.copyto(i_data.i_i0_local_xor_srcs,     cfg.umcfg_i0['xor_src'])
	npd.copyto(i_data.i_i0_local_xor_swaps,    cfg.umcfg_i0['xor_swap'])
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
	npd.copyto(i_data.i_i1_local_xor_srcs,     cfg.umcfg_i1['xor_src'])
	npd.copyto(i_data.i_i1_local_xor_swaps,    cfg.umcfg_i1['xor_swap'])
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
	resp_chan.Report()
	FinishSim()

cfg = default_sample_conf
CSIZE = cfg.DRAM_ALIGN
verf_func_gen = default_verf_func(CSIZE)
VSIZE = cfg.VSIZE
CV_BW = cfg.LG_VSIZE
DIM = cfg.DIM
VDIM = cfg.VDIM
N_I0CFG = cfg.n_i0[1][-1]
N_I1CFG = cfg.n_i1[1][-1]
N_OCFG = cfg.n_o[1][-1]
N_INST = cfg.n_inst[1][-1]
N_CLUT, clut = cfg.luts["const"]
N_TLUT, tlut = cfg.luts["texture"]
N_SLUT0, slut0 = cfg.luts["stencil0"]
N_SLUT1, slut1 = cfg.luts["stencil1"]
sim_cfg = CreateBus((
	"GATE_LEVEL",
	"SIM_MODE",
	"N_TAU",
	"N_TAU_X",
	"N_TAU_Y"
))
sim_cfg.Read()
SIM_MODE = int(sim_cfg.SIM_MODE.value[0])
N_TAU = int(sim_cfg.N_TAU.value[0])
N_TAU_X = int(sim_cfg.N_TAU_X.value[0])
N_TAU_Y = int(sim_cfg.N_TAU_Y.value[0])
strict = False if sim_cfg.GATE_LEVEL.value[0] else True
(
	w_rdy_bus, w_ack_bus,
	ra_rdy_bus, ra_ack_bus,
	rd_rdy_bus, rd_ack_bus,
) = CreateBuses([
	(("w_rdy",),),
	(("w_canack",),),
	(("ra_rdy",),),
	(("ra_canack",),),
	(("rd_rdy",),),
	(("rd_ack",),),
])
# We rename and reshape the data when there is only one ports
w_bus, ra_bus, rd_bus, = CreateBuses([
	(
		("u_top", "o_dramwas", (N_TAU,)),
		(None   , "o_dramwds", (N_TAU,CSIZE,)),
		(None   , "o_dramw_masks", (N_TAU,)),
	),
	(("u_top", "o_dramras", (N_TAU,)),),
	(("u_top", "i_dramrds", (N_TAU,CSIZE,)),),
])
syst_tup = (
	(None   , "i_i0_systolic_skip"),
	(None   , "i_i0_systolic_axis"),
	(None   , "i_i1_systolic_skip"),
	(None   , "i_i1_systolic_axis"),
)
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
		(None   , "i_i0_local_xor_srcs"      , (N_I0CFG,CV_BW,)),
		(None   , "i_i0_local_xor_swaps"     , (N_I0CFG,)),
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
		(None   , "i_i0_wrap"),
		(None   , "i_i0_pad_value"           , (N_I0CFG,)),
		(None   , "i_i0_id_begs"             , (VDIM+1,)),
		(None   , "i_i0_id_ends"             , (VDIM+1,)),
		(None   , "i_i0_stencil"),
		(None   , "i_i0_stencil_begs"        , (N_I0CFG,)),
		(None   , "i_i0_stencil_ends"        , (N_I0CFG,)),
		(None   , "i_i0_stencil_lut"         , (N_SLUT0,)),
		(None   , "i_i1_local_xor_srcs"      , (N_I1CFG,CV_BW,)),
		(None   , "i_i1_local_xor_swaps"     , (N_I1CFG,)),
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
		(None   , "i_i1_wrap"),
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
	) + (syst_tup if SIM_MODE == 2 else tuple()),
	(("cfg_rdy",),),
	(("cfg_ack",),),
])
rst_out_ev, ck_ev = CreateEvents(["rst_out", "ck_ev"])
npd.random.seed(12345)
RegisterCoroutines([
	main(),
])
