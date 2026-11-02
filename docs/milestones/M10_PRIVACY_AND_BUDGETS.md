# M10 measurement, privacy and validation budgets

## Measurement decision

M10 uses local, in-memory match facts rather than remote analytics. There is no telemetry SDK, analytics endpoint, advertising identifier, cross-session player profile, or new persistent tutorial tracking.

A local match records price changes and market-action amounts as the existing rules engine accepts them. Quote records contain round, log sequence, actual price (or an explicit unavailable/gap marker), and the action/event description. Descriptions may contain the local display names already present in the action feed. Per-seat counters cover placements, founding, buys/sells and actual merger payouts; they contain no hand, bag order, session token or shuffle seed. They are discarded with the local match.

Online history contains only public quotes actually received by the current page. It begins at page entry, resets for a different room, and inserts a break on connection loss. It is not a complete server price/trade archive and does not survive refresh. The existing online room/session storage and server SQLite persistence are unchanged. No online trade statistics are guessed from sampled snapshots.

Post-match analysis is descriptive: closing cash, closing holdings and net worth come from the actual local ledger; recorded cash spent, market sale proceeds, merger bonuses and buyouts must reconcile to closing cash. If a synthetic/restored table has incomplete accounting, the UI explicitly withholds the detailed cash narrative. Market sale proceeds are not called profit; no cost-basis or forecast is invented.

Any future external analytics requires a separate design and user-visible consent/retention decision. Do not add names, hands, tokens, raw URLs, seeds or database exports to analytics payloads. Simulation reports are explicit developer outputs with synthetic seats, seeds, outcome hashes and timing metrics; they are not collected from players.

## Enforced budgets and semantics

- At most 128 quote-change records per asset; charts display the latest eight. Identical prices do not produce synthetic movement. Stale online versions are ignored. Reader copies cannot mutate the journal.
- Chart x positions are evenly spaced recorded changes, not elapsed time. Unavailable periods and reconnect gaps break the line. Price labels and text alternatives are available without relying on color.
- Price-history toggles are keyboard-focusable and at least 44px high. Detailed histories are collapsed by default; expansion state survives ordinary UI refreshes. Charts have no animation, including with reduced motion.
- Post-match analysis uses a wrapping, scrollable panel sized to the logical viewport, including text-size changes. A 390×844 headless regression at 1.3× text checks the modal bounds and automatic scrolling of the focused replay control. The real browser run checks nominal-size phone actions; every player's rows remain scrollable.
- Simulations stop at 600 actions per game. Every accepted move checks tile/economy conservation and every seat's cash bridge. Each case is replayed and outcome/log/trace hashes must match.
- The Godot runner treats script/compile errors as failures even if the engine exits zero. A previous success JSON is removed before a browser run so a failed retry cannot masquerade as current evidence.

## Performance targets and limits

The reference target is an individual Easy bot action below 250ms and a Normal/Hard action below 1,000ms on the development machine. The simulation reports measured maxima; these timings are diagnostic rather than portable CI assertions, since hardware and contention vary. Hard bounds on history size, bot search nodes and simulation action counts remain deterministic. Report actual measurements with the evidence; do not infer device frame rate from headless simulation.

A production frame-rate or load-time budget has not been validated on physical devices. Keyboard focus order, screen-reader behavior, text scaling and touch targets need a dedicated human accessibility pass. Desktop Chromium viewport tests do not certify Safari, iOS, Android or physical touch input. First-time-human tutorial comprehension remains an open acceptance gate.

## Reproduce

```bash
./scripts/check_client.sh
./scripts/simulate.sh
./scripts/simulate.sh --seeds=7710 --seats=2 --difficulties=normal,hard --output=build/reports/m10-advanced.json
```

The default sweep covers seeds 0, 1, 4, 17 and 7710, with 2, 3 and 4 seats, on Easy, replaying each case. Reports are written under ignored `build/reports/` by default. The optional browser runner requires Playwright, Chromium, Python Pillow and tesseract:

```bash
# Serve the export with scripts/serve_web.py first.
MD_BROWSER_EVIDENCE=/tmp/md-tutorial node scripts/tutorial_browser.cjs
```

`MD_TUTORIAL_SMOKE=1` runs only the opening trade/history checks and does not pass tutorial completion. Company-label click attempts are diagnostic attempts, not accepted game decisions.

That runner drives the actual local tutorial canvas through mouse input, opens recorded history, performs trades, reaches analysis, checks phone scroll controls and watches for external application requests. It is automation, not a human learning study.
