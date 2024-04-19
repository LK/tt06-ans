<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

ANS is a lossless compression algorithm. It works by exploiting the fact that
most data is not uniformly distributed; in English, the letter 'e' appears more
frequently than the letter 'x', so we can use fewer bits to encode an 'e' and
more bits to encode an 'x'.

### Data Interfaces
The chip has two data interfaces: `in` (`ui[3:0]`) and `out` (`uo[3:0]`). Each
interface follows a two-pin handshake protocol, described below.

### Input Interface

The input interface consists of:

 * `in`: The input data to read.
 * `in_rdy`: An output pin that is pulled high when the chip is ready to read
   an input.
 * `in_vld`: An input pin that must be pulled high when the data on `in` is
   valid.

The protocol for writing data to the chip is:

1. Wait for `in_rdy` high.
2. Write 4-bit value into `in`.
3. Set `in_vld` high.
4. Wait for `in_rdy` low.
5. Set `in_vld` low.

**NOTE:** The protocol for interacting with the encoder is slightly different,
see details below.

### Output Interface

The output interface consists of:

 * `out`: The output data to read.
 * `out_vld`: An output pin that is pulled high when the chip is ready to write
   an output.
 * `out_rdy`: An input pin that must be pulled high when the data on `out` has
   been read.

The protocol for reading data from the chip is:

1. Wait for `out_vld` high.
2. Read 4-bit value from `out`.
3. Set `out_rdy` high.
4. Wait for `out_vld` low.
5. Set `out_rdy` low.

### Operating Modes
The ANS compressor has 4 modes, which are controlled by the `mode` pins
(`uio[1:0]`). The modes are defined below.

#### Idle mode (`0b00`)

This is the default mode of the chip. The chip must be in idle mode when you
bring it out of reset. When transitioning between modes, you must first
transition to the idle mode, and then to the target mode.

#### Configure mode (`0b11`)

Configuration mode allows you to program the symbol frequencies into memory.
Before doing any encoding or decoding, you must enter configure mode and load
the full symbol table into memory.

When you enter configure mode, the chip will request data on the input interface
to fill the symbol table. Because we have a 4-bit alphabet, you must write
exactly 16 symbol counts. The first value read will be the count of symbol 0,
then symbol 1, and so on. Each count is represented as a 4-bit unsigned integer.

The output interface is not used in configure mode.

When you have finished writing 16 values in configure mode, you must transition
back into idle mode.

#### Encoder mode (`0b01`)

Encoder mode is used to compress data. You must enter encoder mode from idle
mode, and you must first configure the symbol table in configure mode.

When you enter encoder mode, the chip will request inputs via the input
interface and write outputs to the output interface.

NOTE: In encoder mode only, the input and output handshakes are interleaved.
After you set `in_vld` high, the chip will not set `in_rdy` low until *after*
all necessary outputs have been generated.

When you are done writing the message, transition back to idle mode. The chip
will output 4 additional symbols over the output interface; you must receive all
of these symbols before entering another mode.

#### Decoder mode (`0b10`)

Decoder mode is used to decompress data. You must enter decoder mode from idle
mode, and you must first configure the symbol table in configure mode. The
symbol table used in decoder mode must match the one that was used to encode the
message.

Decoder mode will request symbols over the input interface and output decoded
symbols over the output interface. Unlike the encoder, the input and output
interface handshakes are independent.

NOTE: The decoder must receive the encoded message *in reverse order*, that is,
the last byte emitted by the encoder must be the first byte received by the
decoder. Additionally, the emitted symbols will be in reverse order as well, so
the first byte fed to the encoder will be the last byte emitted by the decoder.

## How to test

0. Compute the frequency table of your data. We use a 4-bit alphabet, so you'll
need to divide your data into nibbles before doing this computation, and you 
must scale your counts so that the maximum count no more than 15.
1. Set `mode` to `00`, and come out of reset.
2. Set `mode` to `11`, configure mode.
3. Use the input interface to load 16 symbol counts into memory.
4. Set `mode` to `00`.
5. Set `mode` to `01`, encoder mode.
6. For each symbol in your message:
    * Write the symbol on the input interface.
    * During the `in_vld && in_rdy` phase of the input handshake, read any bytes
      that are written to the output interface.
7. Set `mode` to `00`.
8. Read the last 4 bytes of the message from the output interface.
9. Set `mode` to `10`, decoder mode.
10. Use the input interface to write the bytes emitted by the encoder **in reverse order**,
    and capture the output symbols from the output interface.
11. Reverse the symbols read from the output interface; they should match the
    message encoded in step (6).

## External hardware

None
