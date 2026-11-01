-- Market Dominion room store, schema version 1.
-- The API process does not execute this file and does not open PostgreSQL.
-- SQLite creates the same two tables in server/app/persistence/sqlite.py.
-- Apply this only when preparing a PostgreSQL database for a future driver.

CREATE TABLE IF NOT EXISTS schema_meta (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

INSERT INTO schema_meta (key, value)
VALUES ('schema_version', '1')
ON CONFLICT (key) DO NOTHING;

CREATE TABLE IF NOT EXISTS rooms (
    match_id TEXT PRIMARY KEY,
    invite_code TEXT NOT NULL UNIQUE,
    blob TEXT NOT NULL
);
