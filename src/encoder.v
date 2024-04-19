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
      // Reset all signals.
      state_reg <= 0;
      out_vld <= 1'b0;
      in_rdy <= 1'b1;
      state_output_count <= 0;
      out <= 0;
    end else if (ena && state_reg == 0) begin
      state_reg <= total_count + 1;
    end else if (ena && in_vld && in_rdy) begin
      if (state_reg >= ((1 << `SYM_WIDTH) * s_count) || out_rdy || out_vld) begin
        if (!out_vld && !out_rdy) begin
          out <= state_reg[`SYM_WIDTH-1:0];
          state_reg <= (state_reg >> `SYM_WIDTH);
          out_vld <= 1'b1;
        end else if (out_vld && out_rdy) begin
          out_vld <= 1'b0;
        end
      end else begin
        state_reg <= ((state_reg / s_count) * total_count) + s_cumulative + (state_reg % s_count);
        in_rdy  <= 1'b0;
      end
    end else if (ena && !in_rdy && !in_vld) begin
      in_rdy  <= 1'b1;
    end else if (!ena && (state_reg > 0 || state_output_count > 0)) begin
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
      out_vld <= 0;
      state_output_count <= 0;
    end
  end

endmodule
