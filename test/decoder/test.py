# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: MIT

import sys
from random import randint

sys.path.append("..")

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

import model.ans as ans

@cocotb.test()
async def test_decoder_reset(dut):
    dut._log.info("Start")
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    # Reset hardware
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.in_vld.value = 0
    dut.out_rdy.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    assert dut.decoder.current_state.value == 0b00
    assert dut.decoder.in_rdy == 1
    assert dut.decoder.out_vld == 0
    assert dut.decoder.out == 0


async def decoder_read_state(dut, state):
    assert dut.decoder.current_state.value == 0b0

    for i in range(4):
        assert dut.decoder.in_rdy == 1
        assert dut.decoder.out_vld == 0
        dut.in_reg.value = (state >> (4 * i)) & 0b1111
        dut.in_vld.value = 1

        await ClockCycles(dut.clk, 2)

        assert dut.decoder.in_rdy == 0
        dut.in_vld.value = 0

        await ClockCycles(dut.clk, 2)
    
    assert dut.decoder.in_rdy.value == 0
    
    await ClockCycles(dut.clk, 2)

    assert dut.decoder.current_state.value == 0b1
    assert dut.decoder.decoder_state.value == state

@cocotb.test()
async def test_decoder_read_state(dut):
    dut._log.info("Start")
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    await test_decoder_reset(dut)
    await decoder_read_state(dut, randint(0, 2**16 - 1))

@cocotb.test()
async def test_decoder_decode(dut):
    dut._log.info("Start")
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    lib = ans.AnsLibrary(alphabet_size=16, shift=4)
    data_in = bytes([randint(0, 15) for _ in range(16)])
    counts = [data_in.count(x) for x in range(16)]
    lib.set_counts(counts)
    state, bitstream = lib.encode_data(data_in)

    await test_decoder_reset(dut)

    # Load counts/cumulative counts
    count_unpacked = 0
    cumulative_unpacked = 0
    for i in range(16):
        count_unpacked += (counts[i]) << (4 * i)
        cumulative_unpacked += (sum(counts[:i + 1])) << (8 * i)

    dut.counts_unpacked.value = count_unpacked
    dut.cumulative_unpacked.value = cumulative_unpacked

    await decoder_read_state(dut, state)

    for i in range(16):
        assert dut.decoder.counts[i].value == counts[i]
        assert dut.decoder.cumulative[i].value == sum(counts[:i + 1])

    bitstream_model = list(bitstream)
    bitstream_hw = list(bitstream)
    output_model = []
    output_hw = []
    while bitstream_model or lib.hw.state > (lib.hw.total_count + 1):
        symbol = lib.hw.decode(bitstream_model)
        output_model.append(symbol)

        await ClockCycles(dut.clk, 25)
        
        assert dut.out_vld.value == 1
        assert dut.out_reg.value == symbol

        output_hw.append(dut.out_reg.value)

        dut.out_rdy.value = 1

        await ClockCycles(dut.clk, 2)

        assert dut.out_vld.value == 0
        dut.out_rdy.value = 0

        await ClockCycles(dut.clk, 10)

        while dut.decoder.in_rdy.value == 1:
            dut.in_reg.value = bitstream_hw.pop()
            dut.in_vld.value = 1

            await ClockCycles(dut.clk, 2)

            assert dut.decoder.in_rdy.value == 0
            dut.in_vld.value = 0

            await ClockCycles(dut.clk, 2)

        assert dut.decoder.decoder_state.value == lib.hw.state

    assert output_model == output_hw
