module ans_encoder (
    input wire [`CNT_WIDTH-1:0] s_count,
    input wire [`SYM_WIDTH + `CNT_WIDTH - 1:0] s_cumulative,
    input wire [`STATE_WIDTH-1:0] total_count,
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

  reg [1:0] state;
  localparam IDLE = 2'b00, PROCESS = 2'b01, OUTPUT = 2'b10, WAIT_FOR_READ = 2'b11;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset all signals and go to IDLE state.
      state_reg <= total_count + 1;
      out_vld <= 1'b0;
      in_rdy <= 1'b1;
      out <= 0;
      state <= IDLE;
    end else if (ena) begin
      case (state)
        IDLE: begin
          if (in_vld && in_rdy) begin
            state <= PROCESS;
          end
        end
        PROCESS: begin
          if (state_reg >= ((1 << `SYM_WIDTH) * s_count)) begin
            out <= state_reg[`SYM_WIDTH-1:0];
            state_reg <= (state_reg >> `SYM_WIDTH);
            in_rdy <= 1'b0;
            out_vld <= 1'b1;
            state <= OUTPUT;
          end else begin
            state_reg <= (s_count * total_count) + s_cumulative; // ((state_reg / s_count) * total_count) + s_cumulative + (state_reg % s_count);
            in_rdy <= 1'b1;
            out_vld <= 1'b0;
            state <= IDLE;
          end
        end
        OUTPUT: begin
          if (out_vld && out_rdy) begin
            // Output data has been read, prepare to go back to reading an input.
            out_vld <= 1'b0;
            in_rdy  <= 1'b1;
            state   <= WAIT_FOR_READ;
          end
        end
        WAIT_FOR_READ: begin
          // Wait for the next input to be ready.
          if (in_vld) begin
            state <= PROCESS;
          end else begin
            state <= IDLE;
          end
        end
        default: state <= IDLE;
      endcase
    end
  end
endmodule
