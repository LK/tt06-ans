# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: MIT

import sys
from random import randint

sys.path.append("..")

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

import model.ans as ans


def setup_model(data):
    model = ans.AnsHardware(alphabet_size=16, shift=4)
    for symbol in set(data):
        model.load_count(symbol, data.count(symbol))
    return model


@cocotb.test()
async def test_encoder_reset(dut):

    dut._log.info("Start")
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    # Setup the data model
    data_in = [x for x in range(16)]
    model = setup_model(data_in)
    counts = [data_in.count(x) for x in range(16)]

    # Reset model
    model.reset()

    # Reset hardware
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.rst_n.value = 0
    dut.in_reg.value = 0
    dut.in_vld.value = 0
    dut.out_rdy.value = 0
    for i in range(16):
        dut.counts[i].value = counts[i]
        dut.cumulative[i].value = sum(counts[:i + 1])
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    assert dut.encoder.state_reg.value == 0
    assert dut.encoder.in_rdy == 1
    assert dut.encoder.out_vld == 0
    assert dut.encoder.out == 0

    await ClockCycles(dut.clk, 2)

    assert dut.encoder.state_reg.value == model.state

@cocotb.test()
async def test_encoder_state(dut):
    dut._log.info("Start")
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    # Setup the data model
    data_in = [randint(0, 15) for x in range(16)]
    model = setup_model(data_in)
    counts = [data_in.count(x) for x in range(16)]

    # Reset model
    model.reset()
    await test_encoder_reset(dut)

    # Load counts/cumulative counts
    for i in range(16):
        dut.counts[i].value = counts[i]
        dut.cumulative[i].value = sum(counts[:i + 1])
    
    await ClockCycles(dut.clk, 10)

    for symbol in data_in:
        print(symbol)
        assert dut.in_rdy.value == 1

        dut.in_reg.value = symbol

        dut.in_vld.value = 1
        await ClockCycles(dut.clk, 10)

        while dut.out_vld.value:
            output = model.encode(symbol)
            assert dut.out_reg.value == output
            dut.out_rdy.value = 1
            await ClockCycles(dut.clk, 2)
            assert dut.out_vld.value == 0
            dut.out_rdy.value = 0
            await ClockCycles(dut.clk, 2)
        
        dut.in_vld.value = 0
        await ClockCycles(dut.clk, 10)
        
        output = model.encode(symbol)
        assert output == None

        assert dut.encoder.state_reg.value == model.state
    
    out_state = 0
    dut.ena.value = 0
    dut.out_rdy.value = 0

    for i in range(4):
        await ClockCycles(dut.clk, 2)
        assert dut.out_vld == 1
        out_state = dut.out_reg.value << (4 * i) | out_state
        dut.out_rdy.value = 1
        await ClockCycles(dut.clk, 2)
        assert dut.out_vld == 0
        dut.out_rdy.value = 0
    
    assert out_state == model.state
