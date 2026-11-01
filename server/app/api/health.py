"""Liveness and readiness."""

from __future__ import annotations

from fastapi import APIRouter, Request

from app.contract import load_schema
from app.files import load_rules
from app.persistence.sqlite import connect, schema_version
from app.version import SERVER_VERSION

router = APIRouter()


@router.get("/")
def root() -> dict[str, str]:
    return {
        "service": "market-dominion-server",
        "version": SERVER_VERSION,
        "currency": "fictional",
        "health": "/health",
        "ready": "/ready",
        "docs": "/docs",
        "schema": "/v1/protocol/schema",
    }


@router.get("/health")
def health() -> dict[str, str]:
    return {
        "status": "ok",
        "service": "market-dominion-server",
        "version": SERVER_VERSION,
        "currency": "fictional",
    }


@router.get("/ready")
def ready(request: Request) -> dict[str, object]:
    schema = load_schema()
    rules = load_rules()
    connection = connect()
    try:
        version = schema_version(connection)
    finally:
        connection.close()
    return {
        "status": "ready",
        "schema_id": schema["$id"],
        "command_count": len(schema["$defs"]["command_name"]["enum"]),
        "event_count": len(schema["$defs"]["event_name"]["enum"]),
        "database_schema_version": version,
        "database_backend": "sqlite",
        "cors_origin_count": len(getattr(request.app.state, "cors_origins", [])),
        "protocol_version": rules["protocol_version"],
        "currency": "fictional",
    }
