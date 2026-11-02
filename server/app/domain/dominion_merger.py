"""Isolated Dominion financial resolution; not wired to rooms or Classic.

Every transition commits a complete copied ledger. Restores replay from the
opening financial snapshot and compare all derived state, never pay a bonus
on top of already-restored balances. No hand, seed or session data is copied.
"""
from __future__ import annotations

import copy
import json
from typing import Any

from app.domain.mergers import bonus_payouts
from app.domain.dominion_pricing import share_price
from app.domain.rulesets import _integer_numbers
from app.files import load_json


def _text(value: Any) -> str:
    if not isinstance(value, str) or not value:
        raise ValueError("non-empty identifier required")
    return value


def _integer(value: Any, minimum: int = 0, maximum: int | None = None) -> int:
    if isinstance(value, bool) or not isinstance(value, int):
        raise ValueError("integer required")
    if value < minimum or (maximum is not None and value > maximum):
        raise ValueError("integer out of range")
    return value


def _canonical(value: Any) -> str:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


class DominionMerger:
    @classmethod
    def begin(cls, resolution_id: str, survivor_id: str, placer_id: str,
              losing_ids: list[str], companies: list[dict], players: list[dict]) -> DominionMerger:
        resolution_id, survivor_id, placer_id = map(_text, (resolution_id, survivor_id, placer_id))
        order = [item["id"] for item in load_json("fixtures/corporations.json")["corporations"]]
        if not isinstance(companies, list) or len(companies) != len(order):
            raise ValueError("complete corporation ledger required")
        roster: dict[str, dict] = {}
        for company in companies:
            cid = _text(company["id"])
            if cid not in order or cid in roster:
                raise ValueError("unknown or repeated company")
            bank = _integer(company["bank_shares"], 0, 20)
            price = _integer(company["share_price"], 0, share_price(cid, 81, 2))
            if price % 10:
                raise ValueError("quote must be in $10 steps")
            roster[cid] = {"id": cid, "bank_shares": bank, "share_price": price}
        if survivor_id not in roster or roster[survivor_id]["share_price"] <= 0:
            raise ValueError("active survivor required")
        if not isinstance(losing_ids, list) or not losing_ids or any(not isinstance(cid, str) for cid in losing_ids):
            raise ValueError("losing companies required")
        if len(set(losing_ids)) != len(losing_ids) or survivor_id in losing_ids or any(cid not in roster or roster[cid]["share_price"] <= 0 for cid in losing_ids):
            raise ValueError("invalid losing company")
        losers = [cid for cid in order if cid in losing_ids]
        if not isinstance(players, list) or not 2 <= len(players) <= 4:
            raise ValueError("two to four players required")
        seats: dict[str, dict] = {}
        for player in players:
            pid = _text(player["id"])
            if pid in seats or not isinstance(player["shares"], dict) or set(player["shares"]) != set(order):
                raise ValueError("invalid player ledger")
            seats[pid] = {"id": pid, "cash": _integer(player["cash"], 0, 2147483647), "shares": {cid: _integer(player["shares"][cid], 0, 20) for cid in order}}
        if placer_id not in seats:
            raise ValueError("placer must be a player")
        for cid in order:
            if roster[cid]["bank_shares"] + sum(seat["shares"][cid] for seat in seats.values()) != 20:
                raise ValueError("share supply mismatch")
        opening = {"resolution_id": resolution_id, "survivor_id": survivor_id, "placer_id": placer_id,
                   "losing_ids": losers, "companies": [roster[cid] for cid in order],
                   "players": [seats[pid] for pid in sorted(seats)]}
        state = {"format_version": 1, "ruleset_id": "dominion_v1", "opening": copy.deepcopy(opening),
                 "banks": {cid: roster[cid]["bank_shares"] for cid in order},
                 "cash": {pid: seats[pid]["cash"] for pid in sorted(seats)},
                 "shares": {pid: dict(seats[pid]["shares"]) for pid in sorted(seats)},
                 "snapshots": {}, "queue": [], "cursor": 0, "version": 0,
                 "bonuses_paid": True, "decisions": []}
        for cid in losers:
            holdings = {pid: seats[pid]["shares"][cid] for pid in sorted(seats)}
            payouts = bonus_payouts(roster[cid]["share_price"], holdings)
            state["snapshots"][cid] = {"price": roster[cid]["share_price"], "holdings": holdings, "bonuses": payouts}
            for pid, amount in payouts.items():
                state["cash"][pid] += amount
            for pid, count in holdings.items():
                if count > 0:
                    state["queue"].append({"player_id": pid, "loser_id": cid, "shares": count})
        instance = cls()
        instance._state = state
        instance._advance_flags(state)
        return instance

    def export_state(self) -> dict[str, Any]:
        return copy.deepcopy(self._state)

    def current_choice(self) -> dict[str, Any] | None:
        state = self._state
        if state["complete"]:
            return None
        choice = dict(state["queue"][state["cursor"]])
        choice["max_pairs"] = min(choice["shares"] // 2, state["remaining_survivor_bank"])
        return choice

    def choose(self, resolution_id: str, actor_id: str, loser_id: str, pairs: int,
               action_id: str, expected_version: int) -> dict[str, Any]:
        return self._commit(resolution_id, actor_id, loser_id, pairs, action_id, expected_version, False)

    def timeout(self, resolution_id: str, actor_id: str, loser_id: str,
                action_id: str, expected_version: int) -> dict[str, Any]:
        """Caller must verify a real deadline/session loss; defaults only the named pending holder."""
        return self._commit(resolution_id, actor_id, loser_id, 0, action_id, expected_version, True)

    def _commit(self, resolution_id: str, actor_id: str, loser_id: str, pairs: int,
                action_id: str, expected_version: int, timed_out: bool) -> dict[str, Any]:
        request = {"resolution_id": _text(resolution_id), "actor_id": _text(actor_id),
                   "loser_id": _text(loser_id), "pairs": _integer(pairs),
                   "action_id": _text(action_id), "expected_version": _integer(expected_version), "timed_out": timed_out}
        state = self._state
        for decision in state["decisions"]:
            if decision["request"]["action_id"] == action_id:
                original_intent = {key: value for key, value in decision["request"].items() if key != "expected_version"}
                retry_intent = {key: value for key, value in request.items() if key != "expected_version"}
                if original_intent != retry_intent:
                    raise ValueError("action id reused with different request")
                return {"ok": True, "duplicate": True, "receipt": copy.deepcopy(decision["receipt"])}
        choice = self.current_choice()
        if resolution_id != state["opening"]["resolution_id"] or expected_version != state["version"]:
            raise ValueError("wrong resolution or stale version")
        if choice is None:
            raise ValueError("resolution is complete")
        if actor_id != choice["player_id"] or loser_id != choice["loser_id"]:
            raise ValueError("not the required shareholder/company")
        if pairs > choice["max_pairs"]:
            raise ValueError("swap exceeds holdings or survivor bank")
        candidate = copy.deepcopy(state)
        survivor = candidate["opening"]["survivor_id"]
        count = choice["shares"]
        proceeds = (count - 2 * pairs) * candidate["snapshots"][loser_id]["price"]
        candidate["shares"][actor_id][loser_id] = 0
        candidate["shares"][actor_id][survivor] += pairs
        candidate["banks"][loser_id] += count
        candidate["banks"][survivor] -= pairs
        candidate["cash"][actor_id] += proceeds
        candidate["cursor"] += 1
        candidate["version"] += 1
        receipt = {"action_id": action_id, "version": candidate["version"], "player_id": actor_id,
                   "loser_id": loser_id, "pairs": pairs, "loser_shares_returned": count,
                   "survivor_shares_received": pairs, "cash_proceeds": proceeds, "timed_out": timed_out}
        candidate["decisions"].append({"request": request, "receipt": receipt})
        self._advance_flags(candidate)
        for cid, bank in candidate["banks"].items():
            if bank < 0 or bank + sum(row[cid] for row in candidate["shares"].values()) != 20:
                raise ValueError("share supply mismatch")
        self._state = candidate
        return {"ok": True, "duplicate": False, "receipt": copy.deepcopy(receipt)}

    @staticmethod
    def _advance_flags(state: dict) -> None:
        state["complete"] = state["cursor"] == len(state["queue"])
        state["required_actor_id"] = None if state["complete"] else state["queue"][state["cursor"]]["player_id"]
        state["resume_player_id"] = state["opening"]["placer_id"] if state["complete"] else None
        state["remaining_survivor_bank"] = state["banks"][state["opening"]["survivor_id"]]

    @classmethod
    def from_export(cls, data: dict[str, Any]) -> DominionMerger:
        """Rebuild all derived balances/flags/receipts; reject inconsistent derived state or partial snapshots."""
        try:
            saved = _integer_numbers(copy.deepcopy(data))
            opening = saved["opening"]
            rebuilt = cls.begin(**opening)
            for decision in saved["decisions"]:
                request = decision["request"]
                if request["timed_out"] is True:
                    if request["pairs"] != 0:
                        raise ValueError("timeout must sell for cash")
                    arguments = {key: value for key, value in request.items() if key not in {"pairs", "timed_out"}}
                    rebuilt.timeout(**arguments)
                elif request["timed_out"] is False:
                    rebuilt.choose(**{key: value for key, value in request.items() if key != "timed_out"})
                else:
                    raise ValueError("invalid timeout flag")
            if _canonical(saved) != _canonical(rebuilt.export_state()):
                raise ValueError("derived merger state does not match its replay")
            return rebuilt
        except (KeyError, TypeError, AttributeError) as exc:
            raise ValueError("invalid merger snapshot") from exc
