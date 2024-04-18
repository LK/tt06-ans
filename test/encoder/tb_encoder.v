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

  reg [`CNT_WIDTH-1:0] counts[`SYM_COUNT-1:0];
  reg [(`CNT_WIDTH + `SYM_WIDTH)-1:0] cumulative[`SYM_COUNT-1:0];

  // Wire up the inputs and outputs:
  reg [3:0] in_reg;
  reg in_vld;
  reg in_rdy;

  reg [3:0] out_reg;
  reg out_vld;
  reg out_rdy;
  
  reg clk;
  reg rst_n;
  reg ena;

  ans_encoder encoder (

      // Include power ports for the Gate Level test:
`ifdef GL_TEST
      .VPWR(1'b1),
      .VGND(1'b0),
`endif

      .out (out_reg),  
      .s_count(counts[in_reg]),
      .s_cumulative(in_reg == 0 ? 0 : cumulative[in_reg - 1]),
      .total_count(cumulative[`SYM_COUNT-1]),

      .in_vld (in_vld),
      .in_rdy (in_rdy),

      .out_vld (out_vld),
      .out_rdy (out_rdy),

      .ena    (ena),      // enable - goes high when design is selected
      .clk    (clk),      // clock
      .rst_n  (rst_n)     // not reset
  );

endmodule
