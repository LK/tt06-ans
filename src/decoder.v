module ans_decoder (
  input wire [`SYM_WIDTH-1:0] in,
  output reg [`SYM_WIDTH-1:0] out,

  output reg [1:0] read_type,
  output reg [(`CNT_WIDTH + `SYM_WIDTH)-1:0] read_query,
  input wire [(`CNT_WIDTH + `SYM_WIDTH)-1:0] read_result,
  input wire read_rdy,

  input wire in_vld,
  output reg in_rdy,

  output reg out_vld,
  input wire out_rdy,

  input wire clk,
  input wire ena,
  input wire rst_n
);

// typedef enum reg [1:0] {
//     StateReadingState = 2'b00,
//     StateWritingValue = 2'b01,
//     StateUpdatingState = 2'b10,
//     StateReadingValue = 2'b11
// } state_t;

// state_t current_state, next_state;

// reg [(`CNT_WIDTH + `SYM_WIDTH)-1:0] max_cumulative;

// reg [`STATE_WIDTH-1:0] decoder_state;
// reg [`CNT_WIDTH-1:0] decoder_state_ptr;

// reg [`STATE_WIDTH-1:0] temp_decoder_state;
// reg [1:0] decoder_update_step;

// always @(posedge clk or negedge rst_n) begin
//   if (!rst_n) begin
//     // Reset all signals.
//     out_vld <= 1'b0;
//     in_rdy <= 1'b1;
//     out <= 0;
//     read_type <= 0;
//     read_query <= 0;
//     temp_decoder_state <= 0;
//     decoder_update_step <= 0;
//     decoder_state_ptr <= 0;
//     current_state <= StateReadingState;
//     next_state <= StateReadingState;
//     max_cumulative <= 0;
//   end else if (ena) begin
//     current_state <= next_state;

//     if (max_cumulative == 0 && !read_rdy) begin
//       read_type <= READ_TYPE_CMF;
//       read_query <= `SYM_COUNT - 1;
//     end else if (max_cumulative == 0 && read_rdy) begin
//       max_cumulative <= read_result;
//       read_type <= READ_TYPE_NONE;
//     end

//     case (current_state)
//       StateReadingState: begin
//         if (in_vld && in_rdy) begin
//           decoder_state[decoder_state_ptr * 4 +: 4] <= in;
//           decoder_state_ptr <= decoder_state_ptr + 1;
//           in_rdy <= 1'b0;
//         end else if (!in_vld && !in_rdy) begin
//           if (decoder_state_ptr == `STATE_WIDTH / 4) begin
//             next_state <= StateWritingValue;
//           end else begin
//             in_rdy <= 1'b1;
//           end
//         end
//       end
//       StateWritingValue: begin
//         if (max_cumulative > 0 && !out_vld && !out_rdy) begin
//           if (read_type == READ_TYPE_NONE) begin
//             read_type <= READ_TYPE_ICMF;
//             read_query <= decoder_state % max_cumulative;
//           end else if (read_rdy) begin
//             out <= read_result;
//             out_vld <= 1'b1;
//             read_type <= READ_TYPE_NONE;
//           end
//         end else if (out_vld && out_rdy) begin
//           next_state <= StateUpdatingState;
//           decoder_update_step <= 2'b00;
//           out_vld <= 1'b0;
//         end
//       end
//       StateUpdatingState: begin
//         if (decoder_update_step == 2'b00) begin
//           temp_decoder_state <= (decoder_state / max_cumulative);
//           decoder_update_step <= decoder_update_step + 1'b1;

//           read_type <= READ_TYPE_PMF;
//           read_query <= out;
//         end else if (decoder_update_step == 2'b01 && read_rdy) begin
//           temp_decoder_state <= temp_decoder_state * read_result;
//           decoder_update_step <= decoder_update_step + 1'b1;
//           read_type <= READ_TYPE_NONE;
//         end else if (decoder_update_step == 2'b10 && !read_rdy) begin
//           read_type <= READ_TYPE_CMF;
//           read_query <= out - 1;
//         end else if (decoder_update_step == 2'b10 && read_rdy) begin
//           if (out == 0) begin
//             temp_decoder_state <= temp_decoder_state + decoder_state % max_cumulative;
//           end else begin
//             temp_decoder_state <= temp_decoder_state + decoder_state % max_cumulative - read_result;
//           end
//           read_type <= READ_TYPE_NONE;
//           decoder_update_step <= decoder_update_step + 1'b1;
//         end else if (decoder_update_step == 2'b11) begin
//           decoder_state <= temp_decoder_state;

//           if (temp_decoder_state < max_cumulative) begin
//             next_state <= StateReadingValue;
//             in_rdy <= 1'b1;
//           end else begin
//             next_state <= StateWritingValue;
//           end
//         end
//       end
//       StateReadingValue: begin
//         if (!in_vld && !in_rdy) begin
//           next_state <= StateWritingValue;
//         end else if (in_vld && in_rdy) begin
//           decoder_state <= (decoder_state << `SYM_WIDTH) + in;
//           in_rdy <= 1'b0;
//         end
//       end
//     endcase
//   end
// end

endmodule
