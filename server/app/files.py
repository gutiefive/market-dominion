"""Locate the repository and load shared JSON contracts."""

from __future__ import annotations

import json
import os
from functools import lru_cache
from pathlib import Path
from typing import Any


def repo_root() -> Path:
    """Return the directory that contains ``shared/protocol/schema.json``."""
    here = Path(__file__).resolve()
    for parent in here.parents:
        if (parent / "shared" / "protocol" / "schema.json").is_file():
            return parent
    raise FileNotFoundError("Could not find shared/protocol/schema.json")


@lru_cache(maxsize=None)
def load_json(relative: str) -> Any:
    """Load a JSON document under ``shared/``.

    ``relative`` uses POSIX separators, for example
    ``fixtures/rules_constants.json``.
    """
    path = repo_root() / "shared" / Path(relative)
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def load_rules() -> dict[str, Any]:
    """Return shared rules constants and reject a structurally impossible file."""
    raw = load_json("fixtures/rules_constants.json")
    if not isinstance(raw, dict):
        raise TypeError("rules_constants.json must be an object")
    columns = int(raw["board_columns"])
    rows = int(raw["board_rows"])
    if int(raw["tile_count"]) != columns * rows:
        raise ValueError("tile_count must equal board_columns * board_rows")
    if len(str(raw["column_labels"])) != columns:
        raise ValueError("column_labels length must equal board_columns")
    if int(raw["players_min"]) > int(raw["players_max"]):
        raise ValueError("players_min cannot exceed players_max")
    if not (int(raw["sentiment_min"]) < 0 < int(raw["sentiment_max"])):
        raise ValueError("sentiment range must cross zero")
    if not (
        int(raw["byte_price_min"])
        < int(raw["byte_initial_price"])
        < int(raw["byte_price_max"])
    ):
        raise ValueError("BYTE initial price must sit inside the clamp range")
    if int(raw["money_step"]) <= 0:
        raise ValueError("money_step must be positive")
    if raw["currency"] != "fictional_dollars":
        raise ValueError("currency must stay fictional_dollars")
    if not isinstance(raw["sectors"], list) or not raw["sectors"]:
        raise ValueError("sectors must be a non-empty list")
    return raw


def database_path() -> Path:
    """SQLite file for schema metadata and persisted rooms."""
    override = os.environ.get("MD_DATABASE_PATH")
    if override:
        return Path(override)
    return repo_root() / "server" / "data" / "market.db"
