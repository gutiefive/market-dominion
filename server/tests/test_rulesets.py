"""Saved-rule compatibility must fail before any gameplay state is reinterpreted."""
from __future__ import annotations

import copy

import pytest

from app.domain.offline import OfflineMatch
from app.domain import rulesets


def test_classic_identity_roundtrip_and_legacy_continuation_match():
    original = OfflineMatch(7710, ["Rowan", "Quinn"])
    original.place(original.active_player()["hand"][0])
    exported = original.export_state()
    assert exported["ruleset_id"] == "classic_v1"
    assert exported["ruleset_fingerprint"] == rulesets.classic_fingerprint()
    current = OfflineMatch.from_export(exported)
    legacy = copy.deepcopy(exported)
    del legacy["ruleset_id"]
    del legacy["ruleset_fingerprint"]
    restored = OfflineMatch.from_export(legacy)
    for table in (original, current, restored):
        table.pass_market()
        table.pass_market()
        table.place(table.active_player()["hand"][0])
        assert table.economy_errors() == []
    assert original.export_state() == current.export_state() == restored.export_state()
    assert "ruleset_id" not in original.snapshot()  # Existing model fixture/snapshot shape stays unchanged.


@pytest.mark.parametrize("identity", ["dominion_v1", "classic_v2", "Classic", "", None, True])
def test_unimplemented_or_unknown_identity_never_falls_back(identity):
    with pytest.raises(ValueError):
        OfflineMatch(7710, ["Rowan", "Quinn"], ruleset_id=identity)
    saved = OfflineMatch(7710, ["Rowan", "Quinn"]).export_state()
    saved["ruleset_id"] = identity
    with pytest.raises(ValueError):
        OfflineMatch.from_export(saved)


@pytest.mark.parametrize("mutation", ["missing_id", "missing_hash", "bad_hash", "null_hash"])
def test_explicit_corrupt_identity_is_not_treated_as_legacy(mutation):
    saved = OfflineMatch(7710, ["Rowan", "Quinn"]).export_state()
    if mutation == "missing_id":
        del saved["ruleset_id"]
    elif mutation == "missing_hash":
        del saved["ruleset_fingerprint"]
    else:
        saved["ruleset_fingerprint"] = None if mutation == "null_hash" else "0" * 64
    with pytest.raises(ValueError):
        OfflineMatch.from_export(saved)


def test_fixture_drift_is_rejected_even_for_an_unversioned_legacy_save(monkeypatch):
    saved = OfflineMatch(7710, ["Rowan", "Quinn"]).export_state()
    legacy = {key: value for key, value in saved.items() if not key.startswith("ruleset_")}
    changed = dict(rulesets.load_rules())
    changed["share_price_per_tile"] += 1
    monkeypatch.setattr(rulesets, "load_rules", lambda: changed)
    with pytest.raises(ValueError, match="new ruleset"):
        OfflineMatch.from_export(legacy)
    with pytest.raises(ValueError, match="new ruleset"):
        OfflineMatch(7710, ["Rowan", "Quinn"])


def test_transport_changes_do_not_redefine_classic_equations(monkeypatch):
    expected = rulesets.classic_fingerprint()
    changed = dict(rulesets.load_rules())
    changed.update(protocol_version="0.2.0", api_port=9999, command_byte_limit=32768)
    monkeypatch.setattr(rulesets, "load_rules", lambda: changed)
    assert rulesets.classic_fingerprint() == expected
    assert rulesets.resolve_ruleset()["id"] == "classic_v1"
