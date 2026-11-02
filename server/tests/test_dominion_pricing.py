"""Specification vectors, whole-board price parity and disabled-mode isolation."""
from __future__ import annotations

import copy
import hashlib
import json
from fractions import Fraction

import pytest

from app.domain.dominion_pricing import share_price
from app.domain.offline import OfflineMatch
from app.domain.pricing import share_price as classic_share_price
from app.domain.rulesets import resolve_ruleset
from app.files import load_json

VECTORS = load_json("fixtures/dominion_v1/pricing_vectors.json")


@pytest.mark.parametrize("case", VECTORS["quotes"], ids=lambda case: f"{case['company_id']}-{case['size']}-{case['sentiment']}")
def test_written_specification_quotes(case):
    assert share_price(case["company_id"], case["size"], case["sentiment"]) == case["price"]


def test_all_board_sizes_and_sentiments_match_independent_fraction_reference():
    # Deliberately use the written identities, not parameters read by the calculator.
    profiles = [("nova_ai", 55, 12), ("orbit_pay", 45, 8), ("volt_grid", 60, 10), ("pulse_media", 40, 15), ("evermart", 50, 5)]
    observed = []
    for company_id, growth, sensitivity in profiles:
        for size in range(82):
            for sentiment in range(-2, 3):
                exact_steps = Fraction((100 + growth * size) * (100 + sensitivity * sentiment), 1000)
                expected = 0 if size == 0 else int(exact_steps + Fraction(1, 2)) * 10
                actual = share_price(company_id, size, sentiment)
                assert actual == expected, (company_id, size, sentiment)
                assert actual % 10 == 0 and actual >= 0
                if size > 0:
                    assert actual > share_price(company_id, size - 1, sentiment)
                if sentiment > -2:
                    assert actual >= share_price(company_id, size, sentiment - 1)
                observed.append([company_id, size, sentiment, actual])
    digest = hashlib.sha256(json.dumps(observed, separators=(",", ":")).encode()).hexdigest()
    assert len(observed) == VECTORS["cases"] == 2050
    assert digest == VECTORS["matrix_sha256"]


@pytest.mark.parametrize("company_id,size,sentiment,error", [
    ("unknown", 2, 0, ValueError), ("unknown", 0, 0, ValueError),
    (None, 2, 0, TypeError), (True, 2, 0, TypeError),
    ("nova_ai", -1, 0, ValueError), ("nova_ai", 82, 0, ValueError),
    ("nova_ai", 2, -3, ValueError), ("nova_ai", 0, 3, ValueError),
    ("nova_ai", True, 0, TypeError), ("nova_ai", 2, False, TypeError),
    ("nova_ai", 2.0, 0, TypeError), ("nova_ai", 2, 1.5, TypeError),
    ("nova_ai", "2", 0, TypeError), ("nova_ai", 2, None, TypeError),
])
def test_invalid_input_cannot_fall_back_or_make_an_inactive_quote(company_id, size, sentiment, error):
    with pytest.raises(error):
        share_price(company_id, size, sentiment)


def test_calculation_does_not_enable_dominion_or_change_classic_or_parameters():
    parameters = load_json("fixtures/dominion_v1/pricing.json")
    before = copy.deepcopy(parameters)
    assert share_price("nova_ai", 2, 1) == 240
    assert classic_share_price(2, 1) == 220
    assert parameters == before
    assert resolve_ruleset()["id"] == "classic_v1"
    with pytest.raises(ValueError, match="not implemented"):
        OfflineMatch(7710, ["Rowan", "Quinn"], ruleset_id="dominion_v1")
