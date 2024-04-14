module ans_icdf_lookup (
  input wire [(`CNT_WIDTH + `SYM_WIDTH)-1:0] in,
  input wire [((`CNT_WIDTH + `SYM_WIDTH) * `SYM_COUNT)-1:0] cumulative_unpacked,
  input wire start,
  output reg [`SYM_WIDTH-1:0] out,
  output reg done,

  input wire clk,
  input wire rst_n
);

wire [(`CNT_WIDTH + `SYM_WIDTH)-1:0] cumulative[`SYM_COUNT-1:0];

genvar j;
generate for (j = 0; j < `SYM_COUNT; j = j + 1) begin
  assign cumulative[j] = cumulative_unpacked[j*(`CNT_WIDTH + `SYM_WIDTH) +: (`CNT_WIDTH + `SYM_WIDTH)];
end endgenerate

reg [(`CNT_WIDTH + `SYM_WIDTH)-1:0] idx;

// TODO: do this in fewer clock cycles
always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    done <= 1'b0;
    out <= 0;
    idx <= 0;
  end else if (start && !done) begin
    if (cumulative[idx] > in) begin
      out <= idx;
    end else begin 
      idx <= idx + 1;
    end
  end else if (done) begin
    idx <= 0;
    done <= 0;
    out <= 0;
  end
end

endmodule



module ans_decoder (
  input wire [`SYM_WIDTH-1:0] in,
  output reg [`SYM_WIDTH-1:0] out,

  input wire [(`CNT_WIDTH * `SYM_COUNT)-1:0] counts_unpacked,
  input wire [((`CNT_WIDTH + `SYM_WIDTH) * `SYM_COUNT)-1:0] cumulative_unpacked,

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
    StateWritingValue = 2'b01,
    StateUpdatingState = 2'b10,
    StateReadingValue = 2'b11
} state_t;

state_t current_state, next_state;

wire [`CNT_WIDTH-1:0] counts[`SYM_COUNT-1:0];
wire [(`CNT_WIDTH + `SYM_WIDTH)-1:0] cumulative[`SYM_COUNT-1:0];

wire [(`CNT_WIDTH + `SYM_WIDTH)-1:0] max_cumulative;
assign max_cumulative = cumulative[`SYM_COUNT-1];

reg [`STATE_WIDTH-1:0] decoder_state;
reg [`CNT_WIDTH-1:0] decoder_state_ptr;

genvar i;
generate for (i = 0; i < `SYM_COUNT; i = i + 1) begin
  assign counts[i] = counts_unpacked[i*(`CNT_WIDTH) +: `CNT_WIDTH];
end endgenerate

genvar j;
generate for (j = 0; j < `SYM_COUNT; j = j + 1) begin
  assign cumulative[j] = cumulative_unpacked[j*(`CNT_WIDTH + `SYM_WIDTH) +: (`CNT_WIDTH + `SYM_WIDTH)];
end endgenerate

reg start_icdf_lookup;
wire icdf_done;
reg [(`CNT_WIDTH + `SYM_WIDTH)-1:0] icdf_in;
wire [`SYM_WIDTH-1:0] icdf_out;

reg [`STATE_WIDTH-1:0] temp_decoder_state;
reg [1:0] decoder_update_step;

ans_icdf_lookup icdf_lookup (
  .in(icdf_in),
  .cumulative_unpacked(cumulative_unpacked),
  .start(start_icdf_lookup),
  .out(icdf_out),
  .done(icdf_done),
  .clk(clk),
  .rst_n(rst_n)
);

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
    start_icdf_lookup <= 1'b0;
    temp_decoder_state <= 1'b0;
    decoder_update_step <= 1'b0;
  end else if (en) begin
    case (current_state)
      StateReadingState: begin
        if (in_vld && in_rdy) begin
          decoder_state[decoder_state_ptr * 4 +: 4] <= in;
          decoder_state_ptr <= decoder_state_ptr + 1;
          in_rdy <= 1'b0;
        end else if (!in_vld && !in_rdy) begin
          in_rdy <= 1'b1;
          if (decoder_state_ptr == `STATE_WIDTH-1) begin
            next_state <= StateWritingValue;
          end
        end
      end
      StateWritingValue: begin
        if (out_vld && out_rdy) begin
          next_state <= StateUpdatingState;
        end else if (!out_vld && !out_rdy) begin
          if (!start_icdf_lookup) begin
            icdf_in <= decoder_state;
            start_icdf_lookup <= 1'b1;
          end else if (icdf_done) begin
            out <= icdf_out;
            out_vld <= 1'b0;
            start_icdf_lookup <= 1'b0;
            next_state <= StateUpdatingState;
          end
        end
      end
      StateUpdatingState: begin
        if (out_vld) begin
          if (decoder_update_step == 2'b00) begin
            temp_decoder_state <= (decoder_state / max_cumulative);
            decoder_update_step <= 1'b1;
          end else if (decoder_update_step == 2'b1) begin
            temp_decoder_state <= temp_decoder_state * counts[out];
            decoder_update_step <= 1'b10;
          end else if (decoder_update_step == 2'b01) begin
            temp_decoder_state <= temp_decoder_state + decoder_state % max_cumulative - cumulative[out];
            decoder_update_step <= 1'b11;
          end else begin
            decoder_state <= temp_decoder_state;
            decoder_update_step <= 1'b00;
            out_vld <= 1'b0;
          end
        end else begin
          if (decoder_state < max_cumulative) begin
            next_state <= StateReadingValue;
            in_rdy <= 1'b1;
          end else begin
            next_state <= StateWritingValue;
          end
        end
      end
      StateReadingValue: begin
        if (!in_vld && !in_rdy) begin
          next_state <= StateWritingValue;
        end else if (in_vld && in_rdy) begin
          decoder_state <= (decoder_state << `SYM_WIDTH) + in;
          in_rdy <= 1'b0;
        end
      end
    endcase
  end
end

endmodule
