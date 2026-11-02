# Roadmap M9–M12

Audit base: `2ffc6b55928e54a0c39d303ca900a563c48e7fe0`, client `0.19.0`, protocol `0.1.0`.

Current client: `0.20.0`. Protocol is still `0.1.0`. M9 local Chromium acceptance is verified; public release, CI runner results and additional browser/device gates remain pending. M10 is in progress with guided play, recorded history, local analysis, privacy decisions and seeded simulation. M11 and M12 are not started.

## What already existed

M0–M8 are in [TASKS.md](../TASKS.md). The server already had authoritative rooms, SQLite, reconnect on a command, hidden hands, duplicate `client_action_id` rejection, CORS, JSON logs that drop secret field names, health and readiness, and a single-threaded Compatibility export. Local Easy, Normal, and Hard play does not call the server. Classic rules and the shared fixtures are the contract for later modes.

## Risks that later milestones have to respect

- Room coordination and the WebSocket hub live in one process. A second API worker would apply and time out matches independently. M12 must not scale out before that moves to shared storage.
- PostgreSQL DDL exists and the process refuses to open it. Do not migrate until more than one instance is actually required.
- Deterministic fixtures and Classic mode must stay on the current rules. Dominion mode needs an explicit ruleset version before any code change.
- A passing simulation or a passing export is not a playtest, a phone test, or a public URL.

## Passes

| Pass | State | Result |
| --- | --- | --- |
| 1 Audit and these documents | Done with the 0.20.0 commit | Gaps were the deadline loop, invite URLs, web server default, export checks, and deploy examples |
| 2–3 M9 | Local acceptance verified; public release blocked | Full two-browser match, refresh/reconnect, responsive desktop viewports and container readiness passed. Public HTTPS, inaccessible CI results and physical devices remain pending |
| 4 M10 | In progress | Guided play, history, local analysis, local-only measurement and simulation implemented; human usability/accessibility and physical-device budgets remain |
| 5 M11 | Not started | Write the Dominion spec before code |
| 6 M12 | Not started | Profiles, server-side bots, rankings, replays |
| 7 Regression | Not started | Full suite plus Classic, local AI, rooms, and web export |
| 8 Final docs | Not started | Status labels must match the commands that were run |

## Work units already landed for M9

1. Settings, deadline sweep, public invite lookup, tests.
2. Invitation links, web session storage, narrow layout, `m9_check.gd`.
3. Export finish and verify, deploy examples, CI web job, this documentation.

## Next

Continue M10 from the locally verified M9 path: first-time-human tutorial usability, human accessibility review and physical-device load/frame/input budgets remain. Leave public HTTPS blocked until authorized hosting exists and the real URL is tested. The milestone files use the labels Not Started, In Progress, Implemented, Verified, and Blocked.
