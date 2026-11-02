"""Explicit rule identity. Unknown/unimplemented rules never fall back to Classic."""

from __future__ import annotations

import hashlib
import json
from typing import Any

from app.files import load_json, load_rules

CLASSIC = "classic_v1"


def classic_fingerprint() -> str:
    manifest = load_json("fixtures/rulesets.json")
    excluded = manifest["classic_fingerprint_excluded_constants"]
    payload = {
        "constants": {key: value for key, value in load_rules().items() if key not in excluded},
        "corporations": load_json("fixtures/corporations.json")["corporations"],
        "events": load_json("fixtures/round_events.json")["events"],
    }
    canonical = json.dumps(_integer_numbers(payload), sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()


def resolve_ruleset(ruleset_id: str = CLASSIC) -> dict[str, Any]:
    if not isinstance(ruleset_id, str):
        raise ValueError("ruleset_id must be a supported identifier")
    manifest = load_json("fixtures/rulesets.json")
    entry = next((item for item in manifest["rulesets"] if item["id"] == ruleset_id), None)
    if entry is None:
        raise ValueError("unknown ruleset_id")
    if ruleset_id != CLASSIC or not entry["playable"]:
        raise ValueError("ruleset is not implemented")
    if classic_fingerprint() != entry["fingerprint"]:
        raise ValueError("Classic fixtures do not match classic_v1; a new ruleset is required")
    return dict(entry)


def restore_ruleset(data: dict[str, Any]) -> dict[str, Any]:
    has_id = "ruleset_id" in data
    has_fingerprint = "ruleset_fingerprint" in data
    if not has_id and not has_fingerprint:
        return resolve_ruleset()  # Only genuinely pre-identity saves use the legacy default.
    if not has_id or not has_fingerprint:
        raise ValueError("incomplete saved ruleset identity")
    entry = resolve_ruleset(data["ruleset_id"])
    if data["ruleset_fingerprint"] != entry["fingerprint"]:
        raise ValueError("saved ruleset fingerprint does not match the installed ruleset")
    return entry


def _integer_numbers(value: Any) -> Any:
    if isinstance(value, float) and value.is_integer():
        return int(value)
    if isinstance(value, dict):
        return {key: _integer_numbers(item) for key, item in value.items()}
    if isinstance(value, list):
        return [_integer_numbers(item) for item in value]
    return value
