# M11 — Dominion mode

## Goal

Add a versioned advanced ruleset while Classic mode keeps the current v1 rules. Deliverable version `0.22.x` after the spec and the tests exist.

## Current status

Not Started.

## Checklist

| Item | Status |
| --- | --- |
| M11.1 Classic and Dominion modes | Not Started |
| M11.2 Company financial identities | Not Started |
| M11.3 Merger choices within the share supply | Not Started |
| M11.4 BYTE price model | Not Started |
| M11.5 Market events | Not Started |
| M11.6 Financial dashboards from match history | Not Started |
| M11.7 AI for Dominion, no hidden-hand access | Not Started |
| M11.8 Seeded balance runs with recorded parameters | Not Started |

## Dependencies

A written specification comes before code. It needs equations, state transitions, edge cases, and test vectors. Shared fixtures and saved Classic matches must not change silently. The ruleset version has to be stored with the match.

## Acceptance

Not met. Classic compatibility, a finished Dominion match, supply invariants, server authority, and legal AI play are all open.

## Verification evidence

None. No Dominion specification file exists yet.

## Known issues

None. The feature is absent.

## Remaining

Write `docs/dominion_mode.md` (or a successor path named in the spec commit) before changing prices, mergers, or events. Then implement against that text.
