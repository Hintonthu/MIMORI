#include "DRAM.h"
#include "DDR4.h"
#include "Cache.h"
#include "Config.h"
#include "Memory.h"
#include "Controller.h"
#include <utility>
#include <vector>
#include <unordered_set>
#include <cassert>
#include <functional>
#include <memory>
#include "CircBuf.h"

typedef DDR4 DDR;
using namespace std;
using namespace ramulator;

// This disable the L2 shared cache
#define RAMU_BUG

class Wrapper {
	static constexpr size_t CMD_BUF_SIZE = 4;
	static constexpr size_t RESP_BUF_SIZE = 16;
	// Cache
	static constexpr size_t CACHE_LINE_SIZE = 8;
	static constexpr size_t CACHE_OUTSTAND_PER_CORE = 16;
	// L1 cache
	static constexpr size_t L1_CACHE_SIZE = 1024;
	static constexpr size_t L1_CACHE_ASSOC = 4;
	// L2 cache (note: not used owing a Ramulator bug, I've filed an issue.)
	static constexpr size_t L2_CACHE_SIZE = 4096;
	static constexpr size_t L2_CACHE_ASSOC = 4;
	static constexpr long DONE = -1;
	typedef Memory<DDR, Controller> MemType;
	unique_ptr<MemType> mem_;
	shared_ptr<CacheSystem> csys_;
	// L2, L1, L1, L1... (ifndef RAMU_BUG)
	// L1, L1, L1... (now)
    vector<unique_ptr<Cache>> caches_;
	vector<Controller<DDR>*> ctrls_;
	vector<CircBuf<Request, CMD_BUF_SIZE>> rq_, wq_;
	vector<CircBuf<long, RESP_BUF_SIZE>> respq_;
	vector<bool> rsuc_tmp_, wsuc_tmp_;
	int n_cores_;
	static vector<unique_ptr<Wrapper>> ctxs_;
	static unordered_set<int> empty_ctxs_;
	Wrapper(const char *org, const char *speed, int n_cores): n_cores_(n_cores)
	{
		Config configs;
		configs.set_core_num(n_cores_);
		rq_.resize(n_cores_);
		wq_.resize(n_cores_);
		respq_.resize(n_cores_);
		rsuc_tmp_.resize(n_cores_);
		wsuc_tmp_.resize(n_cores_);
		int C = 1, R = 1;
		DDR *dram = new DDR(org, speed);
		dram->set_channel_number(C);
		dram->set_rank_number(R);
		for (int c = 0 ; c < C ; c++) {
			DRAM<DDR>* channel = new DRAM<DDR>(dram, DDR::Level::Channel);
			channel->id = c;
			channel->regStats("");
			ctrls_.push_back(new Controller<DDR>(configs, channel));
		}
		mem_.reset(new MemType(configs, ctrls_));
		function<bool(Request)> mem_send = bind(&MemType::send, mem_.get(), placeholders::_1);
		csys_.reset(new CacheSystem(configs, mem_send));
		csys_->first_level = Cache::Level::L1;
#ifdef RAMU_BUG
		csys_->last_level = Cache::Level::L1;
#else
		csys_->last_level = Cache::Level::L2;
		caches_.emplace_back(new Cache(
			L2_CACHE_SIZE, L2_CACHE_ASSOC, CACHE_LINE_SIZE, CACHE_OUTSTAND_PER_CORE*n_cores_,
			Cache::Level::L2, csys_
		));
#endif
		for (int i = 0; i < n_cores_; ++i) {
			caches_.emplace_back(new Cache(
				L1_CACHE_SIZE, L1_CACHE_ASSOC, CACHE_LINE_SIZE, CACHE_OUTSTAND_PER_CORE,
				Cache::Level::L1, csys_
			));
#ifndef RAMU_BUG
			caches_.back()->concatlower(caches_.front().get());
#endif
		}
	}
public:
	void tick(
		const bool *has_rs, const bool *has_ws, const bool *resp_gots, const long *rs, const long *ws,
		bool *r_fulls, bool *w_fulls, bool *has_resps
	) {
		for (int i = 0; i < n_cores_; ++i) {
			// send from queue
			rsuc_tmp_[i] = not rq_[i].Empty() and caches_[i]->send(rq_[i].Head());
			wsuc_tmp_[i] = not wq_[i].Empty() and caches_[i]->send(wq_[i].Head());
			// push to queue
			if (has_rs[i]) {
				long a = rs[i] & ~(CACHE_LINE_SIZE-1);
				rq_[i].Push(Request(a, Request::Type::READ, [this, i, a](Request req) {
					// cache may convert write to read request
					for (int i = 0; i < n_cores_; ++i) {
						auto &respq = respq_[i];
						for (auto it = respq.begin(); respq.end(it); respq.next(it)) {
							auto &resp = respq.deref(it);
							if (resp == req.addr) {
								resp = DONE;
							}
						}
					}
#ifdef RAMU_BUG
					for (auto &c: caches_) {
						c->callback(req);
					}
#else
					caches_.front()->callback(req);
#endif
				}));
				respq_[i].Push(a);
			}
			if (has_ws[i]) {
				long a = ws[i] & ~(CACHE_LINE_SIZE-1);
				wq_[i].Push(Request(a, Request::Type::WRITE, [this](Request req) {
#ifdef RAMU_BUG
					for (auto &c: caches_) {
						c->callback(req);
					}
#else
					caches_.front()->callback(req);
#endif
				}));
			}
		}
		mem_->tick();
		csys_->tick();
		for (int i = 0; i < n_cores_; ++i) {
			// actually pop here
			if (rsuc_tmp_[i]) { rq_[i].Pop(); }
			if (wsuc_tmp_[i]) { wq_[i].Pop(); }
			if (resp_gots[i]) { respq_[i].Pop(); }
			r_fulls[i] = rq_[i].Full() or respq_[i].Full();
			w_fulls[i] = wq_[i].Full();
			has_resps[i] = not respq_[i].Empty() and respq_[i].Head() == DONE;
		}
		Stats::curTick++;
	}
	void Report()
	{
		// I just copy it from the Ramulator source code.
		static int rpt_idx = 0;
		char stats_file[128];
		sprintf(stats_file, "stats_idx_%d.txt", rpt_idx);
		Stats::statlist.output(stats_file);
		mem_->finish();
		Stats::statlist.printall();
		// rpt_idx++;
	}

	static int CreateCtx(int n_cores)
	{
		assert(n_cores > 0);
		auto wrapper = new Wrapper("DDR3_2Gb_x8", "DDR3_1600K", n_cores);
		int idx;
		if (empty_ctxs_.empty()) {
			idx = ctxs_.size();
			ctxs_.emplace_back(wrapper);
		} else {
			auto it = empty_ctxs_.begin();
			idx = *it;
			ctxs_[idx].reset(wrapper);
			empty_ctxs_.erase(it);
		}
		return idx;
	}

	static Wrapper *GetCtx(int idx)
	{
		auto ret = ctxs_.at(idx).get();
		assert(ret != nullptr);
		return ret;
	}

	static void DestroyCtx(int idx)
	{
		if (ctxs_.at(idx)) {
			ctxs_.at(idx).reset();
			empty_ctxs_.insert(idx);
		}
	}
};
vector<unique_ptr<Wrapper>> Wrapper::ctxs_;
unordered_set<int> Wrapper::empty_ctxs_;

extern "C" {

int RamulatorCreate(int n_cores)
{
	return Wrapper::CreateCtx(n_cores);
}

void RamulatorDestroy(int idx)
{
	Wrapper::DestroyCtx(idx);
}

void RamulatorTick(
	int idx,
	const bool *has_r, const bool *has_w, const bool *resp_got, const long *r, const long *w,
	bool *r_full, bool *w_full, bool *has_resp
) {
	Wrapper::GetCtx(idx)->tick(
		has_r, has_w, resp_got, r, w,
		r_full, w_full, has_resp
	);
}

void RamulatorReport(int idx)
{
	Wrapper::GetCtx(idx)->Report();
}

}

