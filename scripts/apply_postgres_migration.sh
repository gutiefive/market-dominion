#!/usr/bin/env bash
# Apply the unused PostgreSQL DDL. The API process does not run this and does not open Postgres.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SQL="${ROOT}/infra/migrations/0001_rooms.sql"

if [[ -z "${DATABASE_URL:-}" ]]; then
  echo "DATABASE_URL is unset. This script only applies ${SQL}." >&2
  exit 1
fi
case "$DATABASE_URL" in
  postgres://*|postgresql://*) ;;
  *)
    echo "DATABASE_URL must start with postgres:// or postgresql://." >&2
    echo "The API does not use that URL. Point the API at SQLite instead." >&2
    exit 1
    ;;
esac
if ! command -v psql >/dev/null 2>&1; then
  echo "psql is not installed. The migration file is ${SQL}." >&2
  exit 1
fi
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f "$SQL"
echo "POSTGRES_MIGRATION_APPLIED schema_version 1"
