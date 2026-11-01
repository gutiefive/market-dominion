"""FastAPI entrypoint for the Market Dominion server.

Fictional game currency only. This process does not custody assets or accept
real-money payments.
"""

from __future__ import annotations

from fastapi import FastAPI

from app.api.health import router as health_router
from app.api.protocol import router as protocol_router
from app.version import SERVER_VERSION


def create_app() -> FastAPI:
    app = FastAPI(
        title="Market Dominion",
        version=SERVER_VERSION,
        summary="Fictional-currency game server. No wallets, deposits, or real-money trading.",
    )
    app.include_router(health_router)
    app.include_router(protocol_router)
    return app


app = create_app()
