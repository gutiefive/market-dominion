# Roadmap M9–M12

Audit base: `2ffc6b55928e54a0c39d303ca900a563c48e7fe0`, client `0.19.0`, protocol `0.1.0`.

Current client: `0.20.0`. Protocol is still `0.1.0`. M9 is in progress. M10, M11, and M12 are not started.

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
| 2–3 M9 | In progress | Server and export checks below are verified. Public HTTPS, a browser match, and device tests are not |
| 4 M10 | Not started | Menu, tutorial, charts, analytics, simulation harness |
| 5 M11 | Not started | Write the Dominion spec before code |
| 6 M12 | Not started | Profiles, server-side bots, rankings, replays |
| 7 Regression | Not started | Full suite plus Classic, local AI, rooms, and web export |
| 8 Final docs | Not started | Status labels must match the commands that were run |

## Work units already landed for M9

1. Settings, deadline sweep, public invite lookup, tests.
2. Invitation links, web session storage, narrow layout, `m9_check.gd`.
3. Export finish and verify, deploy examples, CI web job, this documentation.

## Next

Finish M9 only by exercising a real two-browser match, a refresh, and the browsers that are actually available. Leave public HTTPS blocked until a hosting account exists and the URL is opened. Do not start M10 feature work on top of an untested multiplayer path. The milestone files use the labels Not Started, In Progress, Implemented, Verified, and Blocked.
