# Dominion financial-resolution core

Status: implemented and verified in separate Python/Godot components. **Dominion remains disabled.** This is not a playable merger UI, room command, board transition or database migration.

## Implemented behavior

`DominionMerger.begin` takes a resolution id, survivor, original placer, losing-company ids and a complete public financial ledger. It captures opening quotes and holdings, calculates each losing company's existing bonus once, and builds the choice queue in corporation-fixture order then ascending holder id. Input arrays can arrive in another order; the resolution order stays deterministic. Constructor inputs are copied and never debited in place. Only id, cash, share counts, bank inventory and quote fields are copied; private hands, seeds and session metadata are not part of the component export.

`current_choice` returns a copied pending holder/company and the current maximum swap count. A decision returns every losing share to its bank, awards the chosen 2-for-1 survivor shares from the live bank, and pays the odd/unexchanged remainder at the frozen losing quote. No share is minted or borrowed. Inadequate bank inventory is rejected rather than silently reducing the request. Each accepted decision advances the component version once and returns a copied receipt. A matching action-id retry returns its original receipt without another payment, including after restore or completion; a changed decision reusing that id fails. Like the existing room idempotency behavior, updating only the expected-version precondition on a retry still returns the original receipt; it does not turn the retry into another exchange.

An invalid holder, company, resolution, version, quantity or action id leaves the ledger unchanged. `timeout` is an explicit default-to-cash operation for the named current holder; a late deadline cannot advance a later holder. **The caller still has to verify a real deadline or disconnect.** The component has no clock, WebSocket or session-token authentication.

All companies maintain bank shares + player holdings = 20. Opening cash must be a nonnegative signed-31-bit integer; quotes must be $10 multiples no higher than their company’s size-81/+2 quote. These input bounds keep the existing integer bonus helper and JSON round-trips exact and cover normal reachable game balances. The caller must still validate the actual board, active companies, legal survivor and current posted quotes; the component is not a substitute for match invariants.

The queue completes only after all positive holders resolve. A company with no holders adds no choices. On completion the export names the original placer as the resume target, but does not change turns, start trading, mark board cells, deactivate companies or reprice anything. Opening quotes are historical snapshots, not final tradeable quotes.

## Serializable state

The internal export has `format_version: 1`, `ruleset_id: dominion_v1`, a normalized opening financial snapshot, snapshotted bonuses, cash/holdings/banks, ordered queue and cursor, required actor, original placer, remaining survivor bank, bonus-paid flag, decisions and receipts. It contains no board, RNG, hands or connection state. It is an internal persistence format, **not** a new public protocol payload.

Restore starts from the original opening ledger, replays recorded decisions and compares every derived field against the saved data. It does not add bonuses onto saved post-bonus cash. Partial, inconsistent, unknown-format and changed-derived snapshots fail. This detects inconsistent serialized state; it is not a cryptographic save-authenticity check against someone rewriting the entire opening and history coherently.

The decision version is local to this resolution. Future room integration must continue validating the room’s global state version and authenticated required holder, then use the stored component version internally. Do not substitute one version counter for the other.

## Integration still required

Before a real match can use this core:

1. The game engine selects the legal survivor and snapshots the involved companies before any financial effect. Start/persist the financial ledger and pending board resolution atomically, and apply copied balances once; do not call `begin` again using already-paid balances.
2. While pending, block placement, trading, round events and scoring in the game engine. Persist/resume the queue with the room and expose a deliberately limited public pending-choice projection through the future protocol.
3. Authorize each command against the required holder’s actual session; use the existing room stale-version/idempotency protections and the core's receipts. Bind the existing deadline sweeper to the named holder and current resolution, rather than automatically the original placer.
4. When complete, atomically apply the financial ledger, assign merged board cells, deactivate losing companies, reprice the survivor once, and resume the original placer's market step.
5. Add the planned database downgrade guard, protocol 0.2 contract, client choices, full-match AI and actual browser refresh/reconnect acceptance before enabling Dominion.

Classic still uses its existing automatic buyout path and unchanged protocol. No current menu or room can select Dominion.

## Verification

[Shared financial vectors](../../shared/fixtures/dominion_v1/merger_vectors.json) specify manual payouts, queue order, bank inventories and closing holdings for the written example, multiple losers, a four-player minority remainder and no holders. Both engines produce the same complete 15-snapshot trace across those four cases. The trace hash is a versioned regression baseline; the financial expectations are separately asserted, not inferred solely from the hash.

Both engines check all **420** positive-holdings (1…20)/survivor-bank (0…20) combinations and all **2,135** legal pair counts, plus one over-request rejection for each combination. Tests cover odd leftovers, supply conservation, invalid actor/resolution/version, duplicate/reused ids, copied-reader isolation, JSON reload before each choice, inconsistent derived snapshots, empty queues, timeout retries and late deadlines. Python additionally resumes a pending decision in a fresh interpreter and confirms retrying the earlier action does not repay its bonus or shares.

See [recorded evidence](evidence/m11-dominion-merger.json). Whole room/server restart, browser reconnection, board repricing, turn resumption, legal AI and balance remain unverified for Dominion because integration has not been implemented.
