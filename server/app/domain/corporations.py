"""Load the five v1 corporations from the shared fixture."""

from __future__ import annotations

from typing import Any

from app.domain.events import sectors
from app.files import load_json, load_rules


def load_corporations() -> list[dict[str, Any]]:
    raw = load_json("fixtures/corporations.json")["corporations"]
    if not isinstance(raw, list):
        raise TypeError("corporations must be a list")
    rules = load_rules()
    supply = int(rules["corporation_share_supply"])
    known_sectors = set(sectors())
    seen: set[str] = set()
    for corporation in raw:
        corp_id = str(corporation["id"])
        if corp_id in seen:
            raise ValueError(f"duplicate corporation id: {corp_id}")
        seen.add(corp_id)
        if not str(corporation["name"]).strip():
            raise ValueError(f"corporation {corp_id} needs a name")
        if corporation["sector"] not in known_sectors:
            raise ValueError(f"corporation {corp_id} has an unknown sector")
        if int(corporation["total_shares"]) != supply:
            raise ValueError(f"corporation {corp_id} must start with {supply} shares")
    return raw
