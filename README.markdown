[![Build Status](https://travis-ci.com/johnjohnlin/MIMORI.svg?branch=master)](https://travis-ci.com/johnjohnlin/MIMORI.svg?branch=master)

## About MERIT Processor
We implement *MERIT Processor*,
an accelerator architecture for deep learning as well as other vision-related tasks with SystemVerilog.
This work is also based on our *Unrolled Memory Inner-Product Operator (UMI Operator)* in ICCV'17 (see the references below),
and you can check out the CUDA version at https://github.com/johnjohnlin/UMI.

The repo name MIMORI cames from *Multi Input Multiple Output Ranged Inner-Product*,
is genealized from the *UMI Operator* mentioned above.
While the architecture name has been changed to *Memory Efficient Ranged Inner-Product (MERIT)*,
we still preserve the original repo name for convenience.

## Why MERIT?
Nowadays the software stack is the most critical part for DNN accelerators.
Apart from writing drivers,
software engineers have to optimize memory movement like prefetching, systolic array, and SRAM bank.
These process is repeatedly performed whenever new algorithms come out,
and many works reduce the optimization efforts by computation abstraction and custom compilers.
However, running compilers for every end-devices is not practical,
and storing and transferring statically-compiled codes might also be a problem.

Our goal is to build an easy-to-program accelerator for data-regular computations,
such as deep learning and many other scientific computations.
Thanks to *UMI Operator*, MERIT processor has these benefits.

**Almost compiler free**:
A network layer can be describe with only tens of integer parameters.
This parameters is (almost) directly written to the cofiguration registers without compiler.
making MERIT Processor more suitable for low-end embedded CPUs.

**Memory efficient**:
Many DNN accelerators utilize per-core local buffers and a large global buffer.
*UMI Operator* identifies the data reuse clearly and provide a methodology to aggregate local buffers as a global buffer.
Besides, while MERIT is a vector processor architecture,
we use *UMI Operator* to also identify a data reuse pattern similar to systolic array,
which we call SysTolic ARray Tensor DAta SHaring (STARTDASH) methodology.

In short, programmers can exploit these optimization with only defining a few integers easily:
* tiling,
* bank-conflict,
* prefetching,
* systolic array data sharing, and
* kernel fusion.

## Hardware Configuration

The interfaces are bus-like data interfaces plus a configuration register interface.
These interfaces are defined to be similar to common bus protocol such as AXI,
and can be converted to this bus protocol with standard procedures.

The design is configured with a 32-core vector array, and can be verified with Synopsys 32 nm Educational Design Kit.
The multiple vector array and its systolic version are also tested under RTL.

## Usage and Verification
### Setup
The simulation requires 2 git submodules to work, and INCISIV (ncverilog/irun) is also necessary.

* *Nicotb*: Yet another project made by me, https://github.com/johnjohnlin/nicotb, which is similar to https://github.com/potentialventures/cocotb and is a Python-Verilog Co-simulation framework.
  I made Nicotb since it works with numpy better and it's enough for me.
* *Ramulator* (CAL 2015): https://github.com/CMU-SAFARI/ramulator, a extensible DRAM simulator based on C++11. I use a simple C++ wrapper to connect it with Nicotb.


```latex
@article{ramulator,
    author={Y. Kim and W. Yang and O. Mutlu},
    journal={IEEE Computer Architecture Letters},
    title={Ramulator: A Fast and Extensible {DRAM} Simulator},
    year={2016},
    volume={15},
    number={1},
    pages={45-49},
    keywords={DRAM chips;circuit simulation;digital simulation;standards;DRAM simulator;DRAM standard;Ramulator;software tool;Hardware design languages;Nonvolatile memory;Proposals;Random access memory;Runtime;Standards;Timing;DRAM;Main memory;performance evaluation, experimental methods, emerging technologies, memory systems, memory scaling;simulation},
    doi={10.1109/LCA.2015.2414456},
    ISSN={1556-6056},
    month={Jan},}
@inproceedings{umi,
    author={Y. S. Lin and W. C. Chen and S. Y. Chien},
    booktitle={2017 IEEE International Conference on Computer Vision (ICCV)},
    title={Unrolled Memory Inner-Products: An Abstract GPU Operator for Efficient Vision-Related Computations},
    year={2017},
    volume={},
    number={},
    pages={4587-4595},
    keywords={Algorithm design and analysis;Computational modeling;Convolution;Graphics processing units;Kernel;Matrix converters;Tensile stress},
    doi={10.1109/ICCV.2017.490},
    ISSN={},
    month={Oct},}
```
