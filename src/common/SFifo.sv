// Copyright 2016 Yu Sheng Lin

// This file is part of Ocean.

// MIMORI is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// MIMORI is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with Ocean.  If not, see <http://www.gnu.org/licenses/>.

module SFifo(
	i_clk,
	i_rst,
	src_rdy,
	src_ack,
	i_data,
	dst_rdy,
	dst_ack,
	o_data
);

parameter BW = 8;
// In SRAM mode, size of n+1 is used to prevent r/w at the same clock
parameter NDATA = 15;
parameter SRAM_MODE = 1;
localparam NDATA1 = NDATA+1; // The SRAM size in SRAM mode
localparam ABW = $clog2(NDATA); // To hold N
localparam ABW1 = $clog2(NDATA+1); // To hold SRAM address
localparam MANUAL_WRAP = $clog2(NDATA+2) == ABW1;

input i_clk;
input i_rst;
input                 src_rdy;
output logic          src_ack;
input        [BW-1:0] i_data;
output logic          dst_rdy;
input                 dst_ack;
output logic [BW-1:0] o_data;

generate if (SRAM_MODE == 0) begin: shift_reg_mode
	logic [NDATA-1:0] rdy_r;
	logic [NDATA-1:0] rdy_w;
	logic [NDATA  :0] is_last;
	logic [BW-1:0] data_r [NDATA];
	logic [BW-1:0] data_w [NDATA];
	assign o_data = data_r[0];
	assign dst_rdy = rdy_r[0];
	assign is_last = {rdy_r, 1'b1} & {1'b1, ~rdy_r};
	assign src_ack = src_rdy & !is_last[NDATA];

	always_comb begin
		case ({src_ack,dst_ack})
			2'b01: begin
				rdy_w = rdy_r >> 1;
			end
			2'b10: begin
				rdy_w = (rdy_r << 1) | 'b1;
			end
			2'b00,
			2'b11: begin
				rdy_w = rdy_r;
			end
		endcase
	end

	always_comb begin
		if (dst_ack) begin
			for (int i = 0; i < NDATA-1; i++) begin
				if (is_last[i+1]) begin
					data_w[i] = src_ack ? i_data : data_r[i];
				end else if (rdy_r[i]) begin
					data_w[i] = data_r[i+1];
				end else begin
					data_w[i] = data_r[i];
				end
			end
			// dst_ack & src_ack --> won't happen when full
			// dst_ack & !src_ack --> nothing to do
			data_w[NDATA-1] = data_r[NDATA-1];
		end else if (src_ack) begin
			for (int i = 0; i < NDATA; i++) begin
				data_w[i] = is_last[i] ? i_data : data_r[i];
			end
		end else begin
			data_w = data_r;
		end
	end

	always_ff @(posedge i_clk or negedge i_rst) begin
		if (!i_rst) begin
			rdy_r <= '0;
		end else if (src_ack^dst_ack) begin
			rdy_r <= rdy_w;
		end
	end

	always_ff @(posedge i_clk or negedge i_rst) begin
		for (int i = 0; i < NDATA; i++) begin
			if (!i_rst) begin
				data_r[i] <= '0;
			end else if (rdy_w[i]) begin
				data_r[i] <= data_w[i];
			end
		end
	end
end else begin: sram_mode
	logic sram_re;
	logic [ABW1-1:0] sram_waddr_r;
	logic [ABW1-1:0] sram_waddr_w;
	logic [ABW1-1:0] sram_raddr_r;
	logic [ABW1-1:0] sram_raddr_w;
	logic [ABW-1:0] n_r;
	logic [ABW-1:0] n_w;
	logic dst_rdy_w;
	logic full_r;
	logic full_w;
	logic [BW-1:0] sram_rdata;
	logic use_shadow_r;
	logic use_shadow_w;
	logic [BW-1:0] shadow_r;
	logic [BW-1:0] shadow_w;
	assign sram_re = use_shadow_r || !use_shadow_w && (n_w != '0) && dst_ack;
	assign src_ack = src_rdy && !full_r;
	assign dst_rdy_w = n_w != '0;
	assign o_data = use_shadow_r ? shadow_r : sram_rdata;
	assign use_shadow_w = (n_w == 'b1) && src_ack;
	assign shadow_w = use_shadow_w ? i_data : shadow_r;
	SRAMDualPort #(.BW(BW), .NDATA(NDATA1)) u_sram(
		.i_clk(i_clk),
		.i_we(src_ack),
		.i_re(sram_re),
		.i_waddr(sram_waddr_r),
		.i_wdata(i_data),
		.i_raddr(sram_raddr_r),
		.o_rdata(sram_rdata)
	);

	always_comb begin
		if (src_ack) begin
			if (MANUAL_WRAP && sram_waddr_r == NDATA) begin
				sram_waddr_w = '0;
			end else begin
				sram_waddr_w = sram_waddr_r + 'b1;
			end
		end else begin
			sram_waddr_w = sram_waddr_r;
		end
	end

	always_comb begin
		if (sram_re) begin
			// the ABW is used to disable the comparison when NDATA is 2^n-1
			if (ABW1 > ABW && sram_raddr_r == NDATA) begin
				sram_raddr_w = '0;
			end else begin
				sram_raddr_w = sram_raddr_r + 'b1;
			end
		end else begin
			sram_raddr_w = sram_raddr_r;
		end
	end

	always_comb begin
		case ({src_ack,dst_ack})
			2'b00,2'b11: begin n_w = n_r      ; end
			2'b01:       begin n_w = n_r - 'b1; end
			2'b10:       begin n_w = n_r + 'b1; end
		endcase
		full_w = n_w == NDATA;
	end

	always_ff @(posedge i_clk or negedge i_rst) begin
		if (!i_rst) begin
			dst_rdy <= 1'b0;
			full_r <= 1'b0;
			use_shadow_r <= 1'b0;
		end else begin
			dst_rdy <= dst_rdy_w;
			full_r <= full_w;
			use_shadow_r <= use_shadow_w;
		end
	end

	// TODO: clock gating
	always_ff @(posedge i_clk or negedge i_rst) begin
		if (!i_rst) begin
			sram_waddr_r <= '0;
			sram_raddr_r <= '0;
			n_r <= '0;
			shadow_r <= '0;
		end else begin
			sram_waddr_r <= sram_waddr_w;
			sram_raddr_r <= sram_raddr_w;
			n_r <= n_w;
			shadow_r <= shadow_w;
		end
	end
end endgenerate

endmodule

