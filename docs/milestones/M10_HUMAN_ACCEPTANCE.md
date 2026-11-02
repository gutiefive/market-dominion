# M10 human acceptance worksheet

Status: **pending human execution**. Automated matches and desktop viewport tests do not satisfy these gates. Record findings without player names, private hands, session tokens or raw invitation URLs.

## First-time player

Use a person who has not played this build. Record build commit, browser/version, operating system, viewport and whether the device is physical. Start from the main menu with the scripted guided Classic match. Confirm that the first lesson identifies an arranged teaching game, and that each new action pauses for instructions/results. Observe before explaining the controls.

1. Ask the player to start learning Classic. Record which entry they choose and any hesitation.
2. Ask them to select and place a tile. Can they explain why a company was founded or grew?
3. Let them buy or sell, then ask what price they paid and whether trading itself changed the posted price.
4. At a company choice, merger or round event, ask them to describe what happened and who acts next. The scripted course must teach both founding and a tied merger; missing either is a defect.
5. Ask them to open a recorded price history and distinguish recorded changes from a forecast.
6. Acknowledge the labelled middle-game demonstration, then place the final-round trigger and finish the match. Ask them to identify the winner, closing cash, holdings and the reason net worth differs from cash. Can they find replay and the main menu?
7. Record observed confusion, time lost, facilitator assistance and exact unclear text. Propose narrowly scoped copy/layout fixes and repeat affected steps after changes.

Acceptance: the player completes the flow and explains placement, trading, events and final standings without facilitator instruction. Any blocked action or material misunderstanding requires correction and a repeat observation.

## Keyboard and assistive technology

Record browser, operating system, input method and assistive technology/version. Check keyboard-only use separately from screen-reader use.

- At the first lesson, read/scroll the instructions, Tab to **Try this step**, then press Enter before using the table. Each next teaching dialog requires acknowledgement.
- Tab and Shift+Tab traverse visible actions with an identifiable focus indicator. Number keys select a hand tile; Enter places the intended selection.
- Open Rules from a focused action. Focus enters the panel; arrow scrolling and Tab reach Close rules; Escape returns to the opener.
- Open a trade confirmation. Cancel receives initial focus. Tab stays inside the dialog; Enter on Cancel closes without spending cash.
- Required founding/merger choices retain focus and cannot be dismissed with Escape. Nested Rules returns to the underlying choice.
- Read errors and events and dismiss them using the keyboard. Background actions must not activate while a dialog is open.
- At final standings, scroll through every player's analysis and reach replay/menu. Repeat at the largest existing text setting and with reduced motion.
- With a screen reader, check meaningful control names, reading order, price-history text alternatives, event announcements and private-hand confidentiality. Record inaccessible canvas content as a defect, not a pass based on focus tests.

## Physical-device and performance record

Test a representative tablet and phone in their actual browsers. Record hardware, browser, connection, build, cold-load time to usable menu, input response and observed frame stalls during placement, events and standings. Check the whole board, hand selection, market actions and player information in portrait and landscape. Record desktop viewport emulation separately.

Report measured results and critical usability defects before setting hardware-specific release budgets. Public HTTPS and additional browser compatibility remain pending until tested on the actual hosted build.

## Result record

- Build / date:
- Device / browser / viewport / physical or emulated:
- Scenario / observed result:
- Assistance required / defect / severity:
- Fix commit / repeat result:
- Remaining untested steps:
- Acceptance decision and evidence:
