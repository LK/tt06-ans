/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`define default_netname none
`define SYM_WIDTH 4
`define STATE_WIDTH 16
`define SYM_COUNT (2**`SYM_WIDTH)
`define CNT_WIDTH 4
`define STATE_WIDTH 16

module tt_um_lk_ans_top (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // will go high when the design is enabled
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  // All output pins must be assigned. If not used, assign to 0.
  // assign uo_out  = ui_in + uio_in;  // Example: ou_out is the sum of ui_in and uio_in
  // assign uio_out = 0;
  // assign uio_oe  = 0;

  assign uio_oe = 8'b00001111;
  assign uo_out[7:4] = 4'b0000;
  assign uio_out[3:0] = 4'b0000;
  assign uio_out[7:6] = 2'b00;

  ans ans_block (
    .in(ui_in[3:0]),
    .out(uo_out[3:0]),
    .cmd(uio_in[1:0]),
    .in_vld(uio_in[2]),
    .in_rdy(uio_out[4]),
    .out_vld(uio_out[5]),
    .out_rdy(uio_in[3]),
    .clk(clk),
    .rst_n(rst_n)
  );

endmodule

module ans (
  input wire [`SYM_WIDTH-1:0] in,
  output reg [`SYM_WIDTH-1:0] out,
  input wire [1:0] cmd,

  input wire in_vld,
  output wire in_rdy,

  output wire out_vld,
  input wire out_rdy,

  input wire clk,
  input wire rst_n
);

wire mode_enc = cmd == 2'b01;
wire mode_dec = cmd == 2'b10;
wire mode_load = cmd == 2'b11;

wire [`CNT_WIDTH-1:0] counts[`SYM_COUNT-1:0];
wire [(`CNT_WIDTH * `SYM_COUNT)-1:0] counts_unpacked;

wire [(`CNT_WIDTH + `SYM_WIDTH)-1:0] cumulative[`SYM_COUNT-1:0];
wire [((`CNT_WIDTH + `SYM_WIDTH) * `SYM_COUNT)-1:0] cumulative_unpacked;

genvar i;
generate for (i = 0; i < `SYM_COUNT; i = i + 1) begin
  assign counts[i] = counts_unpacked[i*`CNT_WIDTH +: `CNT_WIDTH];
end endgenerate

genvar j;
generate for (j = 0; j < `SYM_COUNT; j = j + 1) begin
  assign cumulative[j] = cumulative_unpacked[j*(`CNT_WIDTH + `SYM_WIDTH) +: (`CNT_WIDTH + `SYM_WIDTH)];
end endgenerate

wire loader_in_rdy;

ans_loader loader (
  .in(in),
  .counts_unpacked(counts_unpacked),
  .cumulative_unpacked(cumulative_unpacked),
  .in_vld(in_vld),
  .in_rdy(loader_in_rdy),
  .clk(clk),
  .en(mode_load),
  .rst_n(rst_n)
);

wire encoder_in_rdy;
wire encoder_out_vld;
wire [`SYM_WIDTH-1:0] encoder_out;

ans_encoder encoder (
  .s_count(counts[in]),
  .s_cumulative(in == 0 ? 0 : cumulative[in - 1]),
  .total_count(cumulative[`SYM_COUNT-1]),
  .in_vld(in_vld),
  .in_rdy(encoder_in_rdy),
  .out(encoder_out),
  .out_vld(encoder_out_vld),
  .out_rdy(out_rdy),
  .clk(clk),
  .ena(mode_enc),
  .rst_n(rst_n)
);

wire decoder_in_rdy;
wire decoder_out_vld;
wire [`SYM_WIDTH-1:0] decoder_out;

ans_decoder decoder (
  .in(in),
  .out(decoder_out),
  .counts_unpacked(counts_unpacked),
  .cumulative_unpacked(cumulative_unpacked),
  .in_vld(in_vld),
  .in_rdy(decoder_in_rdy),
  .out_vld(decoder_out_vld),
  .out_rdy(out_rdy),
  .clk(clk),
  .ena(mode_dec),
  .rst_n(rst_n)
);

assign in_rdy = mode_load ? loader_in_rdy : mode_enc ? encoder_in_rdy : mode_dec ? decoder_in_rdy : (loader_in_rdy | encoder_in_rdy | decoder_in_rdy);
assign out_vld = mode_enc ? encoder_out_vld : mode_dec ? decoder_out_vld : (encoder_out_vld | decoder_out_vld);
assign out = mode_enc ? encoder_out : mode_dec ? decoder_out : (encoder_out | decoder_out);

endmodule
