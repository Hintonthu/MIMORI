`ifndef __TAUCFG__
`define __TAUCFG__

package TauCfg;
	parameter VSIZE = 32;
	parameter N_ICFG = 3;
	parameter N_OCFG = 3;
	parameter N_INST = 15;
	parameter ISA_BW = 30;         // instruction
	parameter WORK_BW = 16;        // for parallelism/accumumation idx
	parameter DATA_BW = 16;        // data
	parameter STRIDE_BW = 8;       // stride (f)
	parameter STRIDE_FRAC_BW = 3;  // stride (s) ==> actual stride = f<<s
	parameter TMP_DATA_BW = 20;    // tmp data
	parameter GLOBAL_ADDR_BW = 32; // global address (DRAM)
	parameter LOCAL_ADDR_BW0 = 13; // local address (SRAM)
	parameter LOCAL_ADDR_BW1 = 12; // local address (SRAM)
	parameter VDIM = 6; // #DIM of parallelism/accumumation idx
	parameter DIM = 4;  // #DIM of actual tensor
	parameter CACHE_SIZE = 8;
	parameter SRAM_NWORD = 32;
	parameter WARP_REG_ADDR_SPACE = 8;
	parameter MAX_WARP = 64;
	parameter CONST_LUT = 4; // Do not modify it owing to the limitataion of ISA
	parameter CONST_TEX_LUT = 4;
	parameter ALU_DELAY_BUF_SIZE = 2;
	parameter ARB_FIFO_SIZE = 63;
	parameter STENCIL_SIZE = 31;
	parameter MAX_PENDING_BLOCK = 1023;
	parameter MAX_PENDING_INST = 7;
`ifdef SC
	localparam N_TAU = 1;
`endif
`ifdef MC
	localparam N_TAU = 4;
`endif
`ifdef SD
	localparam N_TAU_X = 2;
	localparam N_TAU_Y = 2;
	localparam N_TAU = N_TAU_X * N_TAU_Y;
	localparam CN_TAU_X = $clog2(N_TAU_X);
	localparam CN_TAU_Y = $clog2(N_TAU_Y);
	localparam CN_TAU_X1 = $clog2(N_TAU_X+1);
	localparam CN_TAU_Y1 = $clog2(N_TAU_Y+1);
`endif
	parameter SYSTOLIC_FIFO_DEPTH = 4;
	// derived
	localparam CW_BW = $clog2(WORK_BW);
	localparam XOR_BW = 4; // Enough for indexing 16 bits (3 or 4 are suitable in most cases)
	localparam ICFG_BW = $clog2(N_ICFG+1);
	localparam OCFG_BW = $clog2(N_OCFG+1);
	localparam INST_BW = $clog2(N_INST+1);
	localparam VDIM_BW = $clog2(VDIM);
	localparam DIM_BW = $clog2(DIM);
	localparam CV_BW = $clog2(VSIZE);
	localparam CCV_BW = $clog2(CV_BW+1);
	localparam CX_BW = $clog2(XOR_BW);
	localparam REG_ABW = $clog2(WARP_REG_ADDR_SPACE);
	localparam ST_BW = $clog2(STENCIL_SIZE+1);
	localparam BLOCK_PBW = $clog2(MAX_PENDING_BLOCK+1);
	localparam INST_PBW = $clog2(MAX_PENDING_INST+1);
	localparam MAX_LOCAL_ADDR_BW = LOCAL_ADDR_BW0 > LOCAL_ADDR_BW1 ? LOCAL_ADDR_BW0 : LOCAL_ADDR_BW1;
	// Systolic flag[3:0] document
	// [0] flag, to right
	// [1] flag, to left
	// [3:2]
	//    00 from RP
	//    10 from right (use flag from RP)
	//    11 from left (use flag from RP)
	// +--------+-------------+-------------+------------------+
	// | 0000   | 0001        | 0010        | 0011             |
	// |  ALU   |  ALU        |       ALU   |       ALU        |
	// |   ^    |   ^         |        ^    |        ^         |
	// |   |    |   |         |        |    |        |         |
	// | Switch | Switch -> 1 | 0 <- Switch | 0 <- Switch -> 1 |
	// |   ^    |   ^         |        ^    |        ^         |
	// |   |    |   |         |        |    |        |         |
	// |  RP    |  RP         |       RP    |       RP         |
	// +--------+-------------+-------------+------------------+
	// |                     Data from RP                      |
	// +-------------------------------------------------------+
	//
	// +-------------+------------------+
	// | 1000        | 1001             |
	// |       ALU   |       ALU        |
	// |        ^    |        ^         |
	// |        |    |        |         |
	// | 0 -> Switch | 0 -> Switch -> 1 |
	// |        ^    |        ^         |
	// |        |    |        |         |
	// |       RP    |       RP         |
	// +-------------+------------------+
	// |        Data from 0             |
	// +--------------------------------+
	//
	// +-------------+------------------+
	// | 1100        | 1110             |
	// |  ALU        |       ALU        |
	// |   ^         |        ^         |
	// |   |         |        |         |
	// | Switch <- 1 | 0 <- Switch <- 1 |
	// |   ^         |        ^         |
	// |   |         |        |         |
	// |  RP         |       RP         |
	// +-------------+------------------+
	// |        Data from 1             |
	// +--------------------------------+
`ifdef SD
	parameter STO_BW = 4;
	typedef logic [$clog2(N_TAU_Y  )-1:0] ST_IDX0_T;
	typedef logic [$clog2(N_TAU_Y  )-1:0] ST_IDX1_T;
	`define IS_FROM_SELF(x) (!x[3])
	`define IS_FROM_SIDE(x) (x[3])
	`define IS_FROM_RIGHT(x) (x[3:2] == 2'b10)
	`define IS_FROM_LEFT(x) (x[3:2] == 2'b11)
	`define IS_TO_LEFT(x) (x[1])
	`define IS_TO_RIGHT(x) (x[0])
	`define FROM_SELF  4'b0000
	`define FROM_RIGHT 4'b1000
	`define FROM_LEFT  4'b1100
	`define TO_EMPTY   4'b0000
	`define TO_RIGHT   4'b0001
	`define TO_LEFT    4'b0010
	`define TO_BOTH    4'b0011
`endif
endpackage

`endif
