# English

## Brief
This project implements an accelerator architecture (with SystemVerilog) for deep learning as well as other vision-related tasks,
which is based on the paper "Unrolled Memory Inner-Products: An Abstract GPU Operator for Efficient Vision-Related Computations" (ICCV 2017).
If you are looking for the CUDA version of UMI, then please refer to johnjohnlin/UMI, another project made by me.

The project name, MIMORI, stands for *Multi Input Multiple Output Ranged Inner-Product*,
is genealized from the *Generalized Inner-Product* of the *UMI Operator* discussed in the ICCV paper above.

## Benefit
Our goal is to build a accelerator for deep learning as well as other scientific computations.
But it should be easy to use, and this can be mostly done by the generality of UMI.

## Implmentation Status
The I/O of this module is bus-like data interfaces and naive configuration interfaces,
and efforts are required if you want to use it for a real system (e.g.,  AXI, Avalon...).

By default, the design is configured with 1 vector array, which is 32-core and is not very high-performance.
You could scale up by increasing the number of vector array, but I haven't did any test on that yet.
We are also working on the systolic extension.

## Verilog Simulation
The simulation requires 2 git submodules to work, and INCISIV (ncverilog/irun) is also necessary.

* *Nicotb*: Yet another project made by me, johnjohnlin/nicotb, which is similar to potentialventures/cocotb and is a Python-Verilog Co-simulation framework.
  I made Nicotb since it works with numpy better and it's enough for me.
* *Ramulator* (CAL 2015): CMU-SAFARI/ramulator, a extensible DRAM simulator based on C++11. I use a simple C++ wrapper to connect it with Nicotb.

# 中文版 README
I made this part since I am a native Mandarin Chinese speaker (zh_TW).

## 概述
這個專案實做了 "Unrolled Memory Inner-Products: An Abstract GPU Operator for Efficient Vision-Related Computations" (ICCV 2017) 論文中的 UMI Operator。
此專案是以 SystemVerilog 實作架構，目的是提供一個有效率的深度學習以及一般的科學運算的硬體加速。
如果你在找的是 CUDA 版本的實作，請看我的另外一個專案 johnjohnlin/UMI。

專案名稱 MIMORI 全名為 *Multi Input Multiple Output Ranged Inner-Product*，
是由前述論文中的 *UMI Operator* 中的 *Generalized Inner-Product* 延伸得來.

## 好處
我們希望能提供一個很好用的深度學習加速器，但是同時也能給其他運算使用。
這主要歸功於 UMI Operator 是很汎用的。

## 實作狀況
現在的版本使用了類似 bus 的界面以及簡單的設定界面。
要用在真實系統的話，你還需要花點功夫（例：AXI, Avalon...）。

預設設定是一個 vector array，不是算非常頂尖的效能。
你可以複製很多次 vector array 來提昇效能，不過我還沒測試過會怎樣。
我們也正在做 systolic 版本。

## Verilog 模擬
這個專案需要兩個額外的 git submodules 以及 INCISIV (ncverilog/irun)。

* *Nicotb*: 另外一個我的專案 johnjohnlin/nicotb，這跟 potentialventures/cocotb 很像，都是 Python-Verilog Co-simulation 架構。
  因為是我自己做的，我可以跟 numpy 較好結合，比較符合我的需求。
* *Ramulator* (CAL 2015): CMU-SAFARI/ramulator 一個很好擴充的 C++11 DRAM 模擬器，我稍微把他包裝了一下，所以可以跟 Python 接起來。
