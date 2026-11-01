"""Authoritative private rooms.

The server owns the seed, the tile order, the event deck, and every cash
and inventory change. A client command is applied only after the session,
the room, the version, and the turn all check out. The same session and
client_action_id returns the original result and does not apply twice.

Assumption A21: create and join issue the session token. Reconnect,
request_snapshot, create, and join do not have to name the current version.
Other commands do. A disconnected active player is autopassed after the
grace period by placing the lowest tile in hand, or by taking the first
legal choice, then passing any market actions left. ``sweep_due`` applies
that deadline without waiting for another player's command. The room lock
keeps the sweep from overlapping a command. A sweep that cannot move the
match does not bump the version, so the same deadline is not applied twice.
"""

from __future__ import annotations

import json
import secrets
import threading
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from app.contract import command_errors
from app.domain.coordinates import all_coordinates
from app.domain.events import load_round_events
from app.domain.invariants import public_state_errors
from app.domain.offline import OfflineMatch
from app.files import load_rules
from app.persistence.sqlite import connect

_INVITE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
_EXEMPT_VERSION = {"create_room", "join_room", "reconnect", "request_snapshot"}
_READ_COMMANDS = {"reconnect", "request_snapshot"}


class RoomError(Exception):
    def __init__(self, code: str, message: str, match_id: str = "missing", version: int = 0) -> None:
        super().__init__(message)
        self.code = code
        self.message = message[:400]
        self.match_id = match_id
        self.version = version
        self.notices: list[dict[str, Any]] = []


@dataclass
class Applied:
    direct: list[dict[str, Any]]
    public: list[dict[str, Any]]
    replayed: bool = False
    notices: list[dict[str, Any]] = field(default_factory=list)


class RoomService:
    def __init__(
        self,
        database: Path | None = None,
        seed: int | None = None,
        create_limit: int = 30,
        command_limit: int = 80,
        grace_seconds: float = 120.0,
        session_ttl_seconds: float = 86400.0,
        clock: Any = None,
    ) -> None:
        self.database = database
        self.fixed_seed = seed
        self.create_limit = create_limit
        self.command_limit = command_limit
        self.grace_seconds = grace_seconds
        self.session_ttl_seconds = session_ttl_seconds
        self.clock = clock or time.time
        self._lock = threading.Lock()
        self._rooms: dict[str, dict[str, Any]] = {}
        self._by_token: dict[str, str] = {}
        self._by_invite: dict[str, str] = {}
        self._creates: list[float] = []
        self._commands: dict[str, list[float]] = {}
        self._notices: list[dict[str, Any]] = []
        self._load()

    def apply(self, command: object) -> Applied:
        with self._lock:
            try:
                return self._apply(command)
            except RoomError as exc:
                exc.notices = list(self._notices)
                raise

    def sweep_due(self) -> list[tuple[str, list[dict[str, Any]]]]:
        """Apply grace deadlines that have elapsed. Safe to call on a timer.

        Returns ``(match_id, public events)`` for each room that moved.
        The caller publishes those events. This method holds the room lock
        for the whole pass, so it cannot interleave with ``apply``.
        """
        with self._lock:
            due: list[tuple[str, list[dict[str, Any]]]] = []
            for room in list(self._rooms.values()):
                self._notices = []
                public = self._sweep(room)
                if public:
                    due.append((str(room["match_id"]), public))
            return due

    def public_invite(self, code: str) -> dict[str, Any] | None:
        """Lobby facts for an invite code. No session token is included."""
        cleaned = code.strip().upper()
        if len(cleaned) < 4 or len(cleaned) > 12:
            return None
        if any(character not in _INVITE_ALPHABET for character in cleaned):
            return None
        with self._lock:
            match_id = self._by_invite.get(cleaned)
            if match_id is None:
                return None
            room = self._rooms.get(match_id)
            if room is None:
                return None
            return _public_invite(room)

    def private_hand(self, match_id: str, token: str) -> tuple[str | None, list[str]]:
        with self._lock:
            room = self._rooms.get(match_id)
            if room is None:
                return None, []
            seat = self._seat_or_none(room, token)
            if seat is None:
                return None, []
            return seat["player_id"], _hand(room, seat["player_id"])

    def hello(self, match_id: str, session_token: str) -> Applied:
        """Mark a socket connected and return a private snapshot. No version bump."""
        with self._lock:
            room = self._require_member(match_id, session_token)
            seat = self._seat(room, session_token)
            self._touch_session(room, seat)
            seat["connected"] = True
            seat["disconnected_at"] = None
            self._persist(room)
            return Applied(
                direct=[self._snapshot_event(room, seat)],
                public=[],
            )

    def bye(self, match_id: str, session_token: str) -> dict[str, Any] | None:
        with self._lock:
            room = self._rooms.get(match_id)
            if room is None:
                return None
            seat = next((item for item in room["seats"] if item["session_token"] == session_token), None)
            if seat is None:
                return None
            seat["connected"] = False
            seat["disconnected_at"] = float(self.clock())
            self._persist(room)
            return self._event(
                room,
                "player_disconnected",
                {"player_id": seat["player_id"]},
            )

    def _apply(self, command: object) -> Applied:
        if not isinstance(command, dict):
            raise RoomError("invalid_command", "command must be an object")
        errors = command_errors(command)
        if errors:
            match_id = str(command.get("match_id", "missing"))
            raise RoomError("invalid_command", errors[0], match_id=match_id)
        name = str(command["command"])
        match_id = str(command["match_id"])
        self._notices = []
        if name == "create_room":
            return self._create(command)
        room = self._rooms.get(match_id)
        if name == "join_room":
            return self._join(command)
        token = str(command["session_token"])
        if room is None:
            owner = self._by_token.get(token)
            if owner and owner != match_id:
                raise RoomError(
                    "unauthorized",
                    "session token is for a different room",
                    match_id=match_id,
                )
            raise RoomError("not_found", "room not found", match_id=match_id)
        seat = self._seat_or_none(room, token)
        if seat is None:
            owner = self._by_token.get(token)
            if owner and owner != match_id:
                raise RoomError(
                    "unauthorized",
                    "session token is for a different room",
                    match_id=match_id,
                    version=int(room["version"]),
                )
            raise RoomError(
                "unauthorized",
                "session token is not valid for this room",
                match_id=match_id,
                version=int(room["version"]),
            )
        self._touch_session(room, seat)
        self._charge(token, room)
        notices = self._sweep(room)
        stored = room["actions"].get(self._action_key(token, command))
        fingerprint = _fingerprint(command)
        if stored is not None:
            if stored["fingerprint"] != fingerprint:
                raise RoomError(
                    "duplicate_action",
                    "client_action_id was already used with a different payload",
                    match_id=match_id,
                    version=int(room["version"]),
                )
            return Applied(direct=stored["events"], public=[], replayed=True, notices=notices)
        if name not in _EXEMPT_VERSION and int(command["expected_state_version"]) != int(room["version"]):
            raise RoomError(
                "stale_version",
                f"expected state version {int(command['expected_state_version'])} "
                f"but the server is at version {int(room['version'])}",
                match_id=match_id,
                version=int(room["version"]),
            )
        if name in _READ_COMMANDS:
            applied = self._read(room, seat, name)
        elif name == "ready":
            applied = self._ready(room, seat, command)
        elif name == "start_match":
            applied = self._start(room, seat, command)
        else:
            applied = self._play(room, seat, command)
        applied.notices = notices + applied.notices
        room["actions"][self._action_key(token, command)] = {
            "fingerprint": fingerprint,
            "events": applied.direct,
        }
        self._persist(room)
        return applied

    def _create(self, command: dict[str, Any]) -> Applied:
        match_id = str(command["match_id"])
        fingerprint = _fingerprint(command)
        existing = self._rooms.get(match_id)
        if existing is not None:
            stored = existing["actions"].get(self._action_key(str(command["session_token"]), command))
            if stored is not None and stored["fingerprint"] == fingerprint:
                return Applied(direct=stored["events"], public=[], replayed=True)
            if stored is not None:
                raise RoomError(
                    "duplicate_action",
                    "client_action_id was already used with a different payload",
                    match_id=match_id,
                    version=int(existing["version"]),
                )
            raise RoomError("invalid_command", "match id is already in use", match_id=match_id)
        self._charge_create()
        nickname = str(command["payload"]["nickname"])
        token = _token()
        code = self._invite()
        room: dict[str, Any] = {
            "match_id": match_id,
            "invite_code": code,
            "version": 0,
            "seed": 0,
            "seats": [],
            "match": None,
            "actions": {},
            "log": [],
        }
        self._add_seat(room, nickname, token, host=True)
        self._rooms[match_id] = room
        self._by_invite[code] = match_id
        self._remember(room)
        direct, public = self._bump(room, room["seats"][0], "create_room", f"{nickname} opened the room")
        self._persist(room)
        key = self._action_key(str(command["session_token"]), command)
        room["actions"][key] = {"fingerprint": _fingerprint(command), "events": direct}
        self._persist(room)
        return Applied(direct=direct, public=public)

    def _join(self, command: dict[str, Any]) -> Applied:
        code = str(command["payload"]["invite_code"])
        match_id = self._by_invite.get(code)
        if match_id is None:
            raise RoomError("not_found", "invite code was not found", match_id=str(command["match_id"]))
        if match_id != str(command["match_id"]):
            raise RoomError(
                "unauthorized",
                "invite code does not match this room",
                match_id=str(command["match_id"]),
            )
        room = self._rooms[match_id]
        self._charge(str(command["session_token"]), room)
        if room["match"] is not None:
            raise RoomError("wrong_phase", "the match has already started", match_id=match_id, version=int(room["version"]))
        if len(room["seats"]) >= 4:
            raise RoomError("wrong_phase", "the room is full", match_id=match_id, version=int(room["version"]))
        nickname = str(command["payload"]["nickname"])
        if any(seat["nickname"] == nickname for seat in room["seats"]):
            raise RoomError("invalid_nickname", "nickname is already in this room", match_id=match_id, version=int(room["version"]))
        stored = room["actions"].get(self._action_key(str(command["session_token"]), command))
        fingerprint = _fingerprint(command)
        if stored is not None:
            if stored["fingerprint"] != fingerprint:
                raise RoomError("duplicate_action", "client_action_id was already used with a different payload", match_id=match_id, version=int(room["version"]))
            return Applied(direct=stored["events"], public=[], replayed=True)
        token = _token()
        seat = self._add_seat(room, nickname, token, host=False)
        direct, public = self._bump(room, seat, "join_room", f"{nickname} joined the room")
        key = self._action_key(str(command["session_token"]), command)
        room["actions"][key] = {"fingerprint": fingerprint, "events": direct}
        self._persist(room)
        return Applied(direct=direct, public=public)

    def _ready(self, room: dict[str, Any], seat: dict[str, Any], command: dict[str, Any]) -> Applied:
        if room["match"] is not None:
            raise self._phase(room, "the match has already started")
        seat["ready"] = bool(command["payload"]["is_ready"])
        word = "ready" if seat["ready"] else "not ready"
        return self._transition(room, seat, "ready", f"{seat['nickname']} is {word}", ["room_updated"])

    def _start(self, room: dict[str, Any], seat: dict[str, Any], command: dict[str, Any]) -> Applied:
        del command
        if not seat["host"]:
            raise self._phase(room, "only the host can start")
        if room["match"] is not None:
            raise self._phase(room, "the match has already started")
        count = len(room["seats"])
        if count < 2 or count > 4:
            raise self._phase(room, "start needs 2 to 4 players")
        if not all(item["ready"] for item in room["seats"]):
            raise self._phase(room, "every player must be ready")
        names = [item["nickname"] for item in room["seats"]]
        seed = self.fixed_seed if self.fixed_seed is not None else secrets.randbits(31)
        room["seed"] = seed
        room["match"] = OfflineMatch(seed, names)
        return self._transition(room, seat, "start_match", "The host started the match", ["match_started"])

    def _play(self, room: dict[str, Any], seat: dict[str, Any], command: dict[str, Any]) -> Applied:
        match = room["match"]
        if not isinstance(match, OfflineMatch):
            raise self._phase(room, "the match has not started")
        if match.phase == "completed":
            raise self._phase(room, "the match is over")
        if seat["player_id"] != match.active_player()["id"]:
            raise RoomError("out_of_turn", "it is not your turn", match_id=room["match_id"], version=int(room["version"]))
        name = str(command["command"])
        payload = command["payload"]
        try:
            if name == "place_tile":
                match.place(str(payload["coordinate"]))
            elif name == "choose_founder":
                match.choose_founder(str(payload["corporation_id"]))
            elif name == "choose_merger_survivor":
                match.choose_survivor(str(payload["corporation_id"]))
            elif name == "market_buy_share":
                match.buy_share(str(payload["corporation_id"]))
            elif name == "market_sell_share":
                match.sell_share(str(payload["corporation_id"]))
            elif name == "market_buy_byte":
                match.buy_byte()
            elif name == "market_sell_byte":
                match.sell_byte()
            elif name == "pass_market_action":
                match.pass_market()
            elif name == "end_turn":
                match.pass_turn()
            else:
                raise RoomError("invalid_command", "command is not a match action", match_id=room["match_id"], version=int(room["version"]))
        except RoomError:
            raise
        except ValueError as exc:
            raise _game_error(room, exc) from exc
        outcome = match.log[-1] if match.log else name
        extras = _extra_events(name, match)
        return self._transition(room, seat, name, outcome, extras)

    def _read(self, room: dict[str, Any], seat: dict[str, Any], name: str) -> Applied:
        if name == "reconnect":
            seat["connected"] = True
            seat["disconnected_at"] = None
            public = self._event(room, "player_reconnected", {"player_id": seat["player_id"]})
            direct = [public, self._snapshot_event(room, seat)]
            return Applied(direct=direct, public=[public])
        return Applied(direct=[self._snapshot_event(room, seat)], public=[])

    def _transition(
        self,
        room: dict[str, Any],
        seat: dict[str, Any],
        command_name: str,
        outcome: str,
        extras: list[str],
    ) -> Applied:
        direct, public = self._bump(room, seat, command_name, outcome, extras)
        return Applied(direct=direct, public=public)

    def _bump(
        self,
        room: dict[str, Any],
        seat: dict[str, Any],
        command_name: str,
        outcome: str,
        extras: list[str] | None = None,
    ) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
        room["version"] = int(room["version"]) + 1
        room["log"].append(
            {
                "seq": len(room["log"]) + 1,
                "actor": seat["player_id"],
                "command": command_name,
                "outcome": outcome[:500],
            }
        )
        names = ["room_updated"] if command_name in {"create_room", "join_room", "ready"} else list(extras or [])
        if command_name == "start_match":
            names = ["match_started"]
        public_events = [self._event(room, name, _public_payload(room, name)) for name in names]
        public_events.append(self._snapshot_event(room, None))
        direct = []
        for event in public_events:
            if event["event"] == "room_updated" and command_name in {"create_room", "join_room"}:
                payload = dict(event["payload"])
                payload["session_token"] = seat["session_token"]
                payload["player_id"] = seat["player_id"]
                direct.append({**event, "payload": payload})
            elif event["event"] == "state_snapshot":
                direct.append(self._snapshot_event(room, seat))
            else:
                direct.append(event)
        return direct, public_events

    def _sweep(self, room: dict[str, Any]) -> list[dict[str, Any]]:
        match = room["match"]
        if not isinstance(match, OfflineMatch) or match.phase == "completed":
            return []
        active = match.active_player()
        seat = next(item for item in room["seats"] if item["player_id"] == active["id"])
        if seat["connected"] or seat["disconnected_at"] is None:
            return []
        if float(self.clock()) - float(seat["disconnected_at"]) < self.grace_seconds:
            return []
        actor = active["id"]
        before = (match.phase, int(match.turn_index), len(match.log), int(match.market_actions_left))
        guard = 0
        while match.phase != "completed" and match.active_player()["id"] == actor and guard < 8:
            guard += 1
            if match.phase == "choose_founder":
                inactive = [corp["id"] for corp in match.corporations if not corp["active"]]
                match.choose_founder(inactive[0])
            elif match.phase == "choose_survivor":
                match.choose_survivor(match.pending_options[0])
            elif match.phase == "place":
                hand = match.active_player()["hand"]
                if hand:
                    match.place(sorted(hand)[0])
                else:
                    match.pass_turn()
            elif match.phase == "market":
                match.pass_market()
            else:
                break
        after = (match.phase, int(match.turn_index), len(match.log), int(match.market_actions_left))
        if after == before:
            return []
        room["timeout_player"] = actor
        try:
            direct, public = self._bump(
                room,
                seat,
                "autopass",
                "Disconnected seat took the deterministic safe actions.",
                ["turn_changed"],
            )
        finally:
            room.pop("timeout_player", None)
        self._notices.extend(public)
        self._persist(room)
        return public

    def _snapshot_event(self, room: dict[str, Any], seat: dict[str, Any] | None) -> dict[str, Any]:
        state = _public_state(room)
        problems = public_state_errors(state)
        if problems:
            raise RuntimeError("public snapshot failed invariants: " + "; ".join(problems))
        payload: dict[str, Any] = {
            "you": None if seat is None else seat["player_id"],
            "step": _step(room),
            "market_actions_left": _market_left(room),
            "pending_options": _pending(room),
            "state": state,
        }
        if seat is not None:
            payload["your_hand"] = _hand(room, seat["player_id"])
        return self._event(room, "state_snapshot", payload)

    def _event(self, room: dict[str, Any], name: str, payload: dict[str, Any]) -> dict[str, Any]:
        return {
            "event": name,
            "match_id": room["match_id"],
            "state_version": int(room["version"]),
            "payload": payload,
        }

    def _add_seat(self, room: dict[str, Any], nickname: str, token: str, host: bool) -> dict[str, Any]:
        seat = {
            "player_id": f"p{len(room['seats']) + 1}",
            "nickname": nickname,
            "session_token": token,
            "ready": False,
            "connected": True,
            "host": host,
            "disconnected_at": None,
        }
        seat["session_seen_at"] = float(self.clock())
        room["seats"].append(seat)
        self._by_token[token] = room["match_id"]
        return seat

    def _remember(self, room: dict[str, Any]) -> None:
        self._by_invite[room["invite_code"]] = room["match_id"]
        for seat in room["seats"]:
            self._by_token[seat["session_token"]] = room["match_id"]

    def _require_member(self, match_id: str, token: str) -> dict[str, Any]:
        room = self._rooms.get(match_id)
        if room is None:
            raise RoomError("not_found", "room not found", match_id=match_id)
        if self._seat_or_none(room, token) is None:
            raise RoomError("unauthorized", "session token is not valid for this room", match_id=match_id, version=int(room["version"]))
        return room

    def _seat(self, room: dict[str, Any], token: str) -> dict[str, Any]:
        found = self._seat_or_none(room, token)
        if found is None:
            raise RoomError("unauthorized", "session token is not valid for this room", match_id=room["match_id"], version=int(room["version"]))
        return found

    def _seat_or_none(self, room: dict[str, Any], token: str) -> dict[str, Any] | None:
        for seat in room["seats"]:
            if seat["session_token"] == token:
                return seat
        return None

    def _phase(self, room: dict[str, Any], message: str) -> RoomError:
        return RoomError("wrong_phase", message, match_id=room["match_id"], version=int(room["version"]))

    def _charge_create(self) -> None:
        now = time.monotonic()
        self._creates = [stamp for stamp in self._creates if now - stamp < 60]
        if len(self._creates) >= self.create_limit:
            raise RoomError("rate_limited", "room creation is rate limited")
        self._creates.append(now)

    def _charge(self, token: str, room: dict[str, Any]) -> None:
        now = time.monotonic()
        window = [stamp for stamp in self._commands.get(token, []) if now - stamp < 10]
        if len(window) >= self.command_limit:
            raise RoomError("rate_limited", "too many commands", match_id=room["match_id"], version=int(room["version"]))
        window.append(now)
        self._commands[token] = window

    def _park_sessions(self, room: dict[str, Any]) -> None:
        """After a restart no socket is connected. Keep an existing deadline."""
        now = float(self.clock())
        for seat in room["seats"]:
            seat["connected"] = False
            if seat.get("disconnected_at") is None:
                seat["disconnected_at"] = now

    def _touch_session(self, room: dict[str, Any], seat: dict[str, Any]) -> None:
        now = float(self.clock())
        seen = seat.get("session_seen_at")
        if seen is not None and now - float(seen) > self.session_ttl_seconds:
            raise RoomError(
                "unauthorized",
                "session expired",
                match_id=room["match_id"],
                version=int(room["version"]),
            )
        seat["session_seen_at"] = now

    def _invite(self) -> str:
        for _ in range(20):
            code = "".join(secrets.choice(_INVITE_ALPHABET) for _ in range(6))
            if code not in self._by_invite:
                return code
        raise RoomError("rate_limited", "could not issue an invite code")

    def _action_key(self, token: str, command: dict[str, Any]) -> str:
        return f"{command['match_id']}|{token}|{command['client_action_id']}"

    def _persist(self, room: dict[str, Any]) -> None:
        blob = json.dumps(_export_room(room))
        connection = connect(self.database)
        try:
            connection.execute(
                """
                INSERT INTO rooms (match_id, invite_code, blob)
                VALUES (?, ?, ?)
                ON CONFLICT(match_id) DO UPDATE SET
                    invite_code = excluded.invite_code,
                    blob = excluded.blob
                """,
                (room["match_id"], room["invite_code"], blob),
            )
            connection.commit()
        finally:
            connection.close()

    def _load(self) -> None:
        connection = connect(self.database)
        try:
            rows = connection.execute("SELECT blob FROM rooms").fetchall()
        finally:
            connection.close()
        for (blob,) in rows:
            room = _import_room(json.loads(blob))
            self._rooms[room["match_id"]] = room
            self._park_sessions(room)
            self._remember(room)


def _export_room(room: dict[str, Any]) -> dict[str, Any]:
    match = room["match"]
    return {
        "match_id": room["match_id"],
        "invite_code": room["invite_code"],
        "version": room["version"],
        "seed": room["seed"],
        "seats": room["seats"],
        "actions": room["actions"],
        "log": room["log"],
        "match": None if match is None else match.export_state(),
    }


def _import_room(data: dict[str, Any]) -> dict[str, Any]:
    match_blob = data["match"]
    return {
        "match_id": data["match_id"],
        "invite_code": data["invite_code"],
        "version": int(data["version"]),
        "seed": int(data["seed"]),
        "seats": data["seats"],
        "actions": data["actions"],
        "log": data["log"],
        "match": None if match_blob is None else OfflineMatch.from_export(match_blob),
    }


def _token() -> str:
    return secrets.token_urlsafe(18)


def _fingerprint(command: dict[str, Any]) -> str:
    payload = json.dumps(command["payload"], sort_keys=True, separators=(",", ":"))
    return f"{command['command']}:{payload}"


def _game_error(room: dict[str, Any], exc: ValueError) -> RoomError:
    text = str(exc)
    version = int(room["version"])
    match_id = room["match_id"]
    if text in {"tile not in hand", "cell occupied"}:
        code = "illegal_tile"
    elif text == "not enough cash":
        code = "insufficient_cash"
    elif text in {
        "no share to sell",
        "no BYTE to sell",
        "no BYTE in the exchange",
        "no share in the bank",
        "company is not active",
    }:
        code = "insufficient_inventory"
    elif text in {
        "the match is over",
        "not the placement step",
        "not the market step",
        "no market action left",
        "no company choice is pending",
        "no survivor choice is pending",
        "hand still has a tile",
        "company is already active",
    }:
        code = "wrong_phase"
    else:
        code = "invalid_command"
    return RoomError(code, text, match_id=match_id, version=version)


def _extra_events(command_name: str, match: OfflineMatch) -> list[str]:
    names: list[str] = []
    if command_name == "place_tile":
        names.append("tile_placed")
        if match.phase == "choose_survivor":
            names.append("merger_started")
        elif any("merger" in line or line.startswith("Quinn kept") or "survives" in line for line in match.log[-4:]):
            if match.phase != "choose_survivor":
                names.append("merger_resolved")
    elif command_name == "choose_founder":
        names.append("company_founded")
    elif command_name == "choose_merger_survivor":
        names.append("merger_resolved")
    elif command_name.startswith("market_"):
        names.append("trade_completed")
    elif command_name in {"pass_market_action", "end_turn"}:
        names.append("turn_changed")
    if any(line.startswith("Round event:") for line in match.log[-3:]):
        names.append("round_event_applied")
    if match.phase == "completed":
        names.append("game_ended")
    return names


def _public_payload(room: dict[str, Any], event_name: str) -> dict[str, Any]:
    if event_name == "room_updated":
        return {
            "player_count": len(room["seats"]),
            "invite_code": room["invite_code"],
            "host_id": next(seat["player_id"] for seat in room["seats"] if seat["host"]),
            "players": [
                {
                    "id": seat["player_id"],
                    "display_name": seat["nickname"],
                    "is_ready": seat["ready"],
                    "connection_state": "connected" if seat["connected"] else "disconnected",
                }
                for seat in room["seats"]
            ],
        }
    if event_name == "game_ended":
        match = room["match"]
        return {"ranking": list(match.ranking), "winner": match.ranking[0] if match.ranking else ""}
    if event_name == "round_event_applied":
        match = room["match"]
        return {"event_ids": list(match.event_ids), "byte_price": match.byte_price}
    if event_name == "turn_changed":
        payload: dict[str, Any] = {"command": event_name}
        timed_out = room.get("timeout_player")
        if isinstance(timed_out, str) and timed_out:
            payload["timed_out_player"] = timed_out
            payload["reason"] = "grace_elapsed"
        return payload
    return {"command": event_name}


def _public_invite(room: dict[str, Any]) -> dict[str, Any]:
    match = room["match"]
    phase = "lobby" if match is None else str(match.phase)
    return {
        "match_id": room["match_id"],
        "invite_code": room["invite_code"],
        "player_count": len(room["seats"]),
        "phase": phase,
        "seats": [
            {
                "id": seat["player_id"],
                "display_name": seat["nickname"],
                "is_ready": bool(seat["ready"]),
                "connection_state": "connected" if seat["connected"] else "disconnected",
                "host": bool(seat["host"]),
            }
            for seat in room["seats"]
        ],
    }


def _public_state(room: dict[str, Any]) -> dict[str, Any]:
    rules = load_rules()
    catalog = all_coordinates()
    match = room["match"]
    if isinstance(match, OfflineMatch):
        phase, flag = _wire_phase(match)
        active = None if match.phase == "completed" else match.active_player()["id"]
        board = [
            {
                "coordinate": coordinate,
                "occupied": bool(match.occupied.get(coordinate, False)),
                "company_id": match.company_of.get(coordinate),
            }
            for coordinate in catalog
        ]
        players = []
        for seat in room["seats"]:
            player = next(item for item in match.players if item["id"] == seat["player_id"])
            players.append(_public_player(seat, player))
        players.sort(key=lambda item: int(item["turn_order_index"]))
        corporations = []
        for corp in match.corporations:
            cells = [coordinate for coordinate in catalog if match.company_of.get(coordinate) == corp["id"]]
            corporations.append(
                {
                    "id": corp["id"],
                    "name": corp["name"],
                    "sector": corp["sector"],
                    "active": bool(corp["active"]),
                    "size": len(cells),
                    "cells": cells,
                    "total_shares": int(rules["corporation_share_supply"]),
                    "bank_shares": int(corp["bank_shares"]),
                    "share_price": int(corp["share_price"]),
                }
            )
        return {
            "match_id": room["match_id"],
            "version": int(room["version"]),
            "seed": 0,  # Do not reveal the shuffle seed while private hands are in play.
            "phase": phase,
            "active_player_id": active,
            "turn_index": int(match.turn_index),
            "round_number": int(match.round_number),
            "final_round_flag": flag,
            "board": board,
            "tile_bag_count": len(match.bag),
            "players": players,
            "corporations": corporations,
            "crypto_market": {
                "symbol": "BYTE",
                "price": int(match.byte_price),
                "exchange_coin_count": int(match.byte_exchange),
                "supply": int(rules["byte_supply"]),
            },
            "sector_sentiment": {sector: int(match.sentiment[sector]) for sector in rules["sectors"]},
            "events_remaining": len(match.events),
            "action_log": list(room["log"]),
        }
    players = []
    for index, seat in enumerate(room["seats"]):
        players.append(
            {
                "id": seat["player_id"],
                "display_name": seat["nickname"],
                "connection_state": "connected" if seat["connected"] else "disconnected",
                "cash": int(rules["starting_cash"]),
                "holdings_by_corp": {corp: 0 for corp in ("nova_ai", "orbit_pay", "volt_grid", "pulse_media", "evermart")},
                "byte_count": 0,
                "hand_count": 0,
                "is_ready": bool(seat["ready"]),
                "turn_order_index": index,
            }
        )
    return {
        "match_id": room["match_id"],
        "version": int(room["version"]),
        "seed": 0,
        "phase": "lobby",
        "active_player_id": None,
        "turn_index": 0,
        "round_number": 0,
        "final_round_flag": False,
        "board": [{"coordinate": coordinate, "occupied": False, "company_id": None} for coordinate in catalog],
        "tile_bag_count": int(rules["tile_count"]),
        "players": players,
        "corporations": [
            {
                "id": corp["id"],
                "name": corp["name"],
                "sector": corp["sector"],
                "active": False,
                "size": 0,
                "cells": [],
                "total_shares": 20,
                "bank_shares": 20,
                "share_price": 0,
            }
            for corp in _lobby_corporations()
        ],
        "crypto_market": {
            "symbol": "BYTE",
            "price": int(rules["byte_initial_price"]),
            "exchange_coin_count": int(rules["byte_supply"]),
            "supply": int(rules["byte_supply"]),
        },
        "sector_sentiment": {sector: 0 for sector in rules["sectors"]},
        "events_remaining": len(load_round_events()),
        "action_log": list(room["log"]),
    }


def _lobby_corporations() -> list[dict[str, Any]]:
    from app.domain.corporations import load_corporations

    return load_corporations()


def _public_player(seat: dict[str, Any], player: dict[str, Any]) -> dict[str, Any]:
    return {
        "id": player["id"],
        "display_name": player["display_name"],
        "connection_state": "connected" if seat["connected"] else "disconnected",
        "cash": int(player["cash"]),
        "holdings_by_corp": {str(corp_id): int(count) for corp_id, count in player["shares"].items()},
        "byte_count": int(player["byte_count"]),
        "hand_count": len(player["hand"]),
        "is_ready": bool(seat["ready"]),
        "turn_order_index": int(player["turn_order_index"]),
    }


def _wire_phase(match: OfflineMatch) -> tuple[str, bool]:
    if match.phase == "completed":
        return "completed", True
    if match.final_round:
        return "final_round", True
    return "playing", False


def _step(room: dict[str, Any]) -> str:
    match = room["match"]
    if not isinstance(match, OfflineMatch):
        return "lobby"
    return str(match.phase)


def _market_left(room: dict[str, Any]) -> int:
    match = room["match"]
    if not isinstance(match, OfflineMatch):
        return 0
    return int(match.market_actions_left)


def _pending(room: dict[str, Any]) -> list[str]:
    match = room["match"]
    if not isinstance(match, OfflineMatch):
        return []
    if match.phase == "choose_survivor":
        return list(match.pending_options)
    if match.phase == "choose_founder":
        return [corp["id"] for corp in match.corporations if not corp["active"]]
    return []


def _hand(room: dict[str, Any], player_id: str) -> list[str]:
    match = room["match"]
    if not isinstance(match, OfflineMatch):
        return []
    player = next(item for item in match.players if item["id"] == player_id)
    return list(player["hand"])
