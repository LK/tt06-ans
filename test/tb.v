`default_nettype none `timescale 1ns / 1ps

/* This testbench just instantiates the module and makes some convenient wires
   that can be driven / tested by the cocotb test.py.
*/
module tb ();

  // Dump the signals to a VCD file. You can view it with gtkwave.
  initial begin
    $dumpfile("tb.vcd");
    $dumpvars(0, tb);
    #1;
  end

  // Wire up the inputs and outputs:
  reg clk;
  reg rst_n;
  reg ena;

  // reg [7:0] ui_in;
  // reg [7:0] uio_in;
  reg [3:0] ans_in;
  reg [1:0] ans_cmd;
  reg ans_in_vld;
  reg ans_out_rdy;

  wire [7:0] uo_out;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;

  wire [3:0] ans_out;
  wire ans_out_vld;
  wire ans_in_rdy;

  assign ans_out = uo_out[3:0];
  assign ans_in_rdy = uio_out[4];
  assign ans_out_vld = uio_out[5];

  tt_um_lk_ans_top user_project (

      // Include power ports for the Gate Level test:
`ifdef GL_TEST
      .VPWR(1'b1),
      .VGND(1'b0),
`endif

      .ui_in  ({4'b0000, ans_in}),    // Dedicated inputs
      .uo_out (uo_out),   // Dedicated outputs
      .uio_in ({4'b0000, ans_out_rdy, ans_in_vld, ans_cmd}),   // IOs: Input path
      .uio_out(uio_out),  // IOs: Output path
      .uio_oe (uio_oe),   // IOs: Enable path (active high: 0=input, 1=output)
      .ena    (ena),      // enable - goes high when design is selected
      .clk    (clk),      // clock
      .rst_n  (rst_n)     // not reset
  );

endmodule
