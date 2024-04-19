try:
    import numpy as np
except ImportError:
    import pip
    pip.main(['install', 'numpy'])
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


def Streaming_rANS_encoder(state, symbol, symbol_counts, shift):
    bitstream = []
    mask = (1 << shift) - 1
    adjust = 1 << (shift)

    while state >= (adjust * symbol_counts[symbol]):
        bitstream.append(state & mask)
        state = state >> shift

    state = C_rANS(symbol, state, symbol_counts)
    return state, bitstream


def Streaming_rANS_decoder(state, bitstream, symbol_counts, shift):
    total_counts = np.sum(symbol_counts)
    s_decoded, state = D_rANS(state, symbol_counts)

    while state < (total_counts):
        bits = bitstream.pop()
        state = (state << shift) + bits

    return s_decoded, state


def rANS_encode(data: list, counts: list, shift=1):
    state = sum(counts) + 1
    output = []

    for symbol in data:
        state, bitstream = Streaming_rANS_encoder(state, symbol, counts, shift)
        output.extend(bitstream)

    return state, output


def rANS_decode(state, counts, compressed, shift=1):
    output = []
    stop = sum(counts) + 1

    while compressed or state > stop:
        symbol, state = Streaming_rANS_decoder(state, compressed, counts, shift)
        output.append(symbol)

    return list(reversed(output))


class AnsHardware:
    """Model a ANS hardware block with a memory mapped interface"""

    def __init__(self, alphabet_size=256, shift=8) -> None:
        self.state = 0
        self.total_count = 0
        self.counts = [0] * alphabet_size
        self.cumulative = [0] * (alphabet_size + 1)
        self.shift = shift

    def reset(self):
        self.state = self.total_count + 1

    def load_count(self, symbol, count):
        self.total_count += count
        self.counts[symbol] = count
        for n in range(symbol, len(self.counts)):
            self.cumulative[n + 1] += count

    def c_rANS(self, state, symbol):
        s_count = self.counts[symbol]
        s_cumulative = self.cumulative[symbol]
        next_state = (
            (state // s_count) * self.total_count + s_cumulative + (state % s_count)
        )
        return next_state

    def d_rANS(self, state):
        # The Cumulative frequency inverse function
        def cumul_inverse(y):
            for i, _s in enumerate(self.cumulative):
                if y < _s:
                    return i - 1

        slot = state % self.total_count
        symbol = cumul_inverse(slot)

        self.state = (
            (state // self.total_count) * self.counts[symbol]
            + slot
            - self.cumulative[symbol]
        )
        return symbol

    def encode(self, symbol) -> int | None:
        mask = (1 << self.shift) - 1
        step = 1 << (self.shift)

        print('initial state', self.state)
        while self.state >= (step * self.counts[symbol]):
            output = self.state & mask
            self.state = self.state >> self.shift
            print('outputting', output)
            print('new state', self.state)
            return output

        print('updating for symbol', symbol)
        self.state = self.c_rANS(self.state, symbol)

        print('post-encode state', self.state)

        return None

    def decode(self, bitstream):
        s_decoded = self.d_rANS(self.state)

        while self.state < self.total_count:
            bits = bitstream.pop()
            self.state = (self.state << self.shift) + bits

        return s_decoded


class AnsLibrary:
    """Models a processor interacting with a memory mapped ANS peripheral"""

    def __init__(self, alphabet_size=256, shift=8) -> None:
        self.hw = AnsHardware(alphabet_size, shift)

    def set_counts(self, symbol_counts: list):
        for symbol, count in enumerate(symbol_counts):
            self.hw.load_count(symbol, count)

    def encode_data(self, data: bytes) -> (int, bytes):
        output = []
        self.hw.reset()

        for symbol in data:
            bits = []
            out = self.hw.encode(symbol)
            while out is not None:  # Valid signal
                bits.append(out)
                out = self.hw.encode(symbol)
            print(self.hw.state, bits)
            output.extend(bits)

        return self.hw.state, bytes(output)

    def decode_data(self, state: int, compressed: bytes) -> bytes:
        output = []
        self.hw.state = state
        bitstream = list(compressed)

        while bitstream or self.hw.state > (self.hw.total_count + 1):
            symbol = self.hw.decode(bitstream)
            output.append(symbol)

        return bytes(reversed(output))
