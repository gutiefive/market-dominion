"""Winner ordering once net worth has already been totaled.

Assumption A10: higher net worth, then higher cash, then more active shares,
then the earlier opening turn (lower ``turn_order_index``). Indexes are unique.
This does not compute net worth from a board.
"""

from __future__ import annotations


def _as_int(name: str, value: object) -> int:
    if isinstance(value, bool) or not isinstance(value, int):
        raise TypeError(f"{name} must be an int")
    return value


def rank_players(players: list[dict[str, object]]) -> list[str]:
    """Return player ids from first place to last place."""
    if not players:
        raise ValueError("at least one player is required")
    indexes: list[int] = []
    normalized: list[dict[str, object]] = []
    for player in players:
        player_id = str(player["id"])
        if not player_id:
            raise ValueError("player id is required")
        index = _as_int("turn_order_index", player["turn_order_index"])
        indexes.append(index)
        normalized.append(
            {
                "id": player_id,
                "net_worth": _as_int("net_worth", player["net_worth"]),
                "cash": _as_int("cash", player["cash"]),
                "active_shares": _as_int("active_shares", player["active_shares"]),
                "turn_order_index": index,
            }
        )
    if len(indexes) != len(set(indexes)):
        raise ValueError("turn_order_index values must be unique")
    ordered = sorted(
        normalized,
        key=lambda player: (
            int(player["net_worth"]),
            int(player["cash"]),
            int(player["active_shares"]),
            -int(player["turn_order_index"]),
        ),
        reverse=True,
    )
    return [str(player["id"]) for player in ordered]
