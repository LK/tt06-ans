module ans_loader (
  input wire [`CNT_WIDTH-1:0] in,
  
  // Yosys doesn't support arrays in ports (sad), so we need to unpack/repack
  // the array as suggested on reddit:
  // https://old.reddit.com/r/yosys/comments/44d7v6/arrays_as_inputs_to_modules/
  output wire [(`CNT_WIDTH * `SYM_COUNT)-1:0] counts_unpacked,

  input wire in_vld,
  output reg in_rdy,

  input wire clk,
  input wire rst_n
);

reg [`CNT_WIDTH-1:0] counts_reg[`SYM_COUNT-1:0];
reg [`SYM_WIDTH-1:0] counter;

genvar i;
generate for (i = 0; i < `SYM_COUNT; i = i + 1) begin
  assign counts_unpacked[i*(`CNT_WIDTH) +: `CNT_WIDTH] = counts_reg[i];
end endgenerate

always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    in_rdy <= 1'b1;
    for (integer i = 0; i < `SYM_COUNT; i = i + 1) begin
      counts_reg[i] <= 0;
    end
    counter <= 0;
  end else if (in_rdy && in_vld) begin
    counts_reg[counter] <= in;
    counter <= counter + 1'b1;
    in_rdy <= 1'b0;
  end else if (!in_rdy && !in_vld) begin
    in_rdy <= 1'b1;
  end
end

endmodule
