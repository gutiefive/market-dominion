"""Rewrite generated fixtures from the domain builders.

Run from anywhere:

    python scripts/dump_fixtures.py
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "server"))

from app.domain.coordinates import all_coordinates  # noqa: E402
from app.domain.setup import build_lobby_snapshot  # noqa: E402
from app.files import repo_root  # noqa: E402


def _write(path: Path, payload: object) -> None:
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    print(path.relative_to(repo_root()))


def main() -> None:
    root = repo_root()
    fixtures = root / "shared" / "fixtures"
    _write(fixtures / "coordinates.json", all_coordinates())
    _write(fixtures / "sample_lobby_state.json", build_lobby_snapshot("match_demo", 7710))


if __name__ == "__main__":
    main()
