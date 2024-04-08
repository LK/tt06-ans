import pytest
from ans import C_rANS, D_rANS, Streaming_rANS_encoder, Streaming_rANS_decoder
import ans
import numpy as np


def test_C_rANS():
    state = 123
    s = 2
    symbol_counts = [1, 2, 3, 4]
    expected_next_state = 413
    assert (
        C_rANS(s, state, symbol_counts) == expected_next_state
    ), "C_rANS function did not return the expected next state"


def test_D_rANS():
    state = 413
    symbol_counts = [1, 2, 3, 4]
    expected_output = (2, 123)
    assert (
        D_rANS(state, symbol_counts) == expected_output
    ), "D_rANS function did not return the expected symbol and previous state"


def test_Streaming_rANS_encoder():
    symbol_counts = [1, 2, 3, 4]
    M = np.sum(symbol_counts)
    l = 1

    state = l * M
    range_factor = l
    symbol = 0
    shift = 1

    expected_state = 10
    expected_bitstream = [0, 1, 0]

    assert Streaming_rANS_encoder(
        state, symbol, symbol_counts, range_factor, shift
    ) == (
        expected_state,
        expected_bitstream,
    ), "Streaming_rANS_encoder did not return the expected state and bitstream"


def test_Streaming_rANS_decoder():
    symbol_counts = [1, 2, 3, 4]
    M = np.sum(symbol_counts)
    l = 1

    state = 10
    bitstream = [0, 1, 0]
    range_factor = l
    shift = 1

    expected_symbol = 0
    expected_final_state = l * M

    assert Streaming_rANS_decoder(
        state, bitstream, symbol_counts, range_factor, shift
    ) == (
        expected_symbol,
        expected_final_state,
    ), "Streaming_rANS_decoder did not return the expected symbol and final state"


def test_hardware_ans():
    data = bytes([3, 0, 1, 1, 2, 2, 2, 3, 3, 3, 3, 1, 1, 2, 3, 4, 1, 5, 122])
    counts = [0] * 256

    for i in set(data):
        counts[i] = data.count(i)

    hw = ans.HardwareAns()
    hw.set_counts(counts)

    assert hw.decode(hw.encode(data)) == data, "Compression error"
