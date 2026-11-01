# Changelog

## 0.12.0 — 2026-11-01

Longer local placement search. Protocol version stays `0.1.0`. Client `config/version` is `0.12.0`. Market, founding, and merger choices from 0.10.0 are unchanged. The one-ply opponent reply from 0.11.0 is unchanged. Pass-and-play and online rooms are unchanged.

### Changed

- Placement searches five tiles in the computer's own hand: the tile under consideration and up to four later tiles. That is the whole starting hand. Each later tile is worth half the one before it. A tile that would end a company for an opponent while the computer holds none of it is not expanded. A tile worth $0 that touches neither the occupied board nor another tile still in hand is not expanded. A later tile is skipped when its immediate value plus $20,000 still cannot beat the best continuation already scored. That ceiling does not cut ordinary lines. The search stops after 500 tile evaluations. A full five-tile hand with nothing cut is 325 evaluations, under the cap. Ties still use the lowest coordinate.
- After the first tile, the computer still scores one ply for each other seat on at most 24 empty neighbors of occupied cells, in catalog order, and subtracts a quarter of the best reply. The district for that neighbor is measured once and reused for every other seat. Hands of other players are not read.
- Share prices used by the search stay cached for the process. The match generator is still not advanced.

### Evidence

- `./scripts/check_client.sh` printed `M0_CLIENT_OK` through `M8_CLIENT_OK`. Seed 7710 with Rowan, Ada, and Bo still completed twice with the same trace, ranking, events, and log. Seed 4 with three computers still completed. The mixed game, Rowan on the safe autopass and Ada and Bo on the computer policy, still finished.
- M8 keeps the earlier chain. NOVA occupies C1–C4 and Ada holds two shares. The hand is B1, D3, E3, and E4. Five tiles still place E3. A second call on the same position returns E3.
- M8 also shows five tiles beating three. All five brands are already active, so a loose block cannot be founded. NOVA is A8–A9 and Ada holds two shares. ORBIT PAY is A1–A2 and Ada holds four. The other three brands sit off the path. The hand is B1, B8, C8, D8, and E8. Columns F–I, rows 5–9, are occupied and unincorporated, and they touch that path only at E8. Three tiles place B1, because growing ORBIT now outscores the NOVA path before the block is visible. Five tiles place B8: B8, C8, and D8 reach E8, and E8 takes the block into NOVA. A second call returns B8.
- The suite printed `M8_PLACEMENT_50_US 201672 nodes 64` during `./scripts/check_client.sh` (about 4 ms each over 50 repeats), under the 1.5 second guard. It also printed `M8_FIVE_PLIES shallow B1 nodes 85 deep B8 nodes 325 us 474085` (about 24 ms each over 20 repeats), under the 80 ms average guard.
- A separate four-seat timing pass, not part of the suite, measured 60 placement decisions in a seed-4 game at 28.6 ms on average and 95.6 ms at the worst (212 tile evaluations on average, 325 at the worst). Two repeats of that pass stayed in the same band.
- `docs/bots-table.png` is still seed 7710 after Bo's opening turn. Rowan sees B5, G4, I8, C1, and I9. The log still says Bo placed B6 and passed both market actions. That opening has no chain to extend.

### Not in this version

Computer seats in an online room, a search past five tiles or into hidden hands, and a neural model.

## 0.11.0 — 2026-11-01

Deeper local placement search. Protocol version stays `0.1.0`. Client `config/version` is `0.11.0`. Market, founding, and merger choices from 0.10.0 are unchanged. Pass-and-play and online rooms are unchanged.

### Changed

- Placement searches three tiles in the computer's own hand: the tile under consideration and two later tiles. Each later tile is worth half the one before it. A tile that would end a company for an opponent while the computer holds none of it is not expanded. A later tile is skipped when its immediate value plus $50,000 still cannot beat the best continuation already scored. The search stops after 120 tile evaluations. A full five-tile hand stays under that cap (85 evaluations). Ties still use the lowest coordinate.
- After that first tile, the computer scores one ply for each other seat on at most 24 empty neighbors of occupied cells, in catalog order. A quarter of the best such reply is subtracted. Hands of other players are not read.
- Share prices used by the search are cached for the process. The match generator is still not advanced.

### Evidence

- `./scripts/check_client.sh` printed `M0_CLIENT_OK` through `M8_CLIENT_OK`. Seed 7710 with Rowan, Ada, and Bo still completed twice with the same trace, ranking, events, and log. Seed 4 with three computers still completed. The mixed game, Rowan on the safe autopass and Ada and Bo on the computer policy, still finished.
- M8 checks that the longer line wins. NOVA occupies C1–C4 and Ada holds two shares. The hand is B1, D3, E3, and E4. One tile ahead places B1, because it grows NOVA now and the next tile is only a size-2 founding. Three tiles place E3: E4 can found, and D3 then merges that company into NOVA. A second call on the same position returns E3.
- Fifty repeats of that search printed `M8_PLACEMENT_50_US 104153` during `./scripts/check_client.sh` (about 2 ms each), under the 1.5 second guard. A separate four-seat timing pass, not part of the suite, measured 60 placement decisions at about 19 ms on average and 52 ms at the worst.
- `docs/bots-table.png` is still seed 7710 after Bo's opening turn. Rowan sees B5, G4, I8, C1, and I9. The log still says Bo placed B6 and passed both market actions. That opening has no chain to extend.

### Not in this version

Computer seats in an online room, a search past three tiles or into hidden hands, and a neural model.

## 0.10.0 — 2026-11-01

Stronger local computers. Protocol version stays `0.1.0`. Client `config/version` is `0.10.0`. Pass-and-play and online rooms are unchanged.

### Changed

- A computer still takes at most two market actions and still does not touch the match generator. It buys a share of a company at size 14 or smaller when sector sentiment is +1 or lower, it would still hold fewer than five shares, and cash after the purchase stays at or above $500. It sells one share of a size-16 company when it holds at least two and sentiment is at least +1. Cash under $500 sells a share it holds, or a BYTE it holds. It buys BYTE at $400 or below and sells BYTE at $800 or above when cash stays at or above $500. A score of zero passes. Equal scores keep fixture order, with a share trade considered before BYTE.
- Placement scores the fictional dollar result: the free founder share, our growth reprice minus every opponent's, or our merger bonus minus opponents' plus the survivor reprice. Half of the best other tile in hand, scored on that board, is added when it is positive. A tile that only pays an opponent loses to a neutral tile. Equal scores use the lowest coordinate.
- Founding picks the inactive brand with the highest share price for that cluster, then fixture order. A tied survivor picks the higher payout, then the larger own holding, then the earlier listed option.

### Evidence

- `./scripts/check_client.sh` printed `M0_CLIENT_OK` through `M8_CLIENT_OK`. Seed 7710 with Rowan, Ada, and Bo still completed twice with the same trace, ranking, events, and log. Seed 4 with three computers still completed. The mixed game, where Rowan uses the safe autopass and only Ada and Bo use the computer policy, still finished.
- M8 also checks the new choices directly. C1 beats an isolated A1 because C2 can found on the next tile. A merger Ada holds is taken; the same merger with Rowan's shares is skipped. With two shares of both tied companies, Ada keeps NOVA AI when ORBIT PAY is listed first and its liquidation bonus is larger. An empty market still passes. Two NOVA AI buys use both actions. Two ORBIT PAY shares outrank that cheaper first buy. A size-18 PULSE MEDIA holding at media sentiment +2 is sold for $1,000 and the second action buys NOVA AI, leaving $6,800. Cash of $400 sells the one NOVA AI share it can. BYTE at $300 is bought twice, leaving $5,400 and two coins. BYTE at $1,000 is sold. BYTE at $300 is refused when the purchase would leave less than $500. Cash of $400 with one BYTE at $500 sells that coin and leaves $900.
- `docs/bots-table.png` is seed 7710 after Bo's opening turn. Rowan sees B5, G4, I8, C1, and I9. Bo and Ada are listed as computer with five tiles each, not the coordinates. The log says Bo placed B6, passed both market actions, and drew. Nothing is on the market and BYTE is $500, so that opening does not trade.

### Not in this version

Computer seats in an online room, a search deeper than the next tile in hand, and a neural model.

## 0.9.0 — 2026-11-01

Local solo play. Protocol version stays `0.1.0`. Client `config/version` is `0.9.0`. Online rooms are unchanged.

### Added

- The local table can seat one human and one to three computers (Ada, Bo, Cy). Pass-and-play is still the unchecked setup.
- A computer plays its own turn on the device: place a tile, choose a founder or a tied survivor, then at most one share purchase and a passed second market action. Equal choices use the autopass order (lowest coordinate, fixture order, or the first listed survivor). The match generator is not used for those choices.
- Founding beats an isolated tile. Growing a company an opponent already holds heavily is skipped when another tile is safe. A higher sector sentiment wins a founding choice. The computer's own shares win a survivor tie.
- The human hand is shown on the human turn. Computer seats are labeled computer, and the activity list shows a tile count rather than the tiles. The device is not passed for a computer seat.

### Evidence

- `./scripts/check_client.sh` printed `M0_CLIENT_OK` through `M8_CLIENT_OK`. Seed 7710 with Rowan, Ada, and Bo completed twice with the same decision trace, ranking, events, and log. Seed 4 with four seats, three of them computers, also completed. A third game keeps Rowan on the safe autopass and lets only Ada and Bo use the computer policy. That game finished too.
- `docs/bots-setup.png` is the setup with You, Ada, and Bo. `docs/bots-table.png` is seed 7710 after Bo's opening turn: Rowan sees B5, G4, I8, C1, and I9. Bo's tiles are not listed. The log says Bo placed B6 and passed both market actions.

### Not in this version

Computer seats in an online room, BYTE trades by the computer, selling shares, and a stronger search than this heuristic.

## 0.8.0 — 2026-11-01

M7 packaging. Protocol version stays `0.1.0`. Client `config/version` is `0.8.0`. No public URL was deployed.

### Added

- `client/export_presets.cfg` exports a single-threaded Compatibility web build to `build/web/index.html`. `scripts/export_web.sh` checks the pinned 4.7.2 template archive, copies `shared/` into the pack, and runs the export. `scripts/serve_web.py` sends `application/wasm` for `.wasm`. `scripts/smoke_web.sh` checks `index.html`, the wasm type, and `must-revalidate`.
- A web page may pass `?server=https://...` or `?server=http://...`. Other schemes are ignored. The desktop client still defaults to `http://127.0.0.1:8741`.
- The image runs uvicorn as uid 10001 after the entrypoint makes `/data` writable. Compose keeps SQLite on a volume. A `postgres` profile and `infra/migrations/0001_rooms.sql` are present. The API rejects `postgres://` and `postgresql://` instead of opening them. `MD_CORS_ORIGINS` limits browser origins and the WebSocket `Origin`. A missing Origin is still allowed. `MD_LOG_LEVEL` selects JSON logs on the `market` logger. `.env.example` lists names only.
- `GET /ready` adds `database_backend` (`sqlite`) and `cors_origin_count`. `GET /health` is unchanged.

### Evidence

- `.venv/bin/python -m pytest -q` passed (76 tests). `./scripts/check_client.sh` prints `M0_CLIENT_OK` through `M7_CLIENT_OK`.
- `./scripts/export_web.sh` printed `WEB_EXPORT_OK`. `build/web/index.html` has `GODOT_THREADS_ENABLED = false`. Sizes: `index.js` 274K, `index.wasm` 38M, `index.pck` 182K. Those files are gitignored.
- `./scripts/smoke_web.sh` printed `WEB_SMOKE_OK http://127.0.0.1:8097/index.html`. Loopback HTTP. No browser.
- `docker build -f infra/Dockerfile -t market-dominion-api:local .` produced `0e9f554b751a`. On `http://127.0.0.1:8751`, `/health` was ok, `/ready` reported schema `1` and backend `sqlite`, and create-room returned 200. The process uid was 10001. The container was removed. `docker compose` is not installed, so the compose file was not started.
- A PostgreSQL `DATABASE_URL` made the container exit 1 and name `infra/migrations/0001_rooms.sql`. `psql` is absent, so that file was not applied.

### Not in this version

A public HTTPS page, Cloudflare Pages, a TLS terminator, WSS from a real browser, Chrome/Firefox/Safari smoke, a running compose stack, a PostgreSQL driver, and the section 10 match (two to four people, one invite URL, a full game, a reconnect, one winner).

## 0.7.0 — 2026-11-01

M6 production UI on the desktop Godot client. Protocol version stays `0.1.0`. Local pass-and-play and online rooms both use the new chrome. No browser export was run.

### Added

- The table is board center-left, tile hand and action bar underneath, market watchlist and a short activity feed on the right, and cash plus net worth on the top bar.
- Company cells show a symbol and two letters: diamond NA, circle OP, triangle VG, square PM, star EM. Legal cells use a teal outline and the word legal. Hover and keyboard focus preview the coordinate in text.
- Turn chrome: active-player badge, a three-step checklist, a founding modal, a survivor modal, a market confirmation, and a round-event overlay.
- The online lobby shows the invite code, a ready list with a check or a dot, and a host Start button that stays disabled until 2–4 players are ready. A dropped socket shows a connection-lost screen and reconnects with the same session token. Rejected commands name their error code.
- Rules overlay: how a turn works, a glossary, why prices change, and how merger pools are paid. R opens it. Esc closes overlays.
- Text size cycles through 100%, 115%, and 130% (`[` and `]`). Reduced motion (M) stops hover brightening. Focus rings stay amber. Settings are stored in `user://market_ui.cfg`.
- Zoom + and Zoom − enlarge the grid. The page scrolls to pan. A window under 980 px wide stacks the watchlist under the board.

### Evidence

- `.venv/bin/python -m pytest -q` passed (71 tests). The room security tests are unchanged.
- `./scripts/check_client.sh` prints `M0_CLIENT_OK` through `M6_CLIENT_OK`.
- Desktop captures: `docs/m6-table.png`, `docs/m6-rules.png`, `docs/m6-founder.png`, `docs/m6-tie.png`, `docs/m6-confirm.png`, `docs/m6-merger.png` (event overlay after a resolved merger), `docs/m6-error.png`.
- `docs/m6-narrow.png` is a 420×800 window, not a phone or tablet.
- `docs/m6-lobby.png` is a live room where Start stays off because Quinn is not ready. `docs/m6-online.png` is the same API after start: the host hand is on screen and the other seat is only a name in the feed.

### Not in this version

Web export, browser smoke tests, a physical tablet pass, Docker, HTTPS, and a PostgreSQL migration.

## 0.6.0 — 2026-11-01

M5 private rooms. Protocol version stays `0.1.0`. `POST /v1/protocol/commands/validate` still returns `applied: false`. Play goes through the room API.

### Added

- `RoomService` owns the seed, the bag, the event deck, cash, and holdings. Clients send a command name and a legal payload. They do not send cash, a hand, or a shuffle.
- Create and join mint a session token and a 6-character invite. The host is `p1`. The host starts only when 2–4 seats are ready. Nicknames are guests, not accounts.
- Commands other than create, join, reconnect, and snapshot must name `expected_state_version`. The idempotency key is `match_id`, the incoming session token, and `client_action_id`. The same payload replays. A different payload is `duplicate_action`.
- Rejected play returns a typed error: `out_of_turn`, `stale_version`, `unauthorized`, `illegal_tile`, `insufficient_cash`, `insufficient_inventory`, `wrong_phase`, and the other codes in the schema. Version and cash stay put.
- Direct snapshots include `your_hand`. Broadcast snapshots and the public `players` list do not. Other seats see `hand_count`.
- SQLite schema version is `1`. A version `0` file gains a `rooms` table in place. `MD_DATABASE_PATH` still selects the file.
- The Godot client opens an online panel: HTTP for create and join, then a WebSocket. The socket URL follows the server scheme (`ws` or `wss`). A dropped socket reconnects with the same token. A stale error asks for a fresh snapshot.
- The server depends on `websockets` 17.4. Uvicorn needs that library to accept the upgrade. Without it the socket path answers HTTP 404.
- A disconnected active seat is autopassed on the next command after 120 seconds: lowest tile, or the first legal choice, then any remaining market passes.

### Evidence

- `.venv/bin/python -m pytest -q` passed (71 tests), including hidden hands, out-of-turn, stale version, duplicate `market_buy_byte` (BYTE supply stays put), a changed payload, a foreign room, a forged tile and a forged cash field, restart from the same SQLite file, disconnect autopass, `test_http_and_websocket_share_one_room`, and a check that Uvicorn has a WebSocket implementation.
- `./scripts/check_client.sh` prints `M0_CLIENT_OK` through `M5_CLIENT_OK`.
- `docs/m5-room.png` is a Godot frame of a live room on the room API. The host session shows its own tiles. The other seat is a public count.
- Two live WebSocket clients on `127.0.0.1:8741` started room `liveplay`. Each snapshot carried a different five-tile hand, and neither snapshot included the other seat's tiles or session token.

### Not in this version

Production layout, keyboard and tablet passes, web export, Docker, HTTPS, and a PostgreSQL migration.

## 0.5.0 — 2026-11-01

M4 events and ending on the local table. Protocol version stays `0.1.0`. The HTTP validator still does not apply moves.

### Added

- The 10 event cards are shuffled with the match generator after the opening deal. A completed round draws one card, clamps each touched sector to −2…+2, and reprices BYTE and every active company. An empty deck is shuffled again with the same generator.
- Seed 7710's first event is Grid Incentives: Energy +1 and BYTE $500 to $450. The 11th draw is Risk-On Rally. Both engines match `golden_events.json`.
- Final round starts when an active company reaches 22 squares, 65 squares are occupied, or the bag and every hand are empty. Seats that have not acted still take one turn. That close applies one event, scores, and does not open another round.
- Net worth is cash plus active shares at the final prices plus BYTE at the final BYTE price. Ties break by cash, then active-share count, then the earlier opening seat. The table shows the ledger.
- Captures `docs/m4-event.png` (Grid Incentives, Energy +1, BYTE $450, round 2) and `docs/m4-score.png` (Rowan $9,000, Quinn $6,000).

### Evidence

- `.venv/bin/python -m pytest -q` passed (64 tests).
- `./scripts/check_client.sh` prints `M0_CLIENT_OK`, `M1_CLIENT_OK`, `M2_CLIENT_OK`, `M3_CLIENT_OK`, and `M4_CLIENT_OK`.

### Not in this version

WebSocket rooms, web export, and deployment.

## 0.4.0 — 2026-11-01

M3 mergers on the local table. Protocol version stays `0.1.0`. The HTTP validator still does not apply moves.

### Added

- Largest pre-placement chain survives. A tie among those largest companies opens a modal and waits for the placer. Smaller companies in the same chain are absorbed.
- Each losing company pays a majority pool of 2 × its snapshotted price and a minority pool of 1 × that price. A sole holder receives both. A tie for the most shares splits the combined pool. Otherwise the minority pool goes to the tied second place. Leftover $1 bills follow ascending player id.
- After the bonus, every losing share is sold back to the bank at the snapshotted price. The loser is inactive, with 20 bank shares and no cells. The survivor is repriced once.
- Captures `docs/m3-merger.png` (NOVA AI size 9 at $550, Quinn paid $750 plus $1,000) and `docs/m3-tie.png` (NOVA AI and ORBIT PAY tied at size 2).

### Evidence

- `.venv/bin/python -m pytest -q` passed (57 tests).
- `./scripts/check_client.sh` prints `M0_CLIENT_OK`, `M1_CLIENT_OK`, `M2_CLIENT_OK`, and `M3_CLIENT_OK`.

### Not in this version

Round events, match scoring, WebSockets, web export, and deployment.

## 0.3.0 — 2026-11-01

M2 economy on the local table. Protocol version stays `0.1.0`. The HTTP validator still does not apply moves.

### Added

- Orthogonal chain detection, founding, and growth. A size-2 unincorporated cluster asks the placer to pick an inactive brand. The founder receives one share when the bank has one.
- Growth absorbs every connected unincorporated square and reprices from `100 + 50 × size` at sentiment 0.
- Up to two market actions after resolution: buy or sell one active-company share, or buy or sell one BYTE, at the posted price. Cash and the 20-share and 30-coin totals stay intact.
- A placement that would join two active companies is rejected and does not change the board (assumption A18). That is not a merger.
- Capture `docs/m2-economy.png`: NOVA AI size 4 at $300, bank 18, Rowan holds 2 after buying one share, cash $5700 fictional, one market action left.

### Evidence

- `.venv/bin/python -m pytest -q` passed (46 tests).
- `./scripts/check_client.sh` prints `M0_CLIENT_OK`, `M1_CLIENT_OK`, and `M2_CLIENT_OK`.

### Not in this version

Merger bonuses and liquidation, round events, match scoring, WebSockets, web export, and deployment.

## 0.2.0 — 2026-11-01

M1 offline board. Protocol version stays `0.1.0`. The HTTP validator still does not apply moves.

### Added

- Local pass-and-play table in the Godot client: labeled 9×9 grid (A1–I9), five-tile hands, and a pass-the-device step that covers the next hand.
- Shared 32-bit xorshift and Fisher-Yates shuffle (assumption A16) in Python and GDScript.
- Seeded deal of the 81-tile catalog and placement that leaves cells unincorporated (assumption A17).
- Fixtures `golden_rng.json`, `golden_deals.json`, and `golden_placement.json`, checked by `server/tests/test_offline.py` and `client/tests/m1_check.gd`.
- Captures `docs/m1-opening.png`, `docs/m1-placed.png` (1280×720), and `docs/m1-narrow.png` (420×800).

### Evidence

- `.venv/bin/python -m pytest -q` passed (37 tests).
- `./scripts/check_client.sh` prints `M0_CLIENT_OK` and `M1_CLIENT_OK`.
- Opening hand for seed 7710, Rowan then Quinn: Rowan holds C1, D4, B9, E9, E6. Placing C1 draws, covers the hand, and leaves Quinn to play with 70 tiles in the bag.

### Not in this version

Founding, growth, trades, mergers, round events, match scoring, WebSockets, web export, and deployment.

## 0.1.0 — 2026-11-01

M0 foundation. No playable match.

### Added

- Godot 4.7.2 client (`4.7.2.stable.official.ed1daf0bf`) with a Compatibility renderer and a foundation screen that reads the shared contract.
- FastAPI service: `/health`, `/ready`, `/v1/protocol/schema`, and `/v1/protocol/commands/validate` (`applied` stays false).
- JSON Schema for 15 commands, 14 events, and a public match snapshot.
- Fixtures for corporations, the 10 round events, golden prices, BYTE, sentiment, winner order, and a pre-deal lobby snapshot.
- Python and GDScript kernels for the coordinate catalog, integer prices, sentiment clamp, winner order, and tile conservation.
- SQLite schema_version `0` (a `schema_meta` table only).
- `./scripts/dev.sh`, `./scripts/test.sh`, `./scripts/check_client.sh`, and a GitHub Actions workflow.
- Dockerfile and compose file, not built in this environment.

### Not in this version

Board interaction, dealing, founding, trades, mergers, round flow, scoring a match, WebSockets, web export, and any deployment.
