"""Orthogonal districts. Diagonals do not connect.

The component is returned in catalog order so both engines agree.
"""

from __future__ import annotations

from app.domain.coordinates import all_coordinates
from app.files import load_rules


def neighbors(coordinate: str) -> list[str]:
    rules = load_rules()
    labels = str(rules["column_labels"])
    rows = int(rules["board_rows"])
    if len(coordinate) < 2 or coordinate[0] not in labels:
        return []
    column = labels.index(coordinate[0])
    try:
        row = int(coordinate[1:])
    except ValueError:
        return []
    found: list[str] = []
    for delta_column, delta_row in ((0, -1), (0, 1), (-1, 0), (1, 0)):
        next_column = column + delta_column
        next_row = row + delta_row
        if 0 <= next_column < len(labels) and 1 <= next_row <= rows:
            found.append(f"{labels[next_column]}{next_row}")
    return found


def component(origin: str, occupied: set[str]) -> list[str]:
    """Occupied cells connected to origin, including origin, in catalog order."""
    if origin not in occupied:
        return []
    seen: set[str] = set()
    stack = [origin]
    while stack:
        current = stack.pop()
        if current in seen or current not in occupied:
            continue
        seen.add(current)
        stack.extend(neighbors(current))
    return [coordinate for coordinate in all_coordinates() if coordinate in seen]
