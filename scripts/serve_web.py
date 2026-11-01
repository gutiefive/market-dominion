#!/usr/bin/env python3
"""Serve a Godot web export with MIME types browsers accept.

Python's stock http.server maps ``.wasm`` to ``application/octet-stream``.
Chromium can refuse to compile that. This server sends ``application/wasm``.

Filenames are not content-hashed, so nothing is cached as immutable.
``index.html`` and ``.js`` are ``no-cache``. Other assets revalidate.
"""

from __future__ import annotations

import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

MIME = {
    ".html": "text/html; charset=utf-8",
    ".js": "text/javascript; charset=utf-8",
    ".mjs": "text/javascript; charset=utf-8",
    ".wasm": "application/wasm",
    ".pck": "application/octet-stream",
    ".png": "image/png",
    ".svg": "image/svg+xml",
    ".ico": "image/x-icon",
    ".json": "application/json",
    ".css": "text/css; charset=utf-8",
    ".webmanifest": "application/manifest+json",
    ".map": "application/json",
}


class ExportHandler(SimpleHTTPRequestHandler):
    def guess_type(self, path: str) -> str:
        return MIME.get(Path(path).suffix.lower(), "application/octet-stream")

    def end_headers(self) -> None:
        path = self.path.split("?", 1)[0]
        suffix = Path(path).suffix.lower()
        if suffix in {".html", ".js", ".mjs"} or path.endswith("/"):
            self.send_header("Cache-Control", "no-cache")
        else:
            self.send_header("Cache-Control", "public, max-age=3600, must-revalidate")
        self.send_header("X-Content-Type-Options", "nosniff")
        super().end_headers()


def main() -> None:
    parser = argparse.ArgumentParser(description="Serve a Market Dominion web export.")
    parser.add_argument("--directory", default="build/web")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8097)
    args = parser.parse_args()
    directory = Path(args.directory).resolve()
    if not (directory / "index.html").is_file():
        raise SystemExit(f"{directory}/index.html is missing. Run ./scripts/export_web.sh first.")
    handler = partial(ExportHandler, directory=str(directory))
    server = ThreadingHTTPServer((args.host, args.port), handler)
    print(f"Serving {directory} at http://{args.host}:{args.port}/", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
