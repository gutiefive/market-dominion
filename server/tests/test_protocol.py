"""Shared schema and committed command/event fixtures."""

from __future__ import annotations

import json

from jsonschema import Draft202012Validator

from app.contract import command_errors, event_errors, load_schema, schema_view
from app.domain.corporations import load_corporations
from app.files import load_rules, repo_root

ROOT = repo_root()


def _load_dir(relative: str) -> list[tuple[str, object]]:
    folder = ROOT / "shared" / "fixtures" / relative
    found = []
    for path in sorted(folder.glob("*.json")):
        found.append((path.name, json.loads(path.read_text(encoding="utf-8"))))
    assert found, f"no fixtures in {relative}"
    return found


def test_schema_is_a_valid_draft_2020_12_document():
    schema = load_schema()
    Draft202012Validator.check_schema(schema)
    Draft202012Validator.check_schema(schema_view("command_envelope"))
    Draft202012Validator.check_schema(schema_view("event_envelope"))
    Draft202012Validator.check_schema(schema_view("public_state"))


def test_command_and_event_names_are_the_v1_surface():
    schema = load_schema()
    assert schema["$defs"]["command_name"]["enum"] == [
        "create_room",
        "join_room",
        "ready",
        "start_match",
        "place_tile",
        "choose_founder",
        "choose_merger_survivor",
        "market_buy_share",
        "market_sell_share",
        "market_buy_byte",
        "market_sell_byte",
        "pass_market_action",
        "end_turn",
        "reconnect",
        "request_snapshot",
    ]
    assert schema["$defs"]["event_name"]["enum"] == [
        "room_updated",
        "match_started",
        "state_snapshot",
        "tile_placed",
        "company_founded",
        "merger_started",
        "merger_resolved",
        "trade_completed",
        "round_event_applied",
        "turn_changed",
        "game_ended",
        "player_disconnected",
        "player_reconnected",
        "error",
    ]
    assert schema["$defs"]["error_code"]["enum"] == [
        "invalid_json",
        "unauthorized",
        "wrong_phase",
        "out_of_turn",
        "stale_version",
        "duplicate_action",
        "illegal_tile",
        "insufficient_cash",
        "insufficient_inventory",
        "rate_limited",
        "payload_too_large",
        "invalid_command",
        "not_found",
        "invalid_nickname",
    ]
    text = json.dumps(schema)
    for name in schema["$defs"]["command_name"]["enum"]:
        assert f'"const": "{name}"' in text


def test_schema_ids_match_the_shared_roster():
    schema = load_schema()
    assert schema["$defs"]["corporation_id"]["enum"] == [
        corporation["id"] for corporation in load_corporations()
    ]
    assert schema["$defs"]["sector_id"]["enum"] == load_rules()["sectors"]
    assert schema["$defs"]["phase"]["enum"] == [
        "lobby",
        "playing",
        "final_round",
        "completed",
    ]


def test_valid_fixtures_pass_and_invalid_fixtures_fail():
    for name, payload in _load_dir("commands"):
        assert command_errors(payload) == [], name
    for name, payload in _load_dir("events"):
        assert event_errors(payload) == [], name
    for name, payload in _load_dir("invalid_commands"):
        assert command_errors(payload), name
    for name, payload in _load_dir("invalid_events"):
        assert event_errors(payload), name


def test_public_snapshot_schema_has_no_private_hand_field():
    player = load_schema()["$defs"]["public_player"]
    assert "private_tile_hand" not in player["properties"]
    assert player["additionalProperties"] is False
    state = load_schema()["$defs"]["public_state"]
    assert "tile_bag" not in state["properties"]
    assert "private_tile_hand" not in json.dumps(state["properties"])
