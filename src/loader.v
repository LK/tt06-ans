module ans_loader (
  input wire [`CNT_WIDTH-1:0] in,
  output wire [`CNT_WIDTH-1:0] counts [`SYM_COUNT-1:0],

  input wire in_vld,
  output reg in_rdy,

  input wire clk,
  input wire rst_n
);

reg [`CNT_WIDTH-1:0] counts_reg[`SYM_COUNT-1:0];
reg [`SYM_WIDTH-1:0] counter;

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
