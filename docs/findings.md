# Findings

The one list of review findings that are still open. Every lens is given this file. Read it at the start of each milestone. Settled findings are in `docs/reviews/` and `docs/decisions.md`.

Status is one of: owed (with the milestone), gate (a test that must pass), guess (decided without a review of the final version).

## Gates

| Milestone | Test | If it fails | Set by |
|---|---|---|---|
| 4 | Add plus alone against plus with dot (a counted habit with no set days) to the blur test in `tools/marks/small_shapes.py`. It passes at 0.25 | Enlarge the dot under a plus, or draw it in the secondary colour | Colour vision and low vision, 16 Nov. `nodays-mark-3x-*.png` |
| 3, owner's device | The widget in clear and tinted modes, on the lightest wallpaper, keeps 3:1 for marks and 4.5:1 for text | Use the system's vibrant foreground. If it still fails, the widget ships without clear mode support | Low vision, 15 Nov. Seen in `m3-w-clear.png` |
| 4 | History month strip and the Habit detail year grid at the largest text size, and under a blur test, in Pen and ink, Pencil and Watercolor. Includes "Not logged" against an empty today, with Show days not logged on (`notlogged-*.jpg`). Includes today's year cell holding the split diamond, with and without Increase Contrast: inside today's outline the gap is 0.63 pt, and 0.38 pt with Increase Contrast. Each check uses a 3x simulator crop, not the 1.5x screenshots. Re-run the neighbour blur check whenever the diamond gap or the mark inset changes. Where larger text grows a year or strip cell past 12 points, the diamond takes the hairline: check that size too | Month moves to milestone 13. History becomes Week only, with no control. If only today's cell fails, today's outline in the year grid goes outside the mark, or the diamond gap is never less than 1 pt | Product owner and low vision, 15 Nov. Today's split diamond: colour vision and low vision, 16 Nov, `SmallMark.swift` today box. Seen in `sheet-hist-month.png` |
| 3, owner's device | On a device with VoiceOver, the rotor offers Audio Graph on the Habit detail year grid | Wrap the grid in `.accessibilityElement(children: .contain)` and test again. If it still fails, put the descriptor on one element that sums up the year | Accessibility, 15 Nov. `App/History/HabitDetailView.swift`, YearGrid |
| 3, owner's device | One signed, sandboxed run of the Mac app with the owner's free account: export to a picked folder, import from it, and open the App Group store | Unsigned builds run without the sandbox, so no test has exercised it. If it fails, find the missing entitlement or profile and bring it to the owner | Release engineer, 15 Nov. `Config/Habit-macOS.entitlements` |
| 4 | On a device at 100%, two split diamonds side by side in a History month row do not read as the system up-down chevron of a menu | Try the 10-degree tilted gap Pencil uses, and run the blur test again | Senior designer, colour vision and low vision, 16 Nov. Seen in `history-month-paper.jpg`, Read row |
| 7 | The Watch's mark sizes are added to the same test | Size the Watch mark clear of 12 points | Colour vision and low vision, 16 Nov |
| 3, owner's device | On a device with VoiceOver, "Not scheduled today" reads "Not scheduled today, 1 habit, button, collapsed", and "expanded" once open. XCUITest finds the button and its disclosure triangle but cannot read the open state | Add `.accessibilityValue` with "Collapsed" or "Expanded" and check it is not read twice | Accessibility (PR #7 review), 16 Nov. `TodayView.swift`, `testTheNotScheduledGroupReadsItsCountAndOpens` |
| 3, owner's device | The widget on a Home Screen: a tap on a row logs it and its mark changes; a tap on a row drawn before the day turned over writes nothing and redraws | If a tap does not log, check the App Group store path in the widget. If a stale tap logs, the rule in `WidgetSnapshot.accepts` is not reached | Milestone 3 build, 18 Nov. `Shared/WidgetLogIntent.swift` |
| 3, owner's device | The widget in StandBy and on the iPad lock screen while locked: the rows are redacted and the "Today" header shows | Check `.privacySensitive()` on the widget's rows reaches the system. If not, hide the rows with `\.redactionReasons` | Security and privacy, 18 Nov. `Shared/WidgetViews.swift` |
| 3, owner's Mac | The View and Habit menus on the Mac: each item acts on History, Habit detail or the selected Today row, the arrow keys move the selection, and Export a Copy opens the save panel with its warning. The Import panel shows no export wording | Fix the item that fails. No UI test runs on the Mac | Milestone 3 build, 18 Nov. `App/HabitApp.swift`, `ImportPresenter` |
| 8 | Nudges make no reminder for a habit whose rule on that day has no set days. Test: the nudge schedule for a mask 0 habit is empty | Nudges skip `hasNoSetDays(on:)` days | Senior software engineer, QA, neurodiversity, 16 Nov. `Habit+Logic.swift` |
| 13 | New habit, Edit habit and the symbol picker in Arabic and Hebrew, and in a double-length pseudo-locale: right-to-left order of the symbol row and More, the day buttons, and chips at 40% longer text | Fix the layout found. Day labels already fall back where letters repeat (`dayButtonTextsDifferInEveryLocale`) | Content designer, 16 Nov. `Pickers.swift`, `HabitFormView.swift` |
| 13 | The day list in German and Finnish at AX5: no weekday name ("Donnerstag", "keskiviikko") breaks inside the word | Apply `.minimumScaleFactor` with one shared scale for all seven names | Typographer, 16 Nov. `Pickers.swift`, DayButtons list |
| 13 | The system offers to save an export password that has no account or domain | The export screen does not mention saving | Security and privacy, 15 Nov |

## For the owner

| Question | Lenses | Recorded by |
|---|---|---|
| None open. The paused-log question was decided by the owner on 16 Nov: under no set days a pause changes nothing. See `docs/decisions.md` | | |

## Gates passed

| Milestone | Test | Result |
|---|---|---|
| 3 | Bring back offers to pause the span the habit was archived, and a run keeps through it | Passed. `BringBackOffer` in `PauseDatesView.swift`. Test: "Pausing: bring back" in `PausingTests.swift`, current run 8 after the pause |
| 3 | The widget's mark size is in the diamond cut test | Passed. The widget's `MarkView(size: 24)` is a literal in `Shared/WidgetViews.swift`, which the source check reads; 24 × 0.68 is above 12. `WidgetSnapshot.markSize` |
| 3 | The widget follows the no-set-days rule | Passed. `WidgetSnapshot.make` uses `Ordering.today` and `Habit.state`. Test: "Widget snapshot" in `PausingTests.swift`, a mask 0 habit holds `.noSetDays` |
| 3 | After a log at AX5, the logged row's control does not intersect the Undo line | Passed. `testAtTheLargestSizeTheLoggedRowScrollsClearOfTheLine` |
| Merge of PR #12 | The owner's Mac test of New habit and Edit habit: Cancel and Add show in the sheet and work, Return adds, Esc cancels | Passed, owner, 17 Nov, with Mac test part 3 |
| 2 | Contrast of every mark and text token, measured on a simulator against the worst pixel of each paper | Passed. Paper text 17.73, secondary 6.88, tertiary 4.87. Ink text 16.29, secondary 8.34, tertiary 5.22. Marks 3.54 to 5.06. `AppUITests/ContrastUITests.swift` |
| 2 | Import size and count limits are set, and a file over them is refused with nothing written | Passed. `ImportLimits`, tested by `HistoryTests.swift`, including a file at every limit that imports in full |
| 2 | The small diamond (year grid, History month strip, small key) blurs apart from every other small state, with a pass mark of 0.25 | Passed after a change. A whole diamond measured 0.16 against done. It is now split by a flat gap of 2.5 units in a 12-unit cell and measures 0.38 in Pen and ink. On 16 Nov the rule became one cut at every size: up to 12 points 2.5 units in 12 of the mark's width, above 12 points a 1.25 point hairline, so the full-size diamond in MarkView gains a hairline. Measurements in `docs/m4-blur-test.md` on `docs/milestone-4-design`. `SmallMark.diamondCut` and `cutDiamond`, tested by `SmallDiamondTests`. Seen in `history-month-paper.jpg`, `detail-year-paper.jpg` |

## Owed

| Milestone | Item | Where seen |
|---|---|---|
| 13 | `WidgetLogIntent.perform` has no test of its own: only the rule it calls (`accepts`) is tested. The owner's widget gate covers it on a device | QA, 18 Nov. `Shared/WidgetLogIntent.swift` |
| 13 | The Pause for dates impact line counts active habits only. An archived habit's days change too, unseen | QA, 18 Nov. `Pausing.swift`, `PauseImpact.of` |
| 13 | No UI test covers the dates form, Keep paused, the Bring back dialog or Remove with Undo. Kit tests cover the rules | QA, 18 Nov. `AppUITests` |
| Product owner | No way to pause one habit for past dates. "Pause this habit" starts today, and a dated pause covers every habit, so pausing after the fact for one habit costs the others' done marks. Time blindness means a pause is often seen as needed only afterwards | Neurodiversity, 18 Nov. `PauseDatesView.swift`, `HabitFormView.swift` pauseSection |
| 4 | Habit detail, Month and Year, for a habit brought back after a long archive: the archived span now draws as a band of paused dashes where it drew nothing. Check it does not make the gap louder than silence | Neurodiversity, 18 Nov. No screenshot yet. `AppModel.bringBack` |
| 4 | The tired daily user and the behavioural scientist used both rounds before the widget's rows became chosen once a day. Their concerns (a row moving under the thumb, prompting what is left) are what the rule answers. They see it at the next stop | `WidgetSnapshot.shownRows` |
| 4 | The widget's rows are stored for each day ahead, so the first tap of a day keeps the rows drawn (`theFirstTapOfADayKeepsTheRowsDrawnAhead`). Made after the neurodiversity expert's second round, to that lens's fix. No lens has seen it | `Shared/WidgetRows.swift`, `Widget/HabitWidget.swift` |
| 4 | A screenshot of Remove on an earlier pause that no other pause covers, showing its impact lines | Neurodiversity, 18 Nov. `pause-form-paper.jpg` shows only "You can undo this." because Pause everything covers its days |
| 13 | History month with many habits has no screenshot | `m2-hist-many.png` is Week only |
| 4 | Marks in a History row are small beside text at the largest size. If the cells grow, lift the cap on the week header letters (`.dynamicTypeSize(...xxxLarge)` in `HistoryWeekHeader`) | `ax-history.png`, `ax5-history-paper.jpg` |
| 13 | No screen was checked on a phone smaller than 393 by 852 points | `sheet-ax.png` |
| 13 | Swipe to change period in Habit detail and History, beside the arrows. Needs a check that it does not fight the back swipe | Human factors, 15 Nov. `detail-month-paper.jpg` |
| 13 | "What the marks mean" in Habit detail sits below the stats, out of view, and is missing before the first log | First-day user, 15 Nov. `HabitDetailView.swift`, `detail-month-paper.jpg` |
| 13 | Weekday labels in the Habit detail week shrink one by one, so a row can mix sizes, most in longer languages | Typographer, 15 Nov. `HabitDetailView.swift`, WeekGrid |
| 13 | A file picker that fails to open a file shows nothing | UI and UX designer, 15 Nov. `ImportExport.swift`, `ImportPresenter` |
| 13 | Habit detail for a no-set-days habit says nothing about why Current run is missing. A line such as "Runs count set days. This habit has none." waits for the wording lenses | Behavioural scientist, content designer, 16 Nov. `HabitDetailView.swift`, StatsBlock |
| 13 | The marks board and the small keys have no "No set days" entry. The dot's entry reads "Not scheduled" | Accessibility, 16 Nov. `YouView.swift`, `CalendarParts.swift` |
| 13 | No UI run covers the form opened after travel or a day-start change, where today's rule differs from the latest one. The kit covers `ruleForEditing` and `rule(on:)` | QA, 16 Nov. `HabitFormView.swift` init |
| 13 | Package tests run on iOS only when run on the simulator (`xcodebuild test -scheme HabitKit`). Add that run to the definition-of-done walk | Senior software engineer, 16 Nov |
| 13 | At accessibility sizes a Today row's control sits on its own line below the name and count, where it can read as part of the next row. This came before the form work | First-day user, 16 Nov. `ax5-nodays-today-paper.jpg` |
| 13 | `.disabled` on controls drawn in a style colour dims them a second time, below the text floor. Check DaySheet.swift:149 and :155 and CalendarParts.swift:121 and :127, as the day shortcuts were fixed | Colour vision and low vision, 16 Nov |
| Next stop | Mac form, for the owner's test after the merge gate: the segmented Logging control's width, a focus ring on plain fields and day buttons, `.searchable` and the title in the symbol picker sheet | Apple industrial designer, 16 Nov. `HabitFormView.swift`, `Pickers.swift` |
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
