"""Pre-deal lobby snapshot.

Assumption A7: this builder only emits phase ``lobby``. No tiles are dealt,
so all 81 coordinates are still in the bag. Assumption A12: seed 7710 is only
the id of the committed sample fixture.
"""

from __future__ import annotations

from typing import Any

from app.domain.coordinates import all_coordinates
from app.domain.corporations import load_corporations
from app.domain.events import load_round_events, sectors
from app.files import load_rules


def build_lobby_snapshot(match_id: str, seed: int) -> dict[str, Any]:
    if not isinstance(match_id, str) or not match_id:
        raise ValueError("match_id is required")
    if isinstance(seed, bool) or not isinstance(seed, int) or seed < 0:
        raise ValueError("seed must be a non-negative int")
    rules = load_rules()
    corporations = []
    for corporation in load_corporations():
        corporations.append(
            {
                "id": corporation["id"],
                "name": corporation["name"],
                "sector": corporation["sector"],
                "active": False,
                "size": 0,
                "cells": [],
                "total_shares": int(rules["corporation_share_supply"]),
                "bank_shares": int(rules["corporation_share_supply"]),
                "share_price": 0,
            }
        )
    return {
        "match_id": match_id,
        "version": 0,
        "seed": seed,
        "phase": "lobby",
        "active_player_id": None,
        "turn_index": 0,
        "round_number": 0,
        "final_round_flag": False,
        "board": [
            {"coordinate": coordinate, "occupied": False, "company_id": None}
            for coordinate in all_coordinates()
        ],
        "tile_bag_count": int(rules["tile_count"]),
        "players": [],
        "corporations": corporations,
        "crypto_market": {
            "symbol": rules["byte_symbol"],
            "price": int(rules["byte_initial_price"]),
            "exchange_coin_count": int(rules["byte_supply"]),
            "supply": int(rules["byte_supply"]),
        },
        "sector_sentiment": {sector: 0 for sector in sectors()},
        "events_remaining": len(load_round_events()),
        "action_log": [],
    }
