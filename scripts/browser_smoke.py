#!/usr/bin/env python3
"""Load the web export in headless Chrome when that browser exists.

Exit 0 prints BROWSER_SMOKE_OK. Chrome parsed the page, the canvas node
exists, Godot's Engine object was created, and the missing-feature notice
stayed empty. That is a load check. It is not a match, not touch input, and
not a phone.

Exit 2 prints BROWSER_SMOKE_UNVERIFIED when Chrome or the websockets library
is missing, or Chrome quits before the debugger answers. Exit 1 is a page
that loaded and then failed the checks.
"""

from __future__ import annotations

import argparse
import errno
import os
import signal
import asyncio
import json
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EXPR = r"""
(() => {
  const notice = document.getElementById('status-notice');
  const canvas = document.getElementById('canvas');
  return JSON.stringify({
    canvas: !!canvas,
    notice: notice ? (notice.textContent || '') : '',
    engine: typeof Engine !== 'undefined'
  });
})()
"""


def _chrome() -> str | None:
    for candidate in (
        "/opt/google/chrome/chrome",
        shutil.which("google-chrome-stable") or "",
        shutil.which("google-chrome") or "",
        shutil.which("chromium") or "",
        shutil.which("chromium-browser") or "",
    ):
        if candidate and Path(candidate).is_file():
            return candidate
    return None


def _debugger_up(port: int) -> bool:
    for _ in range(40):
        try:
            with urllib.request.urlopen(f"http://127.0.0.1:{port}/json/version", timeout=0.5) as response:
                if response.status == 200:
                    return True
        except (OSError, TimeoutError):
            time.sleep(0.25)
    return False


def _open_page(port: int, url: str) -> dict | None:
    target = urllib.parse.quote(url, safe="")
    for method in ("PUT", "GET"):
        request = urllib.request.Request(f"http://127.0.0.1:{port}/json/new?{target}", method=method)
        try:
            with urllib.request.urlopen(request, timeout=2) as response:
                payload = json.load(response)
        except (OSError, json.JSONDecodeError, TimeoutError):
            continue
        if isinstance(payload, dict) and payload.get("webSocketDebuggerUrl"):
            return payload
    return None


async def _inspect(ws_url: str, page_url: str) -> dict:
    import websockets

    async with websockets.connect(ws_url, max_size=2_000_000) as socket:
        counter = 0

        async def send(method: str, params: dict | None = None) -> int:
            nonlocal counter
            counter += 1
            await socket.send(json.dumps({"id": counter, "method": method, "params": params or {}}))
            return counter

        await send("Page.enable")
        await send("Runtime.enable")
        await send("Page.navigate", {"url": page_url})
        latest: dict = {}
        deadline = time.monotonic() + 20
        next_eval = time.monotonic() + 1
        eval_ids: set[int] = set()
        while time.monotonic() < deadline:
            if time.monotonic() >= next_eval:
                eval_ids.add(await send("Runtime.evaluate", {"expression": EXPR, "returnByValue": True}))
                next_eval = time.monotonic() + 1
            try:
                raw = await asyncio.wait_for(socket.recv(), timeout=1)
            except TimeoutError:
                continue
            message = json.loads(raw)
            if message.get("id") in eval_ids:
                value = message.get("result", {}).get("result", {}).get("value")
                if isinstance(value, str):
                    latest = json.loads(value)
                    notice = str(latest.get("notice", "")).lower()
                    if "features required to run godot" in notice:
                        return latest
                    if latest.get("canvas") and latest.get("engine") and not notice.strip():
                        return latest
        return latest


def main() -> None:
    parser = argparse.ArgumentParser(description="Headless Chrome load of build/web.")
    parser.add_argument("--port", type=int, default=8098)
    parser.add_argument("--debug-port", type=int, default=9333)
    parser.add_argument("--directory", default=str(ROOT / "build" / "web"))
    args = parser.parse_args()
    directory = Path(args.directory)
    if not (directory / "index.html").is_file():
        print("BROWSER_SMOKE_UNVERIFIED missing index.html", file=sys.stderr)
        raise SystemExit(2)
    browser = _chrome()
    if browser is None:
        print("BROWSER_SMOKE_UNVERIFIED no Chrome or Chromium binary")
        raise SystemExit(2)
    try:
        import websockets  # noqa: F401
    except ImportError:
        print("BROWSER_SMOKE_UNVERIFIED python package websockets is not installed")
        raise SystemExit(2)
    server = subprocess.Popen(
        [
            sys.executable,
            str(ROOT / "scripts" / "serve_web.py"),
            "--directory",
            str(directory),
            "--host",
            "127.0.0.1",
            "--port",
            str(args.port),
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    profile = tempfile.TemporaryDirectory(prefix="md-chrome-")
    chrome = None
    try:
        ready = False
        for _ in range(25):
            probe = subprocess.run(
                ["curl", "-sf", "-o", "/dev/null", f"http://127.0.0.1:{args.port}/index.html"],
                check=False,
            )
            if probe.returncode == 0:
                ready = True
                break
            time.sleep(0.2)
        if not ready:
            print("BROWSER_SMOKE_UNVERIFIED static server did not answer")
            raise SystemExit(2)
        chrome = subprocess.Popen(
            [
                browser,
                "--headless=new",
                "--no-sandbox",
                "--disable-dev-shm-usage",
                "--enable-unsafe-swiftshader",
                f"--remote-debugging-port={args.debug_port}",
                f"--user-data-dir={profile.name}",
                "about:blank",
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=os.name == "posix",
        )
        if not _debugger_up(args.debug_port):
            print("BROWSER_SMOKE_UNVERIFIED chrome debugger did not answer")
            raise SystemExit(2)
        page = f"http://127.0.0.1:{args.port}/index.html"
        tab = _open_page(args.debug_port, page)
        if tab is None:
            print("BROWSER_SMOKE_UNVERIFIED chrome did not open the game page")
            raise SystemExit(2)
        ws_url = str(tab.get("webSocketDebuggerUrl", ""))
        if not ws_url:
            print("BROWSER_SMOKE_UNVERIFIED chrome tab has no debugger socket")
            raise SystemExit(2)
        facts = asyncio.run(_inspect(ws_url, page))
        notice = str(facts.get("notice", "")).lower()
        if "features required to run godot" in notice:
            print("BROWSER_SMOKE_FAIL godot reported missing features", file=sys.stderr)
            raise SystemExit(1)
        if not facts.get("canvas") or not facts.get("engine"):
            print(f"BROWSER_SMOKE_FAIL page did not start the engine: {facts}", file=sys.stderr)
            raise SystemExit(1)
        print(f"BROWSER_SMOKE_OK {browser} {page}")
        print("Checked the canvas node and that Godot Engine was created.")
        print("Did not play a match, did not send touch input, and did not use a phone.")
    finally:
        if chrome is not None:
            # Chromium's renderer/GPU children can outlive the launcher and
            # keep writing its profile. Signal only the group this run created.
            if os.name == "posix":
                try:
                    os.killpg(chrome.pid, signal.SIGTERM)
                except ProcessLookupError:
                    pass
            elif chrome.poll() is None:
                chrome.terminate()
            try:
                chrome.wait(timeout=3)
            except subprocess.TimeoutExpired:
                chrome.kill()
                chrome.wait(timeout=3)
            if os.name == "posix":
                try:
                    os.killpg(chrome.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
        server.terminate()
        try:
            server.wait(timeout=3)
        except subprocess.TimeoutExpired:
            server.kill()
            server.wait(timeout=3)
        for attempt in range(6):
            try:
                profile.cleanup()
                break
            except OSError as exc:
                if exc.errno not in (errno.ENOTEMPTY, errno.EBUSY) or attempt == 5:
                    raise
                time.sleep(0.1 * (attempt + 1))


if __name__ == "__main__":
    main()
