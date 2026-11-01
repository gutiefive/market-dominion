# M9 release candidate — client 0.20.0

Development baseline: `231d2ab`, including the follow-up invitation/session commit `292c121`. Protocol remains `0.1.0`. No M10 work, financial mechanics, tutorials or visual redesign were added.

## Implemented corrections

- Independent browser loads and refreshes use fresh action-ID namespaces; room creation no longer depends on second-resolution timestamps. Idempotent replay of an existing command is unchanged.
- Failed initial WebSocket connections now report closure, retry with bounded backoff, and clear the error on a fresh snapshot. Old-socket cleanup cannot remove a refreshed subscription.
- Refresh restores the seat, private hand and last dismissed round event. Invitation links retain the server and invite without a session token.
- Public snapshots redact the deterministic shuffle seed to zero. Actual server deals, game RNG state, Classic rules and scoring remain unchanged.
- Healthy snapshots clear stale reconnect warnings, and completed matches show a settled status instead of a null active-player label. Online matches display final standings using the existing scoring/tie-break rules, including after snapshot restoration.
- Browser layouts use actual viewport dimensions. Hand/player controls wrap and the market stacks below the board at narrow widths. Choice dialogs fit the viewport.
- Containers normalize shared-asset read permissions before dropping privileges. Image and Compose healthchecks probe readiness rather than liveness alone. BuildKit can mount an optional pip trust bundle without disabling TLS verification.

## Local validation

- Python: 87 tests passed, including preserved deterministic deals/private hands and replacement-subscription cleanup.
- Godot 4.7.2: headless M0–M9 checks passed, including unique action IDs, holdings-aware standings and initially refused socket handshakes.
- Web export: `WEB_FINISH_OK`, `WEB_VERIFY_OK`, `WEB_EXPORT_OK`.
- MIME and Chromium load smoke: passed. This smoke alone does not verify a match.
- Independent tablet/phone viewport run: 10 UI game commands; both players placed tiles, bought and sold shares, and one company was founded. Desktop Chromium viewports were 768×1024 and 390×844. No physical-device or touch claim is made.
- Docker: repository Dockerfile built with the optional CA secret. `/health`, `/ready`, functional room creation and container readiness passed. API process UID was 10001. Docker Compose itself was not run.
- Two-browser full-match acceptance: passed, 138 UI commands to version 143. Each player placed 22 tiles, bought and sold shares, and continued after refresh or forced disconnect. The run dismissed 42 round-event dialogs and resolved one merger-survivor choice. No synchronization or privacy assertion failed.
- Both visible canvases showed Rowan $13,000 first and Player B $9,680 second, matching the final server ranking/ledger. The subsequent completion-status cleanup was verified with a focused Godot snapshot regression and two real browser restorations of that completed room; both visible standings matched again.

Browser tested: headless Chromium 154.0.8037.57 on Linux, using two isolated Playwright contexts with separate storage and the real exported Godot canvas. Mouse/keyboard inputs drive game commands. HTTP/WebSocket observations stay in memory; saved reports contain no raw tokens or private frames. Sanitized [full-match results](evidence/m9-full-match.json), [viewport results](evidence/m9-viewports.json), and [final standings](evidence/m9-final-standings.json) are committed. See [browser acceptance](M9_BROWSER_ACCEPTANCE.md) for commands and the manual fallback.

## Release gates and limitations

- GitHub Actions web-export result: pending. The GitHub API returned `Forbidden`; no runner success is claimed.
- Public HTTPS/WSS: blocked. No hosting credentials, DNS/TLS access or public URL were provided. A local HTTP match does not satisfy deployment acceptance.
- Firefox and Safari: unverified; those browsers were unavailable. iPad/iPhone/Android and physical tablet/phone input remain unverified.
- Production requires one long-lived API worker, persistent SQLite storage, real HTTPS/WSS URLs, exact CORS origins, correct WASM MIME and revalidating cache headers. The hub, room lock and deadline loop are process-local. See [deployment procedure](../../infra/deploy/README.md).
- Session tokens remain in same-origin browser storage; do not publish raw traces, storage snapshots or room database files. Configure hosting access logs to redact credential-bearing WebSocket query parameters.

M9 public release remains blocked until the external gates pass. M10 has not begun.
