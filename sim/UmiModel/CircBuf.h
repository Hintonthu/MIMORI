#pragma once
#include <array>
#include <cassert>
#include <cstdio>

template <typename T, size_t N>
class CircBuf {
public:
	std::array<T, N> buf_;
	size_t head_, n_;
	inline size_t Wrap(size_t x) { return x >= N ? x-N : x; }
	inline size_t Idx(size_t i) { return Wrap(head_+i); }
	CircBuf(): head_(0), n_(0) {}
	T& Head() {
		assert(not Empty());
		return buf_[head_];
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
		return p.second < n_;
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
