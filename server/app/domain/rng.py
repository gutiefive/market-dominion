"""32-bit xorshift used for offline deals.

Assumption A16: both engines use this generator, not the language runtime RNG.

    state = seed & 0xFFFFFFFF
    if state == 0:
        state = 0x6D2B79F5
    x ^= (x << 13) & 0xFFFFFFFF
    x ^= x >> 17
    x ^= (x << 5) & 0xFFFFFFFF

``below(n)`` is ``next_u32() % n`` (modulo bias is accepted and shared).
"""

from __future__ import annotations

_MASK = 0xFFFFFFFF
_ZERO_STATE = 0x6D2B79F5


class MatchRng:
    def __init__(self, seed: int) -> None:
        if isinstance(seed, bool) or not isinstance(seed, int) or seed < 0:
            raise ValueError("seed")
        state = seed & _MASK
        self.state = state if state != 0 else _ZERO_STATE

    def next_u32(self) -> int:
        x = self.state
        x ^= (x << 13) & _MASK
        x &= _MASK
        x ^= x >> 17
        x &= _MASK
        x ^= (x << 5) & _MASK
        x &= _MASK
        self.state = x
        return x

    def below(self, exclusive_end: int) -> int:
        if isinstance(exclusive_end, bool) or not isinstance(exclusive_end, int):
            raise TypeError("exclusive_end must be an int")
        if exclusive_end <= 0:
            raise ValueError("exclusive_end must be positive")
        return self.next_u32() % exclusive_end


def shuffle(items: list, rng: MatchRng) -> list:
    """Fisher-Yates. ``j`` is drawn from ``0 .. i`` inclusive."""
    out = list(items)
    for index in range(len(out) - 1, 0, -1):
        swap = rng.below(index + 1)
        out[index], out[swap] = out[swap], out[index]
    return out
