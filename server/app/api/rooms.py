"""HTTP and WebSocket entry points for authoritative rooms.

``POST /v1/protocol/commands/validate`` still does not apply a move.
This router does. Each socket is bound to one session token.
"""

from __future__ import annotations

import asyncio
import json
from typing import Any

from fastapi import APIRouter, Request, WebSocket, WebSocketDisconnect
from fastapi.responses import JSONResponse

from app.files import load_rules
from app.rooms import Applied, RoomError, RoomService

router = APIRouter()

_STATUS = {
    "invalid_json": 400,
    "payload_too_large": 413,
    "invalid_command": 422,
    "invalid_nickname": 422,
    "unauthorized": 401,
    "not_found": 404,
    "rate_limited": 429,
    "stale_version": 409,
    "duplicate_action": 409,
    "out_of_turn": 409,
    "wrong_phase": 409,
    "illegal_tile": 409,
    "insufficient_cash": 409,
    "insufficient_inventory": 409,
}


class RoomHub:
    """Per-session queues so one socket task is the only sender."""

    def __init__(self) -> None:
        self.queues: dict[str, dict[str, asyncio.Queue[dict[str, Any]]]] = {}

    def attach(self, match_id: str, token: str) -> asyncio.Queue[dict[str, Any]]:
        queue: asyncio.Queue[dict[str, Any]] = asyncio.Queue()
        self.queues.setdefault(match_id, {})[token] = queue
        return queue

    def detach(self, match_id: str, token: str) -> None:
        room = self.queues.get(match_id)
        if room is None:
            return
        room.pop(token, None)
        if not room:
            self.queues.pop(match_id, None)

    async def publish(
        self,
        service: RoomService,
        match_id: str,
        events: list[dict[str, Any]],
        skip_token: str | None = None,
    ) -> None:
        for token, queue in list(self.queues.get(match_id, {}).items()):
            if token == skip_token:
                continue
            for event in events:
                await queue.put(_personalize(service, match_id, token, event))


def _personalize(service: RoomService, match_id: str, token: str, event: dict[str, Any]) -> dict[str, Any]:
    if event.get("event") != "state_snapshot":
        return event
    payload = dict(event.get("payload", {}))
    if "your_hand" in payload:
        return event
    player_id, hand = service.private_hand(match_id, token)
    payload["you"] = player_id
    payload["your_hand"] = hand
    return {**event, "payload": payload}


def _error_event(error: RoomError) -> dict[str, Any]:
    return {
        "event": "error",
        "match_id": error.match_id if _safe_id(error.match_id) else "missing",
        "state_version": max(0, int(error.version)),
        "payload": {"code": error.code, "message": error.message},
    }


def _safe_id(value: str) -> bool:
    if not 1 <= len(value) <= 64:
        return False
    return all(character.isalnum() or character in "_-" for character in value)


@router.post("/v1/rooms/commands")
async def apply_command(request: Request) -> JSONResponse:
    raw = await request.body()
    limit = int(load_rules()["command_byte_limit"])
    if len(raw) > limit:
        error = RoomError("payload_too_large", "payload too large")
        return JSONResponse(status_code=413, content={"events": [_error_event(error)]})
    try:
        payload = json.loads(raw)
    except json.JSONDecodeError:
        error = RoomError("invalid_json", "invalid JSON")
        return JSONResponse(status_code=400, content={"events": [_error_event(error)]})
    service: RoomService = request.app.state.rooms
    hub: RoomHub = request.app.state.hub
    try:
        applied = service.apply(payload)
    except RoomError as error:
        await hub.publish(service, error.match_id, error.notices)
        return JSONResponse(
            status_code=_STATUS.get(error.code, 409),
            content={"events": [_error_event(error)]},
        )
    match_id = str(payload["match_id"])
    await hub.publish(service, match_id, applied.notices)
    await hub.publish(service, match_id, applied.public, skip_token=_actor_token(applied))
    return JSONResponse(content={"replayed": applied.replayed, "events": applied.direct})


def _actor_token(applied: Applied) -> str | None:
    for event in applied.direct:
        token = event.get("payload", {}).get("session_token")
        if isinstance(token, str):
            return token
    you = None
    for event in applied.direct:
        if event.get("event") == "state_snapshot":
            you = event.get("payload", {}).get("you")
    return None if not isinstance(you, str) else None


@router.websocket("/v1/rooms/ws")
async def room_socket(websocket: WebSocket, match_id: str, session_token: str) -> None:
    await websocket.accept()
    service: RoomService = websocket.app.state.rooms
    hub: RoomHub = websocket.app.state.hub
    try:
        hello = service.hello(match_id, session_token)
    except RoomError as error:
        await websocket.send_json(_error_event(error))
        await websocket.close()
        return
    queue = hub.attach(match_id, session_token)
    sender = asyncio.create_task(_pump(websocket, queue))
    for event in hello.direct:
        await queue.put(event)
    try:
        while True:
            raw = await websocket.receive_text()
            limit = int(load_rules()["command_byte_limit"])
            if len(raw.encode("utf-8")) > limit:
                await queue.put(_error_event(RoomError("payload_too_large", "payload too large", match_id=match_id)))
                continue
            try:
                payload = json.loads(raw)
            except json.JSONDecodeError:
                await queue.put(_error_event(RoomError("invalid_json", "invalid JSON", match_id=match_id)))
                continue
            if not isinstance(payload, dict) or payload.get("match_id") != match_id or payload.get("session_token") != session_token:
                await queue.put(
                    _error_event(
                        RoomError(
                            "unauthorized",
                            "socket is bound to a different session",
                            match_id=match_id if _safe_id(match_id) else "missing",
                        )
                    )
                )
                continue
            try:
                applied = service.apply(payload)
            except RoomError as error:
                await hub.publish(service, match_id, error.notices)
                await queue.put(_error_event(error))
                continue
            await hub.publish(service, match_id, applied.notices)
            for event in applied.direct:
                await queue.put(event)
            await hub.publish(service, match_id, applied.public, skip_token=session_token)
    except WebSocketDisconnect:
        pass
    finally:
        sender.cancel()
        hub.detach(match_id, session_token)
        notice = service.bye(match_id, session_token)
        if notice is not None:
            await hub.publish(service, match_id, [notice])


async def _pump(websocket: WebSocket, queue: asyncio.Queue[dict[str, Any]]) -> None:
    while True:
        event = await queue.get()
        await websocket.send_json(event)
