module ans_encoder (

    input wire [`CNT_WIDTH-1:0] s_count,
    input wire [`STATE_WIDTH-1:0] s_cumulative,
    input wire [`STATE_WIDTH-1:0] total_count,
    input  wire in_vld,
    output reg  in_rdy,

    output reg  [`SYM_WIDTH-1:0] out,
    output reg  out_vld,
    input  wire out_rdy,

    input wire clk,
    input wire ena,
    input wire rst_n
);

  reg [`STATE_WIDTH-1:0] state_reg;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset all signals.
      state_reg <= total_count + 1;
      out_vld <= 1'b0;
      in_rdy <= 1'b1;
      out <= 0;
    end else if (ena && in_vld && in_rdy) begin

      if (state_reg >= ((1 << `SYM_WIDTH) * s_count)) begin
        out <= state_reg[`SYM_WIDTH-1:0];
        state_reg <= (state_reg >> 4);
        in_rdy <= 1'b0;
        out_vld <= 1'b1;
      end else begin
        state_reg = ((state_reg / s_count) * total_count) + s_cumulative + (state_reg % s_count);
        in_rdy <= 1'b1;
        out_vld <= 1'b0;
      end
      
    end else if (ena && out_vld && out_rdy) begin
      // Output data has been read, go back to reading an input.
      out_vld <= 1'b0;
      in_rdy  <= 1'b1;
    end
  end

endmodule
