module ans_encoder (
  input wire [`SYM_WIDTH-1:0] in,
  output reg [`SYM_WIDTH-1:0] out,

  input wire in_vld,
  output reg in_rdy,

  output reg out_vld,
  input wire out_rdy,

  input wire clk,
  input wire rst_n
);

always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    // Reset all signals.
    out_vld <= 1'b0;
    in_rdy <= 1'b1;
    out <= 0;
  end else if (in_vld && in_rdy) begin
    // We have input data, process it.
    out <= in;
    in_rdy <= 1'b0;
    out_vld <= 1'b1;
  end else if (out_vld && out_rdy) begin
    // Output data has been read, go back to reading an input.
    out_vld <= 1'b0;
    in_rdy <= 1'b1;
  end
end

endmodule
