module ans_loader (
  input wire [`CNT_WIDTH-1:0] in,
  
  // Yosys doesn't support arrays in ports (sad), so we need to unpack/repack
  // the array as suggested on reddit:
  // https://old.reddit.com/r/yosys/comments/44d7v6/arrays_as_inputs_to_modules/
  output wire [(`CNT_WIDTH * `SYM_COUNT)-1:0] counts_unpacked,
  output wire [((`CNT_WIDTH + `SYM_WIDTH) * `SYM_COUNT)-1:0] cumulative_unpacked,

  input wire in_vld,
  output reg in_rdy,

  input wire clk,
  input wire en,
  input wire rst_n
);

reg [`CNT_WIDTH-1:0] counts_reg[`SYM_COUNT-1:0];
reg [(`CNT_WIDTH + `SYM_WIDTH)-1:0] cumulative_reg[`SYM_COUNT-1:0];
reg [`SYM_WIDTH-1:0] counter;
reg [(`SYM_WIDTH + `CNT_WIDTH)-1:0] running_sum;

genvar i;
generate for (i = 0; i < `SYM_COUNT; i = i + 1) begin
  assign counts_unpacked[i*(`CNT_WIDTH) +: `CNT_WIDTH] = counts_reg[i];
end endgenerate

genvar j;
generate for (j = 0; j < `SYM_COUNT; j = j + 1) begin
  assign cumulative_unpacked[j*(`CNT_WIDTH + `SYM_WIDTH) +: `CNT_WIDTH + `SYM_WIDTH] = cumulative_reg[j];
end endgenerate

// Input interface works in this order:
// 1. input_ready goes high
// 2. Wait for input_valid to go high
// 3. Process input
// 4. input_ready goes low
// 5. Wait for input_valid to go low
always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    in_rdy <= 1'b1;
    for (integer i = 0; i < `SYM_COUNT; i = i + 1) begin
      counts_reg[i] <= 0;
      cumulative_reg[i] <= 0;
    end
    counter <= 0;
    running_sum <= 0;
  end else if (en && in_rdy && in_vld) begin
    counts_reg[counter] <= in;
    running_sum <= running_sum + in;
    in_rdy <= 1'b0;
  end else if (en && !in_rdy && !in_vld) begin
    cumulative_reg[counter] <= running_sum;
    counter <= counter + 1'b1;
    in_rdy <= 1'b1;
  end
end

endmodule
