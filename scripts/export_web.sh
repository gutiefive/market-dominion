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
ZIP_NAME="Godot_v4.7.2-stable_linux.x86_64.zip"
ZIP_URL="https://github.com/godotengine/godot-builds/releases/download/${VERSION}/${ZIP_NAME}"
ZIP_SHA512="9aa00f7a605200940bce3027a567b782f49bd8e940dd06ae9e987bd65aee1b1467edd56ed84fcdcbdd44354bf613bdbb4e5d2913e925850368e150c59ed54c65"
BIN="${GODOT_BIN:-${ROOT}/.tools/godot/${BIN_NAME}}"
OUT="${ROOT}/build/web"

if [[ -z "${GODOT_BIN:-}" && ! -x "$BIN" ]]; then
  mkdir -p "$(dirname "$BIN")"
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  echo "Downloading ${ZIP_URL}"
  curl -fL --retry 3 --retry-delay 2 -o "${tmp}/${ZIP_NAME}" "$ZIP_URL"
  echo "${ZIP_SHA512}  ${tmp}/${ZIP_NAME}" | sha512sum -c -
  unzip -q -o "${tmp}/${ZIP_NAME}" -d "$tmp"
  install -m 0755 "${tmp}/${BIN_NAME}" "$BIN"
  rm -rf "$tmp"
  trap - EXIT
fi

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

for required in \
  shared/protocol/schema.json \
  shared/fixtures/rules_constants.json \
  shared/fixtures/commands/place_tile.json
do
  if [[ ! -f "${ROOT}/${required}" ]]; then
    echo "Required shared asset is missing: ${required}" >&2
    exit 1
  fi
done

EXPORT_SHARED="${ROOT}/client/export_shared"
rm -rf "$EXPORT_SHARED"
mkdir -p "$EXPORT_SHARED"
cp -a "${ROOT}/shared/protocol" "${ROOT}/shared/fixtures" "$EXPORT_SHARED/"

mkdir -p "$OUT"
GODOT_VERSION="$("$BIN" --version)"
echo "Godot: ${GODOT_VERSION}"
case "${GODOT_VERSION}" in
  4.7.2*) ;;
  *)
    echo "Expected Godot 4.7.2. Got: ${GODOT_VERSION}" >&2
    exit 1
    ;;
esac
"$BIN" --headless --path "${ROOT}/client" --export-release "Web" "${OUT}/index.html"

if [[ ! -f "${OUT}/index.html" || ! -f "${OUT}/index.js" || ! -f "${OUT}/index.wasm" || ! -f "${OUT}/index.pck" ]]; then
  echo "Export is missing index.html, index.js, index.wasm, or index.pck in ${OUT}." >&2
  exit 1
fi
python3 "${ROOT}/scripts/web_build.py" finish --directory "$OUT" --godot-version "${GODOT_VERSION}"
python3 "${ROOT}/scripts/web_build.py" verify --directory "$OUT"
echo "WEB_EXPORT_OK ${OUT}"
