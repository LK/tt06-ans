![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg)

# Hardware Accelerated Asymmetric Numeral System (ANS) Encoder / Decoder

Implement a hardware efficient ANS (https://arxiv.org/abs/1311.2540) encoder / decoder block in verilog. 

This can be used as part of a larger system, to losslessly compress neural network weights on the fly in RAM constrained environments

# How it works

# Loader 

The `loader.v` module is designed to interface with external memory or data sources to load the necessary symbol counts, cumulative symbol counts, and total counts required by the ANS encoder and decoder modules. It acts as a bridge between the raw data storage and the encoding/decoding processes, ensuring that data is correctly formatted and available when needed.

### Functionality

The loader module operates by fetching data from a specified memory address or input stream and parsing it into the format required by the encoder/decoder. This includes separating the symbol counts, cumulative symbol counts, and total counts, and presenting them to the encoder/decoder modules in a synchronized manner.

### Inputs and Outputs

- **Input Signals:**
  - `data_in`: The raw input data stream or memory content.
  - `clk`: The system clock signal.
  - `rst_n`: The asynchronous reset signal, active low.
  - `load_ena`: Enable signal to start the loading process.

- **Output Signals:**
  - `s_count_out`: The parsed symbol counts ready to be used by the encoder/decoder.
  - `s_cumulative_out`: The parsed cumulative symbol counts ready to be used by the encoder/decoder.
  - `total_count_out`: The parsed total count ready to be used by the encoder/decoder.
  - `data_ready`: Signal indicating that the data is parsed and ready for the encoder/decoder.

### Operation

Upon reset (`rst_n` low), the loader module initializes its internal state and output signals to their default values. When the `load_ena` signal is asserted, the module starts parsing the input data (`data_in`) according to the expected format. Once the parsing is complete, the `data_ready` signal is asserted, indicating that the symbol counts, cumulative symbol counts, and total counts are available for the encoder/decoder modules.

The loader module ensures that data is available in a timely manner, minimizing idle times for the encoder/decoder and improving the overall efficiency of the ANS encoding/decoding process.

### Implementation Notes

The specific implementation details of the `loader.v` module, such as the memory interface and parsing logic, depend on the system architecture and the format of the input data. It is designed to be flexible and configurable to accommodate different data sources and encoding/decoding requirements.


## Encoder

The ANS encoder module operates based on a set of input signals and parameters to perform encoding operations. The module takes in symbol counts (`s_count`), cumulative symbol counts (`s_cumulative`), and a total count (`total_count`) as inputs, along with a valid input signal (`in_vld`), clock signal (`clk`), enable signal (`ena`), and reset signal (`rst_n`). The encoder outputs the encoded symbol (`out`), an output valid signal (`out_vld`), and an input ready signal (`in_rdy`).

Upon reset (`rst_n` low), the module initializes its internal state register (`state_reg`), output valid signal (`out_vld`), input ready signal (`in_rdy`), and state output count to their default values. When enabled (`ena` high) and the state register is zero, the state register is loaded with the `total_count` plus one.

During operation, if the input is valid (`in_vld` high) and the module is ready to accept new input (`in_rdy` high), the module checks if the current state requires output generation or state update. If the conditions for output generation are met (state register value is sufficient, or output is ready and not currently valid), the module generates an output symbol from the current state, updates the state register, and sets the output valid signal. If the output is valid and the receiver is ready (`out_rdy` high), the output valid signal is cleared, indicating the module is ready for the next operation.

If the conditions for state update are met, the module updates the state register based on the current symbol count, total count, and cumulative symbol count, and clears the input ready signal to indicate it's processing the current input.

When not enabled (`ena` low), but with a non-zero state or state output count, the module prepares to generate output if not already doing so. If enabled again, it resumes accepting input and processing.

This module efficiently encodes symbols based on the ANS encoding scheme, making it suitable for hardware implementations requiring high throughput and low latency in data compression tasks.


## Decoder

The ANS decoder module operates inversely to the encoder, taking encoded symbols as input and reconstructing the original symbols. It requires inputs such as the encoded symbol (`in`), a valid input signal (`in_vld`), clock signal (`clk`), enable signal (`ena`), and reset signal (`rst_n`). The decoder outputs the original symbol (`out`), an output valid signal (`out_vld`), and an input ready signal (`in_rdy`).

Upon reset (`rst_n` low), the decoder initializes its internal state register (`state_reg`), output valid signal (`out_vld`), and input ready signal (`in_rdy`) to their default values. When enabled (`ena` high) and the state register is zero, the state register is loaded with an initial value based on the encoded input.

During operation, if the input is valid (`in_vld` high) and the decoder is ready to accept new input (`in_rdy` high), the decoder processes the encoded symbol to reconstruct the original symbol. This involves updating the state register based on the encoded input and the known symbol counts and cumulative symbol counts. Once a symbol is reconstructed, it is outputted (`out`), and the output valid signal (`out_vld`) is set.

If the output is valid and the receiver is ready (`out_rdy` high), the output valid signal is cleared, indicating the decoder is ready for the next operation. The decoder continues to process incoming encoded symbols, updating its state and outputting original symbols until all encoded data has been processed.

When not enabled (`ena` low), the decoder maintains its current state, ready to resume operation once enabled again. This ensures that the decoding process can be paused and resumed without loss of data or state, allowing for flexible control in a larger system.

The ANS decoder module efficiently reconstructs original symbols from encoded data, making it an essential counterpart to the encoder in hardware implementations of the ANS encoding scheme. Its ability to operate with high throughput and low latency makes it suitable for applications requiring real-time data decompression.

