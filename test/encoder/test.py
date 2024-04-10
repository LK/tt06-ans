# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: MIT

import sys
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
    dut.total_count.value = model.M
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
    data_in = [x for x in range(16)]
    model = setup_model(data_in)
    
    # Reset model
    model.reset()
    await test_encoder_reset(dut)

    for symbol in data_in:
        
        output = model.encode(symbol)

        dut.s_count.value = model.counts[symbol]
        dut.s_cumulative.value = model.cumulative[symbol]
        dut.total_count.value = model.M
        
        dut.in_vld.value = 1
        await ClockCycles(dut.clk, 1)
        dut.in_vld.value = 0
        await ClockCycles(dut.clk, 1)

        if dut.out_vld.value:
            dut.out_rdy.value = 1
            await ClockCycles(dut.clk, 2)
            assert dut.out_vld.value == 0
            assert dut.out_reg.value == output

        assert dut.encoder.state_reg.value == model.state










# @cocotb.test()
# async def test_encode_reset(dut):
#     dut._log.info("Start")
#     model = ans.AnsHardware(alphabet_size=16, shift=4)
#     data_in = [x for x in range(16)]
#     data_out = []
#     for x in set(data_in):
#         model.load_count(x, data_in.count(x))

#     clock = Clock(dut.clk, 10, units="us")
#     cocotb.start_soon(clock.start())

#     # Reset
#     dut._log.info("Reset")
#     dut.ena.value = 1
#     dut.ui_in.value = 0
#     dut.uio_in.value = 0
#     dut.rst_n.value = 0
#     await ClockCycles(dut.clk, 10)
#     dut.rst_n.value = 1

#     model.reset_state()
#     state = model.state
#     state_reg = dut.user_project.ans_block.encoder.state_reg.value
#     assert state_reg == state

#     # Set the input values, wait one clock cycle, and check the output
#     dut._log.info("Test")
#     for d in data_in:
#         out = model.encode(d)

#         dut.ui_in.value = d
#         dut.uio_in.value = 0b0101  # mode = encode, in_vld = 1, out_rdy = 0
#         await ClockCycles(dut.clk, 10)

#         state_reg = dut.user_project.ans_block.encoder.state_reg.value
#         output_reg = dut.user_project.ans_block.encoder.out.value
#         # assert state_reg == (state)  # out_vld = 1
#         print(d, (int(state_reg), int(output_reg)), (model.state, out))

#         dut.uio_in.value = 0b1001 # mode = encode, in_vld = 0, out_rdy = 1
#         await ClockCycles(dut.clk, 2)
#         assert dut.uio_out[4] == 1 # in_rdy = 1
#         assert dut.uio_out[5] == 0 # out_vld = 0
       

#     assert data_in == data_out