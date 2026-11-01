# Architecture

Market Dominion splits a Godot 4 client from a Python rules server. Online rooms have one authoritative rules implementation on the server. Offline pass-and-play keeps a GDScript copy, and both copies have to match the JSON fixtures in `shared/fixtures/`. The protocol validator still refuses to apply a move. Room commands do apply.

## Process

```
client/  Godot 4.7 GDScript, Compatibility renderer
   |  HTTP create/join, then WebSocket /v1/rooms/ws
   |  dev reads ../shared; the web pack falls back to res://export_shared
shared/protocol/schema.json
shared/fixtures/*
server/  FastAPI. Dev listens on 127.0.0.1:8741. The image listens on 0.0.0.0:8741
   |  SQLite schema_version 1 (schema_meta + rooms)
   |  postgres:// DATABASE_URL is rejected. DDL lives in infra/migrations/
```

`GET /health` is liveness and does not touch disk. `GET /ready` opens SQLite and reads the schema. `POST /v1/protocol/commands/validate` checks an envelope and returns `applied: false`. `POST /v1/rooms/commands` and the WebSocket `/v1/rooms/ws` apply room commands.

Public snapshots omit the bag order and private hands. The schema rejects `private_tile_hand` on a public player. A direct `state_snapshot` may add `your_hand` for the session that owns those tiles. Broadcast events leave that field off.

The play screen is a scene tree, not one script painting every control. `client/scenes/main.tscn` loads `client/theme/market_theme.tres` and a feedback node. The board, tile chips, market dock, price list, and seat cards are packed scenes. They emit signals. A turn banner names who acts and whether the step is place, market, resolve, or waiting. Each seat card shows cash and the share book. Hovering a legal district previews where that tile will land. The price column keeps the last four actions. A trade or a round event flashes that price and bumps the seats that changed. A finished match opens a standings panel with Play again and Back to lobby. `match_screen.gd` still owns the match, the market pass, and the computer turns. Rules stay in `offline_match.gd` and `bot_policy.gd`. Input actions live in the project InputMap. Place, market, and click sounds are synthesized tones. The window stretches with `canvas_items` so the same layout scales.

## Kernels

| Kernel | Python | GDScript | Fixture |
| --- | --- | --- | --- |
| Coordinate catalog | `server/app/domain/coordinates.py` | `client/scripts/domain/coordinates.gd` | `coordinates.json` |
| Share and BYTE prices | `server/app/domain/pricing.py` | `client/scripts/domain/pricing.gd` | `golden_prices.json`, `golden_byte.json` |
| Sentiment clamp | `server/app/domain/events.py` | `client/scripts/domain/events.gd` | `golden_sentiment.json` |
| Winner order | `server/app/domain/scoring.py` | `client/scripts/domain/scoring.gd` | `golden_ranking.json` |
| Tile conservation | `server/app/domain/tiles.py` | `client/scripts/domain/tiles.gd` | exercised in tests |
| Match RNG and shuffle | `server/app/domain/rng.py` | `client/scripts/domain/rng.gd` | `golden_rng.json` |
| Offline deal and placement | `server/app/domain/offline.py` | `client/scripts/domain/offline_match.gd` | `golden_deals.json`, `golden_placement.json` |
| Orthogonal chains | `server/app/domain/board.py` | `client/scripts/domain/board.gd` | exercised in economy tests |
| Lobby snapshot and invariants | `setup.py`, `invariants.py` | not ported | `sample_lobby_state.json` |

GDScript has no exception type in this milestone. Rejected pricing inputs return −1, and a rejected ranking returns an empty list. Python raises `ValueError` or `TypeError`. That split is assumption A13.

## Assumptions

A1. Unshuffled coordinates are row-major, columns A–I left to right, rows 1–9 top to bottom.

A2. Nearest $10, half up, is `(numerator + unit // 2) // unit * 10` with `unit = 1000`. No floating-point money. The same helper rounds BYTE.

A3. `share_price(0, _)` is 0. Sentiment outside −2…+2 is rejected by the price function. Clamping happens only in `apply_sector_deltas`.

A4. A BYTE prior must already be a multiple of $10 inside $100–$2,000. The delta's multiplier `100 + delta` must stay positive. v1 events use −20, −10, +10, and +20.

A5. Public state stores `hand_count` (0…5) and `tile_bag_count`, never the bag order or a private hand. Occupied cells + hand counts + bag count = 81. An empty cell has `company_id: null`. An occupied cell with a null company is an unincorporated district.

A6. Inactive corporations have size 0, no cells, price 0, and all 20 shares in the bank. An active corporation has size at least 2. For every corporation, bank shares plus player holdings equal 20. BYTE exchange coins plus player coins equal 30.

A7. Phases are `lobby`, `playing`, `final_round`, and `completed`. The M0 builder emits only a pre-deal lobby. `final_round_flag` is false in lobby and playing, and true in `final_round` and `completed`. Lobby has no active player.

A8. Every command includes a non-empty `match_id`. For `create_room` that value is a client proposal. Validate does not create a room. Session tokens match `^[A-Za-z0-9_-]{8,128}$` and are opaque guest tokens, not JWTs.

A9. Nicknames match `^[A-Za-z0-9][A-Za-z0-9 _-]{0,23}$`. Invite codes, once issued, match `^[A-HJ-NP-Z2-9]{6}$` (no I, O, 0, or 1). M0 does not issue codes.

A10. Bonus remainder dollars, when mergers exist, go $1 at a time by ascending lexicographic player id. Winner order is higher net worth, then higher cash, then more active shares, then lower `turn_order_index`. Indexes are unique. Index 0 is the first seat in the shuffled opening order. Ranking does not compute net worth.

A11. Command bodies over 16,384 bytes are HTTP 413. The SQLite file is `server/data/market.db` unless `MD_DATABASE_PATH` is set. A `sqlite:///` `DATABASE_URL` overrides that path. `postgres://` and `postgresql://` raise `DatabaseURLError` at startup and name `infra/migrations/0001_rooms.sql`. The process does not open PostgreSQL. Schema version is the string `1`. A file still at version `0` gains the `rooms` table and is updated in place. Any other version is rejected. The dev port is 8741. An installed image finds `shared/` through `MD_REPO_ROOT` (`/app` in the Dockerfile) because the package lives under site-packages.

A12. Sample seed `7710` identifies `sample_lobby_state.json` and the M1 sample table (the client default and several golden deals). It is not a rules constant.

A13. GDScript rejection uses −1 or an empty collection. Python raises. Golden files cover the legal cases on both sides. Python tests cover the rejections.

A14. `round_events.json` order is the unshuffled deck. Deltas clamp per sector. A match shuffles and draws that deck under assumption A20.

A15. The web preset is single-threaded Compatibility (`variant/thread_support=false`, COOP/COEP not required). `./scripts/export_web.sh` installs the pinned 4.7.2 templates and writes gitignored `build/web/`. The shared JSON is copied to `client/export_shared/` before export and packed as `res://export_shared/`. Desktop play still reads the checkout's `shared/` directory when that path exists. The API image was built and probed on `127.0.0.1:8751`, then removed. `docker compose` is not installed here, so the compose file was not started. PostgreSQL DDL is not executed by the API. CORS is `MD_CORS_ORIGINS`. An empty list adds no middleware. A non-empty list checks the WebSocket `Origin` and still allows a missing Origin so the desktop client connects. See [infra/deploy/README.md](infra/deploy/README.md) and [RUNBOOK.md](RUNBOOK.md).

A16. The match generator is a 32-bit xorshift, not a language runtime RNG. `state = seed & 0xFFFFFFFF`, and a zero state becomes `0x6D2B79F5`. Each step is `x ^= (x << 13)`, `x ^= x >> 17`, `x ^= (x << 5)`, masked to 32 bits after each xor. `below(n)` is `next_u32() % n`; modulo bias is accepted. Seed 0 and seed 2^32 share a state. A negative seed is rejected. Opening order shuffles the entry-order roster with Fisher-Yates (`i` from `n-1` down to `1`, `j` in `0..i` inclusive), then shuffles the catalog into the bag, then deals one tile at a time round-robin for five rounds. Bag index 0 is the next draw. Player ids `p1`..`pn` stay with entry order. `turn_order_index` is assigned after the seat shuffle.

A17. M1 drew immediately after a placement. M2 does not. The current local turn is assumption A18.

A18. A local turn places one held tile, or skips when the hand is empty, then resolves founding, growth, or a merger, then allows two market actions, then draws. `round_number` starts at 1 and increments after every seat has finished that sequence, except the close that scores the match (assumption A20). Sector sentiment stays 0 until a round event. Before that, a new company's price is `100 + 50 × size`, already a multiple of $10. The founder receives one share when `bank_shares > 0`. A cluster of size at least 2 stays unincorporated when every brand is already active. Hands stay covered between seats on one device. This is not an online match.

A19. Merger survivor is the company with the largest pre-placement size. Size is the company's own cell count. The new tile and any unincorporated squares in the component do not count toward that comparison. A unique largest company resolves immediately. A tie among the largest opens phase `choose_survivor`; the tile is already on the board and unassigned until the placer picks one of those tied companies. A smaller company in the same component is absorbed and cannot be chosen. Losers resolve in corporation-fixture order. For each loser, bonuses are paid from the snapshotted share price, then every outstanding share of that loser is sold back to the bank at the same price. The loser then goes inactive with 20 bank shares, no cells, and no outstanding shares. The survivor is repriced once after every loser is done. Remainder dollars follow assumption A10. While `choose_survivor` is open, the pending component may contain more than one company; after the choice it must not.

A20. After the opening deal, the same generator shuffles the 10 events. That shuffle does not change seats or the bag. A completed round draws the front card. An empty deck is shuffled again before the next draw. Each listed sector is clamped to −2…+2, then every active company and BYTE are repriced. The log line is `Round event: {name}. {Sector} {signed value}, …. BYTE is ${price}.` Seed 7710 opens with Grid Incentives, energy +1 and BYTE $500 to $450 (`golden_events.json`). The 11th draw of that seed is Risk-On Rally. The end check runs after the draw. Triggers are an active company of size at least 22, at least 65 occupied squares, or an empty bag and empty hands. The first trigger sets `final_round`. Seats that have not finished the current round still take one turn. That close applies one event, sets phase `completed`, and does not increment `round_number`. Later commands fail with `the match is over`. Net worth is cash plus active shares at the post-event prices plus BYTE at the post-event BYTE price. Inactive shares add nothing. `rank_players` orders the ledger (assumption A10). The winner line is `{name} wins with ${net} fictional.`

A21. Online rooms wrap `OfflineMatch`. Create and join ignore the client's placeholder session token and mint `secrets.token_urlsafe(18)` plus an invite from `ABCDEFGHJKLMNPQRSTUVWXYZ23456789`. The host is the first seat. Start requires that seat, 2–4 players, and every seat ready. The live seed is `secrets.randbits(31)` unless the process was constructed with a fixed seed (tests use 7710). Create, join, reconnect, and `request_snapshot` do not have to name the current version. Other commands do. The idempotency key is `match_id|incoming session token|client_action_id`. The fingerprint is the command name plus the canonical payload. A matching fingerprint returns the stored direct events with `replayed: true` and does not apply again. A different payload is `duplicate_action`. A token from another room, or an unknown token, is `unauthorized`. Reads do not bump the version. Mutations bump it once. Direct events may include `session_token` and `your_hand`. Public events must not. The WebSocket hub personalizes each `state_snapshot` for that socket. A disconnected active player is autopassed when `grace_seconds` have elapsed since `disconnected_at`. The default is 120 seconds (`MD_GRACE_SECONDS`). The process lifespan calls `sweep_due` every `MD_DEADLINE_POLL_SECONDS` (default 2, minimum 0.2). That call holds the same lock as `apply`, so a poll cannot interleave with a command. The fallback places the lexicographic lowest tile, or takes the first legal founder or survivor choice, then passes market actions. If phase, turn index, log length, and remaining market actions are unchanged, the sweep returns no events and does not bump the version. A timeout `turn_changed` includes `reason` `grace_elapsed` and `timed_out_player`. After a restart every seat is disconnected. An existing `disconnected_at` is kept. A missing one is set to the new process clock so a crash does not forfeit every seat immediately. `GET /v1/rooms/invites/{code}` returns match id, invite code, phase, and seat display names. It does not return a session token. Activity refreshes `session_seen_at`. A token idle longer than `MD_SESSION_TTL_SECONDS` (default 86400, minimum 60) is rejected with `session expired` before a sweep. Create is limited to 30 per 60 seconds and other commands to 80 per 10 seconds, both in memory, unless `MD_ROOM_CREATE_LIMIT` and `MD_COMMAND_LIMIT` override them. Accounts do not exist. Uvicorn accepts the socket upgrade only when the `websockets` package imported at process start.

## What is intentionally absent

Accounts, a PostgreSQL driver, HTTPS termination, a public URL, a Firefox or Safari run, a phone or tablet run, a remote error sink, and computer seats in an online room. Local computers live in `client/scripts/domain/bot_policy.gd` (Easy, Normal, and Hard; five-tile placement search on Normal and Hard, three-quarter continuations, dollar scores) and do not call the server. The protocol validator still returns `applied: false`. Room rate limits do not survive a process restart. The deadline loop is inside the API process, so two API workers would each sweep the same SQLite file without a shared lock. Stay on one process. Headless Chrome loaded the loopback export far enough to construct `Engine`. It did not play a match. The container image was not rebuilt for `MD_ENV=container`.


### M9 release candidate corrections

Online command IDs include a cryptographically random per-client-load nonce and a counter. Independent browsers and refreshed pages cannot reuse another command's idempotency key; retrying the same envelope still uses the server's existing cache. Room IDs are generated independently for each creation. These identifiers do not consume the match RNG or change rules, prices, deals or scoring.

Online public snapshots retain the protocol's `seed` field as zero. The actual shuffle seed remains private on the authoritative server and in its SQLite state; exposing it would allow deterministic reconstruction of hidden hands. Fixed-seed tests still compare the same dealt hands. Personalized snapshots contain only the receiving seat's hand, and room invitations contain no token.

A replacement WebSocket subscription owns its queue. Cleanup of an older connection cannot remove the replacement or mark that seat disconnected. The client reports failed initial handshakes, retries with bounded exponential backoff, and clears the reconnect error after a fresh snapshot. Browser session storage also remembers the last dismissed round event for that room.

The online completion view uses the existing `Ranking.rank_players` tie-break order and public final holdings/prices. It displays the same final standings after refresh, without introducing financial rules or requiring a new protocol message. Web controls use actual viewport dimensions and existing flow/stack layouts at narrow widths.
