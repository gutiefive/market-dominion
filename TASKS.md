# Milestones

M9 is a browser-beta slice at client `0.20.0`. A box is checked only where a command was run and the result is recorded in [CHANGELOG.md](CHANGELOG.md). The public HTTPS gate is blocked. This is not a completed launch. Detail is in [docs/milestones/M9_PUBLIC_BETA.md](docs/milestones/M9_PUBLIC_BETA.md).

## M0 Foundation

- [x] Repository layout: `client/`, `server/`, `shared/`, `tests/`, `infra/`, docs
- [x] Godot **4.7.2.stable.official.ed1daf0bf** pinned in the README and asserted by `client/tests/m0_check.gd`
- [x] GDScript project, Compatibility renderer, foundation screen (not a board)
- [x] FastAPI health, readiness, schema, and command validation that does not apply moves
- [x] Shared JSON Schema and fixtures, including golden prices
- [x] SQLite schema_version 0 stub
- [x] `./scripts/dev.sh` local start and `./scripts/test.sh`
- [x] GitHub Actions workflow for pytest and the Godot headless check
- [x] Pure kernels with tests: catalog, prices, BYTE, sentiment clamp, tile conservation, lobby invariants, winner order
- [ ] Docker image built during M0 (built later; see M7)
- [ ] Browser export during M0 (produced later; see M7)

## M1 Offline board

Local pass-and-play only. The HTTP API does not apply these moves.

- [x] Interactive 9×9 labeled grid in `client/` (`docs/m1-opening.png`)
- [x] Seeded bag shuffle and a deal of five unique tiles per seat (`golden_deals.json`, `M1_CLIENT_OK`)
- [x] Local pass-and-play turn ownership, with the hand covered between seats
- [x] Legal-cell highlight for the active hand
- [x] Conservation test that walks a scripted deal. A full-bag play, including mergers, is the M3 invariant test.
- [x] Screenshot of a real placement (`docs/m1-placed.png`, seed 7710, Rowan places C1)

## M2 Economy

Local pass-and-play only. The HTTP API does not apply these moves.

- [x] Founding when two orthogonal unincorporated squares connect (`docs/m2-economy.png`, `M2_CLIENT_OK`)
- [x] Free founder share and the 20-share identity after the grant
- [x] Growth that absorbs a connected unincorporated cluster and reprices
- [x] Two market actions that move cash and inventory at the posted price
- [x] Reject a third action, an inactive name, a short sale, and a purchase that would go negative

## M3 Mergers

Local pass-and-play only. The HTTP API does not apply these moves.

- [x] Survivor from pre-placement sizes, with a tie modal (`docs/m3-tie.png`, `M3_CLIENT_OK`)
- [x] Majority and minority pools, including sole holder and ties
- [x] Remainder dollars by ascending player id
- [x] Automatic liquidation of every losing share
- [x] Multi-company merger with one reprice (`docs/m3-merger.png`)

## M4 Events and ending

Local pass-and-play only. The HTTP API does not apply these moves.

- [x] Seeded event deck, one event per completed round, reshuffle (`golden_events.json`, `M4_CLIENT_OK`)
- [x] End triggers at size 22, 65 occupied, or no tiles left
- [x] Final-round turns for players who have not acted
- [x] Ledger and deterministic tie break on a finished match (`docs/m4-score.png`)
- [x] Replay: same seed and commands, same result (`docs/m4-event.png`)

## M5 Online rooms

`POST /v1/protocol/commands/validate` still returns `applied: false`. Room commands on `/v1/rooms/commands` and `/v1/rooms/ws` are the authoritative match.

- [x] Private 2–4 player rooms by invite code, with a guest nickname, ready, and a host start
- [x] The server owns the seed, tile order, event deck, RNG, cash, and holdings
- [x] Private hands: the session sees its tiles; other seats see `hand_count` (`docs/m5-room.png`)
- [x] `expected_state_version`, `client_action_id` replay, and typed errors on rejected commands
- [x] Godot WebSocket client. Reconnect uses the same session token and a snapshot
- [x] Tests for out-of-turn, stale version, duplicate action id, a foreign room, hidden hands, restart, and two sockets on one room

## M6 Production UI

Desktop Godot windows only. No browser and no physical tablet were tested.

- [x] Board center-left, hand below, watchlist on the right, cash and net worth on the top bar, activity feed, action bar (`docs/m6-table.png`)
- [x] Legal cells outlined, company cells labeled with a symbol and letters, hover and focus preview
- [x] Active-player badge, turn checklist, founding modal, survivor modal, market confirmation, event overlay
- [x] Online lobby: invite code, ready list, host start disabled until 2–4 players are ready (`docs/m6-lobby.png`)
- [x] Rules overlay: turn, glossary, price changes, merger payouts (`docs/m6-rules.png`)
- [x] Keyboard path, focus rings, three text sizes, reduced motion, error screens for a rejected action, a dead socket, and a server error
- [x] Narrow viewport still stacks the watchlist under the board (`docs/m6-narrow.png`, 420×800). That is a window-size check, not a device test.

## M7 Ship

Local packaging only. Nothing here is a public HTTPS deploy.

- [x] Web preset, `scripts/export_web.sh`, and the pinned 4.7.2 template archive. `build/web/` was produced and is gitignored
- [x] `scripts/serve_web.py` MIME types and `scripts/smoke_web.sh` on `http://127.0.0.1:8097/index.html` (loopback HTTP, no browser)
- [x] Shared JSON copied into the web pack at `res://export_shared/`
- [x] `?server=http(s)://...` on the web page (`M7_CLIENT_OK`)
- [x] Image `market-dominion-api:local` (`0e9f554b751a`) built from `infra/Dockerfile`, probed on `127.0.0.1:8751` (`/health`, `/ready`, create room, uid 10001, SQLite file), then removed
- [x] `postgres://` `DATABASE_URL` aborts startup. `infra/migrations/0001_rooms.sql` exists and was not applied (`psql` is missing)
- [x] JSON logs, `MD_CORS_ORIGINS`, `MD_REPO_ROOT`, and `.env.example`. No secret file was committed
- [ ] `docker compose` up (the compose plugin is not installed here)
- [ ] Web export loaded over HTTPS
- [ ] Smoke on current desktop Chrome, Firefox, and Safari
- [ ] Section 10: 2–4 people, one invite URL, a full match, a reconnect, one winner

## Local computers

Not a spec milestone. The specification left bots until after launch. This is local only.

- [x] Setup: one human plus one, two, or three computers (`docs/bots-setup.png`)
- [x] Computers take the turn on this device. The human hand stays visible on the human turn. Computer hands are counts (`docs/bots-table.png`)
- [x] Same seed, same computer decisions, and a finished match for three seats and for four (`M8_CLIENT_OK`)
- [x] Computers buy and sell shares and BYTE when the dollar score is positive, still at most two actions (`M8_CLIENT_OK`)
- [x] Placement searches five tiles of the computer's hand, with a 500-evaluation cap, and one ply of opponent frontier threats (`M8_CLIENT_OK`)
- [x] Dollar scores buy BYTE under $500, sell BYTE over $500, buy a fourth share only to tie or take the lead, and sell one rich share when already behind (`M8_CLIENT_OK`)
- [x] Local lobby picks Easy, Normal, or Hard. Normal is the five-tile policy. Easy looks one tile ahead. Hard buys a size 15–18 company to tie or take the lead (`M8_CLIENT_OK`, `docs/bots-setup.png`)
- [ ] Computer seats in an online room

## M9 Public browser beta

Client `0.20.0`. Protocol stays `0.1.0`. Local M9 acceptance is verified; public release remains blocked. See [release report](docs/milestones/M9_RELEASE_CANDIDATE.md).

- [x] `MD_ENV` profiles, production URL checks, and `GET /health` `environment` (`pytest`, 87 passed)
- [x] Server deadline sweep without a second command, no duplicate sweep, restart keeps the advanced turn (`test_deadline_advances_without_another_command_and_does_not_repeat`)
- [x] Public invite lookup without a session token (`GET /v1/rooms/invites/{code}` on the live API and in pytest)
- [x] Two server sessions play to `game_ended` without putting `your_hand` or a session token on public events (`test_two_players_play_to_a_winner_and_public_events_hide_hands`)
- [x] Web export checks Godot 4.7.2, writes `md-config.js` with no loopback URL, and verifies html, js, wasm, pck, and `_headers` (`WEB_EXPORT_OK`, `WEB_VERIFY_OK`)
- [x] Loopback MIME smoke (`WEB_SMOKE_OK http://127.0.0.1:8097/index.html`)
- [x] Headless Chrome created the canvas and the Godot `Engine` object (`BROWSER_SMOKE_OK`). Not a match
- [x] Invitation link builder drops `session_token` (`M9_CLIENT_OK`)
- [ ] Public HTTPS URL (blocked: no hosting account was used)
- [x] Two independent Chromium contexts join and play through 138 UI commands to identical standings
- [x] Browser refresh and forced socket disconnect/reconnect, followed by successful commands
- [ ] Firefox, Safari, iPad, iPhone, Android
- [ ] Phone layout on a phone. A width under 720px in code is not that test
- [ ] GitHub Actions web job executed
- [x] Container image rebuilt; readiness and room creation passed with `MD_ENV=container`
- [x] Tablet/phone desktop viewport interaction: placement and share buys/sells at 768×1024 and 390×844

## M10 First-time player experience

In Progress. See [M10 scope and acceptance](docs/milestones/M10_PLAYER_EXPERIENCE.md). Client remains `0.20.0` until the milestone deliverable is verified.

- [x] Main menu routes to guided Classic, computers, pass-and-play and existing online rooms
- [x] Guided seeded Classic match with phase-specific explanations and a non-mutating tile-selection helper
- [x] Headless production-UI regression reaches guided standings with invariant checks
- [ ] First-time-human tutorial usability acceptance
- [x] Recorded local/observed online quote history and reconciled local post-match analysis
- [x] Local-only privacy/measurement decision and multi-seed deterministic simulation harness
- [x] Bounded histories, reference action budgets and accessible history/analysis controls
- [ ] Human accessibility review and physical-device load/frame/input budgets

## Known limits

- `POST /v1/protocol/commands/validate` never mutates a match. Authoritative play goes through the room API.
- The local pass-and-play table still deals and scores on the device. It is a separate copy of the rules.
- A disconnected seat is autopassed by the server deadline loop after the grace window. The fallback is still the lowest sorted tile, the first legal choice, or a market pass (assumption A21). Another player's command is not required.
- Room rate limits live in process memory. Restarting the API clears them. SQLite keeps the rooms.
- GDScript rejection for prices is −1 or an empty list; the offline table returns `{ok: false, error}`. Python raises (assumption A13).
- Local headless Chromium multiplayer and desktop tablet/phone viewports passed M9 acceptance. Firefox, Safari, physical devices/touch, public HTTPS, and inaccessible CI runner results remain unverified. The API image passed readiness and room creation; `docker compose` was not started. PostgreSQL is a SQL file, not a driver (assumption A15).
- A 420×800 window stacks the watchlist under the board. That does not establish mobile support.
- Local computers do not join online rooms. The lobby difficulty is Easy, Normal, or Hard, and it starts on Normal. Easy looks one tile ahead and mostly passes the market. Normal and Hard look at five tiles. Each later tile keeps three quarters of the previous one. The search stops at 500 evaluations. A later tile is dropped when its immediate value plus $20,000 still cannot beat the best continuation. That ceiling rarely binds. At most 24 frontier cells are scored, and half of any increase in the opponent's reply is subtracted. BYTE at exactly $500 is left alone. Hard will buy a company of size 15 through 18 to tie or take the lead. Size 19 or more is still refused, including a contest. Sentiment +2 is still not bought. A tied holding is not sold unless cash is under $500. The heuristic can still misread a position.
