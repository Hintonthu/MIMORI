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
#include "VAccumWarpLooper.h"
#include "verilated_vcd_c.h"
#include "nicotb_verilator.h"

int main()
{
	using namespace std;
	namespace NiVe = Nicotb::Verilator;
	constexpr int MAX_SIM_CYCLE = 10000;
	constexpr int SIM_CYCLE_AFTER_STOP = 10;
	int n_sim_cycle = MAX_SIM_CYCLE, ret = 0;
	auto dump_name = "AccumWarpLooper.vcd";
	typedef VAccumWarpLooper TopType;

	// Init dut and signals
	// TOP is the default name of our macro
	unique_ptr<TopType> TOP(new TopType);
	TOP->eval();
	MAP_SIGNAL_ALIAS(abofs_rdy, bofs_rdy);
	MAP_SIGNAL_ALIAS(abofs_ack, bofs_ack);
	MAP_SIGNAL_ALIAS(addrval_rdy, av_rdy);
	MAP_SIGNAL_ALIAS(addrval_canack, av_canack);
	MAP_SIGNAL(i_bofs);
	MAP_SIGNAL(i_abeg);
	MAP_SIGNAL(i_aend);
	MAP_SIGNAL(i_linears);
	MAP_SIGNAL(i_bboundary);
	MAP_SIGNAL(i_bsubofs);
	MAP_SIGNAL(i_bsub_up_order);
	MAP_SIGNAL(i_bsub_lo_order);
	MAP_SIGNAL(i_aboundary);
	MAP_SIGNAL(i_bgrid_step);
	MAP_SIGNAL(i_global_bshufs);
	MAP_SIGNAL(i_bstrides_frac);
	MAP_SIGNAL(i_bstrides_shamt);
	MAP_SIGNAL(i_global_ashufs);
	MAP_SIGNAL(i_astrides_frac);
	MAP_SIGNAL(i_astrides_shamt);
	MAP_SIGNAL(i_mofs_bsubsteps);
	MAP_SIGNAL(i_mboundaries);
	MAP_SIGNAL(i_id_begs);
	MAP_SIGNAL(i_id_ends);
	MAP_SIGNAL(i_stencil);
	MAP_SIGNAL(i_stencil_begs);
	MAP_SIGNAL(i_stencil_ends);
	MAP_SIGNAL(i_stencil_lut);
	MAP_SIGNAL(o_id);
	MAP_SIGNAL(o_address);
	MAP_SIGNAL(o_valid);
	MAP_SIGNAL(o_retire);

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
		NiVe::TriggerEvent(ck_ev);
		TOP->eval();
		NiVe::UpdateWrite();
		TOP->eval();
		tfp->dump(sim_time++);
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
	return 0;
}
