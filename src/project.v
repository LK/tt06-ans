/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`define default_netname none
`define DATA_WIDTH 4

`include "encoder.v"

module ans_encoder_top (
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
  assign uio_in[7:6] = 2'b00;
  assign uo_out[7:4] = 4'b0000;

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
  input wire [`DATA_WIDTH-1:0] in,
  output reg [`DATA_WIDTH-1:0] out,
  input wire [1:0] cmd,

  input wire in_vld,
  output reg in_rdy,

  output reg out_vld,
  input wire out_rdy,

  input wire clk,
  input wire rst_n
);

ans_encoder encoder (
  .in(in),
  .out(out),
  .in_vld(in_vld),
  .in_rdy(in_rdy),
  .out_vld(out_vld),
  .out_rdy(out_rdy),
  .clk(clk),
  .rst_n(rst_n)
);

endmodule
