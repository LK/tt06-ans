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

    while state >= (adjust * 2 * range_factor * symbol_counts[symbol]):
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


class HardwareAns:

    def __init__(self, alphabet_size=256, shift=8) -> None:
        self.state = 0
        self.l = 1
        self.M = alphabet_size * 8
        self.counts = [1] * alphabet_size
        self.shift = shift

    def set_counts(self, symbol_counts):
        self.counts = symbol_counts
        self.M = sum(symbol_counts)

    def set_shift(self, shift):
        self.shift = shift

    def encode_symbol(self, symbol):
        self.state, bits = Streaming_rANS_encoder(
            state=self.state,
            symbol=symbol,
            symbol_counts=self.counts,
            range_factor=self.l,
            shift=self.shift,
        )
        return bits

    def decode_symbol(self, bitstream):
        symbol, self.state = Streaming_rANS_decoder(
            state=self.state,
            bitstream=bitstream,
            symbol_counts=self.counts,
            range_factor=self.l,
            shift=self.shift,
        )
        return symbol

    def encode(self, data: bytes):
        output = []
        self.state = self.l * self.M

        for symbol in data:
            bits = self.encode_symbol(symbol)
            output.extend(bits)

        output.append(self.state)
        return output

    def decode(self, compressed: bytes):
        output = []
        self.state = compressed.pop()

        while compressed or self.state != (self.l * self.M):
            symbol = self.decode_symbol(compressed)
            output.append(symbol)

        return bytes(reversed(output))

