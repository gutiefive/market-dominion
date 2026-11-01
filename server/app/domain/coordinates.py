"""Canonical unshuffled district coordinates.

Assumption A1: columns A–I run left to right, rows 1–9 run top to bottom,
and the catalog is row-major (A1, B1, … I1, A2, … I9). Seeded shuffle is
not implemented.
"""

from __future__ import annotations

from app.files import load_rules


def all_coordinates() -> list[str]:
    rules = load_rules()
    columns = str(rules["column_labels"])
    rows = int(rules["board_rows"])
    coordinates = [
        f"{column}{row}" for row in range(1, rows + 1) for column in columns
    ]
    if len(coordinates) != int(rules["tile_count"]):
        raise RuntimeError("coordinate catalog does not match tile_count")
    if len(set(coordinates)) != len(coordinates):
        raise RuntimeError("coordinate catalog contains duplicates")
    return coordinates
