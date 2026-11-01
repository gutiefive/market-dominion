# Milestones

M7 packages a local web export and a container. The playable game is still the M6 desktop table plus the M5 rooms. A box is checked only where a command was run and the result is recorded in [CHANGELOG.md](CHANGELOG.md). This is not a public release.

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

## Known limits

- `POST /v1/protocol/commands/validate` never mutates a match. Authoritative play goes through the room API.
- The local pass-and-play table still deals and scores on the device. It is a separate copy of the rules.
- A disconnected seat is autopassed on the next command after the grace window, not by a background timer (assumption A21).
- Room rate limits live in process memory. Restarting the API clears them. SQLite keeps the rooms.
- GDScript rejection for prices is −1 or an empty list; the offline table returns `{ok: false, error}`. Python raises (assumption A13).
- The web export and the API image were exercised on loopback (assumption A15). `docker compose` was not started. No browser, HTTPS page, or physical phone/tablet was tested. PostgreSQL is a SQL file, not a driver.
- A 420×800 window stacks the watchlist under the board. That does not establish mobile support.
