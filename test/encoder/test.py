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

    # Reset model
    model.reset()

    # Reset hardware
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.rst_n.value = 0
    dut.total_count.value = model.total_count
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    assert dut.encoder.state_reg.value == model.state
    assert dut.encoder.in_rdy == 1
    assert dut.encoder.out_vld == 0
    assert dut.encoder.out == 0


@cocotb.test()
async def test_encoder_state(dut):
    dut._log.info("Start")
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    # Setup the data model
    data_in = [randint(0, 15) for x in range(16)]
    model = setup_model(data_in)

    # Reset model
    model.reset()
    await test_encoder_reset(dut)

    for symbol in data_in:
        output = model.encode(symbol)

        dut.s_count.value = model.counts[symbol]
        dut.s_cumulative.value = model.cumulative[symbol]
        dut.total_count.value = model.total_count

        dut.in_vld.value = 1
        await ClockCycles(dut.clk, 2)
        dut.in_vld.value = 0
        await ClockCycles(dut.clk, 1)

        if dut.out_vld.value:
            dut.out_rdy.value = 1
            await ClockCycles(dut.clk, 2)
            assert dut.out_vld.value == 0
            assert dut.out_reg.value == output
        else:
            assert output == None

        assert dut.encoder.state_reg.value == model.state
