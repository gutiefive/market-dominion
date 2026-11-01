"""SQLite schema version 1 stores one row per room."""

from __future__ import annotations

from app.persistence.sqlite import SCHEMA_VERSION, connect, schema_version


def test_new_database_is_version_one_and_upgrades_a_version_zero_file(tmp_path):
    path = tmp_path / "nested" / "market.db"
    first = connect(path)
    first.close()
    connection = connect(path)
    try:
        assert schema_version(connection) == SCHEMA_VERSION == "1"
        tables = {
            row[0]
            for row in connection.execute(
                "SELECT name FROM sqlite_master WHERE type = 'table'"
            )
        }
    finally:
        connection.close()
    assert tables == {"schema_meta", "rooms"}
    legacy = tmp_path / "legacy.db"
    raw = __import__("sqlite3").connect(legacy)
    raw.execute("CREATE TABLE schema_meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)")
    raw.execute("INSERT INTO schema_meta (key, value) VALUES ('schema_version', '0')")
    raw.commit()
    raw.close()
    upgraded = connect(legacy)
    try:
        assert schema_version(upgraded) == "1"
    finally:
        upgraded.close()
