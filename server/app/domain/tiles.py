"""Tile-conservation checker for the 81-coordinate catalog.

Error strings are a stable contract shared with the Godot helper:
``count:<n>``, ``duplicate:<coord>``, ``missing:<coord>``, ``unknown:<coord>``.
Count comes first, then each group in ascending coordinate order.
"""

from __future__ import annotations

from collections import Counter
from collections.abc import Sequence

from app.domain.coordinates import all_coordinates


def conservation_errors(
    bag: Sequence[str],
    hands: Sequence[Sequence[str]],
    board: Sequence[str],
) -> list[str]:
    catalog = all_coordinates()
    catalog_set = set(catalog)
    seen: list[str] = list(bag)
    for hand in hands:
        seen.extend(hand)
    seen.extend(board)
    errors: list[str] = []
    if len(seen) != len(catalog):
        errors.append(f"count:{len(seen)}")
    counts = Counter(seen)
    for coordinate in sorted(coordinate for coordinate, count in counts.items() if count > 1):
        errors.append(f"duplicate:{coordinate}")
    for coordinate in sorted(catalog_set - set(seen)):
        errors.append(f"missing:{coordinate}")
    for coordinate in sorted(set(seen) - catalog_set):
        errors.append(f"unknown:{coordinate}")
    return errors
