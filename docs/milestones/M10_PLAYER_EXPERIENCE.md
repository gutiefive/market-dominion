# M10 — First-time player experience

## Goal

A new player can finish a guided match without knowing the original board game. Target deliverable version `0.21.x` once the milestone is verified. Development retains client version `0.20.0` and protocol `0.1.0`; this is not a complete M10 release.

## Current status

In Progress. The client now has a main menu, a guided local Classic match, phase-specific explanations, recorded quote history and local post-match analysis. Privacy/measurement decisions and a multi-seed simulation harness are also implemented. M9's local browser acceptance is the prerequisite already recorded in the M9 release report. Its public-hosting and compatibility limitations remain open.

## Checklist

| Item | Status |
| --- | --- |
| M10.1 Main menu | Implemented; local/browser route checks |
| M10.2 Guided tutorial | Initial guided Classic match implemented; first-time-human usability acceptance still open |
| M10.3 Contextual explanations | Implemented for the guided local placement, founding, merger, market and completion phases |
| M10.4 Visual hierarchy | In Progress: clear menu entry and separate guidance card; broader gameplay review pending |
| M10.5 Market feedback from real history | Implemented: actual local quote changes; online observations since page entry with reconnect gaps |
| M10.6 Post-match analysis | Implemented for local/guided matches: closing holdings, net change, action counts and reconciled cash flows |
| M10.7 Privacy-conscious analytics | Local-only measurement decision implemented; no remote telemetry or new player tracking |
| M10.8 Headless seeded simulation | Verified: 34 deterministic games, 5,672 actions, replay hashes and per-action conservation/cash checks |
| M10.9 Accessibility and performance budgets | Deterministic bounds, reference action budgets, history text alternatives and scrollable analysis implemented; human accessibility and physical-device budgets pending |

## First-slice behavior

The default entry offers **Learn Classic · guided match**, **Play computers**, **Pass and play**, and **Online room**. Direct web invitations and configured-server entry continue into the existing M9 room panel. Text size, reduced motion and rules remain available.

The guided entry opens a real two-seat Classic match: seed 7710, Rowan as the human and Ada as an Easy computer. It uses the existing turn-order screen, placement, trading, founding/merger dialogs, round events and standings. Hints follow the actual phase. “Show a tile in my hand” selects an existing hand tile without placing it or consuming a game action. It is an example legal tile, not a claim of an optimal move. “Continue without guidance” removes the hints while retaining the match. Main menu returns to the entry choices.

Guidance never changes the match RNG, prices, resources, scoring or rules. No tutorial progress, private hand or player identifier is sent to an analytics service. Computer hands retain the existing concealment behavior.

## Verification

`client/tests/m10_check.gd`, included in `scripts/check_client.sh`, exercises the production menu and guided UI handlers. It completes the seeded match with 59 automated human-seat actions, checks tile/economy invariants after each action, and confirms visible guided-completion standings. It fingerprints match state around guidance calls to detect mutations, and verifies returning to pass-and-play or the online room clears the tutorial route appropriately. The deterministic run covers placement, market and founding; it does not claim a human usability playtest or general multi-seed simulation.

The UI regression also exposed an existing unowned hidden checklist label; it now belongs to the table and is freed with it. The regression exits without the earlier resource-leak warnings.

Python tests: 87 passed. Godot M0–M10 and the web export passed. In Chromium 154.0.8037.57, actual menu/turn-order controls opened the guided table; tile help and placement advanced the visible guidance from placement to market. The 390×844 desktop menu viewport was inspected and its header/buttons remained readable. A two-browser M9 invitation regression passed create, copy invite, first join, ready/start and five early game actions, without synchronization assertions failing. This short regression is not another complete M9 match. Browser and regression outcomes are also recorded in the changelog. A canvas screenshot or automated seeded completion does not establish that a first-time player understands the game.

## Recorded history and analysis

Local quote history is captured at successful rules-engine actions, including computer moves and round events. Planning, rejected actions and repeated unchanged prices produce no fictitious movement. Charts expose the latest eight recorded changes with numeric text and the actual action/event explanation. Inactive companies and connection gaps break lines. History expansion stays open across ordinary updates; there is no chart animation. Online history is explicitly limited to snapshots received by this page, with no invented backfill after refresh or reconnect.

Local standings now show changes from starting cash, closing cash/portfolio/net, placements, founding, market buys/sells, cash spent, sale proceeds, merger bonuses and buyouts. Starting cash minus market spending plus sales, bonuses and buyouts must equal final cash. Incomplete accounting is labelled instead of presenting an invented narrative. This is descriptive accounting, not a cost-basis profit calculation or a new financial mechanic. The modal wraps and scrolls at narrow widths.

See [privacy decisions, budgets and reproduction commands](M10_PRIVACY_AND_BUDGETS.md). [Easy simulation evidence](evidence/m10-simulation-easy.json) covers 30 games and 5,044 actions; [Normal/Hard evidence](evidence/m10-simulation-advanced.json) adds four games and 628 actions. Every case replayed deterministically with invariant and cash checks after each move. Maximum observed action latency was 37.33ms for Easy and 78.909ms across Normal/Hard on this development machine; these are not physical-device frame-rate results.

The [browser tutorial result](evidence/m10-tutorial-browser.json) records an actual canvas-driven completion with 18 placements, BYTE buying/selling, recorded history expansion, visible desktop analysis and reachable phone-sized standings actions. No external application requests were observed. This remains automation, not a human comprehension study. The harness's modal detector was corrected during the run after it mistook an old merger description for an active dialog; label-click attempts are explicitly not accepted game decisions.

The phone layout regression also checks full modal bounds at the largest existing text setting (1.3×), history-control focus/font scaling, 44px decision targets and automatic scrolling of the focused replay button. This is not a human screen-reader or physical-device certification.

Focused history checks cover duplicate/stale snapshots, gaps, bounded memory, immutable reader copies, price-taking trades, rejected trades, planning/RNG non-mutation and incomplete-accounting disclosure. The strict Godot and simulation wrappers reject engine script errors even when Godot exits zero.

## Remaining acceptance

Run a first-time-human guided playtest and refine explanations from observed confusion. Complete a human keyboard/screen-reader/text-size review and measure load/frame/input budgets on representative physical devices. Online quote history remains page-local rather than a complete archive; detailed local trade analysis is not fabricated for online snapshots. Public HTTPS, unavailable browser/device compatibility and inaccessible CI results remain M9 external gates. Do not mark M10 complete or ship `0.21.x` until the remaining acceptance is verified.
