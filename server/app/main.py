"""FastAPI entrypoint for the Market Dominion server.

Fictional game currency only. This process does not custody assets or accept
real-money payments.
"""

from __future__ import annotations

import os

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.api.health import router as health_router
from app.api.protocol import router as protocol_router
from app.api.rooms import RoomHub, router as rooms_router
from app.http_policy import cors_origins
from app.logging_json import configure_logging, log_event
from app.rooms import RoomService
from app.version import SERVER_VERSION


def create_app() -> FastAPI:
    configure_logging()
    origins = cors_origins()
    app = FastAPI(
        title="Market Dominion",
        version=SERVER_VERSION,
        summary="Fictional-currency game server. No wallets, deposits, or real-money trading.",
    )
    if origins:
        app.add_middleware(
            CORSMiddleware,
            allow_origins=origins,
            allow_credentials=False,
            allow_methods=["GET", "POST", "OPTIONS"],
            allow_headers=["*"],
        )
    app.state.cors_origins = origins
    app.state.database_backend = "sqlite"
    app.state.rooms = RoomService()
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
        database_backend="sqlite",
        cors_origin_count=len(origins),
        log_level=os.environ.get("MD_LOG_LEVEL", "info"),
    )
    return app


app = create_app()
