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

**Days to come draw nothing.** The brief drew a scheduled future day as a faint dashed outline. Week and Month already drew nothing for those days after the low-vision review, so the state was removed. A future day that holds a log draws by its state.

**Weeks, months and years are Gregorian.** Day keys are Gregorian dates, so each period holds whole stored days. Weeks start on the user's first weekday, and names follow the user's locale.

**The year view starts at the week of the first day.** A week belongs to the month that holds its Monday, so every day appears once. The first week can begin in the month or year before.

**A yes-or-no habit shows Days logged, not a unit total.** A count of one per day says nothing more. Counted habits show both.

**A deleted habit is not exported.** Export holds what the user can see, including archived habits. Import skips logs and pauses for a habit deleted on this device, so a deletion is not undone by an old file.

**Import has limits.** 64 MB, 1,000 habits, 300,000 logs, 10,000 pauses and 500 characters of text. A file over any of them is refused with nothing written. This meets the import gate set by the security and QA reviews.

**A day's total stops at 1,000,000.** Adds stop at the cap, so Clear and take-back stay within it, and every day the app can write is one import accepts.

**A past-day log says which day.** The Undo line reads "Logged 7 November" or "Cleared 7 November", and VoiceOver adds "Undo available".

**The off-schedule dot is in the tertiary text colour.** It measures 4.87:1 on Paper and 5.22:1 on Ink, so it meets 3:1 without drawing attention.

**Habit detail opens from "Details".** It is in the row menu and the swipe actions on Today, and a tap on a row in History. The name is still a guess for the content designer.
