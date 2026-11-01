# Milestones

M3 is the stage this tree claims as playable. A box is checked only where a command was run and the result is recorded in [CHANGELOG.md](CHANGELOG.md).

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
- [ ] Docker image actually built (Docker was not installed; compose file only)
- [ ] Browser export

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

Sentiment clamp and BYTE rounding exist. The deck does not move and nothing scores a match.

- [ ] Seeded event deck, one event per completed round, reshuffle
- [ ] End triggers at size 22, 65 occupied, or no tiles left
- [ ] Final-round turns for players who have not acted
- [ ] Ledger and deterministic tie break on a finished match
- [ ] Replay: same seed and commands, same result

## M5 Online rooms

The HTTP validator is not multiplayer.

- [ ] WebSocket rooms for 2–4 players
- [ ] Private hands filtered per session
- [ ] Server-side rejection of illegal, stale, duplicate, and cross-room commands
- [ ] Reconnect and restart without a double trade

## M6 Production UI

- [ ] Board layout, rules overlay, keyboard path, reduced motion, error screens
- [ ] Tablet landscape pass

## M7 Ship

- [ ] Web export loaded over HTTPS
- [ ] Container backend with a real database migration and health checks
- [ ] Smoke on current desktop Chrome, Firefox, and Safari

## Known limits

- Validate never mutates a match. The offline table lives in the client and in `OfflineMatch`; it is not a server room.
- Sector sentiment stays 0 during play. Round events and end-game scoring are M4.
- GDScript rejection for prices is −1 or an empty list; the offline table returns `{ok: false, error}`. Python raises (assumption A13).
- Docker and web export were not executed (assumption A15).
