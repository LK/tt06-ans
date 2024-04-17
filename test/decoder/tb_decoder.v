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
  reg [3:0] in_reg;
  reg [63:0] counts_unpacked;
  reg [127:0] cumulative_unpacked;
  reg in_vld;
  wire in_rdy;

  wire [3:0] out_reg;
  wire out_vld;
  reg out_rdy;
  
  reg clk;
  reg rst_n;
  reg ena_loader;
  reg ena_decoder;

  wire read_type_t read_type;
  wire [(`CNT_WIDTH + `SYM_WIDTH)-1:0] read_query;
  wire [(`CNT_WIDTH + `SYM_WIDTH)-1:0] read_result;
  wire read_rdy;

  ans_loader loader (
    .in(in_reg),
    .in_vld(in_vld),
    .in_rdy(in_rdy),

    .read_type(read_type),
    .read_query(read_query),
    .read_result(read_result),
    .read_rdy(read_rdy),

    .clk(clk),
    .en(ena_loader),
    .rst_n(rst_n)
  );

  ans_decoder decoder (

      // Include power ports for the Gate Level test:
`ifdef GL_TEST
      .VPWR(1'b1),
      .VGND(1'b0),
`endif

      .in (in_reg),
      .out (out_reg),

      .read_type (read_type),
      .read_query (read_query),
      .read_result (read_result),
      .read_rdy (read_rdy),

      .in_vld (in_vld),
      .in_rdy (in_rdy),

      .out_vld (out_vld),
      .out_rdy (out_rdy),

      .ena    (ena_decoder),      // enable - goes high when design is selected
      .clk    (clk),      // clock
      .rst_n  (rst_n)     // not reset
  );

endmodule
