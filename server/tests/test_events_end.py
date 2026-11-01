"""Seeded round events, final-round turns, and the scoreboard."""

from __future__ import annotations

import pytest

from app.domain.coordinates import all_coordinates
from app.domain.events import load_round_events
from app.domain.offline import OfflineMatch
from app.files import load_json
from tests.test_economy import finish_market, pull


def test_event_deck_is_a_seeded_shuffle_and_reshuffles():
    golden = load_json("fixtures/golden_events.json")
    first = OfflineMatch(golden["seed"], golden["names"])
    second = OfflineMatch(golden["seed"], golden["names"])
    deck = [event["id"] for event in first.events]
    assert deck == [event["id"] for event in second.events] == golden["deck"]
    assert set(deck) == {event["id"] for event in load_round_events()}
    played: list[str] = []
    for _ in range(11):
        first._apply_round_event()
        played.append(first.event_ids[-1])
    assert played == golden["eleven"]
    assert played[:10] == golden["deck"]
    assert played[10] in set(deck)
    other = OfflineMatch(2, ["Rowan", "Quinn"])
    assert [event["id"] for event in other.events] != deck


def test_one_round_applies_grid_incentives_and_reprices_byte():
    match = OfflineMatch(7710, ["Rowan", "Quinn"])
    match.place("C1")
    finish_market(match)
    assert match.event_ids == []
    assert match.byte_price == 500
    match.place("F8")
    finish_market(match)
    assert match.round_number == 2
    assert match.event_ids == ["grid_incentives"]
    assert match.sentiment["energy"] == 1
    assert match.byte_price == 450
    assert match.log[-1] == "Round event: Grid Incentives. Energy +1. BYTE is $450."
    replay = OfflineMatch(7710, ["Rowan", "Quinn"])
    replay.place("C1")
    finish_market(replay)
    replay.place("F8")
    finish_market(replay)
    assert replay.log == match.log
    assert replay.sentiment == match.sentiment
    assert replay.byte_price == match.byte_price


def test_sentiment_and_byte_clamp_inside_a_round_event():
    match = OfflineMatch(7710, ["Rowan", "Quinn"])
    by_id = {event["id"]: event for event in load_round_events()}
    match.sentiment["ai"] = 2
    match.byte_price = 2000
    match.events = [by_id["ai_adoption"]]
    match._apply_round_event()
    assert match.sentiment["ai"] == 2
    assert match.byte_price == 2000
    assert "AI +2" in match.log[-1]
    match.byte_price = 100
    match.events = [by_id["fintech_regulation"]]
    match._apply_round_event()
    assert match.sentiment["fintech"] == -1
    assert match.byte_price == 100


def test_size_22_lets_the_other_player_finish_then_scores_once():
    match = OfflineMatch(7710, ["Rowan", "Quinn"])
    cells = [f"A{row}" for row in range(1, 10)] + [f"B{row}" for row in range(1, 10)] + ["C1", "C2", "C3"]
    _paint(match, cells, "nova_ai")
    pull(match, "C4")
    assert match.place("C4")["resolution"] == "growth"
    finish_market(match)
    assert match.final_round
    assert match.phase == "place"
    assert match.active_player()["display_name"] == "Quinn"
    assert match.event_ids == []
    assert match.ranking == []
    _skip_rest(match)
    assert match.phase == "completed"
    assert match.event_ids == ["grid_incentives"]
    assert match.round_number == 1
    assert len(match.event_ids) == match.round_number
    nova = next(corp for corp in match.corporations if corp["id"] == "nova_ai")
    assert nova["size"] == 22
    assert sum(match.occupied.values()) < 65
    assert match.log[-1] == "Rowan wins with $6000 fictional."
    with pytest.raises(ValueError, match="the match is over"):
        match.pass_turn()
    assert match.economy_errors() == []


def test_sixty_five_occupied_squares_open_the_final_round():
    match = OfflineMatch(7710, ["Rowan", "Quinn"])
    for cell in all_coordinates()[:65]:
        _take(match, cell)
        match.occupied[cell] = True
    hand = match.active_player()["hand"]
    for cell in list(hand):
        match.bag.append(cell)
    hand.clear()
    assert sum(match.occupied.values()) == 65
    assert all(not corp["active"] for corp in match.corporations)
    assert match.bag
    match.pass_turn()
    finish_market(match)
    assert match.final_round
    assert match.phase == "place"
    assert match.event_ids == []
    _skip_rest(match)
    assert match.phase == "completed"
    assert match.event_ids == ["grid_incentives"]
    assert match.economy_errors() == []


def test_empty_bag_and_hands_score_after_the_remaining_turn():
    match = OfflineMatch(7710, ["Rowan", "Quinn"])
    _fill_board(match)
    match.pass_turn()
    finish_market(match)
    assert match.final_round
    assert match.phase == "place"
    assert match.event_ids == []
    match.pass_turn()
    finish_market(match)
    assert match.phase == "completed"
    assert match.round_number == 1
    assert match.event_ids == ["grid_incentives"]
    assert match.log[-1] == "Rowan wins with $6000 fictional."
    assert [row["net_worth"] for row in _ordered(match)] == [6000, 6000]
    with pytest.raises(ValueError, match="the match is over"):
        match.buy_byte()


def test_ties_break_by_cash_then_active_shares_then_seat():
    richer = _ended_match()
    richer.players[1]["cash"] = 7000
    _fill_board(richer)
    _finish_both(richer)
    assert richer.ranking[0] == "p2"
    assert _ordered(richer)[0]["display_name"] == "Quinn"
    assert _ordered(richer)[0]["net_worth"] == 7000

    cash_breaks_share_count = _ended_match()
    _paint(cash_breaks_share_count, ["A1", "A2"], "nova_ai")
    _assign(cash_breaks_share_count, "nova_ai", {"p2": 5})
    cash_breaks_share_count.players[0]["cash"] = 7000
    cash_breaks_share_count.players[1]["cash"] = 6000
    cash_breaks_share_count.final_round = True
    _finish_both(cash_breaks_share_count)
    assert [row["net_worth"] for row in _ordered(cash_breaks_share_count)] == [7000, 7000]
    assert cash_breaks_share_count.ranking[0] == "p1"

    shares_break = _ended_match()
    _paint(shares_break, ["A1", "A2"], "nova_ai")
    _paint(shares_break, [f"C{row}" for row in range(1, 7)], "orbit_pay")
    _assign(shares_break, "nova_ai", {"p2": 2})
    _assign(shares_break, "orbit_pay", {"p1": 1})
    shares_break.final_round = True
    _finish_both(shares_break)
    nets = [row["net_worth"] for row in _ordered(shares_break)]
    assert nets[0] == nets[1]
    assert shares_break.ranking[0] == "p2"
    quinn = next(row for row in shares_break.ledger if row["id"] == "p2")
    assert quinn["active_shares"] == 2
    assert quinn["holdings"][0]["name"] == "NOVA AI"
    assert shares_break.economy_errors() == []


def _ended_match() -> OfflineMatch:
    return OfflineMatch(7710, ["Rowan", "Quinn"])


def _finish_both(match: OfflineMatch) -> None:
    while match.phase != "completed":
        if match.phase == "market":
            finish_market(match)
            continue
        hand = match.active_player()["hand"]
        if hand:
            for cell in list(hand):
                match.bag.append(cell)
            hand.clear()
        match.pass_turn()


def _skip_rest(match: OfflineMatch) -> None:
    while match.phase != "completed":
        if match.phase == "market":
            finish_market(match)
            continue
        hand = match.active_player()["hand"]
        for cell in list(hand):
            match.bag.append(cell)
        hand.clear()
        match.pass_turn()


def _fill_board(match: OfflineMatch) -> None:
    for player in match.players:
        while player["hand"]:
            cell = player["hand"].pop()
            if not match.occupied[cell]:
                match.occupied[cell] = True
    while match.bag:
        cell = match.bag.pop(0)
        if not match.occupied[cell]:
            match.occupied[cell] = True


def _take(match: OfflineMatch, cell: str) -> None:
    for player in match.players:
        if cell in player["hand"]:
            player["hand"].remove(cell)
            return
    match.bag.remove(cell)


def _paint(match: OfflineMatch, cells: list[str], corp_id: str) -> None:
    for cell in cells:
        _take(match, cell)
        match.occupied[cell] = True
        match.company_of[cell] = corp_id
    corp = next(item for item in match.corporations if item["id"] == corp_id)
    match._reprice(corp)


def _assign(match: OfflineMatch, corp_id: str, counts: dict[str, int]) -> None:
    outstanding = 0
    for player in match.players:
        count = int(counts.get(player["id"], 0))
        player["shares"][corp_id] = count
        outstanding += count
    corp = next(item for item in match.corporations if item["id"] == corp_id)
    corp["bank_shares"] = match.share_supply - outstanding


def _ordered(match: OfflineMatch) -> list[dict]:
    by_id = {row["id"]: row for row in match.ledger}
    return [by_id[player_id] for player_id in match.ranking]
