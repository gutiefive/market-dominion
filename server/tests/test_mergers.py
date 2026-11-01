"""Largest-survivor mergers, bonuses, and liquidation."""

from __future__ import annotations

import pytest

from app.domain.mergers import bonus_payouts
from app.domain.offline import OfflineMatch
from tests.test_economy import finish_market, pull


def test_bonus_examples_from_the_spec():
    assert bonus_payouts(400, {"p1": 4, "p2": 0}) == {"p1": 1200}
    assert bonus_payouts(300, {"p1": 2, "p2": 2, "p3": 1}) == {"p1": 450, "p2": 450}
    assert bonus_payouts(250, {"p1": 4, "p2": 1, "p3": 1, "p4": 1}) == {
        "p1": 500,
        "p2": 84,
        "p3": 83,
        "p4": 83,
    }
    assert bonus_payouts(250, {"p1": 1, "p2": 1, "p3": 1, "p4": 1}) == {
        "p1": 188,
        "p2": 188,
        "p3": 187,
        "p4": 187,
    }
    assert bonus_payouts(300, {"p1": 0, "p2": 0}) == {}


def test_larger_chain_survives_and_sole_holder_receives_both_pools():
    match = OfflineMatch(7710, ["Rowan", "Quinn"])
    _paint(match, ["C1", "C2", "C3", "C4", "C5"], "nova_ai")
    _paint(match, ["A1", "A2", "A3"], "orbit_pay")
    _assign(match, "orbit_pay", {"p2": 4})
    nova_shares = _shares(match, "nova_ai")
    pull(match, "B1")
    resolved = match.place("B1")
    assert resolved["resolution"] == "merger"
    assert resolved["survivor"] == "nova_ai"
    assert resolved["log"] == "Rowan placed B1. NOVA AI survives the merger at size 9. Share price is $550."
    assert "Quinn received a $750 bonus on ORBIT PAY." in match.log
    assert "Quinn liquidated 4 ORBIT PAY shares for $1000." in match.log
    assert _cash(match, "p2") == 7750
    assert _cash(match, "p1") == 6000
    assert _shares(match, "nova_ai") == nova_shares
    assert _shares(match, "orbit_pay") == {"p1": 0, "p2": 0}
    orbit = _corp(match, "orbit_pay")
    assert orbit["active"] is False
    assert orbit["size"] == 0
    assert orbit["share_price"] == 0
    assert orbit["bank_shares"] == 20
    assert orbit["cells"] == []
    assert _corp(match, "nova_ai")["cells"] == ["A1", "B1", "C1", "A2", "C2", "A3", "C3", "C4", "C5"]
    buyer = match.active_player()
    before = buyer["cash"]
    assert "for $550." in match.buy_share("nova_ai")["log"]
    assert buyer["cash"] == before - 550
    with pytest.raises(ValueError, match="company is not active"):
        match.buy_share("orbit_pay")
    assert match.economy_errors() == []


def test_size_six_loser_at_400_pays_the_spec_majority_example():
    match = OfflineMatch(7710, ["Rowan", "Quinn"])
    _paint(match, [f"C{row}" for row in range(1, 8)], "nova_ai")
    _paint(match, [f"A{row}" for row in range(1, 7)], "orbit_pay")
    _assign(match, "orbit_pay", {"p1": 4})
    pull(match, "B1")
    match.place("B1")
    assert _corp(match, "nova_ai")["size"] == 14
    assert _corp(match, "nova_ai")["share_price"] == 800
    assert "Rowan received a $1200 bonus on ORBIT PAY." in match.log
    assert "Rowan liquidated 4 ORBIT PAY shares for $1600." in match.log
    assert _cash(match, "p1") == 8800
    assert _cash(match, "p2") == 6000
    assert _inactive(match, "orbit_pay")
    assert match.economy_errors() == []


def test_tied_majority_splits_900_and_a_lower_holder_gets_no_bonus():
    match = OfflineMatch(7710, ["Rowan", "Quinn", "Avery"])
    _paint(match, [f"C{row}" for row in range(1, 6)], "nova_ai")
    _paint(match, [f"A{row}" for row in range(1, 5)], "orbit_pay")
    _assign(match, "orbit_pay", {"p1": 2, "p2": 2, "p3": 1})
    pull(match, "B1")
    match.place("B1")
    assert match.log[-6].endswith("NOVA AI survives the merger at size 10. Share price is $600.")
    assert match.log[-5:] == [
        "Rowan received a $450 bonus on ORBIT PAY.",
        "Quinn received a $450 bonus on ORBIT PAY.",
        "Rowan liquidated 2 ORBIT PAY shares for $600.",
        "Quinn liquidated 2 ORBIT PAY shares for $600.",
        "Avery liquidated 1 ORBIT PAY shares for $300.",
    ]
    assert not any("Avery received" in line for line in match.log)
    assert _cash(match, "p1") == 7050
    assert _cash(match, "p2") == 7050
    assert _cash(match, "p3") == 6300
    assert _corp(match, "orbit_pay")["share_price"] == 0
    assert match.economy_errors() == []


def test_second_place_tie_pays_remainder_by_player_id():
    match = OfflineMatch(7710, ["Rowan", "Quinn", "Avery", "Blake"])
    _paint(match, [f"C{row}" for row in range(1, 5)], "nova_ai")
    _paint(match, ["A1", "A2", "A3"], "orbit_pay")
    _assign(match, "orbit_pay", {"p1": 4, "p2": 1, "p3": 1, "p4": 1})
    pull(match, "B1")
    match.place("B1")
    assert _cash(match, "p1") == 7500
    assert _cash(match, "p2") == 6334
    assert _cash(match, "p3") == 6333
    assert _cash(match, "p4") == 6333
    assert "Quinn received a $84 bonus on ORBIT PAY." in match.log
    assert "Avery received a $83 bonus on ORBIT PAY." in match.log
    assert "Blake received a $83 bonus on ORBIT PAY." in match.log
    assert match.economy_errors() == []


def test_four_way_tie_splits_the_combined_pool_with_a_remainder():
    match = OfflineMatch(7710, ["Rowan", "Quinn", "Avery", "Blake"])
    _paint(match, [f"C{row}" for row in range(1, 5)], "nova_ai")
    _paint(match, ["A1", "A2", "A3"], "orbit_pay")
    _assign(match, "orbit_pay", {"p1": 1, "p2": 1, "p3": 1, "p4": 1})
    pull(match, "B1")
    match.place("B1")
    assert _cash(match, "p1") == 6438
    assert _cash(match, "p2") == 6438
    assert _cash(match, "p3") == 6437
    assert _cash(match, "p4") == 6437
    assert match.economy_errors() == []


def test_three_companies_pay_once_and_reprice_the_survivor_once():
    match = OfflineMatch(7710, ["Rowan", "Quinn", "Avery", "Blake"])
    # C5 is the only bridge. Chains stay apart until that tile, and C6 is unincorporated.
    _paint(match, ["A1", "A2", "A3", "A4", "A5", "B5"], "nova_ai")
    _paint(match, ["D5", "E5", "E6"], "orbit_pay")
    _paint(match, ["C3", "C4"], "volt_grid")
    _paint(match, ["C6"], None)
    _assign(match, "orbit_pay", {"p1": 2, "p2": 2})
    _assign(match, "volt_grid", {"p3": 1})
    nova_shares = _shares(match, "nova_ai")
    pull(match, "C5")
    before = len(match.log)
    resolved = match.place("C5")
    assert resolved["survivor"] == "nova_ai"
    added = match.log[before:]
    assert sum("Share price is $" in line for line in added) == 1
    assert any("Share price is $750." in line for line in added)
    assert _corp(match, "nova_ai")["size"] == 13
    assert _corp(match, "nova_ai")["share_price"] == 750
    assert _corp(match, "nova_ai")["cells"] == [
        "A1", "A2", "A3", "C3", "A4", "C4", "A5", "B5", "C5", "D5", "E5", "C6", "E6",
    ]
    assert _shares(match, "nova_ai") == nova_shares
    assert _inactive(match, "orbit_pay")
    assert _inactive(match, "volt_grid")
    assert "Rowan received a $375 bonus on ORBIT PAY." in added
    assert "Avery received a $600 bonus on VOLT GRID." in added
    assert added.index("Rowan received a $375 bonus on ORBIT PAY.") < added.index(
        "Avery received a $600 bonus on VOLT GRID."
    )
    assert match.economy_errors() == []


def test_tie_uses_company_size_before_the_tile_and_ignores_loose_squares():
    match = OfflineMatch(7710, ["Rowan", "Quinn"])
    _paint(match, ["A2", "A3"], "nova_ai")
    _paint(match, ["C2", "C3"], "orbit_pay")
    _paint(match, ["B1"], None)
    pull(match, "B2")
    opened = match.place("B2")
    assert opened["resolution"] == "choose_survivor"
    assert opened["log"] == (
        "Rowan placed B2. Choose the survivor. NOVA AI and ORBIT PAY are tied at size 2."
    )
    assert match.pending_options == ["nova_ai", "orbit_pay"]
    assert _corp(match, "nova_ai")["size"] == 2
    assert _corp(match, "orbit_pay")["size"] == 2
    assert "B1" not in match.company_of
    assert match.economy_errors() == []
    before = match.snapshot()
    with pytest.raises(ValueError, match="company is not a tied survivor"):
        match.choose_survivor("volt_grid")
    with pytest.raises(ValueError, match="unknown company"):
        match.choose_survivor("not_a_brand")
    assert match.snapshot() == before
    kept = match.choose_survivor("orbit_pay")
    assert kept["log"] == "Rowan kept ORBIT PAY. ORBIT PAY is size 6. Share price is $400."
    assert _inactive(match, "nova_ai")
    assert _corp(match, "orbit_pay")["cells"] == ["B1", "A2", "B2", "C2", "A3", "C3"]
    assert match.phase == "market"
    assert match.economy_errors() == []


def test_a_smaller_company_in_the_same_merger_cannot_be_chosen():
    match = OfflineMatch(7710, ["Rowan", "Quinn", "Avery"])
    _paint(match, ["A3", "A4", "A5", "B5"], "nova_ai")
    _paint(match, ["D5", "E5", "E4", "E3"], "orbit_pay")
    _paint(match, ["C6", "C7"], "volt_grid")
    pull(match, "C5")
    match.place("C5")
    assert match.pending_options == ["nova_ai", "orbit_pay"]
    assert _corp(match, "volt_grid")["size"] == 2
    with pytest.raises(ValueError, match="company is not a tied survivor"):
        match.choose_survivor("volt_grid")
    match.choose_survivor("nova_ai")
    assert _corp(match, "nova_ai")["size"] == 11
    assert _corp(match, "nova_ai")["share_price"] == 650
    assert _corp(match, "nova_ai")["cells"] == [
        "A3", "E3", "A4", "E4", "A5", "B5", "C5", "D5", "E5", "C6", "C7",
    ]
    assert _inactive(match, "orbit_pay")
    assert _inactive(match, "volt_grid")
    assert match.economy_errors() == []


def test_empty_loser_pays_nothing_and_can_be_founded_again():
    match = OfflineMatch(7710, ["Rowan", "Quinn"])
    _chain(match, ["A1", "A2", "A3"], "nova_ai")
    _chain(match, ["C1", "C2"], "orbit_pay")
    _assign(match, "orbit_pay", {})
    cash = {player["id"]: player["cash"] for player in match.players}
    pull(match, "B1")
    match.place("B1")
    assert "ORBIT PAY paid no merger bonus." in match.log
    assert not any("liquidated" in line and "ORBIT PAY" in line for line in match.log)
    assert {player["id"]: player["cash"] for player in match.players} == cash
    assert _inactive(match, "orbit_pay")
    finish_market(match)
    pull(match, "I8")
    match.place("I8")
    finish_market(match)
    pull(match, "I9")
    assert match.place("I9")["resolution"] == "choose_founder"
    granted = match.choose_founder("orbit_pay")
    assert granted["granted"] is True
    assert _corp(match, "orbit_pay")["size"] == 2
    assert _corp(match, "orbit_pay")["bank_shares"] == 19
    assert sum(_shares(match, "orbit_pay").values()) == 1
    assert match.economy_errors() == []


def test_loser_price_is_snapshotted_with_its_own_sentiment():
    match = OfflineMatch(7710, ["Rowan", "Quinn"])
    _paint(match, ["C1", "C2", "C3", "C4", "C5"], "nova_ai")
    _paint(match, ["A1", "A2", "A3", "A4"], "orbit_pay")
    match.sentiment["fintech"] = 2
    match._reprice(_corp(match, "orbit_pay"))
    assert _corp(match, "orbit_pay")["share_price"] == 360
    _assign(match, "orbit_pay", {"p1": 1})
    pull(match, "B1")
    match.place("B1")
    assert "Rowan received a $1080 bonus on ORBIT PAY." in match.log
    assert "Rowan liquidated 1 ORBIT PAY shares for $360." in match.log
    assert _corp(match, "nova_ai")["share_price"] == 600
    assert match.economy_errors() == []


def _paint(match: OfflineMatch, cells: list[str], corp_id: str | None) -> None:
    """Put tiles on the board before the first turn, so sentiment is still 0."""
    for cell in cells:
        for player in match.players:
            if cell in player["hand"]:
                player["hand"].remove(cell)
                break
        else:
            match.bag.remove(cell)
        match.occupied[cell] = True
        if corp_id:
            match.company_of[cell] = corp_id
    if corp_id:
        match._reprice(_corp(match, corp_id))


def _chain(match: OfflineMatch, cells: list[str], brand: str) -> None:
    for index, cell in enumerate(cells):
        pull(match, cell)
        placed = match.place(cell)
        if index == 0:
            assert placed["resolution"] == "unincorporated"
        elif index == 1:
            assert placed["resolution"] == "choose_founder"
            match.choose_founder(brand)
        else:
            assert placed["resolution"] == "growth"
        finish_market(match)


def _assign(match: OfflineMatch, corp_id: str, counts: dict[str, int]) -> None:
    outstanding = 0
    for player in match.players:
        count = int(counts.get(player["id"], 0))
        player["shares"][corp_id] = count
        outstanding += count
    corp = _corp(match, corp_id)
    assert outstanding <= match.share_supply
    corp["bank_shares"] = match.share_supply - outstanding


def _corp(match: OfflineMatch, corp_id: str) -> dict:
    for corp in match.corporations:
        if corp["id"] == corp_id:
            return corp
    raise AssertionError(corp_id)


def _shares(match: OfflineMatch, corp_id: str) -> dict[str, int]:
    return {player["id"]: int(player["shares"][corp_id]) for player in match.players}


def _cash(match: OfflineMatch, player_id: str) -> int:
    for player in match.players:
        if player["id"] == player_id:
            return int(player["cash"])
    raise AssertionError(player_id)


def _inactive(match: OfflineMatch, corp_id: str) -> bool:
    corp = _corp(match, corp_id)
    return (
        corp["active"] is False
        and corp["size"] == 0
        and corp["share_price"] == 0
        and corp["bank_shares"] == 20
        and corp["cells"] == []
        and sum(_shares(match, corp_id).values()) == 0
    )
