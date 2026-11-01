"""Domain kernels covered by M0. These are not a playable match."""

from __future__ import annotations

import copy
import json
from pathlib import Path

import pytest

from app.domain.coordinates import all_coordinates
from app.domain.corporations import load_corporations
from app.domain.events import apply_sector_deltas, load_round_events, neutral_sentiment
from app.domain.invariants import public_state_errors
from app.domain.pricing import byte_price_after_delta, share_price
from app.domain.scoring import rank_players
from app.domain.setup import build_lobby_snapshot
from app.domain.tiles import conservation_errors
from app.files import load_json, load_rules, repo_root
from app.version import SERVER_VERSION

ROOT = repo_root()


def _cases(name: str) -> list[dict]:
    return load_json(f"fixtures/{name}")["cases"]


def test_rules_file_matches_the_spec():
    rules = load_rules()
    assert rules["protocol_version"] == SERVER_VERSION == "0.1.0"
    assert rules["currency"] == "fictional_dollars"
    assert rules["board_columns"] == 9
    assert rules["board_rows"] == 9
    assert rules["column_labels"] == "ABCDEFGHI"
    assert rules["tile_count"] == 81
    assert rules["players_min"] == 2
    assert rules["players_max"] == 4
    assert rules["starting_cash"] == 6000
    assert rules["starting_hand_size"] == 5
    assert rules["max_hand_size"] == 5
    assert rules["market_actions_per_turn"] == 2
    assert rules["corporation_share_supply"] == 20
    assert rules["byte_symbol"] == "BYTE"
    assert rules["byte_initial_price"] == 500
    assert rules["byte_supply"] == 30
    assert rules["byte_price_min"] == 100
    assert rules["byte_price_max"] == 2000
    assert rules["sentiment_min"] == -2
    assert rules["sentiment_max"] == 2
    assert rules["sectors"] == ["ai", "fintech", "energy", "media", "retail"]
    assert rules["share_price_base_offset"] == 100
    assert rules["share_price_per_tile"] == 50
    assert rules["money_step"] == 10
    assert rules["end_company_size"] == 22
    assert rules["end_occupied_tiles"] == 65
    assert rules["command_byte_limit"] == 16384
    assert rules["api_port"] == 8741


def test_coordinate_catalog_is_the_full_board():
    coordinates = all_coordinates()
    assert coordinates[0] == "A1"
    assert coordinates[1] == "B1"
    assert coordinates[8] == "I1"
    assert coordinates[9] == "A2"
    assert coordinates[80] == "I9"
    assert len(coordinates) == len(set(coordinates)) == 81
    fixture = load_json("fixtures/coordinates.json")
    assert fixture == coordinates


def test_corporations_match_the_v1_roster():
    corporations = load_corporations()
    assert [(item["id"], item["name"], item["sector"]) for item in corporations] == [
        ("nova_ai", "NOVA AI", "ai"),
        ("orbit_pay", "ORBIT PAY", "fintech"),
        ("volt_grid", "VOLT GRID", "energy"),
        ("pulse_media", "PULSE MEDIA", "media"),
        ("evermart", "EVERMART", "retail"),
    ]
    assert {item["total_shares"] for item in corporations} == {20}


def test_round_events_match_the_v1_table():
    events = load_round_events()
    assert [
        (event["id"], event["name"], event["sector_deltas"], event["byte_delta_percent"])
        for event in events
    ] == [
        ("ai_adoption", "AI Adoption", {"ai": 1}, 10),
        ("fintech_regulation", "Fintech Regulation", {"fintech": -1}, -20),
        ("grid_incentives", "Grid Incentives", {"energy": 1}, -10),
        ("media_boom", "Media Boom", {"media": 1}, 10),
        ("retail_slowdown", "Retail Slowdown", {"retail": -1}, -10),
        ("risk_on_rally", "Risk-On Rally", {"ai": 1, "fintech": 1}, 20),
        ("risk_off_shock", "Risk-Off Shock", {"ai": -1, "fintech": -1}, -20),
        ("consumer_recovery", "Consumer Recovery", {"retail": 1, "media": 1}, 10),
        ("energy_crunch", "Energy Crunch", {"energy": -1}, 10),
        (
            "liquidity_freeze",
            "Liquidity Freeze",
            {"ai": -1, "fintech": -1, "energy": -1, "media": -1, "retail": -1},
            -20,
        ),
    ]


def test_spec_share_price_examples():
    assert share_price(4, 0) == 300
    assert share_price(4, 2) == 360
    assert share_price(4, -2) == 240


def test_share_price_golden_file():
    for case in _cases("golden_prices.json"):
        assert share_price(case["size"], case["sentiment"]) == case["price"]


def test_share_price_rejects_illegal_inputs():
    assert share_price(0, 99) == 0
    with pytest.raises(ValueError):
        share_price(-1, 0)
    with pytest.raises(ValueError):
        share_price(1, 3)
    with pytest.raises(TypeError):
        share_price(True, 0)  # type: ignore[arg-type]


def test_spec_byte_example_and_golden_file():
    assert byte_price_after_delta(500, 20) == 600
    for case in _cases("golden_byte.json"):
        assert byte_price_after_delta(case["prior"], case["delta_percent"]) == case["price"]


def test_byte_price_rejects_illegal_inputs():
    with pytest.raises(ValueError):
        byte_price_after_delta(50, 10)
    with pytest.raises(ValueError):
        byte_price_after_delta(105, 10)
    with pytest.raises(ValueError):
        byte_price_after_delta(500, -100)


def test_sentiment_golden_file_and_clamp():
    start = {"ai": 2, "fintech": 0, "energy": 0, "media": 0, "retail": 0}
    assert apply_sector_deltas(start, {"ai": 1})["ai"] == 2
    for case in _cases("golden_sentiment.json"):
        assert apply_sector_deltas(case["start"], case["deltas"]) == case["result"]
    with pytest.raises(ValueError):
        apply_sector_deltas(neutral_sentiment(), {"space": 1})


def test_tile_conservation_partitions_and_reports_stable_errors():
    coordinates = all_coordinates()
    assert conservation_errors(coordinates, [], []) == []
    hands = [coordinates[:5], coordinates[5:10]]
    assert conservation_errors(coordinates[10:], hands, []) == []
    assert conservation_errors(coordinates + ["A1"], [], []) == ["count:82", "duplicate:A1"]
    removed = [coordinate for coordinate in coordinates if coordinate != "I9"]
    assert conservation_errors(removed, [], []) == ["count:80", "missing:I9"]
    swapped = ["Z9" if coordinate == "A1" else coordinate for coordinate in coordinates]
    assert conservation_errors(swapped, [], []) == ["missing:A1", "unknown:Z9"]


def test_winner_order_uses_the_spec_tie_breaks():
    earlier = rank_players(
        [
            {
                "id": "p_b",
                "net_worth": 8000,
                "cash": 2000,
                "active_shares": 4,
                "turn_order_index": 1,
            },
            {
                "id": "p_a",
                "net_worth": 8000,
                "cash": 2000,
                "active_shares": 4,
                "turn_order_index": 0,
            },
        ]
    )
    assert earlier == ["p_a", "p_b"]
    for case in _cases("golden_ranking.json"):
        assert rank_players(case["players"]) == case["order"]
    with pytest.raises(ValueError):
        rank_players([])
    with pytest.raises(ValueError):
        rank_players(
            [
                {"id": "a", "net_worth": 1, "cash": 0, "active_shares": 0, "turn_order_index": 0},
                {"id": "b", "net_worth": 2, "cash": 0, "active_shares": 0, "turn_order_index": 0},
            ]
        )


def test_lobby_snapshot_is_a_valid_predeal_state():
    snapshot = build_lobby_snapshot("match_demo", 7710)
    assert public_state_errors(snapshot) == []
    assert snapshot["phase"] == "lobby"
    assert snapshot["tile_bag_count"] == 81
    assert snapshot["players"] == []
    assert all(not cell["occupied"] for cell in snapshot["board"])
    committed = json.loads(
        (ROOT / "shared" / "fixtures" / "sample_lobby_state.json").read_text(encoding="utf-8")
    )
    assert committed == snapshot


def test_public_state_checker_rejects_tampering():
    snapshot = build_lobby_snapshot("match_demo", 7710)
    private = copy.deepcopy(snapshot)
    private["players"] = [
        {
            "id": "p1",
            "display_name": "Rowan",
            "connection_state": "connected",
            "cash": 6000,
            "holdings_by_corp": {},
            "byte_count": 0,
            "hand_count": 0,
            "is_ready": False,
            "turn_order_index": 0,
            "private_tile_hand": ["A1"],
        }
    ]
    assert public_state_errors(private)

    short_supply = copy.deepcopy(snapshot)
    short_supply["crypto_market"]["exchange_coin_count"] = 29
    assert "BYTE coins must sum to the fixed supply" in public_state_errors(short_supply)

    flagged = copy.deepcopy(snapshot)
    flagged["final_round_flag"] = True
    assert public_state_errors(flagged)

    active = copy.deepcopy(snapshot)
    active["corporations"][0]["active"] = True
    assert any("at least 2 cells" in error for error in public_state_errors(active))

    shifted = copy.deepcopy(snapshot)
    shifted["board"][-1]["coordinate"] = "A1"
    assert public_state_errors(shifted) == [
        "board coordinates must equal the catalog in catalog order"
    ]


def test_repo_root_finds_this_checkout():
    assert repo_root() == Path(__file__).resolve().parents[2]
