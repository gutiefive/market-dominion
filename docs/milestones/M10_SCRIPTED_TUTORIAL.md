# Scripted Classic teaching match

## Why this replaces the first guide

The Windows desktop playtest of the first guided build found that the initial placement/trading instructions felt like the end of the tutorial. The player reported no useful teaching of company formation, despite gameplay working, and reported a crowded interface and an embedded Godot window that did not expand as expected. This is a failed first-time-player comprehension result, not M10 acceptance.

The replacement is a fully authored practice game with 39 explicit teaching steps. Each new action pauses for its explanation and the preceding actual result. The next lesson remains available from the table. Off-lesson actions are rejected before the rules engine changes tiles, cash or holdings. Leaving returns to the main menu; there is no silent transition into an ordinary unguided match.

## Course

1. Private hand, coordinates, isolated placement and orthogonal connections.
2. Buy and sell BYTE at the posted quote; cash/holding changes and two market actions.
3. Demonstrated opponent turn, replacement draw, round boundaries and actual events.
4. A2 joins A1; the player chooses NOVA AI and receives a founder share.
5. Buy and sell company shares; bank inventory and the price-taking rule.
6. C1 stays separate across an empty gap; pass both market actions.
7. C2 joins C1; the player founds VOLT GRID and buys shares in both companies.
8. B2 connects two size-two companies; the player chooses NOVA AI as the tied survivor. Real bonuses and buyouts are reported from the resulting log and cash.
9. Hold BYTE across a real event, grow NOVA AI at A3, and sell BYTE at its new quote.
10. An explicit middle-game demonstration plays 15 rounds (30 placements, 60 passes, draws and events) through normal commands. It stops at NOVA AI size 21. It does not fabricate a board, skip scoring conditions or directly set a final-round flag.
11. The player places A8, reaches size 22 and passes the final market actions. Ada gets her remaining turn, the final event applies and the existing ledger scores the match.
12. Closing cash, shares, BYTE, net worth, tie-breaks and the cash reconciliation are explained before reviewing standings.

The deal, seats, existing event sequence and opponent moves are arranged, and the introduction says so. The board starts empty. All 81 coordinates remain conserved across board, bag and hands. Prices, resources, market limits, merger rules, end conditions and ranking rules are unchanged. Ordinary local and online matches do not use the tutorial deal or command restrictions. The arranged game teaches mechanics rather than optimal strategy or a guaranteed win in ordinary matches.

## Interface and window behavior

Long instruction/results content scrolls inside a bounded lesson card; Continue and Leave stay outside that scroll. The table retains a compact current-step reminder rather than repeating the entire lesson above the board. Choice text wraps and choice-card width adapts to the viewport. Player cards now wrap instead of forcing the whole page wider than a phone. The dock hides redundant phase pills on a phone, keeps the phase in its title/turn banner, and fits its bounds after refreshed controls settle. Replaced controls leave layout immediately before deferred freeing. Selecting a company restores focus to its replacement market button so Tab can continue to the enabled trade. The five hand tiles retain at least 44px targets while fitting the available phone width; market actions keep their existing horizontal scroll. All 39 production tutorial steps are also checked for page/dock overflow at phone width. Native windows now reflow at actual viewport dimensions, as the web client already did, instead of scaling a fixed reference canvas.

A Godot editor's embedded game surface and its zoom/stretch controls are separate from the application's window size. To check actual Windows window resizing, disable Godot's **Embed Game on Play** option and run the project in a separate window, then maximize that game window. This change cannot make the editor's maximize button resize a fixed embedded surface. Physical Windows maximize behavior still needs the player to repeat the check on the new build.

## Reproduce validation

```bash
./scripts/check_client.sh
./scripts/export_web.sh
# Serve build/web with scripts/serve_web.py, then:
MD_BROWSER_EVIDENCE=/tmp/md-scripted node scripts/tutorial_browser.cjs
MD_BROWSER_EVIDENCE=/tmp/md-scripted-keyboard node scripts/keyboard_browser.cjs
```

The Godot regression drives the production UI handlers through every teaching step, blocks off-script mutations, checks all economy/tile invariants, verifies coverage of founding and survivor choice, reaches 22 events and normal final scoring, and reconciles the ledger cash. A second replay must match all game state, logs and standings exactly. It also checks a 1920×1080 native-sized viewport, enlarged-text phone analysis and all 39 lesson cards at 390×844.

The browser runner uses mouse/keyboard input and screenshots/OCR of the actual exported canvas, without engine state hooks or API game commands. Adjacent share and BYTE controls use fixed desktop footer coordinates at 1280×900 and default text scale because OCR can confuse their labels with board tickers; subsequent numbered lesson transitions must still match. This coordinate fallback is a harness limitation, not a semantic accessibility test. Smoke mode covers only the opening and explicitly does not claim completion. Reports must distinguish the scripted manual actions from the middle-game demonstration. Prior browser evidence describes the earlier tutorial and is retained as historical evidence.

## Acceptance still open

The revised course needs a repeat human playtest: can a new player explain why a company forms, how trading affects cash, what an event changes, why a merger survivor is chosen and how net worth is scored? Automated completion cannot answer that. Screen-reader usability, representative physical devices, public HTTPS deployment and unavailable browser/CI checks retain their existing gates. Do not begin M11 or label M10 complete from automation alone.

Software-rendered Chromium screenshots also show missing-glyph boxes for some decorative company symbols. Company names and tickers remain present. Font fallback and assistive-technology reading are still part of the open accessibility review; the screenshots do not establish a pass for those items.

## Recorded results

- Python: 87 tests passed.
- Strict Godot M0–M10/history/focus checks passed, including all 39 teaching steps, deterministic replay, per-action invariants, normal final scoring, phone gameplay bounds throughout the course, all enlarged-text lesson cards and native viewport resizing.
- Web export and export serving/MIME smoke passed.
- [Full real-canvas course](evidence/m10-scripted-tutorial-browser.json): all 39 lessons completed, seven player placements, two player company foundings, share and BYTE buying/selling, a tied merger, six explicit event lessons, the labelled middle-game demonstration and final scoring. The run used tablet-sized input for first placement, phone-sized input for founding and phone-sized final standings. No external application requests were observed. Market trade coordinates are explicitly documented in the report. Earlier failed OCR attempts were discarded; this result came from a fresh complete run.
- [Browser keyboard entry](evidence/m10-scripted-keyboard-browser.json): menu, turn order, first lesson acknowledgement, Rules and tile shortcut/Enter. This is not a complete keyboard-only course or screen-reader test.
- [Two-browser online regression](evidence/m10-scripted-online-smoke.json): first invitation join, ready/start and five UI commands passed with no reported synchronization errors after the shared player-strip change. `completed`, `refreshed` and `reconnected` are false: the prior full M9 match/recovery acceptance was not repeated for this tutorial change.

These are development-machine/browser results. Human comprehension of the replacement course, physical Windows maximize behavior, screen readers and physical phone/tablet performance remain pending. Public HTTPS deployment is still unverified.
