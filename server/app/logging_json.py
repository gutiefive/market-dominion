"""One JSON object per log line. No remote alert sink is attached."""

from __future__ import annotations

import json
import logging
import os
from typing import Any

_SECRET_KEYS = {
    "password",
    "secret",
    "token",
    "session_token",
    "database_url",
    "authorization",
}


class JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        payload: dict[str, Any] = {
            "level": record.levelname.lower(),
            "logger": record.name,
            "message": record.getMessage(),
        }
        fields = getattr(record, "fields", None)
        if isinstance(fields, dict):
            for key, value in fields.items():
                if key.lower() in _SECRET_KEYS:
                    continue
                payload[key] = value
        if record.exc_info:
            payload["error"] = self.formatException(record.exc_info)
        return json.dumps(payload, default=str)


def configure_logging() -> None:
    raw = os.environ.get("MD_LOG_LEVEL", "info").upper()
    level = getattr(logging, raw, logging.INFO)
    if not isinstance(level, int):
        level = logging.INFO
    logger = logging.getLogger("market")
    logger.handlers.clear()
    logger.setLevel(level)
    logger.propagate = False
    handler = logging.StreamHandler()
    handler.setFormatter(JsonFormatter())
    logger.addHandler(handler)


def log_event(level: str, message: str, **fields: object) -> None:
    logger = logging.getLogger("market")
    numeric = getattr(logging, level.upper(), logging.INFO)
    if not isinstance(numeric, int):
        numeric = logging.INFO
    logger.log(numeric, message, extra={"fields": fields})
