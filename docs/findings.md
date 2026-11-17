# Findings

The one list of review findings that are still open. Every lens is given this file. Read it at the start of each milestone. Settled findings are in `docs/reviews/` and `docs/decisions.md`.

Status is one of: owed (with the milestone), gate (a test that must pass), guess (decided without a review of the final version).

## Gates

| Milestone | Test | If it fails | Set by |
|---|---|---|---|
| 3 | The widget in clear and tinted modes, on the lightest wallpaper, keeps 3:1 for marks and 4.5:1 for text | Use the system's vibrant foreground. If it still fails, the widget ships without clear mode support | Low vision, 15 Nov. Seen in `m3-w-clear.png` |
| 4 | History month strip and the Habit detail year grid at the largest text size, and under a blur test, in Pen and ink, Pencil and Watercolor. Includes "Not logged" against an empty today, with Show days not logged on (`notlogged-*.jpg`). Includes today's year cell holding the split diamond, with and without Increase Contrast: inside today's outline the gap is 0.63 pt, and 0.38 pt with Increase Contrast. Each check uses a 3x simulator crop, not the 1.5x screenshots. Re-run the neighbour blur check whenever the diamond gap or the mark inset changes. Where larger text grows a year or strip cell past 12 points, the diamond takes the hairline: check that size too | Month moves to milestone 13. History becomes Week only, with no control. If only today's cell fails, today's outline in the year grid goes outside the mark, or the diamond gap is never less than 1 pt | Product owner and low vision, 15 Nov. Today's split diamond: colour vision and low vision, 16 Nov, `SmallMark.swift` today box. Seen in `sheet-hist-month.png` |
| 3 | On a device with VoiceOver, the rotor offers Audio Graph on the Habit detail year grid | Wrap the grid in `.accessibilityElement(children: .contain)` and test again. If it still fails, put the descriptor on one element that sums up the year | Accessibility, 15 Nov. `App/History/HabitDetailView.swift`, YearGrid |
| 3 | Bring back offers to pause the span the habit was archived, and a run test shows a habit archived and brought back with that pause keeps its run | Bring back stays without the offer, and the owner decides open decision 6 in `docs/spec.md` | Behavioural scientist, returning user, 15 Nov. `AppModel.bringBack`, `Runs.swift` |
| 3 | One signed, sandboxed run of the Mac app with the owner's free account: export to a picked folder, import from it, and open the App Group store | Unsigned builds run without the sandbox, so no test has exercised it. If it fails, find the missing entitlement or profile and bring it to the owner | Release engineer, 15 Nov. `Config/Habit-macOS.entitlements` |
| 4 | On a device at 100%, two split diamonds side by side in a History month row do not read as the system up-down chevron of a menu | Try the 10-degree tilted gap Pencil uses, and run the blur test again | Senior designer, colour vision and low vision, 16 Nov. Seen in `history-month-paper.jpg`, Read row |
| 3 | The widget's mark sizes are added to the diamond cut test (`everyFullSizeMarkIsAboveTheCutThreshold`), so no widget mark sits near the 12 point jump | Size the widget mark clear of 12 points | Colour vision and low vision, 16 Nov. `SmallMark.diamondCut` |
| 7 | The Watch's mark sizes are added to the same test | Size the Watch mark clear of 12 points | Colour vision and low vision, 16 Nov |
| 3 | On a device with VoiceOver, "Not scheduled today" reads "Not scheduled today, 1 habit, button, collapsed", and "expanded" once open. XCUITest finds the button and its disclosure triangle but cannot read the open state | Add `.accessibilityValue` with "Collapsed" or "Expanded" and check it is not read twice | Accessibility (PR #7 review), 16 Nov. `TodayView.swift`, `testTheNotScheduledGroupReadsItsCountAndOpens` |
| 3 | The widget follows the no-set-days rule: a no-set-days habit shows on the widget every day, its mark is the dot until logged, and a log is done or part done. Test: a widget timeline entry for a mask 0 habit with no log holds `.noSetDays` | Build the widget from `Habit.state(on:today:)` and `Ordering.today`, not its own schedule check | Senior software engineer, QA, 16 Nov. `Ordering.swift`, `DayState.swift` |
| 8 | Nudges make no reminder for a habit whose rule on that day has no set days. Test: the nudge schedule for a mask 0 habit is empty | Nudges skip `hasNoSetDays(on:)` days | Senior software engineer, QA, neurodiversity, 16 Nov. `Habit+Logic.swift` |
| 13 | New habit, Edit habit and the symbol picker in Arabic and Hebrew, and in a double-length pseudo-locale: right-to-left order of the symbol row and More, the day buttons, and chips at 40% longer text | Fix the layout found. Day labels already fall back where letters repeat (`dayButtonTextsDifferInEveryLocale`) | Content designer, 16 Nov. `Pickers.swift`, `HabitFormView.swift` |
| 13 | The day list in German and Finnish at AX5: no weekday name ("Donnerstag", "keskiviikko") breaks inside the word | Apply `.minimumScaleFactor` with one shared scale for all seven names | Typographer, 16 Nov. `Pickers.swift`, DayButtons list |
| 13 | The system offers to save an export password that has no account or domain | The export screen does not mention saving | Security and privacy, 15 Nov |

## For the owner

| Question | Lenses | Recorded by |
|---|---|---|
| Under no set days, a paused day with a log extends a run (invariant 3), while a plain log is neutral. Two paused logs twenty days apart read as Longest run 2. The behavioural scientist and the neurodiversity expert recommend that a paused log under no set days be neutral, as an unpaused one is. Pausing would still never give less than not pausing. Invariant 3 would read: "A paused set day with a log extends it. Under no set days a pause changes nothing." The returning user accepts either, if a pause never lowers a run | Behavioural scientist, neurodiversity, returning user, 16 Nov | `pausedLogsApartUnderNoSetDaysChain`, `pausedLogUnderNoSetDaysNeverLowersLongest` |

## Gates passed

| Milestone | Test | Result |
|---|---|---|
| 2 | Contrast of every mark and text token, measured on a simulator against the worst pixel of each paper | Passed. Paper text 17.73, secondary 6.88, tertiary 4.87. Ink text 16.29, secondary 8.34, tertiary 5.22. Marks 3.54 to 5.06. `AppUITests/ContrastUITests.swift` |
| 2 | Import size and count limits are set, and a file over them is refused with nothing written | Passed. `ImportLimits`, tested by `HistoryTests.swift`, including a file at every limit that imports in full |
| 2 | The small diamond (year grid, History month strip, small key) blurs apart from every other small state, with a pass mark of 0.25 | Passed after a change. A whole diamond measured 0.16 against done. It is now split by a flat gap of 2.5 units in a 12-unit cell and measures 0.38 in Pen and ink. On 16 Nov the rule became one cut at every size: up to 12 points 2.5 units in 12 of the mark's width, above 12 points a 1.25 point hairline, so the full-size diamond in MarkView gains a hairline. Measurements in `docs/m4-blur-test.md` on `docs/milestone-4-design`. `SmallMark.diamondCut` and `cutDiamond`, tested by `SmallDiamondTests`. Seen in `history-month-paper.jpg`, `detail-year-paper.jpg` |

## Owed

| Milestone | Item | Where seen |
|---|---|---|
| 13 | History month with many habits has no screenshot | `m2-hist-many.png` is Week only |
| 4 | Marks in a History row are small beside text at the largest size. If the cells grow, lift the cap on the week header letters (`.dynamicTypeSize(...xxxLarge)` in `HistoryWeekHeader`) | `ax-history.png`, `ax5-history-paper.jpg` |
| 3 | After a log, the row that was logged can sit behind the Undo line at the largest sizes, and a second tap on + lands on the line. Scroll the row clear, only when covered. Test: after one tap on the first counted habit at AX5, its control does not intersect the line | Accessibility, UI and UX, 16 Nov. `ax5-undo-count-paper.jpg` |
| 13 | No screen was checked on a phone smaller than 393 by 852 points | `sheet-ax.png` |
| 3 | The marks board has no Paused or "Logged while paused" row, while the small keys name both. When pausing is built, the board gains the Paused row. The diamond row reads "Logged on a paused day or a day off" since 16 Nov | Senior designer, 16 Nov. `YouView.swift`, MarksBoardView. Seen in `marks-paper.jpg` |
| 3 | On the Mac, History shows its title twice, in the toolbar and as the heading | Owner, signed Mac run, 16 Nov. `HistoryView.swift` |
| 3 | The Undo line for a counted habit on a past day names no habit at standard sizes ("7 November: 4 of 8 glasses"). At accessibility sizes its date could be short, to save a line. Check: `ax5-undo-long-past-paper.jpg` shows four rows, not five | QA and UI and UX, 16 Nov. `AppModel.swift`, `ax5-undo-long-past-paper.jpg` |
| 3 | The Mac View menu lacks Week, Month, Year, Back, Previous and Next Period, and Go to Today | Apple industrial designer, 15 Nov. `App/HabitApp.swift` |
| 3 | On the Mac, Export a Copy opens a sheet and then the save panel. The Mac way is the save panel at once, with the warning in it | Apple industrial designer, 15 Nov. `ImportExport.swift`, ExportSheet |
| 3 | Today and You still use the 393 point column on iPad and Mac | Apple industrial designer, 15 Nov. `TodayView.swift`, `YouView.swift` |
| 3 | With every habit archived, Today shows the first-run screen and says nothing of the archived habits | Returning user, 15 Nov. `TodayView.swift`, FirstRunView |
| 3 | The Mac Habit menu, row selection and arrow keys are not built. The File menu is built, and the View menu has Today and History only | `mac-menus.png` |
| 3 | History week rows expose each day as its own VoiceOver element instead of one row summary | `App/History/HistoryView.swift` |
| 13 | Swipe to change period in Habit detail and History, beside the arrows. Needs a check that it does not fight the back swipe | Human factors, 15 Nov. `detail-month-paper.jpg` |
| 13 | "What the marks mean" in Habit detail sits below the stats, out of view, and is missing before the first log | First-day user, 15 Nov. `HabitDetailView.swift`, `detail-month-paper.jpg` |
| 13 | Weekday labels in the Habit detail week shrink one by one, so a row can mix sizes, most in longer languages | Typographer, 15 Nov. `HabitDetailView.swift`, WeekGrid |
| 13 | A file picker that fails to open a file shows nothing | UI and UX designer, 15 Nov. `ImportExport.swift`, `ImportPresenter` |
| 3 | "Pause for dates" can be reached from Habit detail, where a returning user looks at a gap | Neurodiversity, 15 Nov |
| 3 | Tests for travel across a pause edge | `docs/spec.md`, Milestone 3 screens |
| 13 | Habit detail for a no-set-days habit says nothing about why Current run is missing. A line such as "Runs count set days. This habit has none." waits for the wording lenses | Behavioural scientist, content designer, 16 Nov. `HabitDetailView.swift`, StatsBlock |
| 13 | The marks board and the small keys have no "No set days" entry. The dot's entry reads "Not scheduled" | Accessibility, 16 Nov. `YouView.swift`, `CalendarParts.swift` |
| 13 | No UI run covers the form opened after travel or a day-start change, where today's rule differs from the latest one. The kit covers `ruleForEditing` and `rule(on:)` | QA, 16 Nov. `HabitFormView.swift` init |
| 13 | Package tests run on iOS only when run on the simulator (`xcodebuild test -scheme HabitKit`). Add that run to the definition-of-done walk | Senior software engineer, 16 Nov |
| 13 | At accessibility sizes a Today row's control sits on its own line below the name and count, where it can read as part of the next row. This came before the form work | First-day user, 16 Nov. `ax5-nodays-today-paper.jpg` |
| 4 | Pencil dark version and Pencil marks board | `docs/spec.md`, Pencil |
| After MVP | Habit detail in two columns on the Mac, and a popover for a past day | `docs/spec.md`, Mac window |

## Not adopted

| Finding | Reason |
|---|---|
| Remove "Choose at least one day." and "No days chosen" from the string catalogs (senior software engineer, 16 Nov) | Neither is in a committed catalog. Both are in Xcode's uncommitted rewrite of the working copy, which marks them stale itself |
| An empty Habit detail should show an empty week, to show the shape of the screen (first-day user) | The spec asks for one sentence and Add a past day. An empty grid on day one reads as days not logged |
| A "Set to" control on the day sheet (human factors) | The "makes" line removes the sum with no new control |

## Guesses

| Item | Lens that should see it | Where |
|---|---|---|
| An archived habit shows in History under "Archived" only in a period where it has a log | Product owner, Returning user | `m2-hist-many.png` |
| An imported habit that differs keeps this device's version | Senior software engineer, QA engineer | `docs/spec.md`, Export |
| The export file keeps complete protection, though a share still running when the phone locks can then fail. The release engineer suggested complete-unless-open | Security and privacy | `App/Data/ImportExport.swift`, `writeTemporaryFile` |
