typedef enum reg [1:0] {
  READ_TYPE_NONE = 2'b00,
  READ_TYPE_PMF = 2'b01,
  READ_TYPE_CMF = 2'b10,
  READ_TYPE_ICMF = 2'b11
} read_type_t;


module ans_loader (
  input wire [`CNT_WIDTH-1:0] in,
  
  input wire in_vld,
  output reg in_rdy,

  input wire [1:0] read_type,
  input wire [(`CNT_WIDTH + `SYM_WIDTH)-1:0] read_query,
  output reg [(`CNT_WIDTH + `SYM_WIDTH)-1:0] read_result,
  output reg read_rdy,

  input wire clk,
  input wire en,
  input wire rst_n
);

reg [`CNT_WIDTH-1:0] counts_reg[`SYM_COUNT-1:0];
reg [`SYM_WIDTH-1:0] counter;

reg [`SYM_WIDTH-1:0] query_idx;

always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    read_rdy <= 0;
    read_result <= 0;
    query_idx <= 0;
  end else if (read_type != READ_TYPE_NONE && !read_rdy) begin
  case (read_type)
    READ_TYPE_PMF: begin
      read_result <= counts_reg[read_query[`SYM_WIDTH-1:0]];
      read_rdy <= 1'b1;
    end
    READ_TYPE_CMF: begin
      read_result <= read_result + counts_reg[query_idx];
      if (query_idx == read_query[`SYM_WIDTH-1:0]) begin
        read_rdy <= 1'b1;
      end else begin
        query_idx <= query_idx + 1'b1;
      end
    end
    READ_TYPE_ICMF: begin
      if (read_result > read_query) begin
        read_result <= query_idx - 1;
        read_rdy <= 1'b1;
      end else begin
        read_result <= read_result + counts_reg[query_idx];
        query_idx <= query_idx + 1'b1;
      end
    end
  endcase
  end else if (read_type == READ_TYPE_NONE || read_rdy) begin
    read_rdy <= 0;
    read_result <= 0;
    query_idx <= 0;
  end
end

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
    end
    counter <= 0;
  end else if (en && in_rdy && in_vld) begin
    counts_reg[counter] <= in;
    counter <= counter + 1'b1;
    in_rdy <= 1'b0;
  end else if (en && !in_rdy && !in_vld) begin
    in_rdy <= 1'b1;
  end
end

endmodule
