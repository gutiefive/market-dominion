# Milestones

M0 is the only stage this tree claims. A box is checked only where a command was run and the result is recorded in [CHANGELOG.md](CHANGELOG.md).

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

Not started as a playable surface. The catalog, conservation checker, and Godot project are the pieces M1 should build on.

- [ ] Interactive 9×9 labeled grid in `client/`
- [ ] Seeded bag shuffle and a deal of five unique tiles per seat
- [ ] Local pass-and-play turn ownership
- [ ] Legal-cell highlight for the active hand
- [ ] Conservation test that walks a scripted deal, not only a static partition
- [ ] Screenshot of a real placement

## M2 Economy

Price math exists and is tested. Formation, growth, and trades do not.

- [ ] Founding when two orthogonal unincorporated squares connect
- [ ] Free founder share and the 20-share identity after the grant
- [ ] Growth that absorbs a connected unincorporated cluster
- [ ] Two market actions that move cash and inventory at the posted price
- [ ] Reject a third action, an inactive name, and a purchase that would go negative

## M3 Mergers

- [ ] Survivor from pre-placement sizes, with a tie modal
- [ ] Majority and minority pools, including sole holder and ties
- [ ] Remainder dollars by ascending player id
- [ ] Automatic liquidation of every losing share
- [ ] Multi-company merger with one reprice

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

## Known M0 limits

- Validate never mutates a match. There is no match.
- GDScript rejection is −1 or an empty list; Python raises (assumption A13).
- Docker and web export were not executed (assumption A15).
