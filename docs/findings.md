# Findings

The one list of review findings that are still open. Every lens is given this file. Read it at the start of each milestone. Settled findings are in `docs/reviews/` and `docs/decisions.md`.

Status is one of: owed (with the milestone), gate (a test that must pass), guess (decided without a review of the final version).

## Gates

| Milestone | Test | If it fails | Set by |
|---|---|---|---|
| 2 | Contrast of every mark and text token, measured on a simulator against the worst pixel of each paper | Fix the token, not the floor | Low vision, 15 Nov |
| 2 | Import size and count limits are set, and a file over them is refused with nothing written | Import does not ship | Security and privacy, QA, 15 Nov |
| 3 | The widget in clear and tinted modes, on the lightest wallpaper, keeps 3:1 for marks and 4.5:1 for text | Use the system's vibrant foreground. If it still fails, the widget ships without clear mode support | Low vision, 15 Nov. Seen in `m3-w-clear.png` |
| 4 | History month strip at the largest text size, and under a blur test, in Pen and ink, Pencil and Watercolor | Month moves to milestone 13. History becomes Week only, with no control | Product owner and low vision, 15 Nov. Seen in `sheet-hist-month.png` |
| 13 | The system offers to save an export password that has no account or domain | The export screen does not mention saving | Security and privacy, 15 Nov |

## Owed

| Milestone | Item | Where seen |
|---|---|---|
| 2 | History month with many habits is not drawn | `m2-hist-many.png` is Week only |
| 2 | Marks in a History row are small beside text at the largest size | `ax-history.png` |
| 2 | No screen was checked on a phone smaller than 393 by 852 points | `sheet-ax.png` |
| 2 | The Mac keyboard shortcuts are proposals and have not been tried in a build | `mac-menus.png` |
| 3 | Tests for travel across a pause edge | `docs/spec.md`, Milestone 3 screens |
| 4 | Pencil dark version, Pencil marks board, hand-drawn dashes for days to come | `docs/spec.md`, Pencil |
| After MVP | Habit detail in two columns on the Mac, and a popover for a past day | `docs/spec.md`, Mac window |

## Guesses

| Item | Lens that should see it | Where |
|---|---|---|
| The row menu item that opens Habit detail is called "Details" | Content designer | `m3-menu.png` |
| An archived habit shows in History under "Archived" only in a period where it has a log | Product owner, Returning user | `m2-hist-many.png` |
| An imported habit that differs keeps this device's version | Senior software engineer, QA engineer | `docs/spec.md`, Export |
