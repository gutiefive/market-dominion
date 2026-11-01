#!/usr/bin/env bash
# Release web export: Godot 4.7.2 Compatibility, single-threaded WASM.
# Writes build/web/ (gitignored). Does not upload anywhere.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="4.7.2-stable"
TEMPLATE_NAME="Godot_v4.7.2-stable_export_templates.tpz"
TEMPLATE_URL="https://github.com/godotengine/godot-builds/releases/download/${VERSION}/${TEMPLATE_NAME}"
# SHA-512 of the official 4.7.2-stable export templates archive (1,281,349,702 bytes).
TEMPLATE_SHA512="${GODOT_TEMPLATES_SHA512:-ca4d71c4d7b81dfc15d1a98baa07534aa95b03fdda78a0075b06672e1648d2e5f40980c9adc28d23e1b92e732ee7bf3461997aa804af74ec2fcd7a93ccb84079}"
TEMPLATE_DIR="${GODOT_EXPORT_TEMPLATES:-${HOME}/.local/share/godot/export_templates/4.7.2.stable}"
BIN_NAME="Godot_v4.7.2-stable_linux.x86_64"
BIN="${GODOT_BIN:-${ROOT}/.tools/godot/${BIN_NAME}}"
OUT="${ROOT}/build/web"

if [[ ! -x "$BIN" ]]; then
  echo "Godot binary is missing at ${BIN}." >&2
  echo "Run ./scripts/check_client.sh once, or set GODOT_BIN." >&2
  exit 1
fi

if [[ ! -f "${TEMPLATE_DIR}/web_nothreads_release.zip" ]]; then
  mkdir -p "$(dirname "$TEMPLATE_DIR")"
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  if [[ -n "${GODOT_TEMPLATES_TPZ:-}" ]]; then
    cp "$GODOT_TEMPLATES_TPZ" "${tmp}/${TEMPLATE_NAME}"
  else
    echo "Downloading ${TEMPLATE_URL}"
    curl -fL --retry 3 --retry-delay 2 -o "${tmp}/${TEMPLATE_NAME}" "$TEMPLATE_URL"
  fi
  echo "${TEMPLATE_SHA512}  ${tmp}/${TEMPLATE_NAME}" | sha512sum -c -
  unzip -q "${tmp}/${TEMPLATE_NAME}" -d "$tmp"
  if [[ ! -f "${tmp}/templates/web_nothreads_release.zip" ]]; then
    echo "Archive did not contain templates/web_nothreads_release.zip." >&2
    exit 1
  fi
  rm -rf "$TEMPLATE_DIR"
  mv "${tmp}/templates" "$TEMPLATE_DIR"
  rm -rf "$tmp"
  trap - EXIT
fi

EXPORT_SHARED="${ROOT}/client/export_shared"
rm -rf "$EXPORT_SHARED"
mkdir -p "$EXPORT_SHARED"
cp -a "${ROOT}/shared/protocol" "${ROOT}/shared/fixtures" "$EXPORT_SHARED/"

mkdir -p "$OUT"
echo "Godot: $("$BIN" --version)"
"$BIN" --headless --path "${ROOT}/client" --export-release "Web" "${OUT}/index.html"

if [[ ! -f "${OUT}/index.html" ]]; then
  echo "Export finished without ${OUT}/index.html." >&2
  exit 1
fi
shopt -s nullglob
wasm=("${OUT}"/*.wasm)
pck=("${OUT}"/*.pck)
if [[ ${#wasm[@]} -eq 0 || ${#pck[@]} -eq 0 ]]; then
  echo "Export is missing a .wasm or .pck file in ${OUT}." >&2
  exit 1
fi
echo "WEB_EXPORT_OK ${OUT}"
