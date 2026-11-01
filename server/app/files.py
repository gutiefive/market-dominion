"""Locate the repository and load shared JSON contracts."""

from __future__ import annotations

import json
import os
from functools import lru_cache
from pathlib import Path
from typing import Any


def find_repo_root(start: Path) -> Path:
    """Return the directory that contains ``shared/protocol/schema.json``.

    A checkout walk finds it from ``server/app``. An installed image keeps the
    same tree at ``MD_REPO_ROOT`` (the Dockerfile sets ``/app``) because the
    installed package lives under site-packages and is not next to ``shared/``.
    """
    for parent in (start, *start.parents):
        if (parent / "shared" / "protocol" / "schema.json").is_file():
            return parent
    configured = os.environ.get("MD_REPO_ROOT", "").strip()
    if configured:
        root = Path(configured)
        if (root / "shared" / "protocol" / "schema.json").is_file():
            return root
    raise FileNotFoundError("Could not find shared/protocol/schema.json")


def repo_root() -> Path:
    """Return the directory that contains ``shared/protocol/schema.json``."""
    return find_repo_root(Path(__file__).resolve())


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


class DatabaseURLError(RuntimeError):
    """``DATABASE_URL`` names a database this process will not open."""


def database_path() -> Path:
    """SQLite file for schema metadata and persisted rooms.

    ``DATABASE_URL`` wins when it is set. ``sqlite:///relative`` and
    ``sqlite:////absolute`` are files. ``postgres://`` and ``postgresql://``
    raise ``DatabaseURLError`` and point at ``infra/migrations/0001_rooms.sql``.
    The API does not open PostgreSQL. When ``DATABASE_URL`` is unset,
    ``MD_DATABASE_PATH`` selects the file, otherwise ``server/data/market.db``.
    """
    url = os.environ.get("DATABASE_URL", "").strip()
    if url:
        if url.startswith("sqlite:///"):
            raw = url.removeprefix("sqlite:///")
            if not raw or "?" in raw:
                raise DatabaseURLError(
                    "sqlite DATABASE_URL must be sqlite:///relative.db or sqlite:////absolute/market.db"
                )
            return Path(raw)
        if url.startswith("postgres://") or url.startswith("postgresql://"):
            raise DatabaseURLError(
                "DATABASE_URL is PostgreSQL. This API stores rooms in SQLite. "
                "Apply infra/migrations/0001_rooms.sql with psql when preparing PostgreSQL, "
                "then run the API with MD_DATABASE_PATH or a sqlite:/// DATABASE_URL."
            )
        raise DatabaseURLError(
            "DATABASE_URL must start with sqlite:///. postgres:// is not opened by this process."
        )
    override = os.environ.get("MD_DATABASE_PATH")
    if override:
        return Path(override)
    return repo_root() / "server" / "data" / "market.db"
