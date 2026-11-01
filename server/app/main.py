"""FastAPI entrypoint for the Market Dominion server.

Fictional game currency only. This process does not custody assets or accept
real-money payments.
"""

from __future__ import annotations

import asyncio
from contextlib import suppress
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.api.health import router as health_router
from app.api.protocol import router as protocol_router
from app.api.rooms import RoomHub, router as rooms_router
from app.http_policy import cors_origins
from app.logging_json import configure_logging, log_event
from app.rooms import RoomService
from app.settings import load_settings
from app.version import SERVER_VERSION


@asynccontextmanager
async def _lifespan(app: FastAPI):
    stop = asyncio.Event()
    task = asyncio.create_task(_deadline_loop(app, stop))
    try:
        yield
    finally:
        stop.set()
        task.cancel()
        with suppress(asyncio.CancelledError):
            await task


async def _deadline_loop(app: FastAPI, stop: asyncio.Event) -> None:
    poll = float(app.state.settings.deadline_poll_seconds)
    while not stop.is_set():
        try:
            await asyncio.wait_for(stop.wait(), timeout=poll)
            return
        except TimeoutError:
            pass
        try:
            due = app.state.rooms.sweep_due()
        except Exception as exc:
            log_event("error", "deadline_sweep_failed", error_type=type(exc).__name__)
            continue
        hub: RoomHub = app.state.hub
        service: RoomService = app.state.rooms
        for match_id, events in due:
            log_event("info", "turn_timed_out", match_id=match_id, event_count=len(events))
            await hub.publish(service, match_id, events)


def create_app() -> FastAPI:
    configure_logging()
    settings = load_settings()
    origins = cors_origins()
    app = FastAPI(
        title="Market Dominion",
        version=SERVER_VERSION,
        summary="Fictional-currency game server. No wallets, deposits, or real-money trading.",
        lifespan=_lifespan,
    )
    if origins:
        app.add_middleware(
            CORSMiddleware,
            allow_origins=origins,
            allow_credentials=False,
            allow_methods=["GET", "POST", "OPTIONS"],
            allow_headers=["*"],
        )
    app.state.settings = settings
    app.state.cors_origins = origins
    app.state.database_backend = "sqlite"
    app.state.rooms = RoomService(
        grace_seconds=settings.grace_seconds,
        session_ttl_seconds=settings.session_ttl_seconds,
        create_limit=settings.room_create_limit,
        command_limit=settings.command_limit,
    )
    app.state.hub = RoomHub()
    app.include_router(health_router)
    app.include_router(protocol_router)
    app.include_router(rooms_router)

    @app.exception_handler(Exception)
    async def unhandled(request: Request, exc: Exception) -> JSONResponse:
        log_event(
            "error",
            "unhandled",
            path=request.url.path,
            error_type=type(exc).__name__,
        )
        return JSONResponse(status_code=500, content={"detail": "server_error"})

    log_event(
        "info",
        "api_start",
        version=SERVER_VERSION,
        environment=settings.environment,
        database_backend="sqlite",
        cors_origin_count=len(origins),
        log_level=settings.log_level,
    )
    return app


app = create_app()
