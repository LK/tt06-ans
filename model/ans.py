import numpy as np


def C_rANS(s, state, symbol_counts):
    total_counts = np.sum(symbol_counts)
    cumul_counts = np.insert(np.cumsum(symbol_counts), 0, 0)

    s_count = symbol_counts[s]
    next_state = (state // s_count) * total_counts + cumul_counts[s] + (state % s_count)
    return next_state


def D_rANS(state, symbol_counts):
    total_counts = np.sum(symbol_counts)
    cumul_counts = np.insert(np.cumsum(symbol_counts), 0, 0)

    # The Cumulative frequency inverse function
    def cumul_inverse(y):
        for i, _s in enumerate(cumul_counts):
            if y < _s:
                return i - 1

    slot = state % total_counts  # compute the slot
    s = cumul_inverse(slot)  # decode the symbol
    prev_state = (state // total_counts) * symbol_counts[s] + slot - cumul_counts[s]
    return s, prev_state


def Streaming_rANS_encoder(state, symbol, symbol_counts, range_factor, shift):
    bitstream = []
    mask = (1 << shift) - 1
    adjust = 1 << (shift - 1)

    while state >= (adjust * range_factor * symbol_counts[symbol]):
        bitstream.append(state & mask)
        state = state >> shift

    state = C_rANS(symbol, state, symbol_counts)

    return state, bitstream


def Streaming_rANS_decoder(state, bitstream, symbol_counts, range_factor, shift):
    total_counts = np.sum(symbol_counts)

    s_decoded, state = D_rANS(state, symbol_counts)

    while state < (range_factor * total_counts):
        bits = bitstream.pop()
        state = (state << shift) + bits

    return s_decoded, state


def encode(data: bytes):

    symbol_counts = [1, 2, 3, 4]
    M = np.sum(symbol_counts)
    l = 1

    state = l * M
    range_factor = 2 * l
    shift = 8

    output = []

    for symbol in data:
        state, bits = Streaming_rANS_encoder(
            state, symbol, symbol_counts, range_factor, shift
        )
        output.extend(bits)

    output.append(state)

    return output


def decode(compressed):

    symbol_counts = [1, 2, 3, 4]
    M = np.sum(symbol_counts)
    l = 1
    range_factor = l
    shift = 8

    state = compressed.pop()
    output = []

    while compressed or state != l * M:
        symbol, state = Streaming_rANS_decoder(
            state, compressed, symbol_counts, range_factor, shift
        )
        output.append(symbol)

    return list(reversed(output))
