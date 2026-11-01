#!/usr/bin/env python3
"""Finish and verify a Godot web export.

The script does not upload the build and does not start a browser.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

MD_CONFIG = """\
// Public server for this static host.
// Set window.MD_SERVER to an https:// API origin before publishing.
// Leave it empty to require ?server= on the page instead.
// Do not put a session token or a loopback address in this file.
window.MD_SERVER = window.MD_SERVER || "";
"""

SCRIPT_TAG = '<script src="md-config.js"></script>'
REQUIRED_PCK_MARKERS = (
    b"export_shared",
    b"rules_constants.json",
    b"schema.json",
)
ARTIFACTS = (
    "index.html",
    "index.js",
    "index.wasm",
    "index.pck",
    "md-config.js",
    "_headers",
    "BUILD.txt",
)


def _repo_root() -> Path:
    return Path(__file__).resolve().parents[1]


def finish(directory: Path, godot_version: str) -> None:
    index = directory / "index.html"
    if not index.is_file():
        raise SystemExit(f"missing {index}")
    html = index.read_text(encoding="utf-8")
    if SCRIPT_TAG not in html:
        if "<head>" not in html:
            raise SystemExit("index.html has no <head> element for md-config.js")
        html = html.replace("<head>", "<head>\n\t\t" + SCRIPT_TAG, 1)
        index.write_text(html, encoding="utf-8")
    (directory / "md-config.js").write_text(MD_CONFIG, encoding="utf-8")
    headers = _repo_root() / "infra" / "deploy" / "cloudflare" / "_headers"
    if not headers.is_file():
        raise SystemExit(f"missing {headers}")
    (directory / "_headers").write_text(headers.read_text(encoding="utf-8"), encoding="utf-8")
    lines = [
        f"godot={godot_version.strip()}",
        "renderer=gl_compatibility",
        "threads=false",
        "entry=index.html",
    ]
    for name in ARTIFACTS:
        if name == "BUILD.txt":
            continue
        path = directory / name
        lines.append(f"{name} {path.stat().st_size if path.is_file() else 0}")
    (directory / "BUILD.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"WEB_FINISH_OK {directory}")


def verify(directory: Path) -> list[str]:
    errors: list[str] = []
    for name in ARTIFACTS:
        path = directory / name
        if not path.is_file() or path.stat().st_size <= 0:
            errors.append(f"missing or empty {name}")
    if errors:
        return errors
    html = (directory / "index.html").read_text(encoding="utf-8", errors="replace")
    for needle in ("index.js", "index.wasm", "index.pck", SCRIPT_TAG, "GODOT_THREADS_ENABLED = false"):
        if needle not in html:
            errors.append(f"index.html missing {needle}")
    if "127.0.0.1" in html or "session_token" in html:
        errors.append("index.html contains a development address or a session token")
    blob = (directory / "index.pck").read_bytes()
    for marker in REQUIRED_PCK_MARKERS:
        if marker not in blob:
            errors.append(f"pck missing {marker.decode()}")
    config = (directory / "md-config.js").read_text(encoding="utf-8")
    for forbidden in ("127.0.0.1", "localhost", "session_token"):
        if forbidden in config:
            errors.append(f"md-config.js contains {forbidden}")
    if "window.MD_SERVER" not in config:
        errors.append("md-config.js does not set window.MD_SERVER")
    headers = (directory / "_headers").read_text(encoding="utf-8")
    if "application/wasm" not in headers or "no-cache" not in headers:
        errors.append("_headers is missing wasm or cache rules")
    build = (directory / "BUILD.txt").read_text(encoding="utf-8")
    if not build.startswith("godot=4.7.2"):
        errors.append("BUILD.txt does not record Godot 4.7.2")
    if "threads=false" not in build:
        errors.append("BUILD.txt does not record a single-threaded build")
    scripts = Path(__file__).resolve().parent
    if str(scripts) not in sys.path:
        sys.path.insert(0, str(scripts))
    from serve_web import MIME

    if MIME.get(".wasm") != "application/wasm":
        errors.append("serve_web does not label wasm as application/wasm")
    if "javascript" not in MIME.get(".js", ""):
        errors.append("serve_web does not label js as javascript")
    if MIME.get(".pck") != "application/octet-stream":
        errors.append("serve_web does not label pck as application/octet-stream")
    return errors


def main() -> None:
    parser = argparse.ArgumentParser(description="Finish or verify a Market Dominion web export.")
    parser.add_argument("action", choices=("finish", "verify"))
    parser.add_argument("--directory", default="build/web")
    parser.add_argument("--godot-version", default="")
    args = parser.parse_args()
    directory = Path(args.directory)
    if args.action == "finish":
        if not args.godot_version.strip():
            raise SystemExit("finish requires --godot-version")
        finish(directory, args.godot_version)
        return
    problems = verify(directory)
    if problems:
        for problem in problems:
            print(problem, file=sys.stderr)
        raise SystemExit(1)
    print(f"WEB_VERIFY_OK {directory}")


if __name__ == "__main__":
    main()
