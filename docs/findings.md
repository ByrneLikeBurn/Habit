# Findings

The one list of review findings that are still open. Every lens is given this file. Read it at the start of each milestone. Settled findings are in `docs/reviews/` and `docs/decisions.md`.

Status is one of: owed (with the milestone), gate (a test that must pass), guess (decided without a review of the final version).

## Gates

| Milestone | Test | If it fails | Set by |
|---|---|---|---|
| 3 | The widget in clear and tinted modes, on the lightest wallpaper, keeps 3:1 for marks and 4.5:1 for text | Use the system's vibrant foreground. If it still fails, the widget ships without clear mode support | Low vision, 15 Nov. Seen in `m3-w-clear.png` |
| 4 | History month strip at the largest text size, and under a blur test, in Pen and ink, Pencil and Watercolor | Month moves to milestone 13. History becomes Week only, with no control | Product owner and low vision, 15 Nov. Seen in `sheet-hist-month.png` |
| 3 | One signed, sandboxed run of the Mac app with the owner's free account: export to a picked folder, import from it, and open the App Group store | Unsigned builds run without the sandbox, so no test has exercised it. If it fails, find the missing entitlement or profile and bring it to the owner | Release engineer, 15 Nov. `Config/Habit-macOS.entitlements` |
| 13 | The system offers to save an export password that has no account or domain | The export screen does not mention saving | Security and privacy, 15 Nov |

## Gates passed

| Milestone | Test | Result |
|---|---|---|
| 2 | Contrast of every mark and text token, measured on a simulator against the worst pixel of each paper | Passed. Paper text 17.73, secondary 6.88, tertiary 4.87. Ink text 16.29, secondary 8.34, tertiary 5.22. Marks 3.54 to 5.06. `AppUITests/ContrastUITests.swift` |
| 2 | Import size and count limits are set, and a file over them is refused with nothing written | Passed. `ImportLimits`, tested by `HistoryTests.swift`, including a file at every limit that imports in full |

## Owed

| Milestone | Item | Where seen |
|---|---|---|
| 2 | History month with many habits is not drawn | `m2-hist-many.png` is Week only |
| 2 | Marks in a History row are small beside text at the largest size | `ax-history.png` |
| 2 | No screen was checked on a phone smaller than 393 by 852 points | `sheet-ax.png` |
| 3 | The Mac Habit menu, row selection and arrow keys are not built. File and View menus are | `mac-menus.png` |
| 3 | History week rows expose each day as its own VoiceOver element instead of one row summary | `App/History/HistoryView.swift` |
| 3 | Tests for travel across a pause edge | `docs/spec.md`, Milestone 3 screens |
| 4 | Pencil dark version, Pencil marks board, hand-drawn dashes for days to come | `docs/spec.md`, Pencil |
| After MVP | Habit detail in two columns on the Mac, and a popover for a past day | `docs/spec.md`, Mac window |

## Guesses

| Item | Lens that should see it | Where |
|---|---|---|
| The row menu item that opens Habit detail is called "Details" | Content designer | `m3-menu.png` |
| An archived habit shows in History under "Archived" only in a period where it has a log | Product owner, Returning user | `m2-hist-many.png` |
| An imported habit that differs keeps this device's version | Senior software engineer, QA engineer | `docs/spec.md`, Export |
| The export file keeps complete protection, though a share still running when the phone locks can then fail. The release engineer suggested complete-unless-open | Security and privacy | `App/Data/ImportExport.swift`, `writeTemporaryFile` |
