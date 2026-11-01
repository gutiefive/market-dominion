"""Origin allow-list read from the environment. No secrets live here."""

from __future__ import annotations

import os


def cors_origins() -> list[str]:
    """Comma-separated browser origins. Empty means the desktop default: no CORS middleware."""
    raw = os.environ.get("MD_CORS_ORIGINS", "").strip()
    if not raw:
        return []
    return [part.strip() for part in raw.split(",") if part.strip()]


def origin_allowed(origin: str | None) -> bool:
    """A missing Origin is the native Godot client. A browser Origin must be listed.

    An empty allow-list does not check Origin. Set ``MD_CORS_ORIGINS`` before
    a browser page on another origin calls the API.
    """
    allowed = cors_origins()
    if not allowed:
        return True
    if origin is None or origin == "":
        return True
    return origin in allowed
