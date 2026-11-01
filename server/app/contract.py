"""Validate commands, events, and public states against the shared schema."""

from __future__ import annotations

import copy
from typing import Any

from jsonschema import Draft202012Validator

from app.files import load_json


def load_schema() -> dict[str, Any]:
    schema = load_json("protocol/schema.json")
    if not isinstance(schema, dict):
        raise TypeError("protocol schema must be an object")
    return schema


def schema_view(definition: str) -> dict[str, Any]:
    """Expose one ``$defs`` entry as a root schema so internal refs resolve."""
    schema = load_schema()
    body = copy.deepcopy(schema["$defs"][definition])
    return {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$defs": schema["$defs"],
        **body,
    }


def _format_error(error: Any) -> str:
    location = "$"
    for part in error.absolute_path:
        if isinstance(part, int):
            location += f"[{part}]"
        else:
            location += f".{part}"
    return f"{location}: {error.message}"


def schema_errors(instance: object, definition: str) -> list[str]:
    validator = Draft202012Validator(schema_view(definition))
    found = sorted(validator.iter_errors(instance), key=lambda error: list(error.absolute_path))
    return [_format_error(error) for error in found]


def command_errors(instance: object) -> list[str]:
    return schema_errors(instance, "command_envelope")


def event_errors(instance: object) -> list[str]:
    return schema_errors(instance, "event_envelope")


def public_state_schema_errors(instance: object) -> list[str]:
    return schema_errors(instance, "public_state")
