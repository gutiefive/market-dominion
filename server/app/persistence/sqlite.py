"""Schema version 0: a meta row and no match tables.

Match persistence begins in a later milestone. This stub only proves the
process can open SQLite and remember that no game schema has been migrated.
"""

from __future__ import annotations

import sqlite3
from pathlib import Path

from app.files import database_path

SCHEMA_VERSION = "0"


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
        INSERT OR IGNORE INTO schema_meta (key, value)
        VALUES ('schema_version', ?)
        """,
        (SCHEMA_VERSION,),
    )
    connection.commit()
    return connection


def schema_version(connection: sqlite3.Connection) -> str:
    row = connection.execute(
        "SELECT value FROM schema_meta WHERE key = 'schema_version'"
    ).fetchone()
    if row is None:
        raise RuntimeError("schema_meta is missing schema_version")
    return str(row[0])
