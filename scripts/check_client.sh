#!/usr/bin/env bash
# Download Godot 4.7.2 if needed, import the project, and run the headless client checks.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="4.7.2-stable"
ZIP_NAME="Godot_v4.7.2-stable_linux.x86_64.zip"
BIN_NAME="Godot_v4.7.2-stable_linux.x86_64"
ZIP_URL="https://github.com/godotengine/godot-builds/releases/download/${VERSION}/${ZIP_NAME}"
ZIP_SHA512="9aa00f7a605200940bce3027a567b782f49bd8e940dd06ae9e987bd65aee1b1467edd56ed84fcdcbdd44354bf613bdbb4e5d2913e925850368e150c59ed54c65"
BIN_SHA512="ac9f3af3d8b62237694bc03e7422b8f7b1a39095cf4eeaa8361b7465f13bc9dbaad47f60ac0ac217c9f0b2b3712be207039cd83953f4c72087214bd0357cabbc"

if [[ -n "${GODOT_BIN:-}" ]]; then
  BIN="$GODOT_BIN"
else
  BIN="$ROOT/.tools/godot/${BIN_NAME}"
  if [[ ! -x "$BIN" ]]; then
    mkdir -p "$(dirname "$BIN")"
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT
    curl -fL --retry 3 -o "$tmp/$ZIP_NAME" "$ZIP_URL"
    echo "${ZIP_SHA512}  $tmp/$ZIP_NAME" | sha512sum -c -
    unzip -q -o "$tmp/$ZIP_NAME" -d "$tmp"
    install -m 0755 "$tmp/$BIN_NAME" "$BIN"
    rm -rf "$tmp"
    trap - EXIT
  fi
  echo "${BIN_SHA512}  $BIN" | sha512sum -c -
fi

echo "Godot: $("$BIN" --version)"
"$BIN" --headless --path "$ROOT/client" --import
"$BIN" --headless --path "$ROOT/client" --check-only --script res://tests/m0_check.gd
"$BIN" --headless --path "$ROOT/client" --script res://tests/m0_check.gd
"$BIN" --headless --path "$ROOT/client" --check-only --script res://tests/m1_check.gd
"$BIN" --headless --path "$ROOT/client" --script res://tests/m1_check.gd
"$BIN" --headless --path "$ROOT/client" --check-only --script res://tests/m2_check.gd
"$BIN" --headless --path "$ROOT/client" --script res://tests/m2_check.gd
"$BIN" --headless --path "$ROOT/client" --check-only --script res://tests/m3_check.gd
"$BIN" --headless --path "$ROOT/client" --script res://tests/m3_check.gd
"$BIN" --headless --path "$ROOT/client" --check-only --script res://tests/m4_check.gd
"$BIN" --headless --path "$ROOT/client" --script res://tests/m4_check.gd
"$BIN" --headless --path "$ROOT/client" --check-only --script res://tests/m5_check.gd
"$BIN" --headless --path "$ROOT/client" --script res://tests/m5_check.gd
"$BIN" --headless --path "$ROOT/client" --check-only --script res://tests/m6_check.gd
"$BIN" --headless --path "$ROOT/client" --script res://tests/m6_check.gd
"$BIN" --headless --path "$ROOT/client" --check-only --script res://tests/m7_check.gd
"$BIN" --headless --path "$ROOT/client" --script res://tests/m7_check.gd
