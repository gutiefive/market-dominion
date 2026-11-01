# M9 — Public browser beta

## Goal and status

Client `0.20.0`, protocol `0.1.0`. The M9 release candidate passes local Chromium multiplayer acceptance. Public release remains blocked on real HTTPS/WSS deployment and external verification. M10 has not begun.

See the [release report](M9_RELEASE_CANDIDATE.md), [browser acceptance procedure](M9_BROWSER_ACCEPTANCE.md), and [deployment instructions](../../infra/deploy/README.md).

## Checklist

| Item | Status | Evidence |
| --- | --- | --- |
| M9.1 Production architecture | Implemented; public hosting blocked | One persistent FastAPI worker, SQLite, WSS-capable client and single-threaded Compatibility export |
| M9.2 Web export automation | Verified locally | Godot 4.7.2, `WEB_FINISH_OK`, `WEB_VERIFY_OK`, `WEB_EXPORT_OK`, MIME and canvas-load smoke |
| M9.3 Server configuration | Verified | 87 passing Python tests; container readiness and functional room creation |
| M9.4 Multiplayer flow | Verified locally in Chromium | Two isolated browser contexts, copied invitation, first join, ready/start, private hands, 138 UI commands through completion; identical canvas standings matched the final server ledger |
| M9.5 Session continuity | Verified locally in Chromium | B refreshed mid-match and continued; A recovered from forced socket loss/failed reconnect attempts and continued. Completed-session restoration also checked |
| M9.6 Turn timeouts | Verified | Existing deadline/restart regression tests remain passing |
| M9.7 Browser compatibility | Chromium verified; other browsers pending | Headless Chromium 154.0.8037.57 with software WebGL. Firefox/Safari unavailable; no physical-device claim |
| M9.8 Responsive layout | Desktop viewports verified | 768×1024 and 390×844; both players placed tiles and bought/sold shares. Physical tablet/phone/touch testing pending |
| M9.9 CI | Implemented; runner verification pending | GitHub Actions API returned Forbidden. Local export checks passed; no runner result is claimed |
| M9.10 Release acceptance | Local gate verified; public gate blocked | No authorized hosting, DNS/TLS access or real public URL |

## Acceptance

- [x] Web build generated and verified
- [x] Python tests, Godot M0–M9, MIME and browser-load checks
- [x] Two independent browser sessions create/join through an invitation and ready/start
- [x] Browser UI places tiles, trades shares, dismisses round events and resolves a merger choice
- [x] Both browsers reach completed phase and show identical final standings
- [x] Refresh and forced disconnect/reconnect preserve the seat and hand; subsequent UI commands succeed
- [x] Public state/events omit hands and session tokens; public shuffle seed is redacted
- [x] Tablet/phone desktop viewports support real hand and market interaction
- [x] Docker image build, readiness and functional room creation
- [ ] GitHub Actions web job result — access unavailable
- [ ] Firefox, Safari and physical-device/touch compatibility
- [ ] Real public HTTPS/WSS URL — hosting access unavailable

## Evidence

The full match ended at version 143 after 138 UI game commands: 22 placements by each player, one share buy and sell each, 42 event-dialog dismissals, and one merger-survivor choice. Both canvases displayed `1. Rowan — $13000`, `2. Player B — $9680`; the server's final ledger and ranking agreed. No synchronization or privacy assertion failed.

Sanitized results: [full match](evidence/m9-full-match.json), [responsive controls](evidence/m9-viewports.json), [final standings](evidence/m9-final-standings.json). Raw storage, traffic frames and database files are deliberately excluded. Test tools are described in the acceptance procedure.

## Remaining release blockers and limits

Public hosting must support persistent SQLite, one long-lived API worker, HTTPS/WSS and exact CORS origins. The hub, room lock, rate limits and deadline coordination are process-local; multiple workers are unsupported. PostgreSQL remains a migration file, not a supported API backend.

A local HTTP match is not public deployment evidence. Obtain authorized hosting/DNS/TLS access, deploy using the documented procedure, and repeat acceptance on the real URL. Obtain CI results and record additional browser/device outcomes before claiming broader compatibility. M9 public release is not complete.
