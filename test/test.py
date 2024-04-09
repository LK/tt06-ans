# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: MIT

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

@cocotb.test()
async def test_encode(dut):
  dut._log.info("Start")
  
  clock = Clock(dut.clk, 10, units="us")
  cocotb.start_soon(clock.start())

  # Reset
  dut._log.info("Reset")
  dut.ena.value = 1
  dut.ui_in.value = 0
  dut.uio_in.value = 0
  dut.rst_n.value = 0
  await ClockCycles(dut.clk, 10)
  dut.rst_n.value = 1

  # Set the input values, wait one clock cycle, and check the output
  dut._log.info("Test")

  data_in = [x for x in range(16)]
  data_out = []

  for d in data_in:
    dut.ui_in.value = d
    dut.uio_in.value = 0b0101 # mode = encode, in_vld = 1, out_rdy = 0
    await ClockCycles(dut.clk, 2)
    assert dut.uio_out[4] == 0 # in_rdy = 0
    assert dut.uio_out[5] == 1 # out_vld = 1
    data_out.append(dut.uo_out.value)
    dut.uio_in.value = 0b1001 # mode = encode, in_vld = 0, out_rdy = 1
    await ClockCycles(dut.clk, 2)
    assert dut.uio_out[4] == 1 # in_rdy = 1
    assert dut.uio_out[5] == 0 # out_vld = 0

  assert data_in == data_out

@cocotb.test()
async def test_load(dut):
  dut._log.info("Start")
  
  clock = Clock(dut.clk, 10, units="us")
  cocotb.start_soon(clock.start())

  # Reset
  dut._log.info("Reset")
  dut.ena.value = 1
  dut.ui_in.value = 0
  dut.uio_in.value = 0
  dut.rst_n.value = 0
  await ClockCycles(dut.clk, 10)
  dut.rst_n.value = 1

  # Set the input values, wait one clock cycle, and check the output
  dut._log.info("Test")

  state_in = [x for x in range(16)]

  dut.uio_in.value = 0b0011 # mode = load, in_vld = 0

  await ClockCycles(dut.clk, 1)

  for d in state_in:
    assert dut.uio_out[4] == 1 # in_rdy = 1
    dut.ui_in.value = d
    dut.uio_in.value = 0b0111 # mode = load, in_vld = 1
    await ClockCycles(dut.clk, 2)
    assert dut.uio_out[4] == 0 # in_rdy = 0
    dut.uio_in.value = 0b0011 # mode = load, in_vld = 0
    await ClockCycles(dut.clk, 2)

  # TODO(lenny): make this work for gate-level sims
  try:
    print('state', dut.user_project.ans_block.loader.counts_reg.value)
    assert [x.value for x in reversed(dut.user_project.ans_block.loader.counts_reg.value)] == state_in
  except AttributeError:
    pass
