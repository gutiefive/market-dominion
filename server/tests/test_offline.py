"""Offline deal, placement, and turn order. No companies and no network."""

from __future__ import annotations

import pytest

from app.domain.coordinates import all_coordinates
from app.domain.offline import OfflineMatch
from app.domain.rng import MatchRng
from app.files import load_json


def test_rng_matches_the_shared_vectors_and_literals():
    assert MatchRng(1).next_u32() == 270369
    assert MatchRng(0).next_u32() == 1085196063
    for case in load_json("fixtures/golden_rng.json")["cases"]:
        rng = MatchRng(case["seed"])
        assert [rng.next_u32() for _ in range(len(case["values"]))] == case["values"]
    with pytest.raises(ValueError):
        MatchRng(-1)


def test_opening_hands_are_locked_literals():
    paired = OfflineMatch(7710, ["Rowan", "Quinn"])
    assert [player["display_name"] for player in paired.players] == ["Rowan", "Quinn"]
    assert paired.players[0]["hand"] == ["C1", "D4", "B9", "E9", "E6"]
    assert paired.players[1]["hand"][0] == "F8"
    swapped = OfflineMatch(2, ["Rowan", "Quinn"])
    assert [player["display_name"] for player in swapped.players] == ["Quinn", "Rowan"]
    assert [player["id"] for player in swapped.players] == ["p2", "p1"]
    assert swapped.players[0]["hand"] == ["I9", "A4", "C7", "C6", "B7"]
    trio = OfflineMatch(7710, ["Rowan", "Quinn", "Avery"])
    assert [player["display_name"] for player in trio.players] == ["Avery", "Rowan", "Quinn"]


def test_deals_match_fixtures_and_conserve_tiles():
    catalog = all_coordinates()
    for case in load_json("fixtures/golden_deals.json")["cases"]:
        match = OfflineMatch(case["seed"], case["names"])
        snap = match.snapshot()
        for key in (
            "turn_order",
            "ids",
            "hands",
            "bag",
            "bag_size",
            "round_number",
            "active_player",
        ):
            assert snap[key] == case[key], (case["seed"], case["names"], key)
        seen: list[str] = list(snap["bag"])
        for hand in snap["hands"].values():
            assert len(hand) == 5
            seen.extend(hand)
        assert sorted(seen) == sorted(catalog)
        assert len(seen) == len(set(seen)) == 81
        assert match.conservation() == []
        assert all(player["cash"] == 6000 for player in match.players)


def test_same_seed_replays_and_a_different_seed_does_not():
    first = OfflineMatch(7710, ["Rowan", "Quinn"]).snapshot()
    second = OfflineMatch(7710, ["Rowan", "Quinn"]).snapshot()
    other = OfflineMatch(1, ["Rowan", "Quinn"]).snapshot()
    assert first == second
    assert first["hands"] != other["hands"]


def test_scripted_placement_waits_to_draw_until_the_market_closes():
    fixture = load_json("fixtures/golden_placement.json")
    match = OfflineMatch(fixture["seed"], fixture["names"])
    for step in fixture["steps"]:
        if step["op"] == "place":
            actor = match.active_player()["display_name"]
            tile = match.active_player()["hand"][0]
            placed = match.place(tile)
            assert actor == step["actor"]
            assert placed["placed"] == tile == step["placed"]
        elif step["op"] == "pass_market":
            match.pass_market()
        else:
            raise AssertionError(step["op"])
        snap = match.snapshot()
        assert snap["phase"] == step["phase"]
        assert snap["round_number"] == step["round_number"]
        assert snap["active_player"] == step["active_player"]
        assert snap["bag_size"] == step["bag_size"]
        assert snap["occupied"] == step["occupied"]
        assert snap["log"] == step["log"]
        assert match.economy_errors() == []


def test_illegal_placement_and_early_pass_are_rejected():
    match = OfflineMatch(7710, ["Rowan", "Quinn"])
    with pytest.raises(ValueError, match="tile not in hand"):
        match.place("A1")
    with pytest.raises(ValueError, match="hand still has a tile"):
        match.pass_turn()
    match.place("C1")
    with pytest.raises(ValueError, match="not the placement step"):
        match.place("C1")
    assert match.conservation() == []
    assert match.economy_errors() == []


def _finish_market(match: OfflineMatch) -> None:
    while match.phase == "market":
        match.pass_market()


def test_safe_play_stops_at_a_merger_and_keeps_invariants():
    match = OfflineMatch(7710, ["Rowan", "Quinn"])
    placed = 0
    stopped = False
    while placed < 81:
        assert match.economy_errors() == []
        if match.phase == "choose_founder":
            inactive = [corp["id"] for corp in match.corporations if not corp["active"]]
            match.choose_founder(inactive[0])
            continue
        if match.phase == "market":
            _finish_market(match)
            continue
        hand = match.active_player()["hand"]
        if not hand:
            match.pass_turn()
            continue
        try:
            match.place(hand[0])
        except ValueError as exc:
            assert str(exc) == "merger is not in this build"
            stopped = True
            break
        placed += 1
    assert stopped
    assert match.economy_errors() == []
    assert placed < 81


def test_empty_hand_skips_and_table_size_is_checked():
    match = OfflineMatch(7710, ["Rowan", "Quinn"])
    match.players[0]["hand"] = []
    match.bag = []
    result = match.pass_turn()
    assert result["log"] == "Rowan has no tile to place."
    assert match.phase == "market"
    assert match.active_player()["display_name"] == "Rowan"
    match.pass_market()
    match.pass_market()
    assert match.log[-1] == "Rowan drew nothing. The bag is empty."
    assert match.active_player()["display_name"] == "Quinn"
    with pytest.raises(ValueError, match="player count"):
        OfflineMatch(7710, ["Rowan"])
    with pytest.raises(ValueError, match="player count"):
        OfflineMatch(7710, ["A", "B", "C", "D", "E"])
    with pytest.raises(ValueError, match="nickname"):
        OfflineMatch(7710, ["Rowan", " x"])
    with pytest.raises(ValueError, match="duplicate name"):
        OfflineMatch(7710, ["Rowan", "Rowan"])
