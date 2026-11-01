"""Authoritative rooms: privacy, versions, idempotency, reconnect, restart."""

from __future__ import annotations

import json

from app.domain.offline import OfflineMatch
from app.rooms import RoomService

TOKEN = "guesttoken"


def _command(match_id: str, action: str, version: int, command: str, payload: dict, token: str = TOKEN) -> dict:
    return {
        "match_id": match_id,
        "client_action_id": action,
        "expected_state_version": version,
        "session_token": token,
        "command": command,
        "payload": payload,
    }


def _open_pair(service: RoomService, match_id: str = "room_one") -> tuple[dict, dict]:
    created = service.apply(_command(match_id, "c0", 0, "create_room", {"nickname": "Rowan"}))
    host = _session(created)
    code = _invite(created)
    joined = service.apply(
        _command(match_id, "j0", 0, "join_room", {"invite_code": code, "nickname": "Quinn"}, token="joinertoken")
    )
    guest = _session(joined)
    return host, guest


def _session(applied) -> dict:
    payload = next(event["payload"] for event in applied.direct if "session_token" in event["payload"])
    return payload


def _invite(applied) -> str:
    return next(event["payload"]["invite_code"] for event in applied.direct if event["event"] == "room_updated")


def _snapshot(applied) -> dict:
    return next(event for event in applied.direct if event["event"] == "state_snapshot")


def _state(applied) -> dict:
    return _snapshot(applied)["payload"]["state"]


def _ready_and_start(service: RoomService, match_id: str, host: dict, guest: dict) -> dict:
    version = _state(service.apply(_command(match_id, "rh", _version_of(service, match_id, host), "ready", {"is_ready": True}, host["session_token"])))["version"]
    version = _state(
        service.apply(_command(match_id, "rg", version, "ready", {"is_ready": True}, guest["session_token"]))
    )["version"]
    return service.apply(_command(match_id, "st", version, "start_match", {}, host["session_token"]))


def _version_of(service: RoomService, match_id: str, seat: dict) -> int:
    snap = service.apply(_command(match_id, f"snap-{seat['player_id']}-{id(seat)}", 0, "request_snapshot", {}, seat["session_token"]))
    return int(_state(snap)["version"])


def test_two_sessions_hide_hands_and_follow_the_server_seed(tmp_path):
    service = RoomService(database=tmp_path / "rooms.db", seed=7710)
    host, guest = _open_pair(service)
    started = _ready_and_start(service, "room_one", host, guest)
    state = _state(started)
    assert state["phase"] == "playing"
    assert state["seed"] == 7710
    assert state["active_player_id"] == "p1"
    local = OfflineMatch(7710, ["Rowan", "Quinn"])
    host_hand = next(player["hand"] for player in local.players if player["id"] == "p1")
    guest_hand = next(player["hand"] for player in local.players if player["id"] == "p2")
    assert _snapshot(started)["payload"]["your_hand"] == host_hand
    guest_view = service.apply(_command("room_one", "sg", 0, "request_snapshot", {}, guest["session_token"]))
    assert _snapshot(guest_view)["payload"]["your_hand"] == guest_hand
    public_players = json.dumps(_state(guest_view)["players"])
    for tile in host_hand:
        assert tile not in public_players
    assert "your_hand" not in json.dumps(_state(guest_view))
    assert "private_tile_hand" not in json.dumps(_state(guest_view))
    assert state["tile_bag_count"] + sum(player["hand_count"] for player in state["players"]) == 81
    assert all(player["hand_count"] == 5 for player in state["players"])


def test_out_of_turn_stale_version_duplicate_and_foreign_room_are_rejected(tmp_path):
    service = RoomService(database=tmp_path / "rooms.db", seed=7710)
    host, guest = _open_pair(service)
    started = _ready_and_start(service, "room_one", host, guest)
    version = int(_state(started)["version"])
    hand = _snapshot(started)["payload"]["your_hand"]
    try:
        service.apply(_command("room_one", "bad-turn", version, "place_tile", {"coordinate": hand[0]}, guest["session_token"]))
        raise AssertionError("guest was allowed to place")
    except Exception as exc:
        assert exc.code == "out_of_turn"
    placed = service.apply(_command("room_one", "place-1", version, "place_tile", {"coordinate": hand[0]}, host["session_token"]))
    assert _state(placed)["version"] == version + 1
    try:
        service.apply(_command("room_one", "place-2", version, "pass_market_action", {}, host["session_token"]))
        raise AssertionError("stale command applied")
    except Exception as exc:
        assert exc.code == "stale_version"
    current = int(_state(placed)["version"])
    bought = service.apply(_command("room_one", "byte-1", current, "market_buy_byte", {}, host["session_token"]))
    again = service.apply(_command("room_one", "byte-1", current, "market_buy_byte", {}, host["session_token"]))
    assert again.replayed is True
    assert _snapshot(again)["payload"]["state"]["crypto_market"]["exchange_coin_count"] == 29
    assert _snapshot(bought)["payload"]["state"]["crypto_market"]["exchange_coin_count"] == 29
    try:
        service.apply(_command("room_one", "byte-1", current, "market_sell_byte", {}, host["session_token"]))
        raise AssertionError("changed payload reused an action id")
    except Exception as exc:
        assert exc.code == "duplicate_action"
    try:
        service.apply(_command("room_other", "x", 0, "place_tile", {"coordinate": "A1"}, host["session_token"]))
        raise AssertionError("cross-room command applied")
    except Exception as exc:
        assert exc.code == "unauthorized"
    try:
        service.apply(_command("room_one", "nope", current, "place_tile", {"coordinate": "A1"}, "not-a-real-token"))
        raise AssertionError("unknown token applied")
    except Exception as exc:
        assert exc.code == "unauthorized"


def test_fabricated_tile_and_forged_cash_do_not_change_the_match(tmp_path):
    service = RoomService(database=tmp_path / "rooms.db", seed=7710)
    host, guest = _open_pair(service)
    started = _ready_and_start(service, "room_one", host, guest)
    version = int(_state(started)["version"])
    cash = _state(started)["players"][0]["cash"]
    try:
        service.apply(_command("room_one", "fake", version, "place_tile", {"coordinate": "Z9"}, host["session_token"]))
        raise AssertionError("bad coordinate applied")
    except Exception as exc:
        assert exc.code == "invalid_command"
    try:
        service.apply(
            _command(
                "room_one",
                "forge",
                version,
                "place_tile",
                {"coordinate": "A1", "cash": 999999},
                host["session_token"],
            )
        )
        raise AssertionError("forged cash applied")
    except Exception as exc:
        assert exc.code == "invalid_command"
    fresh = service.apply(_command("room_one", "after-forge", 0, "request_snapshot", {}, host["session_token"]))
    assert _state(fresh)["version"] == version
    assert _state(fresh)["players"][0]["cash"] == cash
    try:
        service.apply(_command("room_one", "missing", version, "place_tile", {"coordinate": "I9"}, host["session_token"]))
        raise AssertionError("tile outside the hand applied")
    except Exception as exc:
        assert exc.code == "illegal_tile"


def test_restart_restores_the_private_hand_and_websocket_two_clients_see_one_room(tmp_path):
    path = tmp_path / "rooms.db"
    first = RoomService(database=path, seed=7710)
    host, guest = _open_pair(first, "room_restart")
    started = _ready_and_start(first, "room_restart", host, guest)
    hand = list(_snapshot(started)["payload"]["your_hand"])
    version = int(_state(started)["version"])
    second = RoomService(database=path, seed=7710)
    restored = second.apply(_command("room_restart", "again", 0, "request_snapshot", {}, host["session_token"]))
    assert _snapshot(restored)["payload"]["your_hand"] == hand
    assert int(_state(restored)["version"]) == version
    placed = second.apply(
        _command("room_restart", "place-restart", version, "place_tile", {"coordinate": hand[0]}, host["session_token"])
    )
    assert hand[0] not in _snapshot(placed)["payload"]["your_hand"]
    guest_view = second.apply(_command("room_restart", "guest-see", 0, "request_snapshot", {}, guest["session_token"]))
    assert hand[0] not in _snapshot(guest_view)["payload"]["your_hand"]
    assert all(cell["coordinate"] != hand[0] or cell["occupied"] for cell in _state(placed)["board"])


def test_host_cannot_start_until_two_players_are_ready_and_disconnect_autopass_is_deterministic(tmp_path):
    service = RoomService(database=tmp_path / "rooms.db", seed=7710, grace_seconds=0, clock=lambda: 5000.0)
    host, guest = _open_pair(service, "room_gate")
    try:
        service.apply(_command("room_gate", "early", 2, "start_match", {}, host["session_token"]))
        raise AssertionError("started before ready")
    except Exception as exc:
        assert exc.code == "wrong_phase"
    started = _ready_and_start(service, "room_gate", host, guest)
    version = int(_state(started)["version"])
    service.bye("room_gate", host["session_token"])
    nudged = service.apply(_command("room_gate", "nudge", version, "request_snapshot", {}, guest["session_token"]))
    state = _state(nudged)
    assert state["active_player_id"] == "p2"
    assert state["phase"] in {"playing", "final_round"}
    host_back = service.apply(_command("room_gate", "back", 0, "reconnect", {}, host["session_token"]))
    assert _snapshot(host_back)["payload"]["your_hand"]
    assert any(event["event"] == "player_reconnected" for event in host_back.direct)


def test_http_and_websocket_share_one_room(client):
    created = client.post(
        "/v1/rooms/commands",
        json=_command("http_room", "c0", 0, "create_room", {"nickname": "Rowan"}),
    )
    assert created.status_code == 200, created.text
    body = created.json()
    host_token = next(event["payload"]["session_token"] for event in body["events"] if "session_token" in event["payload"])
    code = next(event["payload"]["invite_code"] for event in body["events"] if event["event"] == "room_updated")
    joined = client.post(
        "/v1/rooms/commands",
        json=_command("http_room", "j0", 0, "join_room", {"invite_code": code, "nickname": "Quinn"}, token="joinertoken"),
    )
    assert joined.status_code == 200, joined.text
    guest_token = next(event["payload"]["session_token"] for event in joined.json()["events"] if "session_token" in event["payload"])
    with client.websocket_connect(f"/v1/rooms/ws?match_id=http_room&session_token={host_token}") as host_socket:
        hello = host_socket.receive_json()
        assert hello["event"] == "state_snapshot"
        assert hello["payload"]["you"] == "p1"
        with client.websocket_connect(f"/v1/rooms/ws?match_id=http_room&session_token={guest_token}") as guest_socket:
            guest_hello = guest_socket.receive_json()
            assert guest_hello["payload"]["you"] == "p2"
            assert guest_hello["payload"]["your_hand"] == []
            ready = {
                "match_id": "http_room",
                "client_action_id": "ws-ready",
                "expected_state_version": hello["state_version"],
                "session_token": host_token,
                "command": "ready",
                "payload": {"is_ready": True},
            }
            host_socket.send_json(ready)
            seen = host_socket.receive_json()
            assert seen["event"] in {"room_updated", "state_snapshot", "player_reconnected"}
            pushed = guest_socket.receive_json()
            assert pushed["event"] in {"room_updated", "state_snapshot", "player_disconnected", "player_reconnected"}
            dumped = json.dumps(pushed)
            assert host_token not in dumped
    stale = client.post(
        "/v1/rooms/commands",
        json=_command("http_room", "late", 0, "ready", {"is_ready": True}, guest_token),
    )
    assert stale.status_code == 409
    assert stale.json()["events"][0]["payload"]["code"] == "stale_version"
    validate = client.post(
        "/v1/protocol/commands/validate",
        json=_command("http_room", "v", 0, "place_tile", {"coordinate": "A1"}, host_token),
    )
    assert validate.status_code == 200
    assert validate.json()["applied"] is False


def test_uvicorn_has_a_websocket_implementation():
    """Starlette's test client can speak WebSocket without this library.

    Uvicorn cannot. A missing implementation turns the upgrade into an HTTP
    GET, and the room socket answers 404.
    """

    from uvicorn.protocols.websockets.auto import AutoWebSocketsProtocol

    assert AutoWebSocketsProtocol is not None
