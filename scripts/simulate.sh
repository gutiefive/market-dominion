#!/usr/bin/env bash
# Reproducible M10 Classic simulation. Reports are synthetic and stay in ignored build/.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
BIN="${GODOT_BIN:-$ROOT/.tools/godot/Godot_v4.7.2-stable_linux.x86_64}"
if [[ ! -x "$BIN" ]]; then
  echo 'Run ./scripts/check_client.sh to install and verify Godot first.' >&2
  exit 1
fi
if [[ -z "${GODOT_BIN:-}" ]]; then
  echo "ac9f3af3d8b62237694bc03e7422b8f7b1a39095cf4eeaa8361b7465f13bc9dbaad47f60ac0ac217c9f0b2b3712be207039cd83953f4c72087214bd0357cabbc  $BIN" | sha512sum -c -
fi
mkdir -p build/reports
sim_log="$(mktemp)"
trap 'rm -f "$sim_log"' EXIT
set +e
"$BIN" --headless --path client --script res://tests/m10_simulate.gd -- --output="$ROOT/build/reports/m10-simulation.json" "$@" 2>&1 | tee "$sim_log"
sim_status=("${PIPESTATUS[@]}")
set -e
if [[ "${sim_status[0]}" -ne 0 ]]; then exit "${sim_status[0]}"; fi
if [[ "${sim_status[1]}" -ne 0 ]]; then exit "${sim_status[1]}"; fi
if grep -Eq 'SCRIPT ERROR:|^ERROR:' "$sim_log" || ! grep -q '^M10_SIM_OK ' "$sim_log"; then
  exit 1
fi
