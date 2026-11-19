# Decisions

One entry per decision that changed the brief. Each says what changed and why, in two or three sentences. Newest last. Details are in `docs/spec.md`.

## 14 November 2026

**Year view uses shapes, not opacity.** The brief asked for four opacity steps. Three reviews measured neighbouring steps at 1.2:1 to 1.5:1, so an empty day and a part-done day looked the same. Each state is now a small shape.

**A day with no log draws nothing.** The brief drew a missed day as an empty outline. That is a mention of a missed day, which invariant 1 forbids unless the user opts in. One switch, "Show days not logged", brings the outline back.

**Whole-number amounts, typed.** The brief stored each log as plus or minus one. A habit of 15,000 steps would need thousands of events. A log now stores any whole number, and every number in the app can be typed.

**An entitlements file is allowed for the App Group.** The brief banned the file to keep CloudKit out. Widgets and the Watch need a shared store, which needs the file. CloudKit is still out.

**Milestones reordered.** Milestone 1 is the core loop in Pen and ink, with Edit, Archive and manual order. Export and import moved to milestone 2, because the phone holds the only copy of the data. Pencil and Watercolor are milestone 4.

**Scene art is supplemental.** Scenes moved to milestone 5. The art does not change whether the app works, and it was the slowest part of the design. Marks default to Blue until then.

**Red is allowed as a user's accent.** The brief said no red anywhere. Some cultures read red as lucky, and a colour the user picks carries no meaning from the app. The app's own colours still never use red.

**Three reviews per milestone, twenty at the stops.** Eight at once hit the usage limit twice. Engineer, QA and tired daily user run after each milestone, with accessibility and security added when relevant.

**Twelve lenses added.** Product owner, first-day user, content designer, QA, release engineer, UI and UX, human factors, senior designer, behavioural scientist, neurodiversity expert, returning user and illustrator. The first eight covered engineering and visual design but not behaviour, inclusion, flows or release.

**Three tabs.** Tags moved into You. NFC is a shortcut, works on iPhone only, and arrives late, so it did not earn a quarter of the navigation.

**A control-side setting.** A left thumb cannot reach a control on the trailing edge of a large phone. One setting in You moves the control to the leading side.

**Reviews may override the brief on design.** The brief began as an idea, and development follows evidence. Privacy, dependencies, the schema rule and cost stay with the owner, and so does any case where two reviews disagree.

**A counted habit may have no target.** Three reviews said a required target turns a count into a pass or fail test. With no target, any log draws as done. Something is better than nothing.

**A part-done day never breaks a run.** A day at 7 of 8 was scored the same as a day with nothing. Habit detail now shows "Days logged" beside "Days done".

**One widget in milestone 3.** Milestones 1 to 3 gave the user no cue outside the app. A Home Screen widget is a cue the user places, and it carries no guilt.

**"Extra credit" became "Logged while paused".** Three reviews read the old name as grading language. The rule itself did not change.

**Data rules accepted.** Ten rules for how logs are stored, from the engineering and QA reviews. They are fixed before milestone 1 because stored data can only be added to later.

**Pencil marks redrawn.** The senior designer found that Pencil read as Pen and ink with a marker font. Done is now cross-hatched and part done is hatched one way, so the two differ by shape and each stroke shows. The font is lighter and the paper tooth is coarser.

**Pencil marks, second pass.** A review measured done and part done at 1.2:1 apart once blurred, which is state carried by tone. Part done now covers half the square on the diagonal and done covers all of it, so they differ by outline. Strokes are drawn at full strength because the pencil texture had pulled them under 3:1.

## 15 November 2026

**The Pencil control square stays dark.** The senior designer wanted it in soft grey so empty rows go quiet. The accessibility review wanted it easy to find. Accessibility wins, because the square is the thing the user taps and the goal is inclusion from the first milestone. The line gets thinner, which answers the designer's point about weight.

## 15 November 2026, milestone 1

**The shared store works with free signing.** A throwaway project with an app and a widget shared one App Group on the owner's iPhone. The widget read what the app wrote in shared settings, a file and a SwiftData store. Milestone 1 builds on that store.

**Day keys use the Gregorian calendar.** A key is yyyymmdd, and a non-Gregorian calendar would make stored keys mean different days for different users. Keys are Gregorian in the user's time zone, and dates are shown in the user's own calendar.

**Two tabs until history exists.** Progress has nothing to show before the heat map in milestone 2. An empty tab is a dead end, so Today and You are the only tabs until then.

**An off-schedule log reads "Logged on a day off".** The data rules credit a log on an off-schedule day like a log on a paused day, and both draw the diamond. "Logged while paused" would be untrue on a day that was never paused, so VoiceOver and the marks board use their own words for it.

**A part-done day extends a run.** The spec says a part-done day never breaks a run. Something is better than nothing, so it also counts toward the run, as any logged day does. A tested rule keeps it from drifting later.

**The models hold what milestone 1 uses.** `Habit` has the fields milestone 1 needs, and `Pause` exists now so the set of models does not change in milestone 3. Focus, nudge, tag and descriptor fields are added in the milestone that first uses them, which the additive schema rule allows without a new schema version.

**An empty tap amount opens the count sheet.** `tapAmount` is optional with a default of 1, and empty means a tap opens the sheet. That is what the spec asks for above a target of 20, and it needs no special number.

**A yes-or-no tap always lifts the day to done.** Two devices taking back one log offline can leave a total of −1, which shows as 0. A tap then writes enough to reach 1, so it is never swallowed. Typed amounts are always written as typed.

**Archived habits still log from Shortcuts.** A tag or shortcut that stopped working would break invariant 4. The intent logs it and says the habit is archived and can be brought back in You.

**The Undo line waits for VoiceOver.** It shows for five seconds. With VoiceOver on it stays until the next action, because five seconds is too short to reach the button. System undo also takes back the last log.

**The count sheet amount starts selected.** The UI test found that typing 12 after the tap amount of 1 gave 112. The amount now starts focused and selected, so typing replaces it and Add still works with no typing.

**Mark colour sits on the Appearance page.** The milestone 1 mockup shows the eight swatches on the page itself. The separate "Marks" list in the spec comes with "Follow the scene" in milestone 5.

**Large text gets lists where controls do not grow.** A segmented control keeps its small text at accessibility sizes. At those sizes Kind and Light or dark become lists, and symbol cells grow with the text.

**Each reason sits under its field.** If Add is disabled, the reason appears under the field that causes it: the name, the target, the tap amount or the days. A reason at the bottom of the form would be off screen while the keyboard is up.

**Cancel asks before throwing away changes.** A swipe down is blocked when the form has changes, and Cancel asks "Discard changes?". Without changes Cancel closes at once.

**The signing team is not committed.** The team id lives in `Config/Local.xcconfig`, which git ignores, with an example file beside it. The repo is public and the id is tied to a person.

**Screenshots are half-size JPEGs.** Thirty-seven PNGs at full size would add about 20 MB to a public repo. `tools/screenshots/m1.sh` makes them the same way each time.

**A shortcut only ever logs.** The QA review found that running a yes-or-no shortcut twice took the log back, because a tap toggles. Shortcuts, Siri and NFC now mean "log", and Take away with no amount takes away one tap. In-app taps still toggle, as the spec says.

**Every counted change shows Undo.** The tired daily user review found that an extra tap on a counted habit had no quick way back. Every add and take-away on a counted habit now shows its new count with Undo. A yes-or-no log shows only its mark.

**The Undo line stays until the next action.** The accessibility review found five seconds too short for Switch Control and Voice Control users. The line now stays until the next log or archive, for everyone. This replaces the earlier five-second rule.

**Typed numbers stop at 1,000,000.** The QA review showed that a huge number could overflow a sum and crash the app at every launch. Typing, Shortcuts and writes share one cap.

**The count sheet opens full height at large text.** The accessibility review found the keyboard hid the total at AX5. At accessibility sizes the sheet opens full height and waits for a tap on the amount.

**A tap on the name logs.** The tired daily user review found most of a row opened Edit, so a tired tap on the name did nothing useful. The spec had the name open Edit, from the inclusion and human factors reviews. The owner chose the log on 15 November 2026. Edit and Archive are in swipe actions and the touch-and-hold menu, and a wrong log has Undo.

**Logging needs an unlocked device.** The security review found that Siri could read habit names and counts aloud on a locked phone. Habit names can be health details. The owner decided on 15 November 2026 that every intent needs an unlocked device, and a test checks each intent in every target.

**The branch history was rewritten.** The first nine milestone 1 commits carried the owner's personal email. The owner approved a rewrite and force push on 15 November 2026. The commits now carry the GitHub noreply address, and their contents did not change.

## 15 November 2026, milestone 2 design

**Future days in the month view show the date alone.** The accessibility review wanted a faint dashed box so a future day differs from a blank past day. The senior designer wanted it gone because it was the loudest thing on the screen and said the least. The "Add a past day" button now gives a clear way to log a past day, so the boxes no longer earn their place.

**Every addition must earn its place.** The owner set this as the test when two reviews disagree: it must add value and fit the vision and the expert reviews.

**No false binaries.** When two reviews disagree, the first step is to look for a third option that meets what both are protecting, before anyone chooses a side. The owner asked for this after the run-at-zero question, where showing a zero and hiding the row both did harm and a third wording avoided both.

**The Progress tab is now History.** Three reviews agreed (behavioural, neurodiversity and returning user, content). "Progress" implies a direction, so a quiet week reads as a lack of it. "Log" was ruled out because the app already uses it for an entry.

**After a gap, Current run reads "Between runs".** The reviews first split three ways: hide the row, "Starts with any log", or a state phrase. In a second round all three accepted the state phrase, because it shows no zero, gives no instruction and keeps the row the user asked for. Before the first log it reads "No run yet".


**A day that is not scheduled shows a small dot.** The brief drew it blank, the same as a day with nothing logged. The accessibility and tired-user reviews found that a returning user counts those blanks as gaps, and that the app showed "off" three different ways. One dot is now used in week, month, year and History.

**A History row puts the name above its seven days.** The UI and accessibility reviews found the day cells were 23 points apart, so a thumb aimed at Wednesday could open Tuesday. Each cell is now 44 points wide.

**Three reviews confirmed that a part-done day extends a run.** Milestone 1 already built it that way. The behavioural, neurodiversity and content reviews reached the same answer on their own.

**Export is a plain file with no device id.** The security review wanted the device id left out, and the engineering review accepted a fixed "imported" value in its place. The owner deferred to the reviews. The export screen says the file is not encrypted.

**A password on export comes after the MVP.** The reviews agree it should exist and be off by default, because a forgotten password loses that copy for good. The system password manager may offer to save it, which the owner agreed to. The app itself never stores it.

**Invariant 5 names import as a second way in.** The engineering, QA and security reviews agreed that import must share the write code but cannot call the intent once per log, because a failure part way would leave half a file written. The owner approved the new wording. A source check keeps any other code from writing a log.

## 15 November 2026, milestone 3 design

**"Gentle Mode" names the feature, and its two controls are named for what they do.** The reviews first replaced both names with "Pause everything" and "Pause for dates", because mood names hide the action. The owner asked to keep the name, for recognition and an icon. Both reviews then accepted "Gentle Mode" as the section header with the pause symbol, over two action rows with a description each. "Vacation" is gone, because someone ill will not look there.

**Every pause ends the same way.** The reviews first disagreed: one wanted today always kept paused, the other wanted a slip to be fully undone. Both accepted one rule. Ending a pause resumes tomorrow, and a pause that began today is removed whole.

**"Pause everything" is one tap from Today.** The first draft had it only in You, which is three steps on a bad day. It needs no confirmation because a pause does no harm and can be undone.

**A paused counted row shows no target.** "0 of 8 glasses" on a rest day reads as a demand. It now shows "0 glasses".

## 15 November 2026, Mac design

**On the Mac, settings live in a Settings window.** The brief put You in the sidebar on every platform. The Apple platform review found that a Mac user presses Command-comma and expects settings there. Pausing moves to the Habit menu and Today, and Export and Import move to the File menu.

**Mac controls sit in the window toolbar and rows can be selected.** The first draft was the phone page centred in a window. The platform and accessibility reviews asked for toolbar buttons, a visible selection, arrow keys and a full set of menu commands, so every action works from the keyboard.

## 15 November 2026, History tab

**The History tab has Week and Month, and no Year.** The brief gave it all three. Four reviews found that a year row for every habit needs one cell per week, which sums up seven days and reads as a grade. Year stays in Habit detail, one tap away.

**Reviews are sized by what a change touches and how hard it is to undo.** The owner asked for a logic with fewer reviews and no unchecked work moving forward. Twelve rules and a routing table are now in `CLAUDE.md`, tested by a tech lead, QA and product review. Open findings, gates and guesses live in one list, `docs/findings.md`.

## 15 November 2026, milestone 2 build

**The Mac app may read and write a file the user picks.** Export and import on the Mac use the system save and open panels, which the sandbox blocks without the user-selected files entitlement. The owner approved it. The app gets no other file access.

**Days to come draw nothing.** The brief drew a scheduled future day as a faint dashed outline. Week and Month already drew nothing for those days after the low-vision and tired-user check (`docs/spec.md`, History tab), so the state was removed. `CLAUDE.md` still lists the dashed outline under the design rules, and the owner is asked to remove it. A future day that holds a log draws by its state.

**Weeks, months and years are Gregorian.** Day keys are Gregorian dates, so each period holds whole stored days. Weeks start on the user's first weekday, and names follow the user's locale.

**The year view starts at the week of the first day.** A week belongs to the month that holds its Monday, so every day appears once. The first week can begin in the month or year before.

**A yes-or-no habit shows Days logged, not a unit total.** A count of one per day says nothing more. Counted habits show both.

**A deleted habit is not exported.** Export holds what the user can see, including archived habits. Import skips logs and pauses for a habit deleted on this device, so a deletion is not undone by an old file.

**Import has limits.** 64 MB, 1,000 habits, 300,000 logs, 10,000 pauses and 500 characters of text. A file over any of them is refused with nothing written. This meets the import gate set by the security and QA reviews.

**A day's total stops at 1,000,000.** Adds stop at the cap, so Clear and take-back stay within it, and every day the app can write is one import accepts.

**A past-day log says which day.** The Undo line reads "Logged 7 November" or "Cleared 7 November", and VoiceOver adds "Undo available".

**The off-schedule dot is in the tertiary text colour.** It measures 4.87:1 on Paper and 5.22:1 on Ink, so it meets 3:1 without drawing attention.

**Habit detail opens from "Details".** It is in the row menu and the swipe actions on Today, and a tap on a row in History. The name is still a guess for the content designer.

**Each window has its own state.** One model was shared by every window, so an export or import opened in all of them, and the Mac File menu stayed live with no window open. Each window now has its own, and the Mac menus act on the focused window and are off when none is open. Asked for by the release engineer.

**The import preview leads with what changes.** It showed the file's totals first, so the reader had to subtract. It now shows the habits, logs and pauses it adds and the logs already here, in the same rows as the result. Asked for by the tired daily user.

**An archived habit takes no logs in Habit detail either.** History already drew an archived habit's days as plain marks, while detail let them be logged. Detail now matches in Week, Month and Year: its days are not buttons, there is no today outline, and "Add a past day" becomes "Bring back", which shows an Undo line. Asked for by the UI and UX designer.

**The Undo line shows only in the tab where the action was made.** A line made in History also showed on Today, where Undo would change a day out of sight. Asked for by the UI and UX designer.

**The day sheet says what each button makes.** A count could only be corrected by working out the difference. A line under the amount now reads, for example, "Add makes 9. Take away makes 7." Clear this day is on its own row with a symbol, away from Take away. Asked for by human factors.

**The past-day amount starts at the tap amount**, as the count sheet on Today does. Asked for by the first-day user and the UI and UX designer.

**Add a past day has a button at the bottom, "Open this day",** as well as Next, and the day sheet follows the picker with no timer. Asked for by human factors.

**The import preview names the habits that get logs and the days they cover,** because an import cannot be undone. Asked for by human factors.

**History's hint sits above the rows, and Week links to the marks board.** The hint was under the last row, behind the tab bar. Asked for by the first-day user.

**A failed export says so.** A cancelled share leaves the export screen open, and a failed save on the Mac shows the existing message. Asked for by the UI and UX designer.

**The key has no Today entry.** The senior designer decided the guess: the entry made the key three lines, and beside "Not logged" it was a second empty square. Today's outline is the last cell drawn in the current period.

**A day before a habit began draws nothing.** The year view drew off-day dots in the weeks before the "Since" date. Asked for by the colour vision and low vision review.

**Today's small outline sits inside its cell,** heavier than the not-logged square, with the day's mark filling the space inside it, so it never joins the next day's mark. The year grid's cells grow with text size. Asked for by the colour vision and low vision review.

**The day sheet's buttons say what they make,** "Add, makes 9" and "Take away, makes 7", in place of a separate line. The habit's name is a heading that wraps, and the bar shows the date. Asked for by the senior designer and the typographer.

**A unit is shown as typed.** Habit detail's total reads "Total 1,253 ml", so "ml" never becomes "Ml". Asked for by the typographer.

**Habit detail shows no pair of counts that makes a pass rate unless the user opted in.** By default it shows Days logged and, for a counted habit, the total. Days done comes with Show runs, and the "Since" date with Show days not logged. "This week" counts days logged for a habit with a daily target, not a weekly sum. The neurodiversity and behavioural reviews both found that Days logged beside Days done, under a start date, read as days failed. This changes the owner's 14 November default, which showed Days done.

**The run help line matches the run maths.** It now says a run counts the days in a row with any log, and days off don't break it. The old line said only scheduled days count, which could stop someone logging on a day off. Asked for by the behavioural scientist.

**Counts have plural forms in a String Catalog,** and dates, week ranges and lists follow the locale. The past-day Undo line names the habit. The day sheet buttons read "Add 1, total 9". "Already here" became "Logs already here". "Details" stays as the row menu name. Asked for by the content designer.

**While the current run is "Between runs", Longest run stays, second and quieter.** The neurodiversity review found the best-ever run under "Between runs" read as "you used to be better". The behavioural review wanted it kept, because a past best shows it can be done again. Both accepted it shown after Current run, smaller, in the secondary colour and with no rule. Days done moves after the runs.

**History and Habit detail use about 720 points on iPad and Mac,** and a History week row puts the name and its seven days on one line there. Mac sheets have a width in place of detents, Return exports, and the Mac Settings window drops "Controls on the left". Asked for by the Apple industrial designer, under the Mac window rules.

**Longest run is always quiet and is the last stat.** It is smaller, in the secondary colour and with no rule, after Days done on screen and in VoiceOver. The returning user asked for it to stay quiet on a restart day, so "1 day" does not sit over a full-weight "14 days". A first version made it full weight while the current run was the longest. The neurodiversity review failed that: a missed day then changed the screen, which is a loss signal. The behavioural review had passed it as a reward. Both then passed always-quiet. Current run, full weight and growing, carries the reward, and a new best shows as the number rising in place.

**The screenshot flags for Show runs and Show days not logged work only in debug builds.** Asked for by the product owner.

**The Mac Settings window clears its Undo line when it closes,** so an Undo from an earlier visit never acts on a habit used since. Asked for by the Apple industrial designer.

**The small "logged" diamond is split by a flat gap of 2.5 units in a 12-unit cell.** A whole diamond blurred too close to done (0.16 against a pass mark of 0.25). Split, it measures 0.38. Measured in `docs/m4-blur-test.md` on `docs/milestone-4-design`. The full-size diamond is unchanged. The marks board shows the small split diamond beside the large one, so the two read as one state. The senior designer and the colour vision and low vision reviews asked for that. Whether the large diamond takes the gap is decided in milestone 4.

**The diamond has one cut at every size.** Up to 12 points the cut is 2.5 units in 12 of the mark's width. Above 12 points it is a 1.25 point hairline, so the full-size diamond in Today, Week and Month gains a hairline and stays one diamond. The key reads "Logged on a paused day or a day off", because the cut is part of the diamond and does not mean paused. Settled on `docs/milestone-4-design` by the accessibility, low-vision, senior designer, product owner and first-day user reviews (`docs/m4-blur-test.md`, `docs/mockups/png/m4-diamond-cut.png`). This replaces the milestone 4 gate on whether the large diamond takes the gap.

## No set days and the new habit form, 16 November 2026

**A habit may have no set days.** `scheduleMask` 0 means "no set days": a valid habit that is never owed and can be logged on any day. It is not a missing value. Add and Save stay enabled with no day chosen. HabitKit owns the form rule (`HabitForm.problems`), and the schedule is never a problem. Import already accepted 0, so there is no schema change and the export stays at version 1. Masks above 127 and below 0 are still refused. Passed by the senior software engineer and the QA engineer, with tests for the stored meaning, the import of 0, a round trip, a second import of the same file, and the refusal of 128 and -1.

**A no-set-days habit sits in Today's main list, in the user's own order, with no second line.** It is never in "Not scheduled today", because that group means a day off. A second-line button was turned down by the UI and UX designer and human factors as a second target. Passed by the UI and UX designer, human factors, the first-day user and the accessibility expert.

**Its marks.** Today with no log shows the small dot, as its own state (`DayState.noSetDays`), read by VoiceOver as "No set days", not "Not scheduled". A log is done or part done by the target, as on a set day, never the day-off diamond. Any other day with no log draws nothing, even with Show days not logged on, because nothing was owed. A paused day with a log is still "Logged while paused". Under a counted habit's plus the dot sits low, so the plus does not cover it. The brief pinned the dot on every past day and the diamond for a log. The content designer, the neurodiversity expert, the tired daily user, the behavioural scientist, the returning user and the accessibility expert all found that a page of dots read as days off and the diamond read as "not a real day". This third option passed all six.

**Its runs.** A run is measured against set days. Under a no-set-days rule, a log without a pause neither extends nor breaks a run, and a day with no log is neutral. A paused log under no set days was first left to extend a run. The owner changed that on 16 November 2026 (below). Current run is hidden while today has no set days. Longest run shows when it is above 0, and Days logged always shows. The test pins logs on day -40, -20 and today at current 0, longest 0, 3 days logged. Logs months apart never read as a three-day run. Settled by the behavioural scientist, the neurodiversity expert and the returning user. A run from set days is kept through a spell of no set days and back.

**The form's words.** Under the day buttons: "Every day. Choose a day to leave it out." with all seven chosen, "No set days. Log it on any day." with none, and the read-only sentence otherwise ("Every day except Thursday"). Habit detail reads "No set days". Passed by the content designer, the neurodiversity expert and the tired daily user. The neurodiversity expert preferred "turn it off" to "leave it out". It is noted, not adopted, because the content designer found "turn off" reads as a setting.

**New habit and Edit habit follow `sheet-new-habit.png`.** One column with labels above fields on every platform, which fixes the Mac padding. Logging is "Mark done" or "Count", a segmented control that becomes two full-width buttons at accessibility sizes. The day buttons are outlined circles. A chosen day has a heavier outline and a checkmark, so the state is carried by shape. The symbol row is None, five symbols and "More…", which opens a searchable picker in eleven groups of twelve. The default symbol is none. Unit and the log amount sit one step in, on "Unit and log amount".

**Choosing no set days on a day already logged applies from tomorrow.** The form says "Today is logged, so this applies from tomorrow." in place of "A change applies from today." Applied today, the edit took today's log out of a run, so Longest run fell by one after a kind choice. Every other edit, a target change included, applies from today. Edit habit opens on a change waiting for tomorrow. Two or more edits on one day end with the last choice. Passed by the behavioural scientist and the returning user in round two. The neurodiversity expert preferred keeping the day's better run credit with no new line (option d), and gave the wording used here if this option was chosen.

**A no-set-days habit with nothing logged today shows its target alone, "20 minutes", not "0 of 20 minutes".** A zero against a target read as a daily quota on a habit that is never owed. Asked for by the behavioural scientist and the returning user.

**The locked Logging line names the way out:** "This is fixed once a habit has logs. To count instead, add a new habit." Asked for by the neurodiversity expert.

**Symbol search matches what a habit is for,** such as "teeth", "meds", "therapy" and "chores", through search words on each symbol. A search with no match says "No symbols match. A habit works without one." and offers None. Asked for by the neurodiversity expert.

**Wording and flows round, 16 November 2026.**
- A no-set-days row with nothing logged today reads "Target 20 minutes". The target alone read as 20 minutes logged. Asked for by the content designer.
- The form's field is "Target", and the line under it follows the field: "With no target, any amount counts as done." while empty, and "A day is done when its total reaches the target." once typed. "Target each day" brought back a daily quota for a habit with no set days, and the no-target line stayed under a typed target. Asked for by the tired daily user.
- Day buttons use two letters of the short name where all seven differ, and the locale's very short names, or the short names in full, where they repeat, as in Arabic and Hebrew. Tested over fourteen locales. Asked for by the content designer.
- "This stays as it is once a habit has logs." replaces "fixed", which can translate as "repaired". The unit summary is one string per case, such as "glasses, adds 1". Search words split on any comma. Asked for by the content designer.
- Habit detail reads today's rule, and adds "From tomorrow: No set days." while a change waits. Archive keeps valid edits made before it. The symbol picker's chips stay in place, it opens on the chosen symbol, and a swipe cannot close it while a new symbol is picked but not confirmed. On the Mac, Unit and the log amount sit in the form, because a Mac sheet has no back button. Asked for by the UI and UX designer and the tired daily user.
- "Add a name to continue." stays on a blank New habit form. The UI and UX designer asked for it to wait for a first attempt. `docs/spec.md` says "If Add is disabled, a line says why", and the tired daily user and the neurodiversity expert passed it.

**Type and human factors round, 16 November 2026.**
- Number fields in the form use the label face with tabular digits, so a target matches the Today row. Field labels and the picker's group headings share one uppercase label with the style's caps tracking. The day list at large sizes keeps one weight, and the checkmark carries the state. The name field holds up to twelve lines at accessibility sizes. The day circles keep one text size and become the list from xxLarge. Asked for by the typographer.
- The whole Target row focuses its field. Done above the number pad puts it away. Archive sits further from the day shortcuts and, with unsaved changes, asks: "Save changes and archive", "Archive without changes" or "Keep editing". This meets the UI and UX designer, who wanted edits kept, and human factors, who wanted nothing saved without saying so. Asked for by human factors.
- A third shortcut, "Set no days", makes no set days one tap, as every day and weekdays are. The owner's drawing shows two. Asked for by the first-day user, who found a new user would have to clear seven circles to find it.

**Platform, design, colour vision and release round, 16 November 2026.**
- Return in the name field finishes the name and puts the keyboard away, as its Done key says. A name is one line. Asked for by the Apple industrial designer.
- Done above the keyboard shows only for the number pads (Target, and One log adds on its own page), which have no return key. Asked for by the senior designer, who found Done floating over the form while the name keyboard already had one. This also meets the Apple industrial designer's finding that Done did nothing in the Unit field.
- Archive with unsaved changes that cannot be saved asks "Archive without your changes?". "Archive without changes" is marked destructive, as "Discard changes" is. Asked for by the Apple industrial designer.
- "A change applies from today. Earlier days keep what they had." shows only once the days or the target differ from the saved habit. Asked for by the senior designer.
- The symbol set drops `flame` (a streak sign elsewhere), `guitars` (unreadable at row size) and one of each look-alike: `lightbulb.max`, `sun.horizon`, `cloud.moon`, `quote.bubble`, `person.3`, `pawprint`. "Water" for `water.waves` is now "Waves". Groups are no longer padded to twelve. Asked for by the senior designer. The size of the set is the product owner's to confirm at the next stop.
- A shortcut that already matches is no longer disabled. Disabling dimmed tertiary text a second time, to 2.4:1. It stays in tertiary text, a tap changes nothing, and VoiceOver reads "Already set". Asked for by colour vision and low vision.
- With a dot under a plus, the plus moves up and the two are centred as one group, 1.5 points apart at every size, with Increase Contrast too. A test asserts the gap. Asked for by colour vision and low vision.
- A chosen day circle's stroke is twice an open one's, so they stay apart under Increase Contrast. Asked for by colour vision and low vision.
- Launch arguments are read in debug builds only, and a screen only with a fixture store, so no argument can open a form on the user's own habits. The screenshot script refuses another device unless its own output folder is named. Asked for by the release engineer.

**Invariant 3 reworded, 16 November 2026.** The owner decided that under no set days a pause changes nothing. A paused log there neither extends nor breaks a run, the same as an unpaused log. Invariant 3 now reads: "A paused day with no log never breaks a run and never extends it. A paused set day with a log extends it. Under no set days a pause changes nothing." The day still reads "Logged while paused" and still counts in Days logged and Days done. Before, two paused logs twenty days apart read as Longest run 2. Proposed by the behavioural scientist and the neurodiversity expert. The returning user's condition, that a pause never lowers a run, holds. Tests: `pausedLogUnderNoSetDaysLeavesTheRunUnchanged`, `aPausedDayWithALogChangesNothingUnderNoSetDays`, `pausedLogUnderNoSetDaysNeverLowersLongest`.

**Milestone 3 build, 18 November 2026.** These were decided while building, before the lenses ran. Each is checked by the lenses at the stop.
- Pause and resume act at once in Edit, without waiting for Save. Cancel does not undo them. A pause is not a field of the habit, and "Undo pause" sits in the same place.
- The Target and Unit fields read "Optional" when empty. "None" read as a value already set. Asked for by the owner.
- The Pause for dates impact line counts calendar days, the future included, and skips days another pause already covers.
- In the dated pause list, a pause that covers today sits under Coming.
- "Keep paused" puts back the last day a pause had before "Resume tomorrow", within the session. After a relaunch it opens "Pause everything" again.
- Pause dates use the system's interval format, and leave out the year when it is this year.
- "Pause everything" leaves the Not scheduled group as it is.
- The widget is iOS only, small and medium. Each row logs through `WidgetLogIntent`, which calls `LogHabitIntent` and writes nothing if the day or the total changed since the widget drew. A counted habit with no tap amount opens the app.
- Today and You use a 560 point column on iPad and the Mac. History keeps 720. Asked for by the Apple industrial designer.
- With every habit archived, Today says "Nothing on Today" and offers "Show archived habits" and "Add a habit". Asked for by the returning user.
- On the Mac, the page heading in History and the form is left out, because the window title names it. Asked for by the owner.
- On the Mac, Export a Copy opens the save panel at once, with the warning in the panel. The export sheet is iOS only. Asked for by the Apple industrial designer.
- The Undo line's inset is on Today's list, so a logged row it covers scrolls clear. Asked for by accessibility and the UI and UX designer.
- Mac shortcuts: Week, Month and Year are Option-Command-1 to 3, Previous and Next Period are Command-Left and Command-Right, Go to Today is Command-T, Back is Command-[, Log is Command-L, Add an Amount is Option-Command-L, Show Details is Command-I and Edit Habit is Command-E. Archive and the pause items have no shortcut.

**Milestone 3 lens round one, 18 November 2026.**
- Days to come draw nothing, paused or not. An open pause drew a dash on every day left in the month, which read as a forecast of giving up. Asked for by the behavioural scientist.
- Bring back always pauses the days the habit was archived, up to yesterday, and says so in its Undo line. If the archive day holds a log, the pause starts the day after, so a done day stays done (neurodiversity expert). The question is gone. Nothing could be logged while the habit was archived, so the pause only helps, and the other answer could only break a run. This replaces the offer in `docs/spec.md`, open decision 6. Asked for by the behavioural scientist.
- The widget keeps Today's order when every row fits. When rows must be dropped, they are chosen at the day's first draw and kept all day: rows still to do (nothing logged, or part done) take the places first, and a line says how many more there are. While paused, Today's order. The tired daily user asked for the line, so done marks never read as the whole day. The behavioural scientist asked that the widget keep prompting what is left. In round two both found that choosing again after every tap moved a row under the thumb, so a second tap logged a different habit and the logged mark was never seen. The neurodiversity expert proposed choosing once a day, which meets all three. `WidgetSnapshot.shownRows`, `Shared/WidgetRows.swift`.
- The small widget's paused header is the symbol alone. At accessibility sizes the small widget shows one row and the medium two, the header keeps to one line, and the empty widget shows "Add a habit" alone. Asked for by the tired daily user.
- While paused, the pause line at the top holds the one Undo pause or Resume tomorrow button. The bottom "Pause everything" button goes, so the same button never shows twice. Asked for by the tired daily user.
- The dated pause list heads its first group "Now and coming" and no longer marks pauses from Pause everything. Every pause in the list pauses every habit. Asked for by the tired daily user.
- A counted row logged on a paused day says "Logged while paused", as a yes-or-no row does. Asked for by the behavioural scientist.
- VoiceOver hears "Resumes tomorrow.", "Pause undone." and "Paused again.", and nothing when a save fails. A paused row's name carries the same value as its control. The dates form's impact lines are the Save button's hint. The pause line's full sentence is read at every size. Asked for by the accessibility expert.
- Remove on a dated pause shows what it changes: how many days will no longer be paused, how many logged days draw as before, and, for days before today, "A run through these days may get shorter." "Days lose their pause" now reads "days will no longer be paused." Asked for by the neurodiversity expert.

**Milestone 3 lens round one, continued, 18 November 2026.**
- Wording, asked for by the content designer: "Undo pause ends it, and today shows as it did before."; "%lld more days will be paused."; the widget's line reads "%lld more habits" and is its own VoiceOver element; the widget's counted hint reads "Adds 250 ml" with the unit, or "Opens the app to add an amount"; the Mac View menu's item reads "Undo Pause"; "Habit" as the app's name carries a comment not to translate it.
- Habit detail's link reads "Pause every habit for dates", because it pauses every habit. "Choose a date" for the last day picks yesterday when the first day is in the past. The dates form's footer says paused days leave runs as they are. Asked for by the returning user.
- Not adopted: a "Paused" status line on every row under Pause everything (returning user). The pause line at the top says it once. A line on each row would repeat it, which the tired daily user asked to avoid.

