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
      done <= 1'b1;
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
  input wire ena,
  input wire rst_n
);

typedef enum reg [1:0] {
    READ_STATE = 2'b00,
    WRITE_VALUE = 2'b01,
    UPDATE_STATE = 2'b10,
    READ_VALUE = 2'b11
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
    // Reset all signals.
    out_vld <= 1'b0;
    in_rdy <= 1'b1;
    out <= 0;
    start_icdf_lookup <= 0;
    decoder_state_ptr <= 0;
    icdf_in <= 0;
    decoder_state <= 0;
    current_state <= READ_STATE;
    next_state <= READ_STATE;
  end else if (ena) begin
    current_state <= next_state;
    case (current_state)
      READ_STATE: begin
        // Read the initial state.
        if (in_vld && in_rdy) begin
          decoder_state <= (decoder_state << 4) + in;
          decoder_state_ptr <= decoder_state_ptr + 1;
          in_rdy <= 1'b0;
        end else if (!in_vld && !in_rdy) begin
          if (decoder_state_ptr == `STATE_WIDTH / 4) begin
            next_state <= WRITE_VALUE;
          end else begin
            in_rdy <= 1'b1;
          end
        end
      end
      WRITE_VALUE: begin
        // Emit a symbol.
        if (!out_vld && !out_rdy) begin
          if (!start_icdf_lookup) begin
            icdf_in <= decoder_state % max_cumulative;
            start_icdf_lookup <= 1'b1;
          end else if (icdf_done) begin
            out <= icdf_out;
            out_vld <= 1'b1;
            start_icdf_lookup <= 1'b0;
          end
        end else if (out_vld && out_rdy) begin
          next_state <= UPDATE_STATE;
          decoder_state <= (decoder_state / max_cumulative) * counts[out] + decoder_state % max_cumulative - (out == 0 ? 0 : cumulative[out - 1]);
          out_vld <= 1'b0;
        end
      end
      UPDATE_STATE: begin
        // Determine the next state to jump to.
        if (decoder_state < max_cumulative) begin
          next_state <= READ_VALUE;
          in_rdy <= 1'b1;
        end else begin
          next_state <= WRITE_VALUE;
        end
      end
      READ_VALUE: begin
        // Read a new symbol.
        if (!in_vld && !in_rdy) begin
          // Done reading symbol, re-evaluate state.
          next_state <= UPDATE_STATE;
        end else if (in_vld && in_rdy) begin
          decoder_state <= (decoder_state << `SYM_WIDTH) + in;
          in_rdy <= 1'b0;
        end
      end
    endcase
  end
end

endmodule
