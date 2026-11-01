"""Integer share and BYTE prices.

Assumption A2: nearest-step half-up rounding uses integer division
``(numerator + unit // 2) // unit * step`` where ``unit = 100 * step``.
No floating-point money.

Assumption A3: a size of 0 is an inactive chain and prices at 0.
``share_price`` rejects sentiment outside the posted range instead of clamping.

Assumption A4: a BYTE prior must already be a multiple of the money step and
inside the posted clamp. The result is rounded, then clamped.
"""

from __future__ import annotations

from app.files import load_rules


def _as_int(name: str, value: object) -> int:
    if isinstance(value, bool) or not isinstance(value, int):
        raise TypeError(f"{name} must be an int")
    return value


def round_ratio_half_up(numerator: int, divisor: int, step: int) -> int:
    """Round ``numerator / divisor`` to the nearest ``step``, half up."""
    numerator = _as_int("numerator", numerator)
    divisor = _as_int("divisor", divisor)
    step = _as_int("step", step)
    if numerator < 0 or divisor <= 0 or step <= 0:
        raise ValueError("rounding inputs must be non-negative and divisors positive")
    unit = divisor * step
    rounded_steps = (numerator + unit // 2) // unit
    return rounded_steps * step


def share_price(size: int, sentiment: int) -> int:
    """Active-company share price in fictional dollars, or 0 when size is 0."""
    rules = load_rules()
    size = _as_int("size", size)
    sentiment = _as_int("sentiment", sentiment)
    if size < 0:
        raise ValueError("size must be >= 0")
    if size == 0:
        return 0
    low = int(rules["sentiment_min"])
    high = int(rules["sentiment_max"])
    if sentiment < low or sentiment > high:
        raise ValueError("sentiment is outside the posted range")
    base = int(rules["share_price_base_offset"]) + int(rules["share_price_per_tile"]) * size
    multiplier = 100 + 10 * sentiment
    return round_ratio_half_up(base * multiplier, 100, int(rules["money_step"]))


def byte_price_after_delta(prior: int, delta_percent: int) -> int:
    """Apply one BYTE percent delta, round to the money step, then clamp."""
    rules = load_rules()
    prior = _as_int("prior", prior)
    delta_percent = _as_int("delta_percent", delta_percent)
    step = int(rules["money_step"])
    low = int(rules["byte_price_min"])
    high = int(rules["byte_price_max"])
    if prior < low or prior > high:
        raise ValueError("prior BYTE price is outside the posted range")
    if prior % step != 0:
        raise ValueError("prior BYTE price must be a multiple of the money step")
    factor = 100 + delta_percent
    if factor <= 0:
        raise ValueError("BYTE delta must leave a positive multiplier")
    raw = round_ratio_half_up(prior * factor, 100, step)
    return max(low, min(high, raw))
