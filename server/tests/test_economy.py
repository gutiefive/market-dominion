"""Founding, growth, and two market actions. Merger payouts live in test_mergers.py."""

from __future__ import annotations

import pytest

from app.domain.offline import OfflineMatch
from app.domain.pricing import share_price


def pull(match: OfflineMatch, coordinate: str) -> None:
    """Move one unique tile into the active hand. The 81-tile partition stays intact."""
    for player in match.players:
        if coordinate in player["hand"]:
            player["hand"].remove(coordinate)
            break
    else:
        match.bag.remove(coordinate)
    match.active_player()["hand"].append(coordinate)


def finish_market(match: OfflineMatch) -> None:
    while match.phase == "market" and match.market_actions_left > 0:
        match.pass_market()


def test_isolated_tile_does_not_found_and_draw_waits_for_the_market():
    match = OfflineMatch(7710, ["Rowan", "Quinn"])
    placed = match.place("C1")
    assert placed["resolution"] == "unincorporated"
    assert placed["log"] == "Rowan placed C1. The district stays unincorporated."
    assert match.phase == "market"
    assert match.market_actions_left == 2
    assert match.active_player()["display_name"] == "Rowan"
    assert match.bag and len(match.bag) == 71
    assert "C1" not in match.active_player()["hand"]
    assert match.company_of == {}
    assert all(not corp["active"] for corp in match.corporations)
    match.pass_market()
    assert match.phase == "market"
    assert match.market_actions_left == 1
    match.pass_market()
    assert match.phase == "place"
    assert match.active_player()["display_name"] == "Quinn"
    assert match.log[-1] == "Rowan drew from the bag."
    assert len(match.players[0]["hand"]) == 5
    assert match.economy_errors() == []


def test_founding_grants_one_share_and_posts_the_size_price():
    match = OfflineMatch(7710, ["Rowan", "Quinn"])
    pull(match, "A1")
    match.place("A1")
    finish_market(match)
    pull(match, "E9")
    match.place("E9")
    finish_market(match)
    pull(match, "A2")
    pending = match.place("A2")
    assert pending["resolution"] == "choose_founder"
    assert match.phase == "choose_founder"
    with pytest.raises(ValueError, match="unknown company"):
        match.choose_founder("not_a_brand")
    founded = match.choose_founder("nova_ai")
    nova = match.corporations[0]
    assert founded["granted"] is True
    assert founded["log"] == "Rowan founded NOVA AI on 2 districts and received one founder share."
    assert nova["active"] is True
    assert nova["cells"] == ["A1", "A2"]
    assert nova["size"] == 2
    assert nova["share_price"] == share_price(2, 0) == 200
    assert nova["bank_shares"] == 19
    rowan = match.players[0]
    assert rowan["shares"]["nova_ai"] == 1
    assert rowan["cash"] == 6000
    assert match.phase == "market"
    bought = match.buy_share("nova_ai")
    assert bought["turn_finished"] is False
    assert rowan["cash"] == 5800
    assert rowan["shares"]["nova_ai"] == 2
    assert nova["bank_shares"] == 18
    assert match.market_actions_left == 1
    match.sell_share("nova_ai")
    assert rowan["cash"] == 6000
    assert rowan["shares"]["nova_ai"] == 1
    assert nova["bank_shares"] == 19
    assert match.phase == "place"
    assert match.active_player()["display_name"] == "Quinn"
    assert match.economy_errors() == []


def test_growth_absorbs_a_connected_unincorporated_square_and_reprices():
    match = OfflineMatch(7710, ["Rowan", "Quinn"])
    pull(match, "A1")
    match.place("A1")
    finish_market(match)
    pull(match, "E9")
    match.place("E9")
    finish_market(match)
    pull(match, "A2")
    match.place("A2")
    match.choose_founder("nova_ai")
    finish_market(match)
    pull(match, "C1")
    alone = match.place("C1")
    assert alone["resolution"] == "unincorporated"
    finish_market(match)
    pull(match, "B1")
    grew = match.place("B1")
    nova = match.corporations[0]
    assert grew["resolution"] == "growth"
    assert nova["cells"] == ["A1", "B1", "C1", "A2"]
    assert nova["size"] == 4
    assert nova["share_price"] == share_price(4, match.sentiment["ai"])
    assert "E9" not in nova["cells"]
    assert match.company_of.get("E9") is None
    bought = match.buy_share("nova_ai")
    assert f"for ${nova['share_price']}." in bought["log"]
    assert match.active_player()["cash"] == 6000 - nova["share_price"]
    assert match.active_player()["shares"]["nova_ai"] == 2
    assert nova["bank_shares"] == 18
    assert match.economy_errors() == []


def test_diagonal_cells_do_not_found_or_merge_chains():
    match = OfflineMatch(7710, ["Rowan", "Quinn"])
    pull(match, "A1")
    match.place("A1")
    finish_market(match)
    pull(match, "B2")
    placed = match.place("B2")
    assert placed["resolution"] == "unincorporated"
    assert match.phase == "market"
    assert all(not corp["active"] for corp in match.corporations)


def test_a_cluster_stays_unincorporated_when_every_brand_is_active():
    match = OfflineMatch(7710, ["Rowan", "Quinn"])
    pairs = [("A1", "A2"), ("C1", "C2"), ("E1", "E2"), ("G1", "G2"), ("I1", "I2")]
    brands = [corp["id"] for corp in match.corporations]
    for (first, second), brand in zip(pairs, brands, strict=True):
        pull(match, first)
        match.place(first)
        finish_market(match)
        pull(match, second)
        assert match.place(second)["resolution"] == "choose_founder"
        match.choose_founder(brand)
        finish_market(match)
    pull(match, "A4")
    match.place("A4")
    finish_market(match)
    pull(match, "A5")
    stayed = match.place("A5")
    assert stayed["resolution"] == "unincorporated"
    assert "stays unincorporated" in stayed["log"]
    assert match.company_of.get("A4") is None
    assert match.company_of.get("A5") is None
    assert match.economy_errors() == []


def test_equal_chains_wait_for_a_survivor_without_entering_the_market():
    match = OfflineMatch(7710, ["Rowan", "Quinn"])
    pull(match, "A1")
    match.place("A1")
    finish_market(match)
    pull(match, "C4")
    match.place("C4")
    finish_market(match)
    pull(match, "A2")
    match.place("A2")
    match.choose_founder("nova_ai")
    finish_market(match)
    pull(match, "C1")
    match.place("C1")
    finish_market(match)
    pull(match, "C2")
    match.place("C2")
    match.choose_founder("orbit_pay")
    finish_market(match)
    pull(match, "B1")
    opened = match.place("B1")
    assert opened["resolution"] == "choose_survivor"
    assert match.phase == "choose_survivor"
    assert "B1" not in match.active_player()["hand"]
    assert match.occupied["B1"]
    assert "B1" not in match.company_of
    assert match.economy_errors() == []


def test_market_rejects_a_third_action_inactive_names_and_negative_cash():
    match = OfflineMatch(7710, ["Rowan", "Quinn"])
    pull(match, "A1")
    match.place("A1")
    with pytest.raises(ValueError, match="no company choice is pending"):
        match.choose_founder("nova_ai")
    with pytest.raises(ValueError, match="company is not active"):
        match.buy_share("nova_ai")
    assert match.market_actions_left == 2
    finish_market(match)
    pull(match, "A2")
    match.place("A2")
    match.choose_founder("nova_ai")
    rowan = match.active_player()
    rowan["cash"] = 100
    with pytest.raises(ValueError, match="not enough cash"):
        match.buy_share("nova_ai")
    assert rowan["cash"] == 100
    assert rowan["shares"]["nova_ai"] == 1
    assert match.market_actions_left == 2
    rowan["cash"] = 6000
    match.sell_share("nova_ai")
    assert rowan["shares"]["nova_ai"] == 0
    assert nova_bank(match) == 20
    assert rowan["cash"] == 6200
    with pytest.raises(ValueError, match="no share to sell"):
        match.sell_share("nova_ai")
    assert match.market_actions_left == 1
    match.buy_byte()
    assert rowan["cash"] == 5700
    assert rowan["byte_count"] == 1
    assert match.byte_exchange == 29
    assert match.phase == "place"
    with pytest.raises(ValueError, match="not the market step"):
        match.buy_byte()
    assert match.economy_errors() == []
    pull(match, "E5")
    match.place("E5")
    finish_market(match)
    pull(match, "E7")
    match.place("E7")
    posted = match.byte_price
    before = rowan["cash"]
    match.sell_byte()
    assert rowan["byte_count"] == 0
    assert rowan["cash"] == before + posted
    assert match.byte_exchange == 30
    assert match.economy_errors() == []


def nova_bank(match: OfflineMatch) -> int:
    return int(match.corporations[0]["bank_shares"])


def test_founding_without_a_bank_share_is_recorded_and_still_opens():
    match = OfflineMatch(7710, ["Rowan", "Quinn"])
    pull(match, "A1")
    match.place("A1")
    finish_market(match)
    pull(match, "A2")
    match.place("A2")
    nova = match.corporations[0]
    nova["bank_shares"] = 0
    match.players[0]["shares"]["nova_ai"] = 20
    founded = match.choose_founder("nova_ai")
    assert founded["granted"] is False
    assert "no share to grant" in founded["log"]
    assert match.players[0]["shares"]["nova_ai"] == 20
    assert nova["bank_shares"] == 0
    assert nova["active"] is True
    assert nova["share_price"] == 200
    assert match.economy_errors() == []


def test_byte_cannot_be_shorted_and_shares_cannot_exceed_the_bank():
    match = OfflineMatch(7710, ["Rowan", "Quinn"])
    pull(match, "A1")
    match.place("A1")
    with pytest.raises(ValueError, match="no BYTE to sell"):
        match.sell_byte()
    finish_market(match)
    pull(match, "A2")
    match.place("A2")
    match.choose_founder("nova_ai")
    nova = match.corporations[0]
    for player in match.players:
        player["shares"]["nova_ai"] = 0
    match.active_player()["shares"]["nova_ai"] = 20
    nova["bank_shares"] = 0
    with pytest.raises(ValueError, match="no share in the bank"):
        match.buy_share("nova_ai")
    assert match.market_actions_left == 2
    assert match.economy_errors() == []
