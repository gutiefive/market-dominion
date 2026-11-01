"""Local pass-and-play deal and placement.

Assumption A16: shuffle players in entry order, then shuffle the coordinate
catalog into the bag, then deal round-robin one tile at a time for five rounds.
Bag index 0 is the next draw.

Assumption A17: a placement marks the cell occupied and leaves it unincorporated.
Founding, growth, mergers, and market actions are not resolved here. A turn
places one held tile, draws one bag tile when any remain, then advances. An
empty hand is the only skip. Display names are unique nicknames.
"""

from __future__ import annotations

import re
from typing import Any

from app.domain.coordinates import all_coordinates
from app.domain.rng import MatchRng, shuffle
from app.domain.tiles import conservation_errors
from app.files import load_rules

_NICKNAME = re.compile(r"^[A-Za-z0-9][A-Za-z0-9 _-]{0,23}$")


class OfflineMatch:
    def __init__(self, seed: int, names: list[str]) -> None:
        rules = load_rules()
        cleaned = [str(name) for name in names]
        minimum = int(rules["players_min"])
        maximum = int(rules["players_max"])
        if not minimum <= len(cleaned) <= maximum:
            raise ValueError("player count")
        seen: set[str] = set()
        for name in cleaned:
            if _NICKNAME.fullmatch(name) is None:
                raise ValueError("nickname")
            if name in seen:
                raise ValueError("duplicate name")
            seen.add(name)
        self.seed = seed
        self.hand_size = int(rules["starting_hand_size"])
        self.starting_cash = int(rules["starting_cash"])
        rng = MatchRng(seed)
        roster = [
            {
                "id": f"p{index + 1}",
                "display_name": name,
                "hand": [],
            }
            for index, name in enumerate(cleaned)
        ]
        self.players: list[dict[str, Any]] = shuffle(roster, rng)
        for index, player in enumerate(self.players):
            player["turn_order_index"] = index
            player["cash"] = self.starting_cash
        self.bag: list[str] = shuffle(all_coordinates(), rng)
        self.occupied: dict[str, bool] = {coordinate: False for coordinate in all_coordinates()}
        for _ in range(self.hand_size):
            for player in self.players:
                if not self.bag:
                    break
                player["hand"].append(self.bag.pop(0))
        self.turn_index = 0
        self.round_number = 1
        self.log: list[str] = []

    def active_player(self) -> dict[str, Any]:
        return self.players[self.turn_index]

    def place(self, coordinate: str) -> dict[str, Any]:
        player = self.active_player()
        if coordinate not in player["hand"]:
            raise ValueError("tile not in hand")
        if self.occupied.get(coordinate, False):
            raise ValueError("cell occupied")
        player["hand"].remove(coordinate)
        self.occupied[coordinate] = True
        drew = False
        if self.bag:
            player["hand"].append(self.bag.pop(0))
            drew = True
        if drew:
            message = f"{player['display_name']} placed {coordinate} and drew from the bag."
        else:
            message = f"{player['display_name']} placed {coordinate}. The bag is empty."
        self.log.append(message)
        self._advance()
        return {"placed": coordinate, "drew": drew, "log": message}

    def pass_turn(self) -> dict[str, Any]:
        player = self.active_player()
        if player["hand"]:
            raise ValueError("hand still has a tile")
        message = f"{player['display_name']} has no tile to place."
        self.log.append(message)
        self._advance()
        return {"passed": True, "log": message}

    def _advance(self) -> None:
        self.turn_index += 1
        if self.turn_index >= len(self.players):
            self.turn_index = 0
            self.round_number += 1

    def conservation(self) -> list[str]:
        occupied = [coordinate for coordinate, filled in self.occupied.items() if filled]
        hands = [list(player["hand"]) for player in self.players]
        return conservation_errors(self.bag, hands, occupied)

    def snapshot(self) -> dict[str, Any]:
        catalog = all_coordinates()
        return {
            "seed": self.seed,
            "round_number": self.round_number,
            "active_player": self.active_player()["display_name"],
            "turn_order": [player["display_name"] for player in self.players],
            "ids": [player["id"] for player in self.players],
            "bag_size": len(self.bag),
            "bag": list(self.bag),
            "occupied": [coordinate for coordinate in catalog if self.occupied[coordinate]],
            "hands": {player["display_name"]: list(player["hand"]) for player in self.players},
            "log": list(self.log),
        }
