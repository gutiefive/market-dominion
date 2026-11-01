"""HTTP smoke for the M0 server. No match is created."""

from __future__ import annotations

import json
from pathlib import Path

from app.files import repo_root
from app.version import SERVER_VERSION

ROOT = repo_root()


def test_health_ready_and_schema(client):
    health = client.get("/health")
    assert health.status_code == 200
    body = health.json()
    assert body == {
        "status": "ok",
        "service": "market-dominion-server",
        "version": SERVER_VERSION,
        "currency": "fictional",
        "environment": "local",
    }
    assert "wallet" not in json.dumps(body).lower()
    ready = client.get("/ready")
    assert ready.status_code == 200
    ready_body = ready.json()
    assert ready_body["status"] == "ready"
    assert ready_body["database_schema_version"] == "1"
    assert ready_body["database_backend"] == "sqlite"
    assert ready_body["cors_origin_count"] == 0
    assert ready_body["command_count"] == 15
    assert ready_body["event_count"] == 14
    assert ready_body["currency"] == "fictional"
    schema = client.get("/v1/protocol/schema")
    assert schema.status_code == 200
    assert schema.json() == json.loads(
        (ROOT / "shared" / "protocol" / "schema.json").read_text(encoding="utf-8")
    )
    docs = client.get("/openapi.json")
    assert docs.status_code == 200
    assert docs.json()["info"]["title"] == "Market Dominion"
    assert docs.json()["info"]["version"] == SERVER_VERSION


def test_validate_accepts_place_tile_without_applying_it(client):
    payload = json.loads(
        (ROOT / "shared" / "fixtures" / "commands" / "place_tile.json").read_text(
            encoding="utf-8"
        )
    )
    response = client.post("/v1/protocol/commands/validate", json=payload)
    assert response.status_code == 200
    assert response.json() == {
        "valid": True,
        "applied": False,
        "command": "place_tile",
    }


def test_validate_rejects_bad_json_bad_commands_and_oversized_bodies(client):
    broken = client.post(
        "/v1/protocol/commands/validate",
        content=b"{",
        headers={"content-type": "application/json"},
    )
    assert broken.status_code == 400
    assert broken.json()["detail"]["code"] == "invalid_json"

    bad = json.loads(
        (ROOT / "shared" / "fixtures" / "invalid_commands" / "bad_coordinate.json").read_text(
            encoding="utf-8"
        )
    )
    rejected = client.post("/v1/protocol/commands/validate", json=bad)
    assert rejected.status_code == 422
    detail = rejected.json()["detail"]
    assert detail["valid"] is False
    assert detail["applied"] is False
    assert detail["code"] == "invalid_command"
    assert detail["errors"]

    oversized = client.post(
        "/v1/protocol/commands/validate",
        content=b'{"x":"' + (b"a" * 20000) + b'"}',
        headers={"content-type": "application/json"},
    )
    assert oversized.status_code == 413
    assert oversized.json()["detail"]["code"] == "payload_too_large"
