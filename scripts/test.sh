#!/usr/bin/env bash
# Install dev dependencies, run pytest, then the Godot 4.7.2 headless check.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ ! -d .venv ]]; then
  python3 -m venv .venv
fi
.venv/bin/python -m pip install -e ".[dev]"
.venv/bin/python -m pytest -q
./scripts/check_client.sh
