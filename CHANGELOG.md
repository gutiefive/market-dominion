# Changelog

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
