# Milestone 1 reviews

Five lenses ran as separate subagents on branch `feat/core-loop`, two at a time. Each saw `CLAUDE.md`, the spec, the decisions log and the diff, not the working.

## Senior software engineer

| # | Finding | Result |
|---|---|---|
| 1 | Each Today row scanned every event of its habit several times per redraw, and the 30-habit fixture had almost no history | Fixed. Today fetches only today's events once, rows get their total passed in, and `LogWriter` reads a day-filtered fetch. The 30-habit fixture has 200 days of history and a scroll test |
| 2 | `HabitRule` is a composite attribute, so its shape is frozen. `target` and `scheduleMask` can drift from `rules` | Fixed. The spec records the frozen shape, and `schedule` has no setter, so it changes only through `setRule` |
| 3 | Screenshots did not pin language, region or runtime, and animations still ran | Fixed. The script pins iOS 26.5, `en` and `en_GB`, and turns off UIKit animations in fixture mode. It still waits a fixed 4 seconds |
| 4 | The one-write-path check scanned only `App/` and could not be shown to fail | Fixed. It scans every source folder, also catches `.delta =`, and has a can-fail test |
| 5 | A failed save left an unsaved event counted, and the error was swallowed | Fixed. The event is deleted and the error rethrown. Today shows "That log could not be saved. Try again." |

## QA engineer

| # | Finding | Result |
|---|---|---|
| 1 | Running a yes-or-no shortcut twice took the log back. Take away with no amount added | Fixed. Requests from outside the app map through `LogAction.external`: a yes-or-no shortcut only logs, and Take away with no amount takes away one tap. Tested |
| 2 | A huge typed number could overflow a sum and crash every launch | Fixed. Typed numbers are capped at 1,000,000, writes are clamped, and sums saturate. Tested |
| 3 | At the day boundary a row could log a different day than it showed | Fixed. A row logs the day it shows, and Today rebuilds its query when the day changes |
| 4 | Runs left out a logged day after today | Fixed. Runs run to the later of today and the last log. Tested |
| 5 | Missing tests: day-start change, 320 and 375 points, a log after travel, day turnover in the UI, intent parameters | Partly fixed. Day-start change, log after travel and the intent mapping are tested. No simulator at 375 or 320 points is installed, so those layouts are not checked. There is no UI test for day turnover |

## Tired daily user

| # | Finding | Result |
|---|---|---|
| 1 | A wrong tap on a counted habit had no Undo, and a done counted mark looks like a tick that can be untapped | Fixed. Every counted change shows its count with Undo |
| 2 | The Undo screenshot showed "Read taken back." with Read still done | Fixed. The screenshot runs a real take-back |
| 3 | The plus hid the part-done hatching | Fixed with accessibility 2 |
| 4 | Most of the row opens Edit, not a log | Fixed after the owner decided. A tap on the name logs. Edit and Archive are in swipe actions and the menu. UI tests cover the name tap, Edit and Archive |
| 5 | Take away looked disabled | Fixed. It is an outlined button |

## Accessibility expert

| # | Finding | Result |
|---|---|---|
| 1 | At AX5 the count sheet's keyboard hid the total | Fixed. At accessibility sizes the sheet opens full height and does not raise the keyboard by itself |
| 2 | The plus on a part-done mark covered most of the hatching | Fixed. The plus has a thin paper halo, not a disc |
| 3 | The count line outline was about 1.4:1 | Fixed. It uses the tertiary text colour, over 4.8:1 |
| 4 | A counted row's name target was 28 points high | Fixed. Name and count line each keep 44 points |
| 5 | The Undo line timed out for Switch Control and Voice Control users | Fixed. It stays until the next action for everyone |
| | Also: the name placeholder was cut at AX5 | Fixed. The field shows up to four lines |
| | Also: adjustable actions give the count as the value, not the step | Not changed. The count is what a VoiceOver user needs to hear after each step. The spec wording is ambiguous, and the step is in the hint |

## Security and privacy

| # | Finding | Result |
|---|---|---|
| 1 | The branch commits carry the owner's personal email as author and committer. `main` uses the GitHub noreply address | Fixed after the owner approved. The branch was rewritten and force pushed with the noreply address. Old commits may stay reachable on GitHub by id. The global git config still holds the personal address |
| 2 | `LogHabitIntent` runs on a locked device, so Siri can list habit names and read counts aloud | Fixed after the owner decided. Every intent needs an unlocked device. A source check tests each intent |
| 3 | Deleted habits would still be offered in Shortcuts and Siri | Fixed. Deleted habits are never offered. Archived habits are listed after active ones |
| 4 | The comment said the device id never leaves the device, but export and sync will carry it | Fixed. The comment is corrected. Milestone 2 decides whether export keeps the id |
