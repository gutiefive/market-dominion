"""Process settings for local, container, staging, and production.

Values come from the environment. This module does not read secret files
and does not log the values it parses.
"""

from __future__ import annotations

import os
from dataclasses import dataclass

from app.http_policy import cors_origins

_ENVIRONMENTS = {"local", "container", "staging", "production"}


class SettingsError(RuntimeError):
    """The process environment is not a usable Market Dominion configuration."""


@dataclass(frozen=True)
class Settings:
    environment: str
    host: str
    port: int
    public_api_url: str
    public_ws_url: str
    cors_origins: tuple[str, ...]
    log_level: str
    room_create_limit: int
    command_limit: int
    grace_seconds: float
    deadline_poll_seconds: float
    session_ttl_seconds: float


def load_settings() -> Settings:
    environment = os.environ.get("MD_ENV", "local").strip().lower() or "local"
    if environment not in _ENVIRONMENTS:
        raise SettingsError("MD_ENV must be local, container, staging, or production")
    host = os.environ.get("MD_HOST", "127.0.0.1").strip() or "127.0.0.1"
    port = _positive_int("MD_PORT", os.environ.get("MD_PORT", "8741"), minimum=1, maximum=65535)
    public_api = os.environ.get("MD_PUBLIC_API_URL", "").strip().rstrip("/")
    public_ws = os.environ.get("MD_PUBLIC_WS_URL", "").strip().rstrip("/")
    if public_api and not _http_url(public_api):
        raise SettingsError("MD_PUBLIC_API_URL must start with http:// or https://")
    if not public_ws and public_api:
        public_ws = _ws_from_http(public_api)
    if public_ws and not (public_ws.startswith("ws://") or public_ws.startswith("wss://")):
        raise SettingsError("MD_PUBLIC_WS_URL must start with ws:// or wss://")
    origins = tuple(cors_origins())
    if environment == "production":
        if not public_api.startswith("https://"):
            raise SettingsError("production requires MD_PUBLIC_API_URL to start with https://")
        if not public_ws.startswith("wss://"):
            raise SettingsError("production requires a wss:// WebSocket URL")
        if _loopback(public_api) or _loopback(public_ws):
            raise SettingsError("production URLs must not use loopback")
        if not origins:
            raise SettingsError("production requires MD_CORS_ORIGINS")
    elif environment == "staging":
        if not origins:
            raise SettingsError("staging requires MD_CORS_ORIGINS")
        if public_api and not public_api.startswith("https://"):
            raise SettingsError("staging MD_PUBLIC_API_URL must start with https://")
        if public_ws and not public_ws.startswith("wss://"):
            raise SettingsError("staging MD_PUBLIC_WS_URL must start with wss://")
    return Settings(
        environment=environment,
        host=host,
        port=port,
        public_api_url=public_api,
        public_ws_url=public_ws,
        cors_origins=origins,
        log_level=os.environ.get("MD_LOG_LEVEL", "info").strip().lower() or "info",
        room_create_limit=_positive_int("MD_ROOM_CREATE_LIMIT", os.environ.get("MD_ROOM_CREATE_LIMIT", "30"), minimum=1, maximum=1000),
        command_limit=_positive_int("MD_COMMAND_LIMIT", os.environ.get("MD_COMMAND_LIMIT", "80"), minimum=1, maximum=10000),
        grace_seconds=_positive_float("MD_GRACE_SECONDS", os.environ.get("MD_GRACE_SECONDS", "120"), minimum=0.0),
        deadline_poll_seconds=_positive_float("MD_DEADLINE_POLL_SECONDS", os.environ.get("MD_DEADLINE_POLL_SECONDS", "2"), minimum=0.2),
        session_ttl_seconds=_positive_float("MD_SESSION_TTL_SECONDS", os.environ.get("MD_SESSION_TTL_SECONDS", "86400"), minimum=60.0),
    )


def _positive_int(name: str, raw: str | None, minimum: int, maximum: int) -> int:
    text = (raw or "").strip()
    try:
        value = int(text)
    except ValueError as exc:
        raise SettingsError(f"{name} must be an integer") from exc
    if value < minimum or value > maximum:
        raise SettingsError(f"{name} is outside {minimum}..{maximum}")
    return value


def _positive_float(name: str, raw: str | None, minimum: float) -> float:
    text = (raw or "").strip()
    try:
        value = float(text)
    except ValueError as exc:
        raise SettingsError(f"{name} must be a number") from exc
    if value < minimum:
        raise SettingsError(f"{name} must be at least {minimum}")
    return value


def _http_url(value: str) -> bool:
    return value.startswith("https://") or value.startswith("http://")


def _ws_from_http(value: str) -> str:
    if value.startswith("https://"):
        return "wss://" + value.removeprefix("https://")
    if value.startswith("http://"):
        return "ws://" + value.removeprefix("http://")
    return ""


def _loopback(value: str) -> bool:
    host = value.split("://", 1)[-1].split("/", 1)[0].lower()
    return host.startswith("127.0.0.1") or host.startswith("localhost") or host.startswith("[::1]")
