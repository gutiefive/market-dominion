"""Local pass-and-play deal, founding, growth, mergers, and two market actions.

Assumption A16: shuffle seats, then the bag, then deal five tiles round-robin.

Assumption A18: a turn places one tile (or skips an empty hand), resolves
founding, growth, or a merger, then allows two market actions, then draws.
Sector sentiment stays 0 unless a test sets it. No round event is drawn.

Assumption A19: the survivor is the largest pre-placement company. A tie
among those largest companies waits for the placer. Every other company in
the component is bought out, in fixture order, before the survivor is
repriced once.

Assumption A20: after the opening deal, the same generator shuffles the
10-card event deck. A completed round draws one card, reclamps sentiment,
and reprices BYTE and active shares. An empty deck is shuffled again.
A final round lets the remaining seats finish one turn, applies that one
event, and scores. It does not start another round.
"""

from __future__ import annotations

import re
from typing import Any

from app.domain.board import component
from app.domain.coordinates import all_coordinates
from app.domain.corporations import load_corporations
from app.domain.events import apply_sector_deltas, load_round_events, sectors
from app.domain.mergers import bonus_payouts
from app.domain.pricing import byte_price_after_delta, share_price
from app.domain.scoring import rank_players
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
        self.rules = rules
        self.seed = seed
        self.hand_size = int(rules["starting_hand_size"])
        self.starting_cash = int(rules["starting_cash"])
        self.market_limit = int(rules["market_actions_per_turn"])
        self.share_supply = int(rules["corporation_share_supply"])
        self.byte_supply = int(rules["byte_supply"])
        self.byte_price = int(rules["byte_initial_price"])
        self.byte_exchange = self.byte_supply
        self.end_size = int(rules["end_company_size"])
        self.end_occupied = int(rules["end_occupied_tiles"])
        self.sentiment = {str(sector): 0 for sector in rules["sectors"]}
        self.corporations: list[dict[str, Any]] = []
        share_template: dict[str, int] = {}
        for source in load_corporations():
            corp_id = str(source["id"])
            self.corporations.append(
                {
                    "id": corp_id,
                    "name": str(source["name"]),
                    "sector": str(source["sector"]),
                    "active": False,
                    "bank_shares": self.share_supply,
                    "share_price": 0,
                    "size": 0,
                    "cells": [],
                }
            )
            share_template[corp_id] = 0
        rng = MatchRng(seed)
        self.rng = rng
        roster = [
            {
                "id": f"p{index + 1}",
                "display_name": name,
                "hand": [],
                "shares": dict(share_template),
                "byte_count": 0,
            }
            for index, name in enumerate(cleaned)
        ]
        self.players: list[dict[str, Any]] = shuffle(roster, rng)
        for index, player in enumerate(self.players):
            player["turn_order_index"] = index
            player["cash"] = self.starting_cash
        self.bag: list[str] = shuffle(all_coordinates(), rng)
        self.occupied: dict[str, bool] = {coordinate: False for coordinate in all_coordinates()}
        self.company_of: dict[str, str] = {}
        for _ in range(self.hand_size):
            for player in self.players:
                if not self.bag:
                    break
                player["hand"].append(self.bag.pop(0))
        self.events: list[dict[str, Any]] = shuffle(load_round_events(), rng)
        self.event_ids: list[str] = []
        self.turn_index = 0
        self.round_number = 1
        self.phase = "place"
        self.final_round = False
        self.market_actions_left = 0
        self.pending: list[str] = []
        self.pending_options: list[str] = []
        self.pending_tile = ""
        self.ranking: list[str] = []
        self.ledger: list[dict[str, Any]] = []
        self.log: list[str] = []

    def active_player(self) -> dict[str, Any]:
        return self.players[self.turn_index]

    def place(self, coordinate: str) -> dict[str, Any]:
        if self.phase == "completed":
            raise ValueError("the match is over")
        if self.phase != "place":
            raise ValueError("not the placement step")
        player = self.active_player()
        if coordinate not in player["hand"]:
            raise ValueError("tile not in hand")
        if self.occupied.get(coordinate, False):
            raise ValueError("cell occupied")
        occupied = {cell for cell, filled in self.occupied.items() if filled}
        occupied.add(coordinate)
        touched = component(coordinate, occupied)
        company_ids: list[str] = []
        for cell in touched:
            corp_id = self.company_of.get(cell)
            if corp_id and corp_id not in company_ids:
                company_ids.append(corp_id)
        player["hand"].remove(coordinate)
        self.occupied[coordinate] = True
        if len(company_ids) >= 2:
            involved = [corp for corp in self.corporations if corp["id"] in company_ids]
            return self._begin_merger(coordinate, player, touched, involved)
        if len(company_ids) == 1:
            corp = self._corp(company_ids[0])
            for cell in touched:
                self.company_of[cell] = corp["id"]
            self._reprice(corp)
            self._enter_market()
            message = (
                f"{player['display_name']} placed {coordinate} and grew {corp['name']} "
                f"to size {corp['size']}. Share price is ${corp['share_price']}."
            )
            self.log.append(message)
            return {"placed": coordinate, "resolution": "growth", "log": message}
        if len(touched) >= 2 and self._inactive():
            self.pending = list(touched)
            self.phase = "choose_founder"
            message = (
                f"{player['display_name']} placed {coordinate}. "
                f"Choose a company for the {len(touched)}-district cluster."
            )
            self.log.append(message)
            return {"placed": coordinate, "resolution": "choose_founder", "log": message}
        if len(touched) >= 2:
            message = (
                f"{player['display_name']} placed {coordinate}. "
                f"The {len(touched)}-district cluster stays unincorporated."
            )
        else:
            message = f"{player['display_name']} placed {coordinate}. The district stays unincorporated."
        self._enter_market()
        self.log.append(message)
        return {"placed": coordinate, "resolution": "unincorporated", "log": message}

    def choose_founder(self, corp_id: str) -> dict[str, Any]:
        if self.phase == "completed":
            raise ValueError("the match is over")
        if self.phase != "choose_founder":
            raise ValueError("no company choice is pending")
        corp = self._corp(corp_id)
        if corp is None:
            raise ValueError("unknown company")
        if corp["active"]:
            raise ValueError("company is already active")
        player = self.active_player()
        for cell in self.pending:
            self.company_of[cell] = corp["id"]
        self.pending = []
        self.pending_options = []
        self.pending_tile = ""
        self._reprice(corp)
        granted = False
        if int(corp["bank_shares"]) > 0:
            corp["bank_shares"] = int(corp["bank_shares"]) - 1
            player["shares"][corp["id"]] = int(player["shares"][corp["id"]]) + 1
            granted = True
        self._enter_market()
        if granted:
            message = (
                f"{player['display_name']} founded {corp['name']} on {corp['size']} districts "
                "and received one founder share."
            )
        else:
            message = (
                f"{player['display_name']} founded {corp['name']} on {corp['size']} districts. "
                "The bank had no share to grant."
            )
        self.log.append(message)
        return {"founded": corp["id"], "granted": granted, "log": message}

    def choose_survivor(self, corp_id: str) -> dict[str, Any]:
        if self.phase == "completed":
            raise ValueError("the match is over")
        if self.phase != "choose_survivor":
            raise ValueError("no survivor choice is pending")
        if self._corp(corp_id) is None:
            raise ValueError("unknown company")
        if corp_id not in self.pending_options:
            raise ValueError("company is not a tied survivor")
        return self._resolve_merger(corp_id, self.pending_tile, self.active_player(), True)

    def pass_turn(self) -> dict[str, Any]:
        if self.phase == "completed":
            raise ValueError("the match is over")
        if self.phase != "place":
            raise ValueError("not the placement step")
        player = self.active_player()
        if player["hand"]:
            raise ValueError("hand still has a tile")
        message = f"{player['display_name']} has no tile to place."
        self.log.append(message)
        self._enter_market()
        return {"passed": True, "log": message}

    def buy_share(self, corp_id: str) -> dict[str, Any]:
        player, corp, price = self._open_share_trade(corp_id)
        if int(corp["bank_shares"]) < 1:
            raise ValueError("no share in the bank")
        if int(player["cash"]) < price:
            raise ValueError("not enough cash")
        player["cash"] = int(player["cash"]) - price
        corp["bank_shares"] = int(corp["bank_shares"]) - 1
        player["shares"][corp["id"]] = int(player["shares"][corp["id"]]) + 1
        message = f"{player['display_name']} bought 1 {corp['name']} share for ${price}."
        return self._spend_action(message)

    def sell_share(self, corp_id: str) -> dict[str, Any]:
        player, corp, price = self._open_share_trade(corp_id)
        if int(player["shares"][corp["id"]]) < 1:
            raise ValueError("no share to sell")
        player["shares"][corp["id"]] = int(player["shares"][corp["id"]]) - 1
        corp["bank_shares"] = int(corp["bank_shares"]) + 1
        player["cash"] = int(player["cash"]) + price
        message = f"{player['display_name']} sold 1 {corp['name']} share for ${price}."
        return self._spend_action(message)

    def buy_byte(self) -> dict[str, Any]:
        player = self._open_market()
        price = self.byte_price
        if self.byte_exchange < 1:
            raise ValueError("no BYTE in the exchange")
        if int(player["cash"]) < price:
            raise ValueError("not enough cash")
        player["cash"] = int(player["cash"]) - price
        player["byte_count"] = int(player["byte_count"]) + 1
        self.byte_exchange -= 1
        message = f"{player['display_name']} bought 1 BYTE for ${price}."
        return self._spend_action(message)

    def sell_byte(self) -> dict[str, Any]:
        player = self._open_market()
        price = self.byte_price
        if int(player["byte_count"]) < 1:
            raise ValueError("no BYTE to sell")
        player["byte_count"] = int(player["byte_count"]) - 1
        player["cash"] = int(player["cash"]) + price
        self.byte_exchange += 1
        message = f"{player['display_name']} sold 1 BYTE for ${price}."
        return self._spend_action(message)

    def pass_market(self) -> dict[str, Any]:
        player = self._open_market()
        message = f"{player['display_name']} passed a market action."
        return self._spend_action(message)

    def economy_errors(self) -> list[str]:
        errors = list(self.conservation())
        catalog = all_coordinates()
        occupied = {cell for cell, filled in self.occupied.items() if filled}
        holdings: dict[str, int] = {corp["id"]: 0 for corp in self.corporations}
        byte_held = 0
        for player in self.players:
            if int(player["cash"]) < 0:
                errors.append(f"negative cash:{player['id']}")
            if int(player["byte_count"]) < 0:
                errors.append(f"negative byte:{player['id']}")
            byte_held += int(player["byte_count"])
            for corp_id, count in player["shares"].items():
                if int(count) < 0:
                    errors.append(f"negative shares:{player['id']}:{corp_id}")
                holdings[corp_id] = holdings.get(corp_id, 0) + int(count)
        if self.byte_exchange + byte_held != self.byte_supply:
            errors.append("byte supply")
        if self.byte_exchange < 0:
            errors.append("negative exchange")
        for corp in self.corporations:
            corp_id = corp["id"]
            cells = [cell for cell in catalog if self.company_of.get(cell) == corp_id]
            if corp["cells"] != cells:
                errors.append(f"{corp_id}: cells")
            if int(corp["size"]) != len(cells):
                errors.append(f"{corp_id}: size")
            outstanding = holdings.get(corp_id, 0)
            if int(corp["bank_shares"]) + outstanding != self.share_supply:
                errors.append(f"{corp_id}: supply")
            if int(corp["bank_shares"]) < 0:
                errors.append(f"{corp_id}: negative bank")
            expected_price = share_price(len(cells), self.sentiment[corp["sector"]]) if cells else 0
            if int(corp["share_price"]) != expected_price:
                errors.append(f"{corp_id}: price")
            if corp["active"] != (len(cells) >= 2):
                errors.append(f"{corp_id}: active flag")
            if not corp["active"] and (cells or outstanding or int(corp["bank_shares"]) != self.share_supply):
                errors.append(f"{corp_id}: inactive inventory")
        seen: set[str] = set()
        for coordinate in catalog:
            if coordinate not in occupied or coordinate in seen:
                continue
            touched = component(coordinate, occupied)
            seen.update(touched)
            present = []
            for cell in touched:
                corp_id = self.company_of.get(cell)
                if corp_id and corp_id not in present:
                    present.append(corp_id)
            if len(present) > 1 and not (
                self.phase == "choose_survivor" and set(touched) == set(self.pending)
            ):
                errors.append("mixed:" + ",".join(present))
        for cell, corp_id in self.company_of.items():
            if not self.occupied.get(cell, False):
                errors.append(f"empty company cell:{cell}")
            if corp_id not in holdings:
                errors.append(f"unknown company on {cell}")
        return errors

    def conservation(self) -> list[str]:
        occupied = [coordinate for coordinate, filled in self.occupied.items() if filled]
        hands = [list(player["hand"]) for player in self.players]
        return conservation_errors(self.bag, hands, occupied)

    def snapshot(self) -> dict[str, Any]:
        catalog = all_coordinates()
        return {
            "seed": self.seed,
            "round_number": self.round_number,
            "phase": self.phase,
            "market_actions_left": self.market_actions_left,
            "active_player": self.active_player()["display_name"],
            "turn_order": [player["display_name"] for player in self.players],
            "ids": [player["id"] for player in self.players],
            "bag_size": len(self.bag),
            "bag": list(self.bag),
            "occupied": [coordinate for coordinate in catalog if self.occupied[coordinate]],
            "companies_on_board": [
                {"coordinate": coordinate, "company_id": self.company_of[coordinate]}
                for coordinate in catalog
                if coordinate in self.company_of
            ],
            "hands": {player["display_name"]: list(player["hand"]) for player in self.players},
            "cash": {player["display_name"]: int(player["cash"]) for player in self.players},
            "shares": {
                player["display_name"]: dict(player["shares"]) for player in self.players
            },
            "byte": {player["display_name"]: int(player["byte_count"]) for player in self.players},
            "byte_price": self.byte_price,
            "byte_exchange": self.byte_exchange,
            "final_round": self.final_round,
            "event_ids": list(self.event_ids),
            "ranking": list(self.ranking),
            "corporations": [
                {
                    "id": corp["id"],
                    "active": corp["active"],
                    "size": corp["size"],
                    "bank_shares": corp["bank_shares"],
                    "share_price": corp["share_price"],
                    "cells": list(corp["cells"]),
                }
                for corp in self.corporations
            ],
            "pending": list(self.pending),
            "pending_options": list(self.pending_options),
            "log": list(self.log),
        }

    def _corp(self, corp_id: str) -> dict[str, Any] | None:
        for corp in self.corporations:
            if corp["id"] == corp_id:
                return corp
        return None

    def _inactive(self) -> list[dict[str, Any]]:
        return [corp for corp in self.corporations if not corp["active"]]

    def _reprice(self, corp: dict[str, Any]) -> None:
        catalog = all_coordinates()
        cells = [cell for cell in catalog if self.company_of.get(cell) == corp["id"]]
        corp["cells"] = cells
        corp["size"] = len(cells)
        corp["active"] = len(cells) >= 2
        if corp["active"]:
            corp["share_price"] = share_price(len(cells), self.sentiment[corp["sector"]])
        else:
            corp["share_price"] = 0

    def _begin_merger(
        self,
        coordinate: str,
        player: dict[str, Any],
        touched: list[str],
        involved: list[dict[str, Any]],
    ) -> dict[str, Any]:
        top = max(int(corp["size"]) for corp in involved)
        tied = [corp for corp in involved if int(corp["size"]) == top]
        self.pending = list(touched)
        self.pending_tile = coordinate
        if len(tied) > 1:
            self.pending_options = [corp["id"] for corp in tied]
            self.phase = "choose_survivor"
            message = (
                f"{player['display_name']} placed {coordinate}. Choose the survivor. "
                f"{_join_names([corp['name'] for corp in tied])} are tied at size {top}."
            )
            self.log.append(message)
            return {"placed": coordinate, "resolution": "choose_survivor", "log": message}
        self.pending_options = [tied[0]["id"]]
        return self._resolve_merger(tied[0]["id"], coordinate, player, False)

    def _resolve_merger(
        self,
        survivor_id: str,
        coordinate: str,
        player: dict[str, Any],
        chosen: bool,
    ) -> dict[str, Any]:
        involved_ids: list[str] = []
        for cell in self.pending:
            corp_id = self.company_of.get(cell)
            if corp_id and corp_id not in involved_ids:
                involved_ids.append(corp_id)
        losers = [corp for corp in self.corporations if corp["id"] in involved_ids and corp["id"] != survivor_id]
        snapshots = {
            corp["id"]: {
                "price": int(corp["share_price"]),
                "holdings": {holder["id"]: int(holder["shares"][corp["id"]]) for holder in self.players},
            }
            for corp in losers
        }
        loser_ids = {corp["id"] for corp in losers}
        for cell in self.pending:
            self.company_of[cell] = survivor_id
        for cell, corp_id in list(self.company_of.items()):
            if corp_id in loser_ids:
                del self.company_of[cell]
        messages: list[str] = []
        for corp in losers:
            price = int(snapshots[corp["id"]]["price"])
            holdings = snapshots[corp["id"]]["holdings"]
            payouts = bonus_payouts(price, holdings)
            if not any(int(count) > 0 for count in holdings.values()):
                messages.append(f"{corp['name']} paid no merger bonus.")
            else:
                for holder in sorted(self.players, key=lambda item: str(item["id"])):
                    amount = int(payouts.get(holder["id"], 0))
                    if amount <= 0:
                        continue
                    holder["cash"] = int(holder["cash"]) + amount
                    messages.append(f"{holder['display_name']} received a ${amount} bonus on {corp['name']}.")
            for holder in sorted(self.players, key=lambda item: str(item["id"])):
                count = int(holdings[holder["id"]])
                if count <= 0:
                    continue
                proceeds = count * price
                holder["shares"][corp["id"]] = 0
                holder["cash"] = int(holder["cash"]) + proceeds
                messages.append(
                    f"{holder['display_name']} liquidated {count} {corp['name']} shares for ${proceeds}."
                )
            corp["bank_shares"] = self.share_supply
            self._reprice(corp)
        survivor = self._corp(survivor_id)
        assert survivor is not None
        self._reprice(survivor)
        self.pending = []
        self.pending_options = []
        self.pending_tile = ""
        self._enter_market()
        if chosen:
            summary = (
                f"{player['display_name']} kept {survivor['name']}. "
                f"{survivor['name']} is size {survivor['size']}. Share price is ${survivor['share_price']}."
            )
        else:
            summary = (
                f"{player['display_name']} placed {coordinate}. {survivor['name']} survives the merger "
                f"at size {survivor['size']}. Share price is ${survivor['share_price']}."
            )
        self.log.append(summary)
        self.log.extend(messages)
        return {"placed": coordinate, "resolution": "merger", "survivor": survivor_id, "log": summary}

    def _enter_market(self) -> None:
        self.phase = "market"
        self.market_actions_left = self.market_limit

    def _open_market(self) -> dict[str, Any]:
        if self.phase == "completed":
            raise ValueError("the match is over")
        if self.phase != "market":
            raise ValueError("not the market step")
        if self.market_actions_left <= 0:
            raise ValueError("no market action left")
        return self.active_player()

    def _open_share_trade(self, corp_id: str) -> tuple[dict[str, Any], dict[str, Any], int]:
        player = self._open_market()
        corp = self._corp(corp_id)
        if corp is None:
            raise ValueError("unknown company")
        if not corp["active"] or int(corp["share_price"]) <= 0:
            raise ValueError("company is not active")
        return player, corp, int(corp["share_price"])

    def _spend_action(self, message: str) -> dict[str, Any]:
        self.log.append(message)
        self.market_actions_left -= 1
        finished = False
        if self.market_actions_left == 0:
            self._finish_turn()
            finished = True
        return {"log": message, "turn_finished": finished}

    def _finish_turn(self) -> None:
        player = self.active_player()
        if self.bag:
            player["hand"].append(self.bag.pop(0))
            self.log.append(f"{player['display_name']} drew from the bag.")
        else:
            self.log.append(f"{player['display_name']} drew nothing. The bag is empty.")
        self.phase = "place"
        self.market_actions_left = 0
        self.pending = []
        self.pending_options = []
        self.pending_tile = ""
        closing = self.turn_index + 1 >= len(self.players)
        if not self.final_round and self._end_triggered():
            self.final_round = True
            if closing:
                self.log.append("Final round. The round is complete.")
            else:
                self.log.append(
                    "Final round. Everyone who has not acted this round still takes one turn."
                )
        self.turn_index += 1
        if self.turn_index >= len(self.players):
            self.turn_index = 0
            self._apply_round_event()
            if self.final_round:
                self._score_game()
                return
            self.round_number += 1

    def _end_triggered(self) -> bool:
        if any(bool(corp["active"]) and int(corp["size"]) >= self.end_size for corp in self.corporations):
            return True
        occupied = sum(1 for filled in self.occupied.values() if filled)
        if occupied >= self.end_occupied:
            return True
        return not self.bag and all(not player["hand"] for player in self.players)

    def _apply_round_event(self) -> None:
        if not self.events:
            self.events = shuffle(load_round_events(), self.rng)
        event = self.events.pop(0)
        self.event_ids.append(str(event["id"]))
        self.sentiment = apply_sector_deltas(self.sentiment, event["sector_deltas"])
        for corp in self.corporations:
            self._reprice(corp)
        self.byte_price = byte_price_after_delta(self.byte_price, int(event["byte_delta_percent"]))
        parts: list[str] = []
        deltas = event["sector_deltas"]
        for sector in sectors():
            if sector not in deltas:
                continue
            value = int(self.sentiment[sector])
            shown = f"+{value}" if value > 0 else str(value)
            parts.append(f"{_SECTOR_LABELS[sector]} {shown}")
        self.log.append(
            f"Round event: {event['name']}. {', '.join(parts)}. BYTE is ${self.byte_price}."
        )

    def _score_game(self) -> None:
        rows: list[dict[str, Any]] = []
        for player in self.players:
            holdings: list[dict[str, Any]] = []
            share_value = 0
            active_shares = 0
            for corp in self.corporations:
                count = int(player["shares"][corp["id"]])
                if not corp["active"] or count <= 0:
                    continue
                value = count * int(corp["share_price"])
                active_shares += count
                share_value += value
                holdings.append(
                    {
                        "id": corp["id"],
                        "name": corp["name"],
                        "count": count,
                        "price": int(corp["share_price"]),
                        "value": value,
                    }
                )
            byte_count = int(player["byte_count"])
            byte_value = byte_count * self.byte_price
            net_worth = int(player["cash"]) + share_value + byte_value
            rows.append(
                {
                    "id": player["id"],
                    "display_name": player["display_name"],
                    "cash": int(player["cash"]),
                    "share_value": share_value,
                    "active_shares": active_shares,
                    "byte_count": byte_count,
                    "byte_value": byte_value,
                    "net_worth": net_worth,
                    "turn_order_index": int(player["turn_order_index"]),
                    "holdings": holdings,
                }
            )
        self.ranking = rank_players(rows)
        self.ledger = rows
        self.phase = "completed"
        self.market_actions_left = 0
        winner = next(row for row in rows if row["id"] == self.ranking[0])
        self.log.append(f"{winner['display_name']} wins with ${winner['net_worth']} fictional.")


_SECTOR_LABELS = {
    "ai": "AI",
    "fintech": "Fintech",
    "energy": "Energy",
    "media": "Media",
    "retail": "Retail",
}


def _join_names(names: list[str]) -> str:
    if len(names) == 2:
        return f"{names[0]} and {names[1]}"
    return ", ".join(names[:-1]) + f", and {names[-1]}"
