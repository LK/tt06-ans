module ans_decoder (
  input wire [`SYM_WIDTH-1:0] in,
  output reg [`SYM_WIDTH-1:0] out,

  input wire [(`CNT_WIDTH * `SYM_COUNT)-1:0] counts_unpacked,

  input wire in_vld,
  output reg in_rdy,

  output reg out_vld,
  input wire out_rdy,

  input wire clk,
  input wire en,
  input wire rst_n
);

typedef enum reg [1:0] {
    StateReadingState = 2'b00,
    StateReadingValue = 2'b01,
    StateWritingValue = 2'b10
} state_t;

state_t current_state, next_state;

wire [`CNT_WIDTH-1:0] counts[`SYM_COUNT-1:0];

reg [`STATE_WIDTH-1:0] decoder_state;
reg [`CNT_WIDTH-1:0] decoder_state_ptr;

genvar i;
generate for (i = 0; i < `SYM_COUNT; i = i + 1) begin
  assign counts[i] = counts_unpacked[i*(`CNT_WIDTH) +: `CNT_WIDTH];
end endgenerate

always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    current_state <= StateReadingState;
  end else begin
    current_state <= next_state;
  end
end

always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    // Reset all signals.
    out_vld <= 1'b0;
    in_rdy <= 1'b1;
    out <= 0;
  end else if (en) begin
    case (current_state)
      StateReadingState: begin
        if (in_vld && in_rdy) begin
          decoder_state[decoder_state_ptr * 4 +: 4] <= in;
          decoder_state_ptr <= decoder_state_ptr + 1;
          in_rdy <= 1'b0;
        end else if (!in_vld && !in_rdy) begin
          if (decoder_state_ptr == `STATE_WIDTH-1) begin
            next_state <= StateReadingValue;
          end else begin
            in_rdy <= 1'b1;
          end
        end
      end
    endcase
  end
end

endmodule
