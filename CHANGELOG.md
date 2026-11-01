# Changelog

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
