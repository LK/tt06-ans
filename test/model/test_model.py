import pytest
from ans import C_rANS, D_rANS, Streaming_rANS_encoder, Streaming_rANS_decoder
import ans
import numpy as np
from random import randint


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
    data = [0, 1, 0, 2, 2, 0, 2, 1, 2]
    counts = [3, 3, 2]
    state, compressed = ans.rANS_encode(data, counts)

    assert state == 14
    assert compressed == [1, 1, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 1, 1, 1]


def test_Streaming_rANS_decoder():
    bitstream = [1, 1, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 1, 1, 1]
    counts = [3, 3, 2]
    state = 14
    data = ans.rANS_decode(state, counts, bitstream)
    assert data == [0, 1, 0, 2, 2, 0, 2, 1, 2]


def test_streaming_rANS():
    data = [randint(0, 255) for _ in range(1100)]

    counts = [0] * (max(data) + 1)
    for symbol in set(data):
        counts[symbol] = data.count(symbol)

    state, compressed = ans.rANS_encode(data, counts)
    decoded = ans.rANS_decode(state, counts, compressed)
    assert decoded == data


def test_streaming_rANS_4bit():
    data = [randint(0, 16) for _ in range(1100)]
    shift = 4

    counts = [0] * (max(data) + 1)
    for symbol in set(data):
        counts[symbol] = data.count(symbol)

    state, compressed = ans.rANS_encode(data, counts, shift)
    decoded = ans.rANS_decode(state, counts, compressed, shift)
    assert decoded == data


def test_hardware_ans_encoder():
    data = [0, 1, 0, 2, 2, 0, 2, 1, 2]
    counts = [3, 3, 2]

    ans_module = ans.AnsLibrary(alphabet_size=3, shift=1)
    ans_module.set_counts(counts)

    assert ans_module.hw.counts == counts
    assert ans_module.hw.cumulative == list(np.insert(np.cumsum(counts), 0, 0))

    state, compressed = ans_module.encode_data(data)

    assert state == 14
    assert compressed == bytes([1, 1, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 1, 1, 1])


def test_hardware_ans_decoder():
    bitstream = [1, 1, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 1, 1, 1]
    counts = [3, 3, 2]
    state = 14

    ans_module = ans.AnsLibrary(alphabet_size=3, shift=1)
    ans_module.set_counts(counts)

    data = ans.rANS_decode(state, counts, bitstream)

    assert data == [0, 1, 0, 2, 2, 0, 2, 1, 2]


def test_hardware_ans():
    data = bytes([3, 0, 1, 1, 2, 2, 2, 3, 3, 3, 3, 1, 1, 2, 3, 4, 1, 5, 122])
    counts = [0] * 256

    for i in set(data):
        counts[i] = data.count(i)

    ans_module = ans.AnsLibrary()
    ans_module.set_counts(counts)

    state, compressed = ans_module.encode_data(data)
    decoded = ans_module.decode_data(state, compressed)

    assert decoded == data, "Compression error"


def test_hardware_ans_4bit():
    data = bytes([3, 0, 1, 1, 2, 12, 2, 3, 3, 3, 3, 1, 1, 2, 3, 4, 1, 5, 15])

    counts = [0] * 16
    for i in set(data):
        counts[i] = data.count(i)

    ans_module = ans.AnsLibrary(alphabet_size=16, shift=4)
    ans_module.set_counts(counts)

    state, compressed = ans_module.encode_data(data)
    decoded = ans_module.decode_data(state, compressed)

    assert decoded == data, "Compression error"


def test_random_ans_4bit():
    data = bytes([randint(0, 15) for _ in range(1000)])

    counts = [0] * 16
    for i in set(data):
        counts[i] = data.count(i)

    ans_module = ans.AnsLibrary(alphabet_size=16, shift=4)
    ans_module.set_counts(counts)

    state, compressed = ans_module.encode_data(data)
    decoded = ans_module.decode_data(state, compressed)

    assert decoded == data, "Compression error"
