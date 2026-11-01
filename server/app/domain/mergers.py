"""Merger bonuses. Cash stays in integer dollars.

Majority pool is 2 × the losing company's snapshotted share price.
Minority pool is 1 × that price.

A player with shares of 0 is not a holder. The bank is not a holder.
One positive holder receives both pools. A tie for the most shares
combines the pools and splits them across those leaders; everyone else
gets nothing. Otherwise the majority pool goes to the unique leader and
the minority pool goes to every player who holds the second-highest count.

Indivisible dollars are handed out $1 at a time by ascending player id
(assumption A10). No holders means no bonus.
"""

from __future__ import annotations


def bonus_payouts(price: int, holdings: dict[str, int]) -> dict[str, int]:
    """Map player id to a bonus. Missing ids receive nothing."""
    if isinstance(price, bool) or not isinstance(price, int) or price < 0:
        raise ValueError("price")
    positive = {str(player_id): int(count) for player_id, count in holdings.items() if int(count) > 0}
    if not positive or price == 0:
        return {}
    top = max(positive.values())
    leaders = [player_id for player_id, count in positive.items() if count == top]
    if len(positive) == 1:
        return {leaders[0]: 3 * price}
    if len(leaders) >= 2:
        return _split(3 * price, leaders)
    second = max(count for count in positive.values() if count < top)
    runners = [player_id for player_id, count in positive.items() if count == second]
    payouts = _split(2 * price, leaders)
    for player_id, amount in _split(price, runners).items():
        payouts[player_id] = payouts.get(player_id, 0) + amount
    return payouts


def _split(amount: int, player_ids: list[str]) -> dict[str, int]:
    ordered = sorted({str(player_id) for player_id in player_ids})
    if not ordered:
        return {}
    base = amount // len(ordered)
    remainder = amount % len(ordered)
    return {
        player_id: base + (1 if index < remainder else 0)
        for index, player_id in enumerate(ordered)
    }
