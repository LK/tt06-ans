# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: MIT

import sys

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles
import model.ans as ans
from random import randint

async def load_counts(dut, state):
  dut.ans_cmd.value = 0b11
  dut.ans_in_vld.value = 0
  await ClockCycles(dut.clk, 1)
  for d in state:
    dut.ans_in.value = d
    dut.ans_in_vld.value = 1
    await ClockCycles(dut.clk, 2)
    assert dut.ans_in_rdy == 0
    dut.ans_in_vld.value = 0
    await ClockCycles(dut.clk, 2)

@cocotb.test()
async def test_load(dut):
  dut._log.info("Start")
  
  clock = Clock(dut.clk, 10, units="us")
  cocotb.start_soon(clock.start())

  # Reset
  dut._log.info("Reset")
  dut.ena.value = 1
  dut.ans_in.value = 0
  dut.ans_cmd.value = 0
  dut.ans_in_vld.value = 0
  dut.ans_out_rdy.value = 0
  dut.rst_n.value = 0
  await ClockCycles(dut.clk, 10)
  dut.rst_n.value = 1

  # Set the input values, wait one clock cycle, and check the output
  dut._log.info("Test")

  lib = ans.AnsLibrary(alphabet_size=16, shift=4)
  data_in = bytes([randint(0, 15) for _ in range(16)])
  counts = [data_in.count(x) for x in range(16)]
  lib.set_counts(counts)

  await load_counts(dut, counts)

  # TODO(lenny): make this work for gate-level sims
  try:
    print('state', dut.user_project.ans_block.loader.counts_reg.value)
    assert [x.value for x in reversed(dut.user_project.ans_block.loader.counts_reg.value)] == counts
  except AttributeError:
    pass

@cocotb.test()
async def test_e2e(dut):
  dut._log.info("Start")
  
  clock = Clock(dut.clk, 10, units="us")
  cocotb.start_soon(clock.start())

  # Reset
  dut._log.info("Reset")
  dut.ena.value = 1
  dut.ans_in.value = 0
  dut.ans_cmd.value = 0
  dut.ans_in_vld.value = 0
  dut.ans_out_rdy.value = 0
  dut.rst_n.value = 0
  await ClockCycles(dut.clk, 10)
  dut.rst_n.value = 1

  # Set the input values, wait one clock cycle, and check the output
  dut._log.info("Test")

  model = ans.AnsHardware(alphabet_size=16, shift=4)
  data_in = bytes([randint(0, 15) for _ in range(16)])
  counts = [data_in.count(x) for x in range(16)]
  for i in range(16):
    model.load_count(i, counts[i])
  
  model.reset()

  await load_counts(dut, counts)

  hw_out = []

  # idle
  dut.ans_cmd.value = 0b00
  await ClockCycles(dut.clk, 10)

  # encode
  dut.ans_cmd.value = 0b01
  await ClockCycles(dut.clk, 10)

  for symbol in data_in:
    print(symbol)
    assert dut.ans_in_rdy.value == 1

    dut.ans_in.value = symbol

    dut.ans_in_vld.value = 1
    await ClockCycles(dut.clk, 10)

    while dut.ans_out_vld.value:
      output = model.encode(symbol)
      assert dut.ans_out.value == output
      hw_out.append(dut.ans_out.value)
      dut.ans_out_rdy.value = 1
      await ClockCycles(dut.clk, 2)
      assert dut.ans_out_vld.value == 0
      dut.ans_out_rdy.value = 0
      await ClockCycles(dut.clk, 2)
    
    dut.ans_in_vld.value = 0
    await ClockCycles(dut.clk, 10)
    
    output = model.encode(symbol)
    assert output == None

    # assert dut.user_project.ans_block.encoder.state_reg.value == model.state
  
  # capture final state
  out_state = 0
  dut.ans_cmd.value = 0
  dut.ans_out_rdy.value = 0

  for i in range(4):
      await ClockCycles(dut.clk, 2)
      assert dut.ans_out_vld == 1
      out_state = dut.ans_out.value << (4 * i) | out_state
      hw_out.append(dut.ans_out.value)
      dut.ans_out_rdy.value = 1
      await ClockCycles(dut.clk, 2)
      assert dut.ans_out_vld == 0
      dut.ans_out_rdy.value = 0
  
  assert out_state == model.state

  # decode
  dut.ans_cmd.value = 0b10
  await ClockCycles(dut.clk, 10)

  for sym in reversed(hw_out[-4:]):
     assert dut.ans_in_rdy.value == 1
     dut.ans_in.value = sym
     dut.ans_in_vld.value = 1
     await ClockCycles(dut.clk, 2)
     assert dut.ans_in_rdy.value == 0
     dut.ans_in_vld.value = 0
     await ClockCycles(dut.clk, 2)
    
  # assert dut.user_project.ans_block.decoder.decoder_state.value == model.state

  model_bitstream = list(hw_out[:-4])
  hw_bitstream = list(hw_out[:-4])
  hw_decoded = []
  while len(hw_decoded) < len(data_in):
    model_symbol = model.decode(model_bitstream)

    await ClockCycles(dut.clk, 25)
    
    assert dut.ans_out_vld.value == 1
    assert dut.ans_out.value == model_symbol

    hw_decoded.append(dut.ans_out.value)

    dut.ans_out_rdy.value = 1

    await ClockCycles(dut.clk, 2)

    assert dut.ans_out_vld.value == 0
    dut.ans_out_rdy.value = 0

    await ClockCycles(dut.clk, 10)

    while dut.ans_in_rdy.value == 1:
        dut.ans_in.value = hw_bitstream.pop()
        dut.ans_in_vld.value = 1

        await ClockCycles(dut.clk, 2)

        assert dut.ans_in_rdy.value == 0
        dut.ans_in_vld.value = 0

        await ClockCycles(dut.clk, 2)

    # assert dut.user_project.ans_block.decoder.decoder_state.value == model.state
  
  assert list(hw_decoded) == list(reversed(data_in))



