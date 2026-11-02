# M11 — Dominion mode

## Goal

Add a versioned advanced ruleset while Classic retains the current v1 equations and deterministic fixtures. Target `0.22.x` only after implementation and acceptance. Current client remains `0.20.0`, protocol `0.1.0`.

## Current status

**In Progress — identity foundation, isolated pricing and merger financial resolution.** The user accepted the scripted M10 build for continued development. Deferred human/device/accessibility/public-release checks remain open.

The [Dominion specification](../dominion_mode.md) was written before this implementation. It defines experimental company identities, supply-constrained 2-for-1 merger swaps with cash residuals, round BYTE flow/event ordering, arithmetic vectors, timeout/restart behavior, privacy, AI constraints and staged acceptance. Numerical tuning is proposed, not balance-verified.

## Checklist

| Item | Status |
| --- | --- |
| M11.1 Classic and Dominion modes | In Progress: shared version registry, Classic fingerprint, persisted identity and legacy restore; Dominion reserved and disabled, network selection/UI pending |
| M11.2 Company financial identities | Python/Godot standalone calculators verified across 2,050 cases; versioned parameters implemented; match integration pending |
| M11.3 Merger choices within the share supply | Financial core verified in Python/Godot: queue, swaps, cash leftovers, receipts, replay and timeout; match/board/room/UI integration pending |
| M11.4 BYTE price model | Specified; implementation pending |
| M11.5 Market events | Existing effects retained in design; Dominion ordering/fixtures pending |
| M11.6 Financial dashboards from match history | Pending Dominion implementation |
| M11.7 AI for Dominion, no hidden-hand access | Pending |
| M11.8 Seeded balance runs with recorded parameters | Pending |

## Foundation behavior

The shared `fixtures/rulesets.json` reserves `classic_v1` and `dominion_v1`; only Classic is playable. Python and Godot normalize integral JSON numbers, sort keys and compute the same SHA-256 over semantic constants, corporation roster and event effects. Transport/deployment metadata is excluded. The installed fixtures must match the committed Classic fingerprint.

Authoritative saved-match JSON stores both identity fields with the original RNG, hands, board and event queue. A genuine old save missing both fields loads as Classic without reshuffling and gains identity on its next normal persistence. A partial identity, unknown/disabled ruleset, changed fixture or mismatched stored hash fails before execution. Failure does not rewrite the stored room blob. This is compatibility validation, not cryptographic save authentication or engine-code verification.

Current public snapshots, room creation, Classic equations and protocol `0.1.0` remain unchanged. No menu exposes Dominion yet; asking either engine to create a Dominion game fails instead of playing Classic under a new label. No SQL DDL migration is necessary for this Classic-only foundation. Before Dominion activation, a database schema-version gate must also prevent older binaries from opening new-mode saves; extra JSON fields alone cannot protect a downgrade.

## Verification

Results for this foundation are recorded after the Python, strict Godot, export and browser regressions below. Classic golden tests, the complete scripted course and local bot tests remain required. There is no finished Dominion match, balance result, new online mode or `0.22.x` release claim.

## Next

Implement BYTE flow and round-event ordering next, then integrate the verified pricing/merger components into the new match lifecycle. Keep Classic fixtures pinned and Dominion selection disabled until its engine, network contract and acceptance checks are ready.

## Foundation results

- 102 Python tests passed: 87 existing regressions plus 15 identity/legacy-save cases. Coverage includes unchanged legacy continuation/RNG/hands, current save round-trip, unsupported/disabled identities, partial metadata, fixture drift, transport-metadata exclusions, persisted legacy room restart and rejection without rewriting a corrupt room blob.
- Strict Godot M0–M11/history/focus checks passed. Classic/tutorial behavior remains covered; the new M11 check verifies cross-language canonical hashes, explicit/default Classic deal equality, isolated registry readers and refusal to create Dominion/unknown modes.
- Web export passed. The [actual canvas tutorial smoke](evidence/m11-classic-tutorial-smoke.json) loaded the packed registry and completed the first five lessons, including BYTE buy/sell and an event. It explicitly does not claim another full tutorial completion.
- The [updated-server two-browser regression](evidence/m11-classic-online-smoke.json) passed invitation join, ready/start and five UI commands against a disposable database. Full match, refresh and reconnect are false in this short report; existing longer acceptance is not relabelled as a new run.
- Docker image `55766a3d56dcf0f29612e9464b0f88d7a3298905c38a4695dffeacd11ccebc30` built successfully. Inside the installed image, Classic fingerprint resolution and saved-state round-trip passed. `/health`, `/ready` and Docker health status passed; database schema and public protocol remain `1` and `0.1.0`. The temporary verification container was removed.

Public HTTPS, CI runner results, human revised-tutorial comprehension, physical-device budgets and human accessibility checks remain unverified. These do not become Dominion acceptance evidence.


## Company pricing results

The [pricing evidence](evidence/m11-dominion-pricing.json) records matching Python/Godot hashes for all 2,050 company/size/sentiment combinations against an independent exact-Fraction reference. Shared fixtures contain the experimental profiles and explicit written/rounding/boundary vectors. Tests reject invalid inputs, check quote monotonicity and whole-board bounds, preserve Classic's $220 example while Dominion NOVA AI returns $240, and confirm the factory still refuses Dominion. This is arithmetic coverage, not game integration or balance evidence.

127 Python tests and strict Godot M0–M11/history/focus/pricing checks passed. The standard Godot runner now includes the full pricing matrix test. Web export and Chromium canvas/Engine load smoke passed. The harness initially raced profile cleanup after the page loaded; it now terminates its own Chromium process group, waits/reaps processes and retries transient profile-directory cleanup. Two subsequent runs exited cleanly. This is a load check, not browser Dominion gameplay. Docker image `584e085e848f6103b726dd751352af41853617d56b4bfb917e7eb9c327129e48` built successfully; its installed calculator and nested fixtures reproduced all 2,050 quotes and kept Dominion disabled. No Classic equation, core fixture, protocol field, saved-game format or gameplay screen changed in this pricing step.


## Merger core results

See the [financial-resolution core and integration contract](M11_MERGER_CORE.md) and [evidence](evidence/m11-dominion-merger.json). Python/Godot match all four manual scenarios and the full 15-snapshot trace. Both check 2,135 legal exchanges across 420 holdings/bank combinations and 420 over-request rejections. JSON restore, fresh-Python-process continuation, bonus/idempotency retries, timeout/late timeout, inconsistent state rejection, copied ledgers and private-field exclusion are covered.

591 Python tests passed. Strict Godot Classic/tutorial/identity/pricing regressions passed, including the final exhaustive merger checks; the standard runner includes the merger script. Web export and Chromium canvas/Engine load smoke passed. The harness initially raced profile cleanup after the page loaded; it now terminates its own Chromium process group, waits/reaps processes and retries transient profile-directory cleanup. Two subsequent runs exited cleanly. This is not browser Dominion gameplay or live-room reconnect acceptance. Docker image `9f927cd115e9ca3922b82303f8877439a2d82b69e6b56d202181146d1960872d` built successfully; its installed module and fixtures reproduced all four scenarios and the same complete state trace, including JSON recovery. Classic's merger path, wire protocol and persisted room schema remain unchanged.
