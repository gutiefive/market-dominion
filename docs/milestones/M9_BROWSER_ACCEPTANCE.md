# M9 browser acceptance

Use the release candidate's exported Godot client. Server tests and a canvas-load smoke do not pass the multiplayer gate. M10 stays paused until local acceptance is complete. Record actual browser versions, candidate commit/build, viewports, and outcomes; record physical devices separately.

## Local setup

From the repository root:

```bash
.venv/bin/python -m pytest -q
./scripts/check_client.sh
./scripts/export_web.sh
MD_CORS_ORIGINS=http://127.0.0.1:8097 MD_PORT=8742 ./scripts/dev.sh
# Second terminal:
.venv/bin/python scripts/serve_web.py --directory build/web --port 8097
```

Use a disposable `MD_DATABASE_PATH` for acceptance. Do not delete an existing room database. Open the page with `?server=http://127.0.0.1:8742`. The browser must use the exact origin in the API's CORS configuration.

## Automated canvas run

`scripts/multiplayer_browser.cjs` uses two isolated Chromium contexts, real mouse/keyboard input, screenshots/OCR, and in-memory HTTP/WebSocket observations. It sends no game commands through an API helper or engine test hook. Requirements: Node, Playwright, Chromium, `tesseract`, and Python Pillow. These are optional test tools, not application dependencies.

```bash
MD_BROWSER_EVIDENCE=/tmp/md-m9-browser node scripts/multiplayer_browser.cjs
```

Optional settings: `CHROMIUM_BIN`, `MD_BROWSER_WEB`, `MD_BROWSER_API`. `MD_MAX_ACTIONS` runs a partial diagnostic only; it does not pass full-match acceptance. Evidence includes a sanitized result JSON and canvas screenshots. Do not publish raw network traces, storage exports, session tokens, or private database files. `MD_VIEWPORT_ACCEPTANCE=1` runs a separate short tablet/phone interaction test (not full-match acceptance). The runner's grid coordinates are calibrated to the 1280×900 desktop layout; a layout change can require recalibration. A failed OCR/control lookup is an automation limitation and is not a passing game test. Use the manual checklist to finish unverified steps.

## Manual checklist

1. Open two independent browser profiles, A and B. A creates a room. Copy the invitation using the client control; confirm it includes the API location and invite, and excludes credentials. B opens that exact link, chooses a distinct nickname, and joins on the first attempt.
2. Ready A. Host Start must remain disabled until B also readies. Start once. Compare board, active player, prices, round and version. Verify each canvas shows its own hand. Both players must be able to select a hand tile or board cell.
3. Alternate UI turns through placement, founding/growth, share buys and sells, round events and any merger-choice dialogs. Confirm both clients converge after every move. Do not advance the game using server fixtures and report that as browser evidence.
4. Refresh B after several moves, including commands previously sent by B. Verify the same seat and hand return; make another legal command. Then take A offline, close its WebSocket, wait through at least one failed connection attempt, restore networking, and make another command. No lost seats, duplicate-action errors, stale dialogs or turn deadlocks are acceptable.
5. Finish the match through UI input. Both canvases must display identical final standings, names and net values. Compare their order with the server's `game_ended` ranking. Refresh a completed seat and verify standings remain visible.
6. Inspect transport privately: public events and state contain no session tokens or hands; personalized snapshots contain only the receiving player's hand. Invitation lookup and invitation URLs contain no session token. The shuffle seed is redacted to zero in public snapshots so private hands cannot be reconstructed from it. The server retains its real deterministic seed.
7. At 768×1024 and 390×844 desktop viewports, verify readable text, a stacked market section, reachable player information, hand controls, board and trade dialogs. Scroll and use board zoom when needed. Actually place a tile and trade at narrow widths. These results do not establish Safari, touch input, Android, iPhone or iPad compatibility.

## Public HTTPS gate

No local result passes public deployment. Use the deployment instructions in `infra/deploy/README.md`, then repeat invitation, refresh, offline recovery and a full match on the real HTTPS page with WSS to the API. Check HTTPS/WSS, exact CORS origins, persistent storage, WASM MIME and cache headers. Record the tested public URL. Hosting access and CI results that cannot be accessed stay explicitly pending.
