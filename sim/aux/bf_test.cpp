#include <iomanip>
#include <iostream>
#include <cassert>
#include <algorithm>
#include <numeric>
using namespace std;
constexpr int ORDER = 5;
constexpr int N = 1<<ORDER;
constexpr int MASK = N-1;
constexpr int SRAM_SIZE = 10;

void PrintArray(const int *iarray)
{
	for (int i = 0; i < N; ++i) {
		if (i != 0 and i % 8 == 0) {
			cout << '|';
		}
		cout << setw(4) << iarray[i];
	}
	cout << '\n';
	cout.flush();
}

void PrintArrayBin(const int *iarray)
{
	cout << setw(4);
	for (int i = ORDER-1; i >= 0; --i) {
		for (int j = 0; j < N; ++j) {
			if (j != 0 and j % 8 == 0) {
				cout << '|';
			}
			cout << setw(4) << ((iarray[j] >> i) & 1);
		}
		cout << '\n';
	}
	cout << '\n';
	cout.flush();
}

inline int LowBitShuffle(int cur, int shamt)
{
	const int shamtl = ORDER-shamt;
	const int hi = cur & ~MASK;
	const int lo = cur & MASK;
	return hi | (lo>>shamt) | ((lo<<shamtl) & MASK);
}

void GenerateArray(int *iarray, const int *bf, const int bf_shamt)
{
	const int SRAM_TOTAL = N*SRAM_SIZE;
	int tmp[SRAM_TOTAL];
	for (int i = 0; i < ORDER; ++i) {
		if (bf[i] < 0) {
			continue;
		}
		const int xor_num = 1<<i;
		for (int j = 0; j < SRAM_TOTAL; ++j) {
			if ((j & xor_num) == 0 and ((j>>bf[i]) & 1) != 0) {
				swap(iarray[j], iarray[j^xor_num]);
			}
		}
		PrintArrayBin(iarray);
		PrintArrayBin(iarray+N);
	}
	for (int i = 0; i < SRAM_TOTAL; ++i) {
		tmp[LowBitShuffle(i, bf_shamt)] = iarray[i];
	}
	copy(tmp, tmp+SRAM_TOTAL, iarray);
	PrintArrayBin(iarray);
	PrintArrayBin(iarray+N);
}

void ExpandArray(const int base_addr, const int *strides, int *oarray)
{
	oarray[0] = base_addr;
	for (int i = 0; i < ORDER; ++i) {
		const int n = 1<<i;
		for (int j = 0; j < n; ++j) {
			oarray[j+n] = oarray[j] + strides[i];
		}
	}
}

void BfArray(int *iarray, const int *bf, const int bf_shamt)
{
	for (int i = 0; i < N; ++i) {
		const int orig = iarray[i];
		int &cur = iarray[i];
		for (int j = 0; j < ORDER; ++j) {
			if (bf[j] >= 0) {
				cur ^= ((orig >> bf[j]) & 1) << j;
			}
		}
		cur = LowBitShuffle(cur, bf_shamt);
	}
}

void SortArray(int *iarray)
{
	for (int i = ORDER-1; i >= 0; --i) {
		const int xor_num = 1<<i;
		for (int j = 0; j < N; ++j) {
			if ((j & xor_num) == 0 and (iarray[j] & xor_num) != 0) {
				swap(iarray[j], iarray[j^xor_num]);
			}
		}
	}
}

int main(int argc, char const* argv[])
{
	ios_base::sync_with_stdio(false);
	struct Config {
		const int strides[ORDER];
		const int bf_shamt;
		const int bf[ORDER];
	};
	Config configs[] {
		{{6,4,48,32,64}, 0, {1,2,4,5,6}},
		{{48,32,64,6,4}, 2, {1,2,4,5,6}}
	};
	int CFG, adr_base;
	cin >> CFG;
	cin >> adr_base;
	assert(CFG < sizeof(configs)/sizeof(*configs));
	auto &strides = configs[CFG].strides;
	auto &bf = configs[CFG].bf;
	const int bf_shamt = configs[CFG].bf_shamt;
	int orig_adr_array[N];
	int adr_array[N];
	int golden_bank[N];
	int dat_array[N];
	int sram_array[N*SRAM_SIZE];
	iota(sram_array, sram_array+N*SRAM_SIZE, 0);
	GenerateArray(sram_array, bf, bf_shamt);
	ExpandArray(adr_base, strides, adr_array);
	copy(adr_array, adr_array+N, orig_adr_array);
	PrintArray(adr_array);
	PrintArrayBin(adr_array);

	BfArray(adr_array, bf, bf_shamt);
	PrintArray(adr_array);
	PrintArrayBin(adr_array);

	transform(adr_array, adr_array+N, dat_array, [&](int x){return sram_array[x];} );
	transform(adr_array, adr_array+N, adr_array, [](int x){return x&MASK;} );
	assert(equal(dat_array, dat_array+N, orig_adr_array));
	SortArray(adr_array);
	iota(golden_bank, golden_bank+N, 0);
	assert(equal(adr_array, adr_array+N, golden_bank));
	return 0;
}
