#!/usr/bin/env bash
# Start the Market Dominion API on 127.0.0.1:8741 (override with MD_PORT).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ ! -d .venv ]]; then
  python3 -m venv .venv
fi
.venv/bin/python -m pip install -e ".[dev]"

PORT="${MD_PORT:-8741}"
exec .venv/bin/uvicorn app.main:app --host 127.0.0.1 --port "$PORT"
