// Copyright (C) 2018, Yu Sheng Lin, johnjohnlys@media.ee.ntu.edu.tw

// This file is part of MIMORI.

// MIMORI is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// MIMORI is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with MIMORI.  If not, see <http://www.gnu.org/licenses/>.

#include <memory>
#include <iostream>
#include "VTop.h"
#include "verilated_vcd_c.h"
#include "nicotb_verilator.h"
#ifdef SC
#  define D_SIM_MODE 0
#endif
#ifdef MC
#  define D_SIM_MODE 1
#endif
#ifdef SD
#  define D_SIM_MODE 2
#endif
static int SIM_MODE = D_SIM_MODE;
static int GATE_LEVEL = 0;

int main()
{
	using namespace std;
	namespace NiVe = Nicotb::Verilator;
	constexpr int MAX_SIM_CYCLE = 20000;
	constexpr int SIM_CYCLE_AFTER_STOP = 10;
	int n_sim_cycle = MAX_SIM_CYCLE, ret = 0;
	auto dump_name = "Top.vcd";
	typedef VTop TopType;

	// Init dut and signals
	// TOP is the default name of our macro
	unique_ptr<TopType> TOP(new TopType);
	TOP->eval();
	NiVe::AddSignal("GATE_LEVEL", (uint8_t*)&GATE_LEVEL, sizeof(int), {});
	NiVe::AddSignal("SIM_MODE", (uint8_t*)&SIM_MODE, sizeof(int), {});
	MAP_SIGNAL_ALIAS(n_tau, N_TAU);
	MAP_SIGNAL_ALIAS(n_tau_x, N_TAU_X);
	MAP_SIGNAL_ALIAS(n_tau_y, N_TAU_Y);
	MAP_SIGNAL_ALIAS(dramw_rdy, w_rdy);
	MAP_SIGNAL_ALIAS(dramw_canack, w_canack);
	MAP_SIGNAL_ALIAS(dramra_rdy, ra_rdy);
	MAP_SIGNAL_ALIAS(dramra_canack, ra_canack);
	MAP_SIGNAL_ALIAS(dramrd_rdy, rd_rdy);
	MAP_SIGNAL_ALIAS(dramrd_ack, rd_ack);
	MAP_SIGNAL_ALIAS(src_rdy, cfg_rdy);
	MAP_SIGNAL_ALIAS(src_ack, cfg_ack);
	MAP_SIGNAL(o_dramwas);
	MAP_SIGNAL(o_dramwds);
	MAP_SIGNAL(o_dramw_masks);
	MAP_SIGNAL(o_dramras);
	MAP_SIGNAL(i_dramrds);
	MAP_SIGNAL(i_bgrid_step);
	MAP_SIGNAL(i_bgrid_end);
	MAP_SIGNAL(i_bboundary);
	MAP_SIGNAL(i_bsubofs);
	MAP_SIGNAL(i_bsub_up_order);
	MAP_SIGNAL(i_bsub_lo_order);
	MAP_SIGNAL(i_agrid_step);
	MAP_SIGNAL(i_agrid_end);
	MAP_SIGNAL(i_aboundary);
	MAP_SIGNAL(i_i0_local_xor_masks);
	MAP_SIGNAL(i_i0_local_xor_schemes);
	MAP_SIGNAL(i_i0_local_xor_configs);
	MAP_SIGNAL(i_i0_local_boundaries);
	MAP_SIGNAL(i_i0_local_bsubsteps);
	MAP_SIGNAL(i_i0_local_pads);
	MAP_SIGNAL(i_i0_global_starts);
	MAP_SIGNAL(i_i0_global_linears);
	MAP_SIGNAL(i_i0_global_cboundaries);
	MAP_SIGNAL(i_i0_global_boundaries);
	MAP_SIGNAL(i_i0_global_bshufs);
	MAP_SIGNAL(i_i0_global_ashufs);
	MAP_SIGNAL(i_i0_bstrides_frac);
	MAP_SIGNAL(i_i0_bstrides_shamt);
	MAP_SIGNAL(i_i0_astrides_frac);
	MAP_SIGNAL(i_i0_astrides_shamt);
	MAP_SIGNAL(i_i0_wrap);
	MAP_SIGNAL(i_i0_pad_value);
	MAP_SIGNAL(i_i0_id_begs);
	MAP_SIGNAL(i_i0_id_ends);
	MAP_SIGNAL(i_i0_stencil);
	MAP_SIGNAL(i_i0_stencil_begs);
	MAP_SIGNAL(i_i0_stencil_ends);
	MAP_SIGNAL(i_i0_stencil_lut);
	MAP_SIGNAL(i_i1_local_xor_masks);
	MAP_SIGNAL(i_i1_local_xor_schemes);
	MAP_SIGNAL(i_i1_local_xor_configs);
	MAP_SIGNAL(i_i1_local_boundaries);
	MAP_SIGNAL(i_i1_local_bsubsteps);
	MAP_SIGNAL(i_i1_local_pads);
	MAP_SIGNAL(i_i1_global_starts);
	MAP_SIGNAL(i_i1_global_linears);
	MAP_SIGNAL(i_i1_global_cboundaries);
	MAP_SIGNAL(i_i1_global_boundaries);
	MAP_SIGNAL(i_i1_global_bshufs);
	MAP_SIGNAL(i_i1_global_ashufs);
	MAP_SIGNAL(i_i1_bstrides_frac);
	MAP_SIGNAL(i_i1_bstrides_shamt);
	MAP_SIGNAL(i_i1_astrides_frac);
	MAP_SIGNAL(i_i1_astrides_shamt);
	MAP_SIGNAL(i_i1_wrap);
	MAP_SIGNAL(i_i1_pad_value);
	MAP_SIGNAL(i_i1_id_begs);
	MAP_SIGNAL(i_i1_id_ends);
	MAP_SIGNAL(i_i1_stencil);
	MAP_SIGNAL(i_i1_stencil_begs);
	MAP_SIGNAL(i_i1_stencil_ends);
	MAP_SIGNAL(i_i1_stencil_lut);
	MAP_SIGNAL(i_o_global_boundaries);
	MAP_SIGNAL(i_o_global_bsubsteps);
	MAP_SIGNAL(i_o_global_linears);
	MAP_SIGNAL(i_o_global_bshufs);
	MAP_SIGNAL(i_o_bstrides_frac);
	MAP_SIGNAL(i_o_bstrides_shamt);
	MAP_SIGNAL(i_o_global_ashufs);
	MAP_SIGNAL(i_o_astrides_frac);
	MAP_SIGNAL(i_o_astrides_shamt);
	MAP_SIGNAL(i_o_id_begs);
	MAP_SIGNAL(i_o_id_ends);
	MAP_SIGNAL(i_inst_id_begs);
	MAP_SIGNAL(i_inst_id_ends);
	MAP_SIGNAL(i_insts);
	MAP_SIGNAL(i_consts);
	MAP_SIGNAL(i_const_texs);
	MAP_SIGNAL(i_reg_per_warp);
#ifdef SD
	MAP_SIGNAL(i_i0_systolic_skip);
	MAP_SIGNAL(i_i0_systolic_axis);
	MAP_SIGNAL(i_i1_systolic_skip);
	MAP_SIGNAL(i_i1_systolic_axis);
#endif

	// Init events
	NiVe::AddEvent("ck_ev");
	NiVe::AddEvent("rst_out");

	// Init simulation
	vluint64_t sim_time = 0;
	unique_ptr<VerilatedVcdC> tfp(new VerilatedVcdC);
	Verilated::traceEverOn(true);
	TOP->trace(tfp.get(), 99);
	tfp->open(dump_name);

	// Simulation
#define Eval TOP->eval();tfp->dump(sim_time++)
#define EvalEvent(e)\
	if (NiVe::TriggerEvent(e)) {\
		ret = 1;\
		goto cleanup;\
	}\
	TOP->eval();\
	NiVe::UpdateWrite();\
	Eval;

	NiVe::Init();
	const size_t ck_ev = NiVe::GetEventIdx("ck_ev"),
	             rst_out = NiVe::GetEventIdx("rst_out");
	int cycle = 0;
	TOP->i_clk = 0;
	TOP->i_rst = 1;
	Eval;
	TOP->i_rst = 0;
	Eval;
	TOP->i_rst = 1;
	EvalEvent(rst_out);
	for (
		;
		cycle < n_sim_cycle and not Verilated::gotFinish();
		++cycle
	) {
		TOP->i_clk = 1;
		EvalEvent(ck_ev);
		TOP->i_clk = 0;
		Eval;
		if (Nicotb::nicotb_fin_wire) {
			n_sim_cycle = min(cycle + SIM_CYCLE_AFTER_STOP, n_sim_cycle);
		}
	}
cleanup:
	cout << "Simulation stop at timestep " << cycle << endl;
	tfp->close();
	NiVe::Final();
	return ret;
}
