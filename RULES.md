# Market Dominion rules (v1 summary)

This is the project rulebook for implementation. It restates the game specification in project language. It is not a copy of any published board-game rulebook. All money is fictional integer dollars.

The local table deals tiles, founds and grows companies, merges them, and trades shares and BYTE. Round events are not drawn, and a finished match is not scored. Those gaps are listed in [TASKS.md](TASKS.md). Assumptions that close spec gaps are numbered in [ARCHITECTURE.md](ARCHITECTURE.md).

## Players and opening

- 2 to 4 players. Turn order is a shuffle of the match seed (assumption A16), shown before the first tile is revealed. The same seed deals the same seats and the same hands.
- Each player starts with $6,000 fictional cash, no shares, and no BYTE. M1 deals five private coordinate tiles and does not move cash. On one device the hand stays covered until that player continues. Online hands are not implemented.
- Hands stay private in online play. A public snapshot may show `hand_count` only.

## Board and tiles

- The board is 9 columns by 9 rows. Columns are A–I left to right. Rows are 1–9 top to bottom. The 81 cells are A1 through I9, each once.
- The unshuffled catalog order is row-major: A1, B1, … I1, A2, … I9 (assumption A1).
- Orthogonal neighbors connect. Diagonals do not.
- Every coordinate is in exactly one of: the bag, a hand, or an occupied cell.

## Corporations and BYTE

Five corporations, 20 shares each, all in the bank until founded:

| Id | Name | Sector |
| --- | --- | --- |
| `nova_ai` | NOVA AI | ai |
| `orbit_pay` | ORBIT PAY | fintech |
| `volt_grid` | VOLT GRID | energy |
| `pulse_media` | PULSE MEDIA | media |
| `evermart` | EVERMART | retail |

BYTE is the only speculative coin. It opens at $500. The exchange holds 30 coins and players hold none. Supply stays 30 across the exchange and all players. Coins are not mined, minted, shorted, or sent player to player. BYTE does not change sector sentiment.

Sector sentiment starts at 0 for each sector and stays inside −2…+2.

## Turn

1. Place one tile from hand onto its matching empty cell. With no tile, skip placement.
2. Resolve growth, founding, or a merger before market actions. A tie for the largest pre-placement company waits for the placer (assumption A19).
3. Up to two market actions, either of which may be passed: buy one share, sell one share, buy one BYTE, or sell one BYTE, at the price currently posted. No loans, shorts, fractions, or negative cash.
4. Draw one tile if the bag has one. The hand returns to five when the bag allows it. A hand never exceeds five (assumption A5). The draw happens after the market actions.
5. After every remaining player has taken one turn, apply exactly one round event, reprice, and check the end of the game. M3 does not do this. Sentiment stays 0 and BYTE stays at its posted price.

M3 runs steps 1 through 4. Founding requires a connected unincorporated cluster of size at least 2 and an inactive brand. The founder receives one share when the bank has one. Growth absorbs every connected unincorporated square and reprices from the new size. A merger pays each loser, liquidates that stock, then reprices the survivor once.

A player may place with $0. Buying needs cash and inventory. A timer, when enabled later, plays a deterministic legal tile, takes safe defaults, and passes leftover market actions.

## Placement

- Only empty or unincorporated neighbors: the tile joins that cluster. At size 2 or more, if an inactive corporation exists, the placer founds one.
- Exactly one active corporation among the new orthogonal connections: that corporation takes the tile and any attached unincorporated squares.
- Two or more active corporations: merger. The largest pre-placement chain survives. A tie among the largest is chosen by the placer. Every loser is absorbed in that same resolution. No intermediate repricing.
- If no inactive corporation remains, a qualifying cluster stays independent.
- After the transaction, one connected component does not contain two active corporations.

## Founding

The placer picks an inactive corporation. Every unincorporated square in the component joins it. The founder receives one free share when the bank has one. A later founding only happens after a merger has already cashed everyone out of that name. If the bank is somehow empty, founding still succeeds and the missing free share is recorded.

## Share price

For an active company, after each placement, merger, and event:

- `BASE = 100 + (50 × size)`
- `M = 100 + (10 × sentiment)` percent
- Price = `BASE × M / 100`, then nearest $10, half up

Examples: size 4 at sentiment 0 is $300; at +2 is $360; at −2 is $240. Size 0 is inactive and is $0, not a formula result (assumption A3). Inactive names are not traded. Computation stays in integers (assumption A2).

## Mergers and bonuses

Snapshot size, sentiment, holdings, and prices before the board changes.

The survivor keeps its shareholders and gains every square in the merged component.

For each loser, separately:

- Majority pool = 2 × that company's snapshotted share price.
- Minority pool = 1 × that price.
- Compare positive share counts.
- One player holding every share, or the only player with shares, receives both pools.
- A tie for the most shares: add the pools and split them across the tied leaders. Everyone else gets no bonus.
- Otherwise the majority pool splits across the tied leaders and the minority pool splits across the tied second place.
- Indivisible dollars: everyone eligible gets the integer quotient, then leftover $1 bills go in ascending lexicographic player id (assumption A10). No holders means no bonus.
- Every player then sells all of that losing stock back to the bank at the snapshotted price. v1 has no hold-or-convert choice.
- The loser goes inactive with 20 shares in the bank, none outstanding, and no cells.

Then reprice the survivor once from its new size. Log the merger and each cash change.

## BYTE price

At the end of a full round, `new = prior × (100 + delta) / 100`, nearest $10, half up, then clamp to $100–$2,000. A posted price is already a multiple of $10 inside that range (assumption A4). Final scoring values coins at the last posted BYTE price.

The spec example: $500 and a +20% event posts $600.

## Round events

One event per completed round, drawn from a seeded shuffle of this deck. When the deck is empty it is reshuffled with the same match generator. Repeat events after a reshuffle are allowed. M0 stores the unshuffled order and can clamp a delta; it does not draw (assumption A14).

| Event | Sectors | BYTE |
| --- | --- | --- |
| AI Adoption | ai +1 | +10% |
| Fintech Regulation | fintech −1 | −20% |
| Grid Incentives | energy +1 | −10% |
| Media Boom | media +1 | +10% |
| Retail Slowdown | retail −1 | −10% |
| Risk-On Rally | ai +1, fintech +1 | +20% |
| Risk-Off Shock | ai −1, fintech −1 | −20% |
| Consumer Recovery | retail +1, media +1 | +10% |
| Energy Crunch | energy −1 | +10% |
| Liquidity Freeze | all −1 | −20% |

Each sector clamps to −2…+2 after its own delta.

## Ending

The final round starts when any active company reaches 22 squares, or 65 squares are occupied, or the bag and every hand are empty. Players who have not acted in the current round finish one turn. The scheduled event is applied once. Then score. Do not open another round after that.

Net worth = cash + (active shares × posted prices) + (BYTE × posted BYTE price). Inactive holdings must be zero. Highest net worth wins. Ties break by higher cash, then more active shares, then the earlier opening turn (lower turn-order index). Show the ledger and the turn log.

## What a client may not decide

Online matches will take holdings, cash, tile order, randomness, and the winner from the server. M0 only checks the shape of a command. It will not accept a command as a played move.
