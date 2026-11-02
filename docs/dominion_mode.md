# Dominion v1 rules specification

Status: M11 design baseline and implementation sequence. Dominion is **not playable yet**. The numerical tuning below is proposed, unbalanced and confined to a new ruleset; no Classic price, merger, event or score is changed by this document or its identity foundation.

The user authorized proceeding beyond M10 after the scripted tutorial build (`9c2d014`). This authorizes development; it does not turn pending human, accessibility, physical-device or public-deployment checks into verified results.

## Version boundaries

- `classic_v1`: the existing game, default for every current entry point and legacy saved match. Its constants, corporation roster and event effects are fingerprinted. Existing deterministic fixtures remain the compatibility contract.
- `dominion_v1`: reserved, disabled until the following mechanics, Python/Godot parity, AI and full-match acceptance exist. Never route an unknown or disabled identifier into Classic.
- A saved authoritative match stores `ruleset_id` and `ruleset_fingerprint` beside RNG state, board, hands and the event queue. Both identity fields absent means a pre-M11 Classic save. Only one absent, an unknown/disabled id, a fingerprint mismatch or changed installed Classic fixtures is an error before a restored game can execute a command.
- The fingerprint is SHA-256 of compact recursively key-sorted JSON with integral numeric values serialized as integers (including Godot-parsed floats) with keys `constants`, `corporations`, `events`. Constants exclude transport/deployment metadata (`protocol_version`, `api_port`, `command_byte_limit`, `currency`); roster and events use their actual arrays in fixture order. It detects fixture drift, not arbitrary engine-code changes or save authenticity/tampering. Golden tests must still protect engine semantics. A code/equation change requires a new ruleset identifier even when fixtures are unchanged.
- That three-key fingerprint is Classic-specific. Before Dominion activation, its own identity must also bind the versioned company pricing, merger, flow and event parameters. Do not reuse the Classic digest for Dominion. The reserved Dominion registry entry remains disabled with a null fingerprint during this experimental calculator phase.
- SQL schema remains version 1 for this Classic-only foundation: additive match JSON metadata needs no destructive migration. Loading an old save does not reshuffle or overwrite it; subsequent ordinary persistence writes the identity. Before the first persisted Dominion game, add an explicit schema-version-2 upgrade/backup path so pre-M11 binaries (which ignore extra match fields) refuse to open that database. A new engine's identity check cannot protect a downgrade into an old engine that lacks the check. This downgrade gate is required before enabling Dominion.
- Current protocol `0.1.0` remains untouched and Classic-only. Do not add fields to its strict public snapshots. A future protocol `0.2.0` change must introduce explicit ruleset selection/identity and merger-disposition commands across schema, server and Godot together, with explicit old-client compatibility or rejection. Dominion remains disabled until that contract is implemented and tested.

## Classic reference

Everything below the Dominion boundary retains the existing board, 2–4 seats, five-tile hands, $6,000 starting cash, two market actions, 20 shares/company and 30 BYTE. All money is fictional integer dollars.

Let `R10(n/d) = floor((n + 5d)/(10d)) × 10` for nonnegative integer numerator `n`, positive integer denominator `d`. This is nearest-$10 half-up rounding, implemented without floats.

Classic active share quote: `R10((100 + 50 × size) × (100 + 10 × sentiment) / 100)`, with sentiment in −2…+2. Inactive quotes are zero. Trading takes the posted price without moving it. BYTE applies the existing event percentage, rounds to $10, then clamps to $100…$2,000. The largest pre-placement company survives; ties require the placer. Losing shares receive the existing bonuses and an automatic cash buyout at their snapshotted quote. The final event and ranking tie-breaks remain unchanged.

## Dominion company identities

Retain the current five corporations and sectors. At founding, growth, merger completion and sector events, compute each active quote as:

`R10((100 + growth × size) × (100 + sensitivity × sentiment) / 100)`.

| Corporation | Sector | Growth dollars/tile | Sensitivity percent/sentiment point |
| --- | --- | ---: | ---: |
| NOVA AI | AI | 55 | 12 |
| ORBIT PAY | Fintech | 45 | 8 |
| VOLT GRID | Energy | 60 | 10 |
| PULSE MEDIA | Media | 40 | 15 |
| EVERMART | Retail | 50 | 5 |

These are experimental identities, not claims of balanced strategies. All multipliers remain positive within the existing sentiment range. Founder shares, share supply and market-action costs are unchanged. No dividends, debt, leverage, borrowing, short selling, fractional shares or company treasury is introduced in this first Dominion version.

## Dominion merger disposition

Survivor selection still uses pre-placement size and the existing tie choice. Before any payout or exchange, capture all involved companies' quotes and per-player holdings. Pay each losing company's existing majority/minority bonus once from that snapshot: majority pool `2 × quote`, minority pool `1 × quote`; a sole holder takes both; a tie for highest holdings combines both pools and splits them only among those leaders. Otherwise the unique leader receives the majority pool and the second-highest holders split the minority pool. Split leftover dollars by ascending player id. Zero holders receive no bonus.

Then resolve losers in committed corporation-fixture order and positive holders by ascending player id. Each holder chooses an integer number of **2-for-1 swap pairs**:

`0 ≤ pairs ≤ min(floor(losing_shares / 2), survivor_bank_shares)`.

Atomically return all that holder's losing shares to its bank, award `pairs` survivor shares from its bank, and pay `(losing_shares − 2 × pairs) × losing_quote` in cash. Zero pairs sells everything. Odd leftovers are sold. There is no inactive-share hold option. No share is minted and no missing survivor inventory is borrowed. Earlier valid choices consume inventory; later seats see the remaining quantity. An over-request is rejected without mutation, not silently reduced.

During the pending phase, persist a resolution id, ordered queue, current required actor, snapshots, paid-bonus flag and remaining survivor bank. The original placer resumes the market only after the queue ends. Reprice the survivor once after all choices; do not expose a temporarily recomputed price as a tradeable quote. No market command, new placement, round event or final scoring may interleave with unresolved choices.

The future `choose_merger_exchange` command names the resolution, losing company and integer pair count. Authorization uses the required holder, not automatically the tile placer. Existing stale-version and duplicate-action semantics apply. Disconnect/timeout for the required holder defaults to zero pairs; reconnect resumes the same pending choice. Empty queues skip automatically. A crash must not pay the same bonus twice or repeat a completed exchange.

## Dominion BYTE flow and event order

Trading remains price-taking at the posted quote within a round. Track round net flow: `buys − sells`, counting only accepted BYTE units. Rejected, cancelled, duplicate and preview actions do not count. Company trades do not count.

At round end, before the existing event:

1. `flow_percent = clamp(2 × net_flow, −10, +10)`.
2. `flow_quote = clamp(R10(prior_quote × (100 + flow_percent) / 100), 100, 2000)`.
3. Draw the normal existing event; apply sector deltas/clamps and company repricing.
4. Apply the event's BYTE percentage to `flow_quote`, round and clamp normally.
5. Record separate flow/event explanations and reset round net flow to zero.
6. If this was the final round, score using the resulting closing quotes.

Keep the existing event cards and their effects for this first version; use a Dominion-specific versioned fixture so later tuning cannot change Classic. Flow introduces no random draw. The original seeded event shuffle/recycle ordering stays intact. Net-zero flow produces no invented price change in history.

## Shared arithmetic and transition vectors

| Case | Inputs | Expected |
| --- | --- | --- |
| Classic quote | size 2, sentiment +1 | $220 |
| Dominion NOVA AI | size 2, sentiment +1 | $240 |
| Dominion ORBIT PAY | size 2, sentiment −1 | $170 |
| Dominion VOLT GRID | size 3, sentiment 0 | $280 |
| Dominion PULSE MEDIA | size 2, sentiment +2 | $230 |
| Dominion EVERMART | size 2, sentiment −2 | $180 |
| BYTE flow, then event | $500, net +3, event +10% | flow $530; closing $580 |
| BYTE upper flow cap | $500, net +9, event +10% | flow $550; closing $610 |
| BYTE lower clamp | $100, net −5, event −20% | flow $100; closing $100 |
| BYTE zero flow | $500, net 0, event −20% | flow $500; closing $400 |

Merger vector: loser quote $220; p1 holds 5 and p2 holds 3; survivor bank holds 3. Bonuses are p1 $440, p2 $220. p1 swaps two pairs, receives two survivor shares and sells its odd share for $220 (total cash increase $660 including its bonus). Bank now holds one survivor share. p2 requesting two pairs is invalid and changes nothing; one pair receives that last share and sells one loser for $220 (total cash increase $440 including its bonus). All 8 losing shares return to their bank, restoring its 20; survivor bank goes from 3 to 0 and outstanding survivor shares from 17 to 20. Repeat/timeout/restart tests must reproduce those values exactly.

## History, AI and acceptance

Dashboards describe actual posted quotes, accepted trades, bonuses, cash buyouts and swap counts. Distinguish cash proceeds from profits and company swaps from market purchases. Existing private-hand/session-token exclusions and local-only analytics policy remain in force.

AI receives public state and its own hand. It must evaluate legal supply-constrained exchanges and the new quotes without accessing opponent hands, bag order, hidden event order or a seed that reveals those values. Deterministic tie-breaking and a bounded search budget remain required. Compare several seeds, seat counts and difficulties with recorded parameters, per-action supply/cash/tile invariants and replay hashes. Do not label a few profitable runs as balance evidence.

Implementation order:

1. Land this text plus the Classic identity/fingerprint foundation and legacy-save tests.
2. Implement versioned Dominion pricing fixtures and Python/Godot arithmetic vectors while mode selection stays disabled.
3. Implement atomic merger queue/disposition and restart/timeout/idempotency tests.
4. Implement BYTE flow and explicit event ordering, then the coordinated wire contract and UI mode selector.
5. Add history-based dashboards and legal private-information-limited AI; run full Classic/Dominion parity simulations.
6. Complete a whole local and two-browser Dominion match, including mid-disposition refresh/reconnect, matching standings and privacy checks. Run export/container regressions and honest device/browser checks before `0.22.x` release.

The company pricing calculator is now implemented separately in Python and Godot with versioned parameters at `shared/fixtures/dominion_v1/pricing.json`. It is not connected to founding, growth, merger or event transitions yet, and does not enable Dominion in any menu or room. M11.2 game integration and M11.3–M11.8 remain open.

### Pricing calculation contract and evidence

The standalone primitive accepts a known company id, integer size 0…81 and integer sentiment −2…+2. It validates all three even when size is zero. Unknown ids never fall back to Classic. Python raises type/range errors; Godot returns −1 under its existing pricing-error convention. Booleans, strings, floats and nulls are not integer inputs. Size zero returns zero. Size one is permitted for arithmetic/rounding probes, not a change to the minimum two districts needed to found a company.

The fixture vectors include both exact half-up examples ($155 → $160 and $145 → $150), inactive and board-size boundaries, and the five written company examples. A fixed independent Fraction reference defines the full 2,050-case matrix: five companies × 82 sizes × five sentiment values. Both implementations must match its SHA-256, not just a handful of examples. Growth and sentiment monotonicity, $10 rounding, invalid inputs, parameter non-mutation, unchanged Classic quotes and disabled-mode isolation are checked. See [pricing evidence](milestones/evidence/m11-dominion-pricing.json).

These checks establish arithmetic parity, not balance, legal AI play, complete Dominion matches or browser access to a new mode.
