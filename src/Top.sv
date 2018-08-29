// Copyright 2016-2018 Yu Sheng Lin

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

`include "common/define.sv"
`include "common/TauCfg.sv"
`ifdef SC
`include "ParallelBlockLooper.sv"
`endif
`ifdef MC
`include "ParallelBlockLooper_mc.sv"
`endif
`ifdef SD
`include "BidirFifo.sv"
`include "ParallelBlockLooper_sd.sv"
`endif
`include "TileAccumUnit/TileAccumUnit.sv"

module Top(
`ifdef VERI_TOP_Top
	n_tau,
	n_tau_x,
	n_tau_y,
`endif
	`clk_port,
	`rdyack_port(src),
	i_bgrid_step,    // block shape
	i_bgrid_end,     // block shape * #block
	i_bboundary,     // block idx boundary
	i_bsubofs,       // describe idx for a warp
	i_bsub_up_order, // describe idx for a warp
	i_bsub_lo_order, // describe idx for a warp
	i_agrid_step,
	i_agrid_end,
	i_aboundary,
	i_i0_local_xor_srcs,     // configure data layout in SRAM
	i_i0_local_xor_swaps,    // configure omega network (see paper)
	i_i0_local_boundaries,   // memory multiplier (also boundary)
	i_i0_local_bsubsteps,    // memory offsets for a warp
	i_i0_local_pads,         // padding after each dimension
	i_i0_global_starts,      // precomputed memory offsets for each dimension
	i_i0_global_linears,     // linear address
	i_i0_global_cboundaries, // memory multiplier * shared memory shape (not padded)
	i_i0_global_boundaries,  // memory multiplier (also boundary)
	i_i0_global_bshufs,      // VDIM -> DIM mapping
	i_i0_global_ashufs,      // VDIM -> DIM mapping
	i_i0_bstrides_frac,      // describe parallelism strides
	i_i0_bstrides_shamt,     // describe parallelism strides
	i_i0_astrides_frac,      // describe accumulation strides
	i_i0_astrides_shamt,     // describe accumulation strides
	i_i0_wrap,               // padding or wrapping?
	i_i0_pad_value,          // padding value
	i_i0_id_begs,
	i_i0_id_ends,
	i_i0_stencil,
	i_i0_stencil_begs,
	i_i0_stencil_ends,
	i_i0_stencil_lut,
`ifdef SD
	i_i0_systolic_skip,      // Can we skip the data load and obtain from neighbors
	i_i0_systolic_axis,      // How to schedule blocks
`endif
	i_i1_local_xor_srcs,
	i_i1_local_xor_swaps,
	i_i1_local_boundaries,
	i_i1_local_bsubsteps,
	i_i1_local_pads,
	i_i1_global_starts,
	i_i1_global_linears,
	i_i1_global_cboundaries,
	i_i1_global_boundaries,
	i_i1_global_bshufs,
	i_i1_global_ashufs,
	i_i1_bstrides_frac,
	i_i1_bstrides_shamt,
	i_i1_astrides_frac,
	i_i1_astrides_shamt,
	i_i1_wrap,
	i_i1_pad_value,
	i_i1_id_begs,
	i_i1_id_ends,
	i_i1_stencil,
	i_i1_stencil_begs,
	i_i1_stencil_ends,
	i_i1_stencil_lut,
`ifdef SD
	i_i1_systolic_skip,
	i_i1_systolic_axis,
`endif
	// TODO [0] is not used
	i_o_global_boundaries,
	i_o_global_bsubsteps,
	i_o_global_linears,
	i_o_global_bshufs,
	i_o_bstrides_frac,
	i_o_bstrides_shamt,
	i_o_global_ashufs,
	i_o_astrides_frac,
	i_o_astrides_shamt,
	i_o_id_begs,
	i_o_id_ends,
	i_inst_id_begs,
	i_inst_id_ends,
	i_insts,
	i_consts,
	i_const_texs,
	i_reg_per_warp,
`ifdef VERI_TOP_Top
	`rdyack2_port(dramra),
`else
	`rdyack_port(dramra),
`endif
	o_dramras,
	`rdyack_port(dramrd),
	i_dramrds,
`ifdef VERI_TOP_Top
	`rdyack2_port(dramw),
`else
	`rdyack_port(dramw),
`endif
	o_dramwas,
	o_dramwds,
	o_dramw_masks
`ifdef SD
	i_i1_systolic_skip,
	i_i1_systolic_axis,
`endif
);

//======================================
// Parameter
//======================================
localparam WBW = TauCfg::WORK_BW;
localparam GBW = TauCfg::GLOBAL_ADDR_BW;
localparam LBW0 = TauCfg::LOCAL_ADDR_BW0;
localparam LBW1 = TauCfg::LOCAL_ADDR_BW1;
localparam DBW = TauCfg::DATA_BW;
localparam TDBW = TauCfg::TMP_DATA_BW;
localparam DIM = TauCfg::DIM;
localparam VDIM = TauCfg::VDIM;
localparam N_ICFG = TauCfg::N_ICFG;
localparam N_OCFG = TauCfg::N_OCFG;
localparam N_INST = TauCfg::N_INST;
localparam SS_BW = TauCfg::STRIDE_BW;
localparam SF_BW = TauCfg::STRIDE_FRAC_BW;
localparam ISA_BW = TauCfg::ISA_BW;
localparam VSIZE = TauCfg::VSIZE;
localparam CSIZE = TauCfg::CACHE_SIZE;
localparam XOR_BW = TauCfg::XOR_BW;
localparam REG_ADDR = TauCfg::WARP_REG_ADDR_SPACE;
localparam CONST_LUT = TauCfg::CONST_LUT;
localparam CONST_TEX_LUT = TauCfg::CONST_TEX_LUT;
localparam STSIZE = TauCfg::STENCIL_SIZE;
localparam N_TAU = TauCfg::N_TAU;
`ifdef SD
localparam N_TAU_X = TauCfg::N_TAU_X;
localparam N_TAU_Y = TauCfg::N_TAU_Y;
localparam CN_TAU_X = $clog2(N_TAU_X);
localparam CN_TAU_Y = $clog2(N_TAU_Y);
localparam CN_TAU_X1 = $clog2(N_TAU_X+1);
localparam CN_TAU_Y1 = $clog2(N_TAU_Y+1);
`else
localparam N_TAU_X = 1;
localparam N_TAU_Y = 1;
`endif
// derived
localparam ICFG_BW = $clog2(N_ICFG+1);
localparam OCFG_BW = $clog2(N_OCFG+1);
localparam INST_BW = $clog2(N_INST+1);
localparam DIM_BW = $clog2(DIM);
localparam VDIM_BW1 = $clog2(VDIM+1);
localparam CV_BW = $clog2(VSIZE);
localparam CCV_BW = $clog2(CV_BW+1);
localparam REG_ABW = $clog2(REG_ADDR);
localparam ST_BW = $clog2(STSIZE+1);

//======================================
// I/O
//======================================
`ifdef VERI_TOP_Top
	output [31:0] n_tau;
	output [31:0] n_tau_x;
	output [31:0] n_tau_y;
	assign n_tau = N_TAU;
	assign n_tau_x = N_TAU_X;
	assign n_tau_y = N_TAU_Y;
`endif
`clk_input;
`rdyack_input(src);
input [WBW-1:0]     i_bgrid_step     [VDIM];
input [WBW-1:0]     i_bgrid_end      [VDIM];
input [WBW-1:0]     i_bboundary      [VDIM];
input [CV_BW-1:0]   i_bsubofs [VSIZE][VDIM];
input [CCV_BW-1:0]  i_bsub_up_order  [VDIM];
input [CCV_BW-1:0]  i_bsub_lo_order  [VDIM];
input [WBW-1:0]     i_agrid_step     [VDIM];
input [WBW-1:0]     i_agrid_end      [VDIM];
input [WBW-1:0]     i_aboundary      [VDIM];
input [XOR_BW-1:0]  i_i0_local_xor_srcs       [N_ICFG][CV_BW];
input [CCV_BW-1:0]  i_i0_local_xor_swaps      [N_ICFG];
input [LBW0-1:0]    i_i0_local_boundaries     [N_ICFG][DIM];
input [LBW0-1:0]    i_i0_local_bsubsteps      [N_ICFG][CV_BW];
input [CV_BW-1:0]   i_i0_local_pads           [N_ICFG][DIM];
input [WBW-1:0]     i_i0_global_starts        [N_ICFG][DIM];
input [GBW-1:0]     i_i0_global_linears       [N_ICFG];
input [GBW-1:0]     i_i0_global_cboundaries   [N_ICFG][DIM];
input [GBW-1:0]     i_i0_global_boundaries    [N_ICFG][DIM];
input [DIM_BW-1:0]  i_i0_global_bshufs        [N_ICFG][VDIM];
input [DIM_BW-1:0]  i_i0_global_ashufs        [N_ICFG][VDIM];
input [SF_BW-1:0]   i_i0_bstrides_frac        [N_ICFG][VDIM];
input [SS_BW-1:0]   i_i0_bstrides_shamt       [N_ICFG][VDIM];
input [SF_BW-1:0]   i_i0_astrides_frac        [N_ICFG][VDIM];
input [SS_BW-1:0]   i_i0_astrides_shamt       [N_ICFG][VDIM];
input [N_ICFG-1:0]  i_i0_wrap;
input [DBW-1:0]     i_i0_pad_value [N_ICFG];
input [ICFG_BW-1:0] i_i0_id_begs [VDIM+1];
input [ICFG_BW-1:0] i_i0_id_ends [VDIM+1];
input               i_i0_stencil;
input [ST_BW-1:0]   i_i0_stencil_begs [N_ICFG];
input [ST_BW-1:0]   i_i0_stencil_ends [N_ICFG];
input [LBW0-1:0]    i_i0_stencil_lut [STSIZE];
`ifdef SD
input [N_ICFG-1:0]  i_i0_systolic_skip;
input [VDIM_BW1-1:0] i_i0_systolic_axis;
`endif
input [XOR_BW-1:0]  i_i1_local_xor_srcs       [N_ICFG][CV_BW];
input [CCV_BW-1:0]  i_i1_local_xor_swaps      [N_ICFG];
input [LBW1-1:0]    i_i1_local_boundaries     [N_ICFG][DIM];
input [LBW1-1:0]    i_i1_local_bsubsteps      [N_ICFG][CV_BW];
input [CV_BW-1:0]   i_i1_local_pads           [N_ICFG][DIM];
input [WBW-1:0]     i_i1_global_starts        [N_ICFG][DIM];
input [GBW-1:0]     i_i1_global_linears       [N_ICFG];
input [GBW-1:0]     i_i1_global_cboundaries   [N_ICFG][DIM];
input [GBW-1:0]     i_i1_global_boundaries    [N_ICFG][DIM];
input [DIM_BW-1:0]  i_i1_global_bshufs        [N_ICFG][VDIM];
input [DIM_BW-1:0]  i_i1_global_ashufs        [N_ICFG][VDIM];
input [SF_BW-1:0]   i_i1_bstrides_frac        [N_ICFG][VDIM];
input [SS_BW-1:0]   i_i1_bstrides_shamt       [N_ICFG][VDIM];
input [SF_BW-1:0]   i_i1_astrides_frac        [N_ICFG][VDIM];
input [SS_BW-1:0]   i_i1_astrides_shamt       [N_ICFG][VDIM];
input [N_ICFG-1:0]  i_i1_wrap;
input [DBW-1:0]     i_i1_pad_value [N_ICFG];
input [ICFG_BW-1:0] i_i1_id_begs [VDIM+1];
input [ICFG_BW-1:0] i_i1_id_ends [VDIM+1];
input               i_i1_stencil;
input [ST_BW-1:0]   i_i1_stencil_begs [N_ICFG];
input [ST_BW-1:0]   i_i1_stencil_ends [N_ICFG];
input [LBW1-1:0]    i_i1_stencil_lut [STSIZE];
`ifdef SD
input [N_ICFG-1:0]  i_i1_systolic_skip;
input [VDIM_BW1-1:0] i_i1_systolic_axis;
`endif
input [GBW-1:0]     i_o_global_boundaries    [N_OCFG][DIM];
input [GBW-1:0]     i_o_global_bsubsteps     [N_OCFG][CV_BW];
input [GBW-1:0]     i_o_global_linears       [N_OCFG];
input [DIM_BW-1:0]  i_o_global_bshufs        [N_OCFG][VDIM];
input [SF_BW-1:0]   i_o_bstrides_frac        [N_OCFG][VDIM];
input [SS_BW-1:0]   i_o_bstrides_shamt       [N_OCFG][VDIM];
input [DIM_BW-1:0]  i_o_global_ashufs        [N_OCFG][VDIM];
input [SF_BW-1:0]   i_o_astrides_frac        [N_OCFG][VDIM];
input [SS_BW-1:0]   i_o_astrides_shamt       [N_OCFG][VDIM];
input [OCFG_BW-1:0] i_o_id_begs [VDIM+1];
input [OCFG_BW-1:0] i_o_id_ends [VDIM+1];
input [INST_BW-1:0] i_inst_id_begs [VDIM+1];
input [INST_BW-1:0] i_inst_id_ends [VDIM+1];
input [ISA_BW-1:0]  i_insts [N_INST];
input [TDBW-1:0]    i_consts [CONST_LUT];
input [TDBW-1:0]    i_const_texs [CONST_TEX_LUT];
input [REG_ABW-1:0] i_reg_per_warp;
output [N_TAU-1:0] dramra_rdy;
`ifdef VERI_TOP_Top
input  [N_TAU-1:0] dramra_canack;
logic  [N_TAU-1:0] dramra_ack;
assign dramra_ack = dramra_rdy & dramra_canack;
`else
input  [N_TAU-1:0] dramra_ack;
`endif
output [GBW-1:0]   o_dramras [N_TAU];
input  [N_TAU-1:0] dramrd_rdy;
output [N_TAU-1:0] dramrd_ack;
input  [DBW-1:0]   i_dramrds [N_TAU][CSIZE];
output [N_TAU-1:0] dramw_rdy;
`ifdef VERI_TOP_Top
input  [N_TAU-1:0] dramw_canack;
logic  [N_TAU-1:0] dramw_ack;
assign dramw_ack = dramw_rdy & dramw_canack;
`else
input  [N_TAU-1:0] dramw_ack;
`endif
output [GBW-1:0]   o_dramwas [N_TAU];
output [DBW-1:0]   o_dramwds [N_TAU][CSIZE];
output [CSIZE-1:0] o_dramw_masks [N_TAU];

//======================================
// Internal
//======================================
`ifdef SC
`rdyack_logic(blk_tau_bofs);
logic [WBW-1:0] blk_tau_bofs [VDIM];
`dval_logic(tau_blk_done);
`endif
`ifdef MC
logic [N_TAU-1:0] blk_tau_bofs_rdys;
logic [N_TAU-1:0] blk_tau_bofs_acks;
logic [WBW-1:0] blk_tau_bofss [N_TAU][VDIM];
logic [N_TAU-1:0] tau_blk_dones;
`endif
`ifdef SD
logic                 blk_tau_bofs_rdys         [N_TAU_X][N_TAU_Y];
logic                 blk_tau_bofs_acks         [N_TAU_X][N_TAU_Y];
logic [WBW-1:0]       blk_tau_bofss             [N_TAU_X][N_TAU_Y][VDIM];
logic [CN_TAU_X1-1:0] blk_tau_i0_systolic_gsize [N_TAU_X][N_TAU_Y];
logic [CN_TAU_Y -1:0] blk_tau_i0_systolic_idx   [N_TAU_X][N_TAU_Y];
logic [CN_TAU_X1-1:0] blk_tau_i1_systolic_gsize [N_TAU_X][N_TAU_Y];
logic [CN_TAU_Y -1:0] blk_tau_i1_systolic_idx   [N_TAU_X][N_TAU_Y];
logic [N_TAU-1:0]     tau_blk_dones;
logic
	tau_i0_dir0_syst_in_rdy  [N_TAU_X][N_TAU_Y],
	tau_i0_dir0_syst_in_ack  [N_TAU_X][N_TAU_Y],
	tau_i0_dir1_syst_in_rdy  [N_TAU_X][N_TAU_Y],
	tau_i0_dir1_syst_in_ack  [N_TAU_X][N_TAU_Y],
	tau_i0_dir0_syst_out_rdy [N_TAU_X][N_TAU_Y],
	tau_i0_dir0_syst_out_ack [N_TAU_X][N_TAU_Y],
	tau_i0_dir1_syst_out_rdy [N_TAU_X][N_TAU_Y],
	tau_i0_dir1_syst_out_ack [N_TAU_X][N_TAU_Y],
	tau_i1_dir0_syst_in_rdy  [N_TAU_X][N_TAU_Y],
	tau_i1_dir0_syst_in_ack  [N_TAU_X][N_TAU_Y],
	tau_i1_dir1_syst_in_rdy  [N_TAU_X][N_TAU_Y],
	tau_i1_dir1_syst_in_ack  [N_TAU_X][N_TAU_Y],
	tau_i1_dir0_syst_out_rdy [N_TAU_X][N_TAU_Y],
	tau_i1_dir0_syst_out_ack [N_TAU_X][N_TAU_Y],
	tau_i1_dir1_syst_out_rdy [N_TAU_X][N_TAU_Y],
	tau_i1_dir1_syst_out_ack [N_TAU_X][N_TAU_Y];
logic [DBW-1:0] tau_i0_syst_data_out [N_TAU_X][N_TAU_Y][VSIZE];
logic [DBW-1:0] tau_i1_syst_data_out [N_TAU_X][N_TAU_Y][VSIZE];
logic [DBW-1:0] tau_i0_syst_data_in  [N_TAU_X+1][N_TAU_Y][VSIZE];
logic [DBW-1:0] tau_i1_syst_data_in  [N_TAU_X][N_TAU_Y+1][VSIZE];
always_comb begin
	for (int k = 0; k < N_TAU_X; k++) begin
		tau_i1_dir0_syst_in_rdy [k][0        ] = 1'b0;
		tau_i1_dir1_syst_in_rdy [k][N_TAU_Y-1] = 1'b0;
		tau_i1_dir1_syst_out_ack[k][0        ] = tau_i1_dir1_syst_out_rdy[k][0        ];
		tau_i1_dir0_syst_out_ack[k][N_TAU_Y-1] = tau_i1_dir0_syst_out_rdy[k][N_TAU_Y-1];
	end
	for (int k = 0; k < N_TAU_Y; k++) begin
		tau_i0_dir0_syst_in_rdy [0        ][k] = 1'b0;
		tau_i0_dir1_syst_in_rdy [N_TAU_X-1][k] = 1'b0;
		tau_i0_dir1_syst_out_ack[0        ][k] = tau_i0_dir1_syst_out_rdy[0        ][k];
		tau_i0_dir0_syst_out_ack[N_TAU_X-1][k] = tau_i0_dir0_syst_out_rdy[N_TAU_X-1][k];
	end
end

always_comb begin
	for (int k = 0; k < N_TAU_X; k++) begin
		for (int l = 0; l < VSIZE; l++) begin
			tau_i1_syst_data_in[k][0      ][l] = '0;
			tau_i1_syst_data_in[k][N_TAU_Y][l] = '0;
		end
	end
	for (int k = 0; k < N_TAU_Y; k++) begin
		for (int l = 0; l < VSIZE; l++) begin
			tau_i0_syst_data_in[0      ][k][l] = '0;
			tau_i0_syst_data_in[N_TAU_X][k][l] = '0;
		end
	end
end
`endif

//======================================
// Submodule
//======================================
`ifdef SC
ParallelBlockLooper u_pbl(
	`clk_connect,
	`rdyack_connect(src, src),
	.i_bgrid_step(i_bgrid_step),
	.i_bgrid_end(i_bgrid_end),
	`rdyack_connect(bofs, blk_tau_bofs),
	.o_bofs(blk_tau_bofs),
	`dval_connect(blkdone, tau_blk_done)
);
`endif
`ifdef MC
ParallelBlockLooper_mc u_pbl(
	`clk_connect,
	`rdyack_connect(src, src),
	.i_bgrid_step(i_bgrid_step),
	.i_bgrid_end(i_bgrid_end),
	.bofs_rdys(blk_tau_bofs_rdys),
	.bofs_acks(blk_tau_bofs_acks),
	.o_bofss(blk_tau_bofss),
	.blkdone_dvals(tau_blk_dones)
);
`endif
`ifdef SD
ParallelBlockLooper_sd u_pbl(
	`clk_connect,
	`rdyack_connect(src, src),
	.i_bgrid_step(i_bgrid_step),
	.i_bgrid_end(i_bgrid_end),
	.i_bboundary(i_bboundary),
	.i_i0_systolic_axis(i_i0_systolic_axis),
	.i_i1_systolic_axis(i_i1_systolic_axis),
	.bofs_rdys(blk_tau_bofs_rdys),
	.bofs_acks(blk_tau_bofs_acks),
	.o_bofss(blk_tau_bofss),
	.o_i0_systolic_gsize(blk_tau_i0_systolic_gsize),
	.o_i0_systolic_idx(blk_tau_i0_systolic_idx),
	.o_i1_systolic_gsize(blk_tau_i1_systolic_gsize),
	.o_i1_systolic_idx(blk_tau_i1_systolic_idx),
	.blkdone_dvals(tau_blk_dones)
);
`endif

`ifdef MC
genvar i;
generate for (i = 0; i < N_TAU; i++) begin: taus
`endif
`ifdef SD
genvar i, j;
generate for (i = 0; i < N_TAU_X; i++) begin: tausx
	for (j = 0; j < N_TAU_Y; j++) begin: tausy
`endif
TileAccumUnit u_tau(
	`clk_connect,
`ifdef SC
	`rdyack_connect(bofs, blk_tau_bofs),
	.i_bofs(blk_tau_bofs),
`endif
`ifdef MC
	.bofs_rdy(blk_tau_bofs_rdys[i]),
	.bofs_ack(blk_tau_bofs_acks[i]),
	.i_bofs(blk_tau_bofss[i]),
`endif
`ifdef SD
	.bofs_rdy(blk_tau_bofs_rdys[i][j]),
	.bofs_ack(blk_tau_bofs_acks[i][j]),
	.i_bofs(blk_tau_bofss[i][j]),
	.i_i0_systolic_gsize(blk_tau_i0_systolic_gsize[i][j]),
	.i_i0_systolic_idx(blk_tau_i0_systolic_idx[i][j]),
	.i_i1_systolic_gsize(blk_tau_i1_systolic_gsize[i][j]),
	.i_i1_systolic_idx(blk_tau_i1_systolic_idx[i][j]),
`endif
	.i_bboundary(i_bboundary),
	.i_bsubofs(i_bsubofs),
	.i_bsub_up_order(i_bsub_up_order),
	.i_bsub_lo_order(i_bsub_lo_order),
	.i_agrid_step(i_agrid_step),
	.i_bgrid_step(i_bgrid_step),
	.i_agrid_end(i_agrid_end),
	.i_aboundary(i_aboundary),
	.i_i0_local_xor_srcs(i_i0_local_xor_srcs),
	.i_i0_local_xor_swaps(i_i0_local_xor_swaps),
	.i_i0_local_boundaries(i_i0_local_boundaries),
	.i_i0_local_bsubsteps(i_i0_local_bsubsteps),
	.i_i0_local_pads(i_i0_local_pads),
	.i_i0_global_starts(i_i0_global_starts),
	.i_i0_global_linears(i_i0_global_linears),
	.i_i0_global_cboundaries(i_i0_global_cboundaries),
	.i_i0_global_boundaries(i_i0_global_boundaries),
	.i_i0_global_bshufs(i_i0_global_bshufs),
	.i_i0_bstrides_frac(i_i0_bstrides_frac),
	.i_i0_bstrides_shamt(i_i0_bstrides_shamt),
	.i_i0_global_ashufs(i_i0_global_ashufs),
	.i_i0_astrides_frac(i_i0_astrides_frac),
	.i_i0_astrides_shamt(i_i0_astrides_shamt),
	.i_i0_wrap(i_i0_wrap),
	.i_i0_pad_value(i_i0_pad_value),
	.i_i0_id_begs(i_i0_id_begs),
	.i_i0_id_ends(i_i0_id_ends),
	.i_i0_stencil(i_i0_stencil),
	.i_i0_stencil_begs(i_i0_stencil_begs),
	.i_i0_stencil_ends(i_i0_stencil_ends),
	.i_i0_stencil_lut(i_i0_stencil_lut),
`ifdef SD
	.i_i0_systolic_skip(i_i0_systolic_skip),
`endif
	.i_i1_local_xor_srcs(i_i1_local_xor_srcs),
	.i_i1_local_xor_swaps(i_i1_local_xor_swaps),
	.i_i1_local_boundaries(i_i1_local_boundaries),
	.i_i1_local_bsubsteps(i_i1_local_bsubsteps),
	.i_i1_local_pads(i_i1_local_pads),
	.i_i1_global_starts(i_i1_global_starts),
	.i_i1_global_linears(i_i1_global_linears),
	.i_i1_global_cboundaries(i_i1_global_cboundaries),
	.i_i1_global_boundaries(i_i1_global_boundaries),
	.i_i1_global_bshufs(i_i1_global_bshufs),
	.i_i1_bstrides_frac(i_i1_bstrides_frac),
	.i_i1_bstrides_shamt(i_i1_bstrides_shamt),
	.i_i1_global_ashufs(i_i1_global_ashufs),
	.i_i1_astrides_frac(i_i1_astrides_frac),
	.i_i1_astrides_shamt(i_i1_astrides_shamt),
	.i_i1_wrap(i_i1_wrap),
	.i_i1_pad_value(i_i1_pad_value),
	.i_i1_id_begs(i_i1_id_begs),
	.i_i1_id_ends(i_i1_id_ends),
	.i_i1_stencil(i_i1_stencil),
	.i_i1_stencil_begs(i_i1_stencil_begs),
	.i_i1_stencil_ends(i_i1_stencil_ends),
	.i_i1_stencil_lut(i_i1_stencil_lut),
`ifdef SD
	.i_i1_systolic_skip(i_i1_systolic_skip),
`endif
	.i_o_global_boundaries(i_o_global_boundaries),
	.i_o_global_bsubsteps(i_o_global_bsubsteps),
	.i_o_global_linears(i_o_global_linears),
	.i_o_global_bshufs(i_o_global_bshufs),
	.i_o_bstrides_frac(i_o_bstrides_frac),
	.i_o_bstrides_shamt(i_o_bstrides_shamt),
	.i_o_global_ashufs(i_o_global_ashufs),
	.i_o_astrides_frac(i_o_astrides_frac),
	.i_o_astrides_shamt(i_o_astrides_shamt),
	.i_o_id_begs(i_o_id_begs),
	.i_o_id_ends(i_o_id_ends),
	.i_inst_id_begs(i_inst_id_begs),
	.i_inst_id_ends(i_inst_id_ends),
	.i_insts(i_insts),
	.i_consts(i_consts),
	.i_const_texs(i_const_texs),
	.i_reg_per_warp(i_reg_per_warp),
`ifdef MC
`define i_dram i
`endif
`ifdef SD
`define i_dram (i*N_TAU_Y+j)
`endif
`ifdef SC
	`dval_connect(blkdone, tau_blk_done),
	`rdyack_connect(dramra, dramra),
	.o_dramra(o_dramras[0]),
	`rdyack_connect(dramrd, dramrd),
	.i_dramrd(i_dramrds[0]),
	`rdyack_connect(dramw, dramw),
	.o_dramwa(o_dramwas[0]),
	.o_dramwd(o_dramwds[0]),
	.o_dramw_mask(o_dramw_masks[0])
`else
	.blkdone_dval(tau_blk_dones[`i_dram]),
	.dramra_rdy(dramra_rdy[`i_dram]),
	.dramra_ack(dramra_ack[`i_dram]),
	.o_dramra(o_dramras[`i_dram]),
	.dramrd_rdy(dramrd_rdy[`i_dram]),
	.dramrd_ack(dramrd_ack[`i_dram]),
	.i_dramrd(i_dramrds[`i_dram]),
	.dramw_rdy(dramw_rdy[`i_dram]),
	.dramw_ack(dramw_ack[`i_dram]),
	.o_dramwa(o_dramwas[`i_dram]),
	.o_dramwd(o_dramwds[`i_dram]),
	.o_dramw_mask(o_dramw_masks[`i_dram])
`endif
`ifdef SD
	,
	.i0_dir0_syst_in_rdy(tau_i0_dir0_syst_in_rdy[i][j]),
	.i0_dir0_syst_in_ack(tau_i0_dir0_syst_in_ack[i][j]),
	.i0_dir0_syst_data_in(tau_i0_syst_data_in[i][j]),
	.i0_dir1_syst_in_rdy(tau_i0_dir1_syst_in_rdy[i][j]),
	.i0_dir1_syst_in_ack(tau_i0_dir1_syst_in_ack[i][j]),
	.i0_dir1_syst_data_in(tau_i0_syst_data_in[i+1][j]),
	.i0_dir0_syst_out_rdy(tau_i0_dir0_syst_out_rdy[i][j]),
	.i0_dir0_syst_out_ack(tau_i0_dir0_syst_out_ack[i][j]),
	.i0_dir1_syst_out_rdy(tau_i0_dir1_syst_out_rdy[i][j]),
	.i0_dir1_syst_out_ack(tau_i0_dir1_syst_out_ack[i][j]),
	.i0_syst_data_out(tau_i0_syst_data_out[i][j]),
	.i1_dir0_syst_in_rdy(tau_i1_dir0_syst_in_rdy[i][j]),
	.i1_dir0_syst_in_ack(tau_i1_dir0_syst_in_ack[i][j]),
	.i1_dir0_syst_data_in(tau_i1_syst_data_in[i][j]),
	.i1_dir1_syst_in_rdy(tau_i1_dir1_syst_in_rdy[i][j]),
	.i1_dir1_syst_in_ack(tau_i1_dir1_syst_in_ack[i][j]),
	.i1_dir1_syst_data_in(tau_i1_syst_data_in[i][j+1]),
	.i1_dir0_syst_out_rdy(tau_i1_dir0_syst_out_rdy[i][j]),
	.i1_dir0_syst_out_ack(tau_i1_dir0_syst_out_ack[i][j]),
	.i1_dir1_syst_out_rdy(tau_i1_dir1_syst_out_rdy[i][j]),
	.i1_dir1_syst_out_ack(tau_i1_dir1_syst_out_ack[i][j]),
	.i1_syst_data_out(tau_i1_syst_data_out[i][j])
`endif
);
`ifdef MC
end endgenerate
`endif
`ifdef SD
end end endgenerate
`endif

`ifdef SD
generate for (i = 0; i < N_TAU_X-1; i++) begin: syst_i0_conx
	for (j = 0; j < N_TAU_Y; j++) begin: syst_i0_cony
BidirFifo u_fifox(
	`clk_connect,
	.src0_rdy(tau_i0_dir0_syst_out_rdy[i][j]),
	.src0_ack(tau_i0_dir0_syst_out_ack[i][j]),
	.s0_data(tau_i0_syst_data_out[i][j]),
	.src1_rdy(tau_i0_dir1_syst_out_rdy[i+1][j]),
	.src1_ack(tau_i0_dir1_syst_out_ack[i+1][j]),
	.s1_data(tau_i0_syst_data_out[i+1][j]),
	.dst0_rdy(tau_i0_dir0_syst_in_rdy[i+1][j]),
	.dst0_ack(tau_i0_dir0_syst_in_ack[i+1][j]),
	.dst1_rdy(tau_i0_dir1_syst_in_rdy[i][j]),
	.dst1_ack(tau_i0_dir1_syst_in_ack[i][j]),
	.d01_data(tau_i0_syst_data_in[i+1][j])
);
	end
end endgenerate

generate for (i = 0; i < N_TAU_X; i++) begin: syst_i1_conx
	for (j = 0; j < N_TAU_Y-1; j++) begin: syst_i1_cony
BidirFifo u_fifoy(
	`clk_connect,
	.src0_rdy(tau_i1_dir0_syst_out_rdy[i][j]),
	.src0_ack(tau_i1_dir0_syst_out_ack[i][j]),
	.s0_data(tau_i1_syst_data_out[i][j]),
	.src1_rdy(tau_i1_dir1_syst_out_rdy[i][j+1]),
	.src1_ack(tau_i1_dir1_syst_out_ack[i][j+1]),
	.s1_data(tau_i1_syst_data_out[i][j+1]),
	.dst0_rdy(tau_i1_dir0_syst_in_rdy[i][j+1]),
	.dst0_ack(tau_i1_dir0_syst_in_ack[i][j+1]),
	.dst1_rdy(tau_i1_dir1_syst_in_rdy[i][j]),
	.dst1_ack(tau_i1_dir1_syst_in_ack[i][j]),
	.d01_data(tau_i1_syst_data_in[i][j+1])
);
	end
end endgenerate
`endif

endmodule
