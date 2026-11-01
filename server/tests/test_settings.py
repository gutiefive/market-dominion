"""Environment profiles for the browser beta."""

from __future__ import annotations

import pytest

from app.settings import SettingsError, load_settings


def test_local_defaults_and_public_ws_is_derived(monkeypatch):
    monkeypatch.delenv("MD_ENV", raising=False)
    monkeypatch.delenv("MD_PUBLIC_API_URL", raising=False)
    monkeypatch.delenv("MD_PUBLIC_WS_URL", raising=False)
    monkeypatch.delenv("MD_CORS_ORIGINS", raising=False)
    settings = load_settings()
    assert settings.environment == "local"
    assert settings.grace_seconds == 120
    assert settings.session_ttl_seconds == 86400
    monkeypatch.setenv("MD_PUBLIC_API_URL", "https://api.example.test/root/")
    derived = load_settings()
    assert derived.public_api_url == "https://api.example.test/root"
    assert derived.public_ws_url == "wss://api.example.test/root"


def test_production_rejects_loopback_and_missing_cors(monkeypatch):
    monkeypatch.setenv("MD_ENV", "production")
    monkeypatch.setenv("MD_PUBLIC_API_URL", "http://api.example.test")
    monkeypatch.setenv("MD_CORS_ORIGINS", "https://play.example.test")
    with pytest.raises(SettingsError, match="https://"):
        load_settings()
    monkeypatch.setenv("MD_PUBLIC_API_URL", "https://127.0.0.1:8741")
    with pytest.raises(SettingsError, match="loopback"):
        load_settings()
    monkeypatch.setenv("MD_PUBLIC_API_URL", "https://api.example.test")
    monkeypatch.delenv("MD_CORS_ORIGINS", raising=False)
    with pytest.raises(SettingsError, match="MD_CORS_ORIGINS"):
        load_settings()
    monkeypatch.setenv("MD_CORS_ORIGINS", "https://play.example.test")
    ready = load_settings()
    assert ready.public_ws_url == "wss://api.example.test"
    assert ready.cors_origins == ("https://play.example.test",)


def test_unknown_environment_is_rejected(monkeypatch):
    monkeypatch.setenv("MD_ENV", "prod")
    with pytest.raises(SettingsError, match="MD_ENV"):
        load_settings()
