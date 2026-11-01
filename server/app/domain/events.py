"""Sector-sentiment updates and the unshuffled event deck.

Assumption A14: the fixture order is the unshuffled deck. Each listed sector
is clamped on its own after the delta is added. A match shuffles that deck
with its own generator after the opening deal (assumption A20).
"""

from __future__ import annotations

from typing import Any

from app.files import load_json, load_rules


def sectors() -> list[str]:
    return [str(sector) for sector in load_rules()["sectors"]]


def load_round_events() -> list[dict[str, Any]]:
    raw = load_json("fixtures/round_events.json")
    events = raw["events"]
    if not isinstance(events, list) or not events:
        raise ValueError("round event deck is empty")
    known = set(sectors())
    seen: set[str] = set()
    for event in events:
        event_id = str(event["id"])
        if event_id in seen:
            raise ValueError(f"duplicate event id: {event_id}")
        seen.add(event_id)
        if not str(event["name"]).strip():
            raise ValueError(f"event {event_id} needs a name")
        deltas = event["sector_deltas"]
        if not isinstance(deltas, dict) or not deltas:
            raise ValueError(f"event {event_id} needs sector deltas")
        for sector, delta in deltas.items():
            if sector not in known:
                raise ValueError(f"event {event_id} uses unknown sector {sector}")
            if isinstance(delta, bool) or not isinstance(delta, int):
                raise ValueError(f"event {event_id} delta must be an int")
        if isinstance(event["byte_delta_percent"], bool) or not isinstance(
            event["byte_delta_percent"], int
        ):
            raise ValueError(f"event {event_id} BYTE delta must be an int")
    return events


def clamp_sentiment(value: int) -> int:
    if isinstance(value, bool) or not isinstance(value, int):
        raise TypeError("sentiment must be an int")
    rules = load_rules()
    return max(int(rules["sentiment_min"]), min(int(rules["sentiment_max"]), value))


def neutral_sentiment() -> dict[str, int]:
    return {sector: 0 for sector in sectors()}


def apply_sector_deltas(
    sentiment: dict[str, int], deltas: dict[str, int]
) -> dict[str, int]:
    """Return a new sentiment map. Unknown or missing sectors are rejected."""
    expected = sectors()
    if set(sentiment) != set(expected):
        raise ValueError("sentiment must contain exactly the v1 sectors")
    current = {}
    for sector in expected:
        value = sentiment[sector]
        if isinstance(value, bool) or not isinstance(value, int):
            raise TypeError(f"{sector} sentiment must be an int")
        current[sector] = value
    for sector, delta in deltas.items():
        if sector not in current:
            raise ValueError(f"unknown sector: {sector}")
        if isinstance(delta, bool) or not isinstance(delta, int):
            raise TypeError(f"{sector} delta must be an int")
        current[sector] = clamp_sentiment(current[sector] + delta)
    return current
