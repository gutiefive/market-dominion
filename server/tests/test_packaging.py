"""Ship packaging that can be checked without a container daemon or a browser."""

from __future__ import annotations

from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from starlette.websockets import WebSocketDisconnect

from app.files import DatabaseURLError, database_path, find_repo_root, repo_root
from app.logging_json import configure_logging, log_event
from app.main import create_app

ROOT = repo_root()


def test_repo_root_uses_md_repo_root_when_the_walk_misses(tmp_path, monkeypatch):
    protocol = tmp_path / "shared" / "protocol"
    protocol.mkdir(parents=True)
    (protocol / "schema.json").write_text("{}", encoding="utf-8")
    monkeypatch.setenv("MD_REPO_ROOT", str(tmp_path))
    assert find_repo_root(tmp_path / "site-packages" / "app" / "files.py") == tmp_path
    assert repo_root() != tmp_path
    assert (repo_root() / "shared" / "protocol" / "schema.json").is_file()


def test_sqlite_url_selects_the_file_and_postgres_is_rejected(tmp_path, monkeypatch):
    monkeypatch.delenv("MD_DATABASE_PATH", raising=False)
    monkeypatch.setenv("DATABASE_URL", f"sqlite:///{tmp_path}/market.db")
    assert database_path() == tmp_path / "market.db"
    monkeypatch.chdir(tmp_path)
    monkeypatch.setenv("DATABASE_URL", "sqlite:///rooms.db")
    assert database_path() == Path("rooms.db")
    monkeypatch.setenv("DATABASE_URL", "postgresql://market:market@127.0.0.1:5432/market")
    monkeypatch.setenv("MD_DATABASE_PATH", str(tmp_path / "ignored.db"))
    with pytest.raises(DatabaseURLError, match="0001_rooms.sql"):
        database_path()
    monkeypatch.setenv("DATABASE_URL", "mysql://local/market")
    with pytest.raises(DatabaseURLError, match="sqlite:///"):
        create_app()


def test_log_line_omits_secrets(capsys):
    configure_logging()
    log_event(
        "info",
        "api_start",
        database_backend="sqlite",
        session_token="secret-token",
        database_url="postgresql://market:market@db/market",
    )
    line = capsys.readouterr().err
    assert '"message": "api_start"' in line
    assert "secret-token" not in line
    assert "postgresql://" not in line
    assert "sqlite" in line


def test_cors_list_and_socket_origin(tmp_path, monkeypatch):
    monkeypatch.setenv("MD_DATABASE_PATH", str(tmp_path / "market.db"))
    monkeypatch.delenv("DATABASE_URL", raising=False)
    monkeypatch.setenv("MD_CORS_ORIGINS", "http://127.0.0.1:8097, http://localhost:8097")
    application = create_app()
    with TestClient(application) as client:
        ready = client.get("/ready")
        assert ready.json()["cors_origin_count"] == 2
        assert ready.json()["database_backend"] == "sqlite"
        allowed = client.get("/health", headers={"Origin": "http://127.0.0.1:8097"})
        assert allowed.headers["access-control-allow-origin"] == "http://127.0.0.1:8097"
        blocked = client.get("/health", headers={"Origin": "https://evil.example"})
        assert "access-control-allow-origin" not in blocked.headers
        created = client.post(
            "/v1/rooms/commands",
            json={
                "match_id": "cors_room",
                "client_action_id": "c0",
                "expected_state_version": 0,
                "session_token": "guesttoken",
                "command": "create_room",
                "payload": {"nickname": "Rowan"},
            },
        )
        assert created.status_code == 200, created.text
        token = next(
            event["payload"]["session_token"]
            for event in created.json()["events"]
            if "session_token" in event["payload"]
        )
        url = f"/v1/rooms/ws?match_id=cors_room&session_token={token}"
        with pytest.raises(WebSocketDisconnect) as caught:
            with client.websocket_connect(url, headers={"origin": "https://evil.example"}):
                pass
        assert caught.value.code == 1008
        with client.websocket_connect(url, headers={"origin": "http://localhost:8097"}) as socket:
            hello = socket.receive_json()
            assert hello["event"] == "state_snapshot"
        with client.websocket_connect(url) as native:
            assert native.receive_json()["event"] == "state_snapshot"


def test_preset_compose_and_migration_files_match_the_ship_plan():
    preset = (ROOT / "client" / "export_presets.cfg").read_text(encoding="utf-8")
    assert 'name="Web"' in preset
    assert "variant/thread_support=false" in preset
    assert "ensure_cross_origin_isolation_headers=false" in preset
    assert "build/web/index.html" in preset
    project = (ROOT / "client" / "project.godot").read_text(encoding="utf-8")
    assert 'renderer/rendering_method.web="gl_compatibility"' in project
    dockerfile = (ROOT / "infra" / "Dockerfile").read_text(encoding="utf-8")
    assert "10001" in dockerfile
    assert "entrypoint.py" in dockerfile
    assert "MD_REPO_ROOT=/app" in dockerfile
    compose = (ROOT / "infra" / "docker-compose.yml").read_text(encoding="utf-8")
    assert "postgres:16-alpine" in compose
    assert 'profiles: ["postgres"]' in compose
    assert 'profiles: ["web"]' in compose
    api_section = compose.split("postgres:", 1)[0]
    assert "postgresql://" not in api_section
    assert "postgres://" not in api_section
    sql = (ROOT / "infra" / "migrations" / "0001_rooms.sql").read_text(encoding="utf-8")
    assert "schema_meta" in sql and "rooms" in sql and "'schema_version', '1'" in sql
    example = (ROOT / ".env.example").read_text(encoding="utf-8")
    assert "DATABASE_URL" in example
    assert "MD_CORS_ORIGINS" in example
    assert "BEGIN " not in example
