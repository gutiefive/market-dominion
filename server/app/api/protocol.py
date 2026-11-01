"""Read-only protocol endpoints.

Validation does not create rooms, move cash, or change a match. ``applied`` is
always false in M0.
"""

from __future__ import annotations

import json

from fastapi import APIRouter, HTTPException, Request

from app.contract import command_errors, load_schema
from app.files import load_rules

router = APIRouter(prefix="/v1/protocol")


@router.get("/schema")
def get_schema() -> dict[str, object]:
    return load_schema()


@router.post("/commands/validate")
async def validate_command(request: Request) -> dict[str, object]:
    raw = await request.body()
    limit = int(load_rules()["command_byte_limit"])
    if len(raw) > limit:
        raise HTTPException(
            status_code=413,
            detail={
                "valid": False,
                "applied": False,
                "code": "payload_too_large",
                "errors": ["payload_too_large"],
            },
        )
    try:
        payload = json.loads(raw)
    except json.JSONDecodeError:
        raise HTTPException(
            status_code=400,
            detail={
                "valid": False,
                "applied": False,
                "code": "invalid_json",
                "errors": ["invalid_json"],
            },
        ) from None
    errors = command_errors(payload)
    if errors:
        raise HTTPException(
            status_code=422,
            detail={
                "valid": False,
                "applied": False,
                "code": "invalid_command",
                "errors": errors,
            },
        )
    return {
        "valid": True,
        "applied": False,
        "command": payload["command"],
    }
