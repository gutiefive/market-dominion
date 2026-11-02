# M10 — First-time player experience

## Goal

A new player can finish a guided match without knowing the original board game. Target deliverable version `0.21.x` once the milestone is verified. The first slice retains client version `0.20.0` and protocol `0.1.0`; it is not a complete M10 release.

## Current status

In Progress. The first slice adds a main menu, a guided local Classic match and phase-specific explanations. M9's local browser acceptance is the prerequisite already recorded in the M9 release report. Its public-hosting and compatibility limitations remain open.

## Checklist

| Item | Status |
| --- | --- |
| M10.1 Main menu | Implemented; local/browser route checks |
| M10.2 Guided tutorial | Initial guided Classic match implemented; first-time-human usability acceptance still open |
| M10.3 Contextual explanations | Implemented for the guided local placement, founding, merger, market and completion phases |
| M10.4 Visual hierarchy | In Progress: clear menu entry and separate guidance card; broader gameplay review pending |
| M10.5 Market feedback from real history | Not Started |
| M10.6 Post-match analysis | Not Started; existing M9 standings remain |
| M10.7 Privacy-conscious analytics | Not Started; no analytics or telemetry added |
| M10.8 Headless seeded simulation | Not Started as a general simulation harness; a single-seed UI regression is present |
| M10.9 Accessibility and performance budgets | In Progress: keyboard-focusable menu/help controls and wrapping menu header; budgets and broader device verification pending |

## First-slice behavior

The default entry offers **Learn Classic · guided match**, **Play computers**, **Pass and play**, and **Online room**. Direct web invitations and configured-server entry continue into the existing M9 room panel. Text size, reduced motion and rules remain available.

The guided entry opens a real two-seat Classic match: seed 7710, Rowan as the human and Ada as an Easy computer. It uses the existing turn-order screen, placement, trading, founding/merger dialogs, round events and standings. Hints follow the actual phase. “Show a tile in my hand” selects an existing hand tile without placing it or consuming a game action. It is an example legal tile, not a claim of an optimal move. “Continue without guidance” removes the hints while retaining the match. Main menu returns to the entry choices.

Guidance never changes the match RNG, prices, resources, scoring or rules. No tutorial progress, private hand or player identifier is sent to an analytics service. Computer hands retain the existing concealment behavior.

## Verification

`client/tests/m10_check.gd`, included in `scripts/check_client.sh`, exercises the production menu and guided UI handlers. It completes the seeded match with 59 automated human-seat actions, checks tile/economy invariants after each action, and confirms visible guided-completion standings. It fingerprints match state around guidance calls to detect mutations, and verifies returning to pass-and-play or the online room clears the tutorial route appropriately. The deterministic run covers placement, market and founding; it does not claim a human usability playtest or general multi-seed simulation.

The UI regression also exposed an existing unowned hidden checklist label; it now belongs to the table and is freed with it. The regression exits without the earlier resource-leak warnings.

Python tests: 87 passed. Godot M0–M10 and the web export passed. In Chromium 154.0.8037.57, actual menu/turn-order controls opened the guided table; tile help and placement advanced the visible guidance from placement to market. The 390×844 desktop menu viewport was inspected and its header/buttons remained readable. A two-browser M9 invitation regression passed create, copy invite, first join, ready/start and five early game actions, without synchronization assertions failing. This short regression is not another complete M9 match. Browser and regression outcomes are also recorded in the changelog. A canvas screenshot or automated seeded completion does not establish that a first-time player understands the game.

## Remaining acceptance

Run a first-time-human guided playtest; refine explanations from observed confusion. Then implement and validate real market-history feedback, accurate post-match analysis, the analytics/privacy decision, a multi-seed invariant simulation harness, and explicit accessibility/performance budgets. Test guidance across additional seeds and merger scenarios, and on physical devices. Do not mark M10 complete or ship a `0.21.x` milestone release on the basis of this first slice.
