# M12 — Competitive multiplayer

## Goal

Private rooms stay the primary path. Add optional profiles, server-side computer seats, rankings from server results, and replays that store the ruleset. Deliverable version `0.23.x` after the checks below pass. No gameplay monetization.

## Current status

Not Started.

## Checklist

| Item | Status |
| --- | --- |
| M12.1 Optional profiles, guests still work | Not Started |
| M12.2 Lobby settings validated by the server | Not Started |
| M12.3 Server-side computer opponents | Not Started |
| M12.4 Experimental matchmaking | Not Started |
| M12.5 Rankings from confirmed results | Not Started |
| M12.6 Ranked abandonment rules | Not Started |
| M12.7 Match history and replays | Not Started |
| M12.8 Achievements from authoritative events | Not Started |
| M12.9 Cosmetics with no rules effect | Not Started |
| M12.10 Security and single-process limit | Not Started |
| M12.11 Release process | Not Started |

## Dependencies

M9's one-process room lock is a hard limit. Do not add a second API worker until the hub and the deadline loop leave process memory. Do not build a custom password store. Do not require an account for a private room. PostgreSQL stays unused until multi-instance traffic needs it.

## Acceptance

Not met. Guest private rooms already work from M5–M9 server tests. Profiles, server bots, rankings, restart-safe history, ranked policy tests, and a replay that pins the ruleset do not exist.

## Verification evidence

None for this milestone. Private rooms and the deadline sweep are recorded under M9.

## Known issues

The WebSocket hub and `sweep_due` are process-local. Documented in [ARCHITECTURE.md](../../ARCHITECTURE.md).

## Remaining

All of the checklist. Ranked play stays off until abandonment, disconnect, and duplicate-result rules are written and tested.
