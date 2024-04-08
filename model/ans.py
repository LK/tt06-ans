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


class AnsHardware:
    """Model a ANS hardware block with a memory mapped interface"""

    def __init__(self, alphabet_size=256, shift=8) -> None:
        self.state = 0
        self.l = 1
        self.M = 0

        self.counts = [0] * alphabet_size
        self.cumulative = [0] * (alphabet_size + 1)

        self.shift = shift

    def reset_state(self):
        self.state = self.l * self.M

    def update_count(self, symbol, count):
        self.M += count
        self.counts[symbol] = count
        for n in range(symbol, len(self.counts)):
            self.cumulative[n + 1] += count

    def set_counts(self, symbol_counts):
        for symbol, count in enumerate(symbol_counts):
            self.update_count(symbol, count)

    def c_rANS(self, symbol):
        s_count = self.counts[symbol]
        next_state = (
            (self.state // s_count) * self.M
            + self.cumulative[symbol]
            + (self.state % s_count)
        )
        return next_state

    def d_rANS(self, state):
        # The Cumulative frequency inverse function
        def cumul_inverse(y):
            for i, _s in enumerate(self.cumulative):
                if y < _s:
                    return i - 1

        slot = state % self.M  # compute the slot
        symbol = cumul_inverse(slot)  # decode the symbol
        self.state = (
            (state // self.M) * self.counts[symbol] + slot - self.cumulative[symbol]
        )
        return symbol

    def encode(self, symbol):
        bitstream = []
        mask = (1 << self.shift) - 1
        adjust = 1 << (self.shift - 1)

        while self.state >= (adjust * 2 * self.l * self.counts[symbol]):
            bitstream.append(self.state & mask)
            self.state = self.state >> self.shift

        self.state = self.c_rANS(symbol)
        return bitstream

    def decode(self, bitstream):

        s_decoded = self.d_rANS(self.state)

        while self.state < (self.l * self.M):
            bits = bitstream.pop()
            self.state = (self.state << self.shift) + bits

        return s_decoded


class AnsLibrary:
    """Models a processor interacting with a memory mapped ANS peripheral"""

    def __init__(self) -> None:
        self.hw = AnsHardware()

    def set_counts(self, symbol_counts: list):
        for symbol, count in enumerate(symbol_counts):
            self.hw.update_count(symbol, count)

    def encode_data(self, data: bytes) -> (int, bytes):
        output = []
        self.hw.reset_state()

        for symbol in data:
            bits = self.hw.encode(symbol)
            if bits:
                output.extend(bits)

        return self.hw.state, bytes(output)

    def decode_data(self, state: int, compressed: bytes) -> bytes:
        output = []
        self.hw.state = state
        bitstream = list(compressed)

        while bitstream or self.hw.state != (self.hw.l * self.hw.M):
            symbol = self.hw.decode(bitstream)
            output.append(symbol)

        return bytes(reversed(output))
