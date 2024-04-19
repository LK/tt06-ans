module ans_encoder (

    input wire [`CNT_WIDTH-1:0] s_count,
    input wire [`SYM_WIDTH+`CNT_WIDTH-1:0] s_cumulative,
    input wire [`SYM_WIDTH+`CNT_WIDTH-1:0] total_count,
    input wire in_vld,
    output reg in_rdy,

    output reg [`SYM_WIDTH-1:0] out,
    output reg out_vld,
    input wire out_rdy,

    input wire clk,
    input wire ena,
    input wire rst_n
);

  reg [`STATE_WIDTH-1:0] state_reg;
  reg [2:0] state_output_count;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset: set all signals to known values.
      state_reg <= 0;
      out_vld <= 1'b0;
      in_rdy <= 1'b1;
      state_output_count <= 0;
      out <= 0;
    end else if (ena && state_reg == 0) begin
      // Initializaition: set state to M + 1. 
      state_reg <= total_count + 1;
    end else if (ena && in_vld && in_rdy) begin
      // Processing: operate on the inputs
      if (state_reg >= ((1 << `SYM_WIDTH) * s_count)) begin
        // Normalization: normalize the state and output the data.
        out <= state_reg[`SYM_WIDTH-1:0];
        state_reg <= (state_reg >> `SYM_WIDTH);
        in_rdy <= 1'b0;
        out_vld <= 1'b1;
      end else begin
        // Encoding: consume the input signal, request a new one.
        state_reg <= ((state_reg / s_count) * total_count) + s_cumulative + (state_reg % s_count);
        in_rdy  <= 1'b1;
        out_vld <= 1'b0;
      end
    end else if (ena && out_vld && out_rdy) begin
      // Output data has been read, go back to reading an input.
      out_vld <= 1'b0;
      in_rdy  <= 1'b1;
    end else if (!ena && (state_reg > 0 || state_output_count > 0)) begin
      // Shift: ENA is low, bitshift out the state.
      in_rdy <= 0;
      if (!out_vld && !out_rdy) begin
        out <= state_reg[`SYM_WIDTH-1:0];
        state_reg <= (state_reg >> `SYM_WIDTH);
        out_vld <= 1'b1;
        state_output_count <= state_output_count + 1;
      end else if (out_vld && out_rdy) begin
        out_vld <= 1'b0;
      end
    end else if (!ena) begin
      // Disable: ENA is low and state shifting is done
      out_vld <= 0;
      state_output_count <= 0;
    end
  end

endmodule
