"""SQLite schema version 1: a meta row and one JSON blob per room.

Version 0 databases are upgraded in place. The blob is the authoritative room,
including private hands and the match generator state.
"""

from __future__ import annotations

import sqlite3
from pathlib import Path

from app.files import database_path

SCHEMA_VERSION = "1"


def connect(path: Path | None = None) -> sqlite3.Connection:
    db_path = path if path is not None else database_path()
    db_path.parent.mkdir(parents=True, exist_ok=True)
    connection = sqlite3.connect(db_path)
    connection.execute("PRAGMA foreign_keys = ON")
    connection.execute(
        """
        CREATE TABLE IF NOT EXISTS schema_meta (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        )
        """
    )
    connection.execute(
        """
        CREATE TABLE IF NOT EXISTS rooms (
            match_id TEXT PRIMARY KEY,
            invite_code TEXT NOT NULL UNIQUE,
            blob TEXT NOT NULL
        )
        """
    )
    row = connection.execute(
        "SELECT value FROM schema_meta WHERE key = 'schema_version'"
    ).fetchone()
    if row is None:
        connection.execute(
            "INSERT INTO schema_meta (key, value) VALUES ('schema_version', ?)",
            (SCHEMA_VERSION,),
        )
    elif str(row[0]) == "0":
        connection.execute(
            "UPDATE schema_meta SET value = ? WHERE key = 'schema_version'",
            (SCHEMA_VERSION,),
        )
    elif str(row[0]) != SCHEMA_VERSION:
        raise RuntimeError(f"unsupported schema_version {row[0]}")
    connection.commit()
    return connection


def schema_version(connection: sqlite3.Connection) -> str:
    row = connection.execute(
        "SELECT value FROM schema_meta WHERE key = 'schema_version'"
    ).fetchone()
    if row is None:
        raise RuntimeError("schema_meta is missing schema_version")
    return str(row[0])
