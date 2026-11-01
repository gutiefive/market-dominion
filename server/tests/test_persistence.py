"""SQLite schema_version 0 stub."""

from __future__ import annotations

from app.persistence.sqlite import SCHEMA_VERSION, connect, schema_version


def test_new_database_is_version_zero_without_match_tables(tmp_path):
    path = tmp_path / "nested" / "market.db"
    first = connect(path)
    first.close()
    connection = connect(path)
    try:
        assert schema_version(connection) == SCHEMA_VERSION == "0"
        tables = {
            row[0]
            for row in connection.execute(
                "SELECT name FROM sqlite_master WHERE type = 'table'"
            )
        }
    finally:
        connection.close()
    assert tables == {"schema_meta"}
