"""Deployment files that can be checked without a host account or a browser."""

from __future__ import annotations

import sys

from app.files import repo_root
from app.settings import load_settings

ROOT = repo_root()


def _assignments(path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        key, sep, value = line.partition("=")
        assert sep == "=", line
        values[key] = value
    return values


def test_production_env_example_loads(monkeypatch):
    path = ROOT / "infra" / "deploy" / "production.env.example"
    values = _assignments(path)
    expected = (
        "MD_ENV",
        "MD_HOST",
        "MD_PORT",
        "MD_PUBLIC_API_URL",
        "MD_PUBLIC_WS_URL",
        "MD_CORS_ORIGINS",
        "MD_DATABASE_PATH",
        "MD_LOG_LEVEL",
        "MD_GRACE_SECONDS",
        "MD_DEADLINE_POLL_SECONDS",
        "MD_SESSION_TTL_SECONDS",
        "MD_ROOM_CREATE_LIMIT",
        "MD_COMMAND_LIMIT",
    )
    for key in expected:
        assert key in values
        monkeypatch.setenv(key, values[key])
    monkeypatch.delenv("DATABASE_URL", raising=False)
    settings = load_settings()
    assert settings.environment == "production"
    assert settings.public_api_url == "https://api.example.com"
    assert settings.public_ws_url == "wss://api.example.com"
    assert settings.cors_origins == ("https://play.example.com",)
    assert settings.grace_seconds == 120.0
    text = path.read_text(encoding="utf-8")
    assert "session_token" not in text
    assert "postgresql://" not in text
    assert "BEGIN " not in text


def test_static_host_and_caddy_examples_exist():
    headers = (ROOT / "infra" / "deploy" / "cloudflare" / "_headers").read_text(encoding="utf-8")
    assert "application/wasm" in headers
    assert "no-cache" in headers
    assert "must-revalidate" in headers
    assert "Cross-Origin-Opener-Policy" not in headers
    caddy = (ROOT / "infra" / "deploy" / "caddy" / "Caddyfile").read_text(encoding="utf-8")
    assert "reverse_proxy" in caddy
    assert "8741" in caddy
    export = (ROOT / "scripts" / "export_web.sh").read_text(encoding="utf-8")
    assert "4.7.2" in export
    assert "web_build.py" in export
    assert "rules_constants.json" in export


def test_web_verifier_accepts_a_finished_tree_and_rejects_loopback(tmp_path):
    sys.path.insert(0, str(ROOT / "scripts"))
    import web_build

    directory = tmp_path / "web"
    directory.mkdir()
    (directory / "index.html").write_text(
        "<head>\n"
        '<script src="md-config.js"></script>\n'
        "index.js index.wasm index.pck\n"
        "GODOT_THREADS_ENABLED = false\n",
        encoding="utf-8",
    )
    (directory / "index.js").write_text("loader", encoding="utf-8")
    (directory / "index.wasm").write_bytes(b"\0asm")
    (directory / "index.pck").write_bytes(b"export_shared rules_constants.json schema.json")
    (directory / "md-config.js").write_text(web_build.MD_CONFIG, encoding="utf-8")
    (directory / "_headers").write_text(
        (ROOT / "infra" / "deploy" / "cloudflare" / "_headers").read_text(encoding="utf-8"),
        encoding="utf-8",
    )
    (directory / "BUILD.txt").write_text("godot=4.7.2.stable\nthreads=false\n", encoding="utf-8")
    assert web_build.verify(directory) == []
    (directory / "md-config.js").write_text('window.MD_SERVER = "http://127.0.0.1:8741";\n', encoding="utf-8")
    problems = web_build.verify(directory)
    assert any("127.0.0.1" in item for item in problems)
