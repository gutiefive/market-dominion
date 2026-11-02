"""Financial transaction core: real money/supply effects, retries and crash restore."""
import copy
import hashlib
import json

import pytest

from app.domain.dominion_merger import DominionMerger
from app.files import load_json

VECTORS = load_json("fixtures/dominion_v1/merger_vectors.json")["scenarios"]


def _begin(case=VECTORS[0]):
    return DominionMerger.begin(**copy.deepcopy(case["opening"]))


def _apply(merger, pairs, action_id=None, timeout=False):
    choice = merger.current_choice()
    state = merger.export_state()
    args = (state["opening"]["resolution_id"], choice["player_id"], choice["loser_id"])
    if timeout:
        return merger.timeout(*args, action_id or f"a{state['version']}", state["version"])
    return merger.choose(*args, pairs, action_id or f"a{state['version']}", state["version"])


def _supply(state):
    for cid, bank in state["banks"].items():
        assert 0 <= bank <= 20
        assert bank + sum(book[cid] for book in state["shares"].values()) == 20
    assert all(value >= 0 for value in state["cash"].values())


@pytest.mark.parametrize("case", VECTORS, ids=lambda case: case["name"])
def test_shared_financial_examples_and_restore_after_every_choice(case):
    source = copy.deepcopy(case["opening"])
    merger = DominionMerger.begin(**source)
    initial = merger.export_state()
    assert [[item["loser_id"], item["player_id"]] for item in initial["queue"]] == case["queue"]
    assert source == case["opening"]  # Inputs are never debited in-place.
    for pairs in case["choices"]:
        before = merger.export_state()
        merger = DominionMerger.from_export(json.loads(json.dumps(before)))
        assert merger.export_state() == before
        _apply(merger, pairs)
        _supply(merger.export_state())
    final = merger.export_state()
    assert final["complete"] and final["resume_player_id"] == source["placer_id"]
    assert final["required_actor_id"] is None and merger.current_choice() is None
    assert final["cash"] == case["cash"]
    assert final["remaining_survivor_bank"] == case["survivor_bank"]
    assert {pid: book["nova_ai"] for pid, book in final["shares"].items()} == case["survivor_holdings"]
    for cid in source["losing_ids"]:
        assert final["banks"][cid] == 20
        assert all(book[cid] == 0 for book in final["shares"].values())
    assert DominionMerger.from_export(json.loads(json.dumps(final))).export_state() == final


def test_supply_shortage_rejection_and_exact_duplicate_are_atomic_after_restore():
    merger = _begin()
    first = _apply(merger, 2)
    merger = DominionMerger.from_export(merger.export_state())
    before = merger.export_state()
    assert merger.current_choice()["max_pairs"] == 1
    with pytest.raises(ValueError):
        _apply(merger, 2)
    assert merger.export_state() == before
    duplicate = merger.choose("m1", "p1", "volt_grid", 2, "a0", 0)
    assert duplicate["duplicate"] and duplicate["receipt"] == first["receipt"]
    assert merger.export_state() == before
    assert merger.choose("m1", "p1", "volt_grid", 2, "a0", 1)["duplicate"]
    assert merger.export_state() == before
    with pytest.raises(ValueError):
        merger.choose("m1", "p1", "volt_grid", 0, "a0", 0)
    assert merger.export_state() == before
    _apply(merger, 1)
    done = merger.export_state()
    assert merger.choose("m1", "p1", "volt_grid", 2, "a0", 2)["duplicate"]
    assert merger.export_state() == done
    with pytest.raises(ValueError):
        merger.choose("m1", "p2", "volt_grid", 0, "new", 2)
    assert merger.export_state() == done


@pytest.mark.parametrize("args", [
    ("wrong", "p1", "volt_grid", 0, "x", 0),
    ("m1", "p2", "volt_grid", 0, "x", 0),
    ("m1", "p1", "orbit_pay", 0, "x", 0),
    ("m1", "p1", "volt_grid", 0, "x", 1),
    ("m1", "p1", "volt_grid", -1, "x", 0),
    ("m1", "p1", "volt_grid", 3, "x", 0),
    ("m1", "p1", "volt_grid", True, "x", 0),
    ("m1", "p1", "volt_grid", 1.0, "x", 0),
    ("m1", "p1", "volt_grid", 0, "", 0),
    ("m1", "p1", "volt_grid", 0, "x", False),
])
def test_wrong_actor_company_resolution_version_or_quantity_never_changes_state(args):
    merger = _begin()
    before = merger.export_state()
    with pytest.raises(ValueError):
        merger.choose(*args)
    assert merger.export_state() == before


def test_timeout_defaults_only_current_holder_to_cash_and_retries_do_not_pay_again():
    merger = _begin()
    result = _apply(merger, 0, "deadline0", timeout=True)
    assert result["receipt"]["cash_proceeds"] == 1100
    assert result["receipt"]["timed_out"] is True
    restored = DominionMerger.from_export(json.loads(json.dumps(merger.export_state())))
    before = restored.export_state()
    assert restored.timeout("m1", "p1", "volt_grid", "deadline0", 0)["duplicate"]
    assert restored.export_state() == before
    with pytest.raises(ValueError):
        restored.timeout("m1", "p1", "volt_grid", "late-deadline", 0)
    assert restored.export_state() == before
    assert restored.current_choice()["player_id"] == "p2"
    assert restored.current_choice()["max_pairs"] == 1  # Held shares, not bank=3, limit this choice.
    _apply(restored, 0, timeout=True)
    assert restored.export_state()["cash"] == {"p1": 2540, "p2": 1880}


@pytest.mark.parametrize("field", ["cash", "bank", "cursor", "bonus_flag", "receipt", "version_bool", "snapshot", "actor", "extra"])
def test_corrupt_export_is_rejected_without_mutating_the_live_state(field):
    merger = _begin()
    _apply(merger, 2)
    before = merger.export_state()
    saved = copy.deepcopy(before)
    if field == "cash": saved["cash"]["p1"] += 1
    elif field == "bank": saved["banks"]["nova_ai"] += 1
    elif field == "cursor": saved["cursor"] = 0
    elif field == "bonus_flag": saved["bonuses_paid"] = False
    elif field == "receipt": saved["decisions"][0]["receipt"]["cash_proceeds"] += 1
    elif field == "version_bool": saved["version"] = True
    elif field == "snapshot": saved["snapshots"]["volt_grid"]["price"] += 10
    elif field == "actor": saved["required_actor_id"] = "p1"
    else: saved["unexpected"] = "ignored fields are not allowed"
    with pytest.raises(ValueError):
        DominionMerger.from_export(saved)
    assert merger.export_state() == before


def test_copies_and_exports_exclude_private_input_metadata():
    opening = copy.deepcopy(VECTORS[0]["opening"])
    opening["players"][0].update(hand=["I9"], session_token="test-only-not-to-be-copied")
    merger = DominionMerger.begin(**opening)
    saved = merger.export_state()
    assert "session_token" not in json.dumps(saved) and '"hand"' not in json.dumps(saved)
    choice = merger.current_choice()
    choice["max_pairs"] = 99
    saved["cash"]["p1"] = -1
    assert merger.current_choice()["max_pairs"] == 2
    assert merger.export_state()["cash"]["p1"] == 1440


@pytest.mark.parametrize("count", range(1, 21))
@pytest.mark.parametrize("bank", range(0, 21))
def test_all_holdings_and_available_bank_counts_conserve_both_share_supplies(count, bank):
    opening = copy.deepcopy(VECTORS[0]["opening"])
    for player in opening["players"]:
        player["shares"]["volt_grid"] = count if player["id"] == "p1" else 0
        player["shares"]["nova_ai"] = 20 - bank if player["id"] == "p2" else 0
    for corp in opening["companies"]:
        if corp["id"] == "volt_grid": corp["bank_shares"] = 20 - count
        if corp["id"] == "nova_ai": corp["bank_shares"] = bank
    probe = DominionMerger.begin(**opening)
    before = probe.export_state()
    with pytest.raises(ValueError):
        _apply(probe, min(count // 2, bank) + 1)
    assert probe.export_state() == before
    for pairs in range(min(count // 2, bank) + 1):
        merger = DominionMerger.begin(**opening)
        assert merger.current_choice()["max_pairs"] == min(count // 2, bank)
        _apply(merger, pairs)
        final = merger.export_state()
        _supply(final)
        assert final["cash"]["p1"] == 1000 + 660 + (count - 2 * pairs) * 220
        assert final["shares"]["p1"]["nova_ai"] == pairs
        assert final["complete"]


@pytest.mark.parametrize("mutation", ["supply", "negative_cash", "huge_cash", "bool_cash", "huge_price", "duplicate_company", "duplicate_loser", "same_survivor", "unknown_placer", "missing_shares"])
def test_invalid_opening_does_not_change_its_input(mutation):
    opening = copy.deepcopy(VECTORS[0]["opening"])
    if mutation == "supply": opening["companies"][0]["bank_shares"] -= 1
    elif mutation == "negative_cash": opening["players"][0]["cash"] = -1
    elif mutation == "huge_cash": opening["players"][0]["cash"] = 2147483648
    elif mutation == "bool_cash": opening["players"][0]["cash"] = True
    elif mutation == "huge_price": opening["companies"][0]["share_price"] = 1000000000
    elif mutation == "duplicate_company": opening["companies"][0] = dict(opening["companies"][1])
    elif mutation == "duplicate_loser": opening["losing_ids"] *= 2
    elif mutation == "same_survivor": opening["losing_ids"] = [opening["survivor_id"]]
    elif mutation == "unknown_placer": opening["placer_id"] = "p9"
    else: del opening["players"][0]["shares"]["nova_ai"]
    snapshot = copy.deepcopy(opening)
    with pytest.raises((ValueError, KeyError)):
        DominionMerger.begin(**opening)
    assert opening == snapshot


@pytest.mark.parametrize("mutation", ["request_missing", "request_extra", "wrong_timeout_type", "timeout_swaps", "format", "wrong_ruleset"])
def test_invalid_replay_records_and_format_cannot_be_silently_loaded(mutation):
    merger = _begin()
    _apply(merger, 2)
    saved = merger.export_state()
    if mutation == "request_missing": del saved["decisions"][0]["request"]["pairs"]
    elif mutation == "request_extra": saved["decisions"][0]["request"]["extra"] = 1
    elif mutation == "wrong_timeout_type": saved["decisions"][0]["request"]["timed_out"] = 1
    elif mutation == "timeout_swaps": saved["decisions"][0]["request"]["timed_out"] = True
    elif mutation == "format": saved["format_version"] = 2
    else: saved["ruleset_id"] = "classic_v1"
    with pytest.raises(ValueError):
        DominionMerger.from_export(saved)


def test_complete_shared_trace_matches_the_versioned_cross_language_baseline():
    traces = []
    for case in VECTORS:
        merger = _begin(case)
        trace = [merger.export_state()]
        for pairs in case["choices"]:
            merger = DominionMerger.from_export(json.loads(json.dumps(merger.export_state())))
            _apply(merger, pairs)
            trace.append(merger.export_state())
        traces.append(trace)
    digest = hashlib.sha256(json.dumps(traces, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()).hexdigest()
    assert digest == load_json("fixtures/dominion_v1/merger_vectors.json")["trace_sha256"]


def test_pending_choice_survives_a_fresh_python_process_without_repaying_bonus():
    import os
    import subprocess
    import sys
    from app.files import repo_root

    child_environment = dict(os.environ)
    child_environment["PYTHONPATH"] = str(repo_root() / "server") + os.pathsep + child_environment.get("PYTHONPATH", "")
    merger = _begin()
    _apply(merger, 2)
    saved = merger.export_state()
    child = subprocess.run([sys.executable, "-c", """
import json,sys
from app.domain.dominion_merger import DominionMerger
m=DominionMerger.from_export(json.load(sys.stdin))
assert m.choose('m1','p1','volt_grid',2,'a0',0)['duplicate']
assert m.current_choice()['player_id']=='p2'
m.choose('m1','p2','volt_grid',1,'a1',1)
print(json.dumps(m.export_state()))
"""], input=json.dumps(saved), text=True, capture_output=True, check=True, cwd=repo_root(), env=child_environment)
    final = json.loads(child.stdout)
    assert final["complete"] and final["cash"] == {"p1": 1660, "p2": 1440}
    assert final["banks"]["nova_ai"] == 0 and final["banks"]["volt_grid"] == 20
    assert len(final["decisions"]) == 2
    assert merger.export_state() == saved
