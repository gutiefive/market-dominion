# Architecture

Market Dominion splits a Godot 4 client from a Python rules server. Online matches will have one authoritative rules implementation on the server. Offline play keeps a GDScript copy, and both copies have to match the JSON fixtures in `shared/fixtures/`. M1 adds a local pass-and-play deal and placement loop. There is still no WebSocket and no company resolution.

## Process

```
client/  Godot 4.7 GDScript, Compatibility renderer
   |  reads shared/ in the dev checkout (export packaging is later)
shared/protocol/schema.json
shared/fixtures/*
server/  FastAPI on 127.0.0.1:8741
   |  SQLite schema_version 0 (meta row only)
```

`GET /health` is liveness and does not touch disk. `GET /ready` opens SQLite and reads the schema. `POST /v1/protocol/commands/validate` checks an envelope and returns `applied: false`.

Public snapshots omit the bag order and private hands. The schema rejects `private_tile_hand` on a public player.

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

A11. Command bodies over 16,384 bytes are HTTP 413. The SQLite file is `server/data/market.db` unless `MD_DATABASE_PATH` is set. Schema version is the string `0`. The dev port is 8741.

A12. Sample seed `7710` identifies `sample_lobby_state.json` and the M1 sample table (the client default and several golden deals). It is not a rules constant.

A13. GDScript rejection uses −1 or an empty collection. Python raises. Golden files cover the legal cases on both sides. Python tests cover the rejections.

A14. `round_events.json` order is the unshuffled deck. Deltas clamp per sector. Drawing and reshuffling are not implemented.

A15. Docker Compose and the Godot web export were not run. The Compatibility renderer is selected so that export remains possible. See [infra/deploy/README.md](infra/deploy/README.md).

A16. The match generator is a 32-bit xorshift, not a language runtime RNG. `state = seed & 0xFFFFFFFF`, and a zero state becomes `0x6D2B79F5`. Each step is `x ^= (x << 13)`, `x ^= x >> 17`, `x ^= (x << 5)`, masked to 32 bits after each xor. `below(n)` is `next_u32() % n`; modulo bias is accepted. Seed 0 and seed 2^32 share a state. A negative seed is rejected. Opening order shuffles the entry-order roster with Fisher-Yates (`i` from `n-1` down to `1`, `j` in `0..i` inclusive), then shuffles the catalog into the bag, then deals one tile at a time round-robin for five rounds. Bag index 0 is the next draw. Player ids `p1`..`pn` stay with entry order. `turn_order_index` is assigned after the seat shuffle.

A17. M1 drew immediately after a placement. M2 does not. The current local turn is assumption A18.

A18. A local turn places one held tile, or skips when the hand is empty, then resolves founding or growth, then allows two market actions, then draws. `round_number` starts at 1 and increments after every seat has finished that sequence. Sector sentiment stays 0, so a new company's price is `100 + 50 × size`, already a multiple of $10. The founder receives one share when `bank_shares > 0`. A cluster of size at least 2 stays unincorporated when every brand is already active. A placement whose connected component contains two or more active companies is rejected with `merger is not in this build` and does not change the board, hands, cash, or holdings. That rejection is a legality stub, not a merger. Hands stay covered between seats on one device. This is not an online match.

## What is intentionally absent

Rooms, WebSockets, reconnect, idempotent command application, merger payouts, the round-event draw, end-game scoring from a board, accounts, and deployment. The HTTP validator still returns `applied: false`.
