"""Experimental Dominion v1 arithmetic; not a playable engine or Classic dispatch."""
from __future__ import annotations

from app.domain.pricing import round_ratio_half_up
from app.files import load_json


def share_price(company_id: str, size: int, sentiment: int) -> int:
    """Quote by the written Dominion identity; unknown ids never use Classic pricing.

    The primitive covers sizes 0..81, including size 1 for arithmetic probes.
    Size 0 returns zero after validation; actual founding still requires size 2.
    All inputs are validated even for inactive companies.
    """
    if not isinstance(company_id, str):
        raise TypeError("company_id must be a string")
    for name, value in (("size", size), ("sentiment", sentiment)):
        if isinstance(value, bool) or not isinstance(value, int):
            raise TypeError(f"{name} must be an int")
    parameters = load_json("fixtures/dominion_v1/pricing.json")
    profile = next((item for item in parameters["companies"] if item["id"] == company_id), None)
    if profile is None:
        raise ValueError("unknown Dominion company")
    if not parameters["size_min"] <= size <= parameters["size_max"]:
        raise ValueError("company size is outside the board bounds")
    if not parameters["sentiment_min"] <= sentiment <= parameters["sentiment_max"]:
        raise ValueError("sentiment is outside the posted range")
    if size == 0:
        return 0
    base = parameters["base_offset"] + profile["growth"] * size
    multiplier = 100 + profile["sensitivity"] * sentiment
    return round_ratio_half_up(base * multiplier, 100, parameters["money_step"])
