#!/usr/bin/env bash
# Local smoke for a finished web export. Does not open a browser and does not use HTTPS.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WEB="${ROOT}/build/web"
PORT="${MD_WEB_PORT:-8097}"

if [[ ! -f "${WEB}/index.html" || ! -f "${WEB}/index.js" || ! -f "${WEB}/md-config.js" ]]; then
  echo "build/web is missing index.html, index.js, or md-config.js. Run ./scripts/export_web.sh first." >&2
  exit 1
fi

shopt -s nullglob
wasm=("${WEB}"/*.wasm)
pck=("${WEB}"/*.pck)
if [[ ${#wasm[@]} -eq 0 || ${#pck[@]} -eq 0 ]]; then
  echo "build/web is missing a .wasm or .pck file." >&2
  exit 1
fi

wasm_name="$(basename "${wasm[0]}")"
pck_name="$(basename "${pck[0]}")"
if ! grep -q "${wasm_name}" "${WEB}/index.html"; then
  echo "index.html does not reference ${wasm_name}." >&2
  exit 1
fi

python3 "${ROOT}/scripts/serve_web.py" --directory "$WEB" --host 127.0.0.1 --port "$PORT" >/tmp/market-web-smoke.log 2>&1 &
pid=$!
trap 'kill "$pid" >/dev/null 2>&1 || true' EXIT
for _ in 1 2 3 4 5 6 7 8 9 10; do
  if curl -sf -o /dev/null "http://127.0.0.1:${PORT}/index.html"; then
    break
  fi
  sleep 0.2
done

html_headers="$(curl -sS -D - -o /tmp/market-web-index.html "http://127.0.0.1:${PORT}/index.html")"
html_code="$(printf '%s' "$html_headers" | awk 'BEGIN{code=""} /^HTTP/{code=$2} END{print code}')"
if [[ "$html_code" != "200" ]]; then
  echo "index.html returned ${html_code}" >&2
  exit 1
fi
if ! printf '%s' "$html_headers" | awk 'BEGIN{IGNORECASE=1} tolower($1)=="cache-control:"{print}' | grep -q "no-cache"; then
  echo "index.html is missing Cache-Control: no-cache" >&2
  exit 1
fi

wasm_headers="$(curl -sS -D - -o /dev/null "http://127.0.0.1:${PORT}/${wasm_name}")"
if ! printf '%s' "$wasm_headers" | awk 'BEGIN{IGNORECASE=1} tolower($1)=="content-type:"{print}' | grep -q "application/wasm"; then
  echo "${wasm_name} was not served as application/wasm" >&2
  exit 1
fi
if ! printf '%s' "$wasm_headers" | awk 'BEGIN{IGNORECASE=1} tolower($1)=="cache-control:"{print}' | grep -q "must-revalidate"; then
  echo "${wasm_name} is missing must-revalidate" >&2
  exit 1
fi

pck_headers="$(curl -sS -D - -o /dev/null "http://127.0.0.1:${PORT}/${pck_name}")"
if ! printf '%s' "$pck_headers" | awk 'BEGIN{IGNORECASE=1} tolower($1)=="content-type:"{print}' | grep -q "application/octet-stream"; then
  echo "${pck_name} was not served as application/octet-stream" >&2
  exit 1
fi

js_headers="$(curl -sS -D - -o /dev/null "http://127.0.0.1:${PORT}/index.js")"
if ! printf '%s' "$js_headers" | awk 'BEGIN{IGNORECASE=1} tolower($1)=="content-type:"{print}' | grep -qi "javascript"; then
  echo "index.js was not served as javascript" >&2
  exit 1
fi
if ! printf '%s' "$js_headers" | awk 'BEGIN{IGNORECASE=1} tolower($1)=="cache-control:"{print}' | grep -q "no-cache"; then
  echo "index.js is missing Cache-Control: no-cache" >&2
  exit 1
fi

config_headers="$(curl -sS -D - -o /tmp/market-web-config.js "http://127.0.0.1:${PORT}/md-config.js")"
if ! printf '%s' "$config_headers" | awk 'BEGIN{IGNORECASE=1} /^HTTP/{code=$2} END{exit !(code==200)}'; then
  echo "md-config.js was not served" >&2
  exit 1
fi
if grep -q "127.0.0.1\|session_token" /tmp/market-web-config.js; then
  echo "md-config.js contains a loopback address or a session token" >&2
  exit 1
fi

echo "WEB_SMOKE_OK http://127.0.0.1:${PORT}/index.html"
