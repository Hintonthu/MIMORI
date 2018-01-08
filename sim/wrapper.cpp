#include "src/DRAM.h"
#include "src/DDR3.h"
#include "src/Cache.h"
#include "src/Config.h"
#include "src/Memory.h"
#include "src/Controller.h"
#include <utility>
#include <vector>
#include <cassert>
#include <functional>
#include <memory>

using namespace std;
using namespace ramulator;

template<typename DDR>
class Wrapper {
	static constexpr size_t CMD_BUF_SIZE = 4;
	static constexpr size_t RESP_BUF_SIZE = 16;
	static constexpr size_t CACHE_SIZE = 512;
	static constexpr size_t CACHE_ASSOC = 2;
	static constexpr size_t CACHE_LINE_SIZE = 8;
	static constexpr size_t CACHE_OUTSTAND = 16;
	static constexpr long DONE = -1;
	typedef Memory<DDR, Controller> MemType;
	unique_ptr<DDR> dram_;
	unique_ptr<MemType> mem_;
	shared_ptr<CacheSystem> csys_;
	unique_ptr<Cache> cache_;
	vector<Controller<DDR>*> ctrls_;
	template <typename T, size_t N>
	class CircBuf {
		array<T, N> buf_;
		size_t head_, n_;
		inline size_t Wrap(size_t x) { return x >= N ? x-N : x; }
		inline size_t Idx(size_t i) { return Wrap(head_+i); }
	public:
		CircBuf(): head_(0), n_(0) {}
		T& Head() {
			assert(not Empty());
			return buf_[head_];
			printf("%p HEAD %zu\n", this, head_);
		}
		void Push(T req) {
			assert(not Full());
			buf_[Idx(n_)] = req;
			++n_;
		}
		void Pop() {
			assert(not Empty());
			head_ = Idx(1);
			--n_;
		}
		bool Empty() {
			return n_ == 0;
		}
		bool Full() {
			return n_ >= N;
		}
		pair<size_t, size_t> begin() {
			return pair<size_t, size_t>(head_, 0);
		}
		bool end(pair<size_t, size_t> &p) {
			return p.second < N;
		}
		void next(pair<size_t, size_t> &p) {
			++p.first;
			++p.second;
			p.first = Wrap(p.first);
		}
		T& deref(pair<size_t, size_t> &p) {
			return buf_[p.first];
		}
	};
	CircBuf<Request, CMD_BUF_SIZE> rq_, wq_;
	CircBuf<long, RESP_BUF_SIZE> respq_;
public:
	Wrapper(DDR *dram): dram_(dram)
	{
		Config configs;
		configs.set_core_num(1);
		int C = 1, R = 1;
		dram_->set_channel_number(C);
		dram_->set_rank_number(R);
		for (int c = 0 ; c < C ; c++) {
			DRAM<DDR>* channel = new DRAM<DDR>(dram, DDR::Level::Channel);
			channel->id = c;
			channel->regStats("");
			ctrls_.push_back(new Controller<DDR>(configs, channel));
		}
		mem_.reset(new MemType(configs, ctrls_));
		function<bool(Request)> mem_send = bind(&MemType::send, mem_.get(), placeholders::_1);
		csys_.reset(new CacheSystem(configs, mem_send));
		// csys_.reset(new CacheSystem(configs, mem_send));
		csys_->first_level = Cache::Level::L2;
		csys_->last_level = Cache::Level::L2;
		cache_.reset(new Cache(
			CACHE_SIZE, CACHE_ASSOC, CACHE_LINE_SIZE, CACHE_OUTSTAND,
			Cache::Level::L2, csys_
		));
	}
	void tick(
		bool has_r, bool has_w, bool resp_got, long r, long w,
		bool &r_full, bool &w_full, bool &has_resp
	) {
		// send from queue
		bool rsuc = not rq_.Empty() and cache_->send(rq_.Head());
		bool wsuc = not wq_.Empty() and cache_->send(wq_.Head());
		auto GenCallback = [this](bool is_read) {
			return [this, is_read](Request req) {
				// cache may convert write to read request
				if (is_read) {
					for (auto it = respq_.begin(); respq_.end(it); respq_.next(it)) {
						auto &resp = respq_.deref(it);
						if (resp == req.addr) {
							resp = DONE;
						}
					}
				}
				cache_->callback(req);
			};
		};
		// push to queue
		if (has_r) {
			long a = r & ~(CACHE_LINE_SIZE-1);
			rq_.Push(Request(a, Request::Type::READ, GenCallback(true)));
			respq_.Push(a);
		}
		if (has_w) {
			long a = w & ~(CACHE_LINE_SIZE-1);
			wq_.Push(Request(a, Request::Type::WRITE, GenCallback(false)));
		}
		mem_->tick();
		csys_->tick();
		// actually pop here
		if (rsuc) { rq_.Pop(); }
		if (wsuc) { wq_.Pop(); }
		if (resp_got) { respq_.Pop(); }
		r_full = rq_.Full() or respq_.Full();
		w_full = wq_.Full();
		has_resp = not respq_.Empty() and respq_.Head() == DONE;
		Stats::curTick++;
	}
	void Report()
	{
		// I just copy it from the Ramulator source code.
		Stats::statlist.output("stats.txt");
		mem_->finish();
		Stats::statlist.printall();
	}
};

extern "C" {

typedef Wrapper<DDR3> WrapperType;
WrapperType *wrapper = nullptr;

WrapperType *GetRamulatorWrapper()
{
	if (wrapper == nullptr) {
		wrapper = new WrapperType(new DDR3("DDR3_2Gb_x8", "DDR3_1600K"));
	}
	return wrapper;
}

void RamulatorTick(
	bool has_r, bool has_w, bool resp_got, long r, long w,
	bool *r_full, bool *w_full, bool *has_resp
) {
	GetRamulatorWrapper()->tick(
		has_r, has_w, resp_got, r, w,
		*r_full, *w_full, *has_resp
	);
}

void RamulatorReport()
{
	GetRamulatorWrapper()->Report();
}

}

