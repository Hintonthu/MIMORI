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
#include "VSimdDriver.h"
#include "verilated_vcd_c.h"
#include "nicotb_verilator.h"

int main()
{
	using namespace std;
	namespace NiVe = Nicotb::Verilator;
	constexpr int MAX_SIM_CYCLE = 10000;
	constexpr int SIM_CYCLE_AFTER_STOP = 10;
	int n_sim_cycle = MAX_SIM_CYCLE, ret = 0;
	auto dump_name = "SimdDriver.vcd";
	typedef VSimdDriver TopType;

	// Init dut and signals
	// TOP is the default name of our macro
	unique_ptr<TopType> TOP(new TopType);
	TOP->eval();
	MAP_SIGNAL(abofs_rdy);
	MAP_SIGNAL(abofs_ack);
	MAP_SIGNAL(inst_rdy);
	MAP_SIGNAL(inst_canack);
	MAP_SIGNAL(inst_commit_dval);
	MAP_SIGNAL(i_bofs);
	MAP_SIGNAL(i_aofs_beg);
	MAP_SIGNAL(i_aofs_end);
	MAP_SIGNAL(i_bgrid_step);
	MAP_SIGNAL(i_bsub_up_order);
	MAP_SIGNAL(i_bsub_lo_order);
	MAP_SIGNAL(i_aboundary);
	MAP_SIGNAL(i_inst_id_begs);
	MAP_SIGNAL(i_inst_id_ends);
	MAP_SIGNAL(o_bofs);
	MAP_SIGNAL(o_aofs);
	MAP_SIGNAL(o_pc);
	MAP_SIGNAL(o_warpid);

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
			goto cleanup;
		}
	}
	cout << "Timeout\n";
	ret = 1;
cleanup:
	cout << "Simulation stop at timestep " << cycle << endl;
	tfp->close();
	NiVe::Final();
	return ret;
}
