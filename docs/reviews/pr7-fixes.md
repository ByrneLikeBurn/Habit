# PR #7 review fixes, on feat/history

Nine lenses reviewed PR #7 and found six items on Today. The lines were the same on `feat/history`, so they were fixed there once, in 988d609. The accessibility, UI and UX, and QA lenses then checked that commit as separate subagents.

## Round 1

| Lens | # | Finding | Result |
|---|---|---|---|
| All three | 1 | The middle cut in the Undo line removed part of the status ("journal…rchived"), and could remove a count or the word "cleared" | Fixed. `UndoLine` carries the name and the status apart. At accessibility sizes the name takes one line and loses its end. The status always shows in full, with Undo beside it when both fit and under it when not. VoiceOver reads the whole line. Shots: `ax5-undo-long-paper.jpg`, `ax5-undo-long-past-paper.jpg`, `ax5-undo-count-paper.jpg` |
| UI and UX, Accessibility | 2 | At AX5 the capsule covered most of the list | Fixed by the split. The archived line is two lines. The longest, a past-day clear, is four including Undo |
| UI and UX | 3 | The spec and two comments still said the swipe shows Edit and Archive | Fixed. Details, Edit and Archive |
| UI and UX, Accessibility | 4 | Only the archived line had a long-name screenshot | Fixed. The past-day and counted lines have AX5 shots |
| UI and UX, QA | 5 | "%@ brought back" had no translator comment | Fixed, and each status has its own comment |
| Accessibility | 6 | Voice Control may not match "Not scheduled today" against the longer label | Fixed. `.accessibilityInputLabels` names the words on screen. Still to confirm on a device, with gate 3 in findings |
| Accessibility, QA | 7 | The Undo target was tested only at the default size | Fixed. `testAtTheLargestSizeTheStatusShowsAndUndoKeepsItsTarget` runs at AX5 on the longest status |
| QA | 8 | The edge tap had never been seen to fail | Checked. With `.contentShape` removed, the default-size test fails (frame 18 points). The AX5 test passes without it, because the word alone is over 44 points there |
| QA | 9 | No test covered the counted Undo line | Fixed. `testCountedUndoLineShowsTheNewTotalAndTakesItBack` |
| QA, Accessibility | 10 | The counted lines joined strings outside the catalog | Fixed. Both are localized formats with comments. The wording is unchanged |
| QA | 11 | Only the "one" plural form was tested | Fixed. `theNotScheduledLabelHasBothPluralForms` reads the catalog |
| QA | 12 | The working copy of the string catalog is an uncommitted Xcode rewrite with auto-generated comments | Not adopted. It is the owner's open Xcode session. Only the new plural entry was committed. Xcode takes the comments from the source when it extracts |

## Round 2

Accessibility passed all five of its round 1 findings. UI and UX passed four, and failed the capsule height for past-day and counted lines. QA passed four and one in part.

The lenses disagreed on the name. UI and UX wanted one line and Undo moved off the status line. Accessibility and QA wanted two lines, so similar names can be told apart. The third option meets both. Undo sits at the trailing end of the name line, so it is always top right. The name has two lines, and the status has the full width below. At AX5 the archived and counted lines take three lines and a past-day clear four, against four and three before. The capsule no longer covers the counted mark. This was put together after both rounds and has not been back to the lenses.

| Lens | Finding | Result |
|---|---|---|
| QA | The three-line cap at standard sizes was lost, so an imported 500-character name could fill the screen | Fixed. A sentence taller than three lines splits the same way. Checked once with a 300-character fixture name at the largest standard size: three lines. The fixture was restored |
| QA | The AX5 test reads the full label, which does not change with what is drawn | Fixed in part. The status has an identifier, and the test checks it is taller than one line. The words themselves are checked by `ax5-undo-long-past-paper.jpg` |
| QA | `undoLongPast` fell back to yesterday, where the tap logs | Fixed. With no log in the last week no line shows, and the test says the fixture is the cause |
| UI and UX | Undo moved between screens at AX5 | Fixed by the third option |
| UI and UX, QA, Accessibility | The `undo()` call was mis-indented | Fixed |
| QA | At standard size the past-day counted line names no habit, "7 November: 4 of 8 glasses" | Owed to milestone 3. It is a wording change for the content lenses |
| UI and UX | The past-day status could use a short month at accessibility sizes | Owed to milestone 3, with the item above |
| Accessibility | After a log, scroll the row that was logged clear of the capsule | Owed to milestone 13 |
